import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:window_placement/window_placement.dart';
import 'package:window_placement/window_placement_pigeon.dart';
import 'package:window_placement/src/messages.g.dart';

WindowGeometry _geometry({double windowX = 0, double insetTop = 0}) =>
    WindowGeometry(
      windowX: windowX,
      windowY: 0,
      windowWidth: 586,
      windowHeight: 820,
      screenWidth: 1180,
      screenHeight: 820,
      screenInsetLeft: 0,
      screenInsetTop: insetTop,
      screenInsetRight: 0,
      screenInsetBottom: 0,
      isMultiWindow: true,
    );

class _FakeHostApi extends WindowPlacementHostApi {
  _FakeHostApi(this.geometry);

  final WindowGeometry? geometry;

  @override
  Future<WindowGeometry?> getGeometry() async => geometry;
}

void main() {
  test('getPlacement classifies the native geometry', () async {
    final platform = PigeonWindowPlacement(
      hostApi: _FakeHostApi(_geometry(windowX: 594)),
    );
    final info = await platform.getPlacement();
    expect(info.placement, WindowPlacement.right);
    expect(info.windowBounds, const Rect.fromLTWH(594, 0, 586, 820));
    expect(info.isMultiWindow, isTrue);
  });

  test('getPlacement without a window is unknown', () async {
    final platform = PigeonWindowPlacement(hostApi: _FakeHostApi(null));
    expect(await platform.getPlacement(), WindowPlacementInfo.unknown);
  });

  test('toInfo carries the screen insets', () {
    final info = PigeonWindowPlacement.toInfo(_geometry(insetTop: 24));
    expect(info.placement, WindowPlacement.left);
    expect(info.screenInsets.top, 24);
  });
}
