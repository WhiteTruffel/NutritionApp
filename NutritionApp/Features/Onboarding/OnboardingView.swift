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
                Button("onboarding.skip".localized()) { onDone() }
                    .font(.subheadline).foregroundStyle(.secondary).padding()
            }

            TabView(selection: $page) {
                slide(symbol: "leaf.fill", tint: Theme.accent, title: "onboarding.welcome".localized(),
                      text: "onboarding.welcome_text".localized())
                    .tag(0)

                featureSlide.tag(1)

                healthSlide.tag(2)

                slide(symbol: "checkmark.seal.fill", tint: .green, title: "onboarding.ready".localized(),
                      text: "onboarding.ready_text".localized())
                    .tag(3)
            }
            .tabViewStyle(.page)
            .indexViewStyle(.page(backgroundDisplayMode: .always))

            Button(page < 3 ? "common.next".localized() : "whatsnew.lets_go".localized()) {
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
            Text("onboarding.features_title".localized()).font(.title.weight(.bold))
            VStack(alignment: .leading, spacing: 16) {
                featureRow("barcode.viewfinder", "onboarding.feat_scan_title".localized(), "onboarding.feat_scan_sub".localized())
                featureRow("drop.fill", "onboarding.feat_drink_title".localized(), "onboarding.feat_drink_sub".localized())
                featureRow("bed.double.fill", "onboarding.feat_recovery_title".localized(), "onboarding.feat_recovery_sub".localized())
                featureRow("chart.xyaxis.line", "onboarding.feat_trends_title".localized(), "onboarding.feat_trends_sub".localized())
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
            Text("onboarding.health_connect".localized()).font(.title2.weight(.bold))
            Text("onboarding.health_text".localized())
                .font(.callout).foregroundStyle(.secondary)
                .multilineTextAlignment(.center).padding(.horizontal, 28)
            Button {
                healthRequested = true
                Task { try? await health.requestAuthorization() }
            } label: {
                Label(healthRequested ? "onboarding.health_opened".localized() : "onboarding.health_connect".localized(),
                      systemImage: healthRequested ? "checkmark" : "heart.fill")
            }
            .buttonStyle(.bordered)
            .disabled(healthRequested)
            Spacer(); Spacer()
        }
        .frame(maxWidth: .infinity)
    }
}
