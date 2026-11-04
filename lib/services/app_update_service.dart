import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AppUpdateConfig {
  final String feedURL;
  final String publicKey;
  const AppUpdateConfig({required this.feedURL, required this.publicKey});

  factory AppUpdateConfig.forPlatform(TargetPlatform platform) => platform ==
          TargetPlatform.macOS
      ? const AppUpdateConfig(
          feedURL: String.fromEnvironment('LOCKORA_MACOS_FEED_URL'),
          publicKey: String.fromEnvironment('LOCKORA_MACOS_PUBLIC_KEY'))
      : platform == TargetPlatform.windows
          ? const AppUpdateConfig(
              feedURL: String.fromEnvironment('LOCKORA_WINDOWS_FEED_URL'),
              publicKey: String.fromEnvironment('LOCKORA_WINDOWS_PUBLIC_KEY'))
          : const AppUpdateConfig(feedURL: '', publicKey: '');

  bool get isValid {
    final uri = Uri.tryParse(feedURL);
    if (uri == null ||
        uri.scheme != 'https' ||
        uri.host.isEmpty ||
        uri.userInfo.isNotEmpty) return false;
    try {
      return base64Decode(publicKey).length == 32;
    } on FormatException {
      return false;
    }
  }
}

class AppUpdateService extends ChangeNotifier {
  static final instance = AppUpdateService();
  final MethodChannel _channel;
  AppUpdateService({MethodChannel? channel})
      : _channel =
            channel ?? const MethodChannel('me.tbtparent.lockora/updater');

  SharedPreferences? _preferences;
  Future<bool> Function()? _prepareInstall;
  Future<void> Function()? _resumeAfterInstallFailure;
  Future<bool>? _check;
  bool _configured = false;
  bool _automatic = true;
  bool _checking = false;
  bool _preparing = false;
  bool _disposed = false;
  int _operations = 0;
  final Set<Route<dynamic>> _dialogs = {};
  String _message = '更新功能尚未配置';

  bool get isConfigured => _configured;
  bool get isPreparingInstall => _preparing;
  bool get automaticChecks => _automatic;
  bool get isChecking => _checking;
  bool get canInstall =>
      _configured && !_preparing && _operations == 0 && _dialogs.isEmpty;
  String get message => _message;

  Future<void> initialize(
      {required AppUpdateConfig config,
      required SharedPreferences preferences,
      required Future<bool> Function() prepareInstall,
      Future<void> Function()? resumeAfterInstallFailure}) async {
    _preferences = preferences;
    _prepareInstall = prepareInstall;
    _resumeAfterInstallFailure = resumeAfterInstallFailure;
    _configured = false;
    _automatic = preferences.getBool('automatic_update_checks') ?? true;
    _channel.setMethodCallHandler(handleNativeCall);
    if (!config.isValid) {
      _configured = false;
      _message = '更新功能尚未配置';
      _notify();
      return;
    }
    try {
      final result = await _channel.invokeMethod<bool>('configure', {
        'feedURL': config.feedURL,
        'publicKey': config.publicKey,
        'automaticChecks': _automatic,
      });
      _configured = result != false;
      _message = _configured ? '可检查新版本并查看更新说明' : '更新功能不可用';
      _publishGuard();
    } on PlatformException catch (error) {
      _message = error.message ?? '更新初始化失败，请重启应用后重试';
    } on MissingPluginException {
      _message = '此平台暂不支持应用内更新';
    }
    _notify();
  }

  Future<bool> checkForUpdates({bool background = false}) {
    if (!_configured || (background && !_automatic)) return Future.value(false);
    if (background) {
      final previous = _preferences?.getInt('last_successful_update_check');
      if (previous != null &&
          DateTime.now().millisecondsSinceEpoch - previous <
              const Duration(hours: 24).inMilliseconds) {
        return Future.value(false);
      }
    }
    if (_check != null) return _check!;
    return _check = _performCheck(background).whenComplete(() => _check = null);
  }

  Future<bool> _performCheck(bool background) async {
    _checking = true;
    _message = '正在检查更新…';
    _notify();
    try {
      await _channel
          .invokeMethod<void>('checkForUpdates', {'background': background});
      return true;
    } on PlatformException catch (error) {
      _checking = false;
      _message = error.message ?? '无法检查更新，请稍后重试';
    } on MissingPluginException {
      _checking = false;
      _message = '此平台暂不支持应用内更新';
    }
    _notify();
    return false;
  }

  Future<void> setAutomaticChecks(bool enabled) async {
    if (!_configured) return;
    try {
      await _channel
          .invokeMethod<void>('setAutomaticChecks', {'enabled': enabled});
      if (await _preferences!.setBool('automatic_update_checks', enabled)) {
        _automatic = enabled;
      }
    } on PlatformException catch (error) {
      _message = error.message ?? '无法保存更新设置，请重试';
    }
    _notify();
  }

  Future<T> protect<T>(Future<T> Function() operation) async {
    if (_preparing) throw StateError('正在准备安装更新，请稍后重试');
    _operations++;
    _publishGuard();
    try {
      return await operation();
    } finally {
      _operations--;
      _publishGuard();
    }
  }

  Future<dynamic> handleNativeCall(MethodCall call) async {
    if (_disposed) return false;
    if (call.method == 'prepareInstall') {
      if (!canInstall) return false;
      _preparing = true;
      _publishGuard();
      try {
        if (await _prepareInstall!()) return true;
      } catch (_) {
        _message = '暂时无法退出安装，请完成当前操作后重试';
      }
      _preparing = false;
      _publishGuard();
      _notify();
      return false;
    }
    if (call.method == 'updateStatus') {
      final arguments = Map<String, dynamic>.from(call.arguments as Map);
      final status = arguments['status'];
      if (status == 'available' || status == 'upToDate') {
        await _preferences?.setInt('last_successful_update_check',
            DateTime.now().millisecondsSinceEpoch);
      }
      if (_preparing &&
          (status == 'error' || status == 'idle' || status == 'blocked')) {
        _preparing = false;
        try {
          await _resumeAfterInstallFailure?.call();
        } catch (_) {
          _message = '更新未完成，请重新启动 Lockora';
          _notify();
          return null;
        }
        _publishGuard();
      }
      _checking = status == 'checking';
      _message = arguments['message'] as String? ??
          switch (status) {
            'available' => '发现新版本，请在更新窗口中查看详情',
            'upToDate' => '当前已是最新版本',
            'error' => '无法检查更新，请稍后重试',
            'blocked' => '请先完成当前编辑或保存操作，再继续安装',
            'installing' => '正在安装更新…',
            _ => '可检查新版本并查看更新说明',
          };
      _notify();
    }
    return null;
  }

  void _routeChanged(Route<dynamic> route, bool added) {
    if (route is! PopupRoute) return;
    added ? _dialogs.add(route) : _dialogs.remove(route);
    _publishGuard();
  }

  void _publishGuard() {
    if (_configured && !_disposed) {
      unawaited(_channel.invokeMethod<void>(
          'setCanInstall', {'allowed': canInstall}).catchError((Object _) {}));
    }
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _channel.setMethodCallHandler(null);
    super.dispose();
  }
}

class UpdateRouteObserver extends NavigatorObserver {
  final AppUpdateService service;
  UpdateRouteObserver(this.service);
  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) =>
      service._routeChanged(route, true);
  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) =>
      service._routeChanged(route, false);
  @override
  void didRemove(Route<dynamic> route, Route<dynamic>? previousRoute) =>
      service._routeChanged(route, false);
  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    if (oldRoute != null) service._routeChanged(oldRoute, false);
    if (newRoute != null) service._routeChanged(newRoute, true);
  }
}
