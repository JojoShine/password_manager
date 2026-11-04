import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:pointycastle/export.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'local_password_store.dart';
import 'app_update_service.dart';
import 'event_bus.dart';
import '../models/password_entry.dart';

/// 安全存储服务
///
/// 使用 AES-256-CBC 加密密码数据后存入 SharedPreferences，
/// 加密密钥由 flutter_secure_storage 管理（Android Keystore / iOS Keychain）。
/// macOS 与 Web 使用项目本地存储；其他原生平台安全存储不可用时停止读写。
class SecureStorageService {
  static final SecureStorageService _instance =
      SecureStorageService._internal();
  static SecureStorageService get instance => _instance;
  SecureStorageService._internal();

  static const String _keyAlias = 'pm_encryption_key';
  static const String _dataKey = 'saved_passwords';
  static const String _backupKey = 'saved_passwords_backup';
  static const String _migratedKey = 'secure_storage_migrated';
  static const String _windowsDataDirectoryKey =
      'windows_password_data_directory';

  static const String _desktopDataDirectoryKey =
      'desktop_password_data_directory';

  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();

  /// AES 加密密钥（32字节 = 256位）
  Uint8List? _encryptionKey;

  /// 安全存储是否可用
  bool _secureStorageAvailable = false;
  LocalPasswordStore? _localPasswordStore;

  /// 安全存储是否可用（供外部检查）
  bool get isSecureStorageAvailable => _secureStorageAvailable;

  /// 初始化：加载或生成加密密钥
  Future<void> initialize() async {
    if (kIsWeb) {
      _secureStorageAvailable = false;
      _encryptionKey = null;
      return;
    }

    if (_usesDesktopFileStorage) {
      final prefs = await SharedPreferences.getInstance();
      final configuredDirectory = prefs.getString(_desktopDataDirectoryKey) ??
          (defaultTargetPlatform == TargetPlatform.windows
              ? prefs.getString(_windowsDataDirectoryKey)
              : null);
      _localPasswordStore = LocalPasswordStore(
        directory: Directory(configuredDirectory ?? _desktopDataDirectory),
      );
      await _localPasswordStore!.directory.create(recursive: true);
      if (defaultTargetPlatform == TargetPlatform.macOS) {
        // Native startup migration has already selected and verified the
        // preference domain. Never read an older sandbox over these settings.
        await _restoreLegacyPasswordFile(_localPasswordStore!, {
          for (final key in [_dataKey, _backupKey])
            if (prefs.get(key) != null) key: prefs.get(key)!,
        });
      }
      return;
    }

    await _initializeSecureStorage();
    await _migrateIfNeeded();
  }

  Future<void> _initializeSecureStorage() async {
    try {
      final existingKey = await _secureStorage.read(key: _keyAlias);
      if (existingKey != null) {
        _encryptionKey = Uint8List.fromList(base64Decode(existingKey));
      } else {
        // 首次启动，生成随机密钥
        final random = Random.secure();
        _encryptionKey = Uint8List.fromList(
          List<int>.generate(32, (_) => random.nextInt(256)),
        );
        await _secureStorage.write(
          key: _keyAlias,
          value: base64Encode(_encryptionKey!),
        );
      }

      _secureStorageAvailable = true;
    } catch (e) {
      _secureStorageAvailable = false;
      _encryptionKey = null;
      throw SecureStorageInitializationException(e);
    }
  }

  /// 迁移旧版 StringList 格式到加密 String 格式
  Future<void> _migrateIfNeeded() async {
    final prefs = await SharedPreferences.getInstance();
    final alreadyMigrated = prefs.getBool(_migratedKey) ?? false;
    if (alreadyMigrated) return;

    try {
      // 检查是否有旧的 StringList 格式明文数据
      final plainData = prefs.getStringList(_dataKey);
      if (plainData != null && plainData.isNotEmpty) {
        final firstItem = plainData.first;
        if (firstItem.startsWith('{')) {
          // 以 { 开头说明是 JSON 明文，需要迁移
          if (_encryptionKey != null) {
            // 加密迁移
            await _encryptAndSave(plainData, _dataKey);
            final backupData = prefs.getStringList(_backupKey);
            if (backupData != null && backupData.isNotEmpty) {
              await _encryptAndSave(backupData, _backupKey);
            }
          } else {
            // 安全存储不可用，保持明文格式（已经是 StringList，无需迁移）
          }
        }
      }

      // 标记迁移完成
      await prefs.setBool(_migratedKey, true);
    } catch (e) {
      debugPrint('数据迁移失败: $e');
    }
  }

  /// 加载密码数据（自动解密）
  Future<List<String>> loadPasswords() async {
    final prefs = await SharedPreferences.getInstance();

    if (kIsWeb) {
      return prefs.getStringList(_dataKey) ?? [];
    }
    if (_usesDesktopFileStorage) {
      return _requireLocalPasswordStore().readPasswords();
    }
    _ensureSecureStorageAvailable();

    try {
      // 尝试读取加密格式（单个 String）
      final encrypted = prefs.getString(_dataKey);
      if (encrypted != null && encrypted.isNotEmpty) {
        // 检查是否为加密格式（base64 不以 { 开头）
        if (!encrypted.startsWith('{')) {
          final decrypted = _decryptData(encrypted);
          if (decrypted != null) return decrypted;
        }
      }

      // 兼容：如果数据仍是旧的 StringList 格式（迁移未完成）
      final legacyData = prefs.getStringList(_dataKey);
      if (legacyData != null && legacyData.isNotEmpty) {
        return legacyData;
      }

      // 尝试从备份恢复
      final encryptedBackup = prefs.getString(_backupKey);
      if (encryptedBackup != null && encryptedBackup.isNotEmpty) {
        if (!encryptedBackup.startsWith('{')) {
          final decrypted = _decryptData(encryptedBackup);
          if (decrypted != null) return decrypted;
        }
      }

      final legacyBackup = prefs.getStringList(_backupKey);
      if (legacyBackup != null && legacyBackup.isNotEmpty) {
        return legacyBackup;
      }

      return [];
    } catch (e) {
      debugPrint('加载加密密码失败: $e');
      return [];
    }
  }

  /// 保存密码数据（自动加密）
  Future<void> savePasswords(List<String> passwordsJson,
      {List<String>? expectedPasswords}) async {
    final prefs = await SharedPreferences.getInstance();

    if (kIsWeb) {
      await prefs.setStringList(_dataKey, passwordsJson);
      await prefs.setStringList(_backupKey, passwordsJson);
      await prefs.setString(
          'last_backup_time', DateTime.now().toIso8601String());
      return;
    }
    if (_usesDesktopFileStorage) {
      await _requireLocalPasswordStore()
          .writePasswords(passwordsJson, expectedPasswords: expectedPasswords);
      await prefs.setString(
        'last_backup_time',
        DateTime.now().toIso8601String(),
      );
      return;
    }
    _ensureSecureStorageAvailable();

    // 加密后存储为单个 String
    final encrypted = _encryptData(passwordsJson);
    await prefs.setString(_dataKey, encrypted);
    await prefs.setString(_backupKey, encrypted);
    await prefs.setString('last_backup_time', DateTime.now().toIso8601String());
  }

  /// 加密 JSON 字符串列表并保存
  Future<void> _encryptAndSave(List<String> passwordsJson, String key) async {
    _ensureSecureStorageAvailable();

    final prefs = await SharedPreferences.getInstance();
    final jsonStr = jsonEncode(passwordsJson);
    final encrypted = _encryptString(jsonStr);
    await prefs.setString(key, encrypted);
  }

  // ==================== AES-256-CBC 加密/解密 ====================

  /// 加密密码数据（List<String> → 加密字符串）
  String _encryptData(List<String> data) {
    final jsonStr = jsonEncode(data);
    return _encryptString(jsonStr);
  }

  /// 解密密码数据（加密字符串 → List<String>）
  List<String>? _decryptData(String encrypted) {
    final jsonStr = _decryptString(encrypted);
    if (jsonStr == null) return null;
    try {
      final list = jsonDecode(jsonStr) as List<dynamic>;
      return list.cast<String>();
    } catch (e) {
      debugPrint('解密后解析 JSON 失败: $e');
      return null;
    }
  }

  /// AES-256-CBC 加密字符串
  String _encryptString(String plainText) {
    _ensureSecureStorageAvailable();

    final random = Random.secure();
    final iv = Uint8List.fromList(
      List<int>.generate(16, (_) => random.nextInt(256)),
    );

    final cipher = CBCBlockCipher(AESEngine())
      ..init(true, ParametersWithIV(KeyParameter(_encryptionKey!), iv));

    final dataBytes = Uint8List.fromList(utf8.encode(plainText));
    final paddedData = _pkcs7Pad(dataBytes, 16);
    final encryptedBytes = Uint8List(paddedData.length);

    for (int offset = 0; offset < paddedData.length; offset += 16) {
      cipher.processBlock(paddedData, offset, encryptedBytes, offset);
    }

    // 格式: iv(16) + ciphertext
    final result = Uint8List(iv.length + encryptedBytes.length);
    result.setAll(0, iv);
    result.setAll(16, encryptedBytes);

    return base64Encode(result);
  }

  /// AES-256-CBC 解密字符串
  String? _decryptString(String encrypted) {
    if (_encryptionKey == null) return null;

    try {
      final allBytes = base64Decode(encrypted);
      if (allBytes.length < 32) return null; // 至少 IV(16) + 一个块(16)

      final iv = allBytes.sublist(0, 16);
      final ciphertext = allBytes.sublist(16);

      final cipher = CBCBlockCipher(AESEngine())
        ..init(
            false,
            ParametersWithIV(
                KeyParameter(_encryptionKey!), Uint8List.fromList(iv)));

      final decryptedBytes = Uint8List(ciphertext.length);
      for (int offset = 0; offset < ciphertext.length; offset += 16) {
        cipher.processBlock(ciphertext, offset, decryptedBytes, offset);
      }

      final unpadded = _pkcs7Unpad(decryptedBytes);
      return utf8.decode(unpadded);
    } catch (e) {
      debugPrint('解密失败: $e');
      return null;
    }
  }

  /// PKCS7 填充
  Uint8List _pkcs7Pad(Uint8List data, int blockSize) {
    final padLength = blockSize - (data.length % blockSize);
    final padded = Uint8List(data.length + padLength);
    padded.setAll(0, data);
    for (int i = data.length; i < padded.length; i++) {
      padded[i] = padLength;
    }
    return padded;
  }

  /// PKCS7 去填充
  Uint8List _pkcs7Unpad(Uint8List data) {
    if (data.isEmpty) return data;
    final padLength = data.last;
    if (padLength < 1 || padLength > 16) return data;
    for (int i = data.length - padLength; i < data.length; i++) {
      if (data[i] != padLength) return data;
    }
    return Uint8List.fromList(data.sublist(0, data.length - padLength));
  }

  void _ensureSecureStorageAvailable() {
    if (!_secureStorageAvailable || _encryptionKey == null) {
      throw const SecureStorageInitializationException(
        '系统安全存储不可用',
      );
    }
  }

  Future<String> getPasswordDataLocation() async {
    if (kIsWeb) return '浏览器本地存储';
    if (_usesDesktopFileStorage) {
      return _requireLocalPasswordStore().directory.path;
    }
    return '系统安全存储';
  }

  Future<String> changePasswordDataRoot(String selectedRoot) =>
      AppUpdateService.instance
          .protect(() => _changePasswordDataRoot(selectedRoot));

  Future<String> _changePasswordDataRoot(String selectedRoot) async {
    if (!_usesDesktopFileStorage) {
      throw const PasswordStoreException('当前平台不支持更改密码存储位置');
    }
    final root = selectedRoot.trim();
    if (root.isEmpty) throw const PasswordStoreException('请选择有效的数据存储目录');
    final targetDirectory = defaultTargetPlatform == TargetPlatform.windows
        ? LocalPasswordStore.resolveWindowsSelectedDataDirectory(root)
        : '${root.replaceAll(RegExp(r'/+$'), '')}/PasswordManager';
    final targetStore =
        LocalPasswordStore(directory: Directory(targetDirectory));
    await _requireLocalPasswordStore().copyPasswordsTo(targetStore);
    return _activatePasswordStore(targetStore);
  }

  // 保留旧入口供已有 Windows 调用方使用。
  Future<String> changeWindowsPasswordDataRoot(String selectedRoot) =>
      changePasswordDataRoot(selectedRoot);

  Future<String> useExistingPasswordDirectory(String selectedDirectory) =>
      AppUpdateService.instance
          .protect(() => _useExistingPasswordDirectory(selectedDirectory));

  Future<String> _useExistingPasswordDirectory(String selectedDirectory) async {
    if (!_usesDesktopFileStorage) {
      throw const PasswordStoreException('当前平台不支持选择密码库');
    }
    final target = LocalPasswordStore(directory: Directory(selectedDirectory));
    if (!await target.passwordFile.exists()) {
      throw const PasswordStoreException(
          '所选目录没有 passwords.json，请等待云端下载完成后选择密码库目录');
    }
    // 接入已有库时严格校验主文件，不从可能过期的备份覆盖它。
    await target.validatePasswordFile();
    for (final entry in await target.readPasswords()) {
      PasswordEntry.fromJson(jsonDecode(entry) as Map<String, dynamic>);
    }
    return _activatePasswordStore(target);
  }

  Future<String> _activatePasswordStore(LocalPasswordStore target) async {
    final prefs = await SharedPreferences.getInstance();
    if (!await prefs.setString(
        _desktopDataDirectoryKey, target.directory.path)) {
      throw const PasswordStoreException('无法保存新的密码存储位置');
    }
    _localPasswordStore = target;
    EventBus.instance.emitPasswordDataChanged();
    return target.directory.path;
  }

  Future<void> openPasswordDataLocation() async {
    if (!_usesDesktopFileStorage) {
      throw const PasswordStoreException('当前平台没有可打开的数据目录');
    }
    await _requireLocalPasswordStore().openDataDirectory(_desktopPlatform);
  }

  Future<int> countPasswords() async => (await loadPasswords()).length;

  Future<void> clearPasswords() =>
      AppUpdateService.instance.protect(() => _clearPasswords());

  Future<void> _clearPasswords() async {
    if (_usesDesktopFileStorage) {
      await _requireLocalPasswordStore().clearPasswords();
    }
    await _removeLegacyPasswordKeys();
  }

  @visibleForTesting
  Future<void> clearPasswordsForTesting(LocalPasswordStore store) async {
    await store.clearPasswords();
    await _removeLegacyPasswordKeys();
  }

  @visibleForTesting
  Future<void> restoreLegacyMacDataForTesting(
    LocalPasswordStore store,
    LegacyPreferencesReader reader,
  ) async {
    await _restoreLegacyMacData(store, reader);
  }

  Future<void> _restoreLegacyMacData(
    LocalPasswordStore store,
    LegacyPreferencesReader reader,
  ) async {
    final values = await reader.readSupportedPreferences();
    await _restoreLegacyPasswordFile(store, values);

    final prefs = await SharedPreferences.getInstance();
    for (final entry in values.entries) {
      if (entry.key == _dataKey ||
          entry.key == _backupKey ||
          prefs.containsKey(entry.key)) continue;
      await _setPreference(prefs, entry.key, entry.value);
    }
  }

  Future<void> _restoreLegacyPasswordFile(
    LocalPasswordStore store,
    Map<String, Object> values,
  ) async {
    final passwords = _legacyPasswordList(values);
    if (!await store.passwordFile.exists() && passwords != null) {
      await store.writePasswords(passwords);
      final verified = await store.readPasswords();
      if (!listEquals(verified, passwords)) {
        throw const PasswordStoreException('旧版密码数据恢复校验失败');
      }
    }
  }

  List<String>? _legacyPasswordList(Map<String, Object> values) {
    for (final key in [_dataKey, _backupKey]) {
      final value = values[key];
      if (value is List<String> && value.isNotEmpty) return value;
    }
    return null;
  }

  Future<void> _setPreference(
    SharedPreferences prefs,
    String key,
    Object value,
  ) async {
    if (value is String) {
      await prefs.setString(key, value);
    } else if (value is bool) {
      await prefs.setBool(key, value);
    } else if (value is int) {
      await prefs.setInt(key, value);
    } else if (value is double) {
      await prefs.setDouble(key, value);
    } else if (value is List<String>) {
      await prefs.setStringList(key, value);
    }
  }

  Future<void> _removeLegacyPasswordKeys() async {
    final prefs = await SharedPreferences.getInstance();
    for (final key in [
      _dataKey,
      _backupKey,
      _migratedKey,
      'last_backup_time',
    ]) {
      await prefs.remove(key);
    }
  }

  LocalPasswordStore _requireLocalPasswordStore() {
    final store = _localPasswordStore;
    if (store == null) {
      throw const PasswordStoreException('密码数据目录尚未初始化');
    }
    return store;
  }

  bool get _usesDesktopFileStorage =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.macOS ||
          defaultTargetPlatform == TargetPlatform.windows ||
          defaultTargetPlatform == TargetPlatform.linux);

  LocalPasswordPlatform get _desktopPlatform {
    switch (defaultTargetPlatform) {
      case TargetPlatform.macOS:
        return LocalPasswordPlatform.macOS;
      case TargetPlatform.windows:
        return LocalPasswordPlatform.windows;
      case TargetPlatform.linux:
        return LocalPasswordPlatform.linux;
      default:
        throw const PasswordStoreException('当前平台不是桌面平台');
    }
  }

  String get _desktopDataDirectory => LocalPasswordStore.resolveDataDirectory(
        _desktopPlatform,
        Platform.environment,
      );
}

class SecureStorageInitializationException implements Exception {
  final Object cause;

  const SecureStorageInitializationException(this.cause);

  @override
  String toString() => '无法使用系统安全存储：$cause';
}
