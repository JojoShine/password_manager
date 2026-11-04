#!/usr/bin/env python3
"""Build signed Lockora candidates; promote verified immutable OSS objects last."""
import argparse
import base64
import hashlib
import html
import json
import os
from pathlib import Path, PurePosixPath
import plistlib
import re
import stat
import sys
from urllib.parse import urlparse
import xml.etree.ElementTree as ET
import zipfile

ROOT = Path(__file__).resolve().parents[1]
SP = '{http://www.andymatuschak.org/xml-namespaces/sparkle}'
ET.register_namespace('sparkle', SP[1:-1])
PREFIX = 'Download/lockora'


def validate_version(current, tag=None, previous=None):
    match = re.fullmatch(r'(0|[1-9]\d*)\.(0|[1-9]\d*)\.(0|[1-9]\d*)\+([1-9]\d*)', current)
    if not match:
        raise ValueError('Expected release version major.minor.patch+build without leading zeros')
    parts = tuple(map(int, match.groups()))
    if tag and tag != 'v' + current.split('+')[0]:
        raise ValueError('Tag differs from pubspec version')
    if previous:
        old = validate_version(previous)
        if parts[:3] <= old[:3] or parts[3] <= old[3]:
            raise ValueError('Both semantic version and build must increase')
    return parts


def version():
    match = re.search(r'^version:\s*(\S+)\s*$', (ROOT / 'pubspec.yaml').read_text(encoding='utf-8'), re.M)
    if not match:
        raise ValueError('pubspec has no version')
    validate_version(match[1])
    return match[1]


def decode(value, size):
    try:
        raw = base64.b64decode(value, validate=True)
    except Exception:
        raise ValueError('Invalid base64 signing material') from None
    if len(raw) != size:
        raise ValueError(f'Signing material must be {size} bytes')
    return raw


def config():
    data = json.loads((ROOT / 'release/config.json').read_text(encoding='utf-8'))
    for field in ('baseURL', 'macosFeedURL', 'windowsFeedURL'):
        url = urlparse(data[field])
        if url.scheme != 'https' or not url.netloc or url.query or url.fragment:
            raise ValueError(f'{field} must be an absolute HTTPS URL')
    for platform in ('macos', 'windows'):
        decode(data[platform + 'PublicKey'], 32)
        expected = data['baseURL'].rstrip('/') + f'/updates/stable/{platform}.xml'
        if data[platform + 'FeedURL'] != expected:
            raise ValueError('Feed URL must match release baseURL')
    return data


def verify_signature(payload, signature, public):
    from cryptography.exceptions import InvalidSignature
    from cryptography.hazmat.primitives.asymmetric.ed25519 import Ed25519PublicKey
    try:
        Ed25519PublicKey.from_public_bytes(decode(public, 32)).verify(decode(signature, 64), payload)
    except InvalidSignature:
        raise ValueError('Ed25519 package signature does not verify') from None


def appcast(platform, current, url, notes, length, signature, minimum):
    major, minor, patch, build = validate_version(current)
    root = ET.Element('rss', version='2.0')
    channel = ET.SubElement(root, 'channel')
    ET.SubElement(channel, 'title').text = 'Lockora updates'
    item = ET.SubElement(channel, 'item')
    ET.SubElement(item, 'title').text = f'Lockora {major}.{minor}.{patch}'
    ET.SubElement(item, SP + 'releaseNotesLink').text = notes
    ET.SubElement(item, SP + 'minimumSystemVersion').text = minimum
    attrs = {'url': url, 'length': str(length), 'type': 'application/octet-stream',
             SP + 'version': str(build) if platform == 'macos' else f'{major}.{minor}.{patch}.{build}',
             SP + 'shortVersionString': f'{major}.{minor}.{patch}',
             SP + 'edSignature': signature, SP + 'os': 'macos' if platform == 'macos' else 'windows-x64'}
    if platform == 'windows':
        attrs[SP + 'installerArguments'] = '/SILENT /SP- /NOICONS /NORESTART'
    ET.SubElement(item, 'enclosure', attrs)
    return ET.tostring(root, encoding='utf-8', xml_declaration=True)


def safe_member(name):
    path = PurePosixPath(name)
    if not name or '\\' in name or ':' in name or path.is_absolute() or '..' in path.parts:
        raise ValueError('Unsafe archive path')


def validate_zip(path):
    with zipfile.ZipFile(path) as archive:
        for item in archive.infolist():
            safe_member(item.filename)
            if stat.S_ISLNK(item.external_attr >> 16):
                target = archive.read(item).decode('utf-8')
                if target.startswith('/') or '\\' in target:
                    raise ValueError('Unsafe archive symlink')
                stack = list(PurePosixPath(item.filename).parent.parts)
                for part in PurePosixPath(target).parts:
                    if part == '..':
                        if not stack:
                            raise ValueError('Archive symlink escapes package')
                        stack.pop()
                    elif part != '.':
                        stack.append(part)
        if archive.testzip() is not None:
            raise ValueError('ZIP checksum failure')


def notes(current):
    public = current.split('+')[0]
    text = (ROOT / 'CHANGELOG.md').read_text(encoding='utf-8')
    match = re.search(r'^## \[' + re.escape(public) + r'\][^\n]*\n(.*?)(?=^## |\Z)', text, re.M | re.S)
    if not match or not match[1].strip():
        raise ValueError('CHANGELOG lacks this version release notes')
    return ('<!doctype html><html lang="zh-CN"><meta charset="utf-8">'
            f'<title>Lockora {html.escape(public)}</title><body><h1>Lockora {html.escape(public)}</h1>'
            '<pre style="white-space:pre-wrap;font:inherit">' + html.escape(match[1].strip()) + '</pre></body></html>').encode()


def publish_objects(store, public, files, feeds):
    validate_version(public + '+1')
    prefix = f'{PREFIX}/releases/{public}/'
    # Preflight every immutable object before creating or changing anything.
    for name, data in files.items():
        safe_member(name)
        old = store.get(prefix + name)
        if old is not None and old != data:
            raise ValueError(f'Immutable release object differs: {name}')
    for name, data in files.items():
        key = prefix + name
        if store.get(key) is None:
            store.put(key, data, immutable=True)
        if store.get(key) != data:
            raise ValueError(f'Uploaded object verification failed: {name}')
    for name, data in feeds.items():
        if name not in ('macos.xml', 'windows.xml'):
            raise ValueError('Unexpected stable feed')
        key = f'{PREFIX}/updates/stable/{name}'
        store.put(key, data)
        if store.get(key) != data:
            raise ValueError(f'Feed promotion verification failed: {name}; retry same candidate')


class OSSStore:
    def __init__(self):
        import oss2
        auth = (oss2.StsAuth(os.environ['OSS_ACCESS_KEY_ID'], os.environ['OSS_ACCESS_KEY_SECRET'],
                            os.environ['OSS_SECURITY_TOKEN']) if os.getenv('OSS_SECURITY_TOKEN') else
                oss2.Auth(os.environ['OSS_ACCESS_KEY_ID'], os.environ['OSS_ACCESS_KEY_SECRET']))
        self.bucket = oss2.Bucket(auth, 'https://oss-cn-hangzhou.aliyuncs.com', 'tbtparent-me')

    def get(self, key):
        import oss2
        try:
            return self.bucket.get_object(key).read()
        except oss2.exceptions.NoSuchKey:
            return None

    def put(self, key, data, immutable=False):
        headers = {'Cache-Control': 'public,max-age=31536000,immutable' if immutable else 'public,max-age=60,must-revalidate',
                   'Content-Type': 'application/rss+xml; charset=utf-8' if key.endswith('.xml') else
                                   'text/html; charset=utf-8' if key.endswith('.html') else 'application/octet-stream'}
        if immutable:
            headers['x-oss-forbid-overwrite'] = 'true'
        self.bucket.put_object(key, data, headers=headers)


def candidate(out, cfg, current):
    public = current.split('+')[0]
    files = {}
    feeds = {}
    for platform, suffix in [('macos', 'macos.zip'), ('windows', 'windows-setup.exe')]:
        name = f'Lockora-{public}-{suffix}'
        data = (out / name).read_bytes()
        signature = (out / (name + '.sig')).read_text(encoding='utf-8').strip()
        verify_signature(data, signature, cfg[platform + 'PublicKey'])
        if platform == 'macos':
            validate_zip(out / name)
            with zipfile.ZipFile(out / name) as z:
                info = plistlib.loads(z.read('Lockora.app/Contents/Info.plist'))
                if (info['CFBundleIdentifier'] != 'me.tbtparent.lockora' or
                    str(info['CFBundleVersion']) != current.split('+')[1] or
                    info['CFBundleShortVersionString'] != public or
                    info.get('SUPublicEDKey') != cfg['macosPublicKey']):
                    raise ValueError('macOS bundle identity/version/public key mismatch')
                embedded = z.read('Lockora.app/Contents/Frameworks/App.framework/Resources/flutter_assets/assets/files/password_manager_browser.zip')
                if embedded != (out / f'Lockora-{public}-browser.zip').read_bytes():
                    raise ValueError('macOS embedded extension differs from release extension')
                if 'Lockora.app/Contents/MacOS/Lockora' not in z.namelist():
                    raise ValueError('Missing Lockora executable')
        elif not data.startswith(b'MZ'):
            raise ValueError('Windows installer is not a PE executable')
        files[name] = data
        files[name + '.sig'] = (signature + '\n').encode()
        base = cfg['baseURL'].rstrip('/') + f'/releases/{public}/'
        feeds[platform + '.xml'] = appcast(platform, current, base + name, base + 'release-notes.html',
                                               len(data), signature, cfg['minimumMacOS' if platform == 'macos' else 'minimumWindows'])
    browser = f'Lockora-{public}-browser.zip'
    validate_zip(out / browser)
    browser_data = (out / browser).read_bytes()
    if browser_data != (ROOT / 'assets/files/password_manager_browser.zip').read_bytes():
        raise ValueError('Release extension differs from shipped source extension')
    with zipfile.ZipFile(out / browser) as z:
        manifest = json.loads(z.read('manifest.json'))
        if not isinstance(manifest, dict):
            raise ValueError('Invalid browser extension manifest')
        extension_version = manifest.get('version', '')
        if (not isinstance(extension_version, str) or
            not re.fullmatch(r'(0|[1-9]\d*)(?:\.(0|[1-9]\d*)){0,3}', extension_version) or
            any(int(part) > 65535 for part in extension_version.split('.')) or
            not any(int(part) for part in extension_version.split('.'))):
            raise ValueError('Invalid browser extension version')
        if manifest.get('manifest_version') != 3 or not manifest.get('name'):
            raise ValueError('Invalid browser extension manifest')
        referenced = list(manifest.get('icons', {}).values())
        background = manifest.get('background', {})
        if background.get('service_worker'):
            referenced.append(background['service_worker'])
        for script in manifest.get('content_scripts', []):
            referenced.extend(script.get('js', []))
            referenced.extend(script.get('css', []))
        action = manifest.get('action', {})
        if action.get('default_popup'):
            referenced.append(action['default_popup'])
        icons = action.get('default_icon', {})
        referenced.extend([icons] if isinstance(icons, str) else icons.values())
        for filename in referenced:
            safe_member(filename)
            if filename not in z.namelist() or z.getinfo(filename).is_dir():
                raise ValueError('Browser extension references a missing file')
    files[browser] = browser_data
    files['release-notes.html'] = notes(current)
    files['checksums.sha256'] = ''.join(f'{hashlib.sha256(data).hexdigest()}  {name}\n' for name, data in sorted(files.items())).encode()
    return files, feeds


def check_stable(store, current):
    for platform in ('macos', 'windows'):
        existing = store.get(f'{PREFIX}/updates/stable/{platform}.xml')
        if not existing:
            continue
        enc = ET.fromstring(existing).find('./channel/item/enclosure')
        short = enc.get(SP + 'shortVersionString')
        build = enc.get(SP + 'version').split('.')[-1]
        old = short + '+' + build
        if old != current:  # Identical version permits a recovery retry.
            validate_version(current, previous=old)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    sub = parser.add_subparsers(dest='command', required=True)
    validate = sub.add_parser('validate')
    validate.add_argument('--tag')
    validate.add_argument('--previous')
    sub.add_parser('configure')
    sign = sub.add_parser('sign')
    sign.add_argument('--platform', choices=('macos', 'windows'), required=True)
    sign.add_argument('--package', type=Path, required=True)
    for command in ('generate', 'publish'):
        cmd = sub.add_parser(command)
        cmd.add_argument('--directory', type=Path, required=True)
    args = parser.parse_args()
    current = version()
    cfg = config()
    if args.command == 'validate':
        validate_version(current, args.tag, args.previous)
        notes(current)
        print(current)
    elif args.command == 'configure':
        defines = {f'LOCKORA_{p.upper()}_{suffix}': cfg[p + field]
                   for p in ('macos', 'windows') for suffix, field in [('PUBLIC_KEY', 'PublicKey'), ('FEED_URL', 'FeedURL')]}
        (ROOT / 'build').mkdir(exist_ok=True)
        (ROOT / 'build/updates.json').write_text(json.dumps(defines, indent=2) + '\n', encoding='utf-8')
        (ROOT / 'macos/Flutter/ReleaseUpdates.xcconfig').write_text('LOCKORA_MACOS_PUBLIC_KEY = ' + cfg['macosPublicKey'] + '\n', encoding='utf-8')
    elif args.command == 'sign':
        from cryptography.hazmat.primitives.asymmetric.ed25519 import Ed25519PrivateKey
        from cryptography.hazmat.primitives import serialization
        raw = decode(os.environ[f'LOCKORA_{args.platform.upper()}_PRIVATE_KEY'], 64)
        key = Ed25519PrivateKey.from_private_bytes(raw[:32])
        public = key.public_key().public_bytes(serialization.Encoding.Raw, serialization.PublicFormat.Raw)
        if raw[32:] != public or public != decode(cfg[args.platform + 'PublicKey'], 32):
            raise ValueError('Signing key differs from configured public key')
        payload = args.package.read_bytes()
        signature = base64.b64encode(key.sign(payload)).decode()
        verify_signature(payload, signature, cfg[args.platform + 'PublicKey'])
        Path(str(args.package) + '.sig').write_text(signature + '\n', encoding='utf-8')
    else:
        files, feeds = candidate(args.directory, cfg, current)
        if args.command == 'generate':
            for name, data in {**files, **feeds}.items():
                (args.directory / name).write_bytes(data)
        else:
            store = OSSStore()
            check_stable(store, current)
            publish_objects(store, current.split('+')[0], files, feeds)
            print('Both stable feeds verified after promotion')


if __name__ == '__main__':
    try:
        main()
    except (ValueError, KeyError, OSError) as error:
        sys.exit('Release failed: ' + str(error))
