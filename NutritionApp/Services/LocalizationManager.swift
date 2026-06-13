import Foundation
import SwiftUI

@Observable
final class LocalizationManager {
    static let shared = LocalizationManager()

    var currentLanguage: AppLanguage {
        didSet { saveLanguage() }
    }
    var currentRegion: AppRegion {
        didSet { saveRegion() }
    }

    private let languageKey = "appLanguage"
    private let regionKey = "appRegion"

    init() {
        if let saved = UserDefaults.standard.string(forKey: languageKey),
           let language = AppLanguage(rawValue: saved) {
            self.currentLanguage = language
        } else {
            self.currentLanguage = .english // Default: English
        }

        if let saved = UserDefaults.standard.string(forKey: regionKey),
           let region = AppRegion(rawValue: saved) {
            self.currentRegion = region
        } else {
            self.currentRegion = .usa // Default: USA
        }
    }

    func string(_ key: String) -> String {
        string(key, language: currentLanguage)
    }

    /// Resolve a key in a specific language. Falls back to the English bundle when
    /// the requested language has no `.lproj` (the same behaviour the app relies on
    /// for languages without a translation file yet).
    func string(_ key: String, language: AppLanguage) -> String {
        let bundle = Bundle.main
        let path = bundle.path(forResource: language.languageCode, ofType: "lproj")
            ?? bundle.path(forResource: "en", ofType: "lproj")!
        let langBundle = Bundle(path: path)!
        return NSLocalizedString(key, bundle: langBundle, comment: "")
    }

    private func saveLanguage() {
        UserDefaults.standard.set(currentLanguage.rawValue, forKey: languageKey)
    }

    private func saveRegion() {
        UserDefaults.standard.set(currentRegion.rawValue, forKey: regionKey)
    }
}

extension String {
    func localized() -> String {
        LocalizationManager.shared.string(self)
    }
}
