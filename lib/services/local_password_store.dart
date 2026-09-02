import 'dart:convert';
import 'dart:io';

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
  static const int formatVersion = 1;

  final Directory directory;

  LocalPasswordStore({required this.directory});

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
    if (await passwordFile.exists()) {
      try {
        return await _readFile(passwordFile);
      } catch (_) {
        return _recoverFromBackup();
      }
    }

    if (await backupFile.exists()) {
      return _recoverFromBackup();
    }
    return [];
  }

  Future<void> writePasswords(List<String> passwordsJson) async {
    await directory.create(recursive: true);
    final document = _createDocument(passwordsJson);
    final encoded = const JsonEncoder.withIndent('  ').convert(document);

    await temporaryFile.writeAsString(encoded, flush: true);
    await _readFile(temporaryFile);

    var hasValidBackup = false;
    if (await passwordFile.exists()) {
      try {
        await _readFile(passwordFile);
        await passwordFile.copy(backupFile.path);
        hasValidBackup = true;
      } catch (_) {
        // A corrupt primary must never replace a valid backup.
      }
      await passwordFile.delete();
    }

    await temporaryFile.rename(passwordFile.path);
    if (!hasValidBackup) {
      await passwordFile.copy(backupFile.path);
    }
  }

  Future<int> countPasswords() async => (await readPasswords()).length;

  Future<void> clearPasswords() async {
    for (final file in [passwordFile, backupFile, temporaryFile]) {
      if (await file.exists()) await file.delete();
    }
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

  Map<String, dynamic> _createDocument(List<String> passwordsJson) {
    final passwords = passwordsJson.map((value) {
      final decoded = jsonDecode(value);
      if (decoded is! Map<String, dynamic>) {
        throw const PasswordStoreException('密码记录格式无效');
      }
      return decoded;
    }).toList();

    return {
      'version': formatVersion,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
      'passwords': passwords,
    };
  }

  Future<List<String>> _readFile(File file) async {
    try {
      final decoded = jsonDecode(await file.readAsString());
      if (decoded is! Map<String, dynamic> ||
          decoded['version'] != formatVersion ||
          decoded['passwords'] is! List) {
        throw const FormatException('unsupported password document');
      }
      return (decoded['passwords'] as List).map((entry) {
        if (entry is! Map) {
          throw const FormatException('invalid password entry');
        }
        return jsonEncode(Map<String, dynamic>.from(entry));
      }).toList();
    } catch (error) {
      throw PasswordStoreException('密码数据文件损坏', cause: error);
    }
  }

  Future<List<String>> _recoverFromBackup() async {
    if (!await backupFile.exists()) {
      throw const PasswordStoreException('密码数据文件损坏且没有可用备份');
    }
    final recovered = await _readFile(backupFile);
    await directory.create(recursive: true);
    if (await passwordFile.exists()) await passwordFile.delete();
    await backupFile.copy(passwordFile.path);
    return recovered;
  }
}

class PasswordStoreException implements Exception {
  final String message;
  final Object? cause;

  const PasswordStoreException(this.message, {this.cause});

  @override
  String toString() => cause == null ? message : '$message：$cause';
}
