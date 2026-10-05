import Flutter
import XCTest

@testable import window_placement

class RunnerTests: XCTestCase {
  func testGetGeometryReturnsWindowAndScreenSize() throws {
    let geometry = try XCTUnwrap(WindowPlacementPlugin().getGeometry())
    XCTAssertGreaterThan(geometry.windowWidth, 0)
    XCTAssertGreaterThan(geometry.screenWidth, 0)
  }
}
