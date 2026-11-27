import XCTest

@testable import Something

final class LauncherScreenLayoutTests: XCTestCase {
    // A primary screen and a second one to its right, a little higher.
    private let screenFrames = [
        CGRect(x: 0, y: 0, width: 1440, height: 900),
        CGRect(x: 1440, y: 100, width: 1920, height: 1080),
    ]

    func test_should_pick_the_screen_under_the_point() {
        let index = LauncherScreenLayout.screenIndex(
            containing: CGPoint(x: 2000, y: 500),
            screenFrames: screenFrames
        )

        XCTAssertEqual(index, 1)
    }

    func test_should_count_the_top_edge_of_a_screen() {
        let index = LauncherScreenLayout.screenIndex(
            containing: CGPoint(x: 100, y: 900),
            screenFrames: screenFrames
        )

        XCTAssertEqual(index, 0)
    }

    func test_should_pick_no_screen_for_a_point_outside_every_screen() {
        let index = LauncherScreenLayout.screenIndex(
            containing: CGPoint(x: 100, y: 2000),
            screenFrames: screenFrames
        )

        XCTAssertNil(index)
    }

    func test_should_pick_the_screen_that_holds_most_of_a_spanning_window() {
        let window = CGRect(x: 1300, y: 200, width: 600, height: 400)

        let index = LauncherScreenLayout.screenIndex(
            mostOverlapping: window,
            screenFrames: screenFrames
        )

        XCTAssertEqual(index, 1)
    }

    func test_should_pick_no_screen_for_a_window_off_every_screen() {
        let window = CGRect(x: -900, y: 0, width: 600, height: 400)

        let index = LauncherScreenLayout.screenIndex(
            mostOverlapping: window,
            screenFrames: screenFrames
        )

        XCTAssertNil(index)
    }

    func test_should_flip_window_list_bounds_to_appkit_coordinates() {
        let bounds = CGRect(x: 10, y: 20, width: 300, height: 200)

        let rect = LauncherScreenLayout.appKitRect(
            fromWindowListBounds: bounds,
            primaryScreenHeight: 900
        )

        XCTAssertEqual(rect, CGRect(x: 10, y: 680, width: 300, height: 200))
    }

    func test_should_center_the_frame_horizontally_and_above_the_middle() {
        let visibleFrame = CGRect(x: 1440, y: 100, width: 1920, height: 1050)

        let frame = LauncherScreenLayout.frame(
            size: CGSize(width: 720, height: 450),
            centeredIn: visibleFrame
        )

        XCTAssertEqual(frame, CGRect(x: 2040, y: 500, width: 720, height: 450))
    }

    func test_should_shrink_a_frame_larger_than_the_screen() {
        let visibleFrame = CGRect(x: 0, y: 0, width: 800, height: 600)

        let frame = LauncherScreenLayout.frame(
            size: CGSize(width: 1000, height: 700),
            centeredIn: visibleFrame
        )

        XCTAssertEqual(frame, visibleFrame)
    }
}
