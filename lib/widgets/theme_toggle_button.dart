import 'package:flutter/material.dart';

import '../services/theme_service.dart';
import '../theme/internal_ui_theme.dart';

/// 主题切换按钮 - 带有动画效果的科技感切换器
class ThemeToggleButton extends StatefulWidget {
  const ThemeToggleButton({super.key});

  @override
  State<ThemeToggleButton> createState() => _ThemeToggleButtonState();
}

class _ThemeToggleButtonState extends State<ThemeToggleButton> {
  void _toggleTheme() async {
    await ThemeService.instance.toggleTheme();
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final isDark = ThemeService.instance.isDark;
    final borderColor =
        isDark ? InternalUiTokens.darkBorder : InternalUiTokens.border;
    return Semantics(
      button: true,
      label: isDark ? '切换到浅色模式' : '切换到深色模式',
      child: GestureDetector(
        onTap: _toggleTheme,
        child: Container(
          width: 70,
          height: 34,
          padding: const EdgeInsets.all(3),
          decoration: BoxDecoration(
            color: isDark
                ? InternalUiTokens.darkRaised
                : InternalUiTokens.weakBackground,
            borderRadius: BorderRadius.zero,
            border: Border.all(color: borderColor, width: 2),
          ),
          child: Stack(
            alignment: Alignment.center,
            children: [
              AnimatedAlign(
                duration: const Duration(milliseconds: 180),
                curve: Curves.linear,
                alignment:
                    isDark ? Alignment.centerRight : Alignment.centerLeft,
                child: Container(
                  width: 29,
                  height: 26,
                  decoration: BoxDecoration(
                    color: isDark
                        ? InternalUiTokens.darkPrimary
                        : InternalUiTokens.highlight,
                    border: Border.all(color: borderColor, width: 1),
                  ),
                ),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  Icon(
                    Icons.light_mode,
                    size: 16,
                    color: isDark
                        ? InternalUiTokens.darkMuted
                        : InternalUiTokens.ink,
                  ),
                  Icon(
                    Icons.dark_mode,
                    size: 16,
                    color: isDark
                        ? InternalUiTokens.darkBackground
                        : InternalUiTokens.muted,
                  ),
                ],
              ),
              Positioned(
                bottom: 1,
                left: isDark ? null : 10,
                right: isDark ? 10 : null,
                child: Container(
                  width: 7,
                  height: 2,
                  color: isDark
                      ? InternalUiTokens.darkBackground
                      : InternalUiTokens.ink,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
