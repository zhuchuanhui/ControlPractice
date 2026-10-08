import SwiftUI

@main
struct ControlPracticeWatchApp: App {
    @StateObject private var language = LanguageStore()
    var body: some Scene {
        WindowGroup {
            WatchContentView()
                .environment(\.locale, language.language.locale)
        }
    }
}
