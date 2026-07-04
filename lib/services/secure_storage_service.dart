import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:pointycastle/export.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 安全存储服务
///
/// 使用 AES-256-CBC 加密密码数据后存入 SharedPreferences，
/// 加密密钥由 flutter_secure_storage 管理（Android Keystore / iOS Keychain）。
/// 当安全存储不可用时，自动降级为明文 SharedPreferences。
class SecureStorageService {
  static final SecureStorageService _instance = SecureStorageService._internal();
  static SecureStorageService get instance => _instance;
  SecureStorageService._internal();

  static const String _keyAlias = 'pm_encryption_key';
  static const String _dataKey = 'saved_passwords';
  static const String _backupKey = 'saved_passwords_backup';
  static const String _migratedKey = 'secure_storage_migrated';

  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();

  /// AES 加密密钥（32字节 = 256位）
  Uint8List? _encryptionKey;

  /// 安全存储是否可用
  bool _secureStorageAvailable = false;

  /// 安全存储是否可用（供外部检查）
  bool get isSecureStorageAvailable => _secureStorageAvailable;

  /// 初始化：加载或生成加密密钥
  Future<void> initialize() async {
    if (kIsWeb) {
      // Web 平台不使用 flutter_secure_storage
      return;
    }

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

      // 检查是否需要从明文迁移到加密存储
      await _migrateIfNeeded();
    } catch (e) {
      debugPrint('SecureStorageService 初始化失败，将使用明文存储: $e');
      _secureStorageAvailable = false;
      _encryptionKey = null;

      // 即使安全存储不可用，也要处理旧格式数据的迁移
      await _migrateLegacyFormat();
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

  /// 处理旧格式数据（安全存储不可用时的迁移）
  Future<void> _migrateLegacyFormat() async {
    final prefs = await SharedPreferences.getInstance();
    final alreadyMigrated = prefs.getBool(_migratedKey) ?? false;
    if (alreadyMigrated) return;

    try {
      // 检查是否有旧的 StringList 格式数据
      final plainData = prefs.getStringList(_dataKey);
      if (plainData != null && plainData.isNotEmpty && plainData.first.startsWith('{')) {
        // 旧格式数据存在，但无法加密迁移，保持原样
        // 标记迁移检查完成（虽然未加密，但已确认格式）
      }

      await prefs.setBool(_migratedKey, true);
    } catch (e) {
      debugPrint('旧格式迁移检查失败: $e');
    }
  }

  /// 加载密码数据（自动解密）
  Future<List<String>> loadPasswords() async {
    final prefs = await SharedPreferences.getInstance();

    if (kIsWeb || !_secureStorageAvailable) {
      // Web 平台或安全存储不可用：直接读取明文 StringList
      return prefs.getStringList(_dataKey) ?? [];
    }

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
  Future<void> savePasswords(List<String> passwordsJson) async {
    final prefs = await SharedPreferences.getInstance();

    if (kIsWeb || !_secureStorageAvailable) {
      // Web 平台或安全存储不可用：直接保存明文 StringList
      await prefs.setStringList(_dataKey, passwordsJson);
      await prefs.setStringList(_backupKey, passwordsJson);
      await prefs.setString('last_backup_time', DateTime.now().toIso8601String());
      return;
    }

    // 加密后存储为单个 String
    final encrypted = _encryptData(passwordsJson);
    await prefs.setString(_dataKey, encrypted);
    await prefs.setString(_backupKey, encrypted);
    await prefs.setString('last_backup_time', DateTime.now().toIso8601String());
  }

  /// 加密 JSON 字符串列表并保存
  Future<void> _encryptAndSave(List<String> passwordsJson, String key) async {
    if (_encryptionKey == null) return;

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
    if (_encryptionKey == null) return plainText;

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
        ..init(false, ParametersWithIV(KeyParameter(_encryptionKey!), Uint8List.fromList(iv)));

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
}
