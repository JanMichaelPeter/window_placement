## 0.0.3

* `WindowPlacementDetector.getBarRegion(edge, extent)`: where the system places a bar of that thickness along a window edge, clear of the status icons, rounded corners and home indicator (iOS 27.1+, `UIView.LayoutRegion.bar(onEdge:extent:)`). On the iPhone Duo, a bar on the edge with the status icons starts below them; a top bar ends before them. Null before iOS 27.1 and on Android.

## 0.0.2

* Supports Dart 3.9 / Flutter 3.35 and later (was Dart 3.10).

## 0.0.1

* Initial release: `WindowPlacementDetector.getPlacement()` and `WindowPlacementDetector.onPlacementChanged` report the window placement (`fullscreen`, `left`, `right`, `top`, `bottom`, corner tiles, `floatingLeft` / `floatingTop` / `floatingRight` / `floatingBottom`, `floatingFullWidth`, `floatingFullHeight`, `floating`) on iOS and Android, plus `touchesLeftEdge` / `touchesTopEdge` / `touchesRightEdge` / `touchesBottomEdge`.
* iOS: supports both Swift Package Manager and CocoaPods.
