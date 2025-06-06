/// 应用设置模型
class AppSettings {
  final String? masterPasswordHash; // 主密码哈希
  final int autoLockTimeoutMinutes; // 自动锁定超时时间（分钟）
  final DateTime? lastUnlockTime; // 最后解锁时间
  final bool biometricEnabled; // 是否启用生物识别
  final bool isFirstLaunch; // 是否首次启动
  final String appVersion;
  final DateTime createdAt;
  final DateTime updatedAt;

  AppSettings({
    this.masterPasswordHash,
    this.autoLockTimeoutMinutes = 5,
    this.lastUnlockTime,
    this.biometricEnabled = false,
    this.isFirstLaunch = true,
    this.appVersion = '1.0.0',
    DateTime? createdAt,
    DateTime? updatedAt,
  })  : createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  /// 从Map创建AppSettings实例
  factory AppSettings.fromMap(Map<String, dynamic> map) {
    return AppSettings(
      masterPasswordHash: map['master_password_hash'] as String?,
      autoLockTimeoutMinutes: map['auto_lock_timeout_minutes'] as int? ?? 5,
      lastUnlockTime: map['last_unlock_time'] != null
          ? DateTime.parse(map['last_unlock_time'] as String)
          : null,
      biometricEnabled: (map['biometric_enabled'] as int?) == 1,
      isFirstLaunch: (map['is_first_launch'] as int?) == 1,
      appVersion: map['app_version'] as String? ?? '1.0.0',
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: DateTime.parse(map['updated_at'] as String),
    );
  }

  /// 转换为Map
  Map<String, dynamic> toMap() {
    return {
      'master_password_hash': masterPasswordHash,
      'auto_lock_timeout_minutes': autoLockTimeoutMinutes,
      'last_unlock_time': lastUnlockTime?.toIso8601String(),
      'biometric_enabled': biometricEnabled ? 1 : 0,
      'is_first_launch': isFirstLaunch ? 1 : 0,
      'app_version': appVersion,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  /// 创建副本并更新某些字段
  AppSettings copyWith({
    String? masterPasswordHash,
    int? autoLockTimeoutMinutes,
    DateTime? lastUnlockTime,
    bool? biometricEnabled,
    bool? isFirstLaunch,
    String? appVersion,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return AppSettings(
      masterPasswordHash: masterPasswordHash ?? this.masterPasswordHash,
      autoLockTimeoutMinutes:
          autoLockTimeoutMinutes ?? this.autoLockTimeoutMinutes,
      lastUnlockTime: lastUnlockTime ?? this.lastUnlockTime,
      biometricEnabled: biometricEnabled ?? this.biometricEnabled,
      isFirstLaunch: isFirstLaunch ?? this.isFirstLaunch,
      appVersion: appVersion ?? this.appVersion,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? DateTime.now(),
    );
  }

  /// 检查是否需要重新认证
  bool get needsAuthentication {
    if (masterPasswordHash == null || isFirstLaunch) {
      return true;
    }

    if (lastUnlockTime == null) {
      return true;
    }

    final timeSinceLastUnlock = DateTime.now().difference(lastUnlockTime!);
    return timeSinceLastUnlock.inMinutes >= autoLockTimeoutMinutes;
  }

  /// 检查是否已设置主密码
  bool get hasMasterPassword =>
      masterPasswordHash != null && masterPasswordHash!.isNotEmpty;

  @override
  String toString() {
    return 'AppSettings{autoLockTimeoutMinutes: $autoLockTimeoutMinutes, '
        'biometricEnabled: $biometricEnabled, isFirstLaunch: $isFirstLaunch}';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is AppSettings &&
        other.masterPasswordHash == masterPasswordHash &&
        other.autoLockTimeoutMinutes == autoLockTimeoutMinutes &&
        other.biometricEnabled == biometricEnabled &&
        other.isFirstLaunch == isFirstLaunch;
  }

  @override
  int get hashCode {
    return Object.hash(
      masterPasswordHash,
      autoLockTimeoutMinutes,
      biometricEnabled,
      isFirstLaunch,
    );
  }
}
