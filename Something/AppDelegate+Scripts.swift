import Foundation

// The Python extensions of the launcher: the init file, the list of Python rows, and their
// actions. They live here to keep AppDelegate.swift within the file length limit.
//
// `scriptLoader` lists the rows in the background, because the listing calls Python, which
// can run until its timeout. `scriptQueue` runs the init file and the picked actions, one at
// a time in the order of the picks.
extension AppDelegate {
    func makeScriptLoader() -> BackgroundListLoader<String, ScriptItem> {
        let loader = BackgroundListLoader<String, ScriptItem>(
            queueLabel: "com.garaemon.Something.scriptList",
            // Nothing in the settings changes the Python sources, so the key never changes.
            readKey: { "" },
            makeLoadFunction: { [weak self] in
                let catalog = self?.scriptCatalog
                return { _ in catalog?.loadItems() ?? [] }
            }
        )
        loader.onItemsLoaded = { [weak self] items in
            guard let self else { return }
            launcherViewModel?.replaceSource(makeScriptSource(items))
        }
        return loader
    }

    // The init file defines the Python sources, so the first list waits for it. Both run on
    // the queue of the actions, which is serial, and which a slow init file may hold up.
    func runScriptInitFileInBackground() {
        let catalog = scriptCatalog
        scriptQueue.async { [weak self] in
            catalog.runInitFile()
            DispatchQueue.main.async { self?.scriptLoader.refresh() }
        }
    }

    // The action runs off the main thread, because Python can run until its timeout.
    func makeScriptSource(_ items: [ScriptItem]) -> ScriptSource {
        let catalog = scriptCatalog
        return ScriptSource(
            items: items,
            runAction: { [scriptQueue] generation, index in
                scriptQueue.async { catalog.runAction(generation, index) }
            }
        )
    }
}
