import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:password_manager/services/app_update_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('test/lockora/updater');
  final calls = <MethodCall>[];
  late AppUpdateService service;
  late SharedPreferences prefs;
  AppUpdateConfig config(
          {String feed = 'https://updates.example/macos.xml', String? key}) =>
      AppUpdateConfig(
          feedURL: feed, publicKey: key ?? base64Encode(List.filled(32, 1)));

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    calls.clear();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      calls.add(call);
      return true;
    });
    service = AppUpdateService(channel: channel);
  });
  tearDown(() {
    service.dispose();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  test('invalid feed or missing signing key cannot enable updates', () async {
    await service.initialize(
        config: config(feed: 'http://updates.example/feed'),
        preferences: prefs,
        prepareInstall: () async => true);
    expect(service.isConfigured, isFalse);
    expect(calls.where((c) => c.method == 'configure'), isEmpty);
    expect(await service.checkForUpdates(), isFalse);
  });

  test(
      'disabled automatic checks are preserved while manual checks remain available',
      () async {
    await prefs.setBool('automatic_update_checks', false);
    await service.initialize(
        config: config(), preferences: prefs, prepareInstall: () async => true);
    expect(service.automaticChecks, isFalse);
    expect(
        (calls.firstWhere((c) => c.method == 'configure').arguments
            as Map)['automaticChecks'],
        false);
    expect(await service.checkForUpdates(), isTrue);
    expect(calls.where((c) => c.method == 'checkForUpdates').length, 1);
  });

  test('concurrent manual checks share a request and errors remain retryable',
      () async {
    final gate = Completer<bool>();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      calls.add(call);
      if (call.method == 'checkForUpdates') return gate.future;
      return true;
    });
    await service.initialize(
        config: config(), preferences: prefs, prepareInstall: () async => true);
    final first = service.checkForUpdates();
    final second = service.checkForUpdates();
    gate.completeError(PlatformException(code: 'offline', message: '无法检查更新'));
    expect(await first, isFalse);
    expect(await second, isFalse);
    expect(calls.where((c) => c.method == 'checkForUpdates').length, 1);
    expect(service.message, contains('无法检查更新'));
    expect(service.isChecking, isFalse);
  });

  test(
      'busy operations block installation and release their guard after failure',
      () async {
    await service.initialize(
        config: config(), preferences: prefs, prepareInstall: () async => true);
    final gate = Completer<void>();
    final work = service.protect(() => gate.future);
    expect(service.canInstall, isFalse);
    expect(await service.handleNativeCall(const MethodCall('prepareInstall')),
        false);
    gate.completeError(StateError('write failed'));
    await expectLater(work, throwsStateError);
    expect(service.canInstall, isTrue);
    expect(await service.handleNativeCall(const MethodCall('prepareInstall')),
        true);
    expect(service.canInstall, isFalse);
  });

  testWidgets('a modal route blocks installation until removed',
      (tester) async {
    await service.initialize(
        config: config(), preferences: prefs, prepareInstall: () async => true);
    late BuildContext page;
    await tester.pumpWidget(MaterialApp(
        navigatorObservers: [UpdateRouteObserver(service)],
        home: Builder(builder: (context) {
          page = context;
          return const Scaffold();
        })));
    showDialog<void>(
        context: page, builder: (_) => const AlertDialog(title: Text('编辑密码')));
    await tester.pumpAndSettle();
    expect(service.canInstall, isFalse);
    Navigator.of(page).pop();
    await tester.pumpAndSettle();
    expect(service.canInstall, isTrue);
  });
  test(
      'successful background check is not repeated within 24 hours but manual checks work',
      () async {
    await service.initialize(
        config: config(), preferences: prefs, prepareInstall: () async => true);
    await service.handleNativeCall(
        const MethodCall('updateStatus', {'status': 'upToDate'}));
    calls.clear();
    expect(await service.checkForUpdates(background: true), isFalse);
    expect(calls.where((c) => c.method == 'checkForUpdates'), isEmpty);
    expect(await service.checkForUpdates(), isTrue);
  });

  test('an installation error releases guards and resumes the locked app',
      () async {
    var resumed = false;
    await service.initialize(
        config: config(),
        preferences: prefs,
        prepareInstall: () async => true,
        resumeAfterInstallFailure: () async {
          resumed = true;
        });
    expect(await service.handleNativeCall(const MethodCall('prepareInstall')),
        true);
    await service.handleNativeCall(const MethodCall(
        'updateStatus', {'status': 'error', 'message': '安装失败'}));
    expect(service.canInstall, isTrue);
    expect(resumed, isTrue);
    expect(service.message, '安装失败');
  });
}
