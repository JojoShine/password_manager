import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:password_manager/pages/browser_extension_page.dart';
import 'package:password_manager/pages/settings_page.dart';
import 'package:password_manager/theme/internal_ui_theme.dart';
import 'package:password_manager/widgets/decrypt_password_dialog.dart';
import 'package:password_manager/widgets/export_options_dialog.dart';
import 'package:password_manager/widgets/password_add_dialog.dart';
import 'package:password_manager/widgets/password_generator_dialog.dart';

void main() {
  Widget app(Widget child) => MaterialApp(
        theme: ThemeData.light(),
        home: child,
      );

  testWidgets('settings page uses border-led section surfaces', (tester) async {
    await tester.pumpWidget(app(const SettingsPage()));

    expect(find.byType(InternalSurface), findsNWidgets(4));
    expect(find.byType(Card), findsNothing);
  });

  testWidgets('browser extension page uses neutral section surfaces',
      (tester) async {
    await tester.pumpWidget(app(const BrowserExtensionPage()));

    expect(find.byType(InternalSurface), findsNWidgets(3));
  });

  testWidgets('internal dialogs use square pixel frames', (tester) async {
    tester.view.physicalSize = const Size(1400, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    for (final dialog in <Widget>[
      const PasswordAddDialog(),
      const PasswordGeneratorDialog(),
      const DecryptPasswordDialog(),
      const ExportOptionsDialog(),
    ]) {
      await tester.pumpWidget(app(dialog));
      await tester.pump();

      final widget = tester.widget<Dialog>(find.byType(Dialog).first);
      final shape = widget.shape! as RoundedRectangleBorder;
      expect(
        shape.borderRadius,
        BorderRadius.zero,
      );
      expect(shape.side.width, 2);
    }
  });
}
