import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:password_manager/theme/internal_ui_theme.dart';

void main() {
  test('light internal theme uses the monochrome visual system', () {
    final theme = InternalUiTheme.resolve(ThemeData.light());

    expect(theme.scaffoldBackgroundColor, InternalUiTokens.background);
    expect(theme.colorScheme.primary, InternalUiTokens.ink);
    expect(theme.cardTheme.elevation, 0);
    expect(theme.dialogTheme.elevation, 0);

    final buttonStyle = theme.elevatedButtonTheme.style!;
    expect(buttonStyle.elevation!.resolve({}), 0);
    expect(
      buttonStyle.backgroundColor!.resolve({}),
      InternalUiTokens.ink,
    );
  });

  test('dark internal theme keeps the existing theme direction', () {
    final base = ThemeData.dark();

    expect(InternalUiTheme.resolve(base), same(base));
  });

  testWidgets('internal surface has a border and no shadow in light mode',
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
    expect(decoration.boxShadow, isNull);
    expect(decoration.borderRadius, BorderRadius.circular(8));
  });
}
