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

        XCTAssertEqual(fractionFromBottom, MascotPlacement.top.groundLineFraction, accuracy: 0.0001)
        XCTAssertGreaterThan(pitch, 0)
    }

    func test_should_put_the_right_panel_overlapping_the_launcher_with_ground_line_at_its_bottom_edge() {
        let frame = MascotPanelLayout.frame(forLauncherFrame: launcher, placement: .right)

        XCTAssertEqual(frame.minX, launcher.maxX - 30, accuracy: 0.001)
        XCTAssertEqual(frame.minY + 0.21 * frame.height, launcher.minY, accuracy: 0.001)
        XCTAssertEqual(frame.size, CGSize(width: 220, height: 220))
    }

    func test_should_put_the_left_panel_overlapping_the_launcher_with_ground_line_at_its_bottom_edge() {
        let frame = MascotPanelLayout.frame(forLauncherFrame: launcher, placement: .left)

        XCTAssertEqual(frame.maxX, launcher.minX + 30, accuracy: 0.001)
        XCTAssertEqual(frame.minY + 0.21 * frame.height, launcher.minY, accuracy: 0.001)
    }

    func test_should_use_a_higher_ground_line_beside_the_launcher() {
        XCTAssertEqual(MascotPlacement.top.groundLineFraction, 0.03, accuracy: 0.0001)
        XCTAssertEqual(MascotPlacement.left.groundLineFraction, 0.21, accuracy: 0.0001)
        XCTAssertEqual(MascotPlacement.right.groundLineFraction, 0.21, accuracy: 0.0001)
    }

    func test_should_aim_the_camera_per_placement() {
        for placement in MascotPlacement.allCases {
            let pitch = MascotPanelLayout.cameraPitch(
                cameraHeight: 2.9, cameraDistance: 7.6, verticalFieldOfViewDegrees: 24, placement: placement)
            let ndcY = -tan(atan2(2.9, 7.6) - pitch) / tan(24 * Double.pi / 360)

            XCTAssertEqual((ndcY + 1) / 2, placement.groundLineFraction, accuracy: 0.0001)
        }
    }

    func test_should_show_a_ground_shadow_only_beside_the_launcher() {
        XCTAssertFalse(MascotPlacement.top.showsGroundShadow)
        XCTAssertTrue(MascotPlacement.left.showsGroundShadow)
        XCTAssertTrue(MascotPlacement.right.showsGroundShadow)
    }

    func test_should_offer_every_placement_when_all_fit() {
        let screen = CGRect(x: 0, y: 0, width: 2000, height: 1200)
        let centered = CGRect(x: 700, y: 300, width: 600, height: 400)

        XCTAssertEqual(
            Set(MascotPanelLayout.placements(fittingLauncherFrame: centered, within: screen)),
            Set(MascotPlacement.allCases))
    }

    func test_should_exclude_right_when_launcher_is_at_the_right_screen_edge() {
        let screen = CGRect(x: 0, y: 0, width: 2000, height: 1200)
        let atRightEdge = CGRect(x: 1400, y: 300, width: 600, height: 400)

        let placements = MascotPanelLayout.placements(fittingLauncherFrame: atRightEdge, within: screen)

        XCTAssertFalse(placements.contains(.right))
        XCTAssertTrue(placements.contains(.left))
        XCTAssertTrue(placements.contains(.top))
    }

    func test_should_exclude_top_when_launcher_is_at_the_top_of_the_screen() {
        let screen = CGRect(x: 0, y: 0, width: 2000, height: 1200)
        let atTop = CGRect(x: 700, y: 800, width: 600, height: 400)

        let placements = MascotPanelLayout.placements(fittingLauncherFrame: atTop, within: screen)

        XCTAssertFalse(placements.contains(.top))
        XCTAssertTrue(placements.contains(.left))
    }

    func test_should_offer_every_placement_when_none_fits() {
        let screen = CGRect(x: 0, y: 0, width: 600, height: 400)

        XCTAssertEqual(
            Set(MascotPanelLayout.placements(fittingLauncherFrame: screen, within: screen)),
            Set(MascotPlacement.allCases))
    }
}
