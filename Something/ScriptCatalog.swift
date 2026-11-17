import Foundation

/// The Python extensions of the launcher: the init file, the rows of the Python sources, and
/// their actions. A struct of closures, as the other catalogs are, so that tests keep the
/// interpreter and the real init file out of the app delegate.
struct ScriptCatalog {
    /// Runs the init file. Blocks until it ends, so call it off the main thread.
    let runInitFile: () -> Void
    /// Returns the current rows of the Python sources. Blocks, so call it off the main thread.
    let loadItems: () -> [ScriptItem]
    /// Runs the Python action with the given generation and index. Blocks, so call it off the
    /// main thread.
    let runAction: (_ generation: Int, _ index: Int) -> Void

    /// A catalog without any Python extension.
    static let empty = ScriptCatalog(
        runInitFile: {},
        loadItems: { [] },
        runAction: { _, _ in }
    )

    /// Returns `~/Library/Application Support/Something/init.py`, next to the scratch file.
    static func makeDefaultInitFileURL() -> URL {
        ScratchStore.makeDefault().fileURL.deletingLastPathComponent()
            .appendingPathComponent("init.py")
    }

    /// Returns a catalog on the shared interpreter, the one the scratch buffer uses.
    ///
    /// Failures go to the log, because the launcher has no place to show them yet.
    static func makeDefault(initFileURL: URL = makeDefaultInitFileURL()) -> ScriptCatalog {
        ScriptCatalog(
            runInitFile: {
                // A test host runs this app delegate too, and the real init file would then
                // leak into the interpreter tests through the rerun after each reset.
                guard ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] == nil
                else { return }
                // The result is already logged.
                PythonInterpreter.shared.runInitFile(at: initFileURL, rerunAfterReset: true)
            },
            loadItems: {
                let collection = PythonInterpreter.shared.collectExtensionItems()
                for error in collection.errors {
                    NSLog("Python source %@ failed: %@", error.source, error.message)
                }
                return collection.items
            },
            runAction: { generation, index in
                let result = PythonInterpreter.shared.runExtensionAction(
                    generation: generation,
                    index: index
                )
                switch result {
                case .ran: break
                case .stale: NSLog("Python action %d of generation %d is stale", index, generation)
                case .failed(let message): NSLog("Python action failed: %@", message)
                }
            }
        )
    }
}
