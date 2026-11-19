import HotKey
import XCTest

@testable import Something

final class ModifierSidesTests: XCTestCase {
    func test_should_not_be_sided_by_default() {
        XCTAssertFalse(ModifierSides().isSided)
    }

    func test_should_be_sided_when_one_modifier_has_a_side() {
        XCTAssertTrue(ModifierSides(shift: .right).isSided)
    }

    func test_should_read_held_sides_from_device_bits() {
        let sides = ModifierSides.readHeldSides(fromFlags: 
            ModifierFlagBits.rightShiftHeld | ModifierFlagBits.leftCommandHeld)

        XCTAssertEqual(sides, ModifierSides(command: .left, shift: .right))
    }

    func test_should_read_either_when_both_sides_are_held() {
        let sides = ModifierSides.readHeldSides(fromFlags: 
            ModifierFlagBits.rightShiftHeld | ModifierFlagBits.leftShiftHeld)

        XCTAssertEqual(sides, ModifierSides())
    }
}
