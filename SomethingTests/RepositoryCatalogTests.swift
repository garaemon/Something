import XCTest

@testable import Something

final class RepositoryCatalogTests: XCTestCase {
    private var rootDirectory: URL!

    override func setUpWithError() throws {
        rootDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: rootDirectory, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try FileManager.default.removeItem(at: rootDirectory)
    }

    private func createRepositoryDirectory(_ relativePath: String) throws {
        try FileManager.default.createDirectory(
            at: rootDirectory.appendingPathComponent("\(relativePath)/.git", isDirectory: true),
            withIntermediateDirectories: true)
    }

    private func createPlainDirectory(_ relativePath: String) throws {
        try FileManager.default.createDirectory(
            at: rootDirectory.appendingPathComponent(relativePath, isDirectory: true),
            withIntermediateDirectories: true)
    }

    func test_should_name_repositories_relative_to_root() throws {
        try createRepositoryDirectory("github.com/owner/name")

        let repositories = RepositoryCatalog.scanRepositories(under: rootDirectory)

        XCTAssertEqual(repositories.map(\.name), ["github.com/owner/name"])
    }

    func test_should_point_repositories_at_their_directory() throws {
        try createRepositoryDirectory("github.com/owner/name")

        let repositories = RepositoryCatalog.scanRepositories(under: rootDirectory)

        XCTAssertEqual(
            repositories.map(\.url.standardizedFileURL.path),
            [rootDirectory.appendingPathComponent("github.com/owner/name").standardizedFileURL.path])
    }

    func test_should_skip_directories_without_git() throws {
        try createPlainDirectory("github.com/owner/plain")

        let repositories = RepositoryCatalog.scanRepositories(under: rootDirectory)

        XCTAssertTrue(repositories.isEmpty)
    }

    func test_should_find_repositories_deeper_than_owner_level() throws {
        try createRepositoryDirectory("gitlab.com/group/subgroup/name")

        let repositories = RepositoryCatalog.scanRepositories(under: rootDirectory)

        XCTAssertEqual(repositories.map(\.name), ["gitlab.com/group/subgroup/name"])
    }

    func test_should_not_list_directories_inside_a_repository() throws {
        try createRepositoryDirectory("github.com/owner/name")
        try createRepositoryDirectory("github.com/owner/name/vendor/nested")

        let repositories = RepositoryCatalog.scanRepositories(under: rootDirectory)

        XCTAssertEqual(repositories.map(\.name), ["github.com/owner/name"])
    }

    // A worktree or a submodule checkout has a `.git` file instead of a directory.
    func test_should_list_repositories_whose_git_is_a_file() throws {
        try createPlainDirectory("github.com/owner/worktree")
        try Data("gitdir: /elsewhere\n".utf8).write(
            to: rootDirectory.appendingPathComponent("github.com/owner/worktree/.git"))

        let repositories = RepositoryCatalog.scanRepositories(under: rootDirectory)

        XCTAssertEqual(repositories.map(\.name), ["github.com/owner/worktree"])
    }

    func test_should_return_no_repositories_when_root_is_missing() {
        let missingRoot = rootDirectory.appendingPathComponent("missing", isDirectory: true)

        let repositories = RepositoryCatalog.scanRepositories(under: missingRoot)

        XCTAssertTrue(repositories.isEmpty)
    }

    func test_should_list_repositories_reached_through_symbolic_links() throws {
        let outsideDirectory = rootDirectory.appendingPathComponent("outside", isDirectory: true)
        try FileManager.default.createDirectory(
            at: outsideDirectory.appendingPathComponent("name/.git", isDirectory: true),
            withIntermediateDirectories: true)
        let ghqRoot = rootDirectory.appendingPathComponent("ghq", isDirectory: true)
        try FileManager.default.createDirectory(
            at: ghqRoot.appendingPathComponent("github.com", isDirectory: true),
            withIntermediateDirectories: true)
        try FileManager.default.createSymbolicLink(
            at: ghqRoot.appendingPathComponent("github.com/owner"), withDestinationURL: outsideDirectory)

        let repositories = RepositoryCatalog.scanRepositories(under: ghqRoot)

        XCTAssertEqual(repositories.map(\.name), ["github.com/owner/name"])
    }

    func test_should_stop_at_a_symbolic_link_loop() throws {
        try createPlainDirectory("github.com")
        try FileManager.default.createSymbolicLink(
            at: rootDirectory.appendingPathComponent("github.com/loop"), withDestinationURL: rootDirectory)

        let repositories = RepositoryCatalog.scanRepositories(under: rootDirectory)

        XCTAssertTrue(repositories.isEmpty)
    }

    func test_should_skip_repositories_deeper_than_six_levels() throws {
        try createRepositoryDirectory("a/b/c/d/e/f/g")

        let repositories = RepositoryCatalog.scanRepositories(under: rootDirectory)

        XCTAssertTrue(repositories.isEmpty)
    }

    func test_should_list_repositories_six_levels_deep() throws {
        try createRepositoryDirectory("a/b/c/d/e/f")

        let repositories = RepositoryCatalog.scanRepositories(under: rootDirectory)

        XCTAssertEqual(repositories.map(\.name), ["a/b/c/d/e/f"])
    }

    func test_should_not_list_a_repository_again_through_a_link_to_an_ancestor() throws {
        try createRepositoryDirectory("github.com/x/y")
        try createPlainDirectory("github.com/me")
        try FileManager.default.createSymbolicLink(
            at: rootDirectory.appendingPathComponent("github.com/me/all"), withDestinationURL: rootDirectory)

        let repositories = RepositoryCatalog.scanRepositories(under: rootDirectory)

        XCTAssertEqual(repositories.map(\.name), ["github.com/x/y"])
    }
}
