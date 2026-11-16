import XCTest

@testable import Something

final class ScratchKeyBindingsTests: XCTestCase {
    func test_should_run_block_on_control_j() {
        var bindings = ScratchKeyBindings()

        let command = bindings.resolve(key: "j", isControlOnly: true)

        XCTAssertEqual(command, .command(.runBlockAtCursor))
    }

    func test_should_wait_for_second_key_after_control_c() {
        var bindings = ScratchKeyBindings()

        let command = bindings.resolve(key: "c", isControlOnly: true)

        XCTAssertEqual(command, .prefix)
    }

    func test_should_run_all_blocks_on_control_c_control_c() {
        var bindings = ScratchKeyBindings()
        _ = bindings.resolve(key: "c", isControlOnly: true)

        let command = bindings.resolve(key: "c", isControlOnly: true)

        XCTAssertEqual(command, .command(.runAllBlocks))
    }

    func test_should_reset_on_control_c_control_k() {
        var bindings = ScratchKeyBindings()
        _ = bindings.resolve(key: "c", isControlOnly: true)

        let command = bindings.resolve(key: "k", isControlOnly: true)

        XCTAssertEqual(command, .command(.resetInterpreter))
    }

    // Emacs drops an undefined key sequence instead of typing its second key.
    func test_should_swallow_unknown_key_after_prefix() {
        var bindings = ScratchKeyBindings()
        _ = bindings.resolve(key: "c", isControlOnly: true)

        let command = bindings.resolve(key: "x", isControlOnly: false)

        XCTAssertEqual(command, .swallowed)
    }

    func test_should_pass_through_plain_key_after_finished_sequence() {
        var bindings = ScratchKeyBindings()
        _ = bindings.resolve(key: "c", isControlOnly: true)
        _ = bindings.resolve(key: "x", isControlOnly: false)

        let command = bindings.resolve(key: "x", isControlOnly: false)

        XCTAssertEqual(command, .passThrough)
    }

    func test_should_pass_through_other_control_keys() {
        var bindings = ScratchKeyBindings()

        let command = bindings.resolve(key: "a", isControlOnly: true)

        XCTAssertEqual(command, .passThrough)
    }
}
