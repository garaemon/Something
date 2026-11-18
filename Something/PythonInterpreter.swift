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
    /// The type and message of the exception, such as `ZeroDivisionError: ...`, without
    /// the stack frames, or nil on success. A message with line breaks spans several lines.
    let errorMessage: String?
}

/// Runs Python blocks on one embedded pocketpy VM, whose variables persist between runs.
///
/// pocketpy keeps its VM and callbacks in process-wide C state, so the app has a single
/// shared interpreter, and every call runs on its serial queue. Calls block the caller
/// until the run ends, so call them off the main thread.
final class PythonInterpreter {
    static let shared = PythonInterpreter()

    /// The most printed output, in UTF-8 bytes, that one run keeps.
    static let maxOutputByteCount = 100_000
    /// Text that ends the output of a run that printed more than `maxOutputByteCount`.
    static let truncationNotice = "[output truncated]\n"

    private static let sourceFilename = "<scratch>"

    // Internal, so that the extension API in PythonInterpreter+Extensions.swift runs on it too.
    let queue = DispatchQueue(label: "com.garaemon.Something.python")

    /// The init file to run again after every `reset()`, so that permanent extensions survive
    /// a reset. Nil runs none. Only the interpreter queue touches it.
    var initFileURLToRunOnReset: URL?

    private init() {
        queue.sync {
            py_initialize()
            Self.installCallbacks()
            Self.replaceExit()
            Self.installExtensions()
        }
    }

    /// Runs `block`, and stops it with `TimeoutError` once it uses up `timeoutMilliseconds`.
    ///
    /// The last statement does not run when the leading source raises. `input()` reads an
    /// empty line instead of the standard input of the app.
    ///
    /// The pocketpy watchdog has two limits:
    /// - It counts the CPU time of the whole process, so busy threads elsewhere in the app
    ///   end a run early.
    /// - It checks the time between bytecodes only, so a long call into C, such as
    ///   `time.sleep(600)`, runs to the end and blocks the queue meanwhile.
    func run(_ block: PythonBlock, timeoutMilliseconds: Int = 2000) -> PythonRunResult {
        queue.sync {
            PythonOutputCapture.reset()
            py_watchdog_begin(Int64(timeoutMilliseconds))
            defer { py_watchdog_end() }
            let succeeded =
                Self.execute(block.leadingSource, mode: EXEC_MODE)
                && Self.execute(block.lastStatement, mode: SINGLE_MODE)
            let errorMessage = succeeded ? nil : Self.takeErrorMessage()
            let notice = PythonOutputCapture.isTruncated ? Self.truncationNotice : ""
            return PythonRunResult(
                output: PythonOutputCapture.text + notice,
                errorMessage: errorMessage
            )
        }
    }

    /// Discards every variable, function, and import of earlier runs, then installs the
    /// launcher extension API again and runs the init file registered for resets.
    func reset() {
        queue.sync {
            py_resetvm()
            Self.installCallbacks()
            Self.replaceExit()
            Self.installExtensions()
            if let url = initFileURLToRunOnReset {
                _ = runInitFileOnQueue(
                    at: url,
                    timeoutMilliseconds: Self.initFileTimeoutMilliseconds
                )
            }
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

    static func takeErrorMessage() -> String {
        defer { py_clearexc(nil) }
        guard let traceback = py_formatexc() else {
            return "Error"
        }
        defer { py_free(traceback) }
        let message = extractExceptionMessage(fromTraceback: String(cString: traceback))
        return message.isEmpty ? "Error" : message
    }

    // A chained exception prints one traceback per exception, so only the last one counts.
    // Stack frame lines are indented, and the message lines that follow them are not.
    private static func extractExceptionMessage(fromTraceback traceback: String) -> String {
        let lastTraceback =
            traceback.components(separatedBy: "Traceback (most recent call last):").last
            ?? traceback
        return lastTraceback.split(separator: "\n", omittingEmptySubsequences: false)
            .drop { line in line.isEmpty || line.first?.isWhitespace == true }
            .joined(separator: "\n")
            .trimmingCharacters(in: .newlines)
    }

    private static func installCallbacks() {
        py_callbacks().pointee.print = { text in
            guard let text else {
                return
            }
            PythonOutputCapture.append(String(cString: text))
        }
        // The default reads the standard input of the app, which waits forever when the
        // app runs from Xcode, and the watchdog cannot stop a wait inside C.
        py_callbacks().pointee.getchr = { EOF }
    }

    // The builtin exit() of pocketpy calls the C exit(), which would quit the whole app.
    // Raising SystemExit ends only the run, as the error of the block.
    private static func replaceExit() {
        let source = "def exit(code=0):\n    raise SystemExit(code)\n"
        let succeeded = py_exec(source, "<setup>", EXEC_MODE, py_getmodule("builtins"))
        precondition(succeeded, "Replacing the builtin exit() of pocketpy failed.")
    }
}

// The print callback is a C function pointer, which cannot capture the interpreter,
// so printed text collects here. Only the interpreter queue touches it.
private enum PythonOutputCapture {
    static private(set) var text = ""
    static private(set) var isTruncated = false
    private static var byteCount = 0

    static func reset() {
        text = ""
        isTruncated = false
        byteCount = 0
    }

    // A print loop can produce megabytes before the watchdog fires, and the scratch
    // view would then insert all of it.
    static func append(_ chunk: String) {
        guard !isTruncated else {
            return
        }
        let remainingByteCount = PythonInterpreter.maxOutputByteCount - byteCount
        let chunkByteCount = chunk.utf8.count
        if chunkByteCount <= remainingByteCount {
            text += chunk
            byteCount += chunkByteCount
            return
        }
        let head = takeUTF8Prefix(of: chunk, maxByteCount: remainingByteCount)
        text += head
        byteCount += head.utf8.count
        isTruncated = true
    }

    // Stops before a multibyte character that does not fit whole, so that the cut leaves
    // no broken character behind.
    private static func takeUTF8Prefix(of chunk: String, maxByteCount: Int) -> String {
        let bytes = chunk.utf8
        let fittingCutCount = (0...maxByteCount).reversed().first { cutCount in
            let cutIndex = bytes.index(bytes.startIndex, offsetBy: cutCount)
            return cutIndex.samePosition(in: chunk.unicodeScalars) != nil
        }
        return String(bytes.prefix(fittingCutCount ?? 0)) ?? ""
    }
}
