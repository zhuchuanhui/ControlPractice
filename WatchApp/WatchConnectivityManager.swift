import Foundation
import WatchConnectivity

final class WatchConnectivityManager: NSObject, WCSessionDelegate {
    static let shared = WatchConnectivityManager()
    var onSample: ((MotionSample) -> Void)?

    func activate() {
        guard WCSession.isSupported() else { return }
        WCSession.default.delegate = self
        WCSession.default.activate()
    }

    func send(_ sample: MotionSample) {
        guard WCSession.default.isReachable, let data = try? sample.payload() else { return }
        WCSession.default.sendMessage(["motionSample": data], replyHandler: nil)
    }

    func session(_ session: WCSession, activationDidCompleteWith state: WCSessionActivationState, error: Error?) {}
    #if os(iOS)
    func sessionDidBecomeInactive(_ session: WCSession) {}
    func sessionDidDeactivate(_ session: WCSession) { session.activate() }
    #endif

    func session(_ session: WCSession, didReceiveMessage message: [String : Any]) {
        guard let data = message["motionSample"] as? Data, let sample = try? MotionSample.decode(data) else { return }
        DispatchQueue.main.async { self.onSample?(sample) }
    }
}
