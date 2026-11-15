import Foundation

/// How the parts that are not simulated move, plus the commanded position.
struct MascotPose: Equatable {
    var target = 0.0
    /// Height of the whole robot above its resting ground, for the entrance.
    var lift = 0.0
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
    /// The robot starts this far below the ground line, fully hidden behind the window.
    static let hiddenDepth = -2.4
    static let riseDuration = 0.4
    static let overshootHeight = 0.3
    static let landingTime = 0.65
    /// Beside the launcher the robot drops in from above instead.
    static let sideDropHeight = 3.4
    static let sideLandingTime = 0.45
    static let landingKick = 0.8
    static let cursorAppearsAt = 1.0
    /// Time after which the entrance is over and the state may fall back to idle.
    static let appearDuration = 1.2
    static let typingKick = 0.3
    static let nodDuration = 0.18

    /// - Parameters:
    ///   - elapsed: seconds since the state began.
    ///   - sinceInput: seconds since the last query change.
    ///   - inputCount: number of query changes so far, to alternate the hands.
    static func pose(
        state: MascotState,
        elapsed: Double,
        sinceInput: Double,
        inputCount: Int,
        placement: MascotPlacement = .top
    ) -> MascotPose {
        var pose = MascotPose()
        switch state {
        case .appearing:
            pose.lift = entranceLift(elapsed, placement: placement)
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

    /// Rises from behind the window edge past the ground line, then settles back.
    /// The panel's bottom edge hides the robot while it is below the line.
    static func entranceLift(_ t: Double, placement: MascotPlacement = .top) -> Double {
        if placement != .top {
            // As if it jumped off the launcher: falls from above onto the ground.
            guard t < sideLandingTime else { return 0 }
            let u = t / sideLandingTime
            return sideDropHeight * (1 - u * u)
        }
        if t < riseDuration {
            let u = clamp01(t / riseDuration)
            let easeOut = 1 - (1 - u) * (1 - u)
            return hiddenDepth + (overshootHeight - hiddenDepth) * easeOut
        }
        if t < landingTime {
            let u = (t - riseDuration) / (landingTime - riseDuration)
            return overshootHeight * (1 - u * u)
        }
        return 0
    }

    static func landingTime(for placement: MascotPlacement) -> Double {
        placement == .top ? landingTime : sideLandingTime
    }

    private static func clamp01(_ u: Double) -> Double { min(max(u, 0), 1) }
}
