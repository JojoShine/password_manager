import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:password_manager/utils/desktop_window_layout.dart';

void main() {
  test('large work areas use the preferred desktop window size', () {
    final layout = calculateDesktopWindowLayout(
      const Size(1920, 1040),
    );

    expect(layout.initialSize, const Size(900, 900));
    expect(layout.minimumSize, const Size(400, 600));
  });

  test('scaled laptop work areas keep a safe margin around the window', () {
    final layout = calculateDesktopWindowLayout(
      const Size(1280, 720),
    );

    expect(layout.initialSize, const Size(900, 672));
    expect(layout.minimumSize, const Size(400, 600));
  });

  test('small work areas also cap the dynamic minimum height', () {
    final layout = calculateDesktopWindowLayout(
      const Size(800, 500),
    );

    expect(layout.initialSize, const Size(752, 452));
    expect(layout.minimumSize, const Size(400, 452));
  });

  test('the cursor display determines the work area on multiple monitors', () {
    final workArea = selectCurrentVisibleWorkArea(
      displayAreas: const [
        (
          bounds: Rect.fromLTWH(0, 0, 1920, 1080),
          visibleWorkArea: Size(1920, 1040),
        ),
        (
          bounds: Rect.fromLTWH(1920, 0, 1280, 768),
          visibleWorkArea: Size(1280, 720),
        ),
      ],
      cursorPosition: const Offset(2200, 750),
      fallbackSize: const Size(1920, 1040),
    );

    expect(workArea, const Size(1280, 720));
  });
}
