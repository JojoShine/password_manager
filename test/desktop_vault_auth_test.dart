@Timeout(Duration(minutes: 2))
library;

import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:password_manager/models/app_settings.dart';
import 'package:password_manager/services/auth_service.dart';
import 'package:password_manager/services/secure_storage_service.dart';
import 'package:password_manager/services/local_password_store.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'support/faulting_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory directory;
  final storage = SecureStorageService.instance;
  final auth = AuthService.instance;
  setUp(() async {
    directory = await Directory.systemTemp.createTemp('vault_auth_');
    debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
    SharedPreferences.setMockInitialValues(
        {'desktop_password_data_directory': directory.path});
    await storage.initialize();
    await auth.initialize();
  });
  tearDown(() async {
    await auth.lockApp();
    debugDefaultTargetPlatformOverride = null;
    await directory.delete(recursive: true);
  });

  test('new vault replaces fast verifier and locked disk operations fail',
      () async {
    await auth.setMasterPassword('master', 'master');
    expect((await auth.getCurrentSettings()).masterPasswordHash,
        AuthService.desktopVaultMarker);
    await auth.lockApp();
    await expectLater(
        storage.loadPasswords(), throwsA(isA<PasswordStoreException>()));
    expect(await auth.verifyMasterPassword('wrong'), isFalse);
    expect(await auth.verifyMasterPassword('master'), isTrue);
  });
  test(
      'encrypted vault authenticates without settings and ignores stale SHA verifier',
      () async {
    await auth.setMasterPassword('real-master', 'real-master');
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('app_settings');
    await auth.initialize();
    expect(await auth.isFirstLaunch(), isFalse);
    expect(await auth.hasMasterPassword(), isTrue);
    expect(await auth.verifyMasterPassword('real-master'), isTrue);
    await prefs.setString(
        'app_settings',
        jsonEncode(AppSettings(
                masterPasswordHash: sha256
                    .convert(utf8.encode('wrongpassword_manager_salt'))
                    .toString(),
                isFirstLaunch: false)
            .toMap()));
    await auth.initialize();
    expect(await auth.verifyMasterPassword('wrong'), isFalse);
    expect(await auth.verifyMasterPassword('real-master'), isTrue);
  });
  test(
      'legacy SHA must verify before plaintext migration and preferences cleanup',
      () async {
    final prefs = await SharedPreferences.getInstance();
    final records = [
      jsonEncode({'id': 3, 'password': 'old-secret'})
    ];
    await prefs.setStringList('saved_passwords', records);
    await prefs.setStringList('saved_passwords_backup', records);
    await prefs.setString(
        'app_settings',
        jsonEncode(AppSettings(
                masterPasswordHash: sha256
                    .convert(utf8.encode('masterpassword_manager_salt'))
                    .toString(),
                isFirstLaunch: false)
            .toMap()));
    await auth.initialize();
    expect(await auth.verifyMasterPassword('wrong'), isFalse);
    expect(await File('${directory.path}/passwords.json').exists(), isFalse);
    expect(prefs.getStringList('saved_passwords'), records);
    expect(await auth.verifyMasterPassword('master'), isTrue);
    expect(await storage.loadPasswords(), records);
    expect(prefs.containsKey('saved_passwords'), isFalse);
    expect(prefs.containsKey('saved_passwords_backup'), isFalse);
    expect((await auth.getCurrentSettings()).masterPasswordHash,
        AuthService.desktopVaultMarker);
  });
  test('clear records keeps same master password and restart remains locked',
      () async {
    await auth.setMasterPassword('master', 'master');
    await storage.savePasswords([
      jsonEncode({'password': 'delete-me'})
    ]);
    await storage.clearPasswords();
    await auth.initialize();
    expect(await auth.verifyMasterPassword('wrong'), isFalse);
    expect(await auth.verifyMasterPassword('master'), isTrue);
    expect(await storage.loadPasswords(), isEmpty);
  });
  test('rotation ignores stale old settings after restart', () async {
    await auth.setMasterPassword('old', 'old');
    final prefs = await SharedPreferences.getInstance();
    final oldSettings = prefs.getString('app_settings')!;
    await auth.changeMasterPassword('old', 'new', 'new');
    await prefs.setString('app_settings', oldSettings);
    await auth.initialize();
    expect(await auth.verifyMasterPassword('old'), isFalse);
    expect(await auth.verifyMasterPassword('new'), isTrue);
  });
  test('lock during unlock does not restore a live session', () async {
    await auth.setMasterPassword('master', 'master');
    await auth.lockApp();
    final unlocking = auth.verifyMasterPassword('master');
    await auth.lockApp();
    expect(await unlocking, isFalse);
    expect(auth.isSessionUnlocked, isFalse);
    await expectLater(
        storage.loadPasswords(), throwsA(isA<PasswordStoreException>()));
  });
  for (final blockedStage in ['temporary', 'backup']) {
    test(
        'correct legacy password with $blockedStage write failure preserves attempts',
        () async {
      final prefs = await SharedPreferences.getInstance();
      final legacy = jsonEncode({
        'version': 1,
        'passwords': [
          {'id': 1, 'password': 'kept-secret'}
        ]
      });
      final main = File('${directory.path}/passwords.json');
      await main.writeAsString(legacy);
      await prefs.setString(
          'app_settings',
          jsonEncode(AppSettings(
                  masterPasswordHash: sha256
                      .convert(utf8.encode('masterpassword_manager_salt'))
                      .toString(),
                  isFirstLaunch: false)
              .toMap()));
      await auth.initialize();
      final blockedPath = blockedStage == 'temporary'
          ? 'passwords.json.tmp'
          : 'passwords.backup.json';
      await Directory('${directory.path}/$blockedPath').create();
      await expectLater(auth.verifyMasterPassword('master'),
          throwsA(isA<PasswordStoreException>()));
      expect(auth.getFailedAttemptInfo()['failedAttempts'], 0);
      expect(auth.isSessionUnlocked, isFalse);
      expect(await main.readAsString(), legacy);
      await expectLater(
          storage.loadPasswords(), throwsA(isA<PasswordStoreException>()));
    });
  }
  test(
      'correct encrypted password with cleanup failure reports error without consuming attempts',
      () async {
    await auth.setMasterPassword('master', 'master');
    await auth.lockApp();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('saved_passwords', [
      jsonEncode({'password': 'legacy-copy'})
    ]);
    final fault = FaultingPreferences(prefs)..failLegacyRemoval = true;
    fault.install();
    final primary = File('${directory.path}/passwords.json');
    final before = await primary.readAsString();
    await expectLater(auth.verifyMasterPassword('master'),
        throwsA(isA<PasswordStoreException>()));
    expect(auth.getFailedAttemptInfo()['failedAttempts'], 0);
    expect(auth.isSessionUnlocked, isFalse);
    expect(await primary.readAsString(), before);
    await expectLater(
        storage.loadPasswords(), throwsA(isA<PasswordStoreException>()));
  });
  test(
      'missing encrypted primary with marker reports recovery rather than password failure',
      () async {
    await auth.setMasterPassword('master', 'master');
    await auth.lockApp();
    await File('${directory.path}/passwords.json').delete();
    await expectLater(auth.verifyMasterPassword('master'),
        throwsA(isA<PasswordStoreException>()));
    expect(auth.getFailedAttemptInfo()['failedAttempts'], 0);
    expect(await File('${directory.path}/passwords.json').exists(), isFalse);
  });
}
