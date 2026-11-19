import AppKit
import CoreGraphics
import HotKey

/// Which physical key of a modifier a hot key needs.
enum ModifierSide: String, Codable {
    case either
    case left
    case right
}

/// The side that each modifier of a hot key needs. A modifier that the key
/// combination does not hold ignores its side.
struct ModifierSides: Equatable, Codable {
    var command: ModifierSide = .either
    var option: ModifierSide = .either
    var control: ModifierSide = .either
    var shift: ModifierSide = .either

    /// True when a modifier needs one side, so that Carbon cannot register the
    /// hot key and the event tap must watch for it.
    var isSided: Bool {
        [command, option, control, shift].contains { $0 != .either }
    }

    /// Returns the side for one of Command, Option, Control, or Shift. Any other
    /// flag reads as Shift, because the callers only pass those four.
    func side(of modifier: NSEvent.ModifierFlags) -> ModifierSide {
        switch modifier {
        case .command: return command
        case .option: return option
        case .control: return control
        default: return shift
        }
    }

    /// Returns these sides with every modifier outside `modifiers` reset to either.
    func restricted(to modifiers: NSEvent.ModifierFlags) -> ModifierSides {
        ModifierSides(
            command: modifiers.contains(.command) ? command : .either,
            option: modifiers.contains(.option) ? option : .either,
            control: modifiers.contains(.control) ? control : .either,
            shift: modifiers.contains(.shift) ? shift : .either
        )
    }

    /// Reads the side of each modifier that `flags` holds. A modifier with both
    /// sides held, or with no device bit (a synthetic event), stays `.either`.
    static func fromHeldFlags(_ flags: UInt64) -> ModifierSides {
        func readSide(_ modifier: ModifierFlagBits.Modifier) -> ModifierSide {
            let isLeftHeld = flags & modifier.leftBit != 0
            let isRightHeld = flags & modifier.rightBit != 0
            if isLeftHeld && !isRightHeld { return .left }
            if isRightHeld && !isLeftHeld { return .right }
            return .either
        }
        return ModifierSides(
            command: readSide(ModifierFlagBits.commandKey),
            option: readSide(ModifierFlagBits.optionKey),
            control: readSide(ModifierFlagBits.controlKey),
            shift: readSide(ModifierFlagBits.shiftKey)
        )
    }
}

/// Bits of `CGEventFlags` and of the device-dependent part of
/// `NSEvent.modifierFlags`. The device-dependent bits come from IOKit's
/// `NX_DEVICE*KEYMASK` and tell the left key from the right one.
enum ModifierFlagBits {
    struct Modifier {
        let genericBit: UInt64
        let leftBit: UInt64
        let rightBit: UInt64
    }

    static let genericShift = CGEventFlags.maskShift.rawValue
    static let capsLock = CGEventFlags.maskAlphaShift.rawValue
    static let function = CGEventFlags.maskSecondaryFn.rawValue

    static let leftControlHeld: UInt64 = 0x1
    static let leftShiftHeld: UInt64 = 0x2
    static let rightShiftHeld: UInt64 = 0x4
    static let leftCommandHeld: UInt64 = 0x8
    static let rightCommandHeld: UInt64 = 0x10
    static let leftOptionHeld: UInt64 = 0x20
    static let rightOptionHeld: UInt64 = 0x40
    static let rightControlHeld: UInt64 = 0x2000

    static let shiftKey = Modifier(
        genericBit: genericShift,
        leftBit: leftShiftHeld,
        rightBit: rightShiftHeld
    )
    static let controlKey = Modifier(
        genericBit: CGEventFlags.maskControl.rawValue,
        leftBit: leftControlHeld,
        rightBit: rightControlHeld
    )
    static let optionKey = Modifier(
        genericBit: CGEventFlags.maskAlternate.rawValue,
        leftBit: leftOptionHeld,
        rightBit: rightOptionHeld
    )
    static let commandKey = Modifier(
        genericBit: CGEventFlags.maskCommand.rawValue,
        leftBit: leftCommandHeld,
        rightBit: rightCommandHeld
    )

    static let allModifiers: [(flag: NSEvent.ModifierFlags, bits: Modifier)] = [
        (.command, commandKey), (.option, optionKey), (.control, controlKey), (.shift, shiftKey),
    ]
}

/// Decides whether a key-down event triggers a hot key. Pure, so that tests
/// cover every side combination without an event tap.
enum HotKeyEventMatcher {
    /// Returns true when `keyCode` and `flags` hold exactly the modifiers of
    /// `keyCombo`, each on the side that `sides` asks for. A sided modifier
    /// rejects the other side held at the same time, so that Left Shift + E
    /// never fires a Right Shift binding.
    static func matches(
        keyCode: UInt32,
        flags: UInt64,
        keyCombo: KeyCombo,
        sides: ModifierSides
    ) -> Bool {
        guard keyCode == keyCombo.carbonKeyCode else { return false }
        return ModifierFlagBits.allModifiers.allSatisfy { modifier in
            let isRequired = keyCombo.modifiers.contains(modifier.flag)
            let isLeftHeld = flags & modifier.bits.leftBit != 0
            let isRightHeld = flags & modifier.bits.rightBit != 0
            let isAnyHeld = flags & modifier.bits.genericBit != 0 || isLeftHeld || isRightHeld
            guard isRequired else { return !isAnyHeld }
            switch sides.side(of: modifier.flag) {
            case .either: return isAnyHeld
            case .left: return isLeftHeld && !isRightHeld
            case .right: return isRightHeld && !isLeftHeld
            }
        }
    }
}
