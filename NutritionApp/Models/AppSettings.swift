import Foundation
import SwiftUI

// MARK: - Locales & Settings Enums

enum AppRegion: String, Codable, CaseIterable, Identifiable {
    case germany, austria, switzerlandDE, switzerlandFR, switzerlandIT, france, usa, canada, uk, australia, india, farsi, arabic, japan, china, serbia, croatia, russia, hungary, italy, spain, portugal, brazil

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .germany: return "Germany"
        case .austria: return "Austria"
        case .switzerlandDE: return "Switzerland (German)"
        case .switzerlandFR: return "Switzerland (French)"
        case .switzerlandIT: return "Switzerland (Italian)"
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
        case .germany, .austria, .switzerlandDE: return "de"
        case .france, .switzerlandFR: return "fr"
        case .usa, .canada, .uk, .australia, .india: return "en"
        case .farsi: return "fa"
        case .arabic: return "ar"
        case .japan: return "ja"
        case .china: return "zh"
        case .serbia: return "sr"
        case .croatia: return "hr"
        case .russia: return "ru"
        case .hungary: return "hu"
        case .italy, .switzerlandIT: return "it"
        case .spain: return "es"
        case .portugal, .brazil: return "pt"
        }
    }
}

enum AppLanguage: String, Codable, CaseIterable, Identifiable {
    case english, german, french, frenchSwiss, frenchCanadian, afrikaans, hindi, farsi, arabic, japanese, chinese, serbian, serbianLatin, croatian, russian, hungarian, italian, spanish, portuguese, brazilianPortuguese, korean, polish, norwegian, finnish, swedish, danish, czech, slovak, romanian, bulgarian, turkish, greek, swahili, oshiwambo, khoekhoe, herero, silozi

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .english: return "English"
        case .german: return "Deutsch"
        case .french: return "Français (France)"
        case .frenchSwiss: return "Français (Suisse)"
        case .frenchCanadian: return "Français (Canada)"
        case .afrikaans: return "Afrikaans"
        case .hindi: return "हिन्दी"
        case .farsi: return "فارسی"
        case .arabic: return "العربية"
        case .japanese: return "日本語"
        case .chinese: return "中文"
        case .serbian: return "Српски"
        case .serbianLatin: return "Srpski"
        case .croatian: return "Hrvatski"
        case .russian: return "Русский"
        case .hungarian: return "Magyar"
        case .italian: return "Italiano"
        case .spanish: return "Español"
        case .portuguese: return "Português (Portugal)"
        case .brazilianPortuguese: return "Português (Brasil)"
        case .korean: return "한국어"
        case .polish: return "Polski"
        case .norwegian: return "Norsk"
        case .finnish: return "Suomi"
        case .swedish: return "Svenska"
        case .danish: return "Dansk"
        case .czech: return "Čeština"
        case .slovak: return "Slovenčina"
        case .romanian: return "Română"
        case .bulgarian: return "Български"
        case .turkish: return "Türkçe"
        case .greek: return "Ελληνικά"
        case .swahili: return "Kiswahili"
        case .oshiwambo: return "Oshiwambo"
        case .khoekhoe: return "Khoekhoegowab (Damara/Nama)"
        case .herero: return "Otjiherero"
        case .silozi: return "Silozi (Caprivi)"
        }
    }

    var languageCode: String {
        switch self {
        case .english: return "en"
        case .german: return "de"
        case .french: return "fr"
        case .frenchSwiss: return "fr-CH"
        case .frenchCanadian: return "fr-CA"
        case .afrikaans: return "af"
        case .hindi: return "hi"
        case .farsi: return "fa"
        case .arabic: return "ar"
        case .japanese: return "ja"
        case .chinese: return "zh"
        case .serbian: return "sr"
        case .serbianLatin: return "sr-Latn"
        case .croatian: return "hr"
        case .russian: return "ru"
        case .hungarian: return "hu"
        case .italian: return "it"
        case .spanish: return "es"
        case .portuguese: return "pt"
        case .brazilianPortuguese: return "pt-BR"
        case .korean: return "ko"
        case .polish: return "pl"
        case .norwegian: return "nb"
        case .finnish: return "fi"
        case .swedish: return "sv"
        case .danish: return "da"
        case .czech: return "cs"
        case .slovak: return "sk"
        case .romanian: return "ro"
        case .bulgarian: return "bg"
        case .turkish: return "tr"
        case .greek: return "el"
        case .swahili: return "sw"
        case .oshiwambo: return "ng"
        case .khoekhoe: return "naq"
        case .herero: return "hz"
        case .silozi: return "loz"
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

    /// Approximate Fitzpatrick skin tone, used for visual swatches.
    var toneColor: Color {
        switch self {
        case .typeI:   return Color(red: 0.98, green: 0.87, blue: 0.79)
        case .typeII:  return Color(red: 0.95, green: 0.80, blue: 0.66)
        case .typeIII: return Color(red: 0.87, green: 0.67, blue: 0.46)
        case .typeIV:  return Color(red: 0.74, green: 0.53, blue: 0.33)
        case .typeV:   return Color(red: 0.52, green: 0.35, blue: 0.20)
        case .typeVI:  return Color(red: 0.31, green: 0.21, blue: 0.14)
        }
    }

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

/// Horizontal swatch selector so users pick their Fitzpatrick skin tone by
/// sight rather than by reading roman numerals.
struct SkinTonePicker: View {
    @Binding var selection: FitzpatrickSkinType
    var body: some View {
        HStack(spacing: 8) {
            ForEach(FitzpatrickSkinType.allCases) { type in
                Circle()
                    .fill(type.toneColor)
                    .frame(width: 30, height: 30)
                    .overlay(
                        Circle().strokeBorder(
                            selection == type ? Color.accentColor : Color.primary.opacity(0.15),
                            lineWidth: selection == type ? 3 : 1)
                    )
                    .overlay(
                        selection == type
                            ? Image(systemName: "checkmark")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundStyle(.white)
                            : nil
                    )
                    .onTapGesture { selection = type }
                    .accessibilityLabel(type.displayName)
                    .accessibilityAddTraits(selection == type ? .isSelected : [])
            }
        }
    }
}

