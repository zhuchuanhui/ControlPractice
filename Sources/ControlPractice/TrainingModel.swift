import AVKit
import Foundation

enum TrainingPhase: String, CaseIterable, Codable {
    case ready = "準備"
    case stimulate = "刺激"
    case rest = "休憩"
    case complete = "完了"
}

struct TrainingSession: Identifiable, Codable {
    let id: UUID
    let date: Date
    let sets: Int
    let completedSets: Int
    let duration: TimeInterval
}

final class TrainingModel: ObservableObject {
    @Published var videoURL: URL?
    @Published var phase: TrainingPhase = .ready
    @Published var isRunning = false
    @Published var currentSet = 1
    @Published var elapsed: TimeInterval = 0
    @Published var stimulusSeconds = 60
    @Published var restSeconds = 30
    @Published var totalSets = 3
    @Published var automaticControl = true
    @Published var automaticThreshold = 0.75
    @Published var history: [TrainingSession] = []
    @Published private(set) var lastVideoURL: URL?
    @Published private(set) var preferredStartTime: TimeInterval?
    private var preferredStartTimes: [String: TimeInterval] = [:]

    private var timer: Timer?
    private var sessionStartedAt: Date?
    private let historyKey = "training.history"

    init() {
        loadHistory(); loadLastVideo()
        preferredStartTimes = UserDefaults.standard.dictionary(forKey: "training.preferredStartTimes") as? [String: TimeInterval] ?? [:]
        preferredStartTime = lastVideoURL.flatMap { preferredStartTimes[$0.absoluteString] }
    }

    var phaseTitle: String { AppText.value(phase.rawValue) }
    var phaseLimit: TimeInterval { phase == .stimulate ? TimeInterval(stimulusSeconds) : TimeInterval(restSeconds) }
    var remaining: TimeInterval { max(0, phaseLimit - elapsed) }

    func startOrResume() {
        if phase == .complete { reset() }
        if sessionStartedAt == nil { sessionStartedAt = Date() }
        isRunning = true
        if phase == .ready { phase = .stimulate; elapsed = 0 }
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            DispatchQueue.main.async { self?.tick() }
        }
    }

    func pause() { isRunning = false; timer?.invalidate(); timer = nil }

    func reset() {
        pause(); phase = .ready; currentSet = 1; elapsed = 0; sessionStartedAt = nil
    }

    func skipPhase() { transition() }
    func automaticRest() {
        guard automaticControl, isRunning, phase == .stimulate else { return }
        transition()
    }

    private func tick() {
        guard isRunning else { return }
        elapsed += 1
        if elapsed >= phaseLimit { transition() }
    }

    private func transition() {
        elapsed = 0
        if phase == .stimulate {
            phase = .rest
        } else if phase == .rest {
            if currentSet >= totalSets { finish() } else { currentSet += 1; phase = .stimulate }
        } else if phase == .ready { phase = .stimulate }
    }

    private func finish() {
        let duration = sessionStartedAt.map { Date().timeIntervalSince($0) } ?? 0
        history.insert(TrainingSession(id: UUID(), date: Date(), sets: totalSets, completedSets: totalSets, duration: duration), at: 0)
        saveHistory(); pause(); phase = .complete
    }

    func loadVideo(_ url: URL) {
        _ = url.startAccessingSecurityScopedResource()
        videoURL = url
        lastVideoURL = url
        preferredStartTime = preferredStartTimes[url.absoluteString]
        if let bookmark = try? url.bookmarkData(options: .withSecurityScope, includingResourceValuesForKeys: nil, relativeTo: nil) {
            UserDefaults.standard.set(bookmark, forKey: "training.lastVideoBookmark")
        }
    }
    func restoreLastVideo() -> URL? {
        guard let lastVideoURL else { return nil }
        loadVideo(lastVideoURL)
        return lastVideoURL
    }
    func savePreferredStartTime(_ time: TimeInterval) {
        preferredStartTime = max(0, time)
        guard let url = videoURL else { return }
        preferredStartTimes[url.absoluteString] = preferredStartTime
        UserDefaults.standard.set(preferredStartTimes, forKey: "training.preferredStartTimes")
    }
    func deleteHistory(at offsets: IndexSet) { history.remove(atOffsets: offsets); saveHistory() }
    func clearHistory() { history.removeAll(); saveHistory() }

    private func loadHistory() {
        guard let data = UserDefaults.standard.data(forKey: historyKey), let value = try? JSONDecoder().decode([TrainingSession].self, from: data) else { return }
        history = value
    }
    private func saveHistory() { UserDefaults.standard.set(try? JSONEncoder().encode(history), forKey: historyKey) }
    private func loadLastVideo() {
        guard let data = UserDefaults.standard.data(forKey: "training.lastVideoBookmark") else { return }
        var stale = false
        if let url = try? URL(resolvingBookmarkData: data, options: [.withSecurityScope], relativeTo: nil, bookmarkDataIsStale: &stale) {
            lastVideoURL = url
        }
    }
}
