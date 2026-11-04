import base64
import tempfile
import unittest
from unittest.mock import patch
import json
import plistlib
import zipfile
from pathlib import Path
import sys
sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
import release
from cryptography.hazmat.primitives.asymmetric.ed25519 import Ed25519PrivateKey
from cryptography.hazmat.primitives import serialization


class Store:
    def __init__(self, fail=None):
        self.objects = {}
        self.writes = []
        self.fail = fail

    def get(self, key):
        return self.objects.get(key)

    def put(self, key, data, immutable=False):
        if self.fail and self.fail in key:
            raise RuntimeError('simulated upload failure')
        if immutable and key in self.objects and self.objects[key] != data:
            raise ValueError('immutable conflict')
        self.writes.append(key)
        self.objects[key] = data


class ReleaseTests(unittest.TestCase):
    def test_versions_require_both_components_increase(self):
        release.validate_version('3.1.0+5', 'v3.1.0', '3.0.0+4')
        for current, tag, previous in [('3.1.0+5', 'v3.0.0', None),
                                      ('3.1.0+4', 'v3.1.0', '3.0.0+4'),
                                      ('3.0.0+6', None, '3.1.0+5'),
                                      ('3.01.0+5', None, None)]:
            with self.assertRaises(ValueError):
                release.validate_version(current, tag, previous)

    def test_signature_is_verified_against_exact_payload(self):
        private = Ed25519PrivateKey.generate()
        public = base64.b64encode(private.public_key().public_bytes(
            serialization.Encoding.Raw, serialization.PublicFormat.Raw)).decode()
        signature = base64.b64encode(private.sign(b'package')).decode()
        release.verify_signature(b'package', signature, public)
        for payload, sig in [(b'corrupt', signature), (b'package', ''),
                             (b'package', base64.b64encode(b'x' * 64).decode())]:
            with self.assertRaises(ValueError):
                release.verify_signature(payload, sig, public)

    def test_feed_escapes_values_and_platform_version(self):
        import xml.etree.ElementTree as ET
        for platform, expected in [('macos', '5'), ('windows', '3.1.0.5')]:
            xml = release.appcast(platform, '3.1.0+5', 'https://host/file?a=1&b=2',
                                  'https://host/notes', 42, 'a"b&c', '10.15')
            enclosure = ET.fromstring(xml).find('./channel/item/enclosure')
            self.assertEqual(enclosure.get(release.SP + 'version'), expected)
            self.assertEqual(enclosure.get('url'), 'https://host/file?a=1&b=2')
            self.assertEqual(enclosure.get(release.SP + 'edSignature'), 'a"b&c')

    def test_zip_path_safety(self):
        for path in ['../outside', '/absolute', 'Lockora.app/../../outside', 'C:/evil', 'safe\\..\\evil']:
            with self.subTest(path=path), tempfile.TemporaryDirectory() as d:
                archive = Path(d) / 'test.zip'
                with zipfile.ZipFile(archive, 'w') as z:
                    z.writestr(path, 'bad')
                with self.assertRaises(ValueError):
                    release.validate_zip(archive)

    def test_publish_verifies_every_artifact_before_feeds(self):
        store = Store()
        files = {'a.zip': b'a', 'b.exe': b'b', 'notes.html': b'notes'}
        feeds = {'macos.xml': b'mac', 'windows.xml': b'win'}
        release.publish_objects(store, '3.1.0', files, feeds)
        self.assertTrue(all('/updates/' in k for k in store.writes[-2:]))
        store.writes.clear()
        release.publish_objects(store, '3.1.0', files, feeds)
        self.assertEqual(len(store.writes), 2)
        with self.assertRaises(ValueError):
            release.publish_objects(store, '3.1.0', {'a.zip': b'changed'}, feeds)

    def test_upload_failure_does_not_promote_any_feed(self):
        store = Store(fail='b.exe')
        with self.assertRaises(RuntimeError):
            release.publish_objects(store, '3.1.0', {'a.zip': b'a', 'b.exe': b'b'},
                                    {'macos.xml': b'm', 'windows.xml': b'w'})
        self.assertFalse(any('/updates/' in key for key in store.writes))

    def test_remote_corruption_never_promotes_feeds(self):
        class CorruptStore(Store):
            def put(self, key, data, immutable=False):
                super().put(key, data + b'corrupt' if immutable else data, immutable)
        store = CorruptStore()
        with self.assertRaises(ValueError):
            release.publish_objects(store, '3.1.0', {'a.zip': b'a'},
                                    {'macos.xml': b'm', 'windows.xml': b'w'})
        self.assertFalse(any('/updates/' in key for key in store.writes))

    def test_stable_feed_blocks_downgrades_but_accepts_same_retry(self):
        store = Store()
        store.objects['Download/lockora/updates/stable/macos.xml'] = release.appcast(
            'macos', '3.1.0+5', 'https://host/pkg', 'https://host/notes', 2, 'sig', '10.15')
        release.check_stable(store, '3.1.0+5')
        release.check_stable(store, '3.2.0+6')
        with self.assertRaises(ValueError):
            release.check_stable(store, '3.0.0+6')
        with self.assertRaises(ValueError):
            release.check_stable(store, '3.2.0+4')

    def test_candidate_checks_bundle_identity_and_embedded_extension(self):
        with tempfile.TemporaryDirectory() as d:
            out = Path(d)
            private = Ed25519PrivateKey.generate()
            public = base64.b64encode(private.public_key().public_bytes(
                serialization.Encoding.Raw, serialization.PublicFormat.Raw)).decode()
            cfg = {'baseURL': 'https://host/Download/lockora',
                   'macosPublicKey': public, 'windowsPublicKey': public,
                   'minimumMacOS': '10.15', 'minimumWindows': '10.0'}
            browser = out / 'Lockora-3.1.1-browser.zip'
            with zipfile.ZipFile(browser, 'w') as z:
                z.writestr('manifest.json', json.dumps({'manifest_version': 3, 'name': 'Lockora', 'version': '3.1.0'}))
            mac = out / 'Lockora-3.1.1-macos.zip'
            win = out / 'Lockora-3.1.1-windows-setup.exe'
            win.write_bytes(b'MZtest executable')
            info = {'CFBundleIdentifier': 'me.tbtparent.lockora', 'CFBundleVersion': '6',
                    'CFBundleShortVersionString': '3.1.1', 'SUPublicEDKey': public}
            def make_mac():
                with zipfile.ZipFile(mac, 'w') as z:
                    z.writestr('Lockora.app/Contents/Info.plist', plistlib.dumps(info))
                    z.writestr('Lockora.app/Contents/MacOS/Lockora', b'executable')
                    z.writestr('Lockora.app/Contents/Frameworks/App.framework/Resources/flutter_assets/assets/files/password_manager_browser.zip', browser.read_bytes())
                for path in (mac, win):
                    Path(str(path) + '.sig').write_text(base64.b64encode(private.sign(path.read_bytes())).decode())
            source = out / 'assets/files/password_manager_browser.zip'
            source.parent.mkdir(parents=True)
            source.write_bytes(browser.read_bytes())
            make_mac()
            with patch.object(release, 'ROOT', out), patch.object(release, 'notes', return_value=b'<html>notes</html>'):
                files, feeds = release.candidate(out, cfg, '3.1.1+6')
                self.assertIn('checksums.sha256', files)
                self.assertEqual(set(feeds), {'macos.xml', 'windows.xml'})
                # A candidate must be the exact extension shipped in the source tree.
                source.write_bytes(b'different shipped extension')
                with self.assertRaises(ValueError):
                    release.candidate(out, cfg, '3.1.1+6')
                source.write_bytes(browser.read_bytes())
                valid_browser = browser.read_bytes()
                for manifest in [
                    {'manifest_version': 3, 'name': 'Lockora', 'version': 'not-a-version'},
                    {'manifest_version': 3, 'name': 'Lockora', 'version': '3.1.0',
                     'background': {'service_worker': 'missing.js'}},
                ]:
                    with zipfile.ZipFile(browser, 'w') as z:
                        z.writestr('manifest.json', json.dumps(manifest))
                    source.write_bytes(browser.read_bytes())
                    make_mac()
                    with self.subTest(manifest=manifest), self.assertRaises(ValueError):
                        release.candidate(out, cfg, '3.1.1+6')
                browser.write_bytes(valid_browser)
                source.write_bytes(valid_browser)
                info['CFBundleIdentifier'] = 'wrong.identity'
                make_mac()
                with self.assertRaises(ValueError):
                    release.candidate(out, cfg, '3.1.1+6')

    def test_partial_feed_promotion_can_be_retried(self):
        store = Store(fail='windows.xml')
        files = {'a.zip': b'a'}
        feeds = {'macos.xml': b'm', 'windows.xml': b'w'}
        with self.assertRaises(RuntimeError):
            release.publish_objects(store, '3.1.0', files, feeds)
        store.fail = None
        release.publish_objects(store, '3.1.0', files, feeds)
        self.assertEqual(store.objects['Download/lockora/updates/stable/windows.xml'], b'w')


if __name__ == '__main__':
    unittest.main()
