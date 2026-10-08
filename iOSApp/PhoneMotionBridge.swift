import Foundation
import WatchConnectivity
import Network

/// iPhone側でWatchから受け取り、Macへ中継するための入口。
/// Macへの転送方法（Bonjour/Network.framework等）はアプリ本体に合わせて実装します。
final class PhoneMotionBridge: NSObject, WCSessionDelegate {
    var onSample: ((MotionSample) -> Void)?
    private var browser: NWBrowser?
    private var macConnection: NWConnection?

    func activate() {
        guard WCSession.isSupported() else { return }
        WCSession.default.delegate = self
        WCSession.default.activate()
        discoverMac()
    }

    func session(_ session: WCSession, activationDidCompleteWith state: WCSessionActivationState, error: Error?) {}
    func sessionDidBecomeInactive(_ session: WCSession) {}
    func sessionDidDeactivate(_ session: WCSession) { session.activate() }
    func session(_ session: WCSession, didReceiveMessage message: [String : Any]) {
        guard let data = message["motionSample"] as? Data, let sample = try? MotionSample.decode(data) else { return }
        DispatchQueue.main.async { self.onSample?(sample) }
        sendToMac(sample)
    }

    private func discoverMac() {
        let browser = NWBrowser(for: .bonjour(type: "_controlpractice._tcp", domain: nil), using: .tcp)
        browser.browseResultsChangedHandler = { [weak self] results, _ in
            guard let endpoint = results.first?.endpoint else { return }
            let connection = NWConnection(to: endpoint, using: .tcp)
            connection.start(queue: .global(qos: .userInitiated))
            self?.macConnection = connection
        }
        browser.start(queue: .global(qos: .userInitiated))
        self.browser = browser
    }

    private func sendToMac(_ sample: MotionSample) {
        guard let connection = macConnection, let data = try? sample.payload() else { return }
        var size = UInt32(data.count).bigEndian
        var packet = Data(bytes: &size, count: 4)
        packet.append(data)
        connection.send(content: packet, completion: .contentProcessed { _ in })
    }
}
