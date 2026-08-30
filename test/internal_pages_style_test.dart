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

  Widget darkApp(Widget child) => MaterialApp(
        theme: ThemeData.dark(),
        home: child,
      );

  testWidgets('settings page uses border-led section surfaces', (tester) async {
    await tester.pumpWidget(app(const SettingsPage()));

    expect(find.byType(InternalSurface), findsNWidgets(5));
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

  testWidgets('generator selected category has a hard pixel offset',
      (tester) async {
    tester.view.physicalSize = const Size(1400, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(app(const PasswordGeneratorDialog()));
    await tester.pump();

    final selectedCategoryContainers = tester
        .widgetList<Container>(
          find.ancestor(
            of: find.text('常用'),
            matching: find.byType(Container),
          ),
        )
        .map((container) => container.decoration)
        .whereType<BoxDecoration>();

    expect(
      selectedCategoryContainers.any((decoration) =>
          decoration.boxShadow?.any((shadow) => shadow.blurRadius == 0) ??
          false),
      isTrue,
    );
  });

  testWidgets('generated password uses the bundled password font',
      (tester) async {
    tester.view.physicalSize = const Size(1400, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(app(const PasswordGeneratorDialog()));
    await tester.pump();

    final generatedPassword = tester
        .widgetList<SelectableText>(find.byType(SelectableText))
        .singleWhere((widget) => widget.data?.length == 12);

    expect(generatedPassword.style?.fontFamily, 'JetBrainsMono');
    expect(generatedPassword.style?.letterSpacing, 1.1);
  });

  testWidgets('generated password panel uses two clean corner pixels',
      (tester) async {
    tester.view.physicalSize = const Size(1400, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(app(const PasswordGeneratorDialog()));
    await tester.pump();

    expect(
      find.byKey(const ValueKey('generated-password-pixel-accent')),
      findsNWidgets(2),
    );
    expect(
      find.byKey(const ValueKey('generated-password-pixel-panel')),
      findsNothing,
    );
  });

  testWidgets('dark dialog headers use charcoal instead of red',
      (tester) async {
    tester.view.physicalSize = const Size(1400, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    for (final entry in <(Widget, String)>[
      (const PasswordAddDialog(), '添加新密码'),
      (const PasswordGeneratorDialog(), '密码生成器'),
    ]) {
      await tester.pumpWidget(darkApp(entry.$1));
      await tester.pump();

      final headerDecorations = tester
          .widgetList<Container>(
            find.ancestor(
              of: find.text(entry.$2),
              matching: find.byType(Container),
            ),
          )
          .map((container) => container.decoration)
          .whereType<BoxDecoration>();

      expect(
        headerDecorations.any(
          (decoration) => decoration.color == InternalUiTokens.darkRaised,
        ),
        isTrue,
      );
      expect(
        headerDecorations.any(
          (decoration) => decoration.color == InternalUiTokens.darkSecondary,
        ),
        isFalse,
      );
    }
  });
}
