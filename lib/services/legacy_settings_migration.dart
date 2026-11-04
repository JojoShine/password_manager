import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/app_settings.dart';

/// Runs before any preferences consumer so identity changes cannot look like a
/// fresh installation when an existing user's settings could not be migrated.
class LegacySettingsMigration {
  static const _channel = MethodChannel('me.tbtparent.lockora/migration');

  static Future<void> migrate() async {
    if (kIsWeb) return;
    if (defaultTargetPlatform == TargetPlatform.macOS) {
      if (await _channel.invokeMethod<bool>('migrate') != true) {
        throw StateError('旧版设置迁移未完成');
      }
      _validateAuthentication(
          (await SharedPreferences.getInstance()).get('app_settings'));
    } else if (defaultTargetPlatform == TargetPlatform.windows) {
      final appData = Platform.environment['APPDATA'];
      if (appData == null || appData.isEmpty) {
        throw StateError('无法确定旧版设置目录');
      }
      final support = await getApplicationSupportDirectory();
      await migrateWindowsSettings(
        File('$appData/com.example/password_manager/shared_preferences.json'),
        File('${support.path}/shared_preferences.json'),
      );
    }
  }

  static Future<void> migrateWindowsSettings(File source, File target) async {
    final current = await _readIfPresent(target);
    if (current != null) {
      _validate(current);
      return;
    }
    final contents = await _readIfPresent(source);
    if (contents == null) return;
    _validate(contents);
    await target.parent.create(recursive: true);
    // A temporary directory on the target volume permits an atomic rename.
    final staging = await target.parent.createTemp('.lockora-migration-');
    try {
      final staged = File('${staging.path}/shared_preferences.json');
      await staged.writeAsString(contents, flush: true);
      if (await staged.readAsString() != contents) {
        throw StateError('旧版设置复制校验失败');
      }
      // Preserve settings if another startup completed during the copy.
      final concurrent = await _readIfPresent(target);
      if (concurrent != null) {
        _validate(concurrent);
        return;
      }
      await staged.rename(target.path);
    } finally {
      await staging.delete(recursive: true);
    }
  }

  static Future<String?> _readIfPresent(File file) async {
    try {
      return await file.readAsString();
    } on PathNotFoundException {
      return null;
    }
  }

  static void _validate(String contents) {
    final values = jsonDecode(contents);
    if (values is! Map<String, dynamic>) {
      throw const FormatException('设置文件必须是 JSON 对象');
    }
    _validateAuthentication(
        values['flutter.app_settings'] ?? values['app_settings']);
  }

  static void _validateAuthentication(Object? raw) {
    if (raw == null) return;
    try {
      if (raw is! String) throw const FormatException('主密码设置格式无效');
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>)
        throw const FormatException('主密码设置格式无效');
      AppSettings.fromMap(decoded);
    } catch (_) {
      throw const FormatException('已有主密码设置损坏，请恢复设置后重试');
    }
  }
}
