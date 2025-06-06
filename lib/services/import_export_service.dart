import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';

import '../models/password_entry.dart';
// 条件导入：只在Web平台导入dart:html
import 'stub_html.dart' if (dart.library.html) 'dart:html' as html;

class ImportExportService {
  static final ImportExportService _instance = ImportExportService._internal();
  static ImportExportService get instance => _instance;

  ImportExportService._internal();

  /// 导出密码数据到JSON文件（支持加密选项）
  Future<String?> exportPasswords(
    List<PasswordEntry> passwords, {
    bool encrypt = false,
    String? masterPassword,
  }) async {
    try {
      // 准备导出数据
      final exportData = {
        'version': '1.0',
        'exportTime': DateTime.now().toIso8601String(),
        'passwordCount': passwords.length,
        'encrypted': encrypt,
        'passwords': passwords.map((p) => p.toJson()).toList(),
      };

      String jsonString =
          const JsonEncoder.withIndent('  ').convert(exportData);

      // 如果需要加密
      if (encrypt && masterPassword != null) {
        try {
          jsonString = _encryptData(jsonString, masterPassword);
          // 修改导出数据结构，包装加密数据
          final encryptedData = {
            'version': '1.0',
            'exportTime': DateTime.now().toIso8601String(),
            'encrypted': true,
            'data': jsonString,
          };
          jsonString =
              const JsonEncoder.withIndent('  ').convert(encryptedData);
        } catch (e) {
          print('数据加密失败: $e');
          return null;
        }
      }

      final String fileName = encrypt
          ? 'passwords_backup_encrypted_${DateTime.now().millisecondsSinceEpoch}.json'
          : 'passwords_backup_${DateTime.now().millisecondsSinceEpoch}.json';

      if (kIsWeb) {
        // Web平台处理
        _downloadFileOnWeb(jsonString, fileName, 'application/json');
        return fileName; // 返回文件名作为成功标识
      } else {
        // 桌面端/移动端处理 - 让用户选择保存位置
        String? outputFile = await FilePicker.platform.saveFile(
          dialogTitle: encrypt ? '选择加密密码导出位置' : '选择密码导出位置',
          fileName: fileName,
          type: FileType.custom,
          allowedExtensions: ['json'],
        );

        if (outputFile != null) {
          // 写入文件
          final File file = File(outputFile);
          await file.writeAsString(jsonString);
          return outputFile;
        } else {
          // 用户取消了保存
          return null;
        }
      }
    } catch (e) {
      print('导出失败: $e');
      return null;
    }
  }

  /// 从JSON文件导入密码数据（支持加密检测和解密）
  Future<ImportResult> importPasswords([String? decryptPassword]) async {
    try {
      // 选择文件
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['json'],
        allowMultiple: false,
      );

      if (result == null) {
        return ImportResult.cancelled();
      }

      String jsonString;

      if (kIsWeb) {
        // Web平台处理
        if (result.files.single.bytes == null) {
          return ImportResult.error('无法读取文件内容');
        }
        final bytes = result.files.single.bytes!;
        jsonString = String.fromCharCodes(bytes);
      } else {
        // 移动端/桌面端处理
        if (result.files.single.path == null) {
          return ImportResult.cancelled();
        }
        final File file = File(result.files.single.path!);
        jsonString = await file.readAsString();
      }

      // 解析JSON
      final Map<String, dynamic> data = jsonDecode(jsonString);

      // 检查是否是加密文件
      if (data['encrypted'] == true && data.containsKey('data')) {
        // 这是加密文件，需要解密
        if (decryptPassword == null) {
          return ImportResult.needsDecryption('此文件已加密，需要输入主密码进行解密',
              fileContent: jsonString);
        }

        try {
          final decryptedData =
              _decryptData(data['data'] as String, decryptPassword);
          final decryptedJson =
              jsonDecode(decryptedData) as Map<String, dynamic>;
          return _parsePasswordData(decryptedJson);
        } catch (e) {
          return ImportResult.error('解密失败：密码可能不正确或文件已损坏');
        }
      } else {
        // 明文文件，直接解析
        return _parsePasswordData(data);
      }
    } catch (e) {
      print('导入失败: $e');
      return ImportResult.error('导入失败: $e');
    }
  }

  /// 从文件内容导入密码数据（用于处理已选择的加密文件）
  Future<ImportResult> importPasswordsFromContent(
      String fileContent, String decryptPassword) async {
    try {
      // 解析JSON
      final Map<String, dynamic> data = jsonDecode(fileContent);

      // 检查是否是加密文件
      if (data['encrypted'] == true && data.containsKey('data')) {
        try {
          final decryptedData =
              _decryptData(data['data'] as String, decryptPassword);
          final decryptedJson =
              jsonDecode(decryptedData) as Map<String, dynamic>;
          return _parsePasswordData(decryptedJson);
        } catch (e) {
          return ImportResult.error('解密失败：密码可能不正确或文件已损坏');
        }
      } else {
        // 明文文件，直接解析
        return _parsePasswordData(data);
      }
    } catch (e) {
      print('导入失败: $e');
      return ImportResult.error('导入失败: $e');
    }
  }

  /// 解析密码数据的通用方法
  ImportResult _parsePasswordData(Map<String, dynamic> data) {
    try {
      // 验证数据格式
      if (!data.containsKey('passwords') || !data.containsKey('version')) {
        return ImportResult.error('无效的备份文件格式');
      }

      // 解析密码条目
      final List<dynamic> passwordsData = data['passwords'] as List<dynamic>;
      final List<PasswordEntry> passwords = [];

      for (final passwordData in passwordsData) {
        try {
          final password =
              PasswordEntry.fromJson(passwordData as Map<String, dynamic>);
          passwords.add(password);
        } catch (e) {
          print('解析密码条目失败: $e');
          // 跳过无效的条目，继续处理其他条目
        }
      }

      return ImportResult.success(
        passwords: passwords,
        totalCount: passwordsData.length,
        successCount: passwords.length,
        version: data['version'] as String?,
        exportTime: data['exportTime'] as String?,
        wasEncrypted: data['encrypted'] == true,
      );
    } catch (e) {
      return ImportResult.error('解析数据失败: $e');
    }
  }

  /// 检查文件是否为加密文件
  Future<bool> isEncryptedFile(String? filePath, [Uint8List? bytes]) async {
    try {
      String content;
      if (kIsWeb && bytes != null) {
        content = String.fromCharCodes(bytes);
      } else if (filePath != null) {
        final File file = File(filePath);
        content = await file.readAsString();
      } else {
        return false;
      }

      final Map<String, dynamic> data = jsonDecode(content);
      return data['encrypted'] == true && data.containsKey('data');
    } catch (e) {
      return false;
    }
  }

  /// 使用简单的对称加密方法加密数据
  String _encryptData(String data, String password) {
    final key = _deriveKey(password);
    final dataBytes = utf8.encode(data);
    final encryptedBytes = <int>[];

    for (int i = 0; i < dataBytes.length; i++) {
      final keyIndex = i % key.length;
      encryptedBytes.add(dataBytes[i] ^ key[keyIndex]);
    }

    return base64Encode(encryptedBytes);
  }

  /// 使用简单的对称加密方法解密数据
  String _decryptData(String encryptedData, String password) {
    final key = _deriveKey(password);
    final encryptedBytes = base64Decode(encryptedData);
    final decryptedBytes = <int>[];

    for (int i = 0; i < encryptedBytes.length; i++) {
      final keyIndex = i % key.length;
      decryptedBytes.add(encryptedBytes[i] ^ key[keyIndex]);
    }

    return utf8.decode(decryptedBytes);
  }

  /// 从密码派生密钥
  List<int> _deriveKey(String password) {
    // 使用 PBKDF2 类似的方法派生密钥
    final bytes = utf8.encode(password + 'password_manager_encrypt_salt');
    var hash = sha256.convert(bytes);

    // 进行多轮哈希增强安全性
    for (int i = 0; i < 1000; i++) {
      hash = sha256.convert(hash.bytes);
    }

    return hash.bytes;
  }

  /// 导出到CSV格式
  Future<String?> exportToCSV(List<PasswordEntry> passwords) async {
    try {
      final StringBuffer csvBuffer = StringBuffer();

      // CSV 头部
      csvBuffer.writeln('标题,用户名,密码,网站,分类,备注,创建时间,更新时间');

      // 数据行
      for (final password in passwords) {
        final List<String> row = [
          _escapeCsvField(password.title),
          _escapeCsvField(password.username),
          _escapeCsvField(password.password),
          _escapeCsvField(password.website ?? ''),
          _escapeCsvField(password.category ?? ''),
          _escapeCsvField(password.notes ?? ''),
          _escapeCsvField(password.createdAt.toIso8601String()),
          _escapeCsvField(password.updatedAt.toIso8601String()),
        ];
        csvBuffer.writeln(row.join(','));
      }

      final String fileName =
          'passwords_export_${DateTime.now().millisecondsSinceEpoch}.csv';

      if (kIsWeb) {
        // Web平台处理
        _downloadFileOnWeb(csvBuffer.toString(), fileName, 'text/csv');
        return fileName;
      } else {
        // 桌面端/移动端处理 - 让用户选择保存位置
        String? outputFile = await FilePicker.platform.saveFile(
          dialogTitle: '选择CSV导出位置',
          fileName: fileName,
          type: FileType.custom,
          allowedExtensions: ['csv'],
        );

        if (outputFile != null) {
          // 写入文件
          final File file = File(outputFile);
          await file.writeAsString(csvBuffer.toString());
          return outputFile;
        } else {
          // 用户取消了保存
          return null;
        }
      }
    } catch (e) {
      print('CSV导出失败: $e');
      return null;
    }
  }

  /// Web平台文件下载
  void _downloadFileOnWeb(String content, String fileName, String mimeType) {
    if (kIsWeb) {
      try {
        final bytes = utf8.encode(content);
        final blob = html.Blob([bytes], mimeType);
        final url = html.Url.createObjectUrlFromBlob(blob);

        html.AnchorElement(href: url)
          ..setAttribute('download', fileName)
          ..click();

        html.Url.revokeObjectUrl(url);
      } catch (e) {
        print('Web下载失败: $e');
      }
    }
  }

  /// 转义CSV字段
  String _escapeCsvField(String field) {
    // 如果字段包含逗号、引号或换行符，需要用引号包围
    if (field.contains(',') ||
        field.contains('"') ||
        field.contains('\n') ||
        field.contains('\r')) {
      // 转义引号
      final escaped = field.replaceAll('"', '""');
      return '"$escaped"';
    }
    return field;
  }

  /// 验证导入文件格式
  Future<bool> validateImportFile(String? filePath, [Uint8List? bytes]) async {
    try {
      String content;
      if (kIsWeb && bytes != null) {
        content = String.fromCharCodes(bytes);
      } else if (filePath != null) {
        final File file = File(filePath);
        content = await file.readAsString();
      } else {
        return false;
      }

      final Map<String, dynamic> data = jsonDecode(content);

      // 检查是否是加密文件
      if (data['encrypted'] == true && data.containsKey('data')) {
        return true; // 加密文件格式有效
      }

      // 检查明文文件格式
      return data.containsKey('passwords') &&
          data.containsKey('version') &&
          data['passwords'] is List;
    } catch (e) {
      return false;
    }
  }

  /// 合并密码数据（处理重复项）
  List<PasswordEntry> mergePasswords(
    List<PasswordEntry> existingPasswords,
    List<PasswordEntry> importedPasswords, {
    MergeStrategy strategy = MergeStrategy.keepBoth,
  }) {
    final List<PasswordEntry> result = List.from(existingPasswords);

    // 获取当前最大ID，确保新ID不会冲突
    int maxId = 0;
    for (final password in result) {
      if (password.id != null && password.id! > maxId) {
        maxId = password.id!;
      }
    }

    for (final imported in importedPasswords) {
      final existingIndex = result.indexWhere((existing) =>
          existing.title == imported.title &&
          existing.username == imported.username);

      if (existingIndex != -1) {
        // 找到重复项
        switch (strategy) {
          case MergeStrategy.keepExisting:
            // 保留现有的，跳过导入的
            break;
          case MergeStrategy.keepImported:
            // 用导入的替换现有的，但保持现有的ID
            final updatedImported = imported.copyWith(
              id: result[existingIndex].id,
            );
            result[existingIndex] = updatedImported;
            break;
          case MergeStrategy.keepBoth:
            // 两个都保留，给导入的添加后缀和新ID
            maxId++;
            final modifiedImported = imported.copyWith(
              id: maxId,
              title: '${imported.title} (导入)',
            );
            result.add(modifiedImported);
            break;
        }
      } else {
        // 没有重复，分配新ID后添加
        maxId++;
        final importedWithId = imported.copyWith(id: maxId);
        result.add(importedWithId);
      }
    }

    return result;
  }
}

/// 导入结果封装类
class ImportResult {
  final bool success;
  final List<PasswordEntry> passwords;
  final String? errorMessage;
  final int totalCount;
  final int successCount;
  final String? version;
  final String? exportTime;
  final bool needsDecryption;
  final bool wasEncrypted;
  final String? fileContent;

  ImportResult._({
    required this.success,
    required this.passwords,
    this.errorMessage,
    required this.totalCount,
    required this.successCount,
    this.version,
    this.exportTime,
    this.needsDecryption = false,
    this.wasEncrypted = false,
    this.fileContent,
  });

  factory ImportResult.success({
    required List<PasswordEntry> passwords,
    required int totalCount,
    required int successCount,
    String? version,
    String? exportTime,
    bool wasEncrypted = false,
  }) {
    return ImportResult._(
      success: true,
      passwords: passwords,
      totalCount: totalCount,
      successCount: successCount,
      version: version,
      exportTime: exportTime,
      wasEncrypted: wasEncrypted,
    );
  }

  factory ImportResult.error(String message) {
    return ImportResult._(
      success: false,
      passwords: [],
      errorMessage: message,
      totalCount: 0,
      successCount: 0,
    );
  }

  factory ImportResult.cancelled() {
    return ImportResult._(
      success: false,
      passwords: [],
      errorMessage: '用户取消操作',
      totalCount: 0,
      successCount: 0,
    );
  }

  factory ImportResult.needsDecryption(String message, {String? fileContent}) {
    return ImportResult._(
      success: false,
      passwords: [],
      errorMessage: message,
      totalCount: 0,
      successCount: 0,
      needsDecryption: true,
      fileContent: fileContent,
    );
  }

  bool get isCancelled => errorMessage == '用户取消操作';

  /// 是否有失败的条目
  bool get hasFailures => totalCount > successCount;

  /// 失败条目数量
  int get failureCount => totalCount - successCount;
}

/// 合并策略枚举
enum MergeStrategy {
  keepExisting, // 保留现有的
  keepImported, // 保留导入的
  keepBoth, // 两个都保留
}
