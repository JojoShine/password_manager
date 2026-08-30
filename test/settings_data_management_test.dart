import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:password_manager/pages/settings_page.dart';
import 'package:password_manager/theme/internal_ui_theme.dart';

void main() {
  Widget app() => MaterialApp(
        theme: ThemeData.light(),
        home: const SettingsPage(),
      );

  testWidgets('settings shows the data management controls', (tester) async {
    tester.view.physicalSize = const Size(1000, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(app());
    await tester.pump();

    expect(find.text('数据与应用'), findsOneWidget);
    expect(find.text('密码数据存放位置'), findsOneWidget);
    expect(find.text('一键重置密码数据'), findsOneWidget);
    expect(find.text('应用卸载流程'), findsOneWidget);
    expect(find.byType(InternalSurface), findsNWidgets(5));
  });

  testWidgets('uninstall guidance uses the shared pixel dialog',
      (tester) async {
    tester.view.physicalSize = const Size(1000, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(app());
    await tester.pump();
    await tester.ensureVisible(find.text('应用卸载流程'));
    await tester.tap(find.text('应用卸载流程'));
    await tester.pumpAndSettle();

    expect(find.byType(PixelDialogHeader), findsOneWidget);
    expect(find.text('卸载不会自动删除本地数据。'), findsOneWidget);
    expect(find.textContaining('清空密码数据'), findsOneWidget);
  });
}
