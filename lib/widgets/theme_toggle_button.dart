import 'package:flutter/material.dart';

import '../services/theme_service.dart';

/// 主题切换按钮 - 带有动画效果的科技感切换器
class ThemeToggleButton extends StatefulWidget {
  const ThemeToggleButton({super.key});

  @override
  State<ThemeToggleButton> createState() => _ThemeToggleButtonState();
}

class _ThemeToggleButtonState extends State<ThemeToggleButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _animation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );

    // 根据当前主题设置初始动画状态
    if (ThemeService.instance.isDark) {
      _animationController.value = 1.0;
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _toggleTheme() async {
    await ThemeService.instance.toggleTheme();

    if (ThemeService.instance.isDark) {
      _animationController.forward();
    } else {
      _animationController.reverse();
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _toggleTheme,
      child: Container(
        width: 64,
        height: 32,
        padding: const EdgeInsets.all(2),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: LinearGradient(
            colors: ThemeService.instance.isDark
                ? [const Color(0xFF2563EB), const Color(0xFF1E40AF)]
                : [const Color(0xFF2563EB), const Color(0xFF1E40AF)],
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF2563EB).withOpacity(0.4),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            // 背景图标
            Positioned(
              left: 6,
              child: AnimatedOpacity(
                opacity: ThemeService.instance.isDark ? 0.3 : 1.0,
                duration: const Duration(milliseconds: 200),
                child: const Icon(
                  Icons.wb_sunny,
                  color: Colors.white,
                  size: 16,
                ),
              ),
            ),
            Positioned(
              right: 6,
              child: AnimatedOpacity(
                opacity: ThemeService.instance.isDark ? 1.0 : 0.3,
                duration: const Duration(milliseconds: 200),
                child: const Icon(
                  Icons.nightlight_round,
                  color: Colors.white,
                  size: 16,
                ),
              ),
            ),

            // 滑动圆圈
            AnimatedBuilder(
              animation: _animation,
              builder: (context, child) {
                return Positioned(
                  left: _animation.value * 28 + 2,
                  child: Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.2),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Icon(
                      ThemeService.instance.isDark
                          ? Icons.nightlight_round
                          : Icons.wb_sunny,
                      color: const Color(0xFF2563EB),
                      size: 16,
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
