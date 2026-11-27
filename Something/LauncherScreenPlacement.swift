import CoreGraphics

/// The screen that the launcher opens on.
enum LauncherScreenPlacement: String, CaseIterable, Identifiable {
    /// Where the launcher was last moved to, as AppKit's frame autosave keeps it.
    case lastPosition
    /// The screen under the mouse pointer.
    case mouseScreen
    /// The screen of the frontmost window of the frontmost application.
    case activeWindowScreen
    /// The screen with the menu bar.
    case primaryScreen

    static let defaultPlacement = LauncherScreenPlacement.lastPosition

    var id: String { rawValue }

    var title: String {
        switch self {
        case .lastPosition: return "Last position"
        case .mouseScreen: return "Screen with mouse pointer"
        case .activeWindowScreen: return "Screen with active window"
        case .primaryScreen: return "Screen with menu bar"
        }
    }
}

/// The pure geometry of putting the launcher on a screen. Rectangles are in AppKit
/// coordinates: the origin is the bottom left of the primary screen, and y grows upward.
enum LauncherScreenLayout {
    /// The index of the screen whose frame holds `point`, such as the mouse location.
    /// The top and right edges count, because `NSEvent.mouseLocation` reaches them.
    static func screenIndex(containing point: CGPoint, screenFrames: [CGRect]) -> Int? {
        screenFrames.firstIndex {
            $0.minX <= point.x && point.x <= $0.maxX && $0.minY <= point.y && point.y <= $0.maxY
        }
    }

    /// The index of the screen that shares the largest area with `rect`, such as a window
    /// that spans two screens. Nil when `rect` lies on no screen.
    static func screenIndex(mostOverlapping rect: CGRect, screenFrames: [CGRect]) -> Int? {
        let areas = screenFrames.map { frame -> CGFloat in
            let overlap = frame.intersection(rect)
            return overlap.isNull ? 0 : overlap.width * overlap.height
        }
        guard let largest = areas.max(), largest > 0 else { return nil }
        return areas.firstIndex(of: largest)
    }

    /// Converts window bounds from the Core Graphics window list, whose origin is the top
    /// left of the primary screen with y growing downward, to AppKit coordinates.
    static func appKitRect(
        fromWindowListBounds bounds: CGRect,
        primaryScreenHeight: CGFloat
    ) -> CGRect {
        CGRect(
            x: bounds.minX,
            y: primaryScreenHeight - bounds.maxY,
            width: bounds.width,
            height: bounds.height
        )
    }

    /// A frame of `size`, shrunk to fit, centered horizontally in `visibleFrame` and
    /// a little above its middle, as `NSWindow.center()` puts a window.
    static func frame(size: CGSize, centeredIn visibleFrame: CGRect) -> CGRect {
        let width = min(size.width, visibleFrame.width)
        let height = min(size.height, visibleFrame.height)
        let spareHeight = visibleFrame.height - height
        return CGRect(
            x: visibleFrame.minX + (visibleFrame.width - width) / 2,
            // Two thirds of the spare height go below the window.
            y: visibleFrame.minY + spareHeight * 2 / 3,
            width: width,
            height: height
        )
    }
}
