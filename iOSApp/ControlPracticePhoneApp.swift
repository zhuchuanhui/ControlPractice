import SwiftUI

@main
struct ControlPracticePhoneApp: App {
    @StateObject private var bridge = PhoneMotionBridgeModel()
    @StateObject private var language = LanguageStore()

    var body: some Scene {
        WindowGroup {
            VStack(spacing: 16) {
                Image(systemName: "applewatch")
                    .font(.system(size: 48))
                Text("Control Practice")
                    .font(.title2)
                Text("Apple Watchの計測データを待機中".localized)
                    .foregroundStyle(.secondary)
            }
            .environment(\.locale, language.language.locale)
            .padding()
            .onAppear { bridge.activate() }
        }
    }
}

final class PhoneMotionBridgeModel: ObservableObject {
    private let bridge = PhoneMotionBridge()
    func activate() { bridge.activate() }
}
