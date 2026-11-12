import 'dart:ui' show Rect;

import 'window_placement_platform_interface.dart';
import 'src/window_edge.dart';
import 'src/window_environment.dart';
import 'src/window_placement_info.dart';

export 'src/window_edge.dart';
export 'src/window_environment.dart';
export 'src/window_placement_info.dart';

/// Tells where on the display the app window is shown
/// (fullscreen, left/right/top/bottom split, a corner tile,
/// pinned to one edge, or floating).
class WindowPlacementDetector {
  /// Returns the current placement of the app window.
  Future<WindowPlacementInfo> getPlacement() {
    return WindowPlacementPlatform.instance.getPlacement();
  }

  /// Emits the current placement on listen and whenever it changes.
  Stream<WindowPlacementInfo> get onPlacementChanged {
    return WindowPlacementPlatform.instance.onPlacementChanged;
  }

  /// Where the system places a bar [extent] logical pixels thick along
  /// [edge], in the app window's coordinates (the same as Flutter's).
  ///
  /// The region stays clear of the status icons, the rounded corners and the
  /// home indicator. On devices that show the status icons in a column at
  /// the side (iPhone Duo), a bar along that edge starts below the icons
  /// rather than below the whole safe area; where they sit in a band at the
  /// top, a top bar ends before them.
  ///
  /// Null where the platform has no such API (before iOS 27.1, Android) or no
  /// window is attached yet; fall back to `MediaQuery.padding` then. The
  /// region changes with rotation, folding and split screen, so ask again
  /// when [onPlacementChanged] emits or the window size changes.
  Future<Rect?> getBarRegion(WindowEdge edge, double extent) {
    return WindowPlacementPlatform.instance.getBarRegion(edge, extent);
  }

  /// Returns the placement and native traits of the window hosting the
  /// Flutter view, read together from that window.
  ///
  /// [WindowEnvironment.placement] is null while no window hosts the view;
  /// [WindowEnvironment.iosTraits] is null then and on Android.
  Future<WindowEnvironment> getEnvironment() {
    return WindowPlacementPlatform.instance.getEnvironment();
  }

  /// Emits the current environment on listen and whenever the geometry or the
  /// iOS traits change, including when the window goes away. Equal
  /// environments are not repeated.
  Stream<WindowEnvironment> get onEnvironmentChanged {
    return WindowPlacementPlatform.instance.onEnvironmentChanged;
  }
}
