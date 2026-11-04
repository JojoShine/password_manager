import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'vault_crypto.dart';

import 'app_update_service.dart';

typedef ProcessRunner = Future<ProcessResult> Function(
  String executable,
  List<String> arguments,
);

abstract interface class LegacyPreferencesReader {
  Future<Map<String, Object>> readSupportedPreferences();
}

class MacLegacyPreferencesReader implements LegacyPreferencesReader {
  static const _supportedKeys = <String>[
    'app_settings',
    'app_theme_mode',
    'app_title',
    'last_backup_time',
    'last_server_port',
    'lock_timeout_minutes',
    'logo_path',
    'background_path',
    'saved_passwords',
    'saved_passwords_backup',
    'secure_storage_migrated',
  ];

  final File preferencesFile;
  final ProcessRunner processRunner;

  MacLegacyPreferencesReader({
    required this.preferencesFile,
    ProcessRunner? processRunner,
  }) : processRunner = processRunner ?? Process.run;

  @override
  Future<Map<String, Object>> readSupportedPreferences() async {
    final values = <String, Object>{};
    for (final key in _supportedKeys) {
      final plistKey = 'flutter.$key'.replaceAll('.', r'\.');
      final result = await processRunner('/usr/bin/plutil', [
        '-extract',
        plistKey,
        'json',
        '-o',
        '-',
        '--',
        preferencesFile.path,
      ]);
      if (result.exitCode != 0 || result.stdout is! String) continue;

      try {
        final decoded = jsonDecode(result.stdout as String);
        if (decoded is String || decoded is bool || decoded is num) {
          values[key] = decoded as Object;
        } else if (decoded is List && decoded.every((item) => item is String)) {
          values[key] = decoded.cast<String>();
        }
      } on FormatException {
        // Ignore an individual unsupported or malformed preference value.
      }
    }
    return values;
  }
}

enum LocalPasswordPlatform { macOS, windows, linux }

class LocalPasswordStore {
  static const int formatVersion = 2;

  final Directory directory;

  LocalPasswordStore({required this.directory});

  Uint8List? _key;
  Uint8List? _salt;
  String? _lastDocument;
  int _generation = 0;

  bool get isUnlocked => _key != null;
  List<String>? get passwordSnapshot =>
      _lastReadPasswords == null ? null : List<String>.of(_lastReadPasswords!);

  void lock() {
    _generation++;
    _key?.fillRange(0, _key!.length, 0);
    _key = null;
    _salt = null;
    _lastReadPasswords = null;
    _lastDocument = null;
  }

  Future<bool> hasEncryptedVault() async {
    if (!await passwordFile.exists()) return false;
    try {
      return (jsonDecode(await passwordFile.readAsString())
              as Map)['version'] ==
          2;
    } catch (_) {
      // An existing unreadable primary must never be treated as a new vault.
      return true;
    }
  }

  void _ensureUnlocked() {
    if (_key == null) throw const PasswordStoreException('密码库已锁定，请先解锁');
  }

  Future<void> unlock(String password, {List<String>? initialPasswords}) {
    final generation = _generation;
    return _serialize(() async {
      Uint8List? key;
      try {
        final original = await passwordFile.exists()
            ? await passwordFile.readAsString()
            : null;
        if (original == null &&
            (await backupFile.exists() || await temporaryFile.exists())) {
          throw const PasswordStoreException('密码库主文件缺失，请保留备份并手动恢复主文件后重试');
        }
        final document = original == null
            ? null
            : jsonDecode(original) as Map<String, dynamic>;
        final encrypted = document?['version'] == 2;
        final salt = encrypted
            ? VaultCrypto.salt(document!)
            : VaultCrypto.randomBytes(32);
        key = await VaultCrypto.derive(password, salt);
        final records = encrypted
            ? VaultCrypto.decrypt(document!, key)
            : (document == null
                ? initialPasswords ?? <String>[]
                : _readLegacy(document));
        if (generation != _generation)
          throw const PasswordStoreException('密码库已锁定，请重试');
        final committed = !encrypted
            ? await _commit(records, key, salt, original, generation,
                replaceBackup: true)
            : original!;
        final current = await passwordFile.readAsString();
        if (generation != _generation || current != committed) {
          throw const PasswordStoreException('密码库已锁定或被其他设备更新，请重新解锁');
        }
        _key?.fillRange(0, _key!.length, 0);
        _key = key;
        key = null;
        _salt = salt;
        _lastReadPasswords = List.of(records);
        _lastDocument = committed;
      } on VaultAuthenticationException {
        throw const PasswordAuthenticationException();
      } on PasswordStoreException {
        rethrow;
      } on FileSystemException {
        throw const PasswordStoreException('无法读写密码库，请检查数据目录和磁盘后重试');
      } catch (_) {
        throw const PasswordStoreException('密码库格式无效或数据损坏，请保留文件并检查后重试');
      } finally {
        key?.fillRange(0, key.length, 0);
      }
    });
  }

  Future<void> changeMasterPassword(String oldPassword, String newPassword) =>
      _serialize(() async {
        _ensureUnlocked();
        final generation = _generation;
        final original = await passwordFile.readAsString();
        if (original != _lastDocument)
          throw const PasswordStoreException('密码库已被其他设备或操作更新，请重新加载后再保存');
        Uint8List? oldKey;
        Uint8List? newKey;
        try {
          final document = jsonDecode(original) as Map<String, dynamic>;
          oldKey =
              await VaultCrypto.derive(oldPassword, VaultCrypto.salt(document));
          final records = VaultCrypto.decrypt(document, oldKey);
          final salt = VaultCrypto.randomBytes(32);
          newKey = await VaultCrypto.derive(newPassword, salt);
          final committed = await _commit(
              records, newKey, salt, original, generation,
              replaceBackup: true);
          _key!.fillRange(0, _key!.length, 0);
          _key = newKey;
          newKey = null;
          _salt = salt;
          _lastDocument = committed;
          _lastReadPasswords = List.of(records);
        } finally {
          oldKey?.fillRange(0, oldKey.length, 0);
          newKey?.fillRange(0, newKey.length, 0);
        }
      });

  Future<void> _serialize(Future<void> Function() operation) =>
      AppUpdateService.instance.protect(() {
        final result = _pendingWrite.then((_) => operation());
        _pendingWrite = result.then((_) {}, onError: (Object _) {});
        return result;
      });

  List<String>? _lastReadPasswords;
  Future<void> _pendingWrite = Future.value();

  File get passwordFile =>
      File('${directory.path}${Platform.pathSeparator}passwords.json');
  File get backupFile =>
      File('${directory.path}${Platform.pathSeparator}passwords.backup.json');
  File get temporaryFile =>
      File('${directory.path}${Platform.pathSeparator}passwords.json.tmp');

  static String resolveDataDirectory(
    LocalPasswordPlatform platform,
    Map<String, String> environment,
  ) {
    switch (platform) {
      case LocalPasswordPlatform.macOS:
        final home = _requiredEnvironment(environment, 'HOME');
        return '$home/Library/Application Support/PasswordManager';
      case LocalPasswordPlatform.windows:
        final appData = _requiredEnvironment(environment, 'APPDATA');
        return '$appData\\PasswordManager';
      case LocalPasswordPlatform.linux:
        final xdgDataHome = environment['XDG_DATA_HOME'];
        if (xdgDataHome != null && xdgDataHome.isNotEmpty) {
          return '$xdgDataHome/PasswordManager';
        }
        final home = _requiredEnvironment(environment, 'HOME');
        return '$home/.local/share/PasswordManager';
    }
  }

  static String resolveWindowsSelectedDataDirectory(String selectedDirectory) {
    final trimmed = selectedDirectory.trim().replaceAll(RegExp(r'[\\/]+$'), '');
    if (trimmed.isEmpty) {
      throw const PasswordStoreException('请选择有效的数据存储目录');
    }
    return '$trimmed\\PasswordManager';
  }

  static String _requiredEnvironment(
    Map<String, String> environment,
    String key,
  ) {
    final value = environment[key];
    if (value == null || value.isEmpty) {
      throw PasswordStoreException('无法确定系统数据目录：缺少 $key');
    }
    return value;
  }

  Future<List<String>> readPasswords() async {
    final passwords = await _readCurrentPasswords();
    _lastReadPasswords = List.of(passwords);
    return passwords;
  }

  Future<List<String>> _readCurrentPasswords() async {
    _ensureUnlocked();
    if (!await passwordFile.exists())
      throw const PasswordStoreException('密码库主文件缺失，请手动恢复');
    final raw = await passwordFile.readAsString();
    _ensureUnlocked();
    final records = _decrypt(raw, _key!);
    _lastDocument = raw;
    return records;
  }

  Future<void> writePasswords(List<String> passwordsJson,
      {List<String>? expectedPasswords}) {
    final expected = expectedPasswords ?? _lastReadPasswords;
    final expectedDocument = _lastDocument;
    final generation = _generation;
    final snapshot = List<String>.of(passwordsJson);
    return _serialize(() async {
      _ensureUnlocked();
      final original = await passwordFile.readAsString();
      _ensureUnlocked();
      if (original != expectedDocument ||
          (expected != null &&
              !_samePasswords(expected, _decrypt(original, _key!)))) {
        throw const PasswordStoreException('密码库已被其他设备或操作更新，请重新加载后再保存');
      }
      final committed =
          await _commit(snapshot, _key!, _salt!, original, generation);
      _lastReadPasswords = snapshot;
      _lastDocument = committed;
    });
  }

  List<String> _decrypt(String raw, Uint8List key) {
    try {
      return VaultCrypto.decrypt(jsonDecode(raw) as Map<String, dynamic>, key);
    } catch (_) {
      throw const PasswordStoreException('主密码不正确、密码库已更新或数据损坏，请重新解锁');
    }
  }

  Future<String> _commit(List<String> records, Uint8List key, Uint8List salt,
      String? original, int generation,
      {bool replaceBackup = false}) async {
    void checkSession() {
      if (generation != _generation)
        throw const PasswordStoreException('密码库已锁定，请重试');
    }

    checkSession();
    final encoded = VaultCrypto.encrypt(records, key, salt);
    _decrypt(encoded, key);
    await directory.create(recursive: true);
    checkSession();
    await temporaryFile.writeAsString(encoded, flush: true);
    _decrypt(await temporaryFile.readAsString(), key);
    checkSession();
    final current =
        await passwordFile.exists() ? await passwordFile.readAsString() : null;
    if (current != original)
      throw const PasswordStoreException('密码库已被其他设备或操作更新，请重新加载后再保存');
    // Migration and password changes must not retain a plaintext/old-key backup.
    await backupFile.writeAsString(
        replaceBackup || original == null ? encoded : original,
        flush: true);
    checkSession();
    final latest =
        await passwordFile.exists() ? await passwordFile.readAsString() : null;
    if (latest != original)
      throw const PasswordStoreException('密码库已被其他设备或操作更新，请重新加载后再保存');
    await temporaryFile.rename(passwordFile.path);
    checkSession();
    return encoded;
  }

  Future<void> validatePasswordFile() async {
    _lastReadPasswords = await _readCurrentPasswords();
  }

  Future<int> countPasswords() async => (await readPasswords()).length;

  Future<void> clearPasswords() {
    final generation = _generation;
    return _serialize(() async {
      _ensureUnlocked();
      final original = await passwordFile.readAsString();
      _ensureUnlocked();
      if (original != _lastDocument)
        throw const PasswordStoreException('密码库已被其他设备或操作更新，请重新加载后再保存');
      final committed = await _commit([], _key!, _salt!, original, generation,
          replaceBackup: true);
      _lastReadPasswords = [];
      _lastDocument = committed;
    });
  }

  Future<void> copyPasswordsTo(LocalPasswordStore target) async {
    if (directory.absolute.path == target.directory.absolute.path) return;

    final passwords = await readPasswords();
    final targetHasData = await target.passwordFile.exists() ||
        await target.backupFile.exists() ||
        await target.temporaryFile.exists();
    if (targetHasData) {
      final targetPasswords = await target.readPasswords();
      if (!_samePasswords(passwords, targetPasswords)) {
        throw const PasswordStoreException('目标目录已存在其他密码数据，请选择空目录');
      }
      return;
    }

    await target.writePasswords(passwords);
    final verified = await target.readPasswords();
    if (!_samePasswords(passwords, verified)) {
      throw const PasswordStoreException('迁移后的密码数据校验失败');
    }
  }

  bool _samePasswords(List<String> left, List<String> right) {
    if (left.length != right.length) return false;
    for (var index = 0; index < left.length; index += 1) {
      if (left[index] != right[index]) return false;
    }
    return true;
  }

  Future<void> openDataDirectory(LocalPasswordPlatform platform) async {
    await directory.create(recursive: true);
    late final ProcessResult result;
    switch (platform) {
      case LocalPasswordPlatform.macOS:
        result = await Process.run('open', [directory.path]);
        break;
      case LocalPasswordPlatform.windows:
        result = await Process.run('explorer', [directory.path]);
        break;
      case LocalPasswordPlatform.linux:
        result = await Process.run('xdg-open', [directory.path]);
        break;
    }
    if (result.exitCode != 0) {
      throw const PasswordStoreException('无法打开数据目录');
    }
  }

  List<String> _readLegacy(Map<String, dynamic> decoded) {
    if (decoded['version'] != 1 || decoded['passwords'] is! List) {
      throw const PasswordStoreException('密码数据文件格式不支持');
    }
    return (decoded['passwords'] as List).map((entry) {
      if (entry is! Map) throw const PasswordStoreException('密码记录格式无效');
      return jsonEncode(Map<String, dynamic>.from(entry));
    }).toList();
  }
}

class PasswordStoreException implements Exception {
  final String message;
  final Object? cause;

  const PasswordStoreException(this.message, {this.cause});

  @override
  String toString() => cause == null ? message : '$message：$cause';
}

class PasswordAuthenticationException extends PasswordStoreException {
  const PasswordAuthenticationException() : super('主密码不正确或密码库认证失败');
}
