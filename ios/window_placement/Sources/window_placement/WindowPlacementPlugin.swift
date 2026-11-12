import Flutter
import UIKit

public class WindowPlacementPlugin: NSObject, FlutterPlugin, WindowPlacementHostApi {
  let host: FlutterHost
  let observer: WindowObserver
  let geometryChanges: GeometryChangesHandler
  let environmentChanges: EnvironmentChangesHandler

  public static func register(with registrar: FlutterPluginRegistrar) {
    let instance = WindowPlacementPlugin(host: FlutterHost(registrar: registrar))
    WindowPlacementHostApiSetup.setUp(binaryMessenger: registrar.messenger(), api: instance)
    GeometryChangesStreamHandler.register(
      with: registrar.messenger(), streamHandler: instance.geometryChanges)
    EnvironmentChangesStreamHandler.register(
      with: registrar.messenger(), streamHandler: instance.environmentChanges)
  }

  init(host: FlutterHost) {
    self.host = host
    // Both streams share one observer, which runs while either has a listener.
    observer = WindowObserver(host: host)
    geometryChanges = GeometryChangesHandler(observer: observer) { host.legacyGeometry() }
    environmentChanges = EnvironmentChangesHandler(observer: observer) { host.environment() }
    super.init()
    observer.onChange = { [weak self] in
      self?.geometryChanges.emitIfChanged()
      self?.environmentChanges.emitIfChanged()
    }
  }

  override convenience init() {
    self.init(host: FlutterHost())
  }

  func getGeometry() throws -> WindowGeometry? {
    host.legacyGeometry()
  }

  func getEnvironment() throws -> WindowSnapshot {
    host.environment()
  }

  func getBarRegion(edge: BarEdge, extent: Double) throws -> BarRegion? {
    barRegion(in: host.legacyFlutterView(), edge: edge, extent: CGFloat(extent))
  }
}

// MARK: - Host

// The view controller showing this engine's Flutter view, and the window it is in. Reading
// geometry and traits from it keeps them on the same window, also when other scenes show other
// engines.
final class FlutterHost {
  private let viewControllerProvider: (() -> UIViewController?)?

  init(viewController: (() -> UIViewController?)? = nil) {
    viewControllerProvider = viewController
  }

  convenience init(registrar: FlutterPluginRegistrar) {
    self.init { registrar.viewController }
  }

  var viewController: UIViewController? { viewControllerProvider?() }

  // Nil while the Flutter view is not in a window.
  var window: UIWindow? { viewController?.viewIfLoaded?.window }

  // Without a Flutter view (a headless engine, or the plugin made outside `register`),
  // getGeometry, geometryChanges and getBarRegion read the foreground window as before.
  var legacyWindow: UIWindow? { viewController == nil ? activeWindow() : window }

  func environment() -> WindowSnapshot {
    guard let controller = viewController, let window = controller.viewIfLoaded?.window,
      let geometry = windowGeometry(of: window)
    else { return WindowSnapshot() }
    return WindowSnapshot(geometry: geometry, traits: traits(of: controller.traitCollection))
  }

  func legacyGeometry() -> WindowGeometry? {
    legacyWindow.flatMap(windowGeometry(of:))
  }

  func legacyFlutterView() -> UIView? {
    if let controller = viewController { return controller.viewIfLoaded }
    return foregroundFlutterView()
  }
}

// MARK: - Observing

// Calls `onChange` when the host window may have changed: right away for resizing, rotation and
// (on iOS 17+) trait changes, and by polling for everything else.
final class WindowObserver {
  var onChange: () -> Void = {}
  private let host: FlutterHost
  private var listeners = 0
  private var pollTimer: Timer?
  private weak var observedScene: UIWindowScene?
  private var geometryObservation: NSKeyValueObservation?
  private weak var traitController: UIViewController?
  private var traitRegistration: Any?

  init(host: FlutterHost) {
    self.host = host
  }

  var isRunning: Bool { pollTimer != nil }

  func start() {
    listeners += 1
    guard listeners == 1 else { return }
    // Dragging an iPadOS window moves it without resizing, and UIKit has no public callback
    // for that, so poll. This also catches trait changes before iOS 17 and the view leaving its
    // window. The streams emit only when something changed.
    let timer = Timer(timeInterval: 0.25, repeats: true) { [weak self] _ in self?.refresh() }
    RunLoop.main.add(timer, forMode: .common)
    pollTimer = timer
    observeHost()
  }

  func stop() {
    guard listeners > 0 else { return }
    listeners -= 1
    guard listeners == 0 else { return }
    pollTimer?.invalidate()
    pollTimer = nil
    geometryObservation = nil
    observedScene = nil
    observeTraits(of: nil)
  }

  func refresh() {
    observeHost()
    onChange()
  }

  // Follows the host into another scene or view controller.
  private func observeHost() {
    observeScene(host.legacyWindow?.windowScene)
    observeTraits(of: host.viewController)
  }

  // Resizing, rotation and split changes update effectiveGeometry. Observing it reports them
  // right away instead of on the next poll.
  private func observeScene(_ scene: UIWindowScene?) {
    guard #available(iOS 16.0, *), scene !== observedScene else { return }
    observedScene = scene
    geometryObservation = scene?.observe(\.effectiveGeometry) { [weak self] _, _ in
      DispatchQueue.main.async { self?.onChange() }
    }
  }

  // Always called on the main thread: from the platform channels, the timer on the main run
  // loop, or the main queue.
  private func observeTraits(of controller: UIViewController?) {
    guard #available(iOS 17.0, *), controller !== traitController else { return }
    MainActor.assumeIsolated { replaceTraitRegistration(with: controller) }
  }

  @available(iOS 17.0, *)
  @MainActor
  private func replaceTraitRegistration(with controller: UIViewController?) {
    if let registration = traitRegistration as? UITraitChangeRegistration {
      traitController?.unregisterForTraitChanges(registration)
    }
    traitController = controller
    traitRegistration = controller?.registerForTraitChanges([
      UITraitHorizontalSizeClass.self, UITraitVerticalSizeClass.self,
      UITraitUserInterfaceIdiom.self,
    ]) { [weak self] (_: UIViewController, _: UITraitCollection) in
      DispatchQueue.main.async { self?.onChange() }
    }
  }
}

// One stream's sink: sends the value on listen, then only when it changed.
final class ChangeSink<Value: Equatable> {
  private let observer: WindowObserver
  private let read: () -> Value?
  private var sink: PigeonEventSink<Value>?
  private var last: Value?

  init(observer: WindowObserver, read: @escaping () -> Value?) {
    self.observer = observer
    self.read = read
  }

  func listen(_ sink: PigeonEventSink<Value>) {
    if self.sink == nil { observer.start() }
    self.sink = sink
    last = nil
    emitIfChanged()
  }

  func cancel() {
    guard sink != nil else { return }
    sink = nil
    observer.stop()
  }

  func emitIfChanged() {
    guard let sink = sink, let value = read(), value != last else { return }
    last = value
    sink.success(value)
  }
}

// Compares the geometry only, so trait-only changes send nothing here.
final class GeometryChangesHandler: GeometryChangesStreamHandler {
  private let changes: ChangeSink<WindowGeometry>

  init(observer: WindowObserver, read: @escaping () -> WindowGeometry?) {
    changes = ChangeSink(observer: observer, read: read)
  }

  override func onListen(withArguments arguments: Any?, sink: PigeonEventSink<WindowGeometry>) {
    changes.listen(sink)
  }

  override func onCancel(withArguments arguments: Any?) {
    changes.cancel()
  }

  func emitIfChanged() {
    changes.emitIfChanged()
  }
}

final class EnvironmentChangesHandler: EnvironmentChangesStreamHandler {
  private let changes: ChangeSink<WindowSnapshot>

  init(observer: WindowObserver, read: @escaping () -> WindowSnapshot) {
    changes = ChangeSink(observer: observer, read: read)
  }

  override func onListen(withArguments arguments: Any?, sink: PigeonEventSink<WindowSnapshot>) {
    changes.listen(sink)
  }

  override func onCancel(withArguments arguments: Any?) {
    changes.cancel()
  }

  func emitIfChanged() {
    changes.emitIfChanged()
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

private func windowGeometry(of window: UIWindow) -> WindowGeometry? {
  guard let screen = window.windowScene?.screen else { return nil }
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

// MARK: - Traits

private func traits(of collection: UITraitCollection) -> WindowTraits {
  WindowTraits(
    horizontalSizeClass: sizeClass(collection.horizontalSizeClass),
    verticalSizeClass: sizeClass(collection.verticalSizeClass),
    interfaceIdiom: interfaceIdiom(collection.userInterfaceIdiom))
}

private func sizeClass(_ sizeClass: UIUserInterfaceSizeClass) -> SizeClass {
  switch sizeClass {
  case .compact: return .compact
  case .regular: return .regular
  default: return .unspecified
  }
}

// Mac, CarPlay, TV, vision and idioms added later are `other`, not a tablet.
private func interfaceIdiom(_ idiom: UIUserInterfaceIdiom) -> InterfaceIdiom {
  switch idiom {
  case .phone: return .phone
  case .pad: return .pad
  case .unspecified: return .unspecified
  default: return .other
  }
}

// MARK: - Bar regions

// The view Flutter draws into in the foreground window, whose coordinates match Flutter's
// logical pixels. Only for when the plugin has no Flutter view of its own.
private func foregroundFlutterView() -> UIView? {
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
private func barRegion(in view: UIView?, edge: BarEdge, extent: CGFloat) -> BarRegion? {
  guard #available(iOS 27.1, *), extent > 0, let view = view else { return nil }
  let rectEdge: UIRectEdge
  switch edge {
  case .left: rectEdge = .left
  case .top: rectEdge = .top
  case .right: rectEdge = .right
  case .bottom: rectEdge = .bottom
  }
  guard let guide = barLayoutGuide(in: view, edge: rectEdge, extent: extent) else { return nil }
  view.layoutIfNeeded()
  let frame = guide.layoutFrame
  return BarRegion(x: frame.minX, y: frame.minY, width: frame.width, height: frame.height)
}

// `view.layoutGuide(for: .bar(onEdge:extent:))`, called through the Objective-C runtime:
// apps built with an SDK before iOS 27.1 (Xcode 26) don't know `bar(onEdge:extent:)`, and
// `#available` only guards the call at run time, not the compile. Nil where the method is
// missing.
private func barLayoutGuide(in view: UIView, edge: UIRectEdge, extent: CGFloat) -> UILayoutGuide? {
  let regionSelector = NSSelectorFromString("layoutRegionForBarOnEdge:extent:")
  let guideSelector = NSSelectorFromString("layoutGuideForLayoutRegion:")
  guard let regionClass = NSClassFromString("UIViewLayoutRegion"),
    let method = class_getClassMethod(regionClass, regionSelector),
    view.responds(to: guideSelector)
  else { return nil }
  typealias MakeRegion = @convention(c) (AnyClass, Selector, UInt, CGFloat) -> AnyObject?
  let makeRegion = unsafeBitCast(method_getImplementation(method), to: MakeRegion.self)
  guard let region = makeRegion(regionClass, regionSelector, edge.rawValue, extent) else {
    return nil
  }
  return view.perform(guideSelector, with: region)?.takeUnretainedValue() as? UILayoutGuide
}
