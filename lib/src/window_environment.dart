import 'window_placement_info.dart';

/// A UIKit size class (`UITraitCollection.horizontalSizeClass` /
/// `verticalSizeClass`).
enum IosSizeClass {
  /// `UIUserInterfaceSizeClass.compact`.
  compact,

  /// `UIUserInterfaceSizeClass.regular`.
  regular,

  /// `UIUserInterfaceSizeClass.unspecified`: UIKit reports traits, but has
  /// not resolved this one.
  unspecified,
}

/// A UIKit interface idiom (`UITraitCollection.userInterfaceIdiom`).
enum IosInterfaceIdiom {
  /// `UIUserInterfaceIdiom.phone`.
  phone,

  /// `UIUserInterfaceIdiom.pad`.
  pad,

  /// Any other idiom (Mac Catalyst, CarPlay, TV, vision, and idioms added
  /// later). Not a tablet.
  other,

  /// `UIUserInterfaceIdiom.unspecified`.
  unspecified,
}

/// The UIKit traits of the view controller hosting the Flutter view.
///
/// These are facts reported by UIKit, not layout advice: a `regular` size
/// class does not mean an app should show a navigation rail.
class IosWindowTraits {
  const IosWindowTraits({
    required this.horizontalSizeClass,
    required this.verticalSizeClass,
    required this.interfaceIdiom,
  });

  final IosSizeClass horizontalSizeClass;
  final IosSizeClass verticalSizeClass;
  final IosInterfaceIdiom interfaceIdiom;

  @override
  bool operator ==(Object other) =>
      other is IosWindowTraits &&
      other.horizontalSizeClass == horizontalSizeClass &&
      other.verticalSizeClass == verticalSizeClass &&
      other.interfaceIdiom == interfaceIdiom;

  @override
  int get hashCode =>
      Object.hash(horizontalSizeClass, verticalSizeClass, interfaceIdiom);

  @override
  String toString() =>
      'IosWindowTraits(horizontal: ${horizontalSizeClass.name}, '
      'vertical: ${verticalSizeClass.name}, idiom: ${interfaceIdiom.name})';
}

/// The placement and native traits of the window hosting the Flutter view,
/// read together from the same window.
class WindowEnvironment {
  const WindowEnvironment({required this.placement, required this.iosTraits});

  /// No window is hosting the Flutter view (not attached yet, or detached).
  static const WindowEnvironment unavailable = WindowEnvironment(
    placement: null,
    iosTraits: null,
  );

  /// The window's placement and geometry, or null when there is no window.
  final WindowPlacementInfo? placement;

  /// The hosting view controller's UIKit traits. Null when there is no window,
  /// and always null on Android, which has no size classes.
  final IosWindowTraits? iosTraits;

  @override
  bool operator ==(Object other) =>
      other is WindowEnvironment &&
      other.placement == placement &&
      other.iosTraits == iosTraits;

  @override
  int get hashCode => Object.hash(placement, iosTraits);

  @override
  String toString() => 'WindowEnvironment($placement, $iosTraits)';
}
