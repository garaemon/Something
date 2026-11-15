import Foundation

/// The robot's parts as plain data, so that a skin can later be loaded from a file
/// instead of being compiled in. Units are scene units; the robot is about 2 high.
struct MascotModel: Codable, Equatable {
    struct Vector: Codable, Equatable {
        var x: Double
        var y: Double
        var z: Double
    }

    enum Axis: String, Codable {
        case x, y, z
    }

    /// The nodes that the animation moves. Parts belong to exactly one group.
    enum Group: String, Codable, CaseIterable {
        case wheelLeft, wheelRight, tilt, body, head, handLeft, handRight
    }

    enum Shape: Codable, Equatable {
        case box(width: Double, height: Double, depth: Double, cornerRadius: Double)
        /// `axis` is the cylinder's axis of revolution.
        case cylinder(radius: Double, height: Double, axis: Axis)
        case sphere(radius: Double)
    }

    struct GroupSpec: Codable, Equatable {
        var group: Group
        /// Nil attaches the group to the robot root.
        var parent: Group?
        var position: Vector
    }

    struct Part: Codable, Equatable {
        var group: Group
        var shape: Shape
        var position: Vector
        /// "#RRGGBB".
        var color: String
    }

    /// The textured plane that shows the text, in front of the screen box.
    struct Screen: Codable, Equatable {
        var group: Group
        var position: Vector
        var width: Double
        var height: Double
        var textColor: String
    }

    var groups: [GroupSpec]
    var parts: [Part]
    var screen: Screen

    /// Parses "#RRGGBB" into components of 0...1, or nil for anything else.
    static func rgb(hex: String) -> (red: Double, green: Double, blue: Double)? {
        var digits = hex
        if digits.hasPrefix("#") { digits.removeFirst() }
        guard digits.count == 6, let value = UInt32(digits, radix: 16) else { return nil }
        return (
            Double((value >> 16) & 0xFF) / 255,
            Double((value >> 8) & 0xFF) / 255,
            Double(value & 0xFF) / 255)
    }
}

extension MascotModel {
    private static let head = "#FF9A4D"
    private static let cream = "#F4EDE0"
    private static let wheel = "#3A2E1F"
    private static let screenBody = "#2B2A33"
    private static let neck = "#8A8478"

    private static func vec(_ x: Double, _ y: Double, _ z: Double) -> Vector {
        Vector(x: x, y: y, z: z)
    }

    private static func box(
        _ group: Group, _ width: Double, _ height: Double, _ depth: Double, _ color: String,
        at position: Vector, radius: Double = 0.07
    ) -> Part {
        // Same clamp as the prototype: a chamfer cannot exceed half of the smallest side.
        let limit = min(width, height, depth) / 2.01
        return Part(
            group: group,
            shape: .box(width: width, height: height, depth: depth, cornerRadius: min(radius, limit)),
            position: position, color: color)
    }

    /// The approved prototype robot.
    static let `default` = MascotModel(
        groups: [
            GroupSpec(group: .wheelLeft, parent: nil, position: vec(-0.32, 0.2, 0)),
            GroupSpec(group: .wheelRight, parent: nil, position: vec(0.32, 0.2, 0)),
            // The axle: the lean pivots here.
            GroupSpec(group: .tilt, parent: nil, position: vec(0, 0.2, 0)),
            GroupSpec(group: .body, parent: .tilt, position: vec(0, -0.2, 0)),
            // The neck.
            GroupSpec(group: .head, parent: .body, position: vec(0, 0.94, 0)),
            // Hands sit at their rest position so that animation only adds an offset.
            GroupSpec(group: .handLeft, parent: .body, position: vec(-0.48, 0.55, 0.12)),
            GroupSpec(group: .handRight, parent: .body, position: vec(0.48, 0.55, 0.12)),
        ],
        parts: [
            Part(group: .wheelLeft, shape: .cylinder(radius: 0.2, height: 0.14, axis: .x), position: vec(0, 0, 0), color: wheel),
            box(.wheelLeft, 0.16, 0.3, 0.06, cream, at: vec(0, 0, 0), radius: 0.02),
            Part(group: .wheelRight, shape: .cylinder(radius: 0.2, height: 0.14, axis: .x), position: vec(0, 0, 0), color: wheel),
            box(.wheelRight, 0.16, 0.3, 0.06, cream, at: vec(0, 0, 0), radius: 0.02),

            box(.body, 0.7, 0.55, 0.6, cream, at: vec(0, 0.55, 0)),
            box(.body, 0.3, 0.06, 0.03, head, at: vec(0, 0.62, 0.31), radius: 0.01),
            box(.body, 0.18, 0.06, 0.03, "#D8CFBE", at: vec(-0.06, 0.5, 0.31), radius: 0.01),
            Part(group: .body, shape: .cylinder(radius: 0.12, height: 0.14, axis: .y), position: vec(0, 0.87, 0), color: neck),
            Part(group: .handLeft, shape: .sphere(radius: 0.1), position: vec(0, 0, 0), color: cream),
            Part(group: .handRight, shape: .sphere(radius: 0.1), position: vec(0, 0, 0), color: cream),

            box(.head, 1.4, 1.0, 1.0, head, at: vec(0, 0.48, 0), radius: 0.1),
            Part(group: .head, shape: .cylinder(radius: 0.13, height: 0.1, axis: .x), position: vec(-0.74, 0.51, 0), color: cream),
            Part(group: .head, shape: .cylinder(radius: 0.13, height: 0.1, axis: .x), position: vec(0.74, 0.51, 0), color: cream),
            box(.head, 1.0, 0.62, 0.06, screenBody, at: vec(0, 0.5, 0.5), radius: 0.03),
        ],
        screen: Screen(
            group: .head, position: vec(0, 0.5, 0.534), width: 0.9, height: 0.5, textColor: "#FFE66D"))
}
