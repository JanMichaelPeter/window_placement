import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:window_placement/window_placement.dart';

void main() {
  // iPad Air landscape / Pixel phone portrait, in logical pixels.
  const landscape = Rect.fromLTWH(0, 0, 1180, 820);
  const portrait = Rect.fromLTWH(0, 0, 412, 915);

  final cases = <String, (Rect, Rect, WindowPlacement)>{
    'fullscreen': (landscape, landscape, WindowPlacement.fullscreen),
    'split left 50/50': (
      const Rect.fromLTWH(0, 0, 586, 820),
      landscape,
      WindowPlacement.left,
    ),
    'split right 50/50 behind divider': (
      const Rect.fromLTWH(594, 0, 586, 820),
      landscape,
      WindowPlacement.right,
    ),
    'split right 1/3': (
      const Rect.fromLTWH(860, 0, 320, 820),
      landscape,
      WindowPlacement.right,
    ),
    'split top': (
      const Rect.fromLTWH(0, 0, 412, 452),
      portrait,
      WindowPlacement.top,
    ),
    'split bottom': (
      const Rect.fromLTWH(0, 463, 412, 452),
      portrait,
      WindowPlacement.bottom,
    ),
    'top left quarter': (
      const Rect.fromLTWH(0, 0, 590, 410),
      landscape,
      WindowPlacement.topLeft,
    ),
    'top right quarter': (
      const Rect.fromLTWH(590, 0, 590, 410),
      landscape,
      WindowPlacement.topRight,
    ),
    'bottom left quarter': (
      const Rect.fromLTWH(0, 410, 590, 410),
      landscape,
      WindowPlacement.bottomLeft,
    ),
    'bottom right quarter': (
      const Rect.fromLTWH(590, 410, 590, 410),
      landscape,
      WindowPlacement.bottomRight,
    ),
    'floating window': (
      const Rect.fromLTWH(200, 150, 600, 400),
      landscape,
      WindowPlacement.floating,
    ),
    'floating left': (
      const Rect.fromLTWH(0, 150, 600, 400),
      landscape,
      WindowPlacement.floatingLeft,
    ),
    'floating top': (
      const Rect.fromLTWH(300, 0, 600, 400),
      landscape,
      WindowPlacement.floatingTop,
    ),
    'floating right': (
      const Rect.fromLTWH(580, 150, 600, 400),
      landscape,
      WindowPlacement.floatingRight,
    ),
    'floating bottom': (
      const Rect.fromLTWH(300, 420, 600, 400),
      landscape,
      WindowPlacement.floatingBottom,
    ),
    // iPad Pro 13" freeform window parked next to the left edge, not snapped.
    'free window near the left edge is floating': (
      const Rect.fromLTWH(22, 268, 794.5, 737),
      Rect.fromLTWH(0, 0, 1376, 1032),
      WindowPlacement.floating,
    ),
    'free window below the status bar is floating': (
      const Rect.fromLTWH(420, 32, 794.5, 737),
      Rect.fromLTWH(0, 0, 1376, 1032),
      WindowPlacement.floating,
    ),
    'window snapped to the right edge': (
      const Rect.fromLTWH(581.5, 276, 794.5, 737),
      Rect.fromLTWH(0, 0, 1376, 1032),
      WindowPlacement.floatingRight,
    ),
    'floating full width': (
      const Rect.fromLTWH(0, 200, 1180, 400),
      landscape,
      WindowPlacement.floatingFullWidth,
    ),
    'floating full height': (
      const Rect.fromLTWH(300, 0, 600, 820),
      landscape,
      WindowPlacement.floatingFullHeight,
    ),
    'empty window': (Rect.zero, landscape, WindowPlacement.unknown),
    'empty screen': (landscape, Rect.zero, WindowPlacement.unknown),
  };

  for (final MapEntry(key: name, value: (window, screen, expected))
      in cases.entries) {
    test(name, () {
      expect(classifyWindowPlacement(window, screen), expected);
    });
  }

  test('window docked below the status bar still counts as top', () {
    const window = Rect.fromLTWH(0, 24, 392.7, 403.6);
    const screen = Rect.fromLTWH(0, 0, 392.7, 807.3);
    expect(
      classifyWindowPlacement(window, screen),
      WindowPlacement.floatingFullWidth,
    );
    expect(
      classifyWindowPlacement(
        window,
        screen,
        screenInsets: const EdgeInsets.only(top: 24, bottom: 48),
      ),
      WindowPlacement.top,
    );
  });

  test('fromBounds derives the placement', () {
    final info = WindowPlacementInfo.fromBounds(
      const Rect.fromLTWH(594, 0, 586, 820),
      landscape,
      isMultiWindow: true,
    );
    expect(info.placement, WindowPlacement.right);
    expect(info.windowBounds, const Rect.fromLTWH(594, 0, 586, 820));
    expect(info.isMultiWindow, isTrue);
  });

  test('touches*Edge reports each touched edge', () {
    final info = WindowPlacementInfo.fromBounds(
      const Rect.fromLTWH(594, 0, 586, 820),
      landscape,
    );
    expect(info.touchesLeftEdge, isFalse);
    expect(info.touchesTopEdge, isTrue);
    expect(info.touchesRightEdge, isTrue);
    expect(info.touchesBottomEdge, isTrue);
  });

  test('touches*Edge respects screen insets', () {
    const info = WindowPlacementInfo(
      placement: WindowPlacement.top,
      windowBounds: Rect.fromLTWH(0, 24, 392.7, 403.6),
      screenBounds: Rect.fromLTWH(0, 0, 392.7, 807.3),
      screenInsets: EdgeInsets.only(top: 24, bottom: 48),
      isMultiWindow: true,
    );
    expect(info.touchesTopEdge, isTrue);
    expect(info.touchesBottomEdge, isFalse);
  });

  test('unknown touches no edge', () {
    const info = WindowPlacementInfo.unknown;
    expect(info.touchesLeftEdge, isFalse);
    expect(info.touchesTopEdge, isFalse);
    expect(info.touchesRightEdge, isFalse);
    expect(info.touchesBottomEdge, isFalse);
  });
}
