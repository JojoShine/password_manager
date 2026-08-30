import 'package:flutter/material.dart';

/// Small category glyphs drawn on a crisp 12 x 12 pixel grid.
class PixelCategoryIcon extends StatelessWidget {
  const PixelCategoryIcon({
    required this.category,
    this.size = 20,
    this.color,
    super.key,
  });

  final String category;
  final double size;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: '$category分类图标',
      image: true,
      child: CustomPaint(
        size: Size.square(size),
        painter: _PixelCategoryPainter(
          category,
          color ?? IconTheme.of(context).color ?? Colors.black,
        ),
      ),
    );
  }
}

class _PixelCategoryPainter extends CustomPainter {
  const _PixelCategoryPainter(this.category, this.color);

  final String category;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final unit = size.shortestSide / 12;
    final paint = Paint()
      ..color = color
      ..isAntiAlias = false;

    void px(int x, int y, [int width = 1, int height = 1]) {
      canvas.drawRect(
        Rect.fromLTWH(x * unit, y * unit, width * unit, height * unit),
        paint,
      );
    }

    switch (category) {
      case '社交':
        px(2, 2, 3, 3);
        px(7, 3, 3, 3);
        px(1, 6, 5, 4);
        px(6, 7, 5, 3);
        break;
      case '邮箱':
        px(1, 2, 10, 2);
        px(1, 4, 2, 6);
        px(9, 4, 2, 6);
        px(3, 4, 2, 2);
        px(7, 4, 2, 2);
        px(5, 6, 2, 2);
        px(3, 8, 6, 2);
        break;
      case '购物':
        px(1, 1, 2, 2);
        px(2, 3, 2, 5);
        px(4, 4, 7, 2);
        px(4, 6, 6, 2);
        px(4, 9, 2, 2);
        px(8, 9, 2, 2);
        break;
      case '银行':
        px(5, 1, 2, 1);
        px(3, 2, 6, 1);
        px(1, 3, 10, 2);
        px(2, 5, 2, 4);
        px(5, 5, 2, 4);
        px(8, 5, 2, 4);
        px(1, 9, 10, 2);
        break;
      case '工作':
        px(4, 1, 4, 2);
        px(1, 3, 10, 7);
        px(1, 5, 10, 1);
        px(5, 5, 2, 2);
        break;
      case '娱乐':
        px(1, 2, 10, 2);
        px(2, 1, 2, 1);
        px(6, 1, 2, 1);
        px(1, 5, 10, 6);
        px(3, 6, 2, 1);
        px(7, 6, 2, 1);
        break;
      case '游戏':
        px(3, 3, 6, 1);
        px(2, 4, 8, 5);
        px(1, 6, 2, 3);
        px(9, 6, 2, 3);
        px(4, 5, 1, 3);
        px(3, 6, 3, 1);
        px(8, 5);
        px(9, 6);
        break;
      case '其他':
        px(2, 2, 3, 3);
        px(7, 2, 3, 3);
        px(2, 7, 3, 3);
        px(7, 7, 3, 3);
        break;
      case '全部':
      default:
        px(2, 3, 3, 1);
        px(1, 4, 2, 4);
        px(2, 8, 3, 1);
        px(4, 6, 4, 1);
        px(7, 3, 3, 1);
        px(9, 4, 2, 4);
        px(7, 8, 3, 1);
        px(4, 5, 4, 1);
        break;
    }
  }

  @override
  bool shouldRepaint(_PixelCategoryPainter oldDelegate) =>
      oldDelegate.category != category || oldDelegate.color != color;
}
