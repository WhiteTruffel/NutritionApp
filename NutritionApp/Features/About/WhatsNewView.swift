import SwiftUI

/// „Neu in dieser Version" – zeigt die Highlights der aktuellen App-Version.
/// Wird nach einem Update automatisch einmal angezeigt und ist über die Einstellungen erreichbar.
struct WhatsNewView: View {
    @Environment(\.dismiss) private var dismiss

    private struct Feature: Identifiable {
        let id = UUID()
        let symbol: String
        let title: String
        let subtitle: String
    }

    private let features: [Feature] = [
        .init(symbol: "camera.viewfinder", title: "Gericht fotografieren (KI)",
              subtitle: "Foto machen – die KI erkennt das Gericht und schätzt Kalorien & Nährwerte."),
        .init(symbol: "drop.fill", title: "Trinken-Reiter",
              subtitle: "Flüssigkeitsziel nach Gewicht + Koffein mit Abbaukurve und „Schlaf-ok ab“-Zeit."),
        .init(symbol: "leaf.fill", title: "Nährstoffe-Reiter",
              subtitle: "Vitamine & Mineralstoffe pro Tag gegen die Tagesreferenz (RDA)."),
        .init(symbol: "figure.run", title: "Fitness-Reiter",
              subtitle: "Schlafphasen, Erholung vs. Belastung und deine Trainings an einem Ort."),
        .init(symbol: "wand.and.stars", title: "Adaptiver Stoffwechsel",
              subtitle: "Lernt deinen echten Umsatz aus Gewichtstrend & Zufuhr – statt Sport zu addieren."),
        .init(symbol: "fork.knife", title: "Bessere Portionen",
              subtitle: "„1 Riegel“, „1 Hamburger“ statt nur „100 g“ – inkl. Hersteller-Portionen."),
        .init(symbol: "list.bullet.rectangle.portrait", title: "Tagebuch-Detailansicht",
              subtitle: "Zeitpunkt, Makro-Verteilung, % vom Tagesziel und Mikronährstoffe je Eintrag."),
        .init(symbol: "key.fill", title: "Eigene API-Keys",
              subtitle: "USDA & Gemini optional verbinden – mit Schritt-für-Schritt-Anleitung in den Einstellungen.")
    ]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    VStack(spacing: 8) {
                        Image(systemName: "sparkles")
                            .font(.system(size: 44))
                            .foregroundStyle(Theme.accent)
                        Text("Neu in NutritionApp \(Theme.appVersion)")
                            .font(.title2.bold())
                            .multilineTextAlignment(.center)
                    }
                    .padding(.top, 24)

                    VStack(spacing: 18) {
                        ForEach(features) { f in
                            HStack(alignment: .top, spacing: 14) {
                                Image(systemName: f.symbol)
                                    .font(.title2)
                                    .foregroundStyle(Theme.accent)
                                    .frame(width: 34)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(f.title).font(.headline)
                                    Text(f.subtitle).font(.subheadline).foregroundStyle(.secondary)
                                }
                                Spacer(minLength: 0)
                            }
                        }
                    }
                    .padding(.horizontal, 4)
                }
                .padding(20)
            }
            .background(Color(.systemGroupedBackground))
            .safeAreaInset(edge: .bottom) {
                Button { dismiss() } label: {
                    Text("Los geht’s")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(Theme.accent, in: RoundedRectangle(cornerRadius: 14))
                        .foregroundStyle(.white)
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 8)
            }
            .navigationTitle("Was ist neu")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Fertig") { dismiss() }
                }
            }
        }
    }
}
