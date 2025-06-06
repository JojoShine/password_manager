import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/app_settings.dart';

/// 认证服务类
class AuthService {
  static final AuthService _instance = AuthService._internal();
  factory AuthService() => _instance;
  AuthService._internal();

  static AuthService get instance => _instance;

  AppSettings? _currentSettings;
  String? _currentMasterPassword; // 临时存储当前会话的主密码

  /// 初始化认证服务
  Future<void> initialize() async {
    _currentSettings = await _loadSettings();
  }

  /// 获取当前应用设置
  Future<AppSettings> getCurrentSettings() async {
    _currentSettings ??= await _loadSettings();
    return _currentSettings!;
  }

  /// 加载应用设置
  Future<AppSettings> _loadSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final settingsJson = prefs.getString('app_settings');

      if (settingsJson == null) {
        // 创建默认设置
        final defaultSettings = AppSettings();
        await _saveSettings(defaultSettings);
        return defaultSettings;
      }

      final settingsMap = json.decode(settingsJson) as Map<String, dynamic>;
      return AppSettings.fromMap(settingsMap);
    } catch (e) {
      print('加载设置失败: $e');
      return AppSettings();
    }
  }

  /// 保存应用设置
  Future<void> _saveSettings(AppSettings settings) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final settingsJson = json.encode(settings.toMap());
      await prefs.setString('app_settings', settingsJson);
      _currentSettings = settings;
    } catch (e) {
      print('保存设置失败: $e');
    }
  }

  /// 生成密码哈希
  String _hashPassword(String password) {
    final bytes = utf8.encode(password + 'password_manager_salt');
    final digest = sha256.convert(bytes);
    return digest.toString();
  }

  /// 检查是否首次启动
  Future<bool> isFirstLaunch() async {
    final settings = await getCurrentSettings();
    return settings.isFirstLaunch;
  }

  /// 检查是否已设置主密码
  Future<bool> hasMasterPassword() async {
    final settings = await getCurrentSettings();
    return settings.hasMasterPassword;
  }

  /// 设置主密码（首次设置）
  Future<bool> setMasterPassword(
      String password, String confirmPassword) async {
    if (password != confirmPassword) {
      throw ArgumentError('密码不一致');
    }

    if (password.length < 6) {
      throw ArgumentError('密码长度至少为6位');
    }

    final settings = await getCurrentSettings();
    final hashedPassword = _hashPassword(password);

    final updatedSettings = settings.copyWith(
      masterPasswordHash: hashedPassword,
      isFirstLaunch: false,
      lastUnlockTime: DateTime.now(),
    );

    await _saveSettings(updatedSettings);
    return true;
  }

  /// 验证主密码
  Future<bool> verifyMasterPassword(String password) async {
    final settings = await getCurrentSettings();

    if (!settings.hasMasterPassword) {
      return false;
    }

    final hashedPassword = _hashPassword(password);
    final isValid = hashedPassword == settings.masterPasswordHash;

    if (isValid) {
      // 更新最后解锁时间
      final updatedSettings = settings.copyWith(
        lastUnlockTime: DateTime.now(),
      );
      await _saveSettings(updatedSettings);

      // 临时保存主密码用于当前会话的加密操作
      _currentMasterPassword = password;
    }

    return isValid;
  }

  /// 检查是否需要认证
  Future<bool> needsAuthentication() async {
    final settings = await getCurrentSettings();
    return settings.needsAuthentication;
  }

  /// 检查是否在免密登录时间内
  Future<bool> isWithinAutoUnlockTime() async {
    final settings = await getCurrentSettings();

    if (!settings.hasMasterPassword || settings.isFirstLaunch) {
      return false;
    }

    return !settings.needsAuthentication;
  }

  /// 获取当前会话的主密码（用于加密操作）
  String? getCurrentMasterPassword() {
    return _currentMasterPassword;
  }

  /// 检查是否有可用的主密码用于加密
  bool hasCurrentMasterPassword() {
    return _currentMasterPassword != null;
  }

  /// 更新自动锁定超时时间
  Future<void> updateAutoLockTimeout(int minutes) async {
    if (minutes < 1 || minutes > 1440) {
      // 1分钟到24小时
      throw ArgumentError('超时时间必须在1-1440分钟之间');
    }

    final settings = await getCurrentSettings();
    final updatedSettings = settings.copyWith(
      autoLockTimeoutMinutes: minutes,
    );

    await _saveSettings(updatedSettings);
  }

  /// 获取自动锁定超时时间
  Future<int> getAutoLockTimeout() async {
    final settings = await getCurrentSettings();
    return settings.autoLockTimeoutMinutes;
  }

  /// 立即锁定应用
  Future<void> lockApp() async {
    final settings = await getCurrentSettings();
    final updatedSettings = settings.copyWith(
      lastUnlockTime: DateTime.now().subtract(
        Duration(minutes: settings.autoLockTimeoutMinutes + 1),
      ),
    );

    await _saveSettings(updatedSettings);

    // 清除临时保存的主密码
    _currentMasterPassword = null;
  }

  /// 重置应用（清除所有设置，谨慎使用）
  Future<void> resetApp() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('app_settings');
      _currentSettings = null;
    } catch (e) {
      print('清除设置失败: $e');
    }
  }

  /// 更改主密码
  Future<bool> changeMasterPassword(
      String oldPassword, String newPassword, String confirmPassword) async {
    // 验证旧密码
    final isOldPasswordValid = await verifyMasterPassword(oldPassword);
    if (!isOldPasswordValid) {
      throw ArgumentError('旧密码不正确');
    }

    // 验证新密码
    if (newPassword != confirmPassword) {
      throw ArgumentError('新密码不一致');
    }

    if (newPassword.length < 6) {
      throw ArgumentError('新密码长度至少为6位');
    }

    if (newPassword == oldPassword) {
      throw ArgumentError('新密码不能与旧密码相同');
    }

    // 设置新密码
    final settings = await getCurrentSettings();
    final hashedPassword = _hashPassword(newPassword);

    final updatedSettings = settings.copyWith(
      masterPasswordHash: hashedPassword,
      lastUnlockTime: DateTime.now(),
    );

    await _saveSettings(updatedSettings);
    return true;
  }

  /// 获取应用统计信息
  Future<Map<String, dynamic>> getAppStats() async {
    final settings = await getCurrentSettings();

    return {
      'isFirstLaunch': settings.isFirstLaunch,
      'hasMasterPassword': settings.hasMasterPassword,
      'autoLockTimeoutMinutes': settings.autoLockTimeoutMinutes,
      'lastUnlockTime': settings.lastUnlockTime?.toIso8601String(),
      'appVersion': settings.appVersion,
      'createdAt': settings.createdAt.toIso8601String(),
      'needsAuthentication': settings.needsAuthentication,
    };
  }

  /// 导出设置（不包含敏感信息）
  Future<Map<String, dynamic>> exportSettings() async {
    final settings = await getCurrentSettings();

    return {
      'autoLockTimeoutMinutes': settings.autoLockTimeoutMinutes,
      'biometricEnabled': settings.biometricEnabled,
      'appVersion': settings.appVersion,
      'hasPassword': settings.hasMasterPassword,
    };
  }

  /// 验证密码强度
  static Map<String, dynamic> validatePasswordStrength(String password) {
    final result = {
      'isValid': false,
      'score': 0,
      'issues': <String>[],
      'suggestions': <String>[],
    };

    if (password.isEmpty) {
      (result['issues'] as List<String>).add('密码不能为空');
      return result;
    }

    int score = 0;
    final issues = <String>[];
    final suggestions = <String>[];

    // 长度检查
    if (password.length < 6) {
      issues.add('密码长度至少为6位');
    } else if (password.length >= 8) {
      score += 1;
    }

    // 包含大写字母
    if (password.contains(RegExp(r'[A-Z]'))) {
      score += 1;
    } else {
      suggestions.add('建议包含大写字母');
    }

    // 包含小写字母
    if (password.contains(RegExp(r'[a-z]'))) {
      score += 1;
    } else {
      suggestions.add('建议包含小写字母');
    }

    // 包含数字
    if (password.contains(RegExp(r'[0-9]'))) {
      score += 1;
    } else {
      suggestions.add('建议包含数字');
    }

    // 包含特殊字符
    if (password.contains(RegExp(r'[!@#$%^&*(),.?":{}|<>]'))) {
      score += 1;
    } else {
      suggestions.add('建议包含特殊字符');
    }

    result['score'] = score;
    result['issues'] = issues;
    result['suggestions'] = suggestions;
    result['isValid'] = issues.isEmpty && password.length >= 6;

    return result;
  }
}
