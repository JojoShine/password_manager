import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:password_manager/pages/home_page.dart';
import 'package:password_manager/pages/login_page.dart';
import 'package:password_manager/services/auth_service.dart';
import 'package:password_manager/services/settings_service.dart';
import 'package:password_manager/services/theme_service.dart';
import 'package:password_manager/services/web_storage_service.dart';
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

    const windowOptions = WindowOptions(
      size: Size(1080, 1250), // 默认窗口大小：宽1080，高1250
      minimumSize: Size(600, 800), // 最小窗口大小
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

  // 在Web平台初始化Web存储服务
  if (kIsWeb) {
    print('运行在Web平台，使用SharedPreferences存储数据');
    await WebStorageService.instance.initialize();
  }

  // 初始化设置服务
  await SettingsService.instance.init();

  // 初始化主题服务
  await ThemeService.instance.initialize();

  // 初始化认证服务
  await AuthService.instance.initialize();

  // main app
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  @override
  void initState() {
    super.initState();

    // 监听主题变化
    ThemeService.instance.addListener(_onThemeChanged);
    _updateSystemUI();
  }

  @override
  void dispose() {
    ThemeService.instance.removeListener(_onThemeChanged);
    super.dispose();
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
      title: 'Password Manager',
      theme: ThemeService.instance.themeData,
      home: const AuthWrapper(),
    );
  }
}

/// 认证包装器 - 决定显示登录页面还是主页
class AuthWrapper extends StatefulWidget {
  const AuthWrapper({super.key});

  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> {
  final AuthService _authService = AuthService.instance;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<bool>(
      future: _checkAuthStatus(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
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

        final needsAuth = snapshot.data ?? true;

        if (needsAuth) {
          return const LoginPage();
        } else {
          return const HomePage();
        }
      },
    );
  }

  /// 检查认证状态
  Future<bool> _checkAuthStatus() async {
    try {
      // 检查是否需要认证
      final needsAuth = await _authService.needsAuthentication();

      if (!needsAuth) {
        // 检查是否在免密登录时间内
        final isWithinAutoUnlock = await _authService.isWithinAutoUnlockTime();
        return !isWithinAutoUnlock;
      }

      return needsAuth;
    } catch (e) {
      // 如果出现错误，默认需要认证
      return true;
    }
  }
}
