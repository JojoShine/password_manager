import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/app_settings.dart';
import 'settings_service.dart';

/// 认证服务类
class AuthService extends ChangeNotifier {
  static final AuthService _instance = AuthService._internal();
  factory AuthService() => _instance;
  AuthService._internal();

  static AuthService get instance => _instance;

  AppSettings? _currentSettings;
  String? _currentMasterPassword; // 临时存储当前会话的主密码
  bool _isSessionUnlocked = false;
  DateTime? _backgroundedAt;

  bool get isSessionUnlocked => _isSessionUnlocked;

  // 新增：密码尝试失败追踪
  int _failedAttempts = 0;
  DateTime? _lockoutTime;
  static const int MAX_FAILED_ATTEMPTS = 5; // 最大失败尝试次数
  static const int LOCKOUT_DURATION_MINUTES = 15; // 锁定时长（分钟）

  /// 初始化认证服务
  Future<void> initialize() async {
    _isSessionUnlocked = false;
    _currentMasterPassword = null;
    _backgroundedAt = null;
    _failedAttempts = 0;
    _lockoutTime = null;
    _currentSettings = await _loadSettings();
    await _loadFailedAttempts(); // 加载失败尝试记录
  }

  /// 加载失败尝试记录
  Future<void> _loadFailedAttempts() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _failedAttempts = prefs.getInt('failed_attempts') ?? 0;
      if (kDebugMode) print('加载失败尝试记录: 当前失败次数 $_failedAttempts');

      final lockoutTimestamp = prefs.getString('lockout_time');
      if (lockoutTimestamp != null) {
        _lockoutTime = DateTime.parse(lockoutTimestamp);

        // 检查锁定是否已过期
        final now = DateTime.now();
        if (now.difference(_lockoutTime!).inMinutes >=
            LOCKOUT_DURATION_MINUTES) {
          // 锁定已过期，清除记录
          if (kDebugMode) print('锁定已过期，清除失败尝试记录');
          await _clearFailedAttempts();
        } else {
          if (kDebugMode)
            print('账户仍处于锁定状态，剩余时间: ${getRemainingLockoutTime()} 分钟');
        }
      }
    } catch (e) {
      if (kDebugMode) print('加载失败尝试记录失败: $e');
    }
  }

  /// 保存失败尝试记录
  Future<void> _saveFailedAttempts() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('failed_attempts', _failedAttempts);
      if (_lockoutTime != null) {
        await prefs.setString('lockout_time', _lockoutTime!.toIso8601String());
      }
    } catch (e) {
      if (kDebugMode) print('保存失败尝试记录失败: $e');
    }
  }

  /// 清除失败尝试记录
  Future<void> _clearFailedAttempts() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('failed_attempts');
      await prefs.remove('lockout_time');
      _failedAttempts = 0;
      _lockoutTime = null;
    } catch (e) {
      if (kDebugMode) print('清除失败尝试记录失败: $e');
    }
  }

  /// 检查是否被锁定
  bool isLockedOut() {
    if (_lockoutTime == null) return false;

    final now = DateTime.now();
    final minutesSinceLockout = now.difference(_lockoutTime!).inMinutes;

    return minutesSinceLockout < LOCKOUT_DURATION_MINUTES;
  }

  /// 获取剩余锁定时间（分钟）
  int getRemainingLockoutTime() {
    if (_lockoutTime == null) return 0;

    final now = DateTime.now();
    final minutesSinceLockout = now.difference(_lockoutTime!).inMinutes;
    final remaining = LOCKOUT_DURATION_MINUTES - minutesSinceLockout;

    return remaining > 0 ? remaining : 0;
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
      // print('加载设置失败: $e');
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
      // print('保存设置失败: $e');
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

    if (password.isEmpty) {
      throw ArgumentError('密码不能为空');
    }

    final settings = await getCurrentSettings();
    final hashedPassword = _hashPassword(password);

    final updatedSettings = settings.copyWith(
      masterPasswordHash: hashedPassword,
      isFirstLaunch: false,
      lastUnlockTime: DateTime.now(),
    );

    await _saveSettings(updatedSettings);
    _currentMasterPassword = password;
    _setSessionUnlocked(true);
    return true;
  }

  /// 验证主密码
  Future<bool> verifyMasterPassword(String password) async {
    // 检查是否被锁定
    if (isLockedOut()) {
      final remainingTime = getRemainingLockoutTime();
      throw Exception('账户已被锁定，请${remainingTime}分钟后再试');
    }

    final settings = await getCurrentSettings();

    if (!settings.hasMasterPassword) {
      return false;
    }

    final hashedPassword = _hashPassword(password);
    final isValid = hashedPassword == settings.masterPasswordHash;

    if (isValid) {
      // 密码正确，重置失败计数
      await _clearFailedAttempts();

      // 更新最后解锁时间
      final now = DateTime.now();
      final updatedSettings = settings.copyWith(
        lastUnlockTime: now,
      );
      await _saveSettings(updatedSettings);

      // 强制刷新缓存
      _currentSettings = updatedSettings;

      // 临时保存主密码用于当前会话的加密操作
      _currentMasterPassword = password;
      _setSessionUnlocked(true);

      if (kDebugMode) print('密码验证成功，已更新最后解锁时间: $now');
    } else {
      // 密码错误，增加失败计数
      _failedAttempts++;
      if (kDebugMode)
        print('密码验证失败，失败次数: $_failedAttempts/$MAX_FAILED_ATTEMPTS');

      if (_failedAttempts >= MAX_FAILED_ATTEMPTS) {
        // 达到最大失败次数，锁定账户
        _lockoutTime = DateTime.now();
        await _saveFailedAttempts();
        if (kDebugMode) print('账户已被锁定，锁定时间: $_lockoutTime');
        throw Exception('密码错误次数过多，账户已锁定${LOCKOUT_DURATION_MINUTES}分钟');
      } else {
        await _saveFailedAttempts();
      }
    }

    return isValid;
  }

  /// 检查是否需要认证
  Future<bool> needsAuthentication() async {
    // 强制重新加载设置以获取最新数据
    _currentSettings = await _loadSettings();

    // 重新加载失败尝试记录，确保状态是最新的
    await _loadFailedAttempts();

    final settings = _currentSettings!;

    if (settings.masterPasswordHash == null || settings.isFirstLaunch) {
      // print('需要认证：没有设置主密码或首次启动');
      return true;
    }

    // 检查是否因密码错误被锁定（优先级最高）
    if (isLockedOut()) {
      if (kDebugMode) print('账户处于锁定状态，需要认证');
      _setSessionUnlocked(false);
      return true;
    }

    return !_isSessionUnlocked;
  }

  /// 检查是否在免密登录时间内
  Future<bool> isWithinAutoUnlockTime() async {
    final settings = await getCurrentSettings();

    if (!settings.hasMasterPassword || settings.isFirstLaunch) {
      return false;
    }

    return _isSessionUnlocked;
  }

  /// 记录应用首次离开前台的时间；重复的生命周期通知不会重置计时。
  void markBackgrounded(DateTime at) {
    _backgroundedAt ??= at;
  }

  /// 应用返回前台时，仅按实际后台停留时间决定是否锁定。
  Future<bool> resumeFromBackground(DateTime at) async {
    final backgroundedAt = _backgroundedAt;
    _backgroundedAt = null;

    if (!_isSessionUnlocked) return true;
    if (backgroundedAt == null || at.isBefore(backgroundedAt)) return false;

    final timeout = Duration(
      minutes: SettingsService.instance.lockTimeoutMinutes,
    );
    if (at.difference(backgroundedAt) >= timeout) {
      await lockApp();
      return true;
    }

    return false;
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

    await SettingsService.instance.setLockTimeout(minutes);
  }

  /// 获取自动锁定超时时间
  Future<int> getAutoLockTimeout() async {
    return SettingsService.instance.lockTimeoutMinutes;
  }

  /// 立即锁定应用
  Future<void> lockApp() async {
    _currentMasterPassword = null;
    _backgroundedAt = null;
    _setSessionUnlocked(false);

    // 注意：这里不清除失败尝试记录，保持安全策略
  }

  /// 手动重置失败尝试（管理员功能）
  Future<void> resetFailedAttempts() async {
    await _clearFailedAttempts();
  }

  /// 获取失败尝试信息
  Map<String, dynamic> getFailedAttemptInfo() {
    return {
      'failedAttempts': _failedAttempts,
      'maxAttempts': MAX_FAILED_ATTEMPTS,
      'isLockedOut': isLockedOut(),
      'remainingLockoutTime': getRemainingLockoutTime(),
    };
  }

  /// 重置应用（清除所有设置，谨慎使用）
  Future<void> resetApp() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('app_settings');
      _currentSettings = null;
      _currentMasterPassword = null;
      _setSessionUnlocked(false);
    } catch (e) {
      // print('清除设置失败: $e');
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

    if (newPassword.isEmpty) {
      throw ArgumentError('新密码不能为空');
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
    _currentMasterPassword = newPassword;
    _setSessionUnlocked(true);
    return true;
  }

  /// 获取应用统计信息
  Future<Map<String, dynamic>> getAppStats() async {
    final settings = await getCurrentSettings();

    return {
      'isFirstLaunch': settings.isFirstLaunch,
      'hasMasterPassword': settings.hasMasterPassword,
      'autoLockTimeoutMinutes': SettingsService.instance.lockTimeoutMinutes,
      'lastUnlockTime': settings.lastUnlockTime?.toIso8601String(),
      'appVersion': settings.appVersion,
      'createdAt': settings.createdAt.toIso8601String(),
      'needsAuthentication': !_isSessionUnlocked,
    };
  }

  /// 导出设置（不包含敏感信息）
  Future<Map<String, dynamic>> exportSettings() async {
    final settings = await getCurrentSettings();

    return {
      'autoLockTimeoutMinutes': SettingsService.instance.lockTimeoutMinutes,
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
    if (password.length < 8) {
      suggestions.add('建议使用8位以上密码');
    } else if (password.length >= 12) {
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
    result['isValid'] = issues.isEmpty;

    return result;
  }

  void _setSessionUnlocked(bool value) {
    if (_isSessionUnlocked == value) return;
    _isSessionUnlocked = value;
    notifyListeners();
  }
}
