import 'package:flutter/material.dart';

/// Light-mode tokens for the approved restrained 16-bit interface.
abstract final class InternalUiTokens {
  static const background = Color(0xFFE8E0CF);
  static const surface = Color(0xFFFFFAEA);
  static const ink = Color(0xFF1D1C19);
  static const muted = Color(0xFF6B675E);
  static const border = Color(0xFF3A3832);
  static const weakBackground = Color(0xFFE1D8C5);
  static const primary = Color(0xFF285EAE);
  static const secondary = Color(0xFFB33A31);
  static const highlight = Color(0xFFD6A51F);
  static const danger = Color(0xFFB33A31);
  static const success = Color(0xFF427A45);

  static const controlRadius = 0.0;
  static const surfaceRadius = 0.0;
  static const dialogRadius = 0.0;
  static const tagRadius = 0.0;
}

/// Applies the pixel visual language without changing the dark theme direction.
class InternalUiTheme extends StatelessWidget {
  const InternalUiTheme({required this.child, super.key});

  final Widget child;

  static RoundedRectangleBorder dialogShape(
    BuildContext context, {
    double darkRadius = 12,
  }) {
    if (Theme.of(context).brightness == Brightness.dark) {
      return RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(darkRadius),
      );
    }
    return const RoundedRectangleBorder(
      borderRadius: BorderRadius.zero,
      side: BorderSide(color: InternalUiTokens.border, width: 2),
    );
  }

  static BorderRadius dialogRadius(
    BuildContext context, {
    double darkRadius = 12,
  }) {
    return Theme.of(context).brightness == Brightness.dark
        ? BorderRadius.circular(darkRadius)
        : BorderRadius.zero;
  }

  static ThemeData resolve(ThemeData base) {
    if (base.brightness == Brightness.dark) return base;

    final colors = base.colorScheme.copyWith(
      primary: InternalUiTokens.primary,
      onPrimary: Colors.white,
      primaryContainer: InternalUiTokens.weakBackground,
      onPrimaryContainer: InternalUiTokens.ink,
      secondary: InternalUiTokens.secondary,
      onSecondary: Colors.white,
      secondaryContainer: InternalUiTokens.weakBackground,
      onSecondaryContainer: InternalUiTokens.ink,
      surface: InternalUiTokens.surface,
      onSurface: InternalUiTokens.ink,
      onSurfaceVariant: InternalUiTokens.muted,
      outline: InternalUiTokens.border,
      error: InternalUiTokens.danger,
    );
    const pixelBorder = BorderSide(color: InternalUiTokens.border, width: 2);
    const controlShape = RoundedRectangleBorder(
      borderRadius: BorderRadius.zero,
      side: pixelBorder,
    );
    final inputBorder = OutlineInputBorder(
      borderRadius: BorderRadius.zero,
      borderSide: pixelBorder,
    );

    final pixelTextTheme = base.textTheme.copyWith(
      headlineSmall: base.textTheme.headlineSmall?.copyWith(
        fontWeight: FontWeight.w800,
        letterSpacing: 0.4,
      ),
      titleLarge: base.textTheme.titleLarge?.copyWith(
        fontWeight: FontWeight.w800,
        letterSpacing: 0.3,
      ),
      titleMedium: base.textTheme.titleMedium?.copyWith(
        fontWeight: FontWeight.w700,
        letterSpacing: 0.2,
      ),
      labelLarge: base.textTheme.labelLarge?.copyWith(
        fontWeight: FontWeight.w700,
        letterSpacing: 0.4,
      ),
    );

    return base.copyWith(
      colorScheme: colors,
      scaffoldBackgroundColor: InternalUiTokens.background,
      textTheme: pixelTextTheme,
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
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.zero,
          side: pixelBorder,
        ),
      ),
      dialogTheme: const DialogThemeData(
        backgroundColor: InternalUiTokens.surface,
        elevation: 0,
        shadowColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.zero,
          side: pixelBorder,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: InternalUiTokens.primary,
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
          side: pixelBorder,
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
          shape: controlShape,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: InternalUiTokens.primary,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          shape: controlShape,
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          foregroundColor: InternalUiTokens.primary,
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
            color: InternalUiTokens.primary,
            width: 3,
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
        floatingLabelStyle: const TextStyle(color: InternalUiTokens.primary),
        hintStyle: const TextStyle(color: InternalUiTokens.muted),
      ),
      dividerColor: InternalUiTokens.border,
      checkboxTheme: CheckboxThemeData(
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
        side: pixelBorder,
        fillColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? InternalUiTokens.highlight
              : InternalUiTokens.surface,
        ),
        checkColor: const WidgetStatePropertyAll(InternalUiTokens.ink),
      ),
      sliderTheme: base.sliderTheme.copyWith(
        activeTrackColor: InternalUiTokens.ink,
        inactiveTrackColor: InternalUiTokens.weakBackground,
        thumbColor: InternalUiTokens.primary,
        overlayColor: Colors.transparent,
        trackHeight: 6,
        thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 7),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Theme(data: resolve(Theme.of(context)), child: child);
  }
}

/// Crisp framed panel with a hard, blur-free pixel offset in light mode.
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
        borderRadius:
            isDark ? BorderRadius.circular(radius) : BorderRadius.zero,
        border: Border.all(
          color: isDark
              ? theme.colorScheme.outline.withValues(alpha: 0.35)
              : InternalUiTokens.border,
          width: isDark ? 1 : 2,
        ),
        boxShadow: isDark
            ? null
            : const [
                BoxShadow(
                  color: InternalUiTokens.border,
                  blurRadius: 0,
                  offset: Offset(3, 3),
                ),
              ],
      ),
      child: Padding(padding: padding, child: child),
    );
  }
}
