import SwiftUI
import SwiftData

@main
struct NutritionApp: App {
    let container: ModelContainer
    @AppStorage(AppearanceMode.storageKey) private var appearanceRaw = AppearanceMode.system.rawValue

    init() {
        let schema = Schema([FoodItem.self, FoodEntry.self, DailyGoal.self, UserProfile.self,
                             WeightEntry.self, IntakeEntry.self, MealTemplate.self,
                             HRVMeasurementRecord.self])
        // cloudKitDatabase: .none — die App hat zwar eine CloudKit-Berechtigung (für die zentrale
        // Food-DB via CloudFoodDatabase), aber der lokale SwiftData-Store soll NICHT automatisch
        // mit CloudKit spiegeln. Sonst scheitert der Container an @Attribute(.unique)-IDs.
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false, cloudKitDatabase: .none)

        // 1. Versuch: normaler Store (mit automatischer Leichtgewicht-Migration).
        if let c = try? ModelContainer(for: schema, configurations: config) {
            container = c
            return
        }

        // 2. Versuch: Migration fehlgeschlagen → veralteten Store einmalig entfernen
        // und frisch anlegen, damit die App startet statt abzustürzen.
        Self.deleteStoreFiles(for: config)
        if let c = try? ModelContainer(for: schema, configurations: config) {
            container = c
            return
        }

        // 3. Fallback: reiner In-Memory-Store, damit die App in jedem Fall startet.
        let memory = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true, cloudKitDatabase: .none)
        container = try! ModelContainer(for: schema, configurations: memory)
    }

    /// Entfernt die SwiftData-SQLite-Dateien des Default-Stores (inkl. -wal/-shm).
    private static func deleteStoreFiles(for config: ModelConfiguration) {
        let fm = FileManager.default
        let appSupport = fm.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
        var candidates: [URL] = []
        if config.url.path.isEmpty == false { candidates.append(config.url) }
        if let base = appSupport {
            candidates.append(base.appendingPathComponent("default.store"))
        }
        for url in candidates {
            for suffix in ["", "-wal", "-shm"] {
                let target = URL(fileURLWithPath: url.path + suffix)
                try? fm.removeItem(at: target)
            }
        }
    }

    var body: some Scene {
        WindowGroup {
            RootTabView()
                .tint(Theme.accent)
                .preferredColorScheme((AppearanceMode(rawValue: appearanceRaw) ?? .system).colorScheme)
        }
        .modelContainer(container)
    }
}
