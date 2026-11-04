@Timeout(Duration(minutes: 2))
library;

import 'dart:convert';
import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:password_manager/models/password_entry.dart';
import 'package:password_manager/services/local_password_store.dart';
import 'package:password_manager/services/secure_storage_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'support/faulting_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory root;
  final service = SecureStorageService.instance;
  final records = [
    jsonEncode(
        PasswordEntry(title: 'Cloud', username: 'alice', password: 'secret')
            .toJson())
  ];
  setUp(() async {
    root = await Directory.systemTemp.createTemp('pm_directory_');
    debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
    SharedPreferences.setMockInitialValues({
      'desktop_password_data_directory': '${root.path}/local',
      'mac_legacy_data_restore_checked': true,
    });
    await service.initialize();
    await service.unlockDesktopVault('test-master');
    await service.savePasswords(records);
  });
  tearDown(() async {
    debugDefaultTargetPlatformOverride = null;
    await root.delete(recursive: true);
  });

  test('migrates macOS library and retains location after restart', () async {
    final path =
        await service.changePasswordDataRoot('${root.path}/iCloud Drive');
    expect(path, '${root.path}/iCloud Drive/PasswordManager');
    await service.initialize();
    await service.unlockDesktopVault('test-master');
    expect(await service.getPasswordDataLocation(), path);
    expect(await service.loadPasswords(), records);
    expect(await File('${root.path}/local/passwords.json').exists(), isTrue);
  });

  test('opens an existing library without merging or overwriting either side',
      () async {
    final target =
        LocalPasswordStore(directory: Directory('${root.path}/shared'));
    final remote = [
      jsonEncode(
          PasswordEntry(title: 'Remote', username: 'bob', password: 'other')
              .toJson())
    ];
    await target.unlock('test-master');
    await target.writePasswords(remote);
    await service.useExistingPasswordDirectory(target.directory.path);
    expect(await service.loadPasswords(), remote);
    final source =
        LocalPasswordStore(directory: Directory('${root.path}/local'));
    await source.unlock('test-master');
    expect(await source.readPasswords(), records);
  });

  test(
      'rejects a corrupt existing library without restoring over its primary file',
      () async {
    final target =
        LocalPasswordStore(directory: Directory('${root.path}/shared'));
    await target.unlock('test-master');
    await target.writePasswords(records);
    await target.passwordFile.writeAsString('{broken');
    await expectLater(
        service.useExistingPasswordDirectory(target.directory.path),
        throwsA(isA<PasswordStoreException>()));
    expect(await target.passwordFile.readAsString(), '{broken');
    expect(await service.getPasswordDataLocation(), '${root.path}/local');
  });
  test('different-password target leaves current path and both vaults intact',
      () async {
    final target =
        LocalPasswordStore(directory: Directory('${root.path}/different'));
    await target.unlock('other-master', initialPasswords: records);
    final originalTarget = await target.passwordFile.readAsString();
    final currentPath = await service.getPasswordDataLocation();
    await expectLater(
        service.useExistingPasswordDirectory(target.directory.path),
        throwsA(isA<PasswordStoreException>()));
    expect(await service.getPasswordDataLocation(), currentPath);
    expect(await service.loadPasswords(), records);
    expect(await target.passwordFile.readAsString(), originalTarget);
  });
  test('lock while validating target cannot activate an unlocked library',
      () async {
    final target =
        LocalPasswordStore(directory: Directory('${root.path}/shared'));
    await target.unlock('test-master', initialPasswords: records);
    final currentPath = await service.getPasswordDataLocation();
    final switching =
        service.useExistingPasswordDirectory(target.directory.path);
    service.lockDesktopVault();
    await expectLater(switching, throwsA(isA<PasswordStoreException>()));
    expect(await service.getPasswordDataLocation(), currentPath);
    await expectLater(
        service.loadPasswords(), throwsA(isA<PasswordStoreException>()));
  });
  test(
      'save during migration activation is retained in the active target vault',
      () async {
    final fault = FaultingPreferences(await SharedPreferences.getInstance())
      ..activationStarted = Completer<void>()
      ..continueActivation = Completer<void>();
    fault.install();
    final migrating = service.changePasswordDataRoot('${root.path}/cloud');
    await fault.activationStarted!.future;
    final updated = [
      ...records,
      jsonEncode(PasswordEntry(
              title: 'Saved during move', username: 'bob', password: 'retained')
          .toJson())
    ];
    final saving = service.savePasswords(updated, expectedPasswords: records);
    // Give a source-store write time to complete if it bypasses migration.
    await Future<void>.delayed(const Duration(milliseconds: 100));
    fault.continueActivation!.complete();
    await migrating;
    await saving;
    expect(await service.loadPasswords(), updated);
  });
  test(
      'queued save without an expected snapshot cannot overwrite a different selected vault',
      () async {
    final target =
        LocalPasswordStore(directory: Directory('${root.path}/other'));
    final remote = [
      jsonEncode(PasswordEntry(
              title: 'Different vault',
              username: 'remote',
              password: 'remote-secret')
          .toJson())
    ];
    await target.unlock('test-master', initialPasswords: remote);
    final fault = FaultingPreferences(await SharedPreferences.getInstance())
      ..activationStarted = Completer<void>()
      ..continueActivation = Completer<void>();
    fault.install();
    final switching =
        service.useExistingPasswordDirectory(target.directory.path);
    await fault.activationStarted!.future;
    final saving = service.savePasswords(records);
    await Future<void>.delayed(const Duration(milliseconds: 100));
    fault.continueActivation!.complete();
    await switching;
    await expectLater(saving, throwsA(isA<PasswordStoreException>()));
    expect(await service.loadPasswords(), remote);
  });
  test('queued service saves preserve the original implicit read snapshot',
      () async {
    final changed = [
      jsonEncode(PasswordEntry(
              title: 'First saved edit',
              username: 'alice',
              password: 'new-secret')
          .toJson())
    ];
    final results = await Future.wait([
      service.savePasswords(changed).then((_) => true).catchError((_) => false),
      service.savePasswords(records).then((_) => true).catchError((_) => false),
    ]);
    expect(results, [true, false]);
    expect(await service.loadPasswords(), changed);
  });
  test(
      'same-tick save lock and unlock cannot carry an old save into the new session',
      () async {
    final changed = [
      jsonEncode(PasswordEntry(
              title: 'Stale session edit',
              username: 'alice',
              password: 'must-not-save')
          .toJson())
    ];
    final saving = service
        .savePasswords(changed, expectedPasswords: records)
        .then((_) => true)
        .catchError((_) => false);
    service.lockDesktopVault();
    await service.unlockDesktopVault('test-master');
    expect(await saving, isFalse);
    expect(await service.loadPasswords(), records);
  });
}
