import AppKit

extension AppDelegate {
    /// The screen that the settings choose for the launcher, or nil to keep the
    /// position that AppKit restored. Read before the launcher takes the key focus,
    /// because the frontmost application changes then.
    func launcherTargetScreen() -> NSScreen? {
        let screens = NSScreen.screens
        let screenFrames = screens.map(\.frame)
        let index: Int?
        switch settings.launcherScreenPlacement {
        case .lastPosition:
            return nil
        case .mouseScreen:
            index = LauncherScreenLayout.screenIndex(
                containing: NSEvent.mouseLocation,
                screenFrames: screenFrames
            )
        case .activeWindowScreen:
            index = Self.frontmostWindowFrame(primaryScreen: screens.first).flatMap {
                LauncherScreenLayout.screenIndex(mostOverlapping: $0, screenFrames: screenFrames)
            }
        case .primaryScreen:
            index = screens.isEmpty ? nil : 0
        }
        return index.map { screens[$0] } ?? NSScreen.main
    }

    /// Moves the launcher to the middle of `screen`, keeping its size.
    func place(launcher window: NSWindow, on screen: NSScreen) {
        let frame = LauncherScreenLayout.frame(
            size: window.frame.size,
            centeredIn: screen.visibleFrame
        )
        window.setFrame(frame, display: false)
    }

    // The window list gives the bounds of other applications' windows without the
    // Accessibility or Screen Recording permission. It lists windows front to back.
    private static func frontmostWindowFrame(primaryScreen: NSScreen?) -> CGRect? {
        guard
            let primaryScreen,
            let processID = NSWorkspace.shared.frontmostApplication?.processIdentifier,
            let windowInfos = CGWindowListCopyWindowInfo(
                [.optionOnScreenOnly, .excludeDesktopElements],
                kCGNullWindowID
            ) as? [[String: Any]]
        else { return nil }
        for info in windowInfos {
            // Layer 0 holds the normal windows; menus and panels sit above it.
            guard
                info[kCGWindowOwnerPID as String] as? pid_t == processID,
                info[kCGWindowLayer as String] as? Int == 0,
                let boundsDictionary = info[kCGWindowBounds as String] as? NSDictionary,
                let bounds = CGRect(dictionaryRepresentation: boundsDictionary)
            else { continue }
            return LauncherScreenLayout.appKitRect(
                fromWindowListBounds: bounds,
                primaryScreenHeight: primaryScreen.frame.height
            )
        }
        return nil
    }
}
