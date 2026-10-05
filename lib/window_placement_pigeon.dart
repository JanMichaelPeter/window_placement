import 'dart:ui' show Rect;

import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart' show EdgeInsets;

import 'window_placement_platform_interface.dart';
import 'src/messages.g.dart';
import 'src/window_placement_info.dart';

/// An implementation of [WindowPlacementPlatform] that talks to the native side
/// through the Pigeon-generated API in `pigeons/messages.dart`.
class PigeonWindowPlacement extends WindowPlacementPlatform {
  PigeonWindowPlacement({@visibleForTesting WindowPlacementHostApi? hostApi})
    : _hostApi = hostApi ?? WindowPlacementHostApi();

  final WindowPlacementHostApi _hostApi;

  @override
  Future<WindowPlacementInfo> getPlacement() async {
    final geometry = await _hostApi.getGeometry();
    return geometry == null ? WindowPlacementInfo.unknown : toInfo(geometry);
  }

  @override
  Stream<WindowPlacementInfo> get onPlacementChanged =>
      geometryChanges().map(toInfo).distinct();

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
}
