import Combine
import HotKey
import Cocoa
import SwiftUI

// Remove NSWindowDelegate conformance from AppDelegate
@MainActor
class AppDelegate: NSObject, NSApplicationDelegate {
    private(set) var myHotKey: HotKey?
    // Tests replace the settings to keep off the user's real UserDefaults.
    var settings = AppSettings()
    private(set) var settingsWindow: NSWindow?
    private var settingsWindowCloseObserver: NSObjectProtocol?
    private var settingsSubscriptions: Set<AnyCancellable> = []
    var window: NSWindow? // Keep a reference to the window
    // Add a strong reference to the new window controller
    var windowController: SomethingWindowController?
    // The mascot stands on or beside the launcher in a window of its own.
    private(set) var mascotPanel: MascotPanel?
    // Tests replace the catalog to avoid scanning the real application folders.
    var applicationCatalog = ApplicationCatalog.makeDefault()
    var windowCatalog = WindowCatalog.makeDefault()
    var repositoryCatalog = RepositoryCatalog.makeDefault()
    // Tests replace the random pick to get a fixed placement.
    var chooseMascotPlacement: ([MascotPlacement]) -> MascotPlacement = { $0.randomElement() ?? .top }
    // The launcher shows the previous scan immediately, because scanning the
    // folders on the main thread delays the window after the hotkey.
    private var cachedApplications: [LaunchableApplication] = []
    // Walking the repositories folder touches many directories, which would
    // delay the window on the main thread.
    private var cachedRepositories: [GhqRepository] = []
    // A scan of a large repositories folder can outlast a hotkey press, so
    // repeated presses would otherwise pile up stale scans on the serial queue.
    private var isLoadingRepositories = false
    private(set) var launcherViewModel: LauncherViewModel?
    // A serial queue delivers scans in the order they started, so a slow
    // older scan never overwrites a newer result.
    private let applicationScanQueue = DispatchQueue(
        label: "com.garaemon.Something.applicationScan", qos: .userInitiated)
    // Windows get their own queue so that a slow folder scan does not delay
    // the window list, which the user expects right after the hotkey.
    private let windowListQueue = DispatchQueue(
        label: "com.garaemon.Something.windowList", qos: .userInitiated)
    // isLoadingRepositories already keeps scans one at a time; the queue is
    // separate so that a slow repositories folder walk does not delay the
    // other lists.
    private let repositoryListQueue = DispatchQueue(
        label: "com.garaemon.Something.repositoryList", qos: .userInitiated)

    func applicationDidFinishLaunching(_ aNotification: Notification) {
        // Change the activation policy to .accessory
        // This allows the app to become active and its windows to gain/lose focus,
        // while still keeping it out of the Dock.
        NSApplication.shared.setActivationPolicy(.accessory)
        refreshApplicationsInBackground()
        refreshRepositoriesInBackground()
        startObservingSettings()
    }

    /// Registers the hot key from the settings, and registers it again whenever
    /// the settings change it or start recording a new one. Also rescans the
    /// repositories whenever the settings change their folder.
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
        settings.$repositoryRootPath
            .removeDuplicates()
            .dropFirst()
            .sink { [weak self] rootPath in self?.refreshRepositoriesInBackground(pendingRootPath: rootPath) }
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

    /// Shows the settings window, creating it on first use.
    func openSettings() {
        let window = settingsWindow ?? makeSettingsWindow()
        settingsWindow = window
        if window.contentView == nil {
            window.contentView = makeSettingsContentView()
        }
        NSApplication.shared.activate()
        window.makeKeyAndOrderFront(nil)
    }

    private func makeSettingsWindow() -> NSWindow {
        let window = NSWindow(
            contentRect: .zero, styleMask: [.titled, .closable], backing: .buffered, defer: false)
        window.title = SettingsSource.candidateName
        // Kept alive by `settingsWindow` so that a reopen keeps its position.
        window.isReleasedWhenClosed = false
        window.contentView = makeSettingsContentView()
        window.center()
        // Drops the content of the closed window. The mascot preview inside
        // keeps SceneKit's render loop running for as long as the view lives.
        settingsWindowCloseObserver = NotificationCenter.default.addObserver(
            forName: NSWindow.willCloseNotification, object: window, queue: .main
        ) { [weak window] _ in
            MainActor.assumeIsolated { window?.contentView = nil }
        }
        return window
    }

    private func makeSettingsContentView() -> NSView {
        NSHostingView(rootView: SettingsView(settings: settings))
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
            backing: .buffered, defer: false)
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
            self?.window?.orderOut(nil) // Ensure it's hidden if not already
            self?.window = nil
            self?.windowController = nil // Release the strong reference to the controller
            self?.launcherViewModel = nil
        }

        newWindow.contentView = NSHostingView(rootView: makeLauncherView(in: newWindow))
        // Rescan on every open so that newly installed applications reach the
        // open launcher when the scan finishes.
        refreshApplicationsInBackground()
        refreshWindowsInBackground()
        refreshRepositoriesInBackground()

        // Activate before ordering the window front so that the window becomes
        // key and the query field can take keyboard focus.
        NSApplication.shared.activate()
        newWindow.makeKeyAndOrderFront(nil)
        attachMascotPanel(to: newWindow, controller: newWindowController)

        self.window = newWindow // Store reference to the new window
        self.windowController = newWindowController // Store strong reference to the controller
    }

    // Attached after the launcher is ordered front so that the panel never competes
    // for key status; it also cannot become key by itself.
    private func attachMascotPanel(to launcher: NSWindow, controller: SomethingWindowController) {
        guard let viewModel = launcherViewModel else { return }
        // Only placements that fit on the screen are offered, so that the robot is not clipped.
        let candidates = launcher.screen.map {
            MascotPanelLayout.placements(fittingLauncherFrame: launcher.frame, within: $0.visibleFrame)
        } ?? MascotPlacement.allCases
        let panel = MascotPanel.make(
            viewModel: viewModel, launcherFrame: launcher.frame,
            placement: chooseMascotPlacement(candidates), model: settings.mascotModel)
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
            Self.makeWindowSource([]),
            Self.makeApplicationSource(cachedApplications),
            Self.makeRepositorySource(cachedRepositories),
            SettingsSource(openSettings: { [weak self] in self?.openSettings() }),
            WebSearchSource(engines: WebSearchEngine.launcherEngines, openURL: { NSWorkspace.shared.open($0) }),
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

    // The settings sink passes pendingRootPath, because @Published emits
    // before the setting holds the new folder.
    private func refreshRepositoriesInBackground(pendingRootPath: String? = nil) {
        guard !isLoadingRepositories else { return }
        isLoadingRepositories = true
        let catalog = repositoryCatalog
        let scannedRootPath = pendingRootPath ?? settings.repositoryRootPath
        let rootDirectory = URL(fileURLWithPath: scannedRootPath, isDirectory: true)
        repositoryListQueue.async { [weak self] in
            let repositories = catalog.loadRepositories(rootDirectory)
            DispatchQueue.main.async {
                self?.finishRepositoryRefresh(repositories, scannedRootPath: scannedRootPath)
            }
        }
    }

    // A root change during a scan was skipped by the isLoadingRepositories
    // guard, so the stale result is dropped and the new root is scanned.
    private func finishRepositoryRefresh(_ repositories: [GhqRepository], scannedRootPath: String) {
        isLoadingRepositories = false
        guard scannedRootPath == settings.repositoryRootPath else {
            refreshRepositoriesInBackground()
            return
        }
        cachedRepositories = repositories
        launcherViewModel?.replaceSource(Self.makeRepositorySource(repositories))
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

    private static func makeWindowSource(_ windows: [SwitchableWindow]) -> WindowSource {
        WindowSource(windows: windows, raiseWindow: WindowRaiser.raiseWindow)
    }

    private static func makeApplicationSource(_ applications: [LaunchableApplication]) -> ApplicationSource {
        ApplicationSource(applications: applications, launchApplication: launchApplication)
    }

    private static func makeRepositorySource(_ repositories: [GhqRepository]) -> RepositorySource {
        RepositorySource(repositories: repositories, openRepository: openRepository)
    }

    private static func launchApplication(_ application: LaunchableApplication) {
        NSWorkspace.shared.openApplication(
            at: application.url, configuration: NSWorkspace.OpenConfiguration()
        ) { _, error in
            guard let error else { return }
            NSLog("Failed to launch %@: %@", application.url.path, error.localizedDescription)
        }
    }

    private static func openRepository(_ repository: GhqRepository) {
        guard !NSWorkspace.shared.open(repository.url) else { return }
        NSLog("Failed to open %@", repository.url.path)
    }
}
