import 'package:flutter/material.dart';

enum PixelEmptyStateType { vault, search }

class PixelEmptyStateIcon extends StatelessWidget {
  const PixelEmptyStateIcon({
    required this.type,
    this.size = 72,
    this.color,
    this.accentColor,
    super.key,
  });

  final PixelEmptyStateType type;
  final double size;
  final Color? color;
  final Color? accentColor;

  @override
  Widget build(BuildContext context) {
    final label = switch (type) {
      PixelEmptyStateType.vault => '空密码库像素图标',
      PixelEmptyStateType.search => '无搜索结果像素图标',
    };

    return Semantics(
      label: label,
      image: true,
      child: CustomPaint(
        size: Size.square(size),
        painter: _PixelEmptyStatePainter(
          type: type,
          color: color ?? Theme.of(context).colorScheme.onSurfaceVariant,
          accentColor: accentColor ?? Theme.of(context).colorScheme.primary,
        ),
      ),
    );
  }
}

class _PixelEmptyStatePainter extends CustomPainter {
  const _PixelEmptyStatePainter({
    required this.type,
    required this.color,
    required this.accentColor,
  });

  final PixelEmptyStateType type;
  final Color color;
  final Color accentColor;

  @override
  void paint(Canvas canvas, Size size) {
    final unit = size.shortestSide / 16;
    final ink = Paint()
      ..color = color
      ..isAntiAlias = false;
    final accent = Paint()
      ..color = accentColor
      ..isAntiAlias = false;

    void px(Paint paint, int x, int y, [int width = 1, int height = 1]) {
      canvas.drawRect(
        Rect.fromLTWH(x * unit, y * unit, width * unit, height * unit),
        paint,
      );
    }

    switch (type) {
      case PixelEmptyStateType.vault:
        px(ink, 2, 6, 12, 2);
        px(ink, 1, 8, 2, 6);
        px(ink, 13, 8, 2, 6);
        px(ink, 2, 13, 12, 2);
        px(ink, 4, 4, 8, 2);
        px(ink, 6, 2, 4, 2);
        px(accent, 6, 8, 4, 4);
        px(ink, 7, 9, 2, 2);
        px(ink, 8, 11, 1, 2);
        break;
      case PixelEmptyStateType.search:
        px(ink, 4, 2, 6, 2);
        px(ink, 2, 4, 2, 6);
        px(ink, 10, 4, 2, 6);
        px(ink, 4, 10, 6, 2);
        px(ink, 10, 10, 2, 2);
        px(ink, 12, 12, 3, 3);
        px(accent, 5, 5, 2, 2);
        px(accent, 8, 8, 2, 2);
        px(accent, 8, 5, 2, 2);
        px(accent, 5, 8, 2, 2);
        break;
    }
  }

  @override
  bool shouldRepaint(_PixelEmptyStatePainter oldDelegate) =>
      oldDelegate.type != type ||
      oldDelegate.color != color ||
      oldDelegate.accentColor != accentColor;
}
