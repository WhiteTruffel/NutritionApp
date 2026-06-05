import SwiftUI
import SwiftData

/// Detailansicht eines Tagebuch-Eintrags (MyFitnessPal-/Yazio-Stil):
/// Zeitpunkt, Portion, volle Nährwerte, Makro-Verteilung, Mikronährstoffe der Menge,
/// Anteil am Tagesziel und Aktionen (Bearbeiten / Nochmal hinzufügen / Löschen).
struct EntryDetailView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Query private var profiles: [UserProfile]

    let entry: FoodEntry
    private let health = NutritionHealthStore()
    @State private var showEdit = false

    private var profile: UserProfile? { profiles.first }

    var body: some View {
        List {
            headerSection
            macroSection
            otherNutrientsSection
            microSection
            actionSection
        }
        .navigationTitle("Eintrag")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Bearbeiten") { showEdit = true }
            }
        }
        .sheet(isPresented: $showEdit) {
            LogEntryView(editing: entry) { _ in resyncHealth() }
        }
    }

    // MARK: Kopf

    private var headerSection: some View {
        Section {
            VStack(alignment: .leading, spacing: 6) {
                Text(entry.food?.name ?? "Mahlzeit").font(.title3.bold())
                if let brand = entry.food?.brand, !brand.isEmpty {
                    Text(brand).font(.subheadline).foregroundStyle(.secondary)
                }
                HStack(spacing: 8) {
                    Label(entry.mealType.label, systemImage: "fork.knife")
                    Text("·")
                    Label(entry.date.formatted(date: .abbreviated, time: .shortened), systemImage: "clock")
                    if entry.importedFromHealth {
                        Text("·"); Label("aus Health", systemImage: "heart.fill").foregroundStyle(.pink)
                    }
                }
                .font(.caption).foregroundStyle(.secondary)
            }
            HStack {
                Text("Menge"); Spacer()
                Text("\(Int(entry.grams.rounded())) g").foregroundStyle(.secondary)
            }
            HStack {
                Text("Kalorien").font(.headline)
                Spacer()
                Text("\(Int((entry.kcal ?? 0).rounded())) kcal").font(.headline).foregroundStyle(Theme.accent)
            }
            if let p = profile, p.kcalTarget > 0, let k = entry.kcal {
                Text("\(Int((k / p.kcalTarget * 100).rounded())) % deines Tagesziels")
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
    }

    // MARK: Makros + Energie-Split

    private var macroSection: some View {
        let p = entry.proteinG ?? 0, c = entry.carbsG ?? 0, f = entry.fatG ?? 0
        let pe = p * 4, ce = c * 4, fe = f * 9
        let tot = pe + ce + fe
        return Section("Makronährstoffe") {
            if tot > 0 {
                GeometryReader { geo in
                    HStack(spacing: 0) {
                        Rectangle().fill(.blue).frame(width: geo.size.width * pe / tot)
                        Rectangle().fill(.green).frame(width: geo.size.width * ce / tot)
                        Rectangle().fill(.orange).frame(width: geo.size.width * fe / tot)
                    }
                }
                .frame(height: 10).clipShape(Capsule())
                .listRowSeparator(.hidden)
            }
            macroRow("Eiweiß", grams: entry.proteinG, energy: pe, total: tot, target: profile?.targets.proteinG, color: .blue)
            macroRow("Kohlenhydrate", grams: entry.carbsG, energy: ce, total: tot, target: profile?.targets.carbsG, color: .green)
            macroRow("Fett", grams: entry.fatG, energy: fe, total: tot, target: profile?.targets.fatG, color: .orange)
        }
    }

    private func macroRow(_ label: String, grams: Double?, energy: Double, total: Double,
                          target: Double?, color: Color) -> some View {
        HStack {
            Circle().fill(color).frame(width: 8, height: 8)
            Text(label)
            Spacer()
            VStack(alignment: .trailing, spacing: 1) {
                Text("\(Int((grams ?? 0).rounded())) g").monospacedDigit()
                let parts = [total > 0 ? "\(Int((energy / total * 100).rounded())) % kcal" : nil,
                             (target.map { $0 > 0 } ?? false) ? "\(Int(((grams ?? 0) / target! * 100).rounded())) % Ziel" : nil]
                    .compactMap { $0 }
                if !parts.isEmpty {
                    Text(parts.joined(separator: " · ")).font(.caption2).foregroundStyle(.secondary)
                }
            }
        }
    }

    // MARK: Weitere Nährwerte

    @ViewBuilder
    private var otherNutrientsSection: some View {
        let rows: [(String, Double?, String)] = [
            ("Ballaststoffe", entry.fiberG, "g"),
            ("Zucker", entry.sugarG, "g"),
            ("Natrium", entry.sodiumMg, "mg")
        ].filter { $0.1 != nil }
        if !rows.isEmpty {
            Section("Weitere Nährwerte") {
                ForEach(rows, id: \.0) { r in
                    HStack { Text(r.0); Spacer()
                        Text("\(Int((r.1 ?? 0).rounded())) \(r.2)").foregroundStyle(.secondary).monospacedDigit() }
                }
            }
        }
    }

    // MARK: Mikronährstoffe für die Menge

    @ViewBuilder
    private var microSection: some View {
        let micros = entry.food?.micros ?? [:]
        let defs = NutrientCatalog.all.filter { (micros[$0.key] ?? 0) > 0 }
        if !defs.isEmpty {
            Section("Mikronährstoffe (diese Menge)") {
                ForEach(defs) { def in
                    let v = (micros[def.key] ?? 0) * entry.grams / 100
                    HStack { Text(def.label); Spacer()
                        Text("\(microFormat(v)) \(def.unit)").foregroundStyle(.secondary).monospacedDigit() }
                }
            }
        } else {
            Section("Mikronährstoffe") {
                Text("Für dieses Lebensmittel liegen keine Vitamin-/Mineralstoff-Daten vor. Vollständige Mikronährstoffe gibt es vor allem bei USDA-Treffern (Quelle „USDA“ in der Suche).")
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
    }

    private func microFormat(_ v: Double) -> String {
        if v >= 10 { return String(Int(v.rounded())) }
        return String(format: "%.1f", v)
    }

    // MARK: Aktionen

    private var actionSection: some View {
        Section {
            Button { duplicate() } label: { Label("Nochmal hinzufügen (heute)", systemImage: "plus.square.on.square") }
            Button(role: .destructive) { deleteEntry() } label: { Label("Löschen", systemImage: "trash") }
        }
    }

    // MARK: HealthKit-bewusste Aktionen

    private func resyncHealth() {
        let id = entry.id
        let payload = entry.makePayload()
        Task { @MainActor in
            try? await health.delete(mealID: id)
            do { try await health.save(payload); entry.syncedToHealthKit = true; try? context.save() } catch {}
        }
    }

    private func duplicate() {
        let copy = FoodEntry(date: .now, grams: entry.grams, mealType: entry.mealType, food: entry.food)
        context.insert(copy)
        try? context.save()
        let payload = copy.makePayload()
        Task { @MainActor in
            do { try await health.save(payload); copy.syncedToHealthKit = true; try? context.save() } catch {}
        }
        dismiss()
    }

    private func deleteEntry() {
        let id = entry.id
        context.delete(entry)
        try? context.save()
        Task { try? await health.delete(mealID: id) }
        dismiss()
    }
}
