import Foundation

enum WristSide: String, Codable, CaseIterable {
    case left = "左手"
    case right = "右手"
}

struct MotionSample: Codable, Equatable {
    let timestamp: Date
    let accelerationX: Double
    let accelerationY: Double
    let accelerationZ: Double
    let rotationX: Double
    let rotationY: Double
    let rotationZ: Double

    var accelerationMagnitude: Double {
        sqrt(accelerationX * accelerationX + accelerationY * accelerationY + accelerationZ * accelerationZ)
    }

    var rotationMagnitude: Double {
        sqrt(rotationX * rotationX + rotationY * rotationY + rotationZ * rotationZ)
    }

    func intensity(baseline: Double = 0) -> Double {
        min(1, max(0, (abs(accelerationMagnitude - 1) + rotationMagnitude / 8) - baseline))
    }

    func payload() throws -> Data { try JSONEncoder().encode(self) }
    static func decode(_ data: Data) throws -> MotionSample { try JSONDecoder().decode(Self.self, from: data) }
}
