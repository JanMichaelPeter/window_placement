# window_placement

A Flutter plugin that tells you **where on the display** your app window is shown: fullscreen, one side of a split screen, a corner tile, or a floating window (optionally touching one edge or spanning the full width or height).

Flutter's `MediaQuery` gives you the window *size*, but in split screen it can't tell you whether you're on the left or the right. This plugin reads the window frame and the display bounds natively and classifies the placement.

## Usage

```dart
import 'package:window_placement/window_placement.dart';

final placement = WindowPlacementDetector();

// One-off
final info = await placement.getPlacement();
print(info.placement); // WindowPlacement.left

// Live updates (emits the current value first, then every change)
StreamBuilder<WindowPlacementInfo>(
  stream: placement.onPlacementChanged,
  builder: (context, snapshot) =>
      Text('Displayed: ${snapshot.data?.placement.name ?? 'unknown'}'),
);
```

`WindowPlacementInfo` also exposes the raw `windowBounds`, `screenBounds`, `screenInsets` (all in logical pixels), `isMultiWindow`, and whether the window touches each display edge: `touchesLeftEdge`, `touchesTopEdge`, `touchesRightEdge`, `touchesBottomEdge`.

## Positions

| Value | When |
|---|---|
| `fullscreen` | Window covers the whole display |
| `left` / `right` | Side-by-side split (iPad Split View, iPhone Duo split screen, Android landscape split) |
| `top` / `bottom` | Stacked split (Android, typically in portrait) |
| `topLeft` / `topRight` / `bottomLeft` / `bottomRight` | Quarter tiles (iPadOS windowing, Android desktop windowing) |
| `floatingLeft` / `floatingTop` / `floatingRight` / `floatingBottom` | Free window touching exactly one display edge, e.g. an iPadOS window snapped to the left edge |
| `floatingFullWidth` | Free window spanning the full width, touching neither top nor bottom |
| `floatingFullHeight` | Free window spanning the full height, touching neither left nor right |
| `floating` | Window touching no display edge (Stage Manager, Android freeform, PiP) |
| `unknown` | No window available yet |

### Platform notes

- **iPhone:** `fullscreen`, except on the iPhone Duo.
- **iPhone Duo:** the inner display supports side-by-side split screen, which reports `left` / `right`.
- **iPad:** classic Split View is always side by side, even in portrait, so you get `left` / `right`. Stage Manager and iPadOS windowing can produce any value.
  - Slide Over is a known limitation. If the overlay hugs the right edge, it may report `right`, because iOS has no public API to tell it apart from Split View.
- **Android:** phones in portrait and most tablets in portrait split `top` / `bottom`; landscape splits `left` / `right`. Freeform and desktop windows produce corners or `floating`.
  - A window that stops at the status bar or navigation bar still counts as touching that edge.

## How it works

1. **Native side measures.** Each platform reports the window's frame, the display's size and its system bar insets in logical pixels, in display coordinates. This goes over a typed [Pigeon](https://pub.dev/packages/pigeon) API (`WindowGeometry`), so Dart, Swift and Kotlin share one contract.
2. **Dart classifies.** `classifyWindowPlacement` checks which of the four display edges the window touches and maps that combination to a `WindowPlacement`. For example, left + top + bottom is `left`, and only left is `floatingLeft`. The same Dart code runs on both platforms, so they always agree.
3. **What "touching" means.** The window must be within 2 logical pixels of the edge (for rounding), plus any system bar on that side. Split, tiled and snapped windows sit exactly on the edge, so a free window parked next to an edge does not count.

### iOS (15+)

- **Measuring:** the window's bounds are converted to `screen.fixedCoordinateSpace`, then to `screen.coordinateSpace`, and compared with `screen.bounds`. Converting straight to `screen.coordinateSpace` returns scene-relative coordinates (origin always at zero) in split screen on iOS 27.
- **Watching for changes:**
  - On iOS 16+, the scene's `effectiveGeometry` is observed, so resizing, rotation and split changes are reported immediately.
  - While a listener is attached, the frame is also polled 4 times a second, because dragging an iPadOS window moves it without any public callback.
  - An event is sent only when the geometry actually changed.

### Android (API 24+)

- **Measuring:** `androidx.window`'s `WindowMetricsCalculator` compares the current window metrics with the maximum window metrics. System bar insets are passed along, so a window that stops at the status bar still touches the top edge.
- **Watching for changes:** decor view layout listeners.

## Development

The native API is defined in `pigeons/messages.dart`. After changing it, regenerate the Dart, Swift and Kotlin code:

```sh
dart run pigeon --input pigeons/messages.dart
```

The generated files (`*.g.dart`, `*.g.swift`, `*.g.kt`) are checked in. Don't edit them by hand.

### Releasing

1. On a branch, run `tool/release.sh prepare 1.2.3`. It sets the version in `pubspec.yaml` and the podspec and adds a `CHANGELOG.md` section. Replace its TODO with the changes, then open a PR and merge it.
2. On an up-to-date `main`, run `tool/release.sh tag`. It checks the versions and the CHANGELOG, runs `flutter pub publish --dry-run`, then asks before creating and pushing the `v1.2.3` tag.
3. The tag starts the *Publish to pub.dev* workflow. Approve it in the `pub.dev` environment to publish.

## License

MIT. See [LICENSE](LICENSE).
