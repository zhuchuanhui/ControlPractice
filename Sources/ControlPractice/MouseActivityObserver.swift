import AppKit
import Combine

final class MouseActivityObserver: ObservableObject {
    @Published private(set) var isIdle = false
    private var monitor: Any?
    private var hideWork: DispatchWorkItem?

    func start() {
        guard monitor == nil else { return }
        monitor = NSEvent.addLocalMonitorForEvents(matching: [.mouseMoved, .leftMouseDragged, .rightMouseDragged]) { [weak self] event in
            self?.mouseMoved()
            return event
        }
        mouseMoved()
    }

    func stop() {
        if let monitor { NSEvent.removeMonitor(monitor) }
        monitor = nil
        hideWork?.cancel()
    }

    private func mouseMoved() {
        DispatchQueue.main.async { [weak self] in self?.isIdle = false }
        hideWork?.cancel()
        let work = DispatchWorkItem { [weak self] in self?.isIdle = true }
        hideWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 1, execute: work)
    }

    deinit { stop() }
}
