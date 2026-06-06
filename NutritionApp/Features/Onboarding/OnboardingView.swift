import SwiftUI

/// Erststart-Onboarding (BL25): kurze, freundliche Einführung in vier Schritten –
/// Begrüßung, Funktionsüberblick, Apple-Health-Verbindung und „los geht's".
/// Wird nur beim ersten App-Start gezeigt (AppStorage „didOnboard").
struct OnboardingView: View {
    let onDone: () -> Void
    private let health = NutritionHealthStore()

    @State private var page = 0
    @State private var healthRequested = false

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Spacer()
                Button("Überspringen") { onDone() }
                    .font(.subheadline).foregroundStyle(.secondary).padding()
            }

            TabView(selection: $page) {
                slide(symbol: "leaf.fill", tint: Theme.accent, title: "Willkommen",
                      text: "Dein Tracker für Ernährung, Trinken und Erholung – einfach, schnell, mit Apple Health verbunden.")
                    .tag(0)

                featureSlide.tag(1)

                healthSlide.tag(2)

                slide(symbol: "checkmark.seal.fill", tint: .green, title: "Bereit",
                      text: "Lege direkt los – deine Ziele kannst du jederzeit unter Heute › Zahnrad anpassen. Viel Erfolg!")
                    .tag(3)
            }
            .tabViewStyle(.page)
            .indexViewStyle(.page(backgroundDisplayMode: .always))

            Button(page < 3 ? "Weiter" : "Los geht's") {
                if page < 3 { withAnimation { page += 1 } } else { onDone() }
            }
            .font(.headline)
            .frame(maxWidth: .infinity).padding()
            .background(Theme.accent, in: RoundedRectangle(cornerRadius: 14))
            .foregroundStyle(.white)
            .padding(.horizontal, 24).padding(.bottom, 12)
        }
    }

    // MARK: Slides

    private func slide(symbol: String, tint: Color, title: String, text: String) -> some View {
        VStack(spacing: 20) {
            Spacer()
            Image(systemName: symbol).font(.system(size: 64)).foregroundStyle(tint)
            Text(title).font(.title.weight(.bold))
            Text(text).font(.body).foregroundStyle(.secondary)
                .multilineTextAlignment(.center).padding(.horizontal, 32)
            Spacer(); Spacer()
        }
        .frame(maxWidth: .infinity)
    }

    private var featureSlide: some View {
        VStack(spacing: 22) {
            Spacer()
            Text("Das kannst du").font(.title.weight(.bold))
            VStack(alignment: .leading, spacing: 16) {
                featureRow("barcode.viewfinder", "Scannen & suchen", "Barcode, Foto oder Texteingabe – Nährwerte automatisch.")
                featureRow("drop.fill", "Trinken & Koffein", "Wasser und Koffein mit Pacing und Schlaf-Schwelle.")
                featureRow("bed.double.fill", "Erholung & Belastung", "Schlaf, Ruhepuls, Training – aus Apple Health.")
                featureRow("chart.xyaxis.line", "Trends", "Ruhepuls, Schritte, Gewicht & Co. über Zeit.")
            }
            .padding(.horizontal, 28)
            Spacer(); Spacer()
        }
        .frame(maxWidth: .infinity)
    }

    private func featureRow(_ symbol: String, _ title: String, _ text: String) -> some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: symbol).font(.title3).foregroundStyle(Theme.accent).frame(width: 30)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.subheadline.weight(.semibold))
                Text(text).font(.caption).foregroundStyle(.secondary)
            }
        }
    }

    private var healthSlide: some View {
        VStack(spacing: 20) {
            Spacer()
            Image(systemName: "heart.text.square.fill").font(.system(size: 64)).foregroundStyle(.red)
            Text("Mit Apple Health verbinden").font(.title2.weight(.bold))
            Text("So fließen Schritte, Training, Schlaf, Ruhepuls und Gewicht automatisch ein – und deine Mahlzeiten landen umgekehrt in Health. Du entscheidest im nächsten Dialog, was du freigibst.")
                .font(.callout).foregroundStyle(.secondary)
                .multilineTextAlignment(.center).padding(.horizontal, 28)
            Button {
                healthRequested = true
                Task { try? await health.requestAuthorization() }
            } label: {
                Label(healthRequested ? "Health-Dialog geöffnet" : "Mit Apple Health verbinden",
                      systemImage: healthRequested ? "checkmark" : "heart.fill")
            }
            .buttonStyle(.bordered)
            .disabled(healthRequested)
            Spacer(); Spacer()
        }
        .frame(maxWidth: .infinity)
    }
}
