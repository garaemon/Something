import Foundation

/// Python source to run as one scratch block.
struct PythonBlock: Equatable {
    /// Statements that run first without echoing any value.
    var leadingSource = ""
    /// The final top-level statement. When it is an expression, its value is echoed.
    var lastStatement: String
}

/// What one run of a block printed, and how it failed.
struct PythonRunResult: Equatable {
    /// Printed text plus the echoed value of the last expression, if any.
    let output: String
    /// The last line of the traceback, such as `ZeroDivisionError: ...`, or nil on success.
    let errorMessage: String?
}

/// Runs Python blocks on one embedded pocketpy VM, whose variables persist between runs.
///
/// pocketpy keeps its VM and callbacks in process-wide C state, so the app has a single
/// shared interpreter, and every call runs on its serial queue. Calls block the caller
/// until the run ends, so call them off the main thread.
final class PythonInterpreter {
    static let shared = PythonInterpreter()

    private static let sourceFilename = "<scratch>"

    private let queue = DispatchQueue(label: "com.garaemon.Something.python")

    private init() {
        queue.sync {
            py_initialize()
            Self.installCallbacks()
        }
    }

    /// Runs `block`, and stops it with `TimeoutError` after `timeoutMilliseconds`.
    ///
    /// The last statement does not run when the leading source raises.
    func run(_ block: PythonBlock, timeoutMilliseconds: Int = 2000) -> PythonRunResult {
        queue.sync {
            PythonOutputCapture.text = ""
            py_watchdog_begin(Int64(timeoutMilliseconds))
            defer { py_watchdog_end() }
            let succeeded =
                Self.execute(block.leadingSource, mode: EXEC_MODE)
                && Self.execute(block.lastStatement, mode: SINGLE_MODE)
            let errorMessage = succeeded ? nil : Self.takeErrorMessage()
            return PythonRunResult(output: PythonOutputCapture.text, errorMessage: errorMessage)
        }
    }

    /// Discards every variable, function, and import of earlier runs.
    func reset() {
        queue.sync {
            py_resetvm()
            Self.installCallbacks()
        }
    }

    // SINGLE_MODE prints the value of an expression statement through the print
    // callback, the way the interactive prompt does.
    private static func execute(_ source: String, mode: py_CompileMode) -> Bool {
        if source.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return true
        }
        return py_exec(source, sourceFilename, mode, nil)
    }

    private static func takeErrorMessage() -> String {
        defer { py_clearexc(nil) }
        guard let traceback = py_formatexc() else {
            return "Error"
        }
        defer { free(traceback) }
        let lines = String(cString: traceback).split(separator: "\n")
        return lines.last.map(String.init) ?? "Error"
    }

    private static func installCallbacks() {
        py_callbacks().pointee.print = { text in
            guard let text else {
                return
            }
            PythonOutputCapture.text += String(cString: text)
        }
    }
}

// The print callback is a C function pointer, which cannot capture the interpreter,
// so printed text collects here. Only the interpreter queue touches it.
private enum PythonOutputCapture {
    static var text = ""
}
