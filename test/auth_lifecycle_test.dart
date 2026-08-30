import 'package:flutter_test/flutter_test.dart';
import 'package:password_manager/services/auth_service.dart';
import 'package:password_manager/services/settings_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final authService = AuthService.instance;

  Future<void> unlock({int timeoutMinutes = 30}) async {
    SharedPreferences.setMockInitialValues({});
    await SettingsService.instance.init();
    await SettingsService.instance.setLockTimeout(timeoutMinutes);
    await authService.initialize();
    await authService.setMasterPassword('password123', 'password123');
  }

  test('foreground time alone never triggers automatic lock', () async {
    await unlock(timeoutMinutes: 1);

    final needsAuth = await authService.resumeFromBackground(
      DateTime(2026, 8, 30, 12, 0),
    );

    expect(needsAuth, isFalse);
    expect(authService.isSessionUnlocked, isTrue);
  });

  test('background duration below timeout keeps the session unlocked',
      () async {
    await unlock(timeoutMinutes: 30);
    final backgroundedAt = DateTime(2026, 8, 30, 12, 0);

    authService.markBackgrounded(backgroundedAt);
    final needsAuth = await authService.resumeFromBackground(
      backgroundedAt.add(const Duration(minutes: 29, seconds: 59)),
    );

    expect(needsAuth, isFalse);
    expect(authService.isSessionUnlocked, isTrue);
  });

  test('background duration at timeout locks the session', () async {
    await unlock(timeoutMinutes: 30);
    final backgroundedAt = DateTime(2026, 8, 30, 12, 0);

    authService.markBackgrounded(backgroundedAt);
    final needsAuth = await authService.resumeFromBackground(
      backgroundedAt.add(const Duration(minutes: 30)),
    );

    expect(needsAuth, isTrue);
    expect(authService.isSessionUnlocked, isFalse);
  });

  test('multiple background signals keep the earliest timestamp', () async {
    await unlock(timeoutMinutes: 30);
    final firstSignal = DateTime(2026, 8, 30, 12, 0);

    authService.markBackgrounded(firstSignal);
    authService.markBackgrounded(
      firstSignal.add(const Duration(minutes: 10)),
    );
    final needsAuth = await authService.resumeFromBackground(
      firstSignal.add(const Duration(minutes: 30)),
    );

    expect(needsAuth, isTrue);
    expect(authService.isSessionUnlocked, isFalse);
  });
}
