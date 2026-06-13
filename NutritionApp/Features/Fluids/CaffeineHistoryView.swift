import SwiftUI
import SwiftData
import Charts

/// Historische „Koffein im Körper"-Ansicht (BL34, Tester-Wunsch): nicht nur die Aufnahme,
/// sondern der wirksame Koffeinspiegel je Tag (Tagesspitze + Tagesmittel) über 14 Tage,
/// berechnet aus den erfassten Dosen über die CaffeineKinetics-Abbaulogik.
struct CaffeineHistoryView: View {
    @Query(sort: \IntakeEntry.date) private var intakes: [IntakeEntry]
    @Query private var profiles: [UserProfile]

    private var weightKg: Double { profiles.first?.weightKg ?? 75 }
    private var threshold: Double { CaffeineGuide(weightKg: weightKg).sleepThresholdMg }

    private struct DayPoint: Identifiable {
        let id = UUID(); let day: Date; let peak: Double; let avg: Double
    }

    private var points: [DayPoint] {
        let cal = Calendar.current
        let doses = intakes.filter { $0.kind == .caffeine }.map { (date: $0.date, mg: $0.amount) }
        guard !doses.isEmpty else { return [] }
        var out: [DayPoint] = []
        for off in stride(from: 13, through: 0, by: -1) {
            guard let day = cal.date(byAdding: .day, value: -off, to: cal.startOfDay(for: .now)) else { continue }
            var peak = 0.0, sum = 0.0, n = 0
            var h = 6.0
            while h <= 23.5 {
                let t = day.addingTimeInterval(h * 3600)
                let a = CaffeineKinetics.active(at: t, doses: doses)
                peak = max(peak, a); sum += a; n += 1
                h += 0.5
            }
            out.append(DayPoint(day: day, peak: peak, avg: n > 0 ? sum / Double(n) : 0))
        }
        return out
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                if points.allSatisfy({ $0.peak == 0 }) {
                    ContentUnavailableView("Noch keine Koffein-Historie", systemImage: "cup.and.saucer",
                        description: Text("caff.empty".localized()))
                        .padding(.top, 40)
                } else {
                    chartCard
                    Text("caff.note".localized())
                        .font(.caption).foregroundStyle(.secondary)
                }
            }
            .padding(16)
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("caff.title".localized())
        .navigationBarTitleDisplayMode(.inline)
    }

    private var chartCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("caff.active_14".localized()).font(.headline)
            Chart {
                ForEach(points) { p in
                    BarMark(x: .value("common.day".localized(), p.day, unit: .day), y: .value("caff.peak".localized(), p.peak))
                        .foregroundStyle(.brown.opacity(0.8))
                }
                ForEach(points) { p in
                    LineMark(x: .value("common.day".localized(), p.day, unit: .day), y: .value("caff.avg".localized(), p.avg))
                        .foregroundStyle(.orange)
                        .interpolationMethod(.monotone)
                }
                RuleMark(y: .value("recovery.sleep".localized(), threshold))
                    .foregroundStyle(Theme.accent.opacity(0.7))
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [5, 4]))
            }
            .frame(height: 240)
            .chartXAxis {
                AxisMarks(values: .stride(by: .day, count: 2)) { _ in
                    AxisGridLine(); AxisValueLabel(format: .dateTime.day().month(.abbreviated))
                }
            }
        }
        .padding(20).frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16))
    }
}
