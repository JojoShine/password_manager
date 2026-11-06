import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:password_manager/pages/home_page.dart';
import 'package:password_manager/pages/login_page.dart';
import 'package:password_manager/theme/internal_ui_theme.dart';
import 'package:password_manager/widgets/footer.dart';
import 'package:password_manager/widgets/theme_toggle_button.dart';

void main() {
  testWidgets('login page participates in the internal pixel theme',
      (tester) async {
    await tester.pumpWidget(MaterialApp(home: const LoginPage()));
    expect(find.byType(InternalUiTheme), findsOneWidget);
  });

  testWidgets('login page uses the bundled pixel background by default',
      (tester) async {
    await tester.pumpWidget(MaterialApp(home: const LoginPage()));

    final decorations = tester
        .widgetList<Container>(find.byType(Container))
        .map((container) => container.decoration)
        .whereType<BoxDecoration>();
    final usesPixelBackground = decorations.any((decoration) {
      final provider = decoration.image?.image;
      return provider is AssetImage && provider.assetName == 'assets/bg.png';
    });

    expect(usesPixelBackground, isTrue);
  });

  testWidgets('login page does not show the TBTparent attribution link',
      (tester) async {
    await tester.pumpWidget(MaterialApp(home: const LoginPage()));

    expect(find.text('Powered by TBTparent'), findsNothing);
  });

  testWidgets('internal footer uses the TBTparent attribution', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(bottomNavigationBar: Footer())),
    );

    expect(find.text('Powered by TBTparent'), findsOneWidget);
    expect(find.text('技术支持：tbtparent(甜宝塔家长)'), findsNothing);
    expect(tester.getSize(find.byType(Footer)).height, lessThanOrEqualTo(44));
  });

  testWidgets('internal footer places a GitHub icon after the attribution',
      (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(bottomNavigationBar: Footer())),
    );

    final attribution = find.text('Powered by TBTparent');
    final githubIcon = find.byKey(const ValueKey('github-project-link'));
    final githubImage = find.byKey(const ValueKey('github-project-icon'));
    expect(githubIcon, findsOneWidget);
    expect(githubImage, findsOneWidget);
    expect(
      (tester.widget<Image>(githubImage).image as AssetImage).assetName,
      'assets/github-mark.png',
    );
    expect(
      tester.getCenter(githubIcon).dx,
      greaterThan(tester.getCenter(attribution).dx),
    );
    expect(find.byType(Tooltip), findsNothing);
  });

  test('GitHub icon asset has a transparent background', () async {
    final bytes = await File('assets/github-mark.png').readAsBytes();
    final codec = await ui.instantiateImageCodec(bytes);
    final frame = await codec.getNextFrame();
    final pixels =
        await frame.image.toByteData(format: ui.ImageByteFormat.rawRgba);

    expect(pixels!.getUint8(3), 0);
    frame.image.dispose();
    codec.dispose();
  });

  testWidgets('internal footer has no top divider', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(bottomNavigationBar: Footer())),
    );

    final footerContainer = tester.widget<Container>(
      find
          .descendant(
            of: find.byType(Footer),
            matching: find.byType(Container),
          )
          .first,
    );
    final decoration = footerContainer.decoration as BoxDecoration?;

    expect(decoration?.border, isNull);
  });

  testWidgets('privacy policy content does not use emoji', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(bottomNavigationBar: Footer())),
    );

    await tester.tap(find.text('隐私协议'));
    await tester.pumpAndSettle();

    final policy = tester
        .widgetList<SelectableText>(find.byType(SelectableText))
        .map((widget) => widget.data ?? '')
        .firstWhere((text) => text.startsWith('Lockora - 隐私政策'));
    expect(policy, isNot(contains('✅')));
    expect(policy, isNot(contains('❌')));
  });

  testWidgets('privacy policy content stays concise', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(bottomNavigationBar: Footer())),
    );

    await tester.tap(find.text('隐私协议'));
    await tester.pumpAndSettle();

    final policy = tester
        .widgetList<SelectableText>(find.byType(SelectableText))
        .map((widget) => widget.data ?? '')
        .firstWhere((text) => text.startsWith('Lockora - 隐私政策'));
    expect(policy.length, lessThan(1200));
  });

  testWidgets('about dialog uses the shared header and aligned table',
      (tester) async {
    PackageInfo.setMockInitialValues(
      appName: '密码管理器',
      packageName: 'me.tbtparent.lockora',
      version: '3.1.2',
      buildNumber: '1',
      buildSignature: '',
    );
    tester.view.physicalSize = const Size(1200, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const MaterialApp(home: HomePage()));
    await tester.pump();
    await tester.tap(find.text('v3.1.2'));
    await tester.pumpAndSettle();

    expect(find.byType(PixelDialogHeader), findsOneWidget);
    expect(find.byType(Table), findsOneWidget);
  });

  test('package version is consistently 3.1.2', () {
    final pubspec = File('pubspec.yaml').readAsStringSync();
    expect(pubspec, contains('version: 3.1.2+'));
  });

  testWidgets('theme toggle uses a square solid pixel frame', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: ThemeToggleButton())),
    );

    final boxes = tester
        .widgetList<Container>(
          find.descendant(
            of: find.byType(ThemeToggleButton),
            matching: find.byType(Container),
          ),
        )
        .where((container) => container.decoration is BoxDecoration);
    final outer = boxes.first.decoration! as BoxDecoration;

    expect(outer.borderRadius, BorderRadius.zero);
    expect(outer.gradient, isNull);
    expect(outer.border, isNotNull);
  });
}
