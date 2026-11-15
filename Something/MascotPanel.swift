import AppKit
import SwiftUI

/// A transparent, click-through window that holds the mascot above the launcher.
/// It must never become key or main: the launcher hides itself when it resigns key,
/// so a mascot that took key status would close the launcher.
final class MascotPanel: NSPanel {
    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }

    @MainActor
    static func make(viewModel: LauncherViewModel, launcherFrame: CGRect) -> MascotPanel {
        let panel = MascotPanel(
            contentRect: MascotPanelLayout.frame(forLauncherFrame: launcherFrame),
            styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        // ARC owns the panel, as with the launcher window.
        panel.isReleasedWhenClosed = false
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.ignoresMouseEvents = true

        let hostingView = NSHostingView(rootView: MascotOverlayView(viewModel: viewModel))
        // The panel's frame comes from the launcher layout, not from the SwiftUI content.
        hostingView.sizingOptions = []
        panel.contentView = hostingView
        return panel
    }

    func reposition(forLauncherFrame launcherFrame: CGRect) {
        setFrame(MascotPanelLayout.frame(forLauncherFrame: launcherFrame), display: true)
    }
}
