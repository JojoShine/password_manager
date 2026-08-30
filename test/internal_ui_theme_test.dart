import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:password_manager/theme/internal_ui_theme.dart';

void main() {
  test('light internal theme uses the pixel visual system', () {
    final theme = InternalUiTheme.resolve(ThemeData.light());

    expect(theme.scaffoldBackgroundColor, InternalUiTokens.background);
    expect(theme.colorScheme.primary, InternalUiTokens.primary);
    expect(theme.cardTheme.elevation, 0);
    expect(theme.dialogTheme.elevation, 0);

    final buttonStyle = theme.elevatedButtonTheme.style!;
    expect(buttonStyle.elevation!.resolve({}), 0);
    expect(
      buttonStyle.backgroundColor!.resolve({}),
      InternalUiTokens.primary,
    );
    final shape = buttonStyle.shape!.resolve({}) as RoundedRectangleBorder;
    expect(shape.borderRadius, BorderRadius.zero);
    expect(shape.side.width, 2);
  });

  test('dark internal theme uses the same square pixel language', () {
    final base = ThemeData.dark();
    final theme = InternalUiTheme.resolve(base);

    expect(theme, isNot(same(base)));
    expect(theme.scaffoldBackgroundColor, const Color(0xFF151410));
    expect(theme.cardTheme.elevation, 0);
    final shape = theme.cardTheme.shape! as RoundedRectangleBorder;
    expect(shape.borderRadius, BorderRadius.zero);
    expect(shape.side.width, 2);
    expect(shape.side.color, InternalUiTokens.darkBorder);
  });

  test('operation messages use a floating square pixel surface', () {
    final theme = InternalUiTheme.resolve(ThemeData.light());
    final snackBarTheme = theme.snackBarTheme;

    expect(snackBarTheme.behavior, SnackBarBehavior.floating);
    expect(snackBarTheme.elevation, 0);
    expect(snackBarTheme.backgroundColor, InternalUiTokens.ink);
    expect(
      snackBarTheme.insetPadding,
      const EdgeInsets.fromLTRB(20, 0, 20, 16),
    );

    final shape = snackBarTheme.shape! as RoundedRectangleBorder;
    expect(shape.borderRadius, BorderRadius.zero);
    expect(shape.side.width, 2);
    expect(shape.side.color, InternalUiTokens.highlight);
  });

  testWidgets('internal surface has crisp pixel edges in light mode',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData.light(),
        home: const InternalUiTheme(
          child: Scaffold(
            body: InternalSurface(child: SizedBox()),
          ),
        ),
      ),
    );

    final decoratedBox = tester.widget<DecoratedBox>(
      find.descendant(
        of: find.byType(InternalSurface),
        matching: find.byType(DecoratedBox),
      ),
    );
    final decoration = decoratedBox.decoration as BoxDecoration;

    expect(decoration.border, isNotNull);
    expect(decoration.borderRadius, BorderRadius.zero);
    expect(decoration.boxShadow, isNotEmpty);
    expect(decoration.boxShadow!.every((shadow) => shadow.blurRadius == 0),
        isTrue);
  });
}
