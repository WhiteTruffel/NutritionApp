import SwiftUI
import SwiftData
import HealthKit
import Charts

/// Whoop/Bevel-artige Trend-Ansicht: je Metrik eine Karte mit aktuellem Ø, Verlauf,
/// Min/Max und Delta zur Vorperiode. Ein Zeitraum-Umschalter (7 T / 14 T / 4 W / 3 M)
/// stellt alle Karten gleichzeitig um. Quellen: Apple Health + eigene Logs.
enum TrendRange: String, CaseIterable, Identifiable {
    case d7 = "7 T", d14 = "14 T", w4 = "4 W", m3 = "3 M"
    var id: String { rawValue }
    var days: Int { switch self { case .d7: return 7; case .d14: return 14; case .w4: return 28; case .m3: return 90 } }
}

enum TrendChartStyle { case line, bar }

/// Beschreibt eine aus Apple Health ladbare Metrik.
struct HKMetric {
    let title: String
    let unit: String
    let symbol: String
    let tint: Color
    let higherIsBetter: Bool?      // nil = neutral (kein gut/schlecht)
    let style: TrendChartStyle
    let decimals: Int
    let id: HKQuantityTypeIdentifier
    let stat: TrendStat
    let scale: Double              // z. B. Körperfett: Bruchteil → Prozent (×100)

    static let restingHR = HKMetric(title: "Ruhepuls", unit: "bpm", symbol: "heart.fill", tint: .red,
        higherIsBetter: false, style: .line, decimals: 0, id: .restingHeartRate, stat: .average, scale: 1)
    static let hrv = HKMetric(title: "HRV", unit: "ms", symbol: "waveform.path.ecg", tint: .teal,
        higherIsBetter: true, style: .line, decimals: 0, id: .heartRateVariabilitySDNN, stat: .average, scale: 1)
    static let steps = HKMetric(title: "Schritte", unit: "", symbol: "figure.walk", tint: .green,
        higherIsBetter: true, style: .bar, decimals: 0, id: .stepCount, stat: .sum, scale: 1)
    static let exercise = HKMetric(title: "Training", unit: "min", symbol: "figure.run", tint: .orange,
        higherIsBetter: true, style: .bar, decimals: 0, id: .appleExerciseTime, stat: .sum, scale: 1)
    static let activeEnergy = HKMetric(title: "Aktiv-Kalorien", unit: "kcal", symbol: "flame.fill", tint: .pink,
        higherIsBetter: true, style: .bar, decimals: 0, id: .activeEnergyBurned, stat: .sum, scale: 1)
    static let weight = HKMetric(title: "Gewicht", unit: "kg", symbol: "scalemass.fill", tint: .indigo,
        higherIsBetter: nil, style: .line, decimals: 1, id: .bodyMass, stat: .average, scale: 1)
    static let bodyFat = HKMetric(title: "Körperfett", unit: "%", symbol: "drop.triangle.fill", tint: .brown,
        higherIsBetter: false, style: .line, decimals: 1, id: .bodyFatPercentage, stat: .average, scale: 100)
}

// MARK: - Hauptansicht

struct TrendsView: View {
    @Query(sort: \FoodEntry.date) private var foodEntries: [FoodEntry]
    @Query(sort: \IntakeEntry.date) private var intakes: [IntakeEntry]
    private let health = NutritionHealthStore()
    @State private var range: TrendRange = .d14

    var body: some View {
        ScrollView {
            VStack(spacing: 18) {
                Picker("Zeitraum", selection: $range) {
                    ForEach(TrendRange.allCases) { Text($0.rawValue).tag($0) }
                }
                .pickerStyle(.segmented)

                group("Erholung") {
                    HKTrendCard(metric: .restingHR, range: range, store: health)
                    HKTrendCard(metric: .hrv, range: range, store: health)
                    SleepTrendCard(range: range, store: health)
                }
                group("Aktivität") {
                    HKTrendCard(metric: .steps, range: range, store: health)
                    HKTrendCard(metric: .exercise, range: range, store: health)
                    HKTrendCard(metric: .activeEnergy, range: range, store: health)
                }
                group("Körper") {
                    HKTrendCard(metric: .weight, range: range, store: health)
                    HKTrendCard(metric: .bodyFat, range: range, store: health)
                }
                group("Ernährung") {
                    TrendCard(title: "Kalorien", unit: "kcal", symbol: "fork.knife", tint: Theme.accent,
                              higherIsBetter: nil, style: .bar, decimals: 0, series: kcalSeries, range: range)
                    TrendCard(title: "Eiweiß", unit: "g", symbol: "fish.fill", tint: .pink,
                              higherIsBetter: true, style: .bar, decimals: 0, series: proteinSeries, range: range)
                    TrendCard(title: "Koffein", unit: "mg", symbol: "cup.and.saucer.fill", tint: .brown,
                              higherIsBetter: nil, style: .bar, decimals: 0, series: caffeineSeries, range: range)
                }
            }
            .padding(16)
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("Trends")
        .navigationBarTitleDisplayMode(.inline)
    }

    @ViewBuilder
    private func group(_ title: String, @ViewBuilder _ content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title).font(.headline).padding(.leading, 4)
            content()
        }
    }

    // MARK: Eigene Logs → Tagesreihen (über 2× Zeitraum, für Delta-Vergleich)

    private var windowStart: Date {
        Calendar.current.date(byAdding: .day, value: -(2 * range.days - 1),
                              to: Calendar.current.startOfDay(for: .now)) ?? .now
    }
    private func localSeries(_ value: @escaping (FoodEntry) -> Double) -> [DayValue] {
        let cal = Calendar.current
        let grouped = Dictionary(grouping: foodEntries.filter { $0.date >= windowStart }) { cal.startOfDay(for: $0.date) }
        return grouped.map { DayValue(date: $0.key, value: $0.value.reduce(0) { $0 + value($1) }) }
            .sorted { $0.date < $1.date }
    }
    private var kcalSeries: [DayValue] { localSeries { $0.kcal ?? 0 } }
    private var proteinSeries: [DayValue] { localSeries { $0.proteinG ?? 0 } }
    private var caffeineSeries: [DayValue] {
        let cal = Calendar.current
        let doses = intakes.filter { $0.kind == .caffeine && $0.date >= windowStart }
        let grouped = Dictionary(grouping: doses) { cal.startOfDay(for: $0.date) }
        return grouped.map { DayValue(date: $0.key, value: $0.value.reduce(0) { $0 + $1.amount }) }
            .sorted { $0.date < $1.date }
    }
}

// MARK: - HealthKit-Karte (lädt asynchron, neu bei Zeitraumwechsel)

struct HKTrendCard: View {
    let metric: HKMetric
    let range: TrendRange
    let store: NutritionHealthStore
    @State private var series: [DayValue] = []

    var body: some View {
        TrendCard(title: metric.title, unit: metric.unit, symbol: metric.symbol, tint: metric.tint,
                  higherIsBetter: metric.higherIsBetter, style: metric.style, decimals: metric.decimals,
                  series: series, range: range)
            .task(id: range) {
                let raw = await store.dailySeries(metric.id, days: range.days * 2, stat: metric.stat)
                series = metric.scale == 1 ? raw : raw.map { DayValue(date: $0.date, value: $0.value * metric.scale) }
            }
    }
}

/// Schlaf nutzt die bestehende Nächte-Logik (Stunden je Nacht).
struct SleepTrendCard: View {
    let range: TrendRange
    let store: NutritionHealthStore
    @State private var series: [DayValue] = []

    var body: some View {
        TrendCard(title: "Schlaf", unit: "h", symbol: "bed.double.fill", tint: .blue,
                  higherIsBetter: true, style: .bar, decimals: 1, series: series, range: range)
            .task(id: range) {
                let nights = await store.sleepNightsDated(days: range.days * 2)
                series = nights.map { DayValue(date: $0.date, value: $0.hours) }
            }
    }
}

// MARK: - Präsentationskarte (rechnet Ø/Delta/Min/Max, zeichnet Chart)

struct TrendCard: View {
    let title: String
    let unit: String
    let symbol: String
    let tint: Color
    let higherIsBetter: Bool?
    let style: TrendChartStyle
    let decimals: Int
    let series: [DayValue]          // bis zu 2× Zeitraum (für Delta)
    let range: TrendRange

    private var split: (current: [DayValue], prev: [DayValue]) {
        let cal = Calendar.current
        let today = cal.startOfDay(for: .now)
        let curStart = cal.date(byAdding: .day, value: -(range.days - 1), to: today) ?? today
        let cur = series.filter { $0.date >= curStart }
        let prev = series.filter { $0.date < curStart }
        return (cur, prev)
    }
    private func avg(_ a: [DayValue]) -> Double? { a.isEmpty ? nil : a.map(\.value).reduce(0, +) / Double(a.count) }

    var body: some View {
        let cur = split.current
        let curAvg = avg(cur)
        let prevAvg = avg(split.prev)
        return VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: symbol).foregroundStyle(tint).font(.subheadline)
                Text(title).font(.subheadline.weight(.semibold))
                Spacer()
                deltaChip(curAvg, prevAvg)
            }
            if let a = curAvg {
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text(fmt(a)).font(.title2.weight(.bold)).monospacedDigit()
                    Text(unit).font(.caption).foregroundStyle(.secondary)
                    Text("· Ø \(range.rawValue)").font(.caption).foregroundStyle(.tertiary)
                }
                chart(cur, baseline: a)
                    .frame(height: 90)
                if let mn = cur.map(\.value).min(), let mx = cur.map(\.value).max() {
                    Text("Min \(fmt(mn)) · Max \(fmt(mx)) \(unit)")
                        .font(.caption2).foregroundStyle(.tertiary)
                }
            } else {
                Text("Keine Daten in diesem Zeitraum")
                    .font(.caption).foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading).padding(.vertical, 8)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16))
    }

    @ViewBuilder
    private func chart(_ data: [DayValue], baseline: Double) -> some View {
        Chart {
            ForEach(data) { p in
                if style == .bar {
                    BarMark(x: .value("Tag", p.date, unit: .day), y: .value(unit, p.value))
                        .foregroundStyle(tint.opacity(0.85))
                } else {
                    AreaMark(x: .value("Tag", p.date, unit: .day), y: .value(unit, p.value))
                        .foregroundStyle(tint.opacity(0.12)).interpolationMethod(.monotone)
                    LineMark(x: .value("Tag", p.date, unit: .day), y: .value(unit, p.value))
                        .foregroundStyle(tint).interpolationMethod(.monotone)
                    PointMark(x: .value("Tag", p.date, unit: .day), y: .value(unit, p.value))
                        .foregroundStyle(tint).symbolSize(18)
                }
            }
            RuleMark(y: .value("Ø", baseline))
                .foregroundStyle(.secondary.opacity(0.35))
                .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 4]))
        }
        .chartYScale(domain: .automatic(includesZero: style == .bar))
        .chartXAxis {
            AxisMarks(values: .stride(by: .day, count: max(1, range.days / 4))) { _ in
                AxisGridLine()
                AxisValueLabel(format: .dateTime.day().month(.abbreviated))
            }
        }
        .chartYAxis { AxisMarks(position: .leading) }
    }

    @ViewBuilder
    private func deltaChip(_ cur: Double?, _ prev: Double?) -> some View {
        if let c = cur, let p = prev, abs(c - p) > 0.05 {
            let delta = c - p
            let up = delta > 0
            let good: Bool? = higherIsBetter.map { up == $0 }
            let color: Color = good == nil ? .secondary : (good! ? .green : .red)
            HStack(spacing: 2) {
                Image(systemName: up ? "arrow.up.right" : "arrow.down.right").font(.caption2.weight(.bold))
                Text(fmt(abs(delta))).font(.caption.weight(.semibold)).monospacedDigit()
            }
            .foregroundStyle(color)
            .padding(.horizontal, 7).padding(.vertical, 3)
            .background(color.opacity(0.12), in: Capsule())
        }
    }

    private func fmt(_ v: Double) -> String {
        if decimals == 0 { return v >= 1000 ? v.formatted(.number.precision(.fractionLength(0))) : String(Int(v.rounded())) }
        return String(format: "%.\(decimals)f", v)
    }
}
