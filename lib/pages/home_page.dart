import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/category.dart';
import '../models/password_entry.dart';
import '../services/auth_service.dart';
import '../services/event_bus.dart';
import '../services/import_export_service.dart';
import '../services/local_server_service.dart';
import '../services/settings_service.dart';
import '../services/theme_service.dart';
import '../widgets/decrypt_password_dialog.dart';
import '../widgets/export_options_dialog.dart';
import '../widgets/footer.dart';
import '../widgets/password_add_dialog.dart';
import '../widgets/password_generator_dialog.dart';
import '../widgets/theme_toggle_button.dart';
import 'browser_extension_page.dart';
import 'login_page.dart';
import 'settings_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final AuthService _authService = AuthService.instance;
  List<PasswordEntry> _allPasswords = []; // 所有密码的缓存
  final TextEditingController _searchController = TextEditingController();

  String _selectedCategory = '全部'; // 当前选中的分类
  String _searchText = '';
  bool _isLoading = false;

  // 事件总线订阅
  late StreamSubscription<AppEvent> _eventSubscription;

  // 获取所有分类
  List<String> get _categories =>
      ['全部', ...Category.predefinedCategories.map((c) => c.name)];

  // 根据搜索和分类过滤密码列表
  List<PasswordEntry> get _filteredPasswords {
    var filtered = _allPasswords.where((password) {
      // 分类过滤
      final categoryMatch = _selectedCategory == '全部' ||
          (password.category ?? '其他') == _selectedCategory;

      // 搜索过滤
      final searchMatch = _searchText.isEmpty ||
          password.title.toLowerCase().contains(_searchText.toLowerCase()) ||
          (password.website
                  ?.toLowerCase()
                  .contains(_searchText.toLowerCase()) ??
              false);

      return categoryMatch && searchMatch;
    }).toList();

    return filtered;
  }

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      setState(() {
        _searchText = _searchController.text;
      });
    });

    // 监听密码数据变更事件
    _eventSubscription = EventBus.instance.events.listen((event) {
      if (event is PasswordDataChangedEvent) {
        // debugPrint('收到密码数据变更事件，重新加载密码列表');
        _loadPasswords();
      }
    });

    // 设置密码数据变更回调
    PasswordService.onPasswordDataChanged = () {
      // debugPrint('收到密码数据变更回调，重新加载密码列表');
      if (mounted) {
        _loadPasswords();
      }
    };

    _loadPasswords();
  }

  /// 加载密码数据（暂时从SharedPreferences加载）
  Future<void> _loadPasswords() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // 暂时使用SharedPreferences存储密码数据
      await _loadPasswordsFromPreferences();
      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('加载密码失败: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  /// 从SharedPreferences加载密码（带恢复功能）
  Future<void> _loadPasswordsFromPreferences() async {
    final prefs = await SharedPreferences.getInstance();

    try {
      // 尝试加载主数据
      List<String> passwordsJson = prefs.getStringList('saved_passwords') ?? [];

      // 如果主数据为空，尝试从备份恢复
      if (passwordsJson.isEmpty) {
        passwordsJson = prefs.getStringList('saved_passwords_backup') ?? [];
        if (passwordsJson.isNotEmpty) {
          // print('主数据为空，从备份数据恢复');
          // 恢复主数据
          await prefs.setStringList('saved_passwords', passwordsJson);
        }
      }

      final passwords = passwordsJson
          .map((jsonString) {
            try {
              final json = jsonDecode(jsonString) as Map<String, dynamic>;
              return PasswordEntry.fromJson(json);
            } catch (e) {
              // print('解析密码条目失败: $e');
              return null;
            }
          })
          .where((p) => p != null)
          .cast<PasswordEntry>()
          .toList();

      setState(() {
        _allPasswords = passwords;
      });

      // print('成功加载${passwords.length}条密码记录');

      // 显示最后备份时间
      final lastBackupTime = prefs.getString('last_backup_time');
      if (lastBackupTime != null && mounted) {
        final backupDate = DateTime.parse(lastBackupTime);
        final formatTime =
            '${backupDate.year}-${backupDate.month.toString().padLeft(2, '0')}-${backupDate.day.toString().padLeft(2, '0')} ${backupDate.hour.toString().padLeft(2, '0')}:${backupDate.minute.toString().padLeft(2, '0')}';

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('数据加载完成 (最后备份: $formatTime)'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      // print('加载密码数据失败: $e');
      setState(() {
        _allPasswords = [];
      });
    }
  }

  /// 保存密码到SharedPreferences（带备份）
  Future<void> _savePasswordsToPreferences() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final passwordsJson = _allPasswords.map((password) {
        return jsonEncode(password.toJson());
      }).toList();

      // 保存主数据
      await prefs.setStringList('saved_passwords', passwordsJson);

      // 保存备份数据和时间戳
      await prefs.setStringList('saved_passwords_backup', passwordsJson);
      await prefs.setString(
          'last_backup_time', DateTime.now().toIso8601String());

      // print('密码数据已保存，共${_allPasswords.length}条记录');
    } catch (e) {
      // print('保存密码数据失败: $e');
      rethrow;
    }
  }

  /// 获取下一个可用的ID
  int _getNextId() {
    int maxId = 0;
    for (final password in _allPasswords) {
      if (password.id != null && password.id! > maxId) {
        maxId = password.id!;
      }
    }
    return maxId + 1;
  }

  @override
  void dispose() {
    _searchController.dispose();
    _eventSubscription.cancel(); // 取消事件监听
    super.dispose();
  }

  /// 锁定应用
  Future<void> _lockApp() async {
    await _authService.lockApp();
    if (mounted) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (context) => const LoginPage()),
      );
    }
  }

  /// 显示版本信息弹窗
  Future<void> _showVersionInfo() async {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showDialog(
      context: context,
      barrierColor: Colors.black.withOpacity(0.5), // 统一遮罩层透明度
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent, // 设置Dialog背景为透明
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 500), // 移除高度限制
          decoration: BoxDecoration(
            // 根据主题模式设置精确的背景色
            color: isDark
                ? const Color(0xFF1E1E1E) // 深色模式：深灰色背景
                : Colors.white, // 浅色模式：纯白背景
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: isDark
                    ? Colors.black.withOpacity(0.8) // 深色模式：更强的阴影
                    : Colors.black.withOpacity(0.15), // 浅色模式：轻微阴影
                blurRadius: isDark ? 24 : 16,
                offset: const Offset(0, 8),
                spreadRadius: isDark ? 2 : 0,
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // 标题栏
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  // 标题栏使用更精确的渐变背景
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: isDark
                        ? [
                            const Color(0xFF2A2A2A), // 深色模式：深灰渐变
                            const Color(0xFF1A1A1A),
                          ]
                        : [
                            const Color(0xFFF8F9FA), // 浅色模式：浅灰渐变
                            const Color(0xFFE9ECEF),
                          ],
                  ),
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(20),
                    topRight: Radius.circular(20),
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            Theme.of(context).colorScheme.primary,
                            Theme.of(context)
                                .colorScheme
                                .primary
                                .withOpacity(0.8),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: Theme.of(context)
                                .colorScheme
                                .primary
                                .withOpacity(0.3),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.security,
                        color: Colors.white,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '关于应用',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: isDark
                                  ? Colors.white
                                  : const Color(0xFF1A1A1A),
                            ),
                          ),
                          Text(
                            '版本信息与功能介绍',
                            style: TextStyle(
                              fontSize: 14,
                              color: isDark
                                  ? Colors.white.withOpacity(0.7)
                                  : const Color(0xFF666666),
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: Icon(
                        Icons.close,
                        color: isDark
                            ? Colors.white.withOpacity(0.8)
                            : const Color(0xFF666666),
                      ),
                      splashRadius: 20,
                      tooltip: '关闭',
                    ),
                  ],
                ),
              ),
              // 内容区域 - 移除 Expanded 和 SingleChildScrollView
              Container(
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
                  borderRadius: const BorderRadius.only(
                    bottomLeft: Radius.circular(20),
                    bottomRight: Radius.circular(20),
                  ),
                ),
                padding: const EdgeInsets.all(24),
                child: FutureBuilder<Map<String, String>>(
                  future: _getVersionAppInfo(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(
                        child: Padding(
                          padding: EdgeInsets.all(32.0),
                          child: CircularProgressIndicator(),
                        ),
                      );
                    }

                    final appInfo = snapshot.data ?? {};
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildVersionInfoRow(
                            '应用名称', appInfo['appName'] ?? '密码管理器'),
                        const SizedBox(height: 16),
                        _buildVersionInfoRow(
                            '版本号', appInfo['version'] ?? '1.0.0'),
                        const SizedBox(height: 16),
                        _buildVersionInfoRow(
                            '构建号', appInfo['buildNumber'] ?? '1'),
                        const SizedBox(height: 16),
                        _buildVersionInfoRow(
                            '包名',
                            appInfo['packageName'] ??
                                'com.example.password_manager'),
                        const SizedBox(height: 24),
                        // 功能特性卡片
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: isDark
                                ? const Color(0xFF2A2A2A) // 深色模式：深灰背景
                                : const Color(0xFFF8F9FA), // 浅色模式：浅灰背景
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: isDark
                                  ? const Color(0xFF404040) // 深色模式：深色边框
                                  : const Color(0xFFE9ECEF), // 浅色模式：浅色边框
                              width: 1,
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(
                                    Icons.star,
                                    color:
                                        Theme.of(context).colorScheme.primary,
                                    size: 20,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    '功能特性',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                      color: isDark
                                          ? Colors.white
                                          : const Color(0xFF1A1A1A),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              Text(
                                '• 安全的密码存储与管理\n'
                                '• 强密码生成器\n'
                                '• 分类管理与搜索\n'
                                '• 数据导入导出\n'
                                '• 多主题切换\n'
                                '• 自定义界面\n'
                                '• 自动锁定保护',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: isDark
                                      ? Colors.white.withOpacity(0.8)
                                      : const Color(0xFF666666),
                                  height: 1.6,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 20),
                        // 安全提示卡片
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: isDark
                                ? Colors.green.withOpacity(0.1) // 深色模式：绿色半透明
                                : Colors.green.withOpacity(0.05), // 浅色模式：绿色更淡
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: isDark
                                  ? Colors.green.withOpacity(0.3) // 深色模式：绿色边框
                                  : Colors.green.withOpacity(0.2), // 浅色模式：淡绿色边框
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.security,
                                color: isDark
                                    ? Colors.green.shade300 // 深色模式：亮绿色图标
                                    : Colors.green.shade600, // 浅色模式：深绿色图标
                                size: 20,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  '您的数据安全是我们的首要任务，所有密码数据均采用本地加密存储。',
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: isDark
                                        ? Colors.green.shade100 // 深色模式：亮绿色文字
                                        : Colors.green.shade700, // 浅色模式：深绿色文字
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 获取版本应用信息
  Future<Map<String, String>> _getVersionAppInfo() async {
    try {
      PackageInfo packageInfo = await PackageInfo.fromPlatform();
      return {
        'appName': packageInfo.appName,
        'version': packageInfo.version,
        'buildNumber': packageInfo.buildNumber,
        'packageName': packageInfo.packageName,
      };
    } catch (e) {
      return {
        'appName': '密码管理器',
        'version': '1.0.0',
        'buildNumber': '1',
        'packageName': 'com.example.password_manager',
      };
    }
  }

  /// 构建版本信息行
  Widget _buildVersionInfoRow(String label, String value) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 80,
          child: Text(
            label,
            style: TextStyle(
              fontWeight: FontWeight.w500,
              color: isDark
                  ? Colors.white.withOpacity(0.7) // 深色模式：半透明白色
                  : const Color(0xFF666666), // 浅色模式：中等灰色
              fontSize: 14,
            ),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: isDark
                  ? const Color(0xFF2A2A2A) // 深色模式：深灰背景
                  : const Color(0xFFF8F9FA), // 浅色模式：浅灰背景
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: isDark
                    ? const Color(0xFF404040) // 深色模式：深色边框
                    : const Color(0xFFE9ECEF), // 浅色模式：浅色边框
                width: 1,
              ),
            ),
            child: Text(
              value,
              style: TextStyle(
                color: isDark
                    ? Colors.white.withOpacity(0.9) // 深色模式：亮白色
                    : const Color(0xFF1A1A1A), // 浅色模式：深黑色
                fontFamily: 'monospace',
                fontSize: 14,
                fontWeight: FontWeight.w500,
                letterSpacing: 0.5, // 增加字符间距，提高可读性
              ),
            ),
          ),
        ),
      ],
    );
  }

  /// 显示设置页面
  void _showSettings() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => const SettingsPage(),
      ),
    );
  }

  /// 显示浏览器扩展页面
  void _showBrowserExtension() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => const BrowserExtensionPage(),
      ),
    );
  }

  /// 显示导入导出菜单
  void _showImportExportMenu() {
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '数据管理',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 20),
            ListTile(
              leading: const Icon(Icons.upload_file),
              title: const Text('导出为JSON'),
              subtitle: const Text('备份所有密码数据'),
              onTap: () {
                Navigator.pop(context);
                _exportPasswords();
              },
            ),
            ListTile(
              leading: const Icon(Icons.table_chart),
              title: const Text('导出为CSV'),
              subtitle: const Text('导出为表格格式'),
              onTap: () {
                Navigator.pop(context);
                _exportToCSV();
              },
            ),
            ListTile(
              leading: const Icon(Icons.download),
              title: const Text('导入数据'),
              subtitle: const Text('从JSON文件导入密码'),
              onTap: () {
                Navigator.pop(context);
                _importPasswords();
              },
            ),
          ],
        ),
      ),
    );
  }

  /// 导出密码
  Future<void> _exportPasswords() async {
    try {
      // 显示导出选项对话框
      final exportOptions = await showExportOptionsDialog(context);
      if (exportOptions == null) {
        // 用户取消了操作
        return;
      }

      // 如果选择加密，检查是否有可用的主密码
      String? masterPassword;
      if (exportOptions.encrypt) {
        if (!_authService.hasCurrentMasterPassword()) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('无法获取主密码，请重新登录后再试'),
                backgroundColor: Colors.red,
              ),
            );
          }
          return;
        }
        masterPassword = _authService.getCurrentMasterPassword();
      }

      final filePath = await ImportExportService.instance.exportPasswords(
        _allPasswords,
        encrypt: exportOptions.encrypt,
        masterPassword: masterPassword,
      );

      if (filePath != null && mounted) {
        final fileName = filePath.split('/').last;
        final encryptedText = exportOptions.encrypt ? '（已加密）' : '（明文）';

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('数据已导出到: $fileName $encryptedText'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 4),
            action: SnackBarAction(
              label: '查看',
              textColor: Colors.white,
              onPressed: () {
                // 可以在这里添加打开文件所在目录的功能
              },
            ),
          ),
        );
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('导出已取消'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('导出失败: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  /// 导出为CSV
  Future<void> _exportToCSV() async {
    try {
      final filePath =
          await ImportExportService.instance.exportToCSV(_allPasswords);

      if (filePath != null && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('CSV已导出到: ${filePath.split('/').last}'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 4),
            action: SnackBarAction(
              label: '查看',
              textColor: Colors.white,
              onPressed: () {
                // 可以在这里添加打开文件所在目录的功能
              },
            ),
          ),
        );
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('CSV导出已取消'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('CSV导出失败: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  /// 导入密码
  Future<void> _importPasswords() async {
    try {
      // 首次尝试导入（选择文件）
      var result = await ImportExportService.instance.importPasswords();

      // 如果需要解密，显示密码输入对话框并处理加密文件
      if (result.needsDecryption && result.fileContent != null) {
        if (!mounted) return;

        while (true) {
          final decryptPassword = await showDecryptPasswordDialog(context);
          if (decryptPassword == null) {
            // 用户取消了解密操作
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('导入已取消'),
                  backgroundColor: Colors.orange,
                ),
              );
            }
            return;
          }

          // 使用文件内容和解密密码进行导入
          result =
              await ImportExportService.instance.importPasswordsFromContent(
            result.fileContent!,
            decryptPassword,
          );

          // 如果解密成功，跳出循环
          if (result.success) {
            break;
          }

          // 如果解密失败，询问用户是否重试
          if (result.errorMessage?.contains('解密失败') == true) {
            if (!mounted) return;

            final retryResult =
                await showDecryptRetryDialog(context, result.errorMessage!);
            if (retryResult != 'retry') {
              // 用户选择放弃重试
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('导入已取消'),
                    backgroundColor: Colors.orange,
                  ),
                );
              }
              return;
            }
            // 继续循环，让用户重新输入密码
          } else {
            // 其他错误，直接显示并退出
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(result.errorMessage ?? '导入失败'),
                  backgroundColor: Colors.red,
                ),
              );
            }
            return;
          }
        }
      }

      if (!result.success) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(result.errorMessage ?? '导入失败'),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }

      if (result.passwords.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('文件中没有找到有效的密码数据'),
              backgroundColor: Colors.orange,
            ),
          );
        }
        return;
      }

      // 合并数据
      final mergedPasswords = ImportExportService.instance.mergePasswords(
        _allPasswords,
        result.passwords,
        strategy: MergeStrategy.keepBoth,
      );

      setState(() {
        _allPasswords.clear();
        _allPasswords.addAll(mergedPasswords);
      });

      // 保存数据
      await _savePasswordsToPreferences();

      if (mounted) {
        String message = '成功导入 ${result.successCount} 个密码';
        if (result.hasFailures) {
          message += '，${result.failureCount} 个条目导入失败';
        }
        if (result.wasEncrypted) {
          message += '（来自加密文件）';
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(message),
            backgroundColor: result.hasFailures ? Colors.orange : Colors.green,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('导入失败: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  /// 显示密码添加弹窗
  Future<void> _showAddPasswordDialog() async {
    final result = await showDialog<PasswordEntry>(
      context: context,
      builder: (context) => const PasswordAddDialog(),
    );

    if (result != null) {
      try {
        // 分配唯一ID并保存到SharedPreferences
        final newId = _getNextId();
        final entryWithId = result.copyWith(id: newId);
        setState(() {
          _allPasswords.add(entryWithId);
        });
        await _savePasswordsToPreferences();

        // 显示成功消息
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('密码 "${result.title}" 添加成功！'),
              backgroundColor: Colors.green,
              duration: const Duration(seconds: 2),
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('保存密码失败: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  /// 显示密码生成器弹窗
  Future<void> _showPasswordGeneratorDialog() async {
    final result = await showDialog<PasswordEntry>(
      context: context,
      builder: (context) => const PasswordGeneratorDialog(),
    );

    if (result != null) {
      try {
        // 分配唯一ID并保存到SharedPreferences
        final newId = _getNextId();
        final entryWithId = result.copyWith(id: newId);
        setState(() {
          _allPasswords.add(entryWithId);
        });
        await _savePasswordsToPreferences();

        // 显示成功消息
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('密码 "${result.title}" 生成并保存成功！'),
              backgroundColor: Colors.green,
              duration: const Duration(seconds: 2),
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('保存密码失败: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  /// 显示密码查看弹窗
  Future<void> _showPasswordViewDialog(PasswordEntry password) async {
    await showDialog(
      context: context,
      builder: (context) => _PasswordViewDialog(password: password),
    );
  }

  /// 显示密码编辑弹窗
  Future<void> _showEditPasswordDialog(
      PasswordEntry password, int index) async {
    final result = await showDialog<PasswordEntry>(
      context: context,
      builder: (context) => PasswordAddDialog(existingEntry: password),
    );

    if (result != null) {
      try {
        // 更新列表中的条目
        final originalIndex =
            _allPasswords.indexWhere((p) => p.id == password.id);
        setState(() {
          if (originalIndex != -1) {
            _allPasswords[originalIndex] = result;
          }
        });
        await _savePasswordsToPreferences();

        // 显示成功消息
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('密码 "${result.title}" 更新成功！'),
              backgroundColor: Colors.green,
              duration: const Duration(seconds: 2),
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('更新密码失败: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  /// 显示删除确认弹窗
  Future<void> _showDeleteConfirmDialog(
      PasswordEntry password, int index) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        final theme = Theme.of(context);
        final colorScheme = theme.colorScheme;
        final isDark = theme.brightness == Brightness.dark;

        return Dialog(
          backgroundColor: colorScheme.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: Container(
            width: 420,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: colorScheme.surface,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 标题
                Row(
                  children: [
                    Icon(
                      Icons.delete_outline,
                      color: Colors.red.shade600,
                      size: 24,
                    ),
                    const SizedBox(width: 12),
                    Text(
                      '删除确认',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w600,
                        color: colorScheme.onSurface,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  '请确认您要删除以下密码条目',
                  style: TextStyle(
                    fontSize: 14,
                    color: colorScheme.onSurface.withOpacity(0.7),
                  ),
                ),
                const SizedBox(height: 24),

                // 密码信息
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: isDark
                        ? colorScheme.surfaceVariant
                        : Colors.grey.shade50,
                    border: Border.all(
                      color:
                          isDark ? colorScheme.outline : Colors.grey.shade200,
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.key,
                        color: colorScheme.onSurface.withOpacity(0.6),
                        size: 20,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              password.title,
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 16,
                                color: colorScheme.onSurface,
                              ),
                            ),
                            if (password.username.isNotEmpty) ...[
                              const SizedBox(height: 4),
                              Text(
                                password.username,
                                style: TextStyle(
                                  fontSize: 14,
                                  color: colorScheme.onSurface.withOpacity(0.6),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 20),

                // 警告信息
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50.withOpacity(isDark ? 0.1 : 1.0),
                    border: Border.all(
                        color: Colors.red.shade200
                            .withOpacity(isDark ? 0.5 : 1.0)),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.warning_outlined,
                        color: Colors.red.shade700,
                        size: 20,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '警告',
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 14,
                                color: Colors.red.shade800,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '此操作将永久删除该密码条目，无法撤销。请确认您真的要删除此密码。',
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.red.shade700,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                // 操作按钮
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(false),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 20, vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: Text(
                        '取消',
                        style: TextStyle(
                          fontSize: 14,
                          color: colorScheme.onSurface.withOpacity(0.7),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton.icon(
                      onPressed: () => Navigator.of(context).pop(true),
                      icon: const Icon(Icons.delete, size: 18),
                      label: const Text(
                        '删除',
                        style: TextStyle(fontSize: 14),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red.shade600,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 20, vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );

    if (confirmed == true) {
      try {
        setState(() {
          _allPasswords.removeWhere((p) => p.id == password.id);
        });
        await _savePasswordsToPreferences();

        // 显示成功消息
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('密码 "${password.title}" 已删除'),
              backgroundColor: Colors.orange,
              duration: const Duration(seconds: 2),
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('删除密码失败: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([
        ThemeService.instance,
        SettingsService.instance,
      ]),
      builder: (context, child) {
        return Scaffold(
          appBar: AppBar(
            backgroundColor: ThemeService.instance.isDark
                ? const Color(0xFF121212)
                : Colors.white, // 明确设置背景色
            scrolledUnderElevation: 0, // 防止滚动时背景色变化
            title: Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: SettingsService.instance.hasCustomLogo
                        ? Image.file(
                            File(SettingsService.instance.getLogoImagePath()),
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) {
                              return Container(
                                decoration: BoxDecoration(
                                  color: Theme.of(context).colorScheme.primary,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Icon(
                                  Icons.security,
                                  color: Colors.white,
                                  size: 20,
                                ),
                              );
                            },
                          )
                        : Image.asset(
                            SettingsService.instance.getLogoImagePath(),
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) {
                              return Container(
                                decoration: BoxDecoration(
                                  color: Theme.of(context).colorScheme.primary,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Icon(
                                  Icons.security,
                                  color: Colors.white,
                                  size: 20,
                                ),
                              );
                            },
                          ),
                  ),
                ),
                const SizedBox(width: 12),
                Text(SettingsService.instance.appTitle),
                const SizedBox(width: 8),
                // 版本信息按钮
                GestureDetector(
                  onTap: _showVersionInfo,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Theme.of(context)
                          .colorScheme
                          .secondaryContainer
                          .withOpacity(0.7),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.info_outline,
                          size: 16,
                          color: Theme.of(context)
                              .colorScheme
                              .onSecondaryContainer,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'v1.0.0',
                          style: TextStyle(
                            fontSize: 12,
                            color: Theme.of(context)
                                .colorScheme
                                .onSecondaryContainer,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            actions: [
              // 主题切换按钮
              const Padding(
                padding: EdgeInsets.only(right: 8),
                child: ThemeToggleButton(),
              ),
              IconButton(
                icon: const Icon(Icons.extension),
                onPressed: _showBrowserExtension,
                tooltip: '浏览器扩展',
              ),
              IconButton(
                icon: const Icon(Icons.import_export),
                onPressed: _showImportExportMenu,
                tooltip: '导入导出',
              ),
              IconButton(
                icon: const Icon(Icons.settings),
                onPressed: _showSettings,
                tooltip: '设置',
              ),
              IconButton(
                icon: const Icon(Icons.lock),
                onPressed: _lockApp,
                tooltip: '锁定应用',
              ),
            ],
          ),
          body: Column(
            children: [
              // 搜索框
              _buildSearchBar(),
              // 主内容区域
              Expanded(
                child: Row(
                  children: [
                    // 左侧分类列表
                    _buildCategoryList(),
                    // 右侧密码列表
                    Expanded(
                      child: _allPasswords.isEmpty
                          ? _buildEmptyState()
                          : _buildPasswordList(),
                    ),
                  ],
                ),
              ),
              // 底部footer
              const Footer(),
            ],
          ),
        );
      },
    );
  }

  /// 构建搜索框和操作按钮栏
  Widget _buildSearchBar() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        boxShadow: [
          BoxShadow(
            color: ThemeService.instance.isDark
                ? Theme.of(context).colorScheme.shadow.withOpacity(0.1)
                : Colors.black.withOpacity(0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
        border: ThemeService.instance.isDark
            ? null
            : Border(
                bottom: BorderSide(
                  color: Theme.of(context).colorScheme.outline.withOpacity(0.2),
                  width: 0.5,
                ),
              ),
      ),
      child: Row(
        children: [
          // 搜索框
          Expanded(
            flex: 3,
            child: SizedBox(
              height: 48, // 统一设置高度
              child: TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: '搜索密码标题或网站...',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: _searchText.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear),
                          onPressed: () {
                            _searchController.clear();
                          },
                        )
                      : null,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide.none,
                  ),
                  filled: true,
                  fillColor: ThemeService.instance.isDark
                      ? Theme.of(context)
                          .colorScheme
                          .surfaceVariant
                          .withOpacity(0.5)
                      : Theme.of(context)
                          .colorScheme
                          .surfaceVariant
                          .withOpacity(0.8),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 12,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 16),
          // 密码生成器按钮
          SizedBox(
            height: 48, // 统一设置高度
            child: ElevatedButton.icon(
              onPressed: _showPasswordGeneratorDialog,
              icon: const Icon(Icons.generating_tokens, size: 18),
              label: const Text('生成密码'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.secondary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          // 添加密码按钮
          SizedBox(
            height: 48, // 统一设置高度
            child: ElevatedButton.icon(
              onPressed: _showAddPasswordDialog,
              icon: const Icon(Icons.add, size: 18),
              label: const Text('添加密码'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 构建左侧分类列表
  Widget _buildCategoryList() {
    return Container(
      width: 200,
      decoration: BoxDecoration(
        color: ThemeService.instance.isDark
            ? Theme.of(context).colorScheme.surface
            : Theme.of(context).colorScheme.surfaceVariant,
        border: Border(
          right: BorderSide(
            color: Theme.of(context).colorScheme.outline.withOpacity(0.3),
            width: 1,
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              '分类',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: _categories.length,
              itemBuilder: (context, index) {
                final category = _categories[index];
                final isSelected = category == _selectedCategory;
                final count = category == '全部'
                    ? _allPasswords.length
                    : _allPasswords
                        .where((p) => (p.category ?? '其他') == category)
                        .length;

                return Container(
                  margin:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    color: isSelected
                        ? Theme.of(context).colorScheme.primary.withOpacity(0.1)
                        : null,
                  ),
                  child: ListTile(
                    dense: true,
                    contentPadding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    leading: Icon(
                      _getCategoryIcon(category),
                      color: isSelected
                          ? Theme.of(context).colorScheme.primary
                          : Theme.of(context).colorScheme.onSurfaceVariant,
                      size: 20,
                    ),
                    title: Text(
                      category,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight:
                            isSelected ? FontWeight.w600 : FontWeight.normal,
                        color: isSelected
                            ? Theme.of(context).colorScheme.primary
                            : Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                    trailing: count > 0
                        ? Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? Theme.of(context).colorScheme.primary
                                  : Theme.of(context)
                                      .colorScheme
                                      .outline
                                      .withOpacity(0.2),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              count.toString(),
                              style: TextStyle(
                                fontSize: 12,
                                color: isSelected
                                    ? Colors.white
                                    : Theme.of(context)
                                        .colorScheme
                                        .onSurfaceVariant,
                              ),
                            ),
                          )
                        : null,
                    onTap: () {
                      setState(() {
                        _selectedCategory = category;
                      });
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  /// 获取分类图标
  IconData _getCategoryIcon(String category) {
    switch (category) {
      case '全部':
        return Icons.all_inclusive;
      case '社交':
        return Icons.people;
      case '邮箱':
        return Icons.email;
      case '购物':
        return Icons.shopping_cart;
      case '银行':
        return Icons.account_balance;
      case '工作':
        return Icons.work;
      case '娱乐':
        return Icons.movie;
      case '游戏':
        return Icons.games;
      case '其他':
        return Icons.category;
      default:
        return Icons.folder;
    }
  }

  /// 构建空状态界面
  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 120,
            height: 120,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(60),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(44),
              child: SettingsService.instance.hasCustomLogo
                  ? Image.file(
                      File(SettingsService.instance.getLogoImagePath()),
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return Icon(
                          Icons.security,
                          size: 80,
                          color: Theme.of(context).colorScheme.primary,
                        );
                      },
                    )
                  : Image.asset(
                      SettingsService.instance.getLogoImagePath(),
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return Icon(
                          Icons.security,
                          size: 80,
                          color: Theme.of(context).colorScheme.primary,
                        );
                      },
                    ),
            ),
          ),
          const SizedBox(height: 32),
          Text(
            '欢迎使用${SettingsService.instance.appTitle}！',
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            '安全地存储和管理您的所有密码',
            style: TextStyle(
              fontSize: 16,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 48),
          Container(
            padding: const EdgeInsets.all(20),
            margin: const EdgeInsets.symmetric(horizontal: 32),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: Theme.of(context).colorScheme.outline.withOpacity(0.5),
              ),
            ),
            child: Column(
              children: [
                Icon(
                  Icons.add_circle_outline,
                  size: 48,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(height: 16),
                Text(
                  '开始添加您的第一个密码',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '点击右下角的添加按钮来创建密码条目',
                  style: TextStyle(
                    fontSize: 14,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// 构建密码列表
  Widget _buildPasswordList() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    final filteredPasswords = _filteredPasswords;

    if (filteredPasswords.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.search_off,
              size: 64,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: 16),
            Text(
              '没有找到匹配的密码',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '尝试调整搜索关键词或选择其他分类',
              style: TextStyle(
                fontSize: 14,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: filteredPasswords.length,
      itemBuilder: (context, index) {
        final password = filteredPasswords[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          elevation: 1,
          color: Theme.of(context).brightness == Brightness.light
              ? Colors.grey[50]
              : Theme.of(context).colorScheme.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(
              color: Theme.of(context).brightness == Brightness.light
                  ? Colors.grey[300]!
                  : Theme.of(context).colorScheme.outline.withOpacity(0.2),
              width: 0.5,
            ),
          ),
          child: ListTile(
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            leading: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Center(
                child: Text(
                  password.title.isNotEmpty
                      ? password.title[0].toUpperCase()
                      : '?',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ),
            ),
            title: Text(
              password.title,
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 15,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 2),
                Text(
                  password.username,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    fontSize: 13,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    if (password.website?.isNotEmpty == true) ...[
                      Flexible(
                        child: Text(
                          password.website!,
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.primary,
                            fontSize: 11,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                    ],
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 1),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.secondaryContainer,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        password.category ?? '其他',
                        style: TextStyle(
                          fontSize: 10,
                          color: Theme.of(context)
                              .colorScheme
                              .onSecondaryContainer,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (password.isFavorite)
                  const Padding(
                    padding: EdgeInsets.only(right: 4),
                    child: Icon(
                      Icons.star,
                      color: Colors.amber,
                      size: 16,
                    ),
                  ),
                // 查看按钮
                IconButton(
                  onPressed: () => _showPasswordViewDialog(password),
                  icon: Icon(
                    Icons.visibility,
                    size: 18,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  tooltip: '查看',
                  constraints:
                      const BoxConstraints(minWidth: 32, minHeight: 32),
                  padding: const EdgeInsets.all(4),
                ),
                // 编辑按钮
                IconButton(
                  onPressed: () => _showEditPasswordDialog(password, index),
                  icon: Icon(
                    Icons.edit,
                    size: 18,
                    color: Theme.of(context).colorScheme.secondary,
                  ),
                  tooltip: '编辑',
                  constraints:
                      const BoxConstraints(minWidth: 32, minHeight: 32),
                  padding: const EdgeInsets.all(4),
                ),
                // 删除按钮
                IconButton(
                  onPressed: () => _showDeleteConfirmDialog(password, index),
                  icon: const Icon(
                    Icons.delete,
                    size: 18,
                    color: Colors.red,
                  ),
                  tooltip: '删除',
                  constraints:
                      const BoxConstraints(minWidth: 32, minHeight: 32),
                  padding: const EdgeInsets.all(4),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// 密码查看弹窗
class _PasswordViewDialog extends StatefulWidget {
  final PasswordEntry password;

  const _PasswordViewDialog({required this.password});

  @override
  State<_PasswordViewDialog> createState() => _PasswordViewDialogState();
}

class _PasswordViewDialogState extends State<_PasswordViewDialog> {
  bool _obscurePassword = true;

  /// 复制到剪贴板
  Future<void> _copyToClipboard(String text, String label) async {
    await Clipboard.setData(ClipboardData(text: text));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('$label已复制到剪贴板'),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    final maxHeight = screenHeight * 0.85; // 使用屏幕高度的85%

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Container(
        constraints: BoxConstraints(
          maxWidth: 600, // 增加宽度
          maxHeight: maxHeight,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 标题栏
            _buildHeader(),
            // 内容区域
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildInfoField('标题', widget.password.title, Icons.title),
                    const SizedBox(height: 12),
                    _buildInfoField(
                        '用户名/邮箱', widget.password.username, Icons.person),
                    const SizedBox(height: 12),
                    _buildPasswordField(),
                    const SizedBox(height: 12),
                    if (widget.password.website?.isNotEmpty == true) ...[
                      _buildInfoField(
                          '网站/应用', widget.password.website!, Icons.language),
                      const SizedBox(height: 12),
                    ],
                    _buildInfoField(
                        '分类', widget.password.category ?? '其他', Icons.category),
                    const SizedBox(height: 12),
                    if (widget.password.notes?.isNotEmpty == true) ...[
                      _buildNotesField(),
                      const SizedBox(height: 12),
                    ],
                    if (widget.password.customFields.isNotEmpty) ...[
                      _buildCustomFieldsSection(),
                      const SizedBox(height: 12),
                    ],
                    _buildMetaInfo(),
                    const SizedBox(height: 16), // 底部额外空间
                  ],
                ),
              ),
            ),
            // 底部按钮 - 固定在底部
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                border: Border(
                  top: BorderSide(
                    color:
                        Theme.of(context).colorScheme.outline.withOpacity(0.2),
                    width: 1,
                  ),
                ),
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(20),
                  bottomRight: Radius.circular(20),
                ),
              ),
              child: SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text('关闭'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 构建标题栏
  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primary,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.visibility,
              color: Colors.white,
              size: 24,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '查看密码',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  widget.password.title,
                  style: TextStyle(
                    fontSize: 14,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: () => Navigator.of(context).pop(),
            icon: Icon(
              Icons.close,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  /// 构建信息字段
  Widget _buildInfoField(String label, String value, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Theme.of(context).colorScheme.outline.withOpacity(0.2),
        ),
      ),
      child: Row(
        children: [
          Icon(
            icon,
            color: Theme.of(context).colorScheme.primary,
            size: 20,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 16,
                    color: Theme.of(context).colorScheme.onSurface,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: () => _copyToClipboard(value, label),
            icon: const Icon(Icons.copy, size: 18),
            tooltip: '复制$label',
          ),
        ],
      ),
    );
  }

  /// 构建密码字段
  Widget _buildPasswordField() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Theme.of(context).colorScheme.outline.withOpacity(0.2),
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.lock,
            color: Theme.of(context).colorScheme.primary,
            size: 20,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '密码',
                  style: TextStyle(
                    fontSize: 12,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _obscurePassword
                      ? '•' * widget.password.password.length
                      : widget.password.password,
                  style: TextStyle(
                    fontSize: 16,
                    color: Theme.of(context).colorScheme.onSurface,
                    fontWeight: FontWeight.w500,
                    fontFamily: 'monospace',
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: () =>
                setState(() => _obscurePassword = !_obscurePassword),
            icon: Icon(
              _obscurePassword ? Icons.visibility : Icons.visibility_off,
              size: 18,
            ),
            tooltip: _obscurePassword ? '显示密码' : '隐藏密码',
          ),
          IconButton(
            onPressed: () => _copyToClipboard(widget.password.password, '密码'),
            icon: const Icon(Icons.copy, size: 18),
            tooltip: '复制密码',
          ),
        ],
      ),
    );
  }

  /// 构建备注字段
  Widget _buildNotesField() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Theme.of(context).colorScheme.outline.withOpacity(0.2),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.note,
            color: Theme.of(context).colorScheme.primary,
            size: 20,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '备注',
                  style: TextStyle(
                    fontSize: 12,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  widget.password.notes!,
                  style: TextStyle(
                    fontSize: 14,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: () => _copyToClipboard(widget.password.notes!, '备注'),
            icon: const Icon(Icons.copy, size: 18),
            tooltip: '复制备注',
          ),
        ],
      ),
    );
  }

  /// 构建元信息
  Widget _buildMetaInfo() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.5),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '元信息',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(
                Icons.schedule,
                size: 16,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: 8),
              Text(
                '创建时间: ${_formatDateTime(widget.password.createdAt)}',
                style: TextStyle(
                  fontSize: 12,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Icon(
                Icons.update,
                size: 16,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: 8),
              Text(
                '更新时间: ${_formatDateTime(widget.password.updatedAt)}',
                style: TextStyle(
                  fontSize: 12,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// 构建自定义字段部分
  Widget _buildCustomFieldsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '自定义字段',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
        const SizedBox(height: 8),
        ...widget.password.customFields.entries
            .map((entry) =>
                _buildCustomFieldInfoField(entry.key, entry.value.toString()))
            .toList(),
      ],
    );
  }

  /// 构建自定义字段信息项
  Widget _buildCustomFieldInfoField(String label, String value) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Theme.of(context).colorScheme.outline.withOpacity(0.2),
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.extension,
            color: Theme.of(context).colorScheme.primary,
            size: 20,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 16,
                    color: Theme.of(context).colorScheme.onSurface,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: () => _copyToClipboard(value, label),
            icon: const Icon(Icons.copy, size: 18),
            tooltip: '复制$label',
          ),
        ],
      ),
    );
  }

  /// 格式化日期时间
  String _formatDateTime(DateTime dateTime) {
    return '${dateTime.year}-${dateTime.month.toString().padLeft(2, '0')}-${dateTime.day.toString().padLeft(2, '0')} '
        '${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
  }

  /// 显示版本信息弹窗
  Future<void> _showVersionInfo() async {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 500, maxHeight: 600),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // 标题栏
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primaryContainer,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(20),
                    topRight: Radius.circular(20),
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.primary,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.security,
                        color: Colors.white,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '关于应用',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Theme.of(context)
                                  .colorScheme
                                  .onPrimaryContainer,
                            ),
                          ),
                          Text(
                            '版本信息与功能介绍',
                            style: TextStyle(
                              fontSize: 14,
                              color: Theme.of(context)
                                  .colorScheme
                                  .onPrimaryContainer
                                  .withOpacity(0.7),
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: Icon(
                        Icons.close,
                        color: Theme.of(context).colorScheme.onPrimaryContainer,
                      ),
                    ),
                  ],
                ),
              ),
              // 内容区域
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: FutureBuilder<Map<String, String>>(
                    future: _getAppInfo(),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(
                          child: Padding(
                            padding: EdgeInsets.all(32.0),
                            child: CircularProgressIndicator(),
                          ),
                        );
                      }

                      final appInfo = snapshot.data ?? {};
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildVersionInfoRow(
                              '应用名称', appInfo['appName'] ?? '密码管理器'),
                          const SizedBox(height: 16),
                          _buildVersionInfoRow(
                              '版本号', appInfo['version'] ?? '1.0.0'),
                          const SizedBox(height: 16),
                          _buildVersionInfoRow(
                              '构建号', appInfo['buildNumber'] ?? '1'),
                          const SizedBox(height: 16),
                          _buildVersionInfoRow(
                              '包名',
                              appInfo['packageName'] ??
                                  'com.example.password_manager'),
                          const SizedBox(height: 24),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              color: Theme.of(context)
                                  .colorScheme
                                  .surfaceVariant
                                  .withOpacity(0.5),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Icon(
                                      Icons.star,
                                      color:
                                          Theme.of(context).colorScheme.primary,
                                      size: 20,
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      '功能特性',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600,
                                        color: Theme.of(context)
                                            .colorScheme
                                            .onSurface,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  '• 安全的密码存储与管理\n'
                                  '• 强密码生成器\n'
                                  '• 分类管理与搜索\n'
                                  '• 数据导入导出\n'
                                  '• 多主题切换\n'
                                  '• 自定义界面\n'
                                  '• 自动锁定保护',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onSurfaceVariant,
                                    height: 1.6,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 20),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Theme.of(context)
                                  .colorScheme
                                  .tertiaryContainer
                                  .withOpacity(0.3),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: Theme.of(context)
                                    .colorScheme
                                    .tertiary
                                    .withOpacity(0.3),
                              ),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.security,
                                  color: Theme.of(context).colorScheme.tertiary,
                                  size: 20,
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    '您的数据安全是我们的首要任务，所有密码数据均采用本地加密存储。',
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: Theme.of(context)
                                          .colorScheme
                                          .onTertiaryContainer,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 获取应用信息
  Future<Map<String, String>> _getAppInfo() async {
    try {
      PackageInfo packageInfo = await PackageInfo.fromPlatform();
      return {
        'appName': packageInfo.appName,
        'version': packageInfo.version,
        'buildNumber': packageInfo.buildNumber,
        'packageName': packageInfo.packageName,
      };
    } catch (e) {
      return {
        'appName': '密码管理器',
        'version': '1.0.0',
        'buildNumber': '1',
        'packageName': 'com.example.password_manager',
      };
    }
  }

  /// 构建版本信息行
  Widget _buildVersionInfoRow(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 80,
          child: Text(
            label,
            style: TextStyle(
              fontWeight: FontWeight.w500,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              fontSize: 14,
            ),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: Theme.of(context).colorScheme.outline.withOpacity(0.2),
              ),
            ),
            child: Text(
              value,
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurface,
                fontFamily: 'monospace',
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
