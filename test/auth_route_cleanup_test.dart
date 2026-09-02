import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:password_manager/main.dart';
import 'package:password_manager/pages/home_page.dart';
import 'package:password_manager/pages/login_page.dart';
import 'package:password_manager/services/auth_service.dart';
import 'package:password_manager/services/settings_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('locking dismisses dialogs before showing the login page',
      (tester) async {
    tester.view.physicalSize = const Size(1200, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    SharedPreferences.setMockInitialValues({});
    await SettingsService.instance.init();
    await AuthService.instance.initialize();
    await AuthService.instance.setMasterPassword('test', 'test');

    await tester.pumpWidget(const MaterialApp(home: AuthWrapper()));
    await tester.pump();
    expect(find.byType(HomePage), findsOneWidget);

    showDialog<void>(
      context: tester.element(find.byType(HomePage)),
      builder: (_) => const AlertDialog(title: Text('仍然打开的弹窗')),
    );
    await tester.pumpAndSettle();
    expect(find.text('仍然打开的弹窗'), findsOneWidget);

    await AuthService.instance.lockApp();
    await tester.pumpAndSettle();

    expect(find.byType(LoginPage), findsOneWidget);
    expect(find.text('仍然打开的弹窗'), findsNothing);
  });
}
