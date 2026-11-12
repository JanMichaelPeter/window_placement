import 'package:flutter/services.dart';
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

WindowTraits _traits({SizeClass horizontal = SizeClass.compact}) =>
    WindowTraits(
      horizontalSizeClass: horizontal,
      verticalSizeClass: SizeClass.regular,
      interfaceIdiom: InterfaceIdiom.pad,
    );

class _FakeHostApi extends WindowPlacementHostApi {
  _FakeHostApi(this.geometry, {this.barRegion, this.snapshot});

  final WindowGeometry? geometry;
  final BarRegion? barRegion;
  final WindowSnapshot? snapshot;
  final List<(BarEdge, double)> barRegionCalls = [];

  @override
  Future<WindowGeometry?> getGeometry() async => geometry;

  @override
  Future<BarRegion?> getBarRegion(BarEdge edge, double extent) async {
    barRegionCalls.add((edge, extent));
    return barRegion;
  }

  @override
  Future<WindowSnapshot> getEnvironment() async =>
      snapshot ?? (throw PlatformException(code: 'boom'));
}

/// Stands in for the native side of an event channel.
class _NativeEvents {
  _NativeEvents(String name) {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockStreamHandler(
          EventChannel(
            'dev.flutter.pigeon.window_placement.WindowPlacementEventApi.$name',
            pigeonMethodCodec,
          ),
          MockStreamHandler.inline(
            onListen: (_, events) {
              listens++;
              sink = events;
              onListen?.call(events);
            },
            onCancel: (_) {
              cancels++;
              sink = null;
            },
          ),
        );
  }

  void Function(MockStreamHandlerEventSink events)? onListen;
  MockStreamHandlerEventSink? sink;
  int listens = 0;
  int cancels = 0;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

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

  test('getBarRegion passes the edge and extent and returns a Rect', () async {
    final hostApi = _FakeHostApi(
      null,
      barRegion: BarRegion(x: 386, y: 170, width: 64, height: 474),
    );
    final platform = PigeonWindowPlacement(hostApi: hostApi);
    final region = await platform.getBarRegion(WindowEdge.right, 64);
    expect(region, const Rect.fromLTWH(386, 170, 64, 474));
    expect(hostApi.barRegionCalls, [(BarEdge.right, 64.0)]);
  });

  test('getBarRegion is null where the platform has none', () async {
    final platform = PigeonWindowPlacement(hostApi: _FakeHostApi(null));
    expect(await platform.getBarRegion(WindowEdge.top, 64), isNull);
  });

  group('toEnvironment', () {
    test('maps the geometry and every trait', () {
      final environment = PigeonWindowPlacement.toEnvironment(
        WindowSnapshot(geometry: _geometry(windowX: 594), traits: _traits()),
      );
      expect(environment.placement?.placement, WindowPlacement.right);
      expect(
        environment.iosTraits,
        const IosWindowTraits(
          horizontalSizeClass: IosSizeClass.compact,
          verticalSizeClass: IosSizeClass.regular,
          interfaceIdiom: IosInterfaceIdiom.pad,
        ),
      );
    });

    test('maps each size class and idiom', () {
      IosWindowTraits? traits(SizeClass sizeClass, InterfaceIdiom idiom) =>
          PigeonWindowPlacement.toEnvironment(
            WindowSnapshot(
              traits: WindowTraits(
                horizontalSizeClass: sizeClass,
                verticalSizeClass: sizeClass,
                interfaceIdiom: idiom,
              ),
            ),
          ).iosTraits;
      expect(
        [
          for (final s in SizeClass.values)
            traits(s, InterfaceIdiom.phone)!.horizontalSizeClass,
        ],
        [IosSizeClass.compact, IosSizeClass.regular, IosSizeClass.unspecified],
      );
      expect(
        [
          for (final i in InterfaceIdiom.values)
            traits(SizeClass.compact, i)!.interfaceIdiom,
        ],
        [
          IosInterfaceIdiom.phone,
          IosInterfaceIdiom.pad,
          IosInterfaceIdiom.other,
          IosInterfaceIdiom.unspecified,
        ],
      );
    });

    test('without a window is unavailable', () {
      expect(
        PigeonWindowPlacement.toEnvironment(WindowSnapshot()),
        WindowEnvironment.unavailable,
      );
    });

    test('on Android has a placement but no traits', () {
      final environment = PigeonWindowPlacement.toEnvironment(
        WindowSnapshot(geometry: _geometry()),
      );
      expect(environment.placement, isNotNull);
      expect(environment.iosTraits, isNull);
    });
  });

  test('getEnvironment converts the native snapshot', () async {
    final platform = PigeonWindowPlacement(
      hostApi: _FakeHostApi(
        null,
        snapshot: WindowSnapshot(geometry: _geometry(), traits: _traits()),
      ),
    );
    final environment = await platform.getEnvironment();
    expect(environment.placement?.placement, WindowPlacement.left);
    expect(environment.iosTraits?.interfaceIdiom, IosInterfaceIdiom.pad);
  });

  test('getEnvironment passes native failures on', () async {
    final platform = PigeonWindowPlacement(hostApi: _FakeHostApi(null));
    await expectLater(
      platform.getEnvironment(),
      throwsA(isA<PlatformException>()),
    );
  });

  group('onEnvironmentChanged', () {
    late _NativeEvents native;
    late PigeonWindowPlacement platform;

    setUp(() {
      native = _NativeEvents('environmentChanges');
      platform = PigeonWindowPlacement(hostApi: _FakeHostApi(null));
    });

    test('emits trait-only changes and drops equal snapshots', () async {
      native.onListen = (events) {
        events.success(
          WindowSnapshot(geometry: _geometry(), traits: _traits()),
        );
        events.success(
          WindowSnapshot(geometry: _geometry(), traits: _traits()),
        );
        events.success(
          WindowSnapshot(
            geometry: _geometry(),
            traits: _traits(horizontal: SizeClass.regular),
          ),
        );
        events.success(WindowSnapshot());
        events.endOfStream();
      };
      final environments = await platform.onEnvironmentChanged.toList();
      expect(
        [for (final e in environments) e.iosTraits?.horizontalSizeClass],
        [IosSizeClass.compact, IosSizeClass.regular, null],
      );
      expect(environments.last, WindowEnvironment.unavailable);
    });

    test('passes native errors to the subscriber', () async {
      native.onListen = (events) => events.error(code: 'boom');
      await expectLater(
        platform.onEnvironmentChanged.first,
        throwsA(isA<PlatformException>()),
      );
    });

    test('shares one native subscription among subscribers', () async {
      native.onListen = (events) => events.success(WindowSnapshot());
      final first = <WindowEnvironment>[];
      final second = <WindowEnvironment>[];
      final a = platform.onEnvironmentChanged.listen(first.add);
      await pumpEventQueue();
      final b = platform.onEnvironmentChanged.listen(second.add);
      await pumpEventQueue();
      // The late subscriber gets the current environment too.
      expect(second, [WindowEnvironment.unavailable]);

      await a.cancel();
      native.sink!.success(
        WindowSnapshot(geometry: _geometry(), traits: _traits()),
      );
      await pumpEventQueue();
      expect(first, [WindowEnvironment.unavailable]);
      expect(second, hasLength(2));
      expect(native.listens, 1);
      expect(native.cancels, 0);

      await b.cancel();
      expect(native.cancels, 1);
    });

    test('starts over after the last subscriber cancels', () async {
      native.onListen = (events) => events.success(WindowSnapshot());
      expect(
        await platform.onEnvironmentChanged.first,
        WindowEnvironment.unavailable,
      );
      expect(native.cancels, 1);
      expect(
        await platform.onEnvironmentChanged.first,
        WindowEnvironment.unavailable,
      );
      expect(native.listens, 2);
    });
  });

  group('onPlacementChanged', () {
    test('drops equal placements', () async {
      _NativeEvents('geometryChanges').onListen = (events) {
        events.success(_geometry());
        events.success(_geometry());
        events.success(_geometry(windowX: 594));
        events.endOfStream();
      };
      final platform = PigeonWindowPlacement(hostApi: _FakeHostApi(null));
      expect(
        [
          for (final info in await platform.onPlacementChanged.toList())
            info.placement,
        ],
        [WindowPlacement.left, WindowPlacement.right],
      );
    });

    test('keeps other subscribers when one cancels', () async {
      final native = _NativeEvents('geometryChanges')
        ..onListen = (events) => events.success(_geometry());
      final platform = PigeonWindowPlacement(hostApi: _FakeHostApi(null));
      final placements = <WindowPlacement>[];
      final a = platform.onPlacementChanged.listen((_) {});
      final b = platform.onPlacementChanged.listen(
        (info) => placements.add(info.placement),
      );
      await pumpEventQueue();
      await a.cancel();
      native.sink!.success(_geometry(windowX: 594));
      await pumpEventQueue();
      expect(placements, [WindowPlacement.left, WindowPlacement.right]);
      await b.cancel();
      expect(native.cancels, 1);
    });
  });
}
