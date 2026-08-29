import 'package:flutter/material.dart';

/// Light-mode tokens for secondary pages and dialogs.
///
/// The main password list intentionally keeps its existing visual language.
abstract final class InternalUiTokens {
  static const background = Color(0xFFF4F4F1);
  static const surface = Color(0xFFFBFBFA);
  static const ink = Color(0xFF181817);
  static const muted = Color(0xFF6F6F6B);
  static const border = Color(0xFFD8D8D3);
  static const weakBackground = Color(0xFFEFEFEC);
  static const danger = Color(0xFFB42318);
  static const success = Color(0xFF257A4A);

  static const controlRadius = 6.0;
  static const surfaceRadius = 8.0;
  static const dialogRadius = 12.0;
  static const tagRadius = 4.0;
}

/// Applies the restrained monochrome style only to internal pages.
class InternalUiTheme extends StatelessWidget {
  const InternalUiTheme({required this.child, super.key});

  final Widget child;

  static ThemeData resolve(ThemeData base) {
    if (base.brightness == Brightness.dark) return base;

    final colors = base.colorScheme.copyWith(
      primary: InternalUiTokens.ink,
      onPrimary: Colors.white,
      primaryContainer: InternalUiTokens.weakBackground,
      onPrimaryContainer: InternalUiTokens.ink,
      secondary: InternalUiTokens.muted,
      onSecondary: Colors.white,
      secondaryContainer: InternalUiTokens.weakBackground,
      onSecondaryContainer: InternalUiTokens.ink,
      surface: InternalUiTokens.surface,
      onSurface: InternalUiTokens.ink,
      onSurfaceVariant: InternalUiTokens.muted,
      outline: InternalUiTokens.border,
      error: InternalUiTokens.danger,
    );
    final controlShape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(InternalUiTokens.controlRadius),
    );
    final inputBorder = OutlineInputBorder(
      borderRadius: BorderRadius.circular(InternalUiTokens.controlRadius),
      borderSide: const BorderSide(color: InternalUiTokens.border),
    );

    return base.copyWith(
      colorScheme: colors,
      scaffoldBackgroundColor: InternalUiTokens.background,
      appBarTheme: base.appBarTheme.copyWith(
        backgroundColor: InternalUiTokens.background,
        foregroundColor: InternalUiTokens.ink,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
      ),
      cardTheme: const CardThemeData(
        color: InternalUiTokens.surface,
        elevation: 0,
        shadowColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        margin: EdgeInsets.zero,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: InternalUiTokens.surface,
        elevation: 0,
        shadowColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(InternalUiTokens.dialogRadius),
          side: const BorderSide(color: InternalUiTokens.border),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: InternalUiTokens.ink,
          foregroundColor: Colors.white,
          disabledBackgroundColor: InternalUiTokens.weakBackground,
          disabledForegroundColor: InternalUiTokens.muted,
          elevation: 0,
          shadowColor: Colors.transparent,
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
          shape: controlShape,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: InternalUiTokens.ink,
          side: const BorderSide(color: InternalUiTokens.border),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
          shape: controlShape,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: InternalUiTokens.ink,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          shape: controlShape,
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          foregroundColor: InternalUiTokens.ink,
          shape: controlShape,
        ),
      ),
      inputDecorationTheme: base.inputDecorationTheme.copyWith(
        filled: true,
        fillColor: InternalUiTokens.surface,
        border: inputBorder,
        enabledBorder: inputBorder,
        focusedBorder: inputBorder.copyWith(
          borderSide: const BorderSide(
            color: InternalUiTokens.ink,
            width: 1.5,
          ),
        ),
        errorBorder: inputBorder.copyWith(
          borderSide: const BorderSide(color: InternalUiTokens.danger),
        ),
        focusedErrorBorder: inputBorder.copyWith(
          borderSide: const BorderSide(
            color: InternalUiTokens.danger,
            width: 1.5,
          ),
        ),
        labelStyle: const TextStyle(color: InternalUiTokens.muted),
        floatingLabelStyle: const TextStyle(color: InternalUiTokens.ink),
        hintStyle: const TextStyle(color: InternalUiTokens.muted),
      ),
      dividerColor: InternalUiTokens.border,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Theme(data: resolve(Theme.of(context)), child: child);
  }
}

/// Border-led surface for light mode; dark mode keeps the existing treatment.
class InternalSurface extends StatelessWidget {
  const InternalSurface({
    required this.child,
    this.padding = const EdgeInsets.all(20),
    this.radius = InternalUiTokens.surfaceRadius,
    super.key,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(
          color: isDark
              ? theme.colorScheme.outline.withValues(alpha: 0.35)
              : InternalUiTokens.border,
        ),
      ),
      child: Padding(padding: padding, child: child),
    );
  }
}
