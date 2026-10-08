import AVFoundation
import CoreMedia
import CoreVideo
import Combine
import Foundation

final class VideoMotionAnalyzer: NSObject, ObservableObject {
    @Published private(set) var motionScore: Double = 0
    @Published private(set) var isAnalyzing = false
    @Published private(set) var sceneLabel: SceneLabel = .unknown

    private var output: AVPlayerItemVideoOutput?
    private var timer: DispatchSourceTimer?
    private weak var item: AVPlayerItem?
    private var previousBuffer: CVPixelBuffer?
    private var previousScore = 0.0
    private let queue = DispatchQueue(label: "ControlPractice.video-analysis")

    func attach(to item: AVPlayerItem) {
        stop()
        let settings: [String: Any] = [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA]
        let output = AVPlayerItemVideoOutput(pixelBufferAttributes: settings)
        item.add(output)
        self.output = output
        self.item = item
    }

    func start() {
        guard output != nil, !isAnalyzing else { return }
        isAnalyzing = true
        let timer = DispatchSource.makeTimerSource(queue: queue)
        timer.schedule(deadline: .now(), repeating: .milliseconds(100))
        timer.setEventHandler { [weak self] in self?.sample() }
        self.timer = timer
        timer.resume()
    }

    func stop() {
        timer?.cancel()
        timer = nil
        output = nil
        item = nil
        previousBuffer = nil
        previousScore = 0
        sceneLabel = .unknown
        isAnalyzing = false
        motionScore = 0
    }

    private func sample() {
        guard let output else { return }
        guard let item else { return }
        let time = item.currentTime()
        guard output.hasNewPixelBuffer(forItemTime: time), let buffer = output.copyPixelBuffer(forItemTime: time, itemTimeForDisplay: nil) else { return }
        let score = difference(previous: previousBuffer, current: buffer)
        previousBuffer = buffer
        let changeRate = abs(score - previousScore)
        previousScore = score
        let label = SceneAnalysis.estimate(motion: score, changeRate: changeRate)
        DispatchQueue.main.async { [weak self] in
            self?.motionScore = score
            self?.sceneLabel = label
        }
    }

    private func difference(previous: CVPixelBuffer?, current: CVPixelBuffer) -> Double {
        guard let previous else { return 0 }
        CVPixelBufferLockBaseAddress(previous, .readOnly); defer { CVPixelBufferUnlockBaseAddress(previous, .readOnly) }
        CVPixelBufferLockBaseAddress(current, .readOnly); defer { CVPixelBufferUnlockBaseAddress(current, .readOnly) }
        guard let p1 = CVPixelBufferGetBaseAddress(previous)?.assumingMemoryBound(to: UInt8.self),
              let p2 = CVPixelBufferGetBaseAddress(current)?.assumingMemoryBound(to: UInt8.self) else { return 0 }
        let width = CVPixelBufferGetWidth(current), height = CVPixelBufferGetHeight(current)
        let stride1 = CVPixelBufferGetBytesPerRow(previous), stride2 = CVPixelBufferGetBytesPerRow(current)
        var total = 0.0, samples = 0
        for y in stride(from: 0, to: height, by: max(1, height / 24)) {
            for x in stride(from: 0, to: width, by: max(1, width / 32)) {
                let i1 = y * stride1 + x * 4, i2 = y * stride2 + x * 4
                total += abs(Double(p1[i1]) - Double(p2[i2])) + abs(Double(p1[i1 + 1]) - Double(p2[i2 + 1])) + abs(Double(p1[i1 + 2]) - Double(p2[i2 + 2]))
                samples += 3
            }
        }
        return min(1, total / Double(max(1, samples)) / 64)
    }
}
