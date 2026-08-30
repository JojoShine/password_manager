import 'dart:math' as math;
import 'dart:ui';

class DesktopWindowLayout {
  const DesktopWindowLayout({
    required this.initialSize,
    required this.minimumSize,
  });

  final Size initialSize;
  final Size minimumSize;
}

const preferredDesktopWindowSize = Size(900, 900);
const fallbackDesktopWindowLayout = DesktopWindowLayout(
  initialSize: Size(760, 640),
  minimumSize: Size(400, 600),
);

typedef DesktopDisplayArea = ({Rect bounds, Size visibleWorkArea});

Size selectCurrentVisibleWorkArea({
  required List<DesktopDisplayArea> displayAreas,
  required Offset cursorPosition,
  required Size fallbackSize,
}) {
  for (final displayArea in displayAreas) {
    if (displayArea.bounds.contains(cursorPosition)) {
      return displayArea.visibleWorkArea;
    }
  }
  return fallbackSize;
}

DesktopWindowLayout calculateDesktopWindowLayout(
  Size visibleWorkArea, {
  double edgeMargin = 24,
}) {
  final availableWidth = math.max(1.0, visibleWorkArea.width - edgeMargin * 2);
  final availableHeight =
      math.max(1.0, visibleWorkArea.height - edgeMargin * 2);
  final initialSize = Size(
    math.min(preferredDesktopWindowSize.width, availableWidth),
    math.min(preferredDesktopWindowSize.height, availableHeight),
  );

  return DesktopWindowLayout(
    initialSize: initialSize,
    minimumSize: Size(
      math.min(400, initialSize.width),
      math.min(600, initialSize.height),
    ),
  );
}
