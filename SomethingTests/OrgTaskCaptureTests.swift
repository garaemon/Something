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

    private func makeCapturer(fileSystem: FakeFileSystem) -> OrgTaskCapturer {
        OrgTaskCapturer(
            orgDirectory: orgDirectory,
            calendar: utcCalendar,
            now: { [captureDate] in captureDate },
            makeNoteID: { "11111111-2222-3333-4444-555555555555" },
            fileSystem: fileSystem.makeFileSystem()
        )
    }

    func test_should_format_heading_with_created_property() {
        let entry = OrgTaskFormat(calendar: utcCalendar).makeEntry(title: "buy milk", at: captureDate)

        XCTAssertEqual(
            entry,
            "* TODO buy milk :something:\n:PROPERTIES:\n:CREATED:  [2026-11-17 Tue 21:04]\n:END:\n")
    }

    func test_should_collapse_line_breaks_in_title() {
        let entry = OrgTaskFormat(calendar: utcCalendar).makeEntry(
            title: "  buy\nmilk\t now ", at: captureDate)

        XCTAssertTrue(entry.hasPrefix("* TODO buy milk now :something:\n"))
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

    func test_should_create_note_with_header_when_note_is_missing() {
        let fileSystem = FakeFileSystem()
        let capturer = makeCapturer(fileSystem: fileSystem)

        let result = capturer.capture(title: "buy milk")

        XCTAssertTrue(result)
        XCTAssertEqual(
            fileSystem.files[dailyNotePath],
            ":PROPERTIES:\n:ID:       11111111-2222-3333-4444-555555555555\n:END:\n#+title: 2026-11-17\n"
                + "* TODO buy milk :something:\n:PROPERTIES:\n:CREATED:  [2026-11-17 Tue 21:04]\n:END:\n")
    }

    func test_should_append_to_existing_note_without_new_header() {
        let fileSystem = FakeFileSystem()
        fileSystem.files[dailyNotePath] = "#+title: 2026-11-17\n* first\n"
        let capturer = makeCapturer(fileSystem: fileSystem)

        _ = capturer.capture(title: "buy milk")

        XCTAssertEqual(
            fileSystem.files[dailyNotePath],
            "#+title: 2026-11-17\n* first\n* TODO buy milk :something:\n:PROPERTIES:\n"
                + ":CREATED:  [2026-11-17 Tue 21:04]\n:END:\n")
    }

    func test_should_add_missing_newline_before_appended_heading() {
        let fileSystem = FakeFileSystem()
        fileSystem.files[dailyNotePath] = "* first"
        let capturer = makeCapturer(fileSystem: fileSystem)

        _ = capturer.capture(title: "buy milk")

        XCTAssertTrue(fileSystem.files[dailyNotePath]!.hasPrefix("* first\n* TODO buy milk :something:\n"))
    }

    func test_should_report_failure_when_file_write_fails() {
        let fileSystem = FakeFileSystem()
        fileSystem.writeError = CocoaError(.fileWriteNoPermission)
        let capturer = makeCapturer(fileSystem: fileSystem)

        let result = capturer.capture(title: "buy milk")

        XCTAssertFalse(result)
    }

    func test_should_not_overwrite_note_that_cannot_be_read() {
        let fileSystem = FakeFileSystem()
        fileSystem.readError = CocoaError(.fileReadNoPermission)
        fileSystem.files[dailyNotePath] = "precious"
        let capturer = makeCapturer(fileSystem: fileSystem)

        let result = capturer.capture(title: "buy milk")

        XCTAssertFalse(result)
        XCTAssertEqual(fileSystem.files[dailyNotePath], "precious")
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
        let capturer = makeCapturer(fileSystem: fileSystem)

        let result = capturer.capture(title: "  \n ")

        XCTAssertFalse(result)
        XCTAssertTrue(fileSystem.files.isEmpty)
    }
}
