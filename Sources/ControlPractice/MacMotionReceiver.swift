import Foundation
import Combine
import Network

extension Notification.Name {
    static let motionSampleReceived = Notification.Name("ControlPractice.motionSampleReceived")
}

final class MacMotionReceiver: ObservableObject {
    @Published private(set) var latestSample: MotionSample?
    @Published private(set) var intensity: Double = 0
    @Published private(set) var movementSpeed: Double = 0
    @Published private(set) var lastUpdate: Date?
    @Published var wristSide: WristSide = .left
    @Published private(set) var isCalibrating = false
    @Published private(set) var calibrationProgress = 0
    private var calibrationValues: [Double] = []
    private var baseline: Double = 0
    private var previousSample: MotionSample?
    private var listener: NWListener?

    init() {
        startListener()
        NotificationCenter.default.addObserver(forName: .motionSampleReceived, object: nil, queue: .main) { [weak self] note in
            guard let sample = note.object as? MotionSample else { return }
            self?.latestSample = sample
            let raw = sample.intensity()
            if self?.isCalibrating == true {
                self?.calibrationValues.append(raw)
                self?.calibrationProgress = self?.calibrationValues.count ?? 0
                if self?.calibrationValues.count == 20 {
                    self?.baseline = (self?.calibrationValues.reduce(0, +) ?? 0) / 20
                    self?.isCalibrating = false
                }
            }
            self?.intensity = sample.intensity(baseline: self?.baseline ?? 0)
            if let previous = self?.previousSample {
                let interval = max(0.02, sample.timestamp.timeIntervalSince(previous.timestamp))
                let accelerationDelta = abs(sample.accelerationMagnitude - previous.accelerationMagnitude)
                let rotationDelta = abs(sample.rotationMagnitude - previous.rotationMagnitude) / 8
                self?.movementSpeed = min(1, max(0, (accelerationDelta + rotationDelta) / interval / 4))
            }
            self?.previousSample = sample
            self?.lastUpdate = sample.timestamp
        }
    }

    private func startListener() {
        do {
            let listener = try NWListener(using: .tcp, on: 48521)
            listener.service = NWListener.Service(name: "Control Practice", type: "_controlpractice._tcp")
            listener.newConnectionHandler = { [weak self] connection in self?.receive(connection) }
            listener.start(queue: .global(qos: .userInitiated))
            self.listener = listener
        } catch { }
    }

    private func receive(_ connection: NWConnection) {
        connection.start(queue: .global(qos: .userInitiated))
        connection.receive(minimumIncompleteLength: 4, maximumLength: 4) { [weak self] header, _, _, _ in
            guard let header, header.count == 4 else { connection.cancel(); return }
            let length = Int(UInt32(bigEndian: header.withUnsafeBytes { $0.load(as: UInt32.self) }))
            connection.receive(minimumIncompleteLength: length, maximumLength: length) { data, _, _, _ in
                if let data, let sample = try? MotionSample.decode(data) {
                    NotificationCenter.default.post(name: .motionSampleReceived, object: sample)
                }
                connection.cancel()
                _ = self
            }
        }
    }

    func startCalibration() {
        calibrationValues.removeAll(); calibrationProgress = 0; isCalibrating = true
    }

    func sendTestMotion() {
        // ほぼ静止したサンプルを送り、受信経路だけを確認する。
        // 2.2Gなどの強い値を使うと、自動しきい値を超えて
        // 「動きを止めてください」の警告まで発生してしまう。
        let sample = MotionSample(timestamp: Date(), accelerationX: 1.05, accelerationY: 0, accelerationZ: 0, rotationX: 0, rotationY: 0, rotationZ: 0)
        NotificationCenter.default.post(name: .motionSampleReceived, object: sample)
    }

    func requestConnection() {
        latestSample = nil
        intensity = 0
        movementSpeed = 0
    }

    deinit { NotificationCenter.default.removeObserver(self) }
}
