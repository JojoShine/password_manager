import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:password_manager/services/auth_service.dart';
import 'package:password_manager/services/local_server_service.dart';
import 'package:password_manager/services/settings_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final server = LocalServerService.instance;

  setUpAll(() {
    HttpOverrides.global = null;
  });

  setUp(() async {
    await server.stopServer();
    SharedPreferences.setMockInitialValues({});
    await SettingsService.instance.init();
    await AuthService.instance.initialize();
    await AuthService.instance.setMasterPassword(
      'password123',
      'password123',
    );
    expect(await server.startServer(), isTrue);
  });

  tearDown(() async {
    server.setHealthProbeForTesting(null);
    await server.stopServer();
  });

  test('default health probe performs a real authenticated ping', () async {
    await server.performHealthCheckForTesting();

    expect(server.consecutiveHealthCheckFailuresForTesting, 0);
  });

  test('a failed probe increments the consecutive failure count', () async {
    server.setHealthProbeForTesting(() async => false);

    await server.performHealthCheckForTesting();

    expect(server.consecutiveHealthCheckFailuresForTesting, 1);
  });

  test('a successful probe clears earlier failures', () async {
    server.setHealthProbeForTesting(() async => false);
    await server.performHealthCheckForTesting();
    await server.performHealthCheckForTesting();
    expect(server.consecutiveHealthCheckFailuresForTesting, 2);

    server.setHealthProbeForTesting(() async => true);
    await server.performHealthCheckForTesting();

    expect(server.consecutiveHealthCheckFailuresForTesting, 0);
  });
}
