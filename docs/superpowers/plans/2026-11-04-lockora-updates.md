# Lockora Rename and Desktop Updates Implementation Plan

> **For agentic workers:** Use the executing-plans workflow for integration and the dispatching-parallel-agents workflow for independent file scopes. The user explicitly requested implementation, GitHub push, and versioned OSS publication; proceed without another design approval.

**Goal:** Ship Lockora 3.1.0+5, identity me.tbtparent.lockora, preserving existing libraries and adding signed native desktop updates with versioned OSS releases.
**Architecture:** A small Flutter update service bridges Sparkle 2.9.6 (maintains macOS 10.15 compatibility) and WinSparkle 0.9.4. Native frameworks own update UI and installation. Startup migration precedes all SharedPreferences consumers. Release automation creates signed immutable packages before promoting HTTPS appcasts.
**Tech Stack:** Flutter 3.41.9, Swift/Sparkle, C++/WinSparkle, Inno Setup, Python release tooling, GitHub Actions, Alibaba OSS.
**Spec:** ../specs/2026-11-04-lockora-updates-design.md

## Global Constraints
- Release 3.1.0+5; application ID me.tbtparent.lockora; keep old data files and settings as migration sources.
- HTTPS feeds: https://tbtparent-me.oss-cn-hangzhou.aliyuncs.com/Download/lockora/updates/stable/{macos,windows}.xml.
- No credentials in source/logs; Ed25519 mandatory; do not promote missing or unverified artifacts.
- Preserve prior work. Work on a release branch in the current workspace because the uncommitted earlier fixes must ship together.

## Review Focus
- A changed bundle/product identity must not turn an existing user into an empty first-run library.
- User edits and active writes must prevent updater shutdown; cancellation must leave the current app usable.
- Invalid signatures, offline feeds, and same/older builds must not trigger installation.
- Windows packages must contain every runtime dependency and upgrade one stable per-user installation.
- A partial upload/build failure must not publish feeds referencing absent files.

### Task 1: Lockora identity and preference migration
Files: Dart startup/migration and branding, macOS product configuration, Windows resource identity, extension branding and bundled ZIP, migration/settings tests.
Interfaces: startup calls `LegacySettingsMigration.migrate()` before any SharedPreferences consumer; macOS channel `me.tbtparent.lockora/migration`, method `migrate`, returns true or throws. Windows migration copies verified legacy JSON without replacing valid target settings.
- [x] Write/run failing migration and default-title tests; implement migration, rename and version changes; run targeted tests.
- [x] Preserve all old vault/custom paths and old preference files; update affected version/name expectations.

### Task 2: Native update integration and Flutter UI
Files: native runner update bridges/build dependencies, `lib/services/app_update_service.dart`, `lib/widgets/app_update_section.dart`, app startup/settings and route/write guards, update-service tests.
Interfaces: channel `me.tbtparent.lockora/updater`; `configure`({feedURL,publicKey,automaticChecks}), `checkForUpdates`({background}), `setAutomaticChecks`({enabled}), `setCanInstall`({allowed}). Native calls Dart `prepareInstall`, returns bool only after locking/stopping server. Event `updateStatus` carries `{status,message?}`. Framework native UI owns version details/download progress.
- [x] Write/run failing service/configuration/guard tests; implement native bridge, UI, automatic-check preference and shutdown guard.
- [x] Pin verified framework versions, enforce production public-key configuration, compile macOS; Windows compile in Actions.

### Task 3: Signed versioned release pipeline
Files: `tools/release.py`, Python tests, `windows/installer/Lockora.iss`, Actions workflows and release documentation.
Interfaces: release tool validates pubspec/tag, generates platform appcasts from exact signed artifacts and changelog, uploads immutable version objects, verifies them, then promotes feeds. Native bridge reads public keys from platform build configuration generated from public checked-in release config.
- [x] Write/run failing version/feed/path/upload-order tests; implement signing/package/OSS workflows and per-user installer.
- [x] Read existing service configuration safely; provision update keys securely if needed; never expose values in output.

### Task 4: Integrate, verify, push and publish
- [ ] Whole-suite Flutter/extension/Python tests; native macOS build; independent final review and important fixes.
- [ ] Commit only task-related changes, push release branch/merge through existing policy, create v3.1.0 release tag and run both platform builds.
- [ ] Inspect successful Windows/macOS artifacts; verify signed package identities; upload to immutable OSS version prefix and publish appcasts last.
- [ ] Verify public HTTPS objects, package checksums/signatures and feed versions. Report real URLs and any unavailable signing/permission/runtime validation honestly.

User clarification: OSS credentials stay local for this publication; use the already authenticated OSS web console. Do not copy OSS credentials to GitHub. Download prefix is lowercase `Download/lockora/`.
