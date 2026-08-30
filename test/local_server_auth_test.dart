import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:password_manager/services/auth_service.dart';
import 'package:password_manager/services/local_server_service.dart';
import 'package:password_manager/services/settings_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final authService = AuthService.instance;
  final server = LocalServerService.instance;

  setUpAll(() {
    HttpOverrides.global = null;
  });

  setUp(() async {
    await server.stopServer();
    SharedPreferences.setMockInitialValues({});
    await SettingsService.instance.init();
    await authService.initialize();
    await authService.setMasterPassword('password123', 'password123');
    expect(await server.startServer(), isTrue);
  });

  tearDown(() async {
    await server.stopServer();
  });

  Future<(int, Map<String, dynamic>)> get(
    String path, {
    String? token,
  }) async {
    final client = HttpClient();
    try {
      final request =
          await client.getUrl(Uri.parse('${server.serverUrl}$path'));
      if (token != null) {
        request.headers.set(HttpHeaders.authorizationHeader, 'Bearer $token');
      }
      final response = await request.close();
      final body = await utf8.decoder.bind(response).join();
      return (response.statusCode, jsonDecode(body) as Map<String, dynamic>);
    } finally {
      client.close(force: true);
    }
  }

  test('locked config does not disclose the server token', () async {
    await authService.lockApp();

    final (status, body) = await get('/config');

    expect(status, HttpStatus.locked);
    expect(body['code'], 'APP_LOCKED');
    expect(jsonEncode(body), isNot(contains(server.serverToken!)));
  });

  test('locked credential endpoint is rejected before token validation',
      () async {
    final token = server.serverToken!;
    await authService.lockApp();

    final (status, body) = await get('/api/passwords', token: token);

    expect(status, HttpStatus.locked);
    expect(body['code'], 'APP_LOCKED');
    expect(jsonEncode(body), isNot(contains('passwords')));
  });

  test('unlocked config and authenticated ping keep working', () async {
    final (configStatus, configBody) = await get('/config');
    final token =
        (configBody['data'] as Map<String, dynamic>)['token'] as String;
    final (pingStatus, pingBody) = await get('/api/ping', token: token);

    expect(configStatus, HttpStatus.ok);
    expect(token, server.serverToken);
    expect(pingStatus, HttpStatus.ok);
    expect((pingBody['data'] as Map<String, dynamic>)['message'], 'pong');
  });
}
