import Cocoa
import Combine
import HotKey
import SwiftUI

// Remove NSWindowDelegate conformance from AppDelegate
@MainActor
class AppDelegate: NSObject, NSApplicationDelegate {
    private(set) var myHotKey: HotKey?
    // Tests replace the settings to keep off the user's real UserDefaults.
    var settings = AppSettings()
    // Written only by AppDelegate+Settings.swift.
    var settingsWindow: NSWindow?
    var settingsWindowCloseObserver: NSObjectProtocol?
    private var settingsSubscriptions: Set<AnyCancellable> = []
    // Tests replace the store to keep off the user's real scratch file.
    var scratchStore = ScratchStore.makeDefault()
    private(set) var scratchWindowController: ScratchWindowController?
    var window: NSWindow?  // Keep a reference to the window
    // Add a strong reference to the new window controller
    var windowController: SomethingWindowController?
    // The mascot stands on or beside the launcher in a window of its own.
    private(set) var mascotPanel: MascotPanel?
    // Tests replace the catalog to avoid scanning the real application folders.
    var applicationCatalog = ApplicationCatalog.makeDefault()
    var windowCatalog = WindowCatalog.makeDefault()
    var repositoryCatalog = RepositoryCatalog.makeDefault()
    var fileCatalog = FileCatalog.makeDefault()
    // Tests replace the random pick to get a fixed placement.
    var chooseMascotPlacement: ([MascotPlacement]) -> MascotPlacement = {
        $0.randomElement() ?? .top
    }
    // Tests replace the call to keep the test host's own activation policy.
    var applyActivationPolicy: (NSApplication.ActivationPolicy) -> Void =
        AppDelegate.switchActivationPolicy
    // The launcher shows the previous scan immediately, because scanning the
    // folders on the main thread delays the window after the hotkey.
    private var cachedApplications: [LaunchableApplication] = []
    // Walking the repositories folder or a file folder, such as ~/Documents,
    // touches many directories, which would delay the window on the main
    // thread. Each list loads on its own queue so that a slow walk does not
    // delay the other lists.
    private lazy var repositoryLoader = makeRepositoryLoader()
    private lazy var fileLoader = makeFileLoader()
    private(set) var launcherViewModel: LauncherViewModel?
    // A serial queue delivers scans in the order they started, so a slow
    // older scan never overwrites a newer result.
    private let applicationScanQueue = DispatchQueue(
        label: "com.garaemon.Something.applicationScan",
        qos: .userInitiated
    )
    // Windows get their own queue so that a slow folder scan does not delay
    // the window list, which the user expects right after the hotkey.
    private let windowListQueue = DispatchQueue(
        label: "com.garaemon.Something.windowList",
        qos: .userInitiated
    )

    func applicationDidFinishLaunching(_ aNotification: Notification) {
        refreshApplicationsInBackground()
        repositoryLoader.refresh()
        fileLoader.refresh()
        startObservingSettings()
    }

    /// Registers the hot key from the settings, and registers it again whenever
    /// the settings change it or start recording a new one. Also rescans the
    /// repositories or the files whenever the settings change their folders,
    /// and shows or hides the Dock icon as the settings say.
    func startObservingSettings() {
        settingsSubscriptions.removeAll()
        // @Published emits before the property changes, so the sinks use the
        // emitted value instead of reading the settings back.
        settings.$hotKeyCombo
            .removeDuplicates()
            .sink { [weak self] keyCombo in self?.registerHotKey(keyCombo) }
            .store(in: &settingsSubscriptions)
        settings.$isRecordingHotKey
            .removeDuplicates()
            .sink { [weak self] isRecording in self?.myHotKey?.isPaused = isRecording }
            .store(in: &settingsSubscriptions)
        settings.$shouldShowDockIcon
            .removeDuplicates()
            .sink { [weak self] shouldShowDockIcon in
                self?.applyActivationPolicy(shouldShowDockIcon ? .regular : .accessory)
            }
            .store(in: &settingsSubscriptions)
        settings.$repositoryRootPath
            .removeDuplicates()
            .dropFirst()
            .sink { [weak self] rootPath in self?.repositoryLoader.refresh(pendingKey: rootPath) }
            .store(in: &settingsSubscriptions)
        settings.$fileFolderPaths
            .removeDuplicates()
            .dropFirst()
            .sink { [weak self] folderPaths in self?.fileLoader.refresh(pendingKey: folderPaths) }
            .store(in: &settingsSubscriptions)
    }

    private func registerHotKey(_ keyCombo: KeyCombo) {
        // Releasing the old HotKey unregisters it from Carbon.
        myHotKey = nil
        let hotKey = HotKey(keyCombo: keyCombo)
        hotKey.keyDownHandler = { [weak self] in
            self?.openWindow()
        }
        if settings.isRecordingHotKey {
            hotKey.isPaused = true
        }
        myHotKey = hotKey
    }

    func openWindow() {
        if let existingWindow = window, existingWindow.isVisible {
            NSApplication.shared.activate()
            existingWindow.makeKeyAndOrderFront(nil)
            return
        }

        let newWindow = NSWindow(
            contentRect: NSRect(origin: .zero, size: LauncherView.minimumSize),
            styleMask: [.titled, .closable, .resizable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        newWindow.center()
        newWindow.setFrameAutosaveName("SomethingWindow")
        // ARC owns the window through `window`. Letting AppKit also release it on
        // close over-releases it and crashes when the autorelease pool drains.
        newWindow.isReleasedWhenClosed = false

        // Add this line to disable window restoration for this window
        newWindow.restorationClass = nil

        // Create an instance of the new window controller
        let newWindowController = SomethingWindowController()
        // Set the delegate of the new window to the new controller instance
        newWindow.delegate = newWindowController

        // Set the closure for when the window should be released
        newWindowController.onWindowRelease = { [weak self] in
            self?.closeMascotPanel()
            // When the window is released (hidden/closed), nil out the references
            self?.window?.orderOut(nil)  // Ensure it's hidden if not already
            self?.window = nil
            self?.windowController = nil  // Release the strong reference to the controller
            self?.launcherViewModel = nil
        }

        newWindow.contentView = NSHostingView(rootView: makeLauncherView(in: newWindow))
        // Rescan on every open so that newly installed applications reach the
        // open launcher when the scan finishes.
        refreshApplicationsInBackground()
        refreshWindowsInBackground()
        repositoryLoader.refresh()
        fileLoader.refresh()

        // Activate before ordering the window front so that the window becomes
        // key and the query field can take keyboard focus.
        NSApplication.shared.activate()
        newWindow.makeKeyAndOrderFront(nil)
        attachMascotPanel(to: newWindow, controller: newWindowController)

        self.window = newWindow  // Store reference to the new window
        self.windowController = newWindowController  // Store strong reference to the controller
    }

    // Attached after the launcher is ordered front so that the panel never competes
    // for key status; it also cannot become key by itself.
    private func attachMascotPanel(to launcher: NSWindow, controller: SomethingWindowController) {
        guard let viewModel = launcherViewModel else { return }
        // Only placements that fit on the screen are offered, so that the robot is not clipped.
        let candidates =
            launcher.screen.map {
                MascotPanelLayout.placements(
                    fittingLauncherFrame: launcher.frame,
                    within: $0.visibleFrame
                )
            } ?? MascotPlacement.allCases
        let panel = MascotPanel.make(
            viewModel: viewModel,
            launcherFrame: launcher.frame,
            placement: chooseMascotPlacement(candidates),
            model: settings.mascotModel
        )
        launcher.addChildWindow(panel, ordered: .above)
        mascotPanel = panel
        controller.onWindowResize = { [weak self, weak launcher] in
            guard let launcher else { return }
            self?.mascotPanel?.reposition(forLauncherFrame: launcher.frame)
        }
    }

    // Safe to call twice, because both close and resign-key release the window.
    private func closeMascotPanel() {
        guard let panel = mascotPanel else { return }
        mascotPanel = nil
        window?.removeChildWindow(panel)
        // Dropping the content stops the SceneKit view from rendering.
        panel.contentView = nil
        panel.orderOut(nil)
        panel.close()
    }

    private func makeLauncherView(in window: NSWindow) -> LauncherView {
        let viewModel = LauncherViewModel(sources: [
            // The result comes first, as in Raycast: an expression rarely
            // matches a window or an application, and Return copies it.
            CalculatorSource(copyText: Self.copyTextToPasteboard),
            Self.makeWindowSource([]),
            Self.makeApplicationSource(cachedApplications),
            Self.makeRepositorySource(repositoryLoader.cachedItems),
            Self.makeFileSource(fileLoader.cachedItems),
            SettingsSource(openSettings: { [weak self] in self?.openSettings() }),
            ScratchSource(openScratch: { [weak self] in self?.openScratch() }),
            WebSearchSource(
                engines: WebSearchEngine.launcherEngines,
                openURL: { NSWorkspace.shared.open($0) }
            ),
        ])
        launcherViewModel = viewModel
        return LauncherView(viewModel: viewModel, dismiss: { [weak window] in window?.close() })
    }

    private func refreshApplicationsInBackground() {
        let catalog = applicationCatalog
        applicationScanQueue.async { [weak self] in
            let applications = catalog.loadApplications()
            DispatchQueue.main.async {
                self?.cachedApplications = applications
                self?.launcherViewModel?.replaceSource(Self.makeApplicationSource(applications))
            }
        }
    }

    private func makeRepositoryLoader() -> BackgroundListLoader<String, GhqRepository> {
        let loader = BackgroundListLoader<String, GhqRepository>(
            queueLabel: "com.garaemon.Something.repositoryList",
            readKey: { [weak self] in self?.settings.repositoryRootPath ?? "" },
            makeLoadFunction: { [weak self] in
                let catalog = self?.repositoryCatalog
                return { rootPath in
                    catalog?.loadRepositories(URL(fileURLWithPath: rootPath, isDirectory: true))
                        ?? []
                }
            }
        )
        loader.onItemsLoaded = { [weak self] repositories in
            self?.launcherViewModel?.replaceSource(Self.makeRepositorySource(repositories))
        }
        return loader
    }

    private func makeFileLoader() -> BackgroundListLoader<[String], LocalFile> {
        let loader = BackgroundListLoader<[String], LocalFile>(
            queueLabel: "com.garaemon.Something.fileList",
            readKey: { [weak self] in self?.settings.fileFolderPaths ?? [] },
            makeLoadFunction: { [weak self] in
                let catalog = self?.fileCatalog
                return { folderPaths in
                    catalog?.loadFiles(
                        folderPaths.map { URL(fileURLWithPath: $0, isDirectory: true) }
                    ) ?? []
                }
            }
        )
        loader.onItemsLoaded = { [weak self] files in
            self?.launcherViewModel?.replaceSource(Self.makeFileSource(files))
        }
        return loader
    }

    // Windows are not cached, because they open, close, and change titles
    // far more often than applications are installed. A load that outlives
    // its launcher is dropped, because its windows may have closed since.
    private func refreshWindowsInBackground() {
        let catalog = windowCatalog
        let targetViewModel = launcherViewModel
        windowListQueue.async { [weak self] in
            let windows = catalog.loadWindows()
            DispatchQueue.main.async {
                guard let self, let targetViewModel,
                    self.launcherViewModel === targetViewModel
                else { return }
                targetViewModel.replaceSource(Self.makeWindowSource(windows))
            }
        }
    }
}

// Sources and actions of launcher candidates. They keep no state of the delegate.
extension AppDelegate {
    private static func copyTextToPasteboard(_ text: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
    }

    private static func makeWindowSource(_ windows: [SwitchableWindow]) -> WindowSource {
        WindowSource(windows: windows, raiseWindow: WindowRaiser.raiseWindow)
    }

    private static func makeApplicationSource(
        _ applications: [LaunchableApplication]
    ) -> ApplicationSource {
        ApplicationSource(applications: applications, launchApplication: launchApplication)
    }

    private static func makeRepositorySource(_ repositories: [GhqRepository]) -> RepositorySource {
        RepositorySource(repositories: repositories, openRepository: openRepository)
    }

    private static func makeFileSource(_ files: [LocalFile]) -> FileSource {
        FileSource(
            files: files,
            openFile: openFile,
            revealFile: { NSWorkspace.shared.activateFileViewerSelecting([$0.url]) }
        )
    }

    private static func launchApplication(_ application: LaunchableApplication) {
        NSWorkspace.shared.openApplication(
            at: application.url,
            configuration: NSWorkspace.OpenConfiguration()
        ) { _, error in
            guard let error else { return }
            NSLog("Failed to launch %@: %@", application.url.path, error.localizedDescription)
        }
    }

    private static func openRepository(_ repository: GhqRepository) {
        guard !NSWorkspace.shared.open(repository.url) else { return }
        NSLog("Failed to open %@", repository.url.path)
    }

    private static func openFile(_ file: LocalFile) {
        guard !NSWorkspace.shared.open(file.url) else { return }
        NSLog("Failed to open %@", file.url.path)
    }
}

extension AppDelegate {
    /// Shows the Python scratch window, creating it on first use, or again when the last
    /// window could not read the scratch file.
    func openScratch() {
        let controller =
            scratchWindowController?.reuseIfShowingFile()
            ?? ScratchWindowController(store: scratchStore)
        scratchWindowController = controller
        controller.show()
    }

    func applicationWillTerminate(_ notification: Notification) {
        scratchWindowController?.saveNow()
    }
}
