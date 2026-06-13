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
        .navigationTitle("entry.title".localized())
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("entry.edit".localized()) { showEdit = true }
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
                Text(entry.food?.name ?? "diary.meal_fallback".localized()).font(.title3.bold())
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
                Text("entry.amount".localized()); Spacer()
                Text("\(Int(entry.grams.rounded())) g").foregroundStyle(.secondary)
            }
            HStack {
                Text("nutrient.calories".localized()).font(.headline)
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
        return Section("settings.section.macros".localized()) {
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
            macroRow("nutrient.protein".localized(), grams: entry.proteinG, energy: pe, total: tot, target: profile?.targets.proteinG, color: .blue)
            macroRow("nutrient.carbs".localized(), grams: entry.carbsG, energy: ce, total: tot, target: profile?.targets.carbsG, color: .green)
            macroRow("nutrient.fat".localized(), grams: entry.fatG, energy: fe, total: tot, target: profile?.targets.fatG, color: .orange)
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
            ("nutrient.fiber".localized(), entry.fiberG, "g"),
            ("nutrient.sugar".localized(), entry.sugarG, "g"),
            ("nutrient.sodium".localized(), entry.sodiumMg, "mg")
        ].filter { $0.1 != nil }
        if !rows.isEmpty {
            Section("entry.more_nutrients".localized()) {
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
            Section("entry.micros_amount".localized()) {
                ForEach(defs) { def in
                    let v = (micros[def.key] ?? 0) * entry.grams / 100
                    HStack { Text(def.label); Spacer()
                        Text("\(microFormat(v)) \(def.unit)").foregroundStyle(.secondary).monospacedDigit() }
                }
            }
        } else {
            Section("entry.micros".localized()) {
                Text("entry.no_micros".localized())
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
            Button { duplicate() } label: { Label("detail.add_again".localized(), systemImage: "plus.square.on.square") }
            Button(role: .destructive) { deleteEntry() } label: { Label("common.delete".localized(), systemImage: "trash") }
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
