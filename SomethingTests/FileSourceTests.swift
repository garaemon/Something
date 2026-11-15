import XCTest

@testable import Something

final class FileSourceTests: XCTestCase {
    private func makeSource(
        _ files: [LocalFile], openFile: @escaping (LocalFile) -> Void = { _ in },
        revealFile: @escaping (LocalFile) -> Void = { _ in }
    ) -> FileSource {
        FileSource(files: files, openFile: openFile, revealFile: revealFile)
    }

    func test_should_list_no_files_for_empty_query() {
        let source = makeSource([makeFile("Downloads/a.pdf")])

        let candidates = source.makeCandidates(matching: "  ")

        XCTAssertTrue(candidates.isEmpty)
    }

    func test_should_narrow_files_by_path() {
        let source = makeSource([makeFile("Downloads/report.pdf"), makeFile("Documents/memo.txt")])

        let names = source.makeCandidates(matching: "report").map(\.name)

        XCTAssertEqual(names, ["Downloads/report.pdf"])
    }

    func test_should_keep_recent_files_first_among_matches() {
        let source = makeSource([makeFile("Downloads/new.pdf"), makeFile("Downloads/a-old.pdf")])

        let names = source.makeCandidates(matching: "pdf").map(\.name)

        XCTAssertEqual(names, ["Downloads/new.pdf", "Downloads/a-old.pdf"])
    }

    func test_should_list_at_most_candidate_limit() {
        let files = (0..<(FileSource.candidateLimit + 1)).map { makeFile("Downloads/\($0).txt") }
        let source = makeSource(files)

        let candidates = source.makeCandidates(matching: "txt")

        XCTAssertEqual(candidates.count, FileSource.candidateLimit)
    }

    func test_should_open_file_by_default() throws {
        var openedFiles: [LocalFile] = []
        let file = makeFile("Downloads/a.pdf")
        let source = makeSource([file], openFile: { openedFiles.append($0) })
        let candidate = try XCTUnwrap(source.makeCandidates(matching: "a.pdf").first)

        candidate.defaultAction?.perform()

        XCTAssertEqual(openedFiles, [file])
    }

    func test_should_offer_reveal_in_finder_as_second_action() throws {
        var revealedFiles: [LocalFile] = []
        let file = makeFile("Downloads/a.pdf")
        let source = makeSource([file], revealFile: { revealedFiles.append($0) })
        let candidate = try XCTUnwrap(source.makeCandidates(matching: "a.pdf").first)

        candidate.actions.dropFirst().first?.perform()

        XCTAssertEqual(revealedFiles, [file])
    }

    func test_should_show_icon_of_file_extension() throws {
        let source = makeSource([makeFile("Downloads/a.PDF")])

        let candidate = try XCTUnwrap(source.makeCandidates(matching: "a").first)

        XCTAssertEqual(candidate.icon, .fileType(extension: "pdf"))
    }

    func test_should_tag_file_candidates_as_file() {
        let source = makeSource([makeFile("Downloads/a.pdf")])

        let kinds = source.makeCandidates(matching: "a").map(\.kind)

        XCTAssertEqual(kinds, [.file])
    }
}
