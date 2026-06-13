import SwiftUI
import SwiftData

/// Cronometer-artige Mikronährstoff-Auswertung: Tagessummen je Vitamin/Mineralstoff
/// gegen die Tagesreferenz (RDA), mit Fortschrittsbalken. Datenbasis sind die geloggten
/// Einträge des Tages; Mikronährstoffe stammen v. a. aus USDA-Lebensmitteln.
struct NutrientsView: View {
    @Query(sort: \FoodEntry.date, order: .reverse) private var allEntries: [FoodEntry]
    @State private var selectedDay: Date = .now

    private var dayEntries: [FoodEntry] {
        allEntries.filter { Calendar.current.isDate($0.date, inSameDayAs: selectedDay) }
    }

    /// Tagessummen je Nährstoff-Key (per-100g × g/100, über alle Einträge).
    private var totals: [String: Double] {
        var t: [String: Double] = [:]
        for e in dayEntries {
            guard let m = e.food?.micros, !m.isEmpty else { continue }
            let factor = e.grams / 100
            for (k, v) in m { t[k, default: 0] += v * factor }
        }
        return t
    }

    /// Anteil der Tageseinträge, für die überhaupt Mikronährstoffe vorliegen.
    private var coverage: (withData: Int, total: Int) {
        let total = dayEntries.count
        let withData = dayEntries.filter { !($0.food?.micros.isEmpty ?? true) }.count
        return (withData, total)
    }

    private var hasAnyData: Bool { totals.values.contains { $0 > 0 } }

    // MARK: Hauptnährstoffe (Tagessummen der klassischen Etikett-Werte)

    private func sum(_ f: (FoodEntry) -> Double?) -> Double { dayEntries.reduce(0) { $0 + (f($1) ?? 0) } }
    private var kcalT: Double { sum { $0.kcal } }
    private var carbsT: Double { sum { $0.carbsG } }
    private var sugarT: Double { sum { $0.sugarG } }
    private var proteinT: Double { sum { $0.proteinG } }
    private var fatT: Double { sum { $0.fatG } }
    private var satFatT: Double { sum { $0.satFatG } }
    private var fiberT: Double { sum { $0.fiberG } }
    private var saltT: Double { sum { $0.sodiumMg.map { $0 * 2.5 / 1000 } } }   // mg Natrium → g Salz

    var body: some View {
        NavigationStack {
            Group {
                if dayEntries.isEmpty {
                    ContentUnavailableView(
                        "nutrients.empty_title".localized(),
                        systemImage: "leaf",
                        description: Text("nutrients.empty_desc".localized()))
                } else {
                    List {
                        mainSection
                        if hasAnyData {
                            ForEach(NutrientGroup.allCases, id: \.self) { group in
                                Section(group.rawValue) {
                                    ForEach(NutrientCatalog.defs(in: group)) { def in
                                        nutrientRow(def)
                                    }
                                }
                            }
                            Section {
                                let c = coverage
                                Text("\("nutrients.coverage.prefix".localized()) \(c.withData) \("nutrients.coverage.mid".localized()) \(c.total) \("nutrients.coverage.suffix".localized())")
                                    .font(.caption).foregroundStyle(.secondary)
                            }
                        } else {
                            Section("nutrients.section.vitamins".localized()) {
                                Text("nutrients.no_micros".localized())
                                    .font(.caption).foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }
            .navigationTitle("tab.nutrients".localized())
            .navigationBarTitleDisplayMode(.inline)
            .safeAreaInset(edge: .top) { dateBar }
        }
    }

    // MARK: Hauptnährstoffe-Sektion

    private var mainSection: some View {
        Section {
            mainRow("nutrient.calories".localized(), kcalT, ref: 2000, unit: "kcal")
            mainRow("nutrient.carbs".localized(), carbsT, ref: 260, unit: "g")
            mainRow("nutrient.sugar".localized(), sugarT, ref: 90, unit: "g", limit: true, indent: true)
            mainRow("nutrient.fiber".localized(), fiberT, ref: 30, unit: "g")
            mainRow("nutrient.protein".localized(), proteinT, ref: 50, unit: "g")
            mainRow("nutrient.fat".localized(), fatT, ref: 70, unit: "g")
            mainRow("nutrient.satfat_of".localized(), satFatT, ref: 20, unit: "g", limit: true, indent: true)
            mainRow("nutrient.salt".localized(), saltT, ref: 6, unit: "g", limit: true)
        } header: {
            Text("nutrients.section.main".localized())
        } footer: {
            Text("nutrients.reference".localized())
        }
    }

    @ViewBuilder
    private func mainRow(_ label: String, _ value: Double, ref: Double, unit: String,
                         limit: Bool = false, indent: Bool = false) -> some View {
        let pct = ref > 0 ? value / ref : 0
        VStack(spacing: 4) {
            HStack {
                Text(label).font(.subheadline).foregroundStyle(indent ? Color.secondary : Color.primary)
                Spacer()
                if value > 0 {
                    Text("\(format(value)) / \(format(ref)) \(unit)")
                        .font(.caption).foregroundStyle(.secondary).monospacedDigit()
                } else {
                    Text("— \(unit)").font(.caption).foregroundStyle(.tertiary)
                }
            }
            ProgressView(value: min(pct, 1)).tint(mainColor(pct, limit: limit))
        }
        .padding(.vertical, 2)
    }

    private func mainColor(_ p: Double, limit: Bool) -> Color {
        if limit { return p < 0.8 ? .green : (p <= 1.0 ? .orange : .red) }
        return p < 0.5 ? .orange : (p < 1.0 ? .green : .blue)
    }

    // MARK: Nährstoff-Zeile mit RDA-Balken

    @ViewBuilder
    private func nutrientRow(_ def: NutrientDef) -> some View {
        let value = totals[def.key] ?? 0
        let pct = def.rda > 0 ? min(value / def.rda, 1.0) : 0
        VStack(spacing: 4) {
            HStack {
                Text(def.localizedLabel).font(.subheadline)
                Spacer()
                if value > 0 {
                    Text("\(format(value)) / \(format(def.rda)) \(def.unit)")
                        .font(.caption).foregroundStyle(.secondary).monospacedDigit()
                } else {
                    Text("— \(def.unit)").font(.caption).foregroundStyle(.tertiary)
                }
            }
            ProgressView(value: pct)
                .tint(color(forPct: value / max(def.rda, 0.0001)))
        }
        .padding(.vertical, 2)
    }

    private func color(forPct p: Double) -> Color {
        switch p {
        case ..<0.5:  return .orange
        case ..<1.0:  return .green
        default:      return .blue       // ≥ 100 % erreicht
        }
    }

    private func format(_ v: Double) -> String {
        if v >= 100 { return String(Int(v.rounded())) }
        if v >= 10  { return String(format: "%.0f", v) }
        return String(format: "%.1f", v)
    }

    // MARK: Datumsleiste

    private var dateBar: some View {
        HStack {
            Button { shiftDay(-1) } label: { Image(systemName: "chevron.left").frame(width: 44, height: 36) }
            Spacer()
            Text(dayLabel).font(.headline)
            Spacer()
            Button { shiftDay(1) } label: { Image(systemName: "chevron.right").frame(width: 44, height: 36) }
        }
        .padding(.horizontal, 8).padding(.vertical, 6)
        .background(.bar)
    }

    private var dayLabel: String {
        let cal = Calendar.current
        if cal.isDateInToday(selectedDay) { return "tab.today".localized() }
        if cal.isDateInYesterday(selectedDay) { return "diary.yesterday".localized() }
        return selectedDay.formatted(.dateTime.weekday(.wide).day().month(.abbreviated).locale(Locale(identifier: LocalizationManager.shared.currentLanguage.languageCode)))
    }

    private func shiftDay(_ delta: Int) {
        if let d = Calendar.current.date(byAdding: .day, value: delta, to: selectedDay) { selectedDay = d }
    }
}
