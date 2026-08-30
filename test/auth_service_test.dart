import 'package:flutter_test/flutter_test.dart';
import 'package:password_manager/services/auth_service.dart';
import 'package:password_manager/services/settings_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final authService = AuthService.instance;

  Future<void> initializeWithEmptyStorage() async {
    SharedPreferences.setMockInitialValues({});
    await SettingsService.instance.init();
    await authService.initialize();
  }

  test('a new process starts with a locked session', () async {
    await initializeWithEmptyStorage();

    expect(authService.isSessionUnlocked, isFalse);
    expect(await authService.needsAuthentication(), isTrue);
  });

  test('setting the master password unlocks the current session', () async {
    await initializeWithEmptyStorage();

    await authService.setMasterPassword('password123', 'password123');

    expect(authService.isSessionUnlocked, isTrue);
    expect(authService.getCurrentMasterPassword(), 'password123');
    expect(await authService.needsAuthentication(), isFalse);
  });

  test('a non-empty one-character master password is allowed', () async {
    await initializeWithEmptyStorage();

    await authService.setMasterPassword('1', '1');

    expect(authService.isSessionUnlocked, isTrue);
    expect(await authService.verifyMasterPassword('1'), isTrue);
    expect(AuthService.validatePasswordStrength('1')['isValid'], isTrue);
  });

  test('changing to a short non-empty master password is allowed', () async {
    await initializeWithEmptyStorage();
    await authService.setMasterPassword('password123', 'password123');

    await authService.changeMasterPassword('password123', 'x', 'x');
    await authService.lockApp();

    expect(await authService.verifyMasterPassword('x'), isTrue);
  });

  test('locking is idempotent and does not rewrite the unlock timestamp',
      () async {
    await initializeWithEmptyStorage();
    await authService.setMasterPassword('password123', 'password123');
    final unlockTime = (await authService.getCurrentSettings()).lastUnlockTime;

    await authService.lockApp();
    await authService.lockApp();

    expect(authService.isSessionUnlocked, isFalse);
    expect(await authService.needsAuthentication(), isTrue);
    expect(await authService.needsAuthentication(), isTrue);
    expect(
      (await authService.getCurrentSettings()).lastUnlockTime,
      unlockTime,
    );
  });

  test('automatic lock timeout has one settings source', () async {
    await initializeWithEmptyStorage();

    await authService.updateAutoLockTimeout(45);

    expect(SettingsService.instance.lockTimeoutMinutes, 45);
    expect(await authService.getAutoLockTimeout(), 45);
  });
}
