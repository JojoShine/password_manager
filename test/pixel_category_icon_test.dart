import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:password_manager/widgets/pixel_category_icon.dart';
import 'package:password_manager/widgets/pixel_empty_state_icon.dart';

void main() {
  testWidgets('category icon is painted as pixels without an svg asset',
      (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: PixelCategoryIcon(category: '邮箱'),
      ),
    );

    expect(find.byType(CustomPaint), findsWidgets);
    expect(find.bySemanticsLabel('邮箱分类图标'), findsOneWidget);
    expect(find.byType(Image), findsNothing);
  });

  testWidgets('empty states use painted pixel icons', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Column(
          children: [
            PixelEmptyStateIcon(type: PixelEmptyStateType.vault),
            PixelEmptyStateIcon(type: PixelEmptyStateType.search),
          ],
        ),
      ),
    );

    expect(find.bySemanticsLabel('空密码库像素图标'), findsOneWidget);
    expect(find.bySemanticsLabel('无搜索结果像素图标'), findsOneWidget);
    expect(find.byType(Image), findsNothing);
    expect(find.byType(Icon), findsNothing);
  });
}
