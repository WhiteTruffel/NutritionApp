import Foundation
import SwiftUI

// MARK: - Locales & Settings Enums

enum AppRegion: String, Codable, CaseIterable, Identifiable {
    case germany, austria, switzerland, france, usa, canada, uk, australia, india, farsi, arabic, japan, china, serbia, croatia, russia, hungary, italy, spain, portugal, brazil

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .germany: return "Germany"
        case .austria: return "Austria"
        case .switzerland: return "Switzerland"
        case .france: return "France"
        case .usa: return "USA"
        case .canada: return "Canada"
        case .uk: return "United Kingdom"
        case .australia: return "Australia"
        case .india: return "India"
        case .farsi: return "Iran"
        case .arabic: return "Middle East"
        case .japan: return "Japan"
        case .china: return "China"
        case .serbia: return "Serbia"
        case .croatia: return "Croatia"
        case .russia: return "Russia"
        case .hungary: return "Hungary"
        case .italy: return "Italy"
        case .spain: return "Spain"
        case .portugal: return "Portugal"
        case .brazil: return "Brazil"
        }
    }

    var firstDayOfWeek: Int { // 1=Sunday, 2=Monday
        switch self {
        case .usa, .canada, .australia, .india: return 1 // Sunday
        default: return 2 // Monday
        }
    }

    var preferredUnitSystem: UnitSystem {
        switch self {
        case .usa, .canada: return .imperial
        default: return .metric
        }
    }

    var languageCode: String {
        switch self {
        case .germany, .austria, .switzerland: return "de"
        case .france: return "fr"
        case .usa, .canada, .uk, .australia, .india: return "en"
        case .farsi: return "fa"
        case .arabic: return "ar"
        case .japan: return "ja"
        case .china: return "zh"
        case .serbia: return "sr"
        case .croatia: return "hr"
        case .russia: return "ru"
        case .hungary: return "hu"
        case .italy: return "it"
        case .spain: return "es"
        case .portugal, .brazil: return "pt"
        }
    }
}

enum AppLanguage: String, Codable, CaseIterable, Identifiable {
    case english, german, french, frenchCanadian, afrikaans, hindi, farsi, arabic, japanese, chinese, serbian, croatian, russian, hungarian, italian, spanish, portuguese, brazilianPortuguese, korean

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .english: return "English"
        case .german: return "Deutsch"
        case .french: return "Français"
        case .frenchCanadian: return "Français (Canada)"
        case .afrikaans: return "Afrikaans"
        case .hindi: return "हिन्दी"
        case .farsi: return "فارسی"
        case .arabic: return "العربية"
        case .japanese: return "日本語"
        case .chinese: return "中文"
        case .serbian: return "Српски"
        case .croatian: return "Hrvatski"
        case .russian: return "Русский"
        case .hungarian: return "Magyar"
        case .italian: return "Italiano"
        case .spanish: return "Español"
        case .portuguese: return "Português"
        case .brazilianPortuguese: return "Português (Brasil)"
        case .korean: return "한국어"
        }
    }

    var languageCode: String {
        switch self {
        case .english: return "en"
        case .german: return "de"
        case .french: return "fr"
        case .frenchCanadian: return "fr-CA"
        case .afrikaans: return "af"
        case .hindi: return "hi"
        case .farsi: return "fa"
        case .arabic: return "ar"
        case .japanese: return "ja"
        case .chinese: return "zh"
        case .serbian: return "sr"
        case .croatian: return "hr"
        case .russian: return "ru"
        case .hungarian: return "hu"
        case .italian: return "it"
        case .spanish: return "es"
        case .portuguese: return "pt"
        case .brazilianPortuguese: return "pt-BR"
        case .korean: return "ko"
        }
    }
}

enum UnitSystem: String, Codable, CaseIterable, Identifiable {
    case metric, imperial
    var id: String { rawValue }
    var displayName: String { self == .metric ? "Metric (ml, kg, cm)" : "Imperial (oz, lbs, inches)" }
}

enum FitzpatrickSkinType: String, Codable, CaseIterable, Identifiable {
    case typeI, typeII, typeIII, typeIV, typeV, typeVI

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .typeI: return "Type I (Very Fair)"
        case .typeII: return "Type II (Fair)"
        case .typeIII: return "Type III (Medium)"
        case .typeIV: return "Type IV (Olive)"
        case .typeV: return "Type V (Brown)"
        case .typeVI: return "Type VI (Dark Brown/Black)"
        }
    }

    var description: String {
        switch self {
        case .typeI: return "Always burns, never tans. Red, white, or pale skin."
        case .typeII: return "Usually burns, sometimes tans. Light or fair skin."
        case .typeIII: return "Sometimes burns, sometimes tans. Medium skin."
        case .typeIV: return "Rarely burns, always tans. Olive or light brown skin."
        case .typeV: return "Never burns, always deeply tans. Brown skin."
        case .typeVI: return "Never burns. Dark brown or black skin."
        }
    }
}

enum Gender: String, Codable, CaseIterable, Identifiable {
    case male, female, diverse

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .male: return "Male"
        case .female: return "Female"
        case .diverse: return "Diverse"
        }
    }
}

// MARK: - Reminders Settings

@Observable
final class RemindersSettings: Codable {
    var morningMotivationEnabled: Bool = true
    var morningMotivationTime: Date = Date(timeIntervalSince1970: 8 * 3600) // 8:00 AM

    var breakfastReminderEnabled: Bool = true
    var breakfastReminderTime: Date = Date(timeIntervalSince1970: 9 * 3600) // 9:00 AM

    var lunchReminderEnabled: Bool = true
    var lunchReminderTime: Date = Date(timeIntervalSince1970: 13 * 3600) // 1:00 PM

    var dinnerReminderEnabled: Bool = true
    var dinnerReminderTime: Date = Date(timeIntervalSince1970: 19 * 3600) // 7:00 PM

    var bedtimeReminderEnabled: Bool = true
    var bedtimeReminderTime: Date = Date(timeIntervalSince1970: 22 * 3600) // 10:00 PM (user-configured)
    var bedtimeBefore: Int = 60 // minutes before bedtime to remind
}

// MARK: - App Settings (Persisted)

@Observable
final class AppSettingsState: Codable {
    var region: AppRegion = .germany
    var language: AppLanguage = .german
    var unitSystem: UnitSystem = .metric
    var skinType: FitzpatrickSkinType = .typeII
    var gender: Gender = .male
    var onboardingCompleted: Bool = false
    var reminders: RemindersSettings = RemindersSettings()
}
