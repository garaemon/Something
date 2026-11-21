import XCTest

@testable import Something

private final class FakePasteboard: SelectionPasteboard {
    var changeCount = 0
    var snapshot = PasteboardSnapshot(items: [["public.utf8-plain-text": Data("old".utf8)]])
    var currentString: String? = "old"
    private(set) var restoredSnapshots: [PasteboardSnapshot] = []

    var onReadSnapshot: () -> Void = {}

    func readSnapshot() -> PasteboardSnapshot {
        onReadSnapshot()
        return snapshot
    }

    func readString() -> String? { currentString }

    func restore(_ snapshot: PasteboardSnapshot) {
        restoredSnapshots.append(snapshot)
        changeCount += 1
    }

    func simulateCopy(_ text: String) {
        currentString = text
        changeCount += 1
    }
}

@MainActor
final class SelectionCaptureTests: XCTestCase {
    private let safari = SourceApplication(
        processIdentifier: 100, bundleIdentifier: "com.apple.Safari", name: "Safari")
    private let ownProcessIdentifier: Int32 = 1

    private func makeCapturer(
        frontmost: SourceApplication?,
        accessibilityText: String?,
        pasteboard: FakePasteboard,
        canPostCopyKey: Bool = true,
        postCopyKey: @escaping () -> Bool,
        pauseBetweenPolls: @escaping () -> Void = {}
    ) -> SelectionCapturer {
        SelectionCapturer(
            readFrontmostApplication: { frontmost },
            readAccessibilitySelection: { _ in accessibilityText },
            pasteboard: pasteboard,
            canPostCopyKey: { canPostCopyKey },
            postCopyKey: postCopyKey,
            pauseBetweenPolls: pauseBetweenPolls,
            maximumPollCount: 5,
            ownProcessIdentifier: ownProcessIdentifier
        )
    }

    func test_should_return_accessibility_text_without_touching_pasteboard() {
        let pasteboard = FakePasteboard()
        var didPostKey = false
        let capturer = makeCapturer(
            frontmost: safari, accessibilityText: "hello", pasteboard: pasteboard,
            postCopyKey: {
                didPostKey = true
                return true
            })

        let selection = capturer.captureSelection(fallback: .copyKey)

        XCTAssertEqual(selection, CapturedSelection(sourceApplication: safari, text: "hello"))
        XCTAssertFalse(didPostKey)
        XCTAssertTrue(pasteboard.restoredSnapshots.isEmpty)
    }

    func test_should_not_fall_back_when_accessibility_reports_empty_selection() {
        let pasteboard = FakePasteboard()
        var didPostKey = false
        let capturer = makeCapturer(
            frontmost: safari, accessibilityText: "", pasteboard: pasteboard,
            postCopyKey: {
                didPostKey = true
                return true
            })

        let selection = capturer.captureSelection(fallback: .copyKey)

        XCTAssertNil(selection.text)
        XCTAssertFalse(didPostKey)
    }

    func test_should_not_post_copy_key_when_fallback_is_none() {
        let pasteboard = FakePasteboard()
        var didPostKey = false
        let capturer = makeCapturer(
            frontmost: safari, accessibilityText: nil, pasteboard: pasteboard,
            postCopyKey: {
                didPostKey = true
                return true
            })

        _ = capturer.captureSelection(fallback: .none)

        XCTAssertFalse(didPostKey)
    }

    func test_should_keep_source_application_when_fallback_is_none() {
        let pasteboard = FakePasteboard()
        let capturer = makeCapturer(
            frontmost: safari, accessibilityText: nil, pasteboard: pasteboard,
            postCopyKey: { true })

        let selection = capturer.captureSelection(fallback: .none)

        XCTAssertEqual(selection, CapturedSelection(sourceApplication: safari, text: nil))
    }

    func test_should_copy_through_pasteboard_when_accessibility_is_unavailable() {
        let pasteboard = FakePasteboard()
        let capturer = makeCapturer(
            frontmost: safari, accessibilityText: nil, pasteboard: pasteboard,
            postCopyKey: {
                pasteboard.simulateCopy("copied")
                return true
            })

        XCTAssertEqual(capturer.captureSelection(fallback: .copyKey).text, "copied")
    }

    func test_should_restore_previous_pasteboard_after_fallback() {
        let pasteboard = FakePasteboard()
        let originalSnapshot = pasteboard.snapshot
        let capturer = makeCapturer(
            frontmost: safari, accessibilityText: nil, pasteboard: pasteboard,
            postCopyKey: {
                pasteboard.simulateCopy("copied")
                return true
            })

        _ = capturer.captureSelection(fallback: .copyKey)

        XCTAssertEqual(pasteboard.restoredSnapshots, [originalSnapshot])
    }

    func test_should_return_no_text_and_leave_pasteboard_when_copy_changes_nothing() {
        let pasteboard = FakePasteboard()
        let capturer = makeCapturer(
            frontmost: safari, accessibilityText: nil, pasteboard: pasteboard,
            postCopyKey: { true })

        let selection = capturer.captureSelection(fallback: .copyKey)

        XCTAssertNil(selection.text)
        XCTAssertTrue(pasteboard.restoredSnapshots.isEmpty)
    }

    func test_should_wait_for_a_late_pasteboard_change() {
        let pasteboard = FakePasteboard()
        var pauseCount = 0
        let capturer = makeCapturer(
            frontmost: safari, accessibilityText: nil, pasteboard: pasteboard,
            postCopyKey: { true },
            pauseBetweenPolls: {
                pauseCount += 1
                if pauseCount == 2 { pasteboard.simulateCopy("late") }
            })

        XCTAssertEqual(capturer.captureSelection(fallback: .copyKey).text, "late")
    }

    func test_should_not_wait_when_posting_the_copy_key_fails() {
        let pasteboard = FakePasteboard()
        var pauseCount = 0
        let capturer = makeCapturer(
            frontmost: safari, accessibilityText: nil, pasteboard: pasteboard,
            postCopyKey: { false },
            pauseBetweenPolls: { pauseCount += 1 })

        XCTAssertNil(capturer.captureSelection(fallback: .copyKey).text)
        XCTAssertEqual(pauseCount, 0)
    }

    func test_should_capture_nothing_when_frontmost_application_is_this_app() {
        let pasteboard = FakePasteboard()
        let ownApplication = SourceApplication(
            processIdentifier: ownProcessIdentifier, bundleIdentifier: nil, name: "Something")
        var didPostKey = false
        let capturer = makeCapturer(
            frontmost: ownApplication, accessibilityText: "x", pasteboard: pasteboard,
            postCopyKey: {
                didPostKey = true
                return true
            })

        XCTAssertEqual(capturer.captureSelection(fallback: .copyKey), .empty)
        XCTAssertFalse(didPostKey)
    }

    func test_should_remember_application_when_nothing_is_selected() {
        let capturer = makeCapturer(
            frontmost: safari, accessibilityText: "", pasteboard: FakePasteboard(),
            postCopyKey: { true })

        XCTAssertEqual(capturer.captureSelection(fallback: .copyKey).sourceApplication, safari)
    }

    func test_should_stop_polling_after_maximum_poll_count() {
        var pauseCount = 0
        let capturer = makeCapturer(
            frontmost: safari, accessibilityText: nil, pasteboard: FakePasteboard(),
            postCopyKey: { true },
            pauseBetweenPolls: { pauseCount += 1 })

        _ = capturer.captureSelection(fallback: .copyKey)

        XCTAssertEqual(pauseCount, 5)
    }

    func test_should_not_read_pasteboard_when_copy_key_is_not_postable() {
        let pasteboard = FakePasteboard()
        var didReadSnapshot = false
        pasteboard.onReadSnapshot = { didReadSnapshot = true }
        let capturer = makeCapturer(
            frontmost: safari, accessibilityText: nil, pasteboard: pasteboard,
            canPostCopyKey: false, postCopyKey: { true })

        _ = capturer.captureSelection(fallback: .copyKey)

        XCTAssertFalse(didReadSnapshot)
    }

    func test_should_restore_pasteboard_when_it_changed_but_never_held_text() {
        let pasteboard = FakePasteboard()
        let originalSnapshot = pasteboard.snapshot
        let capturer = makeCapturer(
            frontmost: safari, accessibilityText: nil, pasteboard: pasteboard,
            postCopyKey: {
                pasteboard.currentString = nil
                pasteboard.changeCount += 1
                return true
            })

        let selection = capturer.captureSelection(fallback: .copyKey)

        XCTAssertNil(selection.text)
        XCTAssertEqual(pasteboard.restoredSnapshots, [originalSnapshot])
    }
}
