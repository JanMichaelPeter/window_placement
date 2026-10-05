import 'window_placement_platform_interface.dart';
import 'src/window_placement_info.dart';

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
}
