import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:window_placement/window_placement.dart';
import 'package:window_placement/window_placement_platform_interface.dart';
import 'package:window_placement/window_placement_pigeon.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

const _fullscreen = WindowPlacementInfo(
  placement: WindowPlacement.fullscreen,
  windowBounds: Rect.fromLTWH(0, 0, 400, 800),
  screenBounds: Rect.fromLTWH(0, 0, 400, 800),
  isMultiWindow: false,
);

class MockWindowPlacementPlatform
    with MockPlatformInterfaceMixin
    implements WindowPlacementPlatform {
  @override
  Future<WindowPlacementInfo> getPlacement() => Future.value(_fullscreen);

  @override
  Stream<WindowPlacementInfo> get onPlacementChanged =>
      Stream.value(_fullscreen);
}

void main() {
  final WindowPlacementPlatform initialPlatform =
      WindowPlacementPlatform.instance;

  test('$PigeonWindowPlacement is the default instance', () {
    expect(initialPlatform, isInstanceOf<PigeonWindowPlacement>());
  });

  test(
    'getPlacement and onPlacementChanged delegate to the platform',
    () async {
      WindowPlacementDetector detector = WindowPlacementDetector();
      WindowPlacementPlatform.instance = MockWindowPlacementPlatform();

      expect(await detector.getPlacement(), _fullscreen);
      expect(await detector.onPlacementChanged.first, _fullscreen);
    },
  );
}
