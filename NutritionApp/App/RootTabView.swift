import SwiftUI
import SwiftData

/// App-Einstieg: fünf Tabs (Heute, Tagebuch, Trinken, Nährstoffe, Körper).
/// HealthKit-Autorisierung, Localization, Reminders, Test-Data-Seeding zentral.
struct RootTabView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.scenePhase) private var scenePhase
    @Query private var profiles: [UserProfile]
    private let health = NutritionHealthStore()
    @State private var locManager = LocalizationManager.shared

    @AppStorage("lastSeenVersion") private var lastSeenVersion = ""
    @AppStorage("onboardingCompleted") private var onboardingCompleted = false
    @State private var showWhatsNew = false
    @State private var showOnboarding = false

    var body: some View {
        TabView {
            OverviewView()
                .tabItem { Label("Heute", systemImage: "flame.fill").accessibilityIdentifier("tab.heute") }

            DiaryView()
                .tabItem { Label("Tagebuch", systemImage: "book.fill").accessibilityIdentifier("tab.tagebuch") }

            FluidsView()
                .tabItem { Label("Trinken", systemImage: "drop.fill").accessibilityIdentifier("tab.trinken") }

            NutrientsView()
                .tabItem { Label("Nährstoffe", systemImage: "leaf.fill").accessibilityIdentifier("tab.naehrstoffe") }

            BodyView()
                .tabItem { Label("Körper", systemImage: "figure.run").accessibilityIdentifier("tab.koerper") }
        }
        .sheet(isPresented: $showWhatsNew) { WhatsNewView() }
        .fullScreenCover(isPresented: $showOnboarding) {
            NewOnboardingView {
                onboardingCompleted = true
                showOnboarding = false
            }
        }
        .task {
            // Erststart: Neues Onboarding zeigen (nicht übersprungbar).
            if !onboardingCompleted {
                showOnboarding = true
                lastSeenVersion = Theme.appVersion
            } else if lastSeenVersion != Theme.appVersion {
                showWhatsNew = true
                lastSeenVersion = Theme.appVersion
            }

            // Standard-Profil anlegen, falls noch keins existiert.
            if profiles.isEmpty {
                context.insert(UserProfile())
                try? context.save()
            }

            // Test-Daten seeden (12 Wochen Hydration-History).
            TestDataSeeding.seedHydrationHistory(in: context)

            // Reminders einrichten.
            let authorized = await RemindersManager.shared.requestAuthorization()
            if authorized {
                let settings = RemindersSettings()
                RemindersManager.shared.scheduleReminders(settings: settings)
            }

            // HealthKit-Autorisierung.
            try? await health.requestAuthorization()
            let coordinator = HealthSyncCoordinator(health: health, container: context.container)
            await coordinator.sync()
            await coordinator.startBackgroundSync()
        }
        .onChange(of: scenePhase) { _, phase in
            guard phase == .active else { return }
            let container = context.container
            Task { await HealthSyncCoordinator(health: health, container: container).sync() }
        }
    }
}
