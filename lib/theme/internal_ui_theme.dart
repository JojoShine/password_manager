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

  static const darkBackground = Color(0xFF151410);
  static const darkSurface = Color(0xFF211F1B);
  static const darkRaised = Color(0xFF2B2822);
  static const darkInk = Color(0xFFF2E9D5);
  static const darkMuted = Color(0xFFAEA797);
  static const darkBorder = Color(0xFF777063);
  static const darkPrimary = Color(0xFF76A2D8);
  static const darkSecondary = Color(0xFFC66559);

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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return RoundedRectangleBorder(
      borderRadius: BorderRadius.zero,
      side: BorderSide(
        color: isDark ? InternalUiTokens.darkBorder : InternalUiTokens.border,
        width: 2,
      ),
    );
  }

  static BorderRadius dialogRadius(
    BuildContext context, {
    double darkRadius = 12,
  }) {
    return BorderRadius.zero;
  }

  static ThemeData resolve(ThemeData base) {
    final isDark = base.brightness == Brightness.dark;
    final colors = base.colorScheme.copyWith(
      primary: isDark ? InternalUiTokens.darkPrimary : InternalUiTokens.primary,
      onPrimary: isDark ? InternalUiTokens.darkBackground : Colors.white,
      primaryContainer: isDark
          ? InternalUiTokens.darkRaised
          : InternalUiTokens.weakBackground,
      onPrimaryContainer:
          isDark ? InternalUiTokens.darkInk : InternalUiTokens.ink,
      secondary:
          isDark ? InternalUiTokens.darkSecondary : InternalUiTokens.secondary,
      onSecondary: Colors.white,
      secondaryContainer: isDark
          ? InternalUiTokens.darkRaised
          : InternalUiTokens.weakBackground,
      onSecondaryContainer:
          isDark ? InternalUiTokens.darkInk : InternalUiTokens.ink,
      surface: isDark ? InternalUiTokens.darkSurface : InternalUiTokens.surface,
      surfaceContainerHighest: isDark
          ? InternalUiTokens.darkRaised
          : InternalUiTokens.weakBackground,
      onSurface: isDark ? InternalUiTokens.darkInk : InternalUiTokens.ink,
      onSurfaceVariant:
          isDark ? InternalUiTokens.darkMuted : InternalUiTokens.muted,
      outline: isDark ? InternalUiTokens.darkBorder : InternalUiTokens.border,
      error: InternalUiTokens.danger,
    );
    final pixelBorder = BorderSide(
      color: isDark ? InternalUiTokens.darkBorder : InternalUiTokens.border,
      width: 2,
    );
    final controlShape = RoundedRectangleBorder(
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
      scaffoldBackgroundColor: isDark
          ? InternalUiTokens.darkBackground
          : InternalUiTokens.background,
      textTheme: pixelTextTheme,
      appBarTheme: base.appBarTheme.copyWith(
        backgroundColor: isDark
            ? InternalUiTokens.darkBackground
            : InternalUiTokens.background,
        foregroundColor:
            isDark ? InternalUiTokens.darkInk : InternalUiTokens.ink,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
      ),
      cardTheme: CardThemeData(
        color: isDark ? InternalUiTokens.darkSurface : InternalUiTokens.surface,
        elevation: 0,
        shadowColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.zero,
          side: pixelBorder,
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor:
            isDark ? InternalUiTokens.darkSurface : InternalUiTokens.surface,
        elevation: 0,
        shadowColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.zero,
          side: pixelBorder,
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor:
            isDark ? InternalUiTokens.darkRaised : InternalUiTokens.ink,
        contentTextStyle: TextStyle(
          color: isDark ? InternalUiTokens.darkInk : InternalUiTokens.surface,
          fontSize: 14,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.25,
        ),
        elevation: 0,
        behavior: SnackBarBehavior.floating,
        insetPadding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
        actionTextColor: InternalUiTokens.highlight,
        disabledActionTextColor: InternalUiTokens.muted,
        closeIconColor:
            isDark ? InternalUiTokens.darkInk : InternalUiTokens.surface,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.zero,
          side: BorderSide(color: InternalUiTokens.highlight, width: 2),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor:
              isDark ? InternalUiTokens.darkPrimary : InternalUiTokens.primary,
          foregroundColor:
              isDark ? InternalUiTokens.darkBackground : Colors.white,
          disabledBackgroundColor: isDark
              ? InternalUiTokens.darkRaised
              : InternalUiTokens.weakBackground,
          disabledForegroundColor:
              isDark ? InternalUiTokens.darkMuted : InternalUiTokens.muted,
          elevation: 0,
          shadowColor: Colors.transparent,
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
          shape: controlShape,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor:
              isDark ? InternalUiTokens.darkInk : InternalUiTokens.ink,
          side: pixelBorder,
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
          shape: controlShape,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor:
              isDark ? InternalUiTokens.darkPrimary : InternalUiTokens.primary,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          shape: controlShape,
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          foregroundColor:
              isDark ? InternalUiTokens.darkPrimary : InternalUiTokens.primary,
          shape: controlShape,
        ),
      ),
      inputDecorationTheme: base.inputDecorationTheme.copyWith(
        filled: true,
        fillColor:
            isDark ? InternalUiTokens.darkRaised : InternalUiTokens.surface,
        border: inputBorder,
        enabledBorder: inputBorder,
        focusedBorder: inputBorder.copyWith(
          borderSide: BorderSide(
            color: isDark
                ? InternalUiTokens.darkPrimary
                : InternalUiTokens.primary,
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
        labelStyle: TextStyle(
          color: isDark ? InternalUiTokens.darkMuted : InternalUiTokens.muted,
        ),
        floatingLabelStyle: TextStyle(
          color:
              isDark ? InternalUiTokens.darkPrimary : InternalUiTokens.primary,
        ),
        hintStyle: TextStyle(
          color: isDark ? InternalUiTokens.darkMuted : InternalUiTokens.muted,
        ),
      ),
      dividerColor:
          isDark ? InternalUiTokens.darkBorder : InternalUiTokens.border,
      checkboxTheme: CheckboxThemeData(
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
        side: pixelBorder,
        fillColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? InternalUiTokens.highlight
              : isDark
                  ? InternalUiTokens.darkSurface
                  : InternalUiTokens.surface,
        ),
        checkColor: WidgetStatePropertyAll(
          isDark ? InternalUiTokens.darkBackground : InternalUiTokens.ink,
        ),
      ),
      sliderTheme: base.sliderTheme.copyWith(
        activeTrackColor:
            isDark ? InternalUiTokens.darkInk : InternalUiTokens.ink,
        inactiveTrackColor: isDark
            ? InternalUiTokens.darkRaised
            : InternalUiTokens.weakBackground,
        thumbColor:
            isDark ? InternalUiTokens.darkPrimary : InternalUiTokens.primary,
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
        borderRadius: BorderRadius.zero,
        border: Border.all(
          color: isDark ? InternalUiTokens.darkBorder : InternalUiTokens.border,
          width: 2,
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

/// Shared title strip for the light-mode pixel dialogs.
class PixelDialogHeader extends StatelessWidget {
  const PixelDialogHeader({
    required this.title,
    required this.icon,
    this.subtitle,
    this.onClose,
    this.actions = const [],
    this.color = InternalUiTokens.secondary,
    super.key,
  });

  final String title;
  final String? subtitle;
  final IconData icon;
  final VoidCallback? onClose;
  final List<Widget> actions;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final foreground = isDark ? theme.colorScheme.onSurface : Colors.white;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        color: isDark ? theme.colorScheme.surfaceContainerHighest : color,
        borderRadius: BorderRadius.zero,
        border: Border(
          bottom: BorderSide(
            color: isDark ? theme.colorScheme.outline : InternalUiTokens.border,
            width: 2,
          ),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color:
                  isDark ? theme.colorScheme.primary : InternalUiTokens.surface,
              border: Border.all(
                color: isDark
                    ? InternalUiTokens.darkBorder
                    : InternalUiTokens.border,
                width: 2,
              ),
            ),
            child: Icon(
              icon,
              size: 22,
              color: isDark ? Colors.white : InternalUiTokens.ink,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: foreground,
                    fontSize: 19,
                    fontWeight: FontWeight.w800,
                    letterSpacing: .4,
                  ),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    subtitle!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: foreground.withValues(alpha: .78)),
                  ),
                ],
              ],
            ),
          ),
          ...actions,
          if (onClose != null)
            IconButton(
              onPressed: onClose,
              icon: const Icon(Icons.close),
              color: foreground,
              tooltip: '关闭',
            ),
        ],
      ),
    );
  }
}

/// Crisp content block used inside dialogs.
class PixelPanel extends StatelessWidget {
  const PixelPanel(
      {required this.child,
      this.padding = const EdgeInsets.all(14),
      super.key});

  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: isDark
            ? theme.colorScheme.surfaceContainerHighest
            : InternalUiTokens.surface,
        borderRadius: BorderRadius.zero,
        border: Border.all(
          color: isDark ? theme.colorScheme.outline : InternalUiTokens.border,
          width: 2,
        ),
      ),
      child: child,
    );
  }
}
