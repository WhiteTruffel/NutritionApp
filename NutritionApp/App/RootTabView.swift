import SwiftUI
import SwiftData

/// App-Einstieg: zwei Tabs im MyFitnessPal-Muster – Dashboard („Heute") und Tagebuch.
/// HealthKit-Autorisierung wird hier einmal zentral angefragt.
struct RootTabView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.scenePhase) private var scenePhase
    @Query private var profiles: [UserProfile]
    private let health = NutritionHealthStore()

    @AppStorage("lastSeenVersion") private var lastSeenVersion = ""
    @State private var showWhatsNew = false

    var body: some View {
        TabView {
            OverviewView()
                .tabItem { Label("Heute", systemImage: "flame.fill") }

            DiaryView()
                .tabItem { Label("Tagebuch", systemImage: "book.fill") }

            FluidsView()
                .tabItem { Label("Trinken", systemImage: "drop.fill") }

            NutrientsView()
                .tabItem { Label("Nährstoffe", systemImage: "leaf.fill") }

            BodyView()
                .tabItem { Label("Körper", systemImage: "figure.run") }
        }
        .sheet(isPresented: $showWhatsNew) { WhatsNewView() }
        .task {
            // „Neu in dieser Version" einmalig nach einem Update zeigen.
            if lastSeenVersion != Theme.appVersion {
                showWhatsNew = true
                lastSeenVersion = Theme.appVersion
            }
            // Standard-Profil anlegen, falls noch keins existiert (liefert sofort sinnvolle Ziele).
            if profiles.isEmpty {
                context.insert(UserProfile())
                try? context.save()
            }
            try? await health.requestAuthorization()
            let coordinator = HealthSyncCoordinator(health: health, container: context.container)
            await coordinator.sync()              // Import beim Start (Deltas seit letztem Mal)
            await coordinator.startBackgroundSync() // Observer + Background Delivery (Gerät + Capability)
        }
        .onChange(of: scenePhase) { _, phase in
            guard phase == .active else { return }
            let container = context.container
            Task { await HealthSyncCoordinator(health: health, container: container).sync() }
        }
    }
}
