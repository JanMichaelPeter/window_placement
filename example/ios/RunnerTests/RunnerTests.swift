import Flutter
import XCTest

@testable import window_placement

class RunnerTests: XCTestCase {
  private var window: UIWindow!
  private var host: UIViewController!
  private var plugin: WindowPlacementPlugin!

  override func setUpWithError() throws {
    let scene = try XCTUnwrap(
      UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first)
    // A small window next to the app's full-screen key window: the plugin must measure this
    // one, where its host is, not the foreground one.
    window = UIWindow(windowScene: scene)
    window.frame = CGRect(x: 10, y: 20, width: 200, height: 300)
    host = UIViewController()
    window.rootViewController = host
    window.isHidden = false
    plugin = WindowPlacementPlugin(host: FlutterHost { [unowned self] in self.host })
  }

  override func tearDown() {
    plugin.geometryChanges.onCancel(withArguments: nil)
    plugin.environmentChanges.onCancel(withArguments: nil)
    window.isHidden = true
    window = nil
  }

  func testGetGeometryReturnsWindowAndScreenSize() throws {
    let geometry = try XCTUnwrap(WindowPlacementPlugin().getGeometry())
    XCTAssertGreaterThan(geometry.windowWidth, 0)
    XCTAssertGreaterThan(geometry.screenWidth, 0)
  }

  func testEnvironmentReadsTheHostWindow() throws {
    let environment = try plugin.getEnvironment()
    let geometry = try XCTUnwrap(environment.geometry)
    XCTAssertEqual(geometry.windowX, 10)
    XCTAssertEqual(geometry.windowY, 20)
    XCTAssertEqual(geometry.windowWidth, 200)
    XCTAssertEqual(geometry.windowHeight, 300)
    XCTAssertTrue(geometry.isMultiWindow)
    let traits = try XCTUnwrap(environment.traits)
    XCTAssertEqual(traits.interfaceIdiom, UIDevice.current.userInterfaceIdiom == .pad ? .pad : .phone)
    XCTAssertEqual(try plugin.getGeometry(), geometry)
  }

  func testEnvironmentWithoutWindowIsUnavailable() throws {
    window.rootViewController = nil
    XCTAssertEqual(try plugin.getEnvironment(), WindowSnapshot())
    // The legacy API doesn't fall back to another window while it has a host.
    XCTAssertNil(try plugin.getGeometry())
  }

  func testEnvironmentStreamFollowsDetachAndReattach() {
    var snapshots: [WindowSnapshot] = []
    plugin.environmentChanges.onListen(
      withArguments: nil, sink: PigeonEventSink { snapshots.append($0 as! WindowSnapshot) })
    XCTAssertEqual(snapshots.count, 1)
    XCTAssertNotNil(snapshots.last?.geometry)

    window.rootViewController = nil
    plugin.observer.refresh()
    XCTAssertEqual(snapshots.last, WindowSnapshot())

    plugin.observer.refresh()
    XCTAssertEqual(snapshots.count, 2, "unchanged snapshots are not sent again")

    window.rootViewController = host
    plugin.observer.refresh()
    XCTAssertEqual(snapshots.count, 3)
    XCTAssertEqual(snapshots.last?.geometry?.windowWidth, 200)
  }

  func testTraitOnlyChangeReachesOnlyTheEnvironmentStream() throws {
    guard #available(iOS 17.0, *) else { throw XCTSkip("needs traitOverrides") }
    var geometries: [WindowGeometry] = []
    var snapshots: [WindowSnapshot] = []
    plugin.geometryChanges.onListen(
      withArguments: nil, sink: PigeonEventSink { geometries.append($0 as! WindowGeometry) })
    plugin.environmentChanges.onListen(
      withArguments: nil, sink: PigeonEventSink { snapshots.append($0 as! WindowSnapshot) })

    let flipped: UIUserInterfaceSizeClass =
      host.traitCollection.horizontalSizeClass == .compact ? .regular : .compact
    host.traitOverrides.horizontalSizeClass = flipped
    host.updateTraitsIfNeeded()
    plugin.observer.refresh()

    XCTAssertEqual(geometries.count, 1)
    XCTAssertEqual(snapshots.count, 2)
    XCTAssertEqual(snapshots[0].geometry, snapshots[1].geometry)
    XCTAssertEqual(snapshots[1].traits?.horizontalSizeClass, flipped == .compact ? .compact : .regular)
  }

  func testObserverRunsWhileEitherStreamListens() {
    plugin.geometryChanges.onListen(withArguments: nil, sink: PigeonEventSink { _ in })
    plugin.environmentChanges.onListen(withArguments: nil, sink: PigeonEventSink { _ in })
    XCTAssertTrue(plugin.observer.isRunning)

    plugin.geometryChanges.onCancel(withArguments: nil)
    XCTAssertTrue(plugin.observer.isRunning)

    plugin.environmentChanges.onCancel(withArguments: nil)
    XCTAssertFalse(plugin.observer.isRunning)

    // Listening again starts over and sends the current value.
    var snapshots: [WindowSnapshot] = []
    plugin.environmentChanges.onListen(
      withArguments: nil, sink: PigeonEventSink { snapshots.append($0 as! WindowSnapshot) })
    XCTAssertTrue(plugin.observer.isRunning)
    XCTAssertEqual(snapshots.count, 1)
  }
}
