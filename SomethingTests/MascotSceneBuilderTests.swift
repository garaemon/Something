import AppKit
import SceneKit
import XCTest

@testable import Something

final class MascotSceneBuilderTests: XCTestCase {
    func test_should_paint_head_material_with_new_head_color_after_recolor() throws {
        let rig = MascotSceneBuilder.build(.default)
        let recoloredModel = MascotModel.default.recolored(
            headColor: "#3366CC", bodyColor: MascotModel.defaultBodyColor)

        MascotSceneBuilder.applyColors(of: recoloredModel, to: rig)

        let headIndex = try XCTUnwrap(recoloredModel.parts.firstIndex { $0.color == "#3366CC" })
        let headColor = try XCTUnwrap(rig.partMaterials[headIndex].diffuse.contents as? NSColor)
        XCTAssertEqual(MascotSceneBuilderTests.hex(of: headColor), "#3366CC")
    }

    func test_should_create_one_material_per_part() {
        let rig = MascotSceneBuilder.build(.default)

        XCTAssertEqual(rig.partMaterials.count, MascotModel.default.parts.count)
    }

    private static func hex(of color: NSColor) -> String? {
        guard let srgbColor = color.usingColorSpace(.sRGB) else { return nil }
        return MascotModel.hex(
            red: srgbColor.redComponent, green: srgbColor.greenComponent, blue: srgbColor.blueComponent)
    }
}
