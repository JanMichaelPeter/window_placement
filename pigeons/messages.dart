import 'package:pigeon/pigeon.dart';

// Regenerate with: dart run pigeon --input pigeons/messages.dart

@ConfigurePigeon(
  PigeonOptions(
    dartOut: 'lib/src/messages.g.dart',
    kotlinOut:
        'android/src/main/kotlin/io/github/janmichaelpeter/window_placement/Messages.g.kt',
    kotlinOptions: KotlinOptions(
      package: 'io.github.janmichaelpeter.window_placement',
    ),
    swiftOut: 'ios/window_placement/Sources/window_placement/Messages.g.swift',
    dartPackageName: 'window_placement',
  ),
)
/// The app window and the display it is on, in logical pixels and display
/// coordinates.
class WindowGeometry {
  WindowGeometry({
    required this.windowX,
    required this.windowY,
    required this.windowWidth,
    required this.windowHeight,
    required this.screenWidth,
    required this.screenHeight,
    required this.screenInsetLeft,
    required this.screenInsetTop,
    required this.screenInsetRight,
    required this.screenInsetBottom,
    required this.isMultiWindow,
  });

  double windowX;
  double windowY;
  double windowWidth;
  double windowHeight;
  double screenWidth;
  double screenHeight;

  /// System bars / cutouts on each side of the display that a docked window
  /// may stop at. Zero where the platform has none.
  double screenInsetLeft;
  double screenInsetTop;
  double screenInsetRight;
  double screenInsetBottom;

  /// Whether the OS reports the app as being in a multi-window mode.
  bool isMultiWindow;
}

/// A physical edge of the app window.
enum BarEdge { left, top, right, bottom }

/// A rectangle in the app window's coordinates, in logical pixels.
class BarRegion {
  BarRegion({
    required this.x,
    required this.y,
    required this.width,
    required this.height,
  });

  double x;
  double y;
  double width;
  double height;
}

@HostApi()
abstract class WindowPlacementHostApi {
  /// The current geometry, or null when no window is attached yet.
  WindowGeometry? getGeometry();

  /// Where the system places a bar [extent] thick along [edge], clear of the
  /// status icons, rounded corners and home indicator. Null where the platform
  /// has no such API (before iOS 27.1, Android) or no window is attached yet.
  BarRegion? getBarRegion(BarEdge edge, double extent);
}

@EventChannelApi()
abstract class WindowPlacementEventApi {
  /// Emits the geometry on listen and whenever it changes.
  WindowGeometry geometryChanges();
}
