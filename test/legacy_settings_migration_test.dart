import 'dart:io';
import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:password_manager/services/legacy_settings_migration.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory root;
  late File source;
  late File target;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    root = await Directory.systemTemp.createTemp('lockora-migration-test-');
    source = File('${root.path}/legacy/shared_preferences.json');
    target = File('${root.path}/Lockora/shared_preferences.json');
    await source.parent.create();
  });
  tearDown(() => root.delete(recursive: true));

  test('copies complete preferences and retains source across repeated starts',
      () async {
    const contents =
        '{"flutter.master_password_hash":"hash","flutter.failed_attempts":3,"flutter.password_directory":"D:/iCloud/PasswordManager"}';
    await source.writeAsString(contents);
    await LegacySettingsMigration.migrateWindowsSettings(source, target);
    expect(await target.readAsString(), contents);
    expect(await source.readAsString(), contents);
    await target.writeAsString('{"flutter.app_title":"Custom"}');
    await LegacySettingsMigration.migrateWindowsSettings(source, target);
    expect(await target.readAsString(), '{"flutter.app_title":"Custom"}');
  });

  test('valid target wins over damaged legacy settings', () async {
    await source.writeAsString('broken');
    await target.parent.create();
    await target.writeAsString('{"flutter.master_password_hash":"new"}');
    await LegacySettingsMigration.migrateWindowsSettings(source, target);
    expect(
        await target.readAsString(), '{"flutter.master_password_hash":"new"}');
  });

  for (final invalid in ['broken', '[]', 'null']) {
    test('damaged source fails closed: $invalid', () async {
      await source.writeAsString(invalid);
      await expectLater(
          LegacySettingsMigration.migrateWindowsSettings(source, target),
          throwsA(isA<FormatException>()));
      expect(await target.exists(), false);
      expect(await source.readAsString(), invalid);
    });
  }

  test('damaged target fails closed without overwriting either file', () async {
    await source.writeAsString('{"flutter.app_title":"Old"}');
    await target.parent.create();
    await target.writeAsString('broken');
    await expectLater(
        LegacySettingsMigration.migrateWindowsSettings(source, target),
        throwsA(isA<FormatException>()));
    expect(await target.readAsString(), 'broken');
    expect(await source.exists(), true);
  });

  test('write failure preserves source and does not create target', () async {
    await source.writeAsString('{"flutter.master_password_hash":"hash"}');
    await File(target.parent.path).writeAsString('blocks directory creation');
    await expectLater(
        LegacySettingsMigration.migrateWindowsSettings(source, target),
        throwsA(isA<FileSystemException>()));
    expect(
        await source.readAsString(), '{"flutter.master_password_hash":"hash"}');
    expect(await target.exists(), false);
  });

  test('a directory at the source path cannot masquerade as a fresh install',
      () async {
    await Directory(source.path).create();
    await expectLater(
      LegacySettingsMigration.migrateWindowsSettings(source, target),
      throwsA(isA<FileSystemException>()),
    );
    expect(await target.exists(), false);
  });

  test('a directory at the target path fails closed', () async {
    await Directory(target.path).create(recursive: true);
    await expectLater(
      LegacySettingsMigration.migrateWindowsSettings(source, target),
      throwsA(isA<FileSystemException>()),
    );
  });

  test('fresh install leaves preference creation to SharedPreferences',
      () async {
    await LegacySettingsMigration.migrateWindowsSettings(source, target);
    expect(await target.exists(), false);
  });

  test('native migration failures reach startup caller', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
    const channel = MethodChannel('me.tbtparent.lockora/migration');
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    addTearDown(() {
      debugDefaultTargetPlatformOverride = null;
      messenger.setMockMethodCallHandler(channel, null);
    });
    messenger.setMockMethodCallHandler(channel, (call) async {
      expect(call.method, 'migrate');
      throw PlatformException(code: 'migration_failed');
    });
    await expectLater(
        LegacySettingsMigration.migrate(), throwsA(isA<PlatformException>()));
    messenger.setMockMethodCallHandler(channel, (_) async => false);
    await expectLater(
        LegacySettingsMigration.migrate(), throwsA(isA<StateError>()));
    messenger.setMockMethodCallHandler(channel, (_) async => true);
    await LegacySettingsMigration.migrate();
  });
  for (final damaged in [
    '{}',
    '{"created_at":17,"updated_at":"bad"}',
    '{"created_at":"2026-11-04T10:00:00","updated_at":"2026-11-04T10:00:00","master_password_hash":17}'
  ]) {
    test('invalid nested authentication fails migration: $damaged', () async {
      final contents = jsonEncode({'flutter.app_settings': damaged});
      await source.writeAsString(contents);
      await expectLater(
          LegacySettingsMigration.migrateWindowsSettings(source, target),
          throwsFormatException);
      expect(await target.exists(), isFalse);
      expect(await source.readAsString(), contents);
    });
  }

  test('macOS validates migrated authentication before startup consumers',
      () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
    const channel = MethodChannel('me.tbtparent.lockora/migration');
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    addTearDown(() {
      debugDefaultTargetPlatformOverride = null;
      messenger.setMockMethodCallHandler(channel, null);
    });
    SharedPreferences.setMockInitialValues({'app_settings': '{}'});
    messenger.setMockMethodCallHandler(channel, (_) async => true);
    await expectLater(LegacySettingsMigration.migrate(), throwsFormatException);
  });
}
