import 'dart:async';
import 'dart:ui' show Rect;

import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart' show EdgeInsets;

import 'window_placement_platform_interface.dart';
import 'src/messages.g.dart';
import 'src/window_edge.dart';
import 'src/window_environment.dart';
import 'src/window_placement_info.dart';

/// An implementation of [WindowPlacementPlatform] that talks to the native side
/// through the Pigeon-generated API in `pigeons/messages.dart`.
class PigeonWindowPlacement extends WindowPlacementPlatform {
  PigeonWindowPlacement({@visibleForTesting WindowPlacementHostApi? hostApi})
    : _hostApi = hostApi ?? WindowPlacementHostApi();

  final WindowPlacementHostApi _hostApi;

  late final _placementChanges = _SharedStream(
    () => geometryChanges().map(toInfo).distinct(),
  );
  late final _environmentChanges = _SharedStream(
    () => environmentChanges().map(toEnvironment).distinct(),
  );

  @override
  Future<WindowPlacementInfo> getPlacement() async {
    final geometry = await _hostApi.getGeometry();
    return geometry == null ? WindowPlacementInfo.unknown : toInfo(geometry);
  }

  @override
  Stream<WindowPlacementInfo> get onPlacementChanged =>
      _placementChanges.stream;

  @override
  Future<Rect?> getBarRegion(WindowEdge edge, double extent) async {
    final region = await _hostApi.getBarRegion(switch (edge) {
      WindowEdge.left => BarEdge.left,
      WindowEdge.top => BarEdge.top,
      WindowEdge.right => BarEdge.right,
      WindowEdge.bottom => BarEdge.bottom,
    }, extent);
    return region == null
        ? null
        : Rect.fromLTWH(region.x, region.y, region.width, region.height);
  }

  @override
  Future<WindowEnvironment> getEnvironment() async =>
      toEnvironment(await _hostApi.getEnvironment());

  @override
  Stream<WindowEnvironment> get onEnvironmentChanged =>
      _environmentChanges.stream;

  /// Converts the native geometry into a classified [WindowPlacementInfo].
  @visibleForTesting
  static WindowPlacementInfo toInfo(WindowGeometry g) {
    return WindowPlacementInfo.fromBounds(
      Rect.fromLTWH(g.windowX, g.windowY, g.windowWidth, g.windowHeight),
      Rect.fromLTWH(0, 0, g.screenWidth, g.screenHeight),
      screenInsets: EdgeInsets.fromLTRB(
        g.screenInsetLeft,
        g.screenInsetTop,
        g.screenInsetRight,
        g.screenInsetBottom,
      ),
      isMultiWindow: g.isMultiWindow,
    );
  }

  /// Converts the native snapshot into a [WindowEnvironment].
  @visibleForTesting
  static WindowEnvironment toEnvironment(WindowSnapshot s) {
    final geometry = s.geometry;
    final traits = s.traits;
    return WindowEnvironment(
      placement: geometry == null ? null : toInfo(geometry),
      iosTraits: traits == null
          ? null
          : IosWindowTraits(
              horizontalSizeClass: _sizeClass(traits.horizontalSizeClass),
              verticalSizeClass: _sizeClass(traits.verticalSizeClass),
              interfaceIdiom: switch (traits.interfaceIdiom) {
                InterfaceIdiom.phone => IosInterfaceIdiom.phone,
                InterfaceIdiom.pad => IosInterfaceIdiom.pad,
                InterfaceIdiom.other => IosInterfaceIdiom.other,
                InterfaceIdiom.unspecified => IosInterfaceIdiom.unspecified,
              },
            ),
    );
  }

  static IosSizeClass _sizeClass(SizeClass sizeClass) => switch (sizeClass) {
    SizeClass.compact => IosSizeClass.compact,
    SizeClass.regular => IosSizeClass.regular,
    SizeClass.unspecified => IosSizeClass.unspecified,
  };
}

/// Shares one event channel subscription among all listeners.
///
/// Each event channel has a single native sink, so a second channel
/// subscription would take the events from the first, and cancelling either
/// would stop both. The native side sends the current value only when the
/// first listener subscribes, so later listeners get the latest value first.
class _SharedStream<T extends Object> {
  _SharedStream(this._source);

  final Stream<T> Function() _source;
  final Set<MultiStreamController<T>> _listeners = {};
  StreamSubscription<T>? _subscription;
  T? _latest;

  late final Stream<T> stream = Stream.multi(_onListen, isBroadcast: true);

  void _onListen(MultiStreamController<T> listener) {
    _listeners.add(listener);
    final latest = _latest;
    if (latest != null) listener.add(latest);
    _subscription ??= _source().listen(
      (value) {
        _latest = value;
        for (final listener in _listeners) {
          listener.add(value);
        }
      },
      onError: (Object error, StackTrace stackTrace) {
        for (final listener in _listeners) {
          listener.addError(error, stackTrace);
        }
      },
      onDone: () {
        final listeners = [..._listeners];
        _reset();
        for (final listener in listeners) {
          listener.close();
        }
      },
    );
    listener.onCancel = () {
      _listeners.remove(listener);
      if (_listeners.isNotEmpty) return null;
      final subscription = _subscription;
      _reset();
      return subscription?.cancel();
    };
  }

  void _reset() {
    _listeners.clear();
    _subscription = null;
    _latest = null;
  }
}
