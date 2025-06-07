import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SettingsService extends ChangeNotifier {
  static final SettingsService _instance = SettingsService._internal();
  static SettingsService get instance => _instance;

  SettingsService._internal();

  SharedPreferences? _prefs;

  // 设置项
  String _appTitle = '甜宝塔的密码管理工具';
  String? _logoPath;
  String? _backgroundPath;
  int _lockTimeoutMinutes = 30;

  // Getters
  String get appTitle => _appTitle;
  String? get logoPath => _logoPath;
  String? get backgroundPath => _backgroundPath;
  int get lockTimeoutMinutes => _lockTimeoutMinutes;

  // 默认logo和背景图片
  String get defaultLogoPath => 'assets/logo.jpg';
  String get defaultBackgroundPath => 'assets/bg.png';

  /// 初始化设置服务
  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
    await _loadSettings();
  }

  /// 加载设置
  Future<void> _loadSettings() async {
    if (_prefs == null) return;

    _appTitle = _prefs!.getString('app_title') ?? '甜宝塔的密码管理工具';
    _logoPath = _prefs!.getString('logo_path');
    _backgroundPath = _prefs!.getString('background_path');
    _lockTimeoutMinutes = _prefs!.getInt('lock_timeout_minutes') ?? 30;

    notifyListeners();
  }

  /// 设置应用标题
  Future<void> setAppTitle(String title) async {
    if (_prefs == null) return;

    _appTitle = title;
    await _prefs!.setString('app_title', title);
    notifyListeners();
  }

  /// 设置自定义logo
  Future<void> setCustomLogo(String filePath) async {
    if (_prefs == null) return;

    try {
      // 获取应用文档目录
      final Directory appDocDir = await getApplicationDocumentsDirectory();
      final String customAssetsDir = '${appDocDir.path}/custom_assets';

      // 创建自定义资源目录
      final Directory dir = Directory(customAssetsDir);
      if (!await dir.exists()) {
        await dir.create(recursive: true);
      }

      // 复制文件到应用目录
      final File sourceFile = File(filePath);
      final String fileName = 'custom_logo${_getFileExtension(filePath)}';
      final String targetPath = '$customAssetsDir/$fileName';
      await sourceFile.copy(targetPath);

      _logoPath = targetPath;
      await _prefs!.setString('logo_path', targetPath);
      notifyListeners();
    } catch (e) {
    // print('设置自定义logo失败: $e');
      rethrow;
    }
  }

  /// 设置自定义背景图片
  Future<void> setCustomBackground(String filePath) async {
    if (_prefs == null) return;

    try {
      // 获取应用文档目录
      final Directory appDocDir = await getApplicationDocumentsDirectory();
      final String customAssetsDir = '${appDocDir.path}/custom_assets';

      // 创建自定义资源目录
      final Directory dir = Directory(customAssetsDir);
      if (!await dir.exists()) {
        await dir.create(recursive: true);
      }

      // 复制文件到应用目录
      final File sourceFile = File(filePath);
      final String fileName = 'custom_background${_getFileExtension(filePath)}';
      final String targetPath = '$customAssetsDir/$fileName';
      await sourceFile.copy(targetPath);

      _backgroundPath = targetPath;
      await _prefs!.setString('background_path', targetPath);
      notifyListeners();
    } catch (e) {
    // print('设置自定义背景失败: $e');
      rethrow;
    }
  }

  /// 重置logo为默认
  Future<void> resetLogo() async {
    if (_prefs == null) return;

    // 删除自定义logo文件
    if (_logoPath != null) {
      try {
        final File file = File(_logoPath!);
        if (await file.exists()) {
          await file.delete();
        }
      } catch (e) {
    // print('删除自定义logo文件失败: $e');
      }
    }

    _logoPath = null;
    await _prefs!.remove('logo_path');
    notifyListeners();
  }

  /// 重置背景为默认
  Future<void> resetBackground() async {
    if (_prefs == null) return;

    // 删除自定义背景文件
    if (_backgroundPath != null) {
      try {
        final File file = File(_backgroundPath!);
        if (await file.exists()) {
          await file.delete();
        }
      } catch (e) {
    // print('删除自定义背景文件失败: $e');
      }
    }

    _backgroundPath = null;
    await _prefs!.remove('background_path');
    notifyListeners();
  }

  /// 设置锁定超时时间（分钟）
  Future<void> setLockTimeout(int minutes) async {
    if (_prefs == null) return;

    _lockTimeoutMinutes = minutes;
    await _prefs!.setInt('lock_timeout_minutes', minutes);
    notifyListeners();
  }

  /// 获取文件扩展名
  String _getFileExtension(String filePath) {
    return filePath.substring(filePath.lastIndexOf('.'));
  }

  /// 获取logo图片路径（优先使用自定义，否则使用默认）
  String getLogoImagePath() {
    return _logoPath ?? defaultLogoPath;
  }

  /// 获取背景图片路径（优先使用自定义，否则使用默认）
  String getBackgroundImagePath() {
    return _backgroundPath ?? defaultBackgroundPath;
  }

  /// 是否使用自定义logo
  bool get hasCustomLogo => _logoPath != null;

  /// 是否使用自定义背景
  bool get hasCustomBackground => _backgroundPath != null;
}
