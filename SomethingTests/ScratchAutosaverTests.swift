import XCTest

@testable import Something

final class ScratchAutosaverTests: XCTestCase {
    private var savedTexts: [String] = []

    private func makeAutosaver(delay: TimeInterval = 60) -> ScratchAutosaver {
        ScratchAutosaver(delay: delay, saveText: { [unowned self] in savedTexts.append($0) })
    }

    func test_should_not_save_before_delay() {
        let autosaver = makeAutosaver()

        autosaver.scheduleSave("a")

        XCTAssertEqual(savedTexts, [])
    }

    func test_should_save_latest_text_after_delay() {
        let autosaver = makeAutosaver(delay: 0.01)
        let saved = expectation(description: "saved")
        autosaver.scheduleSave("a")
        autosaver.scheduleSave("ab")

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { saved.fulfill() }
        wait(for: [saved], timeout: 1)

        XCTAssertEqual(savedTexts, ["ab"])
    }

    func test_should_save_pending_text_on_flush() {
        let autosaver = makeAutosaver()
        autosaver.scheduleSave("a")

        autosaver.flush()

        XCTAssertEqual(savedTexts, ["a"])
    }

    func test_should_not_save_again_after_flush() {
        let autosaver = makeAutosaver(delay: 0.01)
        let waited = expectation(description: "waited")
        autosaver.scheduleSave("a")
        autosaver.flush()

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { waited.fulfill() }
        wait(for: [waited], timeout: 1)

        XCTAssertEqual(savedTexts, ["a"])
    }

    func test_should_not_save_on_flush_without_changes() {
        let autosaver = makeAutosaver()

        autosaver.flush()

        XCTAssertEqual(savedTexts, [])
    }
}
