import CoreMotion
import Combine
import Foundation

final class WatchMotionManager: ObservableObject {
    @Published private(set) var latestSample: MotionSample?
    @Published private(set) var isRunning = false

    private let manager = CMMotionManager()
    private let queue: OperationQueue = {
        let queue = OperationQueue()
        queue.qualityOfService = .userInitiated
        return queue
    }()
    var onSample: ((MotionSample) -> Void)?

    func start() {
        guard manager.isDeviceMotionAvailable, !isRunning else { return }
        manager.deviceMotionUpdateInterval = 0.1
        manager.startDeviceMotionUpdates(to: queue) { [weak self] motion, _ in
            guard let motion else { return }
            let sample = MotionSample(
                timestamp: Date(),
                accelerationX: motion.userAcceleration.x,
                accelerationY: motion.userAcceleration.y,
                accelerationZ: motion.userAcceleration.z,
                rotationX: motion.rotationRate.x,
                rotationY: motion.rotationRate.y,
                rotationZ: motion.rotationRate.z
            )
            DispatchQueue.main.async {
                self?.latestSample = sample
                self?.onSample?(sample)
            }
        }
        isRunning = true
    }

    func stop() {
        manager.stopDeviceMotionUpdates()
        isRunning = false
    }
}
