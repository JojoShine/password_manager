import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/app_settings.dart';
import 'settings_service.dart';

/// 认证服务类
class AuthService {
  static final AuthService _instance = AuthService._internal();
  factory AuthService() => _instance;
  AuthService._internal();

  static AuthService get instance => _instance;

  AppSettings? _currentSettings;
  String? _currentMasterPassword; // 临时存储当前会话的主密码
  
  // 新增：密码尝试失败追踪
  int _failedAttempts = 0;
  DateTime? _lockoutTime;
  static const int MAX_FAILED_ATTEMPTS = 5; // 最大失败尝试次数
  static const int LOCKOUT_DURATION_MINUTES = 15; // 锁定时长（分钟）

  /// 初始化认证服务
  Future<void> initialize() async {
    _currentSettings = await _loadSettings();
    await _loadFailedAttempts(); // 加载失败尝试记录
  }
  
  /// 加载失败尝试记录
  Future<void> _loadFailedAttempts() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _failedAttempts = prefs.getInt('failed_attempts') ?? 0;
      print('加载失败尝试记录: 当前失败次数 $_failedAttempts');
      
      final lockoutTimestamp = prefs.getString('lockout_time');
      if (lockoutTimestamp != null) {
        _lockoutTime = DateTime.parse(lockoutTimestamp);
        
        // 检查锁定是否已过期
        final now = DateTime.now();
        if (now.difference(_lockoutTime!).inMinutes >= LOCKOUT_DURATION_MINUTES) {
          // 锁定已过期，清除记录
          print('锁定已过期，清除失败尝试记录');
          await _clearFailedAttempts();
        } else {
          print('账户仍处于锁定状态，剩余时间: ${getRemainingLockoutTime()} 分钟');
        }
      }
    } catch (e) {
      print('加载失败尝试记录失败: $e');
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
      print('保存失败尝试记录失败: $e');
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
      print('清除失败尝试记录失败: $e');
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

      print('密码验证成功，已更新最后解锁时间: $now');
    } else {
      // 密码错误，增加失败计数
      _failedAttempts++;
      print('密码验证失败，失败次数: $_failedAttempts/$MAX_FAILED_ATTEMPTS');
      
      if (_failedAttempts >= MAX_FAILED_ATTEMPTS) {
        // 达到最大失败次数，锁定账户
        _lockoutTime = DateTime.now();
        await _saveFailedAttempts();
        print('账户已被锁定，锁定时间: $_lockoutTime');
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
      print('账户处于锁定状态，需要认证');
      return true;
    }

    if (settings.lastUnlockTime == null) {
      // print('需要认证：没有记录解锁时间');
      return true;
    }

    // 获取锁定超时时间（从SettingsService获取）
    final timeoutMinutes = SettingsService.instance.lockTimeoutMinutes;
    
    // 调试日志：打印SettingsService的配置值
    print('🔍 [自动锁定检查] SettingsService配置的超时时间: ${timeoutMinutes} 分钟');
    print('🔍 [自动锁定检查] SharedPreferences中的原始值: ${await _getRawLockTimeoutValue()}');
    
    final now = DateTime.now();
    final timeSinceLastUnlock = now.difference(settings.lastUnlockTime!);

    // 使用更精确的时间比较（毫秒级别），避免inMinutes的整数截断问题
    final timeoutDuration = Duration(minutes: timeoutMinutes);
    final needsAuth = timeSinceLastUnlock >= timeoutDuration;

    // 调试日志
    print('🔍 [自动锁定检查] 详细时间信息:');
    print('  - 上次解锁时间: ${settings.lastUnlockTime!.toLocal()}');
    print('  - 当前时间: ${now.toLocal()}');
    print('  - 已过去时间: ${timeSinceLastUnlock.inMinutes} 分 ${timeSinceLastUnlock.inSeconds % 60} 秒 (${timeSinceLastUnlock.inSeconds} 秒)');
    print('  - 配置超时: ${timeoutMinutes} 分钟 (${timeoutDuration.inSeconds} 秒)');
    print('  - 是否需要认证: $needsAuth');

    // 如果超过锁定时间，自动锁定应用
    if (needsAuth) {
      await lockApp();
    }

    return needsAuth;
  }
  
  /// 获取SharedPreferences中的原始锁定超时值（用于调试）
  Future<int?> _getRawLockTimeoutValue() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getInt('lock_timeout_minutes');
    } catch (e) {
      print('获取原始锁定超时值失败: $e');
      return null;
    }
  }
  
  /// 检查是否在免密登录时间内
  Future<bool> isWithinAutoUnlockTime() async {
    final settings = await getCurrentSettings();

    if (!settings.hasMasterPassword || settings.isFirstLaunch) {
      return false;
    }

    if (settings.lastUnlockTime == null) {
      return false;
    }

    // 获取锁定超时时间（从SettingsService获取）
    final timeoutMinutes = SettingsService.instance.lockTimeoutMinutes;
    final timeSinceLastUnlock =
        DateTime.now().difference(settings.lastUnlockTime!);

    // 使用精确的Duration比较
    final timeoutDuration = Duration(minutes: timeoutMinutes);
    
    // 如果未超过锁定时间，说明在免密登录时间内
    return timeSinceLastUnlock < timeoutDuration;
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
