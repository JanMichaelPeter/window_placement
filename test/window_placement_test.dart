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

const _phone = WindowEnvironment(
  placement: _fullscreen,
  iosTraits: IosWindowTraits(
    horizontalSizeClass: IosSizeClass.compact,
    verticalSizeClass: IosSizeClass.regular,
    interfaceIdiom: IosInterfaceIdiom.phone,
  ),
);

class MockWindowPlacementPlatform
    with MockPlatformInterfaceMixin
    implements WindowPlacementPlatform {
  @override
  Future<WindowPlacementInfo> getPlacement() => Future.value(_fullscreen);

  @override
  Stream<WindowPlacementInfo> get onPlacementChanged =>
      Stream.value(_fullscreen);

  @override
  Future<Rect?> getBarRegion(WindowEdge edge, double extent) =>
      Future.value(Rect.fromLTWH(0, 16, 400, extent));

  @override
  Future<WindowEnvironment> getEnvironment() => Future.value(_phone);

  @override
  Stream<WindowEnvironment> get onEnvironmentChanged => Stream.value(_phone);
}

/// An implementation written before environments existed.
class LegacyWindowPlacementPlatform extends WindowPlacementPlatform {
  LegacyWindowPlacementPlatform(this.placements);

  final List<WindowPlacementInfo> placements;

  @override
  Future<WindowPlacementInfo> getPlacement() async => placements.first;

  @override
  Stream<WindowPlacementInfo> get onPlacementChanged =>
      Stream.fromIterable(placements);
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

  test('getBarRegion delegates to the platform', () async {
    WindowPlacementPlatform.instance = MockWindowPlacementPlatform();
    expect(
      await WindowPlacementDetector().getBarRegion(WindowEdge.top, 64),
      const Rect.fromLTWH(0, 16, 400, 64),
    );
  });

  test(
    'getEnvironment and onEnvironmentChanged delegate to the platform',
    () async {
      final detector = WindowPlacementDetector();
      WindowPlacementPlatform.instance = MockWindowPlacementPlatform();

      expect(await detector.getEnvironment(), _phone);
      expect(await detector.onEnvironmentChanged.first, _phone);
    },
  );

  group('a legacy platform implementation', () {
    test('getEnvironment wraps the placement without traits', () async {
      WindowPlacementPlatform.instance = LegacyWindowPlacementPlatform([
        _fullscreen,
      ]);
      expect(
        await WindowPlacementDetector().getEnvironment(),
        const WindowEnvironment(placement: _fullscreen, iosTraits: null),
      );
    });

    test('maps the unknown placeholder to no placement', () async {
      WindowPlacementPlatform.instance = LegacyWindowPlacementPlatform([
        WindowPlacementInfo.unknown,
      ]);
      expect(
        await WindowPlacementDetector().getEnvironment(),
        WindowEnvironment.unavailable,
      );
    });

    test('onEnvironmentChanged wraps and dedupes the placements', () async {
      WindowPlacementPlatform.instance = LegacyWindowPlacementPlatform([
        WindowPlacementInfo.unknown,
        _fullscreen,
        _fullscreen,
      ]);
      expect(await WindowPlacementDetector().onEnvironmentChanged.toList(), [
        WindowEnvironment.unavailable,
        const WindowEnvironment(placement: _fullscreen, iosTraits: null),
      ]);
    });
  });

  group('$WindowEnvironment', () {
    test('equal when placement and traits are equal', () {
      const copy = WindowEnvironment(
        placement: _fullscreen,
        iosTraits: IosWindowTraits(
          horizontalSizeClass: IosSizeClass.compact,
          verticalSizeClass: IosSizeClass.regular,
          interfaceIdiom: IosInterfaceIdiom.phone,
        ),
      );
      expect(copy, _phone);
      expect(copy.hashCode, _phone.hashCode);
    });

    test('differs when only the traits differ', () {
      const regular = WindowEnvironment(
        placement: _fullscreen,
        iosTraits: IosWindowTraits(
          horizontalSizeClass: IosSizeClass.regular,
          verticalSizeClass: IosSizeClass.regular,
          interfaceIdiom: IosInterfaceIdiom.phone,
        ),
      );
      expect(regular, isNot(_phone));
    });

    test('tells missing traits apart from unspecified ones', () {
      const unspecified = WindowEnvironment(
        placement: _fullscreen,
        iosTraits: IosWindowTraits(
          horizontalSizeClass: IosSizeClass.unspecified,
          verticalSizeClass: IosSizeClass.unspecified,
          interfaceIdiom: IosInterfaceIdiom.unspecified,
        ),
      );
      expect(
        unspecified,
        isNot(const WindowEnvironment(placement: _fullscreen, iosTraits: null)),
      );
    });
  });
}
