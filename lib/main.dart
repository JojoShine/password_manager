import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:password_manager/pages/home_page.dart';
import 'package:password_manager/pages/login_page.dart';
import 'package:password_manager/services/auth_service.dart';
import 'package:password_manager/services/local_server_service.dart';
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
      size: Size(900, 900), // 默认窗口大小：宽1080，高1250
      minimumSize: Size(400, 600), // 最小窗口大小
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

  // 初始化Web存储服务（所有平台）
  // print('初始化密码存储服务...');
  await WebStorageService.instance.initialize();
  // print('✅ 密码存储服务初始化完成');

  // 初始化设置服务
  await SettingsService.instance.init();

  // 初始化主题服务
  await ThemeService.instance.initialize();

  // 初始化认证服务
  await AuthService.instance.initialize();

  // 启动本地服务器（用于浏览器扩展通信）
  if (!kIsWeb) {
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
    } catch (e, stackTrace) {
      // print('❌ 启动本地服务器时出错: $e');
      // print('📋 错误堆栈: $stackTrace');
    }
  }

  // main app
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    
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

class _AuthWrapperState extends State<AuthWrapper> with WidgetsBindingObserver {
  final AuthService _authService = AuthService.instance;
  bool _needsAuth = true;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _checkAuthStatus();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);

    // 当应用从后台回到前台时，重新检查认证状态
    if (state == AppLifecycleState.resumed) {
      _checkAuthStatus();
    }
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

        // 如果当前在主页面但需要认证，强制跳转到登录页
        if (needsAuth && !_isLoading) {
          _navigateToLogin();
        }
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

  /// 跳转到登录页面
  void _navigateToLogin() {
    if (mounted) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (context) => const LoginPage()),
        (route) => false,
      );
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
