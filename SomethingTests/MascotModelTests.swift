import XCTest

@testable import Something

final class MascotModelTests: XCTestCase {
    func test_should_paint_head_parts_with_new_head_color() {
        let model = MascotModel.default.recolored(
            headColor: "#3366CC", bodyColor: MascotModel.defaultBodyColor)

        let headBoxColors = model.parts.filter { $0.group == .head }.map(\.color)

        XCTAssertTrue(headBoxColors.contains("#3366CC"))
    }

    func test_should_leave_no_part_with_old_head_color() {
        let model = MascotModel.default.recolored(
            headColor: "#3366CC", bodyColor: MascotModel.defaultBodyColor)

        XCTAssertFalse(model.parts.contains { $0.color == MascotModel.defaultHeadColor })
    }

    func test_should_leave_no_part_with_old_body_color() {
        let model = MascotModel.default.recolored(
            headColor: MascotModel.defaultHeadColor, bodyColor: "#112233")

        XCTAssertFalse(model.parts.contains { $0.color == MascotModel.defaultBodyColor })
    }

    // The wheels and the screen are not part of the skin colors.
    func test_should_keep_wheel_color() {
        let model = MascotModel.default.recolored(headColor: "#000000", bodyColor: "#000000")

        let wheelColors = model.parts.filter { $0.shape == .cylinder(radius: 0.2, height: 0.14, axis: .x) }
            .map(\.color)

        XCTAssertEqual(Set(wheelColors), ["#3A2E1F"])
    }

    func test_should_equal_default_when_recolored_with_default_colors() {
        let model = MascotModel.default.recolored(
            headColor: MascotModel.defaultHeadColor, bodyColor: MascotModel.defaultBodyColor)

        XCTAssertEqual(model, MascotModel.default)
    }
}

final class MascotColorTests: XCTestCase {
    func test_should_format_components_as_uppercase_hex() {
        let hex = MascotModel.hex(red: 0.2, green: 0.4, blue: 0.8)

        XCTAssertEqual(hex, "#3366CC")
    }

    func test_should_clamp_components_outside_unit_range() {
        let hex = MascotModel.hex(red: -0.5, green: 1.5, blue: 0)

        XCTAssertEqual(hex, "#00FF00")
    }
}
