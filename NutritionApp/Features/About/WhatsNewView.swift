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
        .init(symbol: "camera.viewfinder", title: "whatsnew.f1.title".localized(),
              subtitle: "whatsnew.f1.sub".localized()),
        .init(symbol: "drop.fill", title: "whatsnew.f2.title".localized(),
              subtitle: "whatsnew.f2.sub".localized()),
        .init(symbol: "leaf.fill", title: "whatsnew.f3.title".localized(),
              subtitle: "whatsnew.f3.sub".localized()),
        .init(symbol: "figure.run", title: "whatsnew.f4.title".localized(),
              subtitle: "whatsnew.f4.sub".localized()),
        .init(symbol: "wand.and.stars", title: "whatsnew.f5.title".localized(),
              subtitle: "whatsnew.f5.sub".localized()),
        .init(symbol: "fork.knife", title: "whatsnew.f6.title".localized(),
              subtitle: "whatsnew.f6.sub".localized()),
        .init(symbol: "list.bullet.rectangle.portrait", title: "Tagebuch-Detailansicht",
              subtitle: "Zeitpunkt, Makro-Verteilung, % vom Tagesziel und Mikronährstoffe je Eintrag."),
        .init(symbol: "key.fill", title: "whatsnew.f8.title".localized(),
              subtitle: "whatsnew.f8.sub".localized())
    ]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    VStack(spacing: 8) {
                        Image(systemName: "sparkles")
                            .font(.system(size: 44))
                            .foregroundStyle(Theme.accent)
                        Text("\("whatsnew.version".localized()) \(Theme.appVersion)")
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
                    Text("whatsnew.lets_go".localized())
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(Theme.accent, in: RoundedRectangle(cornerRadius: 14))
                        .foregroundStyle(.white)
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 8)
            }
            .navigationTitle("whatsnew.title".localized())
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("common.done".localized()) { dismiss() }
                }
            }
        }
    }
}
