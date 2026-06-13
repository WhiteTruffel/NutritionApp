import SwiftUI
import SwiftData

/// Wochenrückblick (BL18) + Zusammenhänge (BL19): 7-Tage-Ernährungsschnitt und einfache
/// Korrelationen (Koffein↔Schlaf, Kalorien↔Schlaf) aus den vorhandenen Daten.
struct WeeklyReviewView: View {
    @Environment(\.modelContext) private var context
    @Query private var entries: [FoodEntry]
    @Query private var profiles: [UserProfile]
    @Query private var intakes: [IntakeEntry]
    @Query(sort: \WeightEntry.date) private var weights: [WeightEntry]
    private let health = NutritionHealthStore()

    @State private var nights: [SleepNight] = []

    private let cal = Calendar.current

    // MARK: 7-Tage-Ernährung

    private var last7Days: [Date] {
        (0..<7).compactMap { cal.date(byAdding: .day, value: -$0, to: cal.startOfDay(for: .now)) }
    }
    private func kcal(on day: Date) -> Double {
        entries.filter { cal.isDate($0.date, inSameDayAs: day) }.reduce(0) { $0 + ($1.kcal ?? 0) }
    }
    private var avgKcal: Double {
        let vals = last7Days.map { kcal(on: $0) }.filter { $0 > 0 }
        return vals.isEmpty ? 0 : vals.reduce(0, +) / Double(vals.count)
    }
    private var daysLogged: Int { last7Days.filter { kcal(on: $0) > 0 }.count }
    private var goalKcal: Double { profiles.first?.kcalTarget ?? NutritionTargets.default.kcal }
    private var weekTotals: MacroTotals {
        entries.filter { e in last7Days.contains { cal.isDate(e.date, inSameDayAs: $0) } }.totals()
    }
    private var weightChange: Double? {
        let recent = weights.filter { $0.date >= cal.date(byAdding: .day, value: -7, to: .now)! }
        guard let first = recent.first, let last = recent.last, recent.count > 1 else { return nil }
        return last.weightKg - first.weightKg
    }

    // MARK: Korrelationen

    private func daySum(_ kv: [(Date, Double)]) -> [Date: Double] {
        Dictionary(kv.map { (cal.startOfDay(for: $0.0), $0.1) }, uniquingKeysWith: +)
    }
    private var kcalByDay: [Date: Double] {
        daySum(entries.map { ($0.date, $0.kcal ?? 0) })
    }
    private var caffeineByDay: [Date: Double] {
        daySum(intakes.filter { $0.kind == .caffeine }.map { ($0.date, $0.amount) })
    }
    /// Paare (Tageswert am Vortag, Schlafstunden der Nacht) für eine Tagesreihe.
    private func pairs(_ byDay: [Date: Double]) -> ([Double], [Double]) {
        var xs: [Double] = [], ys: [Double] = []
        for n in nights {
            guard let prev = cal.date(byAdding: .day, value: -1, to: n.date),
                  let v = byDay[cal.startOfDay(for: prev)] else { continue }
            xs.append(v); ys.append(n.hours)
        }
        return (xs, ys)
    }

    var body: some View {
        List {
            Section("recovery.avg7".localized()) {
                row("review.avg_cals".localized(), "\(Int(avgKcal.rounded())) kcal",
                    sub: "Ziel \(Int(goalKcal)) kcal · Δ \(Int((avgKcal - goalKcal).rounded())) kcal")
                row("review.avg_carbs".localized(), "\(Int((weekTotals.carbsG / max(1, Double(daysLogged))).rounded())) g")
                row("review.avg_protein".localized(), "\(Int((weekTotals.proteinG / max(1, Double(daysLogged))).rounded())) g")
                row("review.avg_fat".localized(), "\(Int((weekTotals.fatG / max(1, Double(daysLogged))).rounded())) g")
                row("review.days_logged".localized(), "\(daysLogged) / 7")
                if let weightChange {
                    row("Gewicht", "\(weightChange >= 0 ? "+" : "")\(String(format: "%.1f", weightChange)) kg")
                }
            }

            Section {
                correlationRow(title: "review.corr_caffeine_sleep".localized(), pair: pairs(caffeineByDay),
                               moreText: "review.more_caff_short".localized(),
                               lessText: "review.more_caff_long".localized())
                correlationRow(title: "review.corr_cals_sleep".localized(), pair: pairs(kcalByDay),
                               moreText: "review.more_cals_short".localized(),
                               lessText: "review.more_cals_long".localized())
            } header: {
                Text("review.correlations".localized())
            } footer: {
                Text("review.corr_note".localized())
            }
        }
        .navigationTitle("review.title".localized())
        .navigationBarTitleDisplayMode(.inline)
        .task { nights = await health.sleepNightsDated(days: 14) }
    }

    // MARK: Bausteine

    private func row(_ label: String, _ value: String, sub: String? = nil) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                if let sub { Text(sub).font(.caption).foregroundStyle(.secondary) }
            }
            Spacer()
            Text(value).foregroundStyle(.secondary).monospacedDigit()
        }
    }

    @ViewBuilder
    private func correlationRow(title: String, pair: ([Double], [Double]),
                               moreText: String, lessText: String) -> some View {
        let r = pearson(pair.0, pair.1)
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                if let r {
                    Text(abs(r) < 0.2 ? "review.no_clear".localized()
                         : "\(abs(r) < 0.5 ? "schwacher" : "deutlicher") Zusammenhang · \(r < 0 ? moreText : lessText)")
                        .font(.caption).foregroundStyle(.secondary)
                } else {
                    Text("review.insufficient".localized()).font(.caption).foregroundStyle(.tertiary)
                }
            }
            Spacer()
            if let r { Text(String(format: "r = %.2f", r)).foregroundStyle(.secondary).monospacedDigit() }
        }
    }

    private func pearson(_ xs: [Double], _ ys: [Double]) -> Double? {
        guard xs.count == ys.count, xs.count >= 4 else { return nil }
        let n = Double(xs.count)
        let mx = xs.reduce(0, +) / n, my = ys.reduce(0, +) / n
        var sxy = 0.0, sxx = 0.0, syy = 0.0
        for i in xs.indices {
            let dx = xs[i] - mx, dy = ys[i] - my
            sxy += dx * dy; sxx += dx * dx; syy += dy * dy
        }
        let den = (sxx * syy).squareRoot()
        return den > 0 ? sxy / den : nil
    }
}
