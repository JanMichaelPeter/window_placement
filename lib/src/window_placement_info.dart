import 'dart:ui' show Rect;

import 'package:flutter/painting.dart' show EdgeInsets;

/// Where the app window sits on the physical display.
enum WindowPlacement {
  /// The window covers the whole display.
  fullscreen,

  /// Split screen, left side (iPad Split View, Android landscape split).
  left,

  /// Split screen, right side.
  right,

  /// Split screen, top side (Android portrait split).
  top,

  /// Split screen, bottom side.
  bottom,

  /// Window tiled into the top-left quarter (iPadOS windowing, Android desktop).
  topLeft,

  /// Window tiled into the top-right quarter.
  topRight,

  /// Window tiled into the bottom-left quarter.
  bottomLeft,

  /// Window tiled into the bottom-right quarter.
  bottomRight,

  /// Free window touching only the left display edge (e.g. an iPadOS window
  /// snapped to the left edge).
  floatingLeft,

  /// Free window touching only the top display edge.
  floatingTop,

  /// Free window touching only the right display edge.
  floatingRight,

  /// Free window touching only the bottom display edge.
  floatingBottom,

  /// Free window spanning the full display width, but touching neither the
  /// top nor the bottom edge.
  floatingFullWidth,

  /// Free window spanning the full display height, but touching neither the
  /// left nor the right edge.
  floatingFullHeight,

  /// A free-floating window that touches no display edge
  /// (Stage Manager, Android freeform windows, picture-in-picture).
  floating,

  /// The placement could not be determined (e.g. no window attached yet).
  unknown,
}

/// The current window placement together with the raw geometry it was derived from.
class WindowPlacementInfo {
  const WindowPlacementInfo({
    required this.placement,
    required this.windowBounds,
    required this.screenBounds,
    required this.isMultiWindow,
    this.screenInsets = EdgeInsets.zero,
  });

  /// Placeholder for when no geometry is available.
  static const WindowPlacementInfo unknown = WindowPlacementInfo(
    placement: WindowPlacement.unknown,
    windowBounds: Rect.zero,
    screenBounds: Rect.zero,
    isMultiWindow: false,
  );

  /// Builds the info for [window] on [screen] and derives [placement] with
  /// [classifyWindowPlacement].
  factory WindowPlacementInfo.fromBounds(
    Rect window,
    Rect screen, {
    EdgeInsets screenInsets = EdgeInsets.zero,
    bool isMultiWindow = false,
  }) {
    return WindowPlacementInfo(
      placement: classifyWindowPlacement(
        window,
        screen,
        screenInsets: screenInsets,
      ),
      windowBounds: window,
      screenBounds: screen,
      screenInsets: screenInsets,
      isMultiWindow: isMultiWindow,
    );
  }

  /// The window bounds in logical pixels, in display coordinates.
  final Rect windowBounds;

  /// The display bounds in logical pixels.
  final Rect screenBounds;

  /// System bars / cutouts on the display that a docked window may stop at.
  final EdgeInsets screenInsets;

  /// Whether the OS reports the app as being in a multi-window mode.
  final bool isMultiWindow;

  /// The derived placement of the window on the display.
  final WindowPlacement placement;

  /// Whether the window touches the left edge of the display.
  bool get touchesLeftEdge => _edges.$1;

  /// Whether the window touches the top edge of the display.
  bool get touchesTopEdge => _edges.$2;

  /// Whether the window touches the right edge of the display.
  bool get touchesRightEdge => _edges.$3;

  /// Whether the window touches the bottom edge of the display.
  bool get touchesBottomEdge => _edges.$4;

  (bool, bool, bool, bool) get _edges =>
      windowBounds.isEmpty || screenBounds.isEmpty
      ? (false, false, false, false)
      : _touchedEdges(windowBounds, screenBounds, screenInsets);

  @override
  bool operator ==(Object other) =>
      other is WindowPlacementInfo &&
      other.placement == placement &&
      other.windowBounds == windowBounds &&
      other.screenBounds == screenBounds &&
      other.screenInsets == screenInsets &&
      other.isMultiWindow == isMultiWindow;

  @override
  int get hashCode => Object.hash(
    placement,
    windowBounds,
    screenBounds,
    screenInsets,
    isMultiWindow,
  );

  @override
  String toString() =>
      'WindowPlacementInfo($placement, window: $windowBounds, '
      'screen: $screenBounds, insets: $screenInsets, '
      'isMultiWindow: $isMultiWindow)';
}

/// Derives a [WindowPlacement] by checking which display edges [window] touches.
///
/// An edge counts as touched when the window is within 2 logical pixels of it
/// (rounding), plus the [screenInsets] on that side (e.g. Android windows
/// docked below the status bar). Split, tiled and snapped windows sit exactly
/// on the edge; a free window parked next to an edge does not.
WindowPlacement classifyWindowPlacement(
  Rect window,
  Rect screen, {
  EdgeInsets screenInsets = EdgeInsets.zero,
}) {
  if (window.isEmpty || screen.isEmpty) return WindowPlacement.unknown;

  return switch (_touchedEdges(window, screen, screenInsets)) {
    (true, true, true, true) => WindowPlacement.fullscreen,
    (true, true, false, true) => WindowPlacement.left,
    (false, true, true, true) => WindowPlacement.right,
    (true, true, true, false) => WindowPlacement.top,
    (true, false, true, true) => WindowPlacement.bottom,
    (true, true, false, false) => WindowPlacement.topLeft,
    (false, true, true, false) => WindowPlacement.topRight,
    (true, false, false, true) => WindowPlacement.bottomLeft,
    (false, false, true, true) => WindowPlacement.bottomRight,
    (true, false, false, false) => WindowPlacement.floatingLeft,
    (false, true, false, false) => WindowPlacement.floatingTop,
    (false, false, true, false) => WindowPlacement.floatingRight,
    (false, false, false, true) => WindowPlacement.floatingBottom,
    (true, false, true, false) => WindowPlacement.floatingFullWidth,
    (false, true, false, true) => WindowPlacement.floatingFullHeight,
    (false, false, false, false) => WindowPlacement.floating,
  };
}

/// How far (in logical pixels) a window may be from an edge and still touch it.
const double _edgeTolerance = 2;

/// Which display edges [window] touches, as (left, top, right, bottom).
(bool, bool, bool, bool) _touchedEdges(
  Rect window,
  Rect screen,
  EdgeInsets screenInsets,
) {
  return (
    (window.left - screen.left).abs() <= _edgeTolerance + screenInsets.left,
    (window.top - screen.top).abs() <= _edgeTolerance + screenInsets.top,
    (screen.right - window.right).abs() <= _edgeTolerance + screenInsets.right,
    (screen.bottom - window.bottom).abs() <=
        _edgeTolerance + screenInsets.bottom,
  );
}
