import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/password_entry.dart';

/// 本地HTTP服务器服务
/// 用于与浏览器扩展进行无感知的本地通信
class LocalServerService {
  static LocalServerService? _instance;
  static LocalServerService get instance =>
      _instance ??= LocalServerService._();

  LocalServerService._();

  HttpServer? _server;
  String? _serverToken;
  int? _serverPort;
  bool _isRunning = false;

  /// 启动本地服务器
  Future<bool> startServer() async {
    if (_isRunning) return true;

    try {
      // 生成随机端口和安全token
      _serverPort = _generateRandomPort();
      _serverToken = _generateSecureToken();

      // 启动HTTP服务器
      _server =
          await HttpServer.bind(InternetAddress.loopbackIPv4, _serverPort!);

      // 设置请求处理
      _server!.listen(_handleRequest);

      // 写入配置文件供浏览器扩展读取
      await _writeServerConfig();

      _isRunning = true;

      debugPrint('密码管理器本地服务器已启动: http://127.0.0.1:$_serverPort');
      debugPrint('服务器Token: $_serverToken');

      return true;
    } catch (e) {
      debugPrint('启动本地服务器失败: $e');
      return false;
    }
  }

  /// 停止本地服务器
  Future<void> stopServer() async {
    if (_server != null) {
      await _server!.close();
      _server = null;
    }

    // 删除配置文件
    await _deleteServerConfig();

    _isRunning = false;
    _serverPort = null;
    _serverToken = null;

    debugPrint('密码管理器本地服务器已停止');
  }

  /// 处理HTTP请求
  Future<void> _handleRequest(HttpRequest request) async {
    // 设置CORS头，允许浏览器扩展访问
    request.response.headers.set('Access-Control-Allow-Origin', '*');
    request.response.headers
        .set('Access-Control-Allow-Methods', 'GET, POST, PUT, DELETE, OPTIONS');
    request.response.headers.set('Access-Control-Allow-Headers',
        'Content-Type, Authorization, X-Requested-With');
    request.response.headers.set('Access-Control-Max-Age', '86400');

    // 处理预检请求
    if (request.method == 'OPTIONS') {
      request.response.statusCode = 200;
      await request.response.close();
      return;
    }

    try {
      // 配置端点不需要token验证
      if (request.uri.path == '/config') {
        await _routeRequest(request);
        return;
      }

      // 验证token
      final authHeader = request.headers.value('Authorization');
      if (authHeader != 'Bearer $_serverToken') {
        await _sendErrorResponse(request.response, 401, '未授权访问');
        return;
      }

      // 路由请求
      await _routeRequest(request);
    } catch (e) {
      debugPrint('处理请求失败: $e');
      await _sendErrorResponse(request.response, 500, '服务器内部错误');
    }
  }

  /// 路由请求到相应的处理器
  Future<void> _routeRequest(HttpRequest request) async {
    final path = request.uri.path;
    final method = request.method;

    switch ('$method $path') {
      case 'GET /config':
        await _handleGetConfig(request);
        break;
      case 'GET /api/ping':
        await _handlePing(request);
        break;
      case 'GET /api/passwords':
        await _handleGetPasswords(request);
        break;
      case 'GET /api/passwords/domain':
        await _handleGetPasswordsByDomain(request);
        break;
      case 'POST /api/passwords':
        await _handleSavePassword(request);
        break;
      case 'PUT /api/passwords':
        await _handleUpdatePassword(request);
        break;
      case 'DELETE /api/passwords':
        await _handleDeletePassword(request);
        break;
      default:
        await _sendErrorResponse(request.response, 404, '接口不存在');
    }
  }

  /// 处理配置请求
  Future<void> _handleGetConfig(HttpRequest request) async {
    // 不需要token验证，配置信息是公开的
    final config = {
      'server_url': 'http://127.0.0.1:$_serverPort',
      'token': _serverToken,
      'pid': pid,
      'timestamp': DateTime.now().toIso8601String(),
      'api_version': '1.0.0',
    };

    await _sendSuccessResponse(request.response, config);
  }

  /// 处理ping请求
  Future<void> _handlePing(HttpRequest request) async {
    await _sendSuccessResponse(request.response, {
      'message': 'pong',
      'timestamp': DateTime.now().toIso8601String(),
      'version': '1.0.0',
    });
  }

  /// 处理获取密码列表请求
  Future<void> _handleGetPasswords(HttpRequest request) async {
    try {
      final query = request.uri.queryParameters['q'] ?? '';
      final passwords = await PasswordService.searchPasswords(query);

      await _sendSuccessResponse(request.response, {
        'passwords': passwords.map((p) => p.toJson()).toList(),
        'total': passwords.length,
      });
    } catch (e) {
      await _sendErrorResponse(request.response, 500, '获取密码失败: $e');
    }
  }

  /// 处理根据域名获取密码请求
  Future<void> _handleGetPasswordsByDomain(HttpRequest request) async {
    try {
      final domain = request.uri.queryParameters['domain'];
      if (domain == null || domain.isEmpty) {
        await _sendErrorResponse(request.response, 400, '缺少域名参数');
        return;
      }

      final passwords = await PasswordService.getPasswordsByDomain(domain);

      await _sendSuccessResponse(request.response, {
        'passwords': passwords.map((p) => p.toJson()).toList(),
        'domain': domain,
        'total': passwords.length,
      });
    } catch (e) {
      await _sendErrorResponse(request.response, 500, '获取密码失败: $e');
    }
  }

  /// 处理保存密码请求
  Future<void> _handleSavePassword(HttpRequest request) async {
    try {
      final body = await _readRequestBody(request);
      final data = jsonDecode(body) as Map<String, dynamic>;

      final passwordEntry = PasswordEntry.fromJson(data);
      final savedPassword = await PasswordService.savePassword(passwordEntry);

      await _sendSuccessResponse(request.response, {
        'message': '密码保存成功',
        'password': savedPassword.toJson(),
      });
    } catch (e) {
      await _sendErrorResponse(request.response, 500, '保存密码失败: $e');
    }
  }

  /// 处理更新密码请求
  Future<void> _handleUpdatePassword(HttpRequest request) async {
    try {
      final body = await _readRequestBody(request);
      final data = jsonDecode(body) as Map<String, dynamic>;

      final id = data['id'] as int?;
      if (id == null) {
        await _sendErrorResponse(request.response, 400, '缺少密码ID');
        return;
      }

      final passwordEntry = PasswordEntry.fromJson(data);
      final updatedPassword =
          await PasswordService.updatePassword(id, passwordEntry);

      await _sendSuccessResponse(request.response, {
        'message': '密码更新成功',
        'password': updatedPassword.toJson(),
      });
    } catch (e) {
      await _sendErrorResponse(request.response, 500, '更新密码失败: $e');
    }
  }

  /// 处理删除密码请求
  Future<void> _handleDeletePassword(HttpRequest request) async {
    try {
      final idStr = request.uri.queryParameters['id'];
      final id = int.tryParse(idStr ?? '');

      if (id == null) {
        await _sendErrorResponse(request.response, 400, '无效的密码ID');
        return;
      }

      await PasswordService.deletePassword(id);

      await _sendSuccessResponse(request.response, {
        'message': '密码删除成功',
        'id': id,
      });
    } catch (e) {
      await _sendErrorResponse(request.response, 500, '删除密码失败: $e');
    }
  }

  /// 读取请求体
  Future<String> _readRequestBody(HttpRequest request) async {
    final bytes = <int>[];
    await for (final data in request) {
      bytes.addAll(data);
    }
    return utf8.decode(bytes);
  }

  /// 发送成功响应
  Future<void> _sendSuccessResponse(
      HttpResponse response, Map<String, dynamic> data) async {
    response.statusCode = 200;
    response.headers.contentType = ContentType.json;

    final responseData = {
      'success': true,
      'data': data,
      'timestamp': DateTime.now().toIso8601String(),
    };

    response.write(jsonEncode(responseData));
    await response.close();
  }

  /// 发送错误响应
  Future<void> _sendErrorResponse(
      HttpResponse response, int statusCode, String message) async {
    response.statusCode = statusCode;
    response.headers.contentType = ContentType.json;

    final responseData = {
      'success': false,
      'error': message,
      'timestamp': DateTime.now().toIso8601String(),
    };

    response.write(jsonEncode(responseData));
    await response.close();
  }

  /// 写入服务器配置文件供浏览器扩展读取
  Future<void> _writeServerConfig() async {
    try {
      final configDir = await _getConfigDirectory();
      final configFile = File('${configDir.path}/password_manager_config.json');

      // 确保目录存在
      await configDir.create(recursive: true);

      final config = {
        'server_url': 'http://127.0.0.1:$_serverPort',
        'token': _serverToken,
        'pid': pid,
        'timestamp': DateTime.now().toIso8601String(),
        'api_version': '1.0.0',
      };

      await configFile.writeAsString(jsonEncode(config));
      debugPrint('服务器配置已写入: ${configFile.path}');
    } catch (e) {
      debugPrint('写入服务器配置失败: $e');
    }
  }

  /// 删除服务器配置文件
  Future<void> _deleteServerConfig() async {
    try {
      final configDir = await _getConfigDirectory();
      final configFile = File('${configDir.path}/password_manager_config.json');

      if (await configFile.exists()) {
        await configFile.delete();
        debugPrint('服务器配置文件已删除');
      }
    } catch (e) {
      debugPrint('删除服务器配置失败: $e');
    }
  }

  /// 获取配置文件目录
  Future<Directory> _getConfigDirectory() async {
    if (Platform.isWindows) {
      // Windows: %APPDATA%\PasswordManager
      final appData = Platform.environment['APPDATA']!;
      return Directory('$appData\\PasswordManager');
    } else if (Platform.isMacOS) {
      // macOS: ~/Library/Application Support/PasswordManager
      final home = Platform.environment['HOME']!;
      return Directory('$home/Library/Application Support/PasswordManager');
    } else {
      // Linux: ~/.config/PasswordManager
      final home = Platform.environment['HOME']!;
      return Directory('$home/.config/PasswordManager');
    }
  }

  /// 生成随机端口
  int _generateRandomPort() {
    // 如果想要固定端口，直接返回 5000
    // return 5000;

    final random = Random();
    // 使用5000-5999范围内的端口，避免常用端口冲突
    return 5000 + random.nextInt(1000);
  }

  /// 生成安全token
  String _generateSecureToken() {
    final random = Random.secure();
    final bytes = List<int>.generate(32, (i) => random.nextInt(256));
    return base64Url.encode(bytes);
  }

  /// 检查服务器是否运行
  bool get isRunning => _isRunning;

  /// 获取服务器地址
  String? get serverUrl =>
      _serverPort != null ? 'http://127.0.0.1:$_serverPort' : null;

  /// 获取服务器token
  String? get serverToken => _serverToken;
}

/// 密码服务接口
///
/// 直接从SharedPreferences读取真实的密码数据（与home_page.dart使用相同的存储）
class PasswordService {
  /// 密码数据变更回调
  static void Function()? onPasswordDataChanged;

  /// 从SharedPreferences加载所有密码
  static Future<List<PasswordEntry>> _loadPasswordsFromPreferences() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // 使用与home_page.dart相同的键名
      List<String> passwordsJson = prefs.getStringList('saved_passwords') ?? [];

      // 如果主数据为空，尝试从备份恢复
      if (passwordsJson.isEmpty) {
        passwordsJson = prefs.getStringList('saved_passwords_backup') ?? [];
        debugPrint('主数据为空，从备份数据恢复');
      }

      final passwords = passwordsJson
          .map((jsonString) {
            try {
              final json = jsonDecode(jsonString) as Map<String, dynamic>;
              return PasswordEntry.fromJson(json);
            } catch (e) {
              debugPrint('解析密码条目失败: $e');
              return null;
            }
          })
          .where((p) => p != null)
          .cast<PasswordEntry>()
          .toList();

      debugPrint('从SharedPreferences加载了 ${passwords.length} 条密码记录');
      return passwords;
    } catch (e) {
      debugPrint('从SharedPreferences加载密码失败: $e');
      return [];
    }
  }

  /// 保存密码到SharedPreferences
  static Future<void> _savePasswordsToPreferences(
      List<PasswordEntry> passwords) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final passwordsJson = passwords.map((password) {
        return jsonEncode(password.toJson());
      }).toList();

      // 保存主数据
      await prefs.setStringList('saved_passwords', passwordsJson);

      // 保存备份数据和时间戳
      await prefs.setStringList('saved_passwords_backup', passwordsJson);
      await prefs.setString(
          'last_backup_time', DateTime.now().toIso8601String());

      debugPrint('密码数据已保存到SharedPreferences，共${passwords.length}条记录');
    } catch (e) {
      debugPrint('保存密码数据到SharedPreferences失败: $e');
      rethrow;
    }
  }

  /// 搜索密码
  static Future<List<PasswordEntry>> searchPasswords(String query) async {
    debugPrint('搜索密码: $query');

    try {
      final allPasswords = await _loadPasswordsFromPreferences();

      if (query.isEmpty) {
        return allPasswords;
      }

      final filteredPasswords = allPasswords.where((password) {
        final title = password.title.toLowerCase();
        final username = password.username.toLowerCase();
        final website = password.website?.toLowerCase() ?? '';
        final notes = password.notes?.toLowerCase() ?? '';
        final queryLower = query.toLowerCase();

        return title.contains(queryLower) ||
            username.contains(queryLower) ||
            website.contains(queryLower) ||
            notes.contains(queryLower);
      }).toList();

      debugPrint('搜索结果: ${filteredPasswords.length} 条密码记录');
      return filteredPasswords;
    } catch (e) {
      debugPrint('搜索密码失败: $e');
      return [];
    }
  }

  /// 保存密码
  static Future<PasswordEntry> savePassword(PasswordEntry entry) async {
    debugPrint('保存密码: ${entry.title}');

    try {
      final allPasswords = await _loadPasswordsFromPreferences();

      // 生成新的ID
      int maxId = 0;
      for (final password in allPasswords) {
        if (password.id != null && password.id! > maxId) {
          maxId = password.id!;
        }
      }
      final newId = maxId + 1;

      // 创建新的密码条目
      final newEntry = entry.copyWith(
        id: newId,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      // 添加到列表并保存
      allPasswords.add(newEntry);
      await _savePasswordsToPreferences(allPasswords);

      debugPrint('密码保存成功，ID: $newId');

      // 发送数据变更事件，通知UI刷新
      try {
        // 这里需要动态导入以避免循环依赖
        _notifyPasswordDataChanged();
        debugPrint('已发送密码数据变更事件');
      } catch (e) {
        debugPrint('发送事件失败（不影响主功能）: $e');
      }

      return newEntry;
    } catch (e) {
      debugPrint('保存密码失败: $e');
      throw Exception('保存密码失败: $e');
    }
  }

  /// 更新密码
  static Future<PasswordEntry> updatePassword(
      int id, PasswordEntry entry) async {
    debugPrint('更新密码 ID: $id');

    try {
      final allPasswords = await _loadPasswordsFromPreferences();

      // 找到要更新的密码
      final index = allPasswords.indexWhere((p) => p.id == id);
      if (index == -1) {
        throw Exception('密码不存在');
      }

      // 更新密码
      final updatedEntry = entry.copyWith(
        id: id,
        createdAt: allPasswords[index].createdAt,
        updatedAt: DateTime.now(),
      );

      allPasswords[index] = updatedEntry;
      await _savePasswordsToPreferences(allPasswords);

      debugPrint('密码更新成功');
      return updatedEntry;
    } catch (e) {
      debugPrint('更新密码失败: $e');
      throw Exception('更新密码失败: $e');
    }
  }

  /// 删除密码
  static Future<void> deletePassword(int id) async {
    debugPrint('删除密码 ID: $id');

    try {
      final allPasswords = await _loadPasswordsFromPreferences();

      // 删除密码
      final initialLength = allPasswords.length;
      allPasswords.removeWhere((p) => p.id == id);

      if (allPasswords.length < initialLength) {
        await _savePasswordsToPreferences(allPasswords);
        debugPrint('密码删除成功');
      } else {
        throw Exception('密码不存在或删除失败');
      }
    } catch (e) {
      debugPrint('删除密码失败: $e');
      throw Exception('删除密码失败: $e');
    }
  }

  /// 根据域名获取密码
  static Future<List<PasswordEntry>> getPasswordsByDomain(String domain) async {
    debugPrint('Flutter: ==================== 开始获取域名密码 ====================');
    debugPrint('Flutter: 请求域名: "$domain"');

    if (domain.isEmpty) {
      debugPrint('Flutter: 域名为空，返回空列表');
      return [];
    }

    try {
      // 从SharedPreferences加载所有密码
      debugPrint('Flutter: 正在从SharedPreferences获取所有密码...');
      final allPasswords = await _loadPasswordsFromPreferences();
      debugPrint('Flutter: 从SharedPreferences获取到 ${allPasswords.length} 条密码记录');

      // 打印所有密码的网站信息
      if (allPasswords.isNotEmpty) {
        debugPrint('Flutter: 存储中的密码记录：');
        for (int i = 0; i < allPasswords.length; i++) {
          final password = allPasswords[i];
          debugPrint(
              'Flutter: 密码 ${i + 1}: title="${password.title}", website="${password.website}", username="${password.username}"');
        }
      } else {
        debugPrint('Flutter: ⚠️ SharedPreferences中没有任何密码记录！');
        return [];
      }

      // 根据域名匹配密码 - 使用宽松的匹配策略
      debugPrint('Flutter: 开始宽松域名匹配，目标域名/IP: "$domain"');
      final matchedPasswords = allPasswords.where((password) {
        final website = password.website ?? '';
        debugPrint('Flutter: 检查密码 "${password.title}" - 网站: "$website"');

        if (website.isEmpty) {
          debugPrint('Flutter: 跳过 - 网站为空');
          return false;
        }

        // 提取密码记录中的域名或IP
        final passwordDomain = _extractDomainFromWebsite(website);
        debugPrint('Flutter: 提取的域名/IP: "$passwordDomain" (来源: "$website")');

        // 🎯 宽松匹配策略：只要域名或IP地址有任何重叠就认为匹配

        // 1. 完全匹配（域名或IP）
        if (passwordDomain == domain) {
          debugPrint('Flutter: ✅ 完全匹配! "$passwordDomain" == "$domain"');
          return true;
        }

        // 2. 检查是否都是IP地址
        final isCurrentIP = _isIPAddress(domain);
        final isPasswordIP = _isIPAddress(passwordDomain);

        if (isCurrentIP && isPasswordIP) {
          if (passwordDomain == domain) {
            debugPrint('Flutter: ✅ IP地址完全匹配! "$passwordDomain" == "$domain"');
            return true;
          }
        }

        // 3. 域名包含关系匹配（任意方向）
        if (passwordDomain.isNotEmpty && domain.isNotEmpty) {
          // 提取主域名进行比较（去掉子域名）
          final passwordMainDomain = _extractMainDomain(passwordDomain);
          final currentMainDomain = _extractMainDomain(domain);

          debugPrint(
              'Flutter: 主域名比较: "$passwordMainDomain" vs "$currentMainDomain"');

          // 主域名匹配
          if (passwordMainDomain == currentMainDomain &&
              passwordMainDomain.isNotEmpty) {
            debugPrint(
                'Flutter: ✅ 主域名匹配! "$passwordMainDomain" == "$currentMainDomain"');
            return true;
          }

          // 包含关系匹配
          if (passwordDomain.contains(domain) ||
              domain.contains(passwordDomain)) {
            debugPrint('Flutter: ✅ 包含匹配! "$passwordDomain" <-> "$domain"');
            return true;
          }
        }

        debugPrint('Flutter: ❌ 无匹配');
        return false;
      }).toList();

      debugPrint('Flutter: ==================== 匹配结果 ====================');
      debugPrint('Flutter: 找到 ${matchedPasswords.length} 个匹配的密码');
      if (matchedPasswords.isNotEmpty) {
        for (int i = 0; i < matchedPasswords.length; i++) {
          final password = matchedPasswords[i];
          debugPrint(
              'Flutter: 匹配密码 ${i + 1}: "${password.title}" - ${password.website}');
        }
      }
      debugPrint('Flutter: ==================== 结束 ====================');

      return matchedPasswords;
    } catch (e, stackTrace) {
      debugPrint('Flutter: ❌ 获取域名密码失败: $e');
      debugPrint('Flutter: 错误堆栈: $stackTrace');
      return [];
    }
  }

  /// 通知密码数据变更
  static void _notifyPasswordDataChanged() {
    try {
      // 发送密码数据变更事件
      _sendPasswordChangeEvent();
      debugPrint('密码数据已变更，已发送刷新事件');
    } catch (e) {
      debugPrint('发送密码变更事件失败: $e');
    }
  }

  /// 发送密码变更事件
  static void _sendPasswordChangeEvent() {
    // 调用全局回调通知UI刷新
    if (onPasswordDataChanged != null) {
      onPasswordDataChanged!();
      debugPrint('已调用密码数据变更回调');
    } else {
      debugPrint('密码数据变更回调未设置');
    }
  }

  /// 从网站URL中提取域名或IP地址
  static String _extractDomainFromWebsite(String website) {
    try {
      if (website.isEmpty) return '';

      String cleanUrl = website.trim();

      // 移除协议
      cleanUrl = cleanUrl.replaceAll(RegExp(r'^https?://'), '');

      // 移除路径和查询参数
      cleanUrl = cleanUrl.split('/')[0].split('?')[0];

      // 移除端口号
      cleanUrl = cleanUrl.split(':')[0];

      return cleanUrl.toLowerCase();
    } catch (e) {
      debugPrint('Flutter: 提取域名失败: $e');
      return '';
    }
  }

  /// 检查字符串是否是IP地址
  static bool _isIPAddress(String str) {
    if (str.isEmpty) return false;

    // 简单的IP地址正则表达式
    final ipRegex = RegExp(r'^(\d{1,3}\.){3}\d{1,3}$');

    if (!ipRegex.hasMatch(str)) return false;

    // 验证每个数字段是否在0-255范围内
    final parts = str.split('.');
    for (final part in parts) {
      final num = int.tryParse(part);
      if (num == null || num < 0 || num > 255) {
        return false;
      }
    }

    return true;
  }

  /// 提取主域名（去掉子域名）
  static String _extractMainDomain(String domain) {
    if (domain.isEmpty) return '';

    // 如果是IP地址，直接返回
    if (_isIPAddress(domain)) return domain;

    try {
      final parts = domain.split('.');

      // 如果只有一级域名，直接返回
      if (parts.length <= 2) return domain;

      // 返回最后两级域名作为主域名
      return '${parts[parts.length - 2]}.${parts[parts.length - 1]}';
    } catch (e) {
      debugPrint('Flutter: 提取主域名失败: $e');
      return domain;
    }
  }
}
