import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:password_manager/models/password_entry.dart';
import 'package:password_manager/pages/home_page.dart';
import 'package:password_manager/services/event_bus.dart';
import 'package:password_manager/services/local_password_store.dart';
import 'package:password_manager/services/secure_storage_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets(
      'an edit dialog cannot overwrite a change received while it was open',
      (tester) async {
    final directory = (await tester
        .runAsync(() => Directory.systemTemp.createTemp('pm_edit_')))!;
    debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
    tester.view.physicalSize = const Size(1400, 1200);
    tester.view.devicePixelRatio = 1;
    final entry = PasswordEntry(
        id: 1,
        title: 'Example',
        username: 'alice',
        password: 'old-secret',
        website: 'example.com');
    try {
      SharedPreferences.setMockInitialValues({
        'desktop_password_data_directory': directory.path,
        'mac_legacy_data_restore_checked': true,
      });
      await tester.runAsync(() async {
        await SecureStorageService.instance.initialize();
        await SecureStorageService.instance.unlockDesktopVault('test-master');
        await SecureStorageService.instance
            .savePasswords([jsonEncode(entry.toJson())]);
      });
      await tester.pumpWidget(const MaterialApp(home: HomePage()));
      for (var i = 0; i < 12; i++) {
        await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 20)));
        await tester.pump();
      }
      expect(find.text('Example'), findsOneWidget);
      await tester.tap(find.byIcon(Icons.edit).first);
      await tester.pumpAndSettle();
      final remote = entry.copyWith(password: 'remote-new');
      await tester.runAsync(() async {
        final other = LocalPasswordStore(directory: directory);
        await other.unlock('test-master');
        await other.writePasswords([jsonEncode(remote.toJson())]);
        EventBus.instance.emitPasswordDataChanged();
        await Future<void>.delayed(const Duration(milliseconds: 100));
      });
      await tester.pump();
      await tester.tap(find.text('保存').last);
      for (var i = 0; i < 100; i++) {
        await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 20)));
        await tester.pump(const Duration(milliseconds: 200));
        if (find.textContaining('密码库已被其他设备或操作更新').evaluate().isNotEmpty) break;
      }
      final records = await tester.runAsync(() async {
        final reader = LocalPasswordStore(directory: directory);
        await reader.unlock('test-master');
        return reader.readPasswords();
      });
      expect(jsonDecode(records!.single)['password'], 'remote-new');
      expect(find.text('编辑密码'), findsNothing);
      expect(find.textContaining('密码库已被其他设备或操作更新'), findsOneWidget);
    } finally {
      await tester.pumpWidget(const SizedBox.shrink());
      debugDefaultTargetPlatformOverride = null;
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
      await tester.runAsync(() => directory.delete(recursive: true));
    }
  });
}
