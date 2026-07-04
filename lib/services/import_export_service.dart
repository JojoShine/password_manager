import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:pointycastle/export.dart';

import '../models/password_entry.dart';
// 条件导入：只在Web平台导入dart:html
import 'stub_html.dart' if (dart.library.html) 'dart:html' as html;

class ImportExportService {
  static final ImportExportService _instance = ImportExportService._internal();
  static ImportExportService get instance => _instance;

  ImportExportService._internal();

  /// 导出密码数据到JSON文件（支持加密）
  Future<String?> exportPasswords(
    List<PasswordEntry> passwords, {
    bool encrypt = false,
    String? masterPassword,
  }) async {
    try {
    // print('开始导出密码数据，加密: $encrypt，密码数量: ${passwords.length}');

      // 构建导出数据
      final Map<String, dynamic> exportData = {
        'version': '1.0.0',
        'exportTime': DateTime.now().toIso8601String(),
        'encrypted': encrypt,
        'passwordCount': passwords.length,
        'passwords': passwords.map((p) => p.toJson()).toList(),
      };

      String jsonString;
      String fileName;

      if (encrypt) {
        if (masterPassword == null || masterPassword.isEmpty) {
    // print('导出失败：缺少主密码');
          throw Exception('主密码不能为空');
        }

        // 加密数据
        final dataToEncrypt = jsonEncode({
          'version': '1.0.0',
          'exportTime': DateTime.now().toIso8601String(),
          'passwordCount': passwords.length,
          'passwords': passwords.map((p) => p.toJson()).toList(),
        });

        final encryptedData = _encryptData(dataToEncrypt, masterPassword);

        final encryptedExportData = {
          'version': '2.0.0',
          'exportTime': DateTime.now().toIso8601String(),
          'encrypted': true,
          'encryption': 'aes-256-cbc',
          'data': encryptedData,
        };

        jsonString = jsonEncode(encryptedExportData);
        fileName =
            'passwords_encrypted_${DateTime.now().millisecondsSinceEpoch}.json';
      } else {
        jsonString = jsonEncode(exportData);
        fileName = 'passwords_${DateTime.now().millisecondsSinceEpoch}.json';
      }

    // print('准备保存文件: $fileName');

      if (kIsWeb) {
        // Web平台处理
    // print('Web平台导出');
        _downloadFileOnWeb(jsonString, fileName, 'application/json');
        return fileName; // 返回文件名作为成功标识
      } else {
        // 桌面端/移动端处理 - 让用户选择保存位置
    // print('桌面端导出，显示文件保存对话框');

        String? outputFile = await FilePicker.platform.saveFile(
          dialogTitle: encrypt ? '选择加密密码导出位置' : '选择密码导出位置',
          fileName: fileName,
          type: FileType.custom,
          allowedExtensions: ['json'],
        );

    // print('文件选择结果: $outputFile');

        if (outputFile != null) {
          // 写入文件
    // print('写入文件: $outputFile');
          final File file = File(outputFile);
          await file.writeAsString(jsonString);
    // print('文件写入成功');
          return outputFile;
        } else {
          // 用户取消了保存
    // print('用户取消了文件保存');
          return null;
        }
      }
    } catch (e) {
    // print('导出失败: $e');
      return null;
    }
  }

  /// 从JSON文件导入密码数据（支持加密检测和解密）
  Future<ImportResult> importPasswords([String? decryptPassword]) async {
    try {
    // print('开始导入密码数据');

      // 选择文件
    // print('显示文件选择对话框');
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['json'],
        allowMultiple: false,
      );

    // print('文件选择结果: ${result?.files.length ?? 0} 个文件');

      if (result == null) {
    // print('用户取消了文件选择');
        return ImportResult.cancelled();
      }

      String jsonString;

      if (kIsWeb) {
        // Web平台处理
    // print('Web平台导入');
        if (result.files.single.bytes == null) {
    // print('无法读取文件内容（bytes为null）');
          return ImportResult.error('无法读取文件内容');
        }
        final bytes = result.files.single.bytes!;
        jsonString = String.fromCharCodes(bytes);
    // print('文件内容长度: ${jsonString.length}');
      } else {
        // 移动端/桌面端处理
    // print('桌面端导入');
        if (result.files.single.path == null) {
    // print('文件路径为null');
          return ImportResult.cancelled();
        }
        final File file = File(result.files.single.path!);
    // print('读取文件: ${file.path}');
        jsonString = await file.readAsString();
    // print('文件内容长度: ${jsonString.length}');
      }

      // 解析JSON
    // print('解析JSON数据');
      final Map<String, dynamic> data = jsonDecode(jsonString);
    // print('JSON解析成功，encrypted: ${data['encrypted']}');

      // 检查是否是加密文件
      if (data['encrypted'] == true && data.containsKey('data')) {
        // 这是加密文件，需要解密
    // print('检测到加密文件');
        if (decryptPassword == null) {
    // print('需要解密密码');
          return ImportResult.needsDecryption('此文件已加密，需要输入主密码进行解密',
              fileContent: jsonString);
        }

        try {
    // print('尝试解密数据');
          final decryptedData =
              _decryptData(data['data'] as String, decryptPassword);
          final decryptedJson =
              jsonDecode(decryptedData) as Map<String, dynamic>;
    // print('解密成功');
          return _parsePasswordData(decryptedJson, wasEncrypted: true);
        } catch (e) {
    // print('解密失败: $e');
          return ImportResult.error('解密失败：密码可能不正确或文件已损坏');
        }
      } else {
        // 明文文件，直接解析
    // print('处理明文文件');
        return _parsePasswordData(data);
      }
    } catch (e) {
    // print('导入失败: $e');
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
          return _parsePasswordData(decryptedJson, wasEncrypted: true);
        } catch (e) {
          return ImportResult.error('解密失败：密码可能不正确或文件已损坏');
        }
      } else {
        // 明文文件，直接解析
        return _parsePasswordData(data);
      }
    } catch (e) {
    // print('导入失败: $e');
      return ImportResult.error('导入失败: $e');
    }
  }

  /// 解析密码数据的通用方法
  ImportResult _parsePasswordData(Map<String, dynamic> data, {bool wasEncrypted = false}) {
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
    // print('解析密码条目失败: $e');
          // 跳过无效的条目，继续处理其他条目
        }
      }

      return ImportResult.success(
        passwords: passwords,
        totalCount: passwordsData.length,
        successCount: passwords.length,
        version: data['version'] as String?,
        exportTime: data['exportTime'] as String?,
        wasEncrypted: wasEncrypted,
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

  /// AES-256-CBC 加密数据（新格式）
  String _encryptData(String data, String password) {
    final random = Random.secure();
    // 生成随机盐值（16字节）和 IV（16字节）
    final salt = Uint8List.fromList(
      List<int>.generate(16, (_) => random.nextInt(256)),
    );
    final iv = Uint8List.fromList(
      List<int>.generate(16, (_) => random.nextInt(256)),
    );

    // 使用 PBKDF2 派生 256 位密钥
    final key = _deriveKeyFromPassword(password, salt);

    // AES-256-CBC 加密
    final cipher = CBCBlockCipher(AESEngine())
      ..init(true, ParametersWithIV(KeyParameter(key), iv));

    final dataBytes = Uint8List.fromList(utf8.encode(data));
    final paddedData = _pkcs7Pad(dataBytes, 16);
    final encryptedBytes = Uint8List(paddedData.length);

    for (int offset = 0; offset < paddedData.length; offset += 16) {
      cipher.processBlock(paddedData, offset, encryptedBytes, offset);
    }

    // 格式: salt(16) + iv(16) + ciphertext
    final result = Uint8List(salt.length + iv.length + encryptedBytes.length);
    result.setAll(0, salt);
    result.setAll(16, iv);
    result.setAll(32, encryptedBytes);

    return base64Encode(result);
  }

  /// 解密数据（自动检测新旧格式，向后兼容旧版 XOR 加密）
  String _decryptData(String encryptedData, String password) {
    final allBytes = base64Decode(encryptedData);

    // 检测格式：新格式至少 48 字节（16 salt + 16 iv + 16 密文块），
    // 且第33字节应为 0x50 ('P') 作为 "PM" 标记
    if (allBytes.length >= 48 && allBytes[32] == 0x50 && allBytes[33] == 0x4D) {
      return _decryptDataAes(allBytes, password);
    }
    // 向后兼容：旧版 XOR 格式
    return _decryptDataLegacy(allBytes, password);
  }

  /// AES-256-CBC 解密（新格式）
  String _decryptDataAes(Uint8List allBytes, String password) {
    final salt = allBytes.sublist(0, 16);
    final iv = allBytes.sublist(16, 32);
    final ciphertext = allBytes.sublist(32);

    final key = _deriveKeyFromPassword(password, Uint8List.fromList(salt));

    final cipher = CBCBlockCipher(AESEngine())
      ..init(false, ParametersWithIV(KeyParameter(key), Uint8List.fromList(iv)));

    final decryptedBytes = Uint8List(ciphertext.length);
    for (int offset = 0; offset < ciphertext.length; offset += 16) {
      cipher.processBlock(ciphertext, offset, decryptedBytes, offset);
    }

    final unpadded = _pkcs7Unpad(decryptedBytes);
    return utf8.decode(unpadded);
  }

  /// 旧版 XOR 解密（向后兼容）
  String _decryptDataLegacy(Uint8List encryptedBytes, String password) {
    final key = _deriveKeyLegacy(password);
    final decryptedBytes = <int>[];

    for (int i = 0; i < encryptedBytes.length; i++) {
      final keyIndex = i % key.length;
      decryptedBytes.add(encryptedBytes[i] ^ key[keyIndex]);
    }

    return utf8.decode(decryptedBytes);
  }

  /// PBKDF2-SHA256 派生密钥（新格式，使用随机盐值）
  Uint8List _deriveKeyFromPassword(String password, Uint8List salt) {
    return _pbkdf2Sha256(utf8.encode(password), salt, 10000, 32);
  }

  /// 手动实现 PBKDF2-HMAC-SHA256
  Uint8List _pbkdf2Sha256(List<int> password, Uint8List salt, int iterations, int keyLength) {
    final hmac = Hmac(sha256, password);
    final result = Uint8List(keyLength);
    int blockIndex = 1;
    int derivedLength = 0;

    while (derivedLength < keyLength) {
      // U1 = HMAC(password, salt + INT_32_BE(blockIndex))
      final saltBlock = Uint8List(salt.length + 4);
      saltBlock.setAll(0, salt);
      saltBlock[salt.length] = (blockIndex >> 24) & 0xFF;
      saltBlock[salt.length + 1] = (blockIndex >> 16) & 0xFF;
      saltBlock[salt.length + 2] = (blockIndex >> 8) & 0xFF;
      saltBlock[salt.length + 3] = blockIndex & 0xFF;

      var u = Uint8List.fromList(hmac.convert(saltBlock).bytes);
      var block = Uint8List.fromList(u);

      // U2..Uc
      for (int i = 1; i < iterations; i++) {
        u = Uint8List.fromList(hmac.convert(u).bytes);
        for (int j = 0; j < block.length; j++) {
          block[j] ^= u[j];
        }
      }

      final copyLength = keyLength - derivedLength > block.length
          ? block.length
          : keyLength - derivedLength;
      result.setAll(derivedLength, block.sublist(0, copyLength));
      derivedLength += copyLength;
      blockIndex++;
    }

    return result;
  }

  /// 旧版密钥派生（向后兼容）
  List<int> _deriveKeyLegacy(String password) {
    final bytes = utf8.encode(password + 'password_manager_encrypt_salt');
    var hash = sha256.convert(bytes);
    for (int i = 0; i < 1000; i++) {
      hash = sha256.convert(hash.bytes);
    }
    return hash.bytes;
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
      if (data[i] != padLength) return data; // 填充无效
    }
    return Uint8List.fromList(data.sublist(0, data.length - padLength));
  }

  /// 导出到CSV格式
  Future<String?> exportToCSV(List<PasswordEntry> passwords) async {
    try {
    // print('开始CSV导出，密码数量: ${passwords.length}');

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

    // print('准备保存CSV文件: $fileName');

      if (kIsWeb) {
        // Web平台处理
    // print('Web平台CSV导出');
        _downloadFileOnWeb(csvBuffer.toString(), fileName, 'text/csv');
        return fileName;
      } else {
        // 桌面端/移动端处理 - 让用户选择保存位置
    // print('桌面端CSV导出，显示文件保存对话框');
        String? outputFile = await FilePicker.platform.saveFile(
          dialogTitle: '选择CSV导出位置',
          fileName: fileName,
          type: FileType.custom,
          allowedExtensions: ['csv'],
        );

    // print('CSV文件选择结果: $outputFile');

        if (outputFile != null) {
          // 写入文件
    // print('写入CSV文件: $outputFile');
          final File file = File(outputFile);
          await file.writeAsString(csvBuffer.toString());
    // print('CSV文件写入成功');
          return outputFile;
        } else {
          // 用户取消了保存
    // print('用户取消了CSV文件保存');
          return null;
        }
      }
    } catch (e) {
    // print('CSV导出失败: $e');
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
    // print('Web下载失败: $e');
      }
    }
  }

  /// 从CSV文件导入密码数据
  Future<ImportResult> importFromCSV() async {
    try {
      // 选择文件
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['csv'],
        allowMultiple: false,
      );

      if (result == null) {
        return ImportResult.cancelled();
      }

      String csvString;

      if (kIsWeb) {
        if (result.files.single.bytes == null) {
          return ImportResult.error('无法读取文件内容');
        }
        final bytes = result.files.single.bytes!;
        csvString = String.fromCharCodes(bytes);
      } else {
        if (result.files.single.path == null) {
          return ImportResult.cancelled();
        }
        final File file = File(result.files.single.path!);
        csvString = await file.readAsString();
      }

      return _parseCSVContent(csvString);
    } catch (e) {
      return ImportResult.error('CSV导入失败: $e');
    }
  }

  /// 解析CSV内容
  ImportResult _parseCSVContent(String csvContent) {
    try {
      final rawLines = _splitCSVLines(csvContent);
      if (rawLines.isEmpty) {
        return ImportResult.error('CSV文件为空');
      }

      // 第一行为头部，识别列映射
      final header = rawLines.first;
      final columnMap = _buildCSVColumnMap(header);

      if (columnMap == null) {
        return ImportResult.error('无法识别CSV文件格式，请确保包含标题、用户名、密码列');
      }

      final List<PasswordEntry> passwords = [];

      for (int i = 1; i < rawLines.length; i++) {
        final fields = rawLines[i];
        if (fields.isEmpty) continue;

        try {
          if (fields.length < columnMap.length) {
            continue;
          }

          final title = fields[columnMap['title']!].trim();
          final username = fields[columnMap['username']!].trim();
          final password = fields[columnMap['password']!].trim();

          // 标题、用户名、密码为必填
          if (title.isEmpty && username.isEmpty && password.isEmpty) {
            continue;
          }

          final website = columnMap.containsKey('website')
              ? fields[columnMap['website']!].trim()
              : '';
          final category = columnMap.containsKey('category')
              ? fields[columnMap['category']!].trim()
              : '';
          final notes = columnMap.containsKey('notes')
              ? fields[columnMap['notes']!].trim()
              : '';

          DateTime? createdAt;
          DateTime? updatedAt;

          if (columnMap.containsKey('createdAt')) {
            final dateStr = fields[columnMap['createdAt']!].trim();
            if (dateStr.isNotEmpty) {
              try {
                createdAt = DateTime.parse(dateStr);
              } catch (_) {}
            }
          }

          if (columnMap.containsKey('updatedAt')) {
            final dateStr = fields[columnMap['updatedAt']!].trim();
            if (dateStr.isNotEmpty) {
              try {
                updatedAt = DateTime.parse(dateStr);
              } catch (_) {}
            }
          }

          passwords.add(PasswordEntry(
            title: title.isNotEmpty ? title : '未命名',
            username: username,
            password: password,
            website: website.isNotEmpty ? website : null,
            category: category.isNotEmpty ? category : null,
            notes: notes.isNotEmpty ? notes : null,
            createdAt: createdAt ?? DateTime.now(),
            updatedAt: updatedAt ?? DateTime.now(),
          ));
        } catch (e) {
          // 跳过解析失败的行
        }
      }

      return ImportResult.success(
        passwords: passwords,
        totalCount: rawLines.length - 1, // 减去头部
        successCount: passwords.length,
      );
    } catch (e) {
      return ImportResult.error('解析CSV文件失败: $e');
    }
  }

  /// 构建CSV列映射
  Map<String, int>? _buildCSVColumnMap(List<String> header) {
    final map = <String, int>{};

    // 支持的列名映射（支持中英文）
    final columnAliases = {
      'title': ['标题', 'title', '名称', 'name'],
      'username': ['用户名', 'username', 'user', 'email', '邮箱', '账号', 'account'],
      'password': ['密码', 'password', 'pass', 'pwd'],
      'website': ['网站', 'website', 'url', '网址', '链接', 'link'],
      'category': ['分类', 'category', 'group', '分组', '类型', 'type'],
      'notes': ['备注', 'notes', 'note', 'comment', '注释', '说明'],
      'createdAt': ['创建时间', 'createdat', 'created', 'creation_date'],
      'updatedAt': ['更新时间', 'updatedat', 'updated', 'modified', 'last_modified'],
    };

    for (int i = 0; i < header.length; i++) {
      final normalized = header[i].trim().toLowerCase();
      for (final entry in columnAliases.entries) {
        if (entry.value.contains(normalized) && !map.containsKey(entry.key)) {
          map[entry.key] = i;
        }
      }
    }

    // 必须包含标题、用户名、密码三列
    if (!map.containsKey('title') ||
        !map.containsKey('username') ||
        !map.containsKey('password')) {
      return null;
    }

    return map;
  }

  /// 分割CSV行为列表（处理引号内的换行）
  List<List<String>> _splitCSVLines(String content) {
    final result = <List<String>>[];
    final lines = <String>[];
    var currentLine = StringBuffer();
    var inQuotes = false;

    for (int i = 0; i < content.length; i++) {
      final char = content[i];

      if (char == '"') {
        // 检查是否是转义的引号
        if (inQuotes && i + 1 < content.length && content[i + 1] == '"') {
          currentLine.write('""');
          i++; // 跳过下一个引号
        } else {
          inQuotes = !inQuotes;
          currentLine.write(char);
        }
      } else if ((char == '\n' || char == '\r') && !inQuotes) {
        if (char == '\r' && i + 1 < content.length && content[i + 1] == '\n') {
          i++; // 跳过 \n
        }
        final line = currentLine.toString().trim();
        if (line.isNotEmpty) {
          lines.add(line);
        }
        currentLine = StringBuffer();
      } else {
        currentLine.write(char);
      }
    }

    // 处理最后一行
    final lastLine = currentLine.toString().trim();
    if (lastLine.isNotEmpty) {
      lines.add(lastLine);
    }

    for (final line in lines) {
      result.add(_parseCSVLine(line));
    }

    return result;
  }

  /// 解析CSV单行（正确处理引号包裹的字段）
  List<String> _parseCSVLine(String line) {
    final fields = <String>[];
    final currentField = StringBuffer();
    var inQuotes = false;

    for (int i = 0; i < line.length; i++) {
      final char = line[i];

      if (char == '"') {
        if (inQuotes && i + 1 < line.length && line[i + 1] == '"') {
          // 转义的引号
          currentField.write('"');
          i++;
        } else {
          // 切换引号状态
          inQuotes = !inQuotes;
        }
      } else if (char == ',' && !inQuotes) {
        fields.add(currentField.toString());
        currentField.clear();
      } else {
        currentField.write(char);
      }
    }

    fields.add(currentField.toString());
    return fields;
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
