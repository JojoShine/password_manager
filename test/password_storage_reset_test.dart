import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:password_manager/services/local_password_store.dart';
import 'package:password_manager/services/secure_storage_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('reset removes password data but preserves app settings', () async {
    final directory = await Directory.systemTemp.createTemp('pm_reset_');
    addTearDown(() async {
      if (await directory.exists()) await directory.delete(recursive: true);
    });
    final store = LocalPasswordStore(directory: directory);
    await store.writePasswords([
      jsonEncode({'id': 1})
    ]);
    SharedPreferences.setMockInitialValues({
      'saved_passwords': [
        jsonEncode({'id': 1})
      ],
      'app_settings': 'keep',
      'app_title': 'keep',
    });

    await SecureStorageService.instance.clearPasswordsForTesting(store);

    final prefs = await SharedPreferences.getInstance();
    expect(await store.passwordFile.exists(), isFalse);
    expect(prefs.containsKey('saved_passwords'), isFalse);
    expect(prefs.getString('app_settings'), 'keep');
    expect(prefs.getString('app_title'), 'keep');
  });

  test('restores old macOS passwords and settings without deleting the source',
      () async {
    final directory = await Directory.systemTemp.createTemp('pm_restore_');
    addTearDown(() async {
      if (await directory.exists()) await directory.delete(recursive: true);
    });
    final store = LocalPasswordStore(directory: directory);
    final legacyPasswords = [
      jsonEncode({'id': 9, 'title': 'Old data'})
    ];
    final reader = _FakeLegacyPreferencesReader({
      'saved_passwords': legacyPasswords,
      'app_settings': 'old-app-settings',
      'lock_timeout_minutes': 45,
    });
    SharedPreferences.setMockInitialValues({});

    await SecureStorageService.instance.restoreLegacyMacDataForTesting(
      store,
      reader,
    );

    expect(await store.readPasswords(), legacyPasswords);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('app_settings'), 'old-app-settings');
    expect(prefs.getInt('lock_timeout_minutes'), 45);
    expect(reader.readCount, 1);
  });
}

class _FakeLegacyPreferencesReader implements LegacyPreferencesReader {
  final Map<String, Object> values;
  int readCount = 0;

  _FakeLegacyPreferencesReader(this.values);

  @override
  Future<Map<String, Object>> readSupportedPreferences() async {
    readCount++;
    return values;
  }
}
