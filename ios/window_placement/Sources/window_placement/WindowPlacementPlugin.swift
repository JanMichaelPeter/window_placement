import Flutter
import UIKit

public class WindowPlacementPlugin: NSObject, FlutterPlugin, WindowPlacementHostApi {
  private let geometryChanges = GeometryChangesHandler()

  public static func register(with registrar: FlutterPluginRegistrar) {
    let instance = WindowPlacementPlugin()
    WindowPlacementHostApiSetup.setUp(binaryMessenger: registrar.messenger(), api: instance)
    GeometryChangesStreamHandler.register(
      with: registrar.messenger(), streamHandler: instance.geometryChanges)
  }

  func getGeometry() throws -> WindowGeometry? {
    currentGeometry()
  }

  func getBarRegion(edge: BarEdge, extent: Double) throws -> BarRegion? {
    barRegion(edge: edge, extent: CGFloat(extent))
  }
}

private class GeometryChangesHandler: GeometryChangesStreamHandler {
  private var sink: PigeonEventSink<WindowGeometry>?
  private var lastGeometry: WindowGeometry?
  private var pollTimer: Timer?
  private weak var observedScene: UIWindowScene?
  private var geometryObservation: NSKeyValueObservation?

  override func onListen(withArguments arguments: Any?, sink: PigeonEventSink<WindowGeometry>) {
    self.sink = sink
    lastGeometry = nil
    update()

    // Dragging an iPadOS window moves it without resizing, and UIKit has no public callback
    // for that, so poll. Emits only when something changed.
    pollTimer?.invalidate()
    let timer = Timer(timeInterval: 0.25, repeats: true) { [weak self] _ in self?.update() }
    RunLoop.main.add(timer, forMode: .common)
    pollTimer = timer
  }

  override func onCancel(withArguments arguments: Any?) {
    sink = nil
    pollTimer?.invalidate()
    pollTimer = nil
    geometryObservation = nil
    observedScene = nil
  }

  private func update() {
    observeActiveScene()
    emitIfChanged()
  }

  private func emitIfChanged() {
    guard let sink = sink, let geometry = currentGeometry(), geometry != lastGeometry else { return }
    lastGeometry = geometry
    sink.success(geometry)
  }

  // Resizing, rotation and split changes update effectiveGeometry. Observing it reports them
  // right away instead of on the next poll.
  private func observeActiveScene() {
    guard #available(iOS 16.0, *), let scene = activeWindow()?.windowScene, scene !== observedScene
    else { return }
    observedScene = scene
    geometryObservation = scene.observe(\.effectiveGeometry) { [weak self] _, _ in
      DispatchQueue.main.async { self?.emitIfChanged() }
    }
  }
}

// MARK: - Geometry

private func activeWindow() -> UIWindow? {
  let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
  let scene = scenes.first { $0.activationState == .foregroundActive }
    ?? scenes.first { $0.activationState == .foregroundInactive }
    ?? scenes.first
  guard let scene = scene else { return nil }
  return scene.windows.first { $0.isKeyWindow } ?? scene.windows.first
}

private func currentGeometry() -> WindowGeometry? {
  guard let window = activeWindow(), let screen = window.windowScene?.screen else { return nil }
  // Go through the fixed (portrait) space: in split screen on iOS 27, converting straight to
  // screen.coordinateSpace yields scene-relative coordinates with the origin always at zero.
  let fixedFrame = window.convert(window.bounds, to: screen.fixedCoordinateSpace)
  let frame = screen.fixedCoordinateSpace.convert(fixedFrame, to: screen.coordinateSpace)
  let screenBounds = screen.bounds
  return WindowGeometry(
    windowX: frame.origin.x,
    windowY: frame.origin.y,
    windowWidth: frame.width,
    windowHeight: frame.height,
    screenWidth: screenBounds.width,
    screenHeight: screenBounds.height,
    screenInsetLeft: 0,
    screenInsetTop: 0,
    screenInsetRight: 0,
    screenInsetBottom: 0,
    isMultiWindow: frame.size != screenBounds.size
  )
}

// MARK: - Bar regions

// The view Flutter draws into, whose coordinates match Flutter's logical pixels.
private func flutterView() -> UIView? {
  guard let root = activeWindow()?.rootViewController else { return nil }
  var stack = [root]
  while let vc = stack.popLast() {
    if vc is FlutterViewController { return vc.view }
    stack.append(contentsOf: vc.children)
    if let presented = vc.presentedViewController { stack.append(presented) }
  }
  return root.view
}

// UIKit's bar layout region (iOS 27.1): where a bar of this thickness fits along the edge,
// clear of the status icons (a column at the side or a band at the top, depending on the
// device and orientation), the corners and the home indicator.
private func barRegion(edge: BarEdge, extent: CGFloat) -> BarRegion? {
  guard #available(iOS 27.1, *), extent > 0, let view = flutterView() else { return nil }
  let rectEdge: UIRectEdge
  switch edge {
  case .left: rectEdge = .left
  case .top: rectEdge = .top
  case .right: rectEdge = .right
  case .bottom: rectEdge = .bottom
  }
  let guide = view.layoutGuide(for: .bar(onEdge: rectEdge, extent: extent))
  view.layoutIfNeeded()
  let frame = guide.layoutFrame
  return BarRegion(x: frame.minX, y: frame.minY, width: frame.width, height: frame.height)
}
