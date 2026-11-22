import AppKit
import SwiftUI

/// A transparent, click-through window that holds the mascot on or beside the launcher.
/// It must never become key or main: the launcher hides itself when it resigns key,
/// so a mascot that took key status would close the launcher.
final class MascotPanel: NSPanel {
    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }

    /// Fixed for the panel's lifetime, because the scene is built for it.
    private(set) var placement = MascotPlacement.top

    @MainActor
    static func make(
        viewModel: LauncherViewModel,
        launcherFrame: CGRect,
        placement: MascotPlacement,
        model: MascotModel
    ) -> MascotPanel {
        let panel = MascotPanel(
            contentRect: MascotPanelLayout.frame(
                forLauncherFrame: launcherFrame,
                placement: placement
            ),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        // ARC owns the panel, as with the launcher window.
        panel.isReleasedWhenClosed = false
        panel.placement = placement
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.ignoresMouseEvents = true
        // Hidden until SceneKit renders its first frame. The empty SCNView otherwise
        // shows as an opaque white square for up to about 150 ms after ordering front.
        panel.alphaValue = 0

        let hostingView = NSHostingView(
            rootView: MascotOverlayView(
                viewModel: viewModel,
                placement: placement,
                model: model,
                onFirstFrameRendered: { [weak panel] in panel?.revealContent() }
            )
        )
        // The panel's frame comes from the launcher layout, not from the SwiftUI content.
        hostingView.sizingOptions = []
        panel.contentView = hostingView
        return panel
    }

    /// Shows the panel, which `make` creates fully transparent.
    func revealContent() {
        alphaValue = 1
    }

    func reposition(forLauncherFrame launcherFrame: CGRect) {
        setFrame(
            MascotPanelLayout.frame(forLauncherFrame: launcherFrame, placement: placement),
            display: true
        )
    }
}
