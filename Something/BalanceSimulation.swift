import Foundation

/// Two-wheeled inverted pendulum that balances itself with a fixed state feedback.
/// The gains were pole-placed for the prototype and are stable, so do not tune them
/// by feel. The launcher state only sends commands; the balancing never stops.
struct BalanceSimulation: Equatable {
    /// What the outside world asks of the robot for one step.
    struct Command: Equatable {
        /// Wanted position along the heading.
        var target = 0.0
        /// One-off angular velocity added before the step, for a nudge.
        var kick = 0.0
    }

    static let fixedStep = 1.0 / 240.0
    static let gravity = 25.0
    static let positionGain = 7.5
    static let velocityGain = 7.9
    static let leanGain = 109.0
    static let leanRateGain = 21.4
    static let accelerationLimit = 40.0
    /// Peak of the sum-of-sines push in angular acceleration. Without it the
    /// robot would hold perfectly still, which looks dead.
    static let disturbanceAmplitude = 0.35

    var position = 0.0
    var velocity = 0.0
    var lean = 0.0
    var leanRate = 0.0
    /// Simulated seconds, which also drives the disturbance so runs are deterministic.
    private(set) var time = 0.0

    init(position: Double = 0) {
        self.position = position
    }

    mutating func step(dt: Double = BalanceSimulation.fixedStep, command: Command = Command()) {
        let error = position - command.target
        let unclamped =
            Self.positionGain * error + Self.velocityGain * velocity
            + Self.leanGain * lean + Self.leanRateGain * leanRate
        let acceleration = min(max(unclamped, -Self.accelerationLimit), Self.accelerationLimit)
        leanRate += command.kick
        velocity += acceleration * dt
        position += velocity * dt
        let disturbance = Self.disturbanceAmplitude * Self.noise(at: time + 10)
        leanRate += (Self.gravity * sin(lean) - acceleration * cos(lean) + disturbance) * dt
        lean += leanRate * dt
        time += dt
    }

    /// Runs idle steps so that the first visible frame already wobbles naturally.
    mutating func settle(seconds: Double) {
        let steps = Int(seconds / Self.fixedStep)
        for _ in 0..<steps {
            step()
        }
    }

    private static func noise(at t: Double) -> Double {
        0.5 * sin(2.3 * t) + 0.35 * sin(5.1 * t + 1) + 0.25 * sin(8.7 * t + 2)
    }
}
