# Desktop encryption implementation plan

1. Add failing storage/auth integration tests against the existing APIs; verify the plaintext baseline fails confidentiality and locked-session requirements.
2. Add VaultCrypto and locked LocalPasswordStore v2 persistence, authenticated migration, conflict checks and primary-last password rotation. Verify storage crypto and failure tests.
3. Integrate desktop session unlock/lock/rotation, legacy preference cleanup and authenticated directory switching. Make vault presence authoritative during login with missing preferences. Preserve mobile/web behavior.
4. Update existing test fixtures to explicitly unlock their temporary stores. Run affected tests and the full Flutter suite, then inspect changes for plaintext fallbacks and report limitations.

No user data, release keys, version files, or unrelated directories are modified.
