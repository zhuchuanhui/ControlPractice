import SwiftUI
import AppKit

@main
struct ControlPracticeApp: App {
    @StateObject private var model = TrainingModel()
    @StateObject private var motionReceiver = MacMotionReceiver()
    @StateObject private var language = LanguageStore()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.locale, language.language.locale)
                .environmentObject(model)
                .environmentObject(motionReceiver)
                .environmentObject(language)
                .frame(minWidth: 900, minHeight: 620)
                .ignoresSafeArea()
                .onAppear {
                    DynamicAppIcon.shared.update(for: .ready)
                    configureWindow()
                }
        }
        .windowResizability(.automatic)
        Settings { SettingsView().environmentObject(model).environmentObject(language).environment(\.locale, Locale(identifier: language.language.rawValue)) }
    }

    private func configureWindow() {
        guard let window = NSApp.keyWindow else { return }
        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true
        window.styleMask.insert(.fullSizeContentView)
        window.collectionBehavior.insert(.fullScreenPrimary)
    }
}
