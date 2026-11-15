import Foundation

/// Where the mascot's panel sits relative to the launcher, and how the camera is
/// aimed so that the robot's ground line lands on the launcher's top edge.
enum MascotPanelLayout {
    static let panelSize = CGSize(width: 220, height: 220)
    /// Distance from the launcher's right edge to the panel's right edge.
    static let rightInset = 24.0
    static let groundLineFraction = MascotChoreography.groundLineFraction

    /// The panel's bottom edge sits slightly below the launcher's top edge, because the
    /// ground line is a little above the panel's bottom. AppKit's y axis points up.
    static func frame(forLauncherFrame launcher: CGRect) -> CGRect {
        CGRect(
            x: launcher.maxX - rightInset - panelSize.width,
            y: launcher.maxY - groundLineFraction * panelSize.height,
            width: panelSize.width, height: panelSize.height)
    }

    /// Downward pitch of the camera, in radians, that puts the world origin at
    /// `groundLineFraction` of the view height above the bottom. The ray to the origin
    /// is `atan2(height, distance)` below horizontal and must end up
    /// `atan((1 - 2f) * tan(fov / 2))` below the view axis.
    static func cameraPitch(
        cameraHeight: Double, cameraDistance: Double, verticalFieldOfViewDegrees: Double,
        groundLineFraction: Double = MascotPanelLayout.groundLineFraction
    ) -> Double {
        let angleToOrigin = atan2(cameraHeight, cameraDistance)
        let halfFieldOfView = verticalFieldOfViewDegrees * Double.pi / 360
        return angleToOrigin - atan((1 - 2 * groundLineFraction) * tan(halfFieldOfView))
    }
}
