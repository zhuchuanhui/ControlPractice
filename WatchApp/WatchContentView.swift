import SwiftUI

struct WatchContentView: View {
    @StateObject private var motion = WatchMotionManager()
    private let connection = WatchConnectivityManager.shared

    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: motion.isRunning ? "waveform.path.ecg" : "applewatch")
                .font(.largeTitle)
            Text((motion.isRunning ? "計測中" : "開始してください").localized)
            Button(motion.isRunning ? "停止".localized : "計測開始".localized) {
                if motion.isRunning { motion.stop() } else { motion.start() }
            }
        }
        .onAppear {
            connection.activate()
            motion.onSample = { connection.send($0) }
        }
    }
}
