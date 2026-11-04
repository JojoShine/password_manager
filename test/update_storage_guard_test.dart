import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:password_manager/models/password_entry.dart';
import 'package:password_manager/services/app_update_service.dart';
import 'package:password_manager/services/local_password_store.dart';
import 'package:password_manager/services/secure_storage_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final updates = AppUpdateService.instance;
  const channel = MethodChannel('me.tbtparent.lockora/updater');
  late Directory root;
  setUp(() async {
    root = await Directory.systemTemp.createTemp('lockora_guard_');
    debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
    SharedPreferences.setMockInitialValues(
        {'desktop_password_data_directory': '${root.path}/local'});
    await SecureStorageService.instance.initialize();
    await SecureStorageService.instance.savePasswords([
      jsonEncode(
          PasswordEntry(title: 'Test', username: 'alice', password: 'secret')
              .toJson())
    ]);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (_) async => true);
    await updates.initialize(
        config: AppUpdateConfig(
            feedURL: 'https://updates.example/feed.xml',
            publicKey: base64Encode(List.filled(32, 1))),
        preferences: await SharedPreferences.getInstance(),
        prepareInstall: () async => true);
  });
  tearDown(() async {
    await updates.initialize(
        config: const AppUpdateConfig(feedURL: '', publicKey: ''),
        preferences: await SharedPreferences.getInstance(),
        prepareInstall: () async => true);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
    debugDefaultTargetPlatformOverride = null;
    await root.delete(recursive: true);
  });

  test('directory migration blocks install from its start through path commit',
      () async {
    final changing = SecureStorageService.instance
        .changePasswordDataRoot('${root.path}/cloud');
    expect(updates.canInstall, isFalse);
    await changing;
    expect(updates.canInstall, isTrue);
    expect(await SecureStorageService.instance.getPasswordDataLocation(),
        '${root.path}/cloud/PasswordManager');
  });

  test(
      'opening existing library blocks install through validation and path commit',
      () async {
    final existing =
        LocalPasswordStore(directory: Directory('${root.path}/shared'));
    await existing.writePasswords([
      jsonEncode(
          PasswordEntry(title: 'Remote', username: 'bob', password: 'other')
              .toJson())
    ]);
    final changing = SecureStorageService.instance
        .useExistingPasswordDirectory(existing.directory.path);
    expect(updates.canInstall, isFalse);
    await changing;
    expect(updates.canInstall, isTrue);
    expect(await SecureStorageService.instance.getPasswordDataLocation(),
        existing.directory.path);
  });
}
