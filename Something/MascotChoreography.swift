import Foundation

/// How the parts that are not simulated move, plus the commanded position.
struct MascotPose: Equatable {
    var target = 0.0
    var yaw = MascotChoreography.restingYaw
    /// Extra head nod about the neck, added to the counter-tilt of the lean.
    var headNod = 0.0
    var headTilt = 0.0
    var leftHandLift = 0.0
    var rightHandLift = 0.0
    var rightHandSideways = 0.0
}

/// Scripts from the approved prototype, one per state.
enum MascotChoreography {
    static let restingYaw = -0.5
    static let startPosition = -3.3
    static let cursorAppearsAt = 2.3
    /// Time after which the entrance is over and the state may fall back to idle.
    static let appearDuration = 2.4
    static let typingKick = 0.3
    static let nodDuration = 0.18

    /// - Parameters:
    ///   - elapsed: seconds since the state began.
    ///   - sinceInput: seconds since the last query change.
    ///   - inputCount: number of query changes so far, to alternate the hands.
    static func pose(state: MascotState, elapsed: Double, sinceInput: Double, inputCount: Int) -> MascotPose {
        var pose = MascotPose()
        switch state {
        case .appearing:
            let drive = clamp01(elapsed / 1.3)
            let turn = clamp01((elapsed - 1.7) / 0.6)
            pose.target = startPosition * (1 - ease(drive))
            pose.yaw = -Double.pi / 2 + (restingYaw + Double.pi / 2) * ease(turn)
        case .idle:
            break
        case .typing:
            let tap = max(0, 1 - sinceInput / nodDuration)
            pose.headNod = 0.09 * tap
            // Alternate hands per keystroke, like typing with both hands.
            if inputCount % 2 == 1 {
                pose.leftHandLift = 0.08 * tap
            } else {
                pose.rightHandLift = 0.08 * tap
            }
        case .noMatch:
            let envelope = sin(Double.pi * clamp01(elapsed / 2.6))
            pose.target = 0.22 * sin(2 * Double.pi * elapsed / 1.3) * envelope
            pose.headTilt = 0.2 * envelope
            pose.leftHandLift = 0.08 * envelope
            pose.rightHandLift = 0.08 * envelope
        }
        return pose
    }

    private static func ease(_ u: Double) -> Double { u * u * (3 - 2 * u) }
    private static func clamp01(_ u: Double) -> Double { min(max(u, 0), 1) }
}
