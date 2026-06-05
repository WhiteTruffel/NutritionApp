import SwiftUI

/// Zentrale Design-Tokens (Markenfarbe, Geometrie). Eine Akzentfarbe für die ganze App.
enum Theme {
    /// Markenfarbe (Grün-Teal, passend zum App-Icon). Global via `.tint(Theme.accent)`.
    static let accent = Color(red: 0.18, green: 0.74, blue: 0.52)

    static let radius: CGFloat = 16
    static let cardPadding: CGFloat = 20
    static let screenPadding: CGFloat = 16

    /// Aktuelle App-Version (für „Neu in dieser Version").
    static let appVersion = "1.1"
}

/// Einheitlicher Card-Stil (gleicher Radius/Padding/Hintergrund überall).
private struct CardModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(Theme.cardPadding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(.secondarySystemGroupedBackground),
                        in: RoundedRectangle(cornerRadius: Theme.radius))
    }
}

extension View {
    func card() -> some View { modifier(CardModifier()) }
}
