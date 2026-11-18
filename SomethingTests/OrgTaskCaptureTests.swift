import XCTest

@testable import Something

final class OrgTaskCaptureTests: XCTestCase {
    // 2026-11-17 21:04 in UTC, a Tuesday.
    private let captureDate = Date(timeIntervalSince1970: 1_794_949_440)
    private let orgDirectory = URL(fileURLWithPath: "/org", isDirectory: true)
    private let dailyNotePath = "/org/org-roam/daily/2026-11-17.org"

    private var utcCalendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        return calendar
    }

    private final class FakeFileSystem {
        var files: [String: String] = [:]
        var writeError: Error?
        var readError: Error?

        func makeFileSystem() -> OrgFileSystem {
            OrgFileSystem(
                readText: { [self] url in
                    if let readError { throw readError }
                    return files[url.path]
                },
                writeText: { [self] text, url in
                    if let writeError { throw writeError }
                    files[url.path] = text
                }
            )
        }
    }

    private func makeCapturer(
        fileSystem: FakeFileSystem,
        runEmacsclient: @escaping ([String]) -> EmacsclientOutcome
    ) -> OrgTaskCapturer {
        OrgTaskCapturer(
            orgDirectory: orgDirectory,
            calendar: utcCalendar,
            now: { [captureDate] in captureDate },
            makeNoteID: { "11111111-2222-3333-4444-555555555555" },
            runEmacsclient: runEmacsclient,
            fileSystem: fileSystem.makeFileSystem()
        )
    }

    func test_should_format_heading_with_created_property() {
        let entry = OrgTaskFormat(calendar: utcCalendar).makeEntry(title: "buy milk", at: captureDate)

        XCTAssertEqual(
            entry,
            "* TODO buy milk\n:PROPERTIES:\n:CREATED:  [2026-11-17 Tue 21:04]\n:END:\n")
    }

    func test_should_collapse_line_breaks_in_title() {
        let entry = OrgTaskFormat(calendar: utcCalendar).makeEntry(
            title: "  buy\nmilk\t now ", at: captureDate)

        XCTAssertTrue(entry.hasPrefix("* TODO buy milk now\n"))
    }

    func test_should_name_daily_note_after_capture_day() {
        let url = OrgTaskFormat(calendar: utcCalendar).makeDailyNoteURL(
            orgDirectory: orgDirectory, at: captureDate)

        XCTAssertEqual(url.path, dailyNotePath)
    }

    func test_should_use_local_day_for_daily_note() {
        var tokyoCalendar = utcCalendar
        tokyoCalendar.timeZone = TimeZone(identifier: "Asia/Tokyo")!

        let url = OrgTaskFormat(calendar: tokyoCalendar).makeDailyNoteURL(
            orgDirectory: orgDirectory, at: captureDate)

        XCTAssertEqual(url.lastPathComponent, "2026-11-18.org")
    }

    func test_should_format_new_note_header_with_id_then_title() {
        let header = OrgTaskFormat(calendar: utcCalendar).makeNewNoteHeader(
            noteID: "abc", at: captureDate)

        XCTAssertEqual(header, ":PROPERTIES:\n:ID:       abc\n:END:\n#+title: 2026-11-17\n")
    }

    func test_should_escape_backslash_and_quote_in_elisp_string() {
        let literal = OrgElisp.makeStringLiteral("a\"b\\c")

        XCTAssertEqual(literal, "\"a\\\"b\\\\c\"")
    }

    func test_should_keep_quote_in_title_inside_elisp_string() {
        let expression = OrgElisp.makeAppendExpression(
            filePath: "/org/a.org", entry: "* TODO say \"hi\"\n", newNoteHeader: "H\n")

        XCTAssertTrue(expression.contains("\"* TODO say \\\"hi\\\"\n\""))
    }

    func test_should_balance_parentheses_of_append_expression() {
        let expression = OrgElisp.makeAppendExpression(
            filePath: "/org/a (1).org", entry: "* TODO ) \"x\" (\n", newNoteHeader: "((\n")

        XCTAssertEqual(countParenthesesOutsideStrings(in: expression), 0)
    }

    // Counts "(" minus ")" while skipping elisp string literals and their escapes.
    private func countParenthesesOutsideStrings(in expression: String) -> Int {
        var depth = 0
        var isInsideString = false
        var isEscaped = false
        for character in expression {
            if isInsideString {
                if isEscaped {
                    isEscaped = false
                } else if character == "\\" {
                    isEscaped = true
                } else if character == "\"" {
                    isInsideString = false
                }
            } else if character == "\"" {
                isInsideString = true
            } else if character == "(" {
                depth += 1
            } else if character == ")" {
                depth -= 1
            }
        }
        return depth
    }

    func test_should_pass_append_expression_to_emacsclient_with_eval() {
        var receivedArguments: [String] = []
        let capturer = makeCapturer(fileSystem: FakeFileSystem()) {
            receivedArguments = $0
            return .succeeded
        }

        _ = capturer.capture(title: "buy milk")

        XCTAssertEqual(receivedArguments.first, "--eval")
        XCTAssertTrue(receivedArguments.last?.contains(dailyNotePath) ?? false)
    }

    func test_should_report_emacs_when_server_answers() {
        let capturer = makeCapturer(fileSystem: FakeFileSystem()) { _ in .succeeded }

        let result = capturer.capture(title: "buy milk")

        XCTAssertEqual(result, .sentToEmacs)
    }

    func test_should_not_touch_file_when_server_answers() {
        let fileSystem = FakeFileSystem()
        let capturer = makeCapturer(fileSystem: fileSystem) { _ in .succeeded }

        _ = capturer.capture(title: "buy milk")

        XCTAssertTrue(fileSystem.files.isEmpty)
    }

    func test_should_create_note_with_header_when_no_server_answers() {
        let fileSystem = FakeFileSystem()
        let capturer = makeCapturer(fileSystem: fileSystem) { _ in .serverUnavailable }

        let result = capturer.capture(title: "buy milk")

        XCTAssertEqual(result, .wroteFile)
        XCTAssertEqual(
            fileSystem.files[dailyNotePath],
            ":PROPERTIES:\n:ID:       11111111-2222-3333-4444-555555555555\n:END:\n#+title: 2026-11-17\n"
                + "* TODO buy milk\n:PROPERTIES:\n:CREATED:  [2026-11-17 Tue 21:04]\n:END:\n")
    }

    func test_should_append_to_existing_note_without_new_header() {
        let fileSystem = FakeFileSystem()
        fileSystem.files[dailyNotePath] = "#+title: 2026-11-17\n* first\n"
        let capturer = makeCapturer(fileSystem: fileSystem) { _ in .serverUnavailable }

        _ = capturer.capture(title: "buy milk")

        XCTAssertEqual(
            fileSystem.files[dailyNotePath],
            "#+title: 2026-11-17\n* first\n* TODO buy milk\n:PROPERTIES:\n"
                + ":CREATED:  [2026-11-17 Tue 21:04]\n:END:\n")
    }

    func test_should_add_missing_newline_before_appended_heading() {
        let fileSystem = FakeFileSystem()
        fileSystem.files[dailyNotePath] = "* first"
        let capturer = makeCapturer(fileSystem: fileSystem) { _ in .serverUnavailable }

        _ = capturer.capture(title: "buy milk")

        XCTAssertTrue(fileSystem.files[dailyNotePath]!.hasPrefix("* first\n* TODO buy milk\n"))
    }

    func test_should_report_failure_when_file_write_fails() {
        let fileSystem = FakeFileSystem()
        fileSystem.writeError = CocoaError(.fileWriteNoPermission)
        let capturer = makeCapturer(fileSystem: fileSystem) { _ in .serverUnavailable }

        let result = capturer.capture(title: "buy milk")

        XCTAssertEqual(result, .failed)
    }

    func test_should_not_write_file_when_emacs_failed_after_accepting_request() {
        let fileSystem = FakeFileSystem()
        let capturer = makeCapturer(fileSystem: fileSystem) { _ in .evaluationFailed }

        let result = capturer.capture(title: "buy milk")

        XCTAssertEqual(result, .failed)
        XCTAssertTrue(fileSystem.files.isEmpty)
    }

    func test_should_not_overwrite_note_that_cannot_be_read() {
        let fileSystem = FakeFileSystem()
        fileSystem.readError = CocoaError(.fileReadNoPermission)
        fileSystem.files[dailyNotePath] = "precious"
        let capturer = makeCapturer(fileSystem: fileSystem) { _ in .serverUnavailable }

        let result = capturer.capture(title: "buy milk")

        XCTAssertEqual(result, .failed)
        XCTAssertEqual(fileSystem.files[dailyNotePath], "precious")
    }

    func test_should_insert_header_only_for_empty_buffer_in_elisp() {
        let expression = OrgElisp.makeAppendExpression(
            filePath: "/org/a.org", entry: "E\n", newNoteHeader: "H\n")

        XCTAssertTrue(
            expression.contains("(when (= (buffer-size) 0) (insert \"H\n\"))"))
    }

    func test_should_save_inside_with_current_buffer() {
        let expression = OrgElisp.makeAppendExpression(
            filePath: "/org/a.org", entry: "E\n", newNoteHeader: "H\n")

        XCTAssertTrue(expression.hasSuffix("(insert \"E\n\")))\n(save-buffer)))"))
    }

    func test_should_read_nil_for_missing_file_in_live_file_system() throws {
        let missingURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("OrgLive-\(UUID().uuidString)/missing.org")

        XCTAssertNil(try OrgFileSystem.live.readText(missingURL))
    }

    func test_should_create_folders_when_writing_with_live_file_system() throws {
        let folderURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("OrgLive-\(UUID().uuidString)")
        addTeardownBlock { try? FileManager.default.removeItem(at: folderURL) }
        let noteURL = folderURL.appendingPathComponent("a/b.org")

        try OrgFileSystem.live.writeText("x", noteURL)

        XCTAssertEqual(try OrgFileSystem.live.readText(noteURL), "x")
    }

    func test_should_not_capture_blank_title() {
        let fileSystem = FakeFileSystem()
        let capturer = makeCapturer(fileSystem: fileSystem) { _ in .serverUnavailable }

        let result = capturer.capture(title: "  \n ")

        XCTAssertEqual(result, .failed)
        XCTAssertTrue(fileSystem.files.isEmpty)
    }
}
