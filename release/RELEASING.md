# Lockora release procedure

The desktop version comes from `pubspec.yaml`; the matching changelog section is required. Both semantic version and numeric build must increase relative to both existing stable feeds. Tags use `v3.1.0`. A tag or default manual run produces a signed candidate only. Dispatch with `publish=true` explicitly promotes a successful candidate. Both platforms and Flutter/release-tool tests must pass first.

`release/config.json` contains public material only. Provision permanent, independently generated Ed25519 keys before the first candidate. Public keys are base64 raw 32-byte keys. GitHub secrets `LOCKORA_MACOS_PRIVATE_KEY` and `LOCKORA_WINDOWS_PRIVATE_KEY` contain base64 of the 64 bytes `seed || publicKey`. The release tool derives and checks the public half before signing, then verifies the signature over the complete final archive bytes. These raw Ed25519 signatures match Sparkle 2.9.6 and WinSparkle 0.9.4. Never log, commit, upload, or pass private keys as command arguments. Keep offline secure backups; replacing keys in a later client requires an explicit framework-supported rotation plan.

Install Python 3.12+ and `pip install -r tools/requirements-release.txt` in a virtual environment. Commands from repository root:

```sh
python tools/release.py validate --tag v3.1.0 --previous 3.0.0+4
python tools/release.py configure
flutter build macos --release --dart-define-from-file=build/updates.json
# On macOS, archive Lockora.app with ditto -c -k --sequesterRsrc --keepParent.
python tools/release.py sign --platform macos --package dist/Lockora-3.1.0-macos.zip
# On Windows, build windows, compile windows/installer/Lockora.iss, then sign:
python tools/release.py sign --platform windows --package dist/Lockora-3.1.0-windows-setup.exe
python tools/release.py generate --directory dist
python tools/release.py publish --directory dist
```

Configure writes public Dart defines to `build/updates.json` and `macos/Flutter/ReleaseUpdates.xcconfig`. Extension versions evolve independently of desktop versions. The release ZIP must exactly match the shipped source ZIP and the copy embedded in macOS. Copy the bundled extension into `dist/Lockora-3.1.0-browser.zip` before generation. Directory must contain both final packages and their `.sig` sidecars. Generating checks exact signatures, macOS identity/version/key, ZIP paths and symlinks, extension manifest/files and Windows installer format. macOS CI verifies universal arm64/x86_64 executable architecture before archiving; Windows CI validates runtime dependencies before compiling the complete runtime into the installer.

OSS publication accepts `OSS_ACCESS_KEY_ID`, `OSS_ACCESS_KEY_SECRET`, and optional `OSS_SECURITY_TOKEN` from the environment. GitHub uses the same secret names. Scope the identity to `Download/lockora/` in bucket `tbtparent-me`; permit reads/writes but avoid delete permissions. No additional GitHub approval environment is assumed. Store credentials using GitHub's secure secret input or existing local credential storage, never this document.

Publication checks both current feeds to prevent downgrade, preflights immutable conflicts, uploads release files with OSS overwrite protection, downloads each object to compare exact bytes, and only then promotes `macos.xml` and `windows.xml`. Already existing identical objects are reused. Different bytes under an existing version fail: build a higher version instead. Release objects have year-long immutable cache headers; feeds revalidate after 60 seconds. Feed promotion is sequential, not an OSS transaction. If the second promotion fails, the first platform can already see the new release; retry the **same signed candidate** to complete promotion. Packages and earlier versions remain available for manual repair. Never delete preferences, password files or iCloud folders to recover an installation.

Platform code signing is separate from Ed25519 update signing. This workflow records that Developer ID/notarization and Authenticode are not configured; it does not buy or require new certificates. Native embedded framework signatures still require platform inspection. Before claiming end-to-end update support, test an actual signed update install/restart on each OS using independent test keys/feed, including rejection of corrupted packages and cancellation; automated build/signature checks do not prove these runtime behaviors.

References: [Sparkle signing](https://sparkle-project.org/documentation/), [WinSparkle publishing](https://winsparkle.org/guides/publishing-updates/), [WinSparkle 0.9.4 signature verification source](https://github.com/vslavik/winsparkle/blob/v0.9.4/src/signatureverifier.cpp).
