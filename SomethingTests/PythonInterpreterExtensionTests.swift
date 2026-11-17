import XCTest

@testable import Something

final class PythonInterpreterExtensionTests: XCTestCase {
    private let interpreter = PythonInterpreter.shared
    private var raisedWindowTitles: [String] = []
    private let raisedLock = NSLock()
    private var listedWindows: [SwitchableWindow] = []

    override func setUp() {
        super.setUp()
        listedWindows = [makeWindow("Safari", "GitHub"), makeWindow("Code", "notes.py")]
        // The stubs keep the tests off the Accessibility API.
        interpreter.useWindowProvider(
            loadWindows: { [weak self] in self?.listedWindows ?? [] },
            raiseWindow: { [weak self] window in
                self?.raisedLock.withLock { self?.raisedWindowTitles.append(window.title) }
            }
        )
        interpreter.reset()
    }

    override func tearDown() {
        interpreter.forgetInitFileForReset()
        interpreter.reset()
        super.tearDown()
    }

    private func python(_ source: String) -> PythonRunResult {
        interpreter.run(PythonBlock(leadingSource: source, lastStatement: "None"))
    }

    private func pythonValue(_ expression: String) -> String {
        interpreter.run(PythonBlock(lastStatement: expression)).output
    }

    private func makeTemporaryFile(_ text: String) throws -> URL {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        addTeardownBlock { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appendingPathComponent("init.py")
        try text.write(to: url, atomically: true, encoding: .utf8)
        return url
    }

    func test_should_collect_rows_of_a_source_registered_from_python() {
        let result = python(
            """
            import something
            something.add_source("demo", lambda: [something.Candidate("one"), something.Candidate("two")])
            """)

        let collection = interpreter.collectExtensionItems()

        XCTAssertNil(result.errorMessage)
        XCTAssertEqual(collection.items.map(\.title), ["one", "two"])
        XCTAssertEqual(collection.items.map(\.source), ["demo", "demo"])
        XCTAssertEqual(collection.errors, [])
    }

    func test_should_list_windows_and_focus_one_from_a_collected_action() {
        let result = python(
            """
            import something
            def rows():
                return [something.Candidate(f"{w.app_name} — {w.title}", action=w.focus)
                        for w in something.windows()]
            something.add_source("python windows", rows)
            """)
        let collection = interpreter.collectExtensionItems()
        let raised = expectation(description: "the window is raised")
        raised.assertForOverFulfill = false

        let titles = collection.items.map(\.title)
        let index = collection.items.first { $0.title == "Code — notes.py" }?.action
        let actionResult = interpreter.runExtensionAction(
            generation: collection.generation, index: index ?? -1)
        DispatchQueue.main.async {
            // The raise hops to the main thread, so this block runs after it.
            raised.fulfill()
        }
        wait(for: [raised], timeout: 5)

        XCTAssertNil(result.errorMessage)
        XCTAssertEqual(titles, ["Safari — GitHub", "Code — notes.py"])
        XCTAssertEqual(actionResult, .ran)
        XCTAssertEqual(raisedLock.withLock { raisedWindowTitles }, ["notes.py"])
    }

    func test_should_expose_window_attributes() {
        _ = python("import something\nws = something.windows()")

        XCTAssertEqual(pythonValue("[(w.app_name, w.title) for w in ws]"), "[('Safari', 'GitHub'), ('Code', 'notes.py')]\n")
        XCTAssertEqual(pythonValue("ws[0].pid == " + "\(getpid())"), "True\n")
    }

    func test_should_pass_titles_with_quotes_slashes_and_non_ascii_through_json() {
        listedWindows = [makeWindow("App", "a \"b\" c/d \\ é — \u{1F600}")]

        _ = python("import something\nws = something.windows()")

        XCTAssertEqual(pythonValue("ws[0].title == 'a \"b\" c/d \\\\ é — \u{1F600}'"), "True\n")
    }

    func test_should_raise_runtime_error_when_focusing_a_stale_window() {
        _ = python("import something\nold = something.windows()[0]\nsomething.windows()\nsomething.windows()")

        let result = python("old.focus()")

        XCTAssertEqual(result.errorMessage?.hasPrefix("RuntimeError"), true)
        XCTAssertEqual(raisedLock.withLock { raisedWindowTitles }, [])
    }

    func test_should_keep_the_previous_window_list_usable() {
        _ = python("import something\nold = something.windows()[0]\nsomething.windows()")
        let raised = expectation(description: "the window is raised")

        let result = python("old.focus()")
        DispatchQueue.main.async { raised.fulfill() }
        wait(for: [raised], timeout: 5)

        XCTAssertNil(result.errorMessage)
        XCTAssertEqual(raisedLock.withLock { raisedWindowTitles }, ["GitHub"])
    }

    func test_should_run_an_action_that_sets_a_python_variable() {
        _ = python(
            """
            import something
            state = []
            def mark():
                state.append("ran")
            something.add_source("demo", lambda: [something.Candidate("mark", action=mark)])
            """)
        let collection = interpreter.collectExtensionItems()
        let index = collection.items.first?.action ?? -1

        let result = interpreter.runExtensionAction(generation: collection.generation, index: index)

        XCTAssertEqual(result, .ran)
        XCTAssertEqual(pythonValue("state"), "['ran']\n")
    }

    func test_should_give_a_row_without_an_action_no_action_index() {
        _ = python("import something\nsomething.add_source('demo', lambda: [something.Candidate('plain')])")

        let collection = interpreter.collectExtensionItems()

        XCTAssertEqual(collection.items.map(\.action), [nil])
    }

    func test_should_replace_a_source_added_again_under_the_same_name() {
        _ = python(
            """
            import something
            something.add_source("demo", lambda: [something.Candidate("old")])
            something.add_source("demo", lambda: [something.Candidate("new")])
            """)

        let collection = interpreter.collectExtensionItems()

        XCTAssertEqual(collection.items.map(\.title), ["new"])
    }

    func test_should_drop_a_removed_source() {
        _ = python(
            """
            import something
            something.add_source("demo", lambda: [something.Candidate("row")])
            something.remove_source("demo")
            something.remove_source("never added")
            """)

        let collection = interpreter.collectExtensionItems()

        XCTAssertEqual(collection.items, [])
    }

    func test_should_report_a_raising_source_and_still_list_the_others() {
        _ = python(
            """
            import something
            def broken():
                raise ValueError("boom")
            something.add_source("a broken", broken)
            something.add_source("b fine", lambda: [something.Candidate("fine")])
            """)

        let collection = interpreter.collectExtensionItems()

        XCTAssertEqual(collection.items.map(\.title), ["fine"])
        XCTAssertEqual(
            collection.errors, [ScriptSourceError(source: "a broken", message: "ValueError: boom")])
    }

    func test_should_start_a_new_generation_on_each_collection() {
        _ = python("import something")

        let first = interpreter.collectExtensionItems()
        let second = interpreter.collectExtensionItems()

        XCTAssertEqual(second.generation, first.generation + 1)
    }

    func test_should_report_stale_for_a_generation_two_collections_old() {
        _ = python(
            "import something\nsomething.add_source('demo', lambda: [something.Candidate('row', action=lambda: None)])")
        let first = interpreter.collectExtensionItems()
        _ = interpreter.collectExtensionItems()
        _ = interpreter.collectExtensionItems()

        let result = interpreter.runExtensionAction(generation: first.generation, index: 0)

        XCTAssertEqual(result, .stale)
    }

    func test_should_still_run_an_action_of_the_previous_generation() {
        _ = python(
            "import something\nsomething.add_source('demo', lambda: [something.Candidate('row', action=lambda: None)])")
        let first = interpreter.collectExtensionItems()
        _ = interpreter.collectExtensionItems()

        let result = interpreter.runExtensionAction(generation: first.generation, index: 0)

        XCTAssertEqual(result, .ran)
    }

    func test_should_report_stale_for_an_unknown_index() {
        _ = python("import something")
        let collection = interpreter.collectExtensionItems()

        let result = interpreter.runExtensionAction(generation: collection.generation, index: 5)

        XCTAssertEqual(result, .stale)
    }

    func test_should_report_a_raising_action_as_failed() {
        _ = python(
            """
            import something
            def boom():
                raise KeyError("nope")
            something.add_source("demo", lambda: [something.Candidate("row", action=boom)])
            """)
        let collection = interpreter.collectExtensionItems()

        let result = interpreter.runExtensionAction(generation: collection.generation, index: 0)

        guard case .failed(let message) = result else {
            return XCTFail("Expected a failure, got \(result)")
        }
        XCTAssertTrue(message.hasPrefix("KeyError"), message)
    }

    func test_should_forget_sources_after_reset_but_import_the_module_again() {
        _ = python("import something\nsomething.add_source('demo', lambda: [something.Candidate('row')])")
        interpreter.reset()

        let result = python("import something\nsomething.add_source('again', lambda: [something.Candidate('x')])")
        let collection = interpreter.collectExtensionItems()

        XCTAssertNil(result.errorMessage)
        XCTAssertEqual(collection.items.map(\.source), ["again"])
    }

    func test_should_run_an_init_file_in_the_scratch_namespace() throws {
        let url = try makeTemporaryFile(
            "import something\nfrom_init = 42\nsomething.add_source('init', lambda: [something.Candidate('from init')])\n")

        let error = interpreter.runInitFile(at: url)

        XCTAssertNil(error)
        XCTAssertEqual(pythonValue("from_init"), "42\n")
        XCTAssertEqual(interpreter.collectExtensionItems().items.map(\.title), ["from init"])
    }

    func test_should_do_nothing_for_a_missing_init_file() {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("\(UUID().uuidString)/init.py")

        let error = interpreter.runInitFile(at: url)

        XCTAssertNil(error)
    }

    func test_should_report_an_init_file_error() throws {
        let url = try makeTemporaryFile("1 / 0\n")

        let error = interpreter.runInitFile(at: url)

        XCTAssertEqual(error?.hasPrefix("ZeroDivisionError"), true)
    }

    func test_should_run_the_init_file_again_after_reset_when_asked() throws {
        let url = try makeTemporaryFile(
            "import something\nsomething.add_source('init', lambda: [something.Candidate('permanent')])\n")
        interpreter.runInitFile(at: url, rerunAfterReset: true)

        interpreter.reset()

        XCTAssertEqual(interpreter.collectExtensionItems().items.map(\.title), ["permanent"])
    }

    func test_should_not_run_the_init_file_after_reset_by_default() throws {
        let url = try makeTemporaryFile("later = 1\n")
        interpreter.runInitFile(at: url)

        interpreter.reset()

        let result = interpreter.run(PythonBlock(lastStatement: "later"))
        XCTAssertEqual(result.errorMessage?.hasPrefix("NameError"), true)
    }
}
