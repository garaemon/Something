import Foundation

/// What `PythonInterpreter.runExtensionAction` did.
enum ExtensionActionResult: Equatable {
    /// The Python action ran to the end.
    case ran
    /// The action belongs to a collection that is too old, or its index is unknown.
    case stale
    /// The action raised. The associated value is the exception, such as `KeyError: 'x'`.
    case failed(String)
}

// The launcher extension API. Python code in the scratch buffer and in the init file runs in
// the same VM as the scratch buffer, so that it can change the running launcher. The API is
// the Python module `something`, written in Python in `PythonExtensionPrelude`, on top of
// the hidden native module `_something_native`, which is a few flat functions bound here.
extension PythonInterpreter {
    /// The most time that the init file may run. Longer than a scratch block, because the
    /// init file may build lists or read files.
    static let initFileTimeoutMilliseconds = 5000

    /// Replaces how `something.windows()` lists windows and how `Window.focus()` raises one.
    /// The defaults use the Accessibility API. Tests replace them.
    ///
    /// `raiseWindow` runs on the main thread, and `focus()` does not wait for it, so that a
    /// run started from the main thread cannot deadlock against it.
    func useWindowProvider(
        loadWindows: @escaping () -> [SwitchableWindow],
        raiseWindow: @escaping (SwitchableWindow) -> Void
    ) {
        queue.sync {
            PythonWindowBridge.loadWindows = loadWindows
            PythonWindowBridge.raiseWindow = raiseWindow
        }
    }

    /// Runs the Python file at `url` in the main module, the one the scratch buffer uses.
    ///
    /// A missing file does nothing. With `rerunAfterReset`, every later `reset()` runs the
    /// file again, so that the extensions in it are permanent. Returns the exception, such
    /// as `NameError: ...`, or the reason that the file cannot be read, or nil on success.
    /// Failures also go to the log.
    @discardableResult
    func runInitFile(
        at url: URL,
        rerunAfterReset: Bool = false,
        timeoutMilliseconds: Int = PythonInterpreter.initFileTimeoutMilliseconds
    ) -> String? {
        queue.sync {
            if rerunAfterReset {
                initFileURLToRunOnReset = url
            }
            return runInitFileOnQueue(at: url, timeoutMilliseconds: timeoutMilliseconds)
        }
    }

    /// Stops `reset()` from running the init file again.
    func forgetInitFileForReset() {
        queue.sync { initFileURLToRunOnReset = nil }
    }

    /// Calls `something._collect()`, which asks every Python source for its rows.
    ///
    /// Never throws: when the call or its JSON fails, the result has no items and one error
    /// whose source is `something`.
    func collectExtensionItems(timeoutMilliseconds: Int = 2000) -> ScriptCollection {
        queue.sync {
            py_watchdog_begin(Int64(timeoutMilliseconds))
            defer { py_watchdog_end() }
            guard Self.callExtensionFunction("_collect", arguments: []) else {
                return Self.makeCollectionFailure(Self.takeErrorMessage())
            }
            guard let text = py_tostr(py_retval()) else {
                return Self.makeCollectionFailure("_collect() did not return a string")
            }
            do {
                return try ScriptCollection.decode(fromJSON: String(cString: text))
            } catch {
                return Self.makeCollectionFailure("Invalid collection: \(error)")
            }
        }
    }

    /// Calls the Python action at `index` of the collection `generation`.
    func runExtensionAction(
        generation: Int,
        index: Int,
        timeoutMilliseconds: Int = 2000
    ) -> ExtensionActionResult {
        queue.sync {
            py_watchdog_begin(Int64(timeoutMilliseconds))
            defer { py_watchdog_end() }
            guard Self.callExtensionFunction("_run_action", arguments: [generation, index]) else {
                return .failed(Self.takeErrorMessage())
            }
            return py_tobool(py_retval()) ? .ran : .stale
        }
    }

    // MARK: - Running on the queue

    // The caller already holds the queue, so that `reset()` can use it too.
    func runInitFileOnQueue(at url: URL, timeoutMilliseconds: Int) -> String? {
        let source: String
        do {
            source = try String(contentsOf: url, encoding: .utf8)
        } catch CocoaError.fileReadNoSuchFile {
            return nil
        } catch {
            let message = "Cannot read \(url.path): \(error.localizedDescription)"
            NSLog("%@", message)
            return message
        }
        py_watchdog_begin(Int64(timeoutMilliseconds))
        defer { py_watchdog_end() }
        guard py_exec(source, url.lastPathComponent, EXEC_MODE, nil) else {
            let message = Self.takeErrorMessage()
            NSLog("Init file %@ failed: %@", url.path, message)
            return message
        }
        return nil
    }

    private static func makeCollectionFailure(_ message: String) -> ScriptCollection {
        ScriptCollection(
            generation: 0,
            items: [],
            errors: [ScriptSourceError(source: "something", message: message)]
        )
    }

    // Calls a function of the `something` module with int arguments, and leaves its result in
    // `py_retval()`. The arguments go through the registers, which are contiguous, as
    // `py_call` expects. Returns false with the exception pending when the call raises.
    private static func callExtensionFunction(_ name: String, arguments: [Int]) -> Bool {
        guard let module = py_getmodule("something"),
            let function = py_getdict(module, py_name(name))
        else {
            return false
        }
        for (position, argument) in arguments.enumerated() {
            py_newint(py_getreg(Int32(position)), py_i64(argument))
        }
        return py_call(function, Int32(arguments.count), py_getreg(0))
    }

    // MARK: - Installing

    // `py_resetvm()` wipes every module, so this runs at init and after each reset.
    static func installExtensions() {
        let native = py_newmodule("_something_native")
        // The C function pointers cannot capture, so they reach their state through
        // `PythonWindowBridge`. They report errors by raising through the wrappers of the
        // bridging header, because Swift cannot import the macros and varargs of pocketpy.
        py_bindfunc(native, "list_windows") { argc, _ in
            guard argc == 0 else {
                return something_raise_type_error("list_windows() takes no arguments")
            }
            py_newstr(py_retval(), PythonWindowBridge.listWindowsJSON())
            return true
        }
        py_bindfunc(native, "focus_window") { argc, argv in
            guard argc == 1 else {
                return something_raise_type_error("focus_window() takes one argument")
            }
            guard something_check_int(argv) else {
                return false
            }
            py_newbool(py_retval(), PythonWindowBridge.focusWindow(handle: Int(py_toint(argv))))
            return true
        }
        let module = py_newmodule("something")
        let succeeded = py_exec(PythonExtensionPrelude.source, "<something>", EXEC_MODE, module)
        precondition(succeeded, "Installing the something module failed.")
    }
}

// The windows that Python has seen. Only the interpreter queue touches the state, except
// that `raiseWindow` runs on the main thread.
private enum PythonWindowBridge {
    // One catalog for every listing, because it asks for the Accessibility permission at most
    // once per catalog.
    private static let defaultCatalog = WindowCatalog.makeDefault()
    static var loadWindows: () -> [SwitchableWindow] = { defaultCatalog.loadWindows() }
    static var raiseWindow: (SwitchableWindow) -> Void = WindowRaiser.raiseWindow

    // Each listing starts a new table. The previous table stays, so that a window listed just
    // before another listing still works, and older ones go, so that memory stays bounded.
    private static let keptTableCount = 2
    private static var tables: [[Int: SwitchableWindow]] = []
    // Handles count up and are never reused, so a stale handle cannot name another window.
    private static var nextHandle = 1

    private struct Record: Encodable {
        let handle: Int
        let title: String
        let appName: String
        let pid: Int

        private enum CodingKeys: String, CodingKey {
            case handle, title, appName = "app_name", pid
        }
    }

    static func listWindowsJSON() -> String {
        var table: [Int: SwitchableWindow] = [:]
        var records: [Record] = []
        for window in loadWindows() {
            let handle = nextHandle
            nextHandle += 1
            table[handle] = window
            records.append(
                Record(
                    handle: handle,
                    title: sanitize(window.title),
                    appName: sanitize(window.applicationName),
                    pid: Int(window.processIdentifier)
                )
            )
        }
        tables.append(table)
        tables = Array(tables.suffix(keptTableCount))
        let encoder = JSONEncoder()
        // The JSON parser of pocketpy rejects the escapes `\/` and `\u`.
        encoder.outputFormatting = .withoutEscapingSlashes
        guard let data = try? encoder.encode(records) else {
            return "[]"
        }
        return String(decoding: data, as: UTF8.self)
    }

    // Returns false when the handle is not in the kept tables.
    static func focusWindow(handle: Int) -> Bool {
        guard let window = tables.lazy.compactMap({ $0[handle] }).first else {
            return false
        }
        let raiseWindow = raiseWindow
        DispatchQueue.main.async { raiseWindow(window) }
        return true
    }

    // The JSON encoder writes control characters as `\u00XX`, which pocketpy cannot parse.
    private static func sanitize(_ text: String) -> String {
        String(
            String.UnicodeScalarView(
                text.unicodeScalars.map { $0.value < 0x20 || $0.value == 0x7F ? " " : $0 }
            )
        )
    }
}
