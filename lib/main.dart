import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'services/app_update_service.dart';
import 'package:password_manager/pages/home_page.dart';
import 'package:password_manager/pages/login_page.dart';
import 'package:password_manager/services/auth_service.dart';
import 'package:password_manager/services/legacy_settings_migration.dart';
import 'package:password_manager/services/local_server_service.dart';
import 'package:password_manager/services/secure_storage_service.dart';
import 'package:password_manager/services/settings_service.dart';
import 'package:password_manager/services/theme_service.dart';
import 'package:password_manager/services/web_storage_service.dart';
import 'package:password_manager/utils/desktop_window_layout.dart';
import 'package:screen_retriever/screen_retriever.dart';
import 'package:window_manager/window_manager.dart';

void main() async {
  // make sure flutter is initialized
  WidgetsFlutterBinding.ensureInitialized();

  // 配置桌面窗口（仅在桌面平台）
  if (!kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.windows ||
          defaultTargetPlatform == TargetPlatform.linux ||
          defaultTargetPlatform == TargetPlatform.macOS)) {
    await windowManager.ensureInitialized();

    var windowLayout = fallbackDesktopWindowLayout;
    try {
      final primaryDisplay = await screenRetriever.getPrimaryDisplay();
      final displays = await screenRetriever.getAllDisplays();
      final cursorPosition = await screenRetriever.getCursorScreenPoint();
      final visibleWorkArea = selectCurrentVisibleWorkArea(
        displayAreas: displays.map((display) {
          final visiblePosition = display.visiblePosition ?? Offset.zero;
          return (
            bounds: Rect.fromLTWH(
              visiblePosition.dx,
              visiblePosition.dy,
              display.size.width,
              display.size.height,
            ),
            visibleWorkArea: display.visibleSize ?? display.size,
          );
        }).toList(),
        cursorPosition: cursorPosition,
        fallbackSize: primaryDisplay.visibleSize ?? primaryDisplay.size,
      );
      if (visibleWorkArea.width > 0 && visibleWorkArea.height > 0) {
        windowLayout = calculateDesktopWindowLayout(visibleWorkArea);
      }
    } catch (_) {
      // 保留安全回退尺寸，避免显示器信息异常阻止应用启动。
    }

    final windowOptions = WindowOptions(
      size: windowLayout.initialSize,
      minimumSize: windowLayout.minimumSize,
      center: true, // 居中显示
      backgroundColor: Colors.transparent,
      skipTaskbar: false,
      titleBarStyle: TitleBarStyle.normal,
      windowButtonVisibility: true,
    );

    await windowManager.waitUntilReadyToShow(windowOptions, () async {
      await windowManager.show();
      await windowManager.focus();
    });
  }

  try {
    await LegacySettingsMigration.migrate();
  } catch (_) {
    // Do not initialize preferences, authentication, or a library on failure.
    runApp(MaterialApp(
      title: 'Lockora',
      home: SettingsMigrationErrorPage(onRetry: main),
    ));
    return;
  }

  // 初始化Web存储服务（所有平台）
  // print('初始化密码存储服务...');
  await WebStorageService.instance.initialize();
  // print('✅ 密码存储服务初始化完成');

  String? startupError;

  // 初始化安全存储服务（AES加密密钥管理 + 数据迁移）
  try {
    await SecureStorageService.instance.initialize();
  } catch (e) {
    debugPrint('安全存储初始化失败：$e');
    startupError = e.toString();
  }

  // 初始化设置服务
  await SettingsService.instance.init();

  // 初始化主题服务
  await ThemeService.instance.initialize();

  // 初始化认证服务
  await AuthService.instance.initialize();

  // 启动本地服务器（用于浏览器扩展通信）
  if (!kIsWeb && startupError == null) {
    // print('开始启动本地服务器...');
    try {
      final success = await LocalServerService.instance.startServer();
      if (success) {
        // print('✅ 本地服务器启动成功！');
        // print('🌍 服务器地址: ${LocalServerService.instance.serverUrl}');
        // print('🔑 访问令牌: ${LocalServerService.instance.serverToken}');
      } else {
        // print('❌ 本地服务器启动失败');
      }
    } catch (e) {
      // print('❌ 启动本地服务器时出错: $e');
      // print('📋 错误堆栈: $stackTrace');
    }
  }

  // main app
  runApp(MyApp(startupError: startupError));
}

class SettingsMigrationErrorPage extends StatelessWidget {
  final VoidCallback onRetry;

  const SettingsMigrationErrorPage({super.key, required this.onRetry});

  @override
  Widget build(BuildContext context) => Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('旧版设置迁移未完成'),
                const SizedBox(height: 16),
                const Text('为保护已有密码和设置，应用已停止启动。请确认旧版设置文件可读取、磁盘可写后重试。',
                    textAlign: TextAlign.center),
                const SizedBox(height: 16),
                FilledButton(onPressed: onRetry, child: const Text('重试')),
              ],
            ),
          ),
        ),
      );
}

class MyApp extends StatefulWidget {
  final String? startupError;

  const MyApp({super.key, this.startupError});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> with WidgetsBindingObserver {
  late final UpdateRouteObserver _updateRoutes =
      UpdateRouteObserver(AppUpdateService.instance);

  Future<void> _initializeUpdates() async {
    if (kIsWeb || widget.startupError != null) return;
    final service = AppUpdateService.instance;
    await service.initialize(
      config: AppUpdateConfig.forPlatform(defaultTargetPlatform),
      preferences: await SharedPreferences.getInstance(),
      prepareInstall: () async {
        await AuthService.instance.lockApp();
        await LocalServerService.instance.stopServer();
        return true;
      },
      resumeAfterInstallFailure: () async {
        await LocalServerService.instance.startServer();
      },
    );
    if (service.automaticChecks)
      await service.checkForUpdates(background: true);
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance
        .addPostFrameCallback((_) => unawaited(_initializeUpdates()));

    // 添加应用生命周期监听
    WidgetsBinding.instance.addObserver(this);

    // 监听主题变化
    ThemeService.instance.addListener(_onThemeChanged);
    _updateSystemUI();
  }

  @override
  void dispose() {
    ThemeService.instance.removeListener(_onThemeChanged);
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);

    // 当应用进入后台或恢复时，确保服务器仍在运行
    if (state == AppLifecycleState.paused) {
      print('应用进入后台，保持服务器运行');
      // 不关闭服务器，让它继续运行
    } else if (state == AppLifecycleState.resumed) {
      print('应用恢复到前台，检查服务器状态');
      // 确保服务器仍在运行
      _ensureServerRunning();
    }
  }

  /// 确保服务器正在运行
  Future<void> _ensureServerRunning() async {
    if (widget.startupError != null ||
        AppUpdateService.instance.isPreparingInstall) return;

    try {
      if (!LocalServerService.instance.isRunning) {
        print('服务器未运行，重新启动...');
        final success = await LocalServerService.instance.startServer();
        if (success) {
          print('✅ 服务器重启成功');
        } else {
          print('❌ 服务器重启失败');
        }
      } else {
        print('服务器正常运行');
      }
    } catch (e) {
      print('检查服务器状态失败: $e');
    }
  }

  void _onThemeChanged() {
    setState(() {});
    _updateSystemUI();
  }

  void _updateSystemUI() {
    final isDark = ThemeService.instance.isDark;

    SystemChrome.setSystemUIOverlayStyle(
      SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
        systemNavigationBarColor:
            isDark ? const Color(0xFF0F0F0F) : const Color(0xFFF9FAFB),
        systemNavigationBarIconBrightness:
            isDark ? Brightness.light : Brightness.dark,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Lockora',
      navigatorObservers: [_updateRoutes],
      theme: ThemeService.instance.themeData,
      home: widget.startupError == null
          ? const AuthWrapper()
          : SecureStorageErrorPage(details: widget.startupError!),
    );
  }
}

class SecureStorageErrorPage extends StatelessWidget {
  final String details;

  const SecureStorageErrorPage({super.key, required this.details});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.lock_outline,
                  size: 48,
                  color: Theme.of(context).colorScheme.error,
                ),
                const SizedBox(height: 20),
                Text(
                  '安全存储不可用',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 12),
                const Text(
                  '为避免密码以明文保存，应用已停止读取和写入密码。请确认系统钥匙串可用后重新启动应用。',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                Text(
                  details,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// 认证包装器 - 决定显示登录页面还是主页
class AuthWrapper extends StatefulWidget {
  const AuthWrapper({super.key});

  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> with WidgetsBindingObserver {
  final AuthService _authService = AuthService.instance;
  bool _needsAuth = true;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _authService.addListener(_handleAuthStateChanged);
    _checkAuthStatus();
  }

  @override
  void dispose() {
    _authService.removeListener(_handleAuthStateChanged);
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);

    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.hidden ||
        state == AppLifecycleState.paused) {
      _authService.markBackgrounded(DateTime.now());
    } else if (state == AppLifecycleState.resumed) {
      _resumeFromBackground();
    }
  }

  Future<void> _resumeFromBackground() async {
    await _authService.resumeFromBackground(DateTime.now());
    _handleAuthStateChanged();
  }

  void _handleAuthStateChanged() {
    if (!mounted) return;
    final needsAuth = !_authService.isSessionUnlocked;
    if (needsAuth) {
      Navigator.maybeOf(context, rootNavigator: true)?.popUntil(
        (route) => route.isFirst,
      );
    }
    setState(() {
      _needsAuth = needsAuth;
      _isLoading = false;
    });
  }

  /// 检查认证状态并更新UI
  Future<void> _checkAuthStatus() async {
    try {
      final needsAuth = await _authService.needsAuthentication();

      if (mounted) {
        setState(() {
          _needsAuth = needsAuth;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _needsAuth = true;
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      // 显示加载界面
      return const Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('正在初始化...'),
            ],
          ),
        ),
      );
    }

    if (_needsAuth) {
      return const LoginPage();
    } else {
      return const HomePage();
    }
  }
}
