import XCTest

@testable import Something

final class MascotPanelLayoutTests: XCTestCase {
    private let launcher = CGRect(x: 100, y: 200, width: 600, height: 400)

    func test_should_use_a_220_point_square_panel() {
        let frame = MascotPanelLayout.frame(forLauncherFrame: launcher)

        XCTAssertEqual(frame.size, CGSize(width: 220, height: 220))
    }

    func test_should_inset_the_panel_24_points_from_the_launcher_right_edge() {
        let frame = MascotPanelLayout.frame(forLauncherFrame: launcher)

        XCTAssertEqual(frame.maxX, launcher.maxX - 24, accuracy: 0.001)
    }

    func test_should_put_the_ground_line_on_the_launcher_top_edge() {
        let frame = MascotPanelLayout.frame(forLauncherFrame: launcher)

        XCTAssertEqual(frame.minY + 0.03 * frame.height, launcher.maxY, accuracy: 0.001)
    }

    func test_should_follow_a_resized_launcher() {
        let resized = CGRect(x: 100, y: 200, width: 800, height: 500)

        let frame = MascotPanelLayout.frame(forLauncherFrame: resized)

        XCTAssertEqual(frame.maxX, 800 + 100 - 24, accuracy: 0.001)
        XCTAssertEqual(frame.minY, 700 - 6.6, accuracy: 0.001)
    }

    func test_should_aim_the_camera_so_the_origin_lands_on_the_ground_line() {
        let height = 2.9
        let distance = 7.6
        let fov = 24.0
        let pitch = MascotPanelLayout.cameraPitch(
            cameraHeight: height, cameraDistance: distance, verticalFieldOfViewDegrees: fov)

        // Project the origin: its angle below the view axis against the half field of view.
        let belowAxis = atan2(height, distance) - pitch
        let ndcY = -tan(belowAxis) / tan(fov * Double.pi / 360)
        let fractionFromBottom = (ndcY + 1) / 2

        XCTAssertEqual(fractionFromBottom, MascotPanelLayout.groundLineFraction, accuracy: 0.0001)
        XCTAssertGreaterThan(pitch, 0)
    }
}
