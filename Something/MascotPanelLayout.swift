import Foundation

/// Where the mascot stands relative to the launcher. Fixed for a panel's lifetime.
enum MascotPlacement: CaseIterable {
    case top
    case left
    case right

    /// Fraction of the panel's height between its bottom edge and the robot's ground
    /// line. The layout and the camera both derive from it, so they cannot drift apart.
    /// The sides sit higher because they show a ground shadow, whose near edge the
    /// panel's bottom would otherwise clip.
    var groundLineFraction: Double {
        switch self {
        case .top: return 0.03
        case .left, .right: return 0.21
        }
    }

    /// Only the sides have no edge to stand on, so only they get a shadow.
    var showsGroundShadow: Bool { self != .top }
}

/// Where the mascot's panel sits relative to the launcher, and how the camera is
/// aimed so that the robot's ground line lands where the placement wants it.
enum MascotPanelLayout {
    static let panelSize = CGSize(width: 220, height: 220)
    /// Top placement: distance from the launcher's right edge to the panel's right edge.
    static let rightInset = 24.0
    /// Side placements: how far the panel overlaps the launcher, so that the robot
    /// does not stand far away from it.
    static let sideOverlap = 30.0

    /// AppKit's y axis points up. On top, the ground line is the launcher's top edge;
    /// beside the launcher, it is level with the launcher's bottom edge.
    static func frame(forLauncherFrame launcher: CGRect, placement: MascotPlacement = .top) -> CGRect {
        let lineOffset = placement.groundLineFraction * panelSize.height
        switch placement {
        case .top:
            return CGRect(
                x: launcher.maxX - rightInset - panelSize.width, y: launcher.maxY - lineOffset,
                width: panelSize.width, height: panelSize.height)
        case .right:
            return CGRect(
                x: launcher.maxX - sideOverlap, y: launcher.minY - lineOffset,
                width: panelSize.width, height: panelSize.height)
        case .left:
            return CGRect(
                x: launcher.minX + sideOverlap - panelSize.width, y: launcher.minY - lineOffset,
                width: panelSize.width, height: panelSize.height)
        }
    }

    /// Placements whose panel lies entirely on the screen, so that the robot is never
    /// cut off. Returns every placement when none fits, because the mascot must still appear.
    static func placements(
        fittingLauncherFrame launcher: CGRect, within screenVisibleFrame: CGRect
    ) -> [MascotPlacement] {
        let fitting = MascotPlacement.allCases.filter {
            screenVisibleFrame.contains(frame(forLauncherFrame: launcher, placement: $0))
        }
        return fitting.isEmpty ? MascotPlacement.allCases : fitting
    }

    /// Downward pitch of the camera, in radians, that puts the world origin at
    /// `groundLineFraction` of the view height above the bottom. The ray to the origin
    /// is `atan2(height, distance)` below horizontal and must end up
    /// `atan((1 - 2f) * tan(fov / 2))` below the view axis.
    static func cameraPitch(
        cameraHeight: Double, cameraDistance: Double, verticalFieldOfViewDegrees: Double,
        placement: MascotPlacement = .top
    ) -> Double {
        let angleToOrigin = atan2(cameraHeight, cameraDistance)
        let halfFieldOfView = verticalFieldOfViewDegrees * Double.pi / 360
        return angleToOrigin - atan((1 - 2 * placement.groundLineFraction) * tan(halfFieldOfView))
    }
}
