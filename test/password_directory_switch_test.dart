import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:password_manager/models/password_entry.dart';
import 'package:password_manager/services/local_password_store.dart';
import 'package:password_manager/services/secure_storage_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
    await target.writePasswords(remote);
    await service.useExistingPasswordDirectory(target.directory.path);
    expect(await service.loadPasswords(), remote);
    expect(
        await LocalPasswordStore(directory: Directory('${root.path}/local'))
            .readPasswords(),
        records);
  });

  test(
      'rejects a corrupt existing library without restoring over its primary file',
      () async {
    final target =
        LocalPasswordStore(directory: Directory('${root.path}/shared'));
    await target.writePasswords(records);
    await target.passwordFile.writeAsString('{broken');
    await expectLater(
        service.useExistingPasswordDirectory(target.directory.path),
        throwsA(isA<PasswordStoreException>()));
    expect(await target.passwordFile.readAsString(), '{broken');
    expect(await service.getPasswordDataLocation(), '${root.path}/local');
  });
}
