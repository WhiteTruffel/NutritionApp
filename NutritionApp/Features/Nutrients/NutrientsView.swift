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

    var body: some View {
        NavigationStack {
            Group {
                if dayEntries.isEmpty {
                    ContentUnavailableView(
                        "Noch keine Einträge",
                        systemImage: "leaf",
                        description: Text("Erfasse Lebensmittel, um deine Vitamine & Mineralstoffe zu sehen."))
                } else if !hasAnyData {
                    ContentUnavailableView {
                        Label("Keine Mikronährstoff-Daten", systemImage: "leaf")
                    } description: {
                        Text("Für die heutigen Einträge liegen keine Vitamin-/Mineralstoff-Werte vor. Tipp: Wähle in der Suche einen Treffer mit Quelle „USDA“ – diese liefern vollständige Mikronährstoffe.")
                    }
                } else {
                    List {
                        ForEach(NutrientGroup.allCases, id: \.self) { group in
                            Section(group.rawValue) {
                                ForEach(NutrientCatalog.defs(in: group)) { def in
                                    nutrientRow(def)
                                }
                            }
                        }
                        Section {
                            let c = coverage
                            Text("Mikronährstoff-Daten liegen für \(c.withData) von \(c.total) Einträgen vor – am vollständigsten bei USDA-Treffern.")
                                .font(.caption).foregroundStyle(.secondary)
                        }
                    }
                }
            }
            .navigationTitle("Nährstoffe")
            .navigationBarTitleDisplayMode(.inline)
            .safeAreaInset(edge: .top) { dateBar }
        }
    }

    // MARK: Nährstoff-Zeile mit RDA-Balken

    @ViewBuilder
    private func nutrientRow(_ def: NutrientDef) -> some View {
        let value = totals[def.key] ?? 0
        let pct = def.rda > 0 ? min(value / def.rda, 1.0) : 0
        VStack(spacing: 4) {
            HStack {
                Text(def.label).font(.subheadline)
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
        if cal.isDateInToday(selectedDay) { return "Heute" }
        if cal.isDateInYesterday(selectedDay) { return "Gestern" }
        return selectedDay.formatted(.dateTime.weekday(.wide).day().month(.abbreviated))
    }

    private func shiftDay(_ delta: Int) {
        if let d = Calendar.current.date(byAdding: .day, value: delta, to: selectedDay) { selectedDay = d }
    }
}
