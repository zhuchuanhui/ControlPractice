import Foundation
import SwiftUI

enum AppLanguage: String, CaseIterable, Identifiable {
    case japanese = "ja"
    case english = "en"
    case simplifiedChinese = "zh-Hans"
    case traditionalChinese = "zh-Hant"

    var id: String { rawValue }

    var locale: Locale { Locale(identifier: rawValue) }

    var displayName: String {
        switch self {
        case .japanese: return "日本語"
        case .english: return "English"
        case .simplifiedChinese: return "简体中文"
        case .traditionalChinese: return "繁體中文"
        }
    }
}

enum LanguageSettings {
    static let key = "app.language"
    static let defaults = UserDefaults.standard

    static var current: AppLanguage {
        AppLanguage(rawValue: defaults.string(forKey: key) ?? "") ?? .japanese
    }
}

final class LanguageStore: ObservableObject {
    @Published var language: AppLanguage {
        didSet { LanguageSettings.defaults.set(language.rawValue, forKey: LanguageSettings.key) }
    }

    private var observer: NSObjectProtocol?

    init() {
        language = LanguageSettings.current
        observer = NotificationCenter.default.addObserver(forName: UserDefaults.didChangeNotification, object: nil, queue: .main) { [weak self] _ in
            guard let self, self.language != LanguageSettings.current else { return }
            self.objectWillChange.send()
        }
    }

    deinit { if let observer { NotificationCenter.default.removeObserver(observer) } }
}
