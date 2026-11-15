import AppKit
import SceneKit
import XCTest

@testable import Something

final class MascotSceneBuilderTests: XCTestCase {
    func test_should_paint_head_material_with_new_head_color_after_recolor() throws {
        let newHeadColor = "#3366CC"
        let rig = MascotSceneBuilder.build(.default)
        let headIndex = try XCTUnwrap(
            MascotModel.default.parts.firstIndex { $0.color == MascotModel.defaultHeadColor })
        let recoloredModel = MascotModel.default.recolored(
            headColor: newHeadColor, bodyColor: MascotModel.defaultBodyColor)

        MascotSceneBuilder.applyColors(of: recoloredModel, to: rig)

        let headColor = try XCTUnwrap(rig.partMaterials[headIndex].diffuse.contents as? NSColor)
        XCTAssertEqual(MascotSceneBuilder.hex(of: headColor), newHeadColor)
    }

    func test_should_create_one_material_per_part() {
        let rig = MascotSceneBuilder.build(.default)

        XCTAssertEqual(rig.partMaterials.count, MascotModel.default.parts.count)
    }

    func test_should_format_display_p3_color_as_srgb_hex() throws {
        let srgbColor = NSColor(srgbRed: 0.2, green: 0.4, blue: 0.8, alpha: 1)
        let displayP3Color = try XCTUnwrap(srgbColor.usingColorSpace(.displayP3))

        XCTAssertEqual(MascotSceneBuilder.hex(of: displayP3Color), "#3366CC")
    }
}
