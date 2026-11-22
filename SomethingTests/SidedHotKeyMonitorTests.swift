import HotKey
import XCTest

@testable import Something

@MainActor
final class FakeKeyEventTapInstaller: KeyEventTapInstalling {
    var installCount = 0
    var uninstallCount = 0
    var canInstall = true
    var handler: ((TappedKeyEvent) -> Bool)?

    func install(handler: @escaping @MainActor (TappedKeyEvent) -> Bool) -> Bool {
        guard canInstall else { return false }
        installCount += 1
        self.handler = handler
        return true
    }

    func uninstall() {
        uninstallCount += 1
        handler = nil
    }
}

@MainActor
final class SidedHotKeyMonitorTests: XCTestCase {
    private let rightShiftEBinding = HotKeyBinding(
        keyCombo: KeyCombo(key: .e, modifiers: [.shift]),
        modifierSides: ModifierSides(shift: .right),
        command: .openScratch)
    private let unsidedBinding = HotKeyBinding(
        keyCombo: KeyCombo(key: .x, modifiers: [.command, .shift]), command: .openLauncher)
    private var installer = FakeKeyEventTapInstaller()
    private var isTrusted = true
    private var ranCommands: [HotKeyCommand] = []

    override func setUp() {
        installer = FakeKeyEventTapInstaller()
        isTrusted = true
        ranCommands = []
    }

    private func makeMonitor(onCommand: @escaping () -> Void = {}) -> SidedHotKeyMonitor {
        SidedHotKeyMonitor(
            installer: installer,
            isAccessibilityTrusted: { [unowned self] in isTrusted },
            runCommand: { [unowned self] command in
                ranCommands.append(command)
                onCommand()
            })
    }

    private func makeRightShiftEvent(isAutorepeat: Bool = false) -> TappedKeyEvent {
        TappedKeyEvent(
            keyCode: Key.e.carbonKeyCode, flags: ModifierFlagBits.rightShiftHeld | ModifierFlagBits.genericShift,
            isAutorepeat: isAutorepeat)
    }

    func test_should_not_install_tap_without_sided_bindings() {
        let monitor = makeMonitor()

        monitor.update(bindings: [unsidedBinding])

        XCTAssertEqual(installer.installCount, 0)
        XCTAssertEqual(monitor.status, .inactive)
    }

    func test_should_install_tap_for_sided_binding() {
        let monitor = makeMonitor()

        monitor.update(bindings: [unsidedBinding, rightShiftEBinding])

        XCTAssertEqual(installer.installCount, 1)
        XCTAssertEqual(monitor.status, .active)
    }

    func test_should_install_tap_once_for_repeated_updates() {
        let monitor = makeMonitor()

        monitor.update(bindings: [rightShiftEBinding])
        monitor.update(bindings: [rightShiftEBinding, unsidedBinding])

        XCTAssertEqual(installer.installCount, 1)
    }

    func test_should_remove_tap_when_last_sided_binding_goes() {
        let monitor = makeMonitor()
        monitor.update(bindings: [rightShiftEBinding])

        monitor.update(bindings: [unsidedBinding])

        XCTAssertEqual(installer.uninstallCount, 1)
        XCTAssertEqual(monitor.status, .inactive)
    }

    func test_should_report_missing_accessibility_permission() {
        isTrusted = false
        let monitor = makeMonitor()

        monitor.update(bindings: [rightShiftEBinding])

        XCTAssertEqual(installer.installCount, 0)
        XCTAssertEqual(monitor.status, .needsAccessibility)
    }

    func test_should_install_tap_after_permission_is_granted() {
        isTrusted = false
        let monitor = makeMonitor()
        monitor.update(bindings: [rightShiftEBinding])

        isTrusted = true
        monitor.refresh()

        XCTAssertEqual(monitor.status, .active)
    }

    func test_should_report_tap_creation_failure() {
        installer.canInstall = false
        let monitor = makeMonitor()

        monitor.update(bindings: [rightShiftEBinding])

        XCTAssertEqual(monitor.status, .tapUnavailable)
    }

    func test_should_remove_tap_when_permission_is_revoked() {
        let monitor = makeMonitor()
        monitor.update(bindings: [rightShiftEBinding])

        isTrusted = false
        monitor.refresh()

        XCTAssertEqual(installer.uninstallCount, 1)
        XCTAssertEqual(monitor.status, .needsAccessibility)
    }

    func test_should_swallow_matching_event_and_run_command() async {
        let commandRan = expectation(description: "command ran")
        let monitor = makeMonitor(onCommand: { commandRan.fulfill() })
        monitor.update(bindings: [rightShiftEBinding])

        let isSwallowed = installer.handler?(makeRightShiftEvent())
        await fulfillment(of: [commandRan], timeout: 2)

        XCTAssertEqual(isSwallowed, true)
        XCTAssertEqual(ranCommands, [.openScratch])
    }

    func test_should_pass_left_shift_event_through() {
        let monitor = makeMonitor()
        monitor.update(bindings: [rightShiftEBinding])
        let leftShiftEvent = TappedKeyEvent(
            keyCode: Key.e.carbonKeyCode, flags: ModifierFlagBits.leftShiftHeld | ModifierFlagBits.genericShift,
            isAutorepeat: false)

        XCTAssertEqual(installer.handler?(leftShiftEvent), false)
        XCTAssertEqual(ranCommands, [])
    }

    func test_should_swallow_autorepeat_without_running_command_again() async {
        let commandRan = expectation(description: "command ran")
        let monitor = makeMonitor(onCommand: { commandRan.fulfill() })
        monitor.update(bindings: [rightShiftEBinding])

        let isRepeatSwallowed = installer.handler?(makeRightShiftEvent(isAutorepeat: true))
        _ = installer.handler?(makeRightShiftEvent())
        await fulfillment(of: [commandRan], timeout: 2)

        XCTAssertEqual(isRepeatSwallowed, true)
        XCTAssertEqual(ranCommands, [.openScratch])
    }

    func test_should_pass_events_through_while_paused() {
        let monitor = makeMonitor()
        monitor.update(bindings: [rightShiftEBinding])

        monitor.isPaused = true

        XCTAssertEqual(installer.handler?(makeRightShiftEvent()), false)
        XCTAssertEqual(ranCommands, [])
    }
}
