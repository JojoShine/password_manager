import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 主题模式枚举
enum ThemeMode { light, dark }

/// 主题服务 - 管理应用主题切换
class ThemeService extends ChangeNotifier {
  static final ThemeService _instance = ThemeService._internal();
  static ThemeService get instance => _instance;

  ThemeService._internal();

  static const String _themeKey = 'app_theme_mode';
  ThemeMode _currentTheme = ThemeMode.dark; // 默认深色主题

  ThemeMode get currentTheme => _currentTheme;
  bool get isDark => _currentTheme == ThemeMode.dark;

  /// 初始化主题服务
  Future<void> initialize() async {
    final prefs = await SharedPreferences.getInstance();
    final themeIndex = prefs.getInt(_themeKey) ?? ThemeMode.dark.index;
    _currentTheme = ThemeMode.values[themeIndex];
    notifyListeners();
  }

  /// 切换主题
  Future<void> toggleTheme() async {
    _currentTheme =
        _currentTheme == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_themeKey, _currentTheme.index);

    notifyListeners();
  }

  /// 设置特定主题
  Future<void> setTheme(ThemeMode theme) async {
    if (_currentTheme != theme) {
      _currentTheme = theme;

      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_themeKey, _currentTheme.index);

      notifyListeners();
    }
  }

  /// 获取当前主题数据
  ThemeData get themeData {
    return isDark ? _darkTheme : _lightTheme;
  }

  /// 自定义深色主题
  static final ThemeData _darkTheme = ThemeData(
    brightness: Brightness.dark,
    useMaterial3: true,

    // 自定义颜色方案
    colorScheme: const ColorScheme.dark(
      primary: Color(0xFF4A9EFF), // 亮蓝色
      primaryContainer: Color(0xFF1E3A5F),
      secondary: Color(0xFF7C4DFF), // 紫色
      secondaryContainer: Color(0xFF3C2A6B),
      surface: Color(0xFF121212),
      onPrimary: Colors.white,
      onSecondary: Colors.white,
      onSurface: Colors.white,
      onSurfaceVariant: Color(0xFFE0E0E0),
      outline: Color(0xFF6B6B6B),
      error: Color(0xFFFF6B6B),
    ),

    // 自定义组件主题
    appBarTheme: const AppBarTheme(
      centerTitle: true,
      elevation: 0,
      backgroundColor: Colors.transparent,
      foregroundColor: Colors.white,
    ),

    cardTheme: const CardTheme(
      elevation: 8,
      margin: EdgeInsets.all(8),
      color: Color(0xFF2C2C2C),
    ),

    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        elevation: 4,
        backgroundColor: const Color(0xFF4A9EFF),
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),
    ),

    scaffoldBackgroundColor: const Color(0xFF0F0F0F),

    inputDecorationTheme: InputDecorationTheme(
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: Color(0xFF4A4A4A)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: Color(0xFF4A4A4A)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: Color(0xFF4A9EFF), width: 2),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      fillColor: const Color(0xFF2C2C2C),
      filled: true,
      labelStyle: const TextStyle(color: Color(0xFFE0E0E0)),
      hintStyle: const TextStyle(color: Color(0xFF8A8A8A)),
    ),

    iconTheme: const IconThemeData(
      color: Color(0xFFE0E0E0),
      size: 24,
    ),

    snackBarTheme: const SnackBarThemeData(
      backgroundColor: Color(0xFF333333),
      contentTextStyle: TextStyle(color: Colors.white),
      behavior: SnackBarBehavior.fixed,
    ),
  );

  /// 自定义浅色主题
  static final ThemeData _lightTheme = ThemeData(
    brightness: Brightness.light,
    useMaterial3: true,

    // 自定义颜色方案
    colorScheme: const ColorScheme.light(
      primary: Color(0xFF2563EB), // 深蓝色
      primaryContainer: Color(0xFFEBF3FF),
      secondary: Color(0xFF6366F1), // 靛蓝色
      secondaryContainer: Color(0xFFF3F4F6), // 浅灰色背景
      surface: Colors.white,
      surfaceVariant: Color(0xFFF8FAFC), // 更浅的表面色
      onPrimary: Colors.white,
      onSecondary: Colors.white,
      onSurface: Color(0xFF111827), // 更深的文本色
      onSurfaceVariant: Color(0xFF4B5563), // 更深的次要文本色
      onSecondaryContainer: Color(0xFF374151), // 分类标签文本色
      outline: Color(0xFFE5E7EB), // 更浅的边框色
      error: Color(0xFFDC2626),
    ),

    // 自定义组件主题
    appBarTheme: const AppBarTheme(
      centerTitle: true,
      elevation: 0,
      backgroundColor: Colors.transparent,
      foregroundColor: Color(0xFF1F2937),
    ),

    cardTheme: CardTheme(
      elevation: 1,
      margin: const EdgeInsets.all(8),
      color: Colors.white,
      shadowColor: Colors.black.withOpacity(0.1),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: const Color(0xFFE5E7EB).withOpacity(0.5),
          width: 0.5,
        ),
      ),
    ),

    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        elevation: 4,
        backgroundColor: const Color(0xFF2563EB),
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),
    ),

    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: const Color(0xFF2563EB),
        side: const BorderSide(color: Color(0xFF2563EB), width: 1.5),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),
    ),

    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: const Color(0xFF2563EB),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    ),

    floatingActionButtonTheme: const FloatingActionButtonThemeData(
      backgroundColor: Color(0xFF2563EB),
      foregroundColor: Colors.white,
      elevation: 6,
    ),

    scaffoldBackgroundColor: const Color(0xFFF9FAFB),

    inputDecorationTheme: InputDecorationTheme(
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: Color(0xFFD1D5DB)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: Color(0xFFD1D5DB)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: Color(0xFF2563EB), width: 2),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      fillColor: Colors.white,
      filled: true,
      labelStyle: const TextStyle(color: Color(0xFF6B7280)),
      floatingLabelStyle: const TextStyle(
        color: Color(0xFF2563EB),
        backgroundColor: Colors.transparent,
      ),
      hintStyle: const TextStyle(color: Color(0xFF9CA3AF)),
    ),

    iconTheme: const IconThemeData(
      color: Color(0xFF6B7280),
      size: 24,
    ),

    snackBarTheme: const SnackBarThemeData(
      backgroundColor: Color(0xFF374151),
      contentTextStyle: TextStyle(color: Colors.white),
      behavior: SnackBarBehavior.fixed,
    ),
  );
}
