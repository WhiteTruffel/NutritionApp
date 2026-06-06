import SwiftUI

/// „Erholung" (BL6-Trennung): Schlaf, Erholungs-Score (HRV/Ruhepuls) und Regeneration
/// (Achtsamkeit/Meditation/Sauna). Belastung/Sport liegen getrennt im Belastungs-Detail.
/// Alle Werte aus Apple Health, rein informativ – kein medizinischer Messwert.
struct RecoveryDetailView: View {
    private let health = NutritionHealthStore()
    @State private var sleep: SleepSummary?
    @State private var sleep7: [Double] = []
    @State private var readiness: ReadinessResult?
    @State private var mindfulMin: Double = 0
    @State private var loading = true

    var body: some View {
        List {
            if loading {
                HStack { ProgressView(); Text("Lade Erholungsdaten …").foregroundStyle(.secondary) }
            } else {
                recommendationSection
                recoverySection
                trendSection
                sleepSection
                regenerationSection
                Section {
                    Text("Alle Werte stammen aus Apple Health und dienen nur der Orientierung – keine medizinische Bewertung.")
                        .font(.caption2).foregroundStyle(.secondary)
                }
            }
        }
        .refreshable { await load() }
        .task { await load() }
    }

    // MARK: Empfehlung

    private var recommendation: (text: String, color: Color, symbol: String) {
        guard let s = readiness?.score else {
            return ("Noch zu wenig Daten für eine Empfehlung – trage Schlaf & Herzdaten in Apple Health bei.", .secondary, "questionmark.circle")
        }
        switch s {
        case 66...:    return ("Gut erholt – eine höhere Belastung ist heute in Ordnung.", .green, "checkmark.seal.fill")
        case 40..<66:  return ("Mäßig erholt – moderate Belastung empfehlenswert.", .orange, "exclamationmark.triangle.fill")
        default:       return ("Wenig erholt – heute eher regenerieren.", .red, "bed.double.fill")
        }
    }

    private var recommendationSection: some View {
        Section {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: recommendation.symbol).foregroundStyle(recommendation.color).font(.title3)
                Text(recommendation.text).font(.subheadline)
            }
            .padding(.vertical, 2)
        }
    }

    // MARK: Erholungs-Score

    private var recoverySection: some View {
        Section("Erholung") {
            scorePill(title: "Erholungs-Score",
                      value: readiness.map { "\($0.score)" } ?? "–",
                      unit: readiness != nil ? "/100" : "",
                      color: scoreColor(readiness?.score))
                .padding(.vertical, 4)
            if let r = readiness {
                if let hrv = r.hrv { detailRow("Herzraten­variabilität", String(format: "%.0f ms", hrv)) }
                if let rhr = r.rhr { detailRow("Ruhepuls", String(format: "%.0f bpm", rhr)) }
            }
        }
    }

    // MARK: Trend (Ruhepuls über 7 Tage + Einstieg in alle Trends)

    private var trendSection: some View {
        Section {
            HKTrendCard(metric: .restingHR, range: .d7, store: health)
                .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
                .listRowBackground(Color.clear)
            NavigationLink { TrendsView() } label: {
                Label("Alle Trends ansehen", systemImage: "chart.xyaxis.line")
            }
        } header: {
            Text("Trend")
        }
    }

    // MARK: Schlaf

    @ViewBuilder
    private var sleepSection: some View {
        if let s = sleep {
            Section("Schlaf – letzte Nacht") {
                HStack {
                    Text("Gesamt").font(.headline)
                    Spacer()
                    Text(hm(s.totalHours)).font(.headline).foregroundStyle(.indigo)
                }
                if let start = s.start, let end = s.end {
                    detailRow("Im Bett", "\(start.formatted(date: .omitted, time: .shortened)) – \(end.formatted(date: .omitted, time: .shortened))")
                }
                stageBar(s)
                stageRow("Tiefschlaf", s.deepHours, .indigo)
                stageRow("REM", s.remHours, .purple)
                stageRow("Kernschlaf", s.coreHours, .blue)
                stageRow("Wach", s.awakeHours, .gray)
                if !sleep7.isEmpty {
                    let avg = sleep7.reduce(0, +) / Double(sleep7.count)
                    detailRow("7-Tage-Schnitt", hm(avg))
                }
            }
        } else {
            Section("Schlaf") {
                Text("Keine Schlafdaten in Apple Health gefunden (letzte 36 h).")
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
    }

    // MARK: Regeneration (Achtsamkeit/Meditation/Sauna)

    private var regenerationSection: some View {
        Section("Regeneration") {
            detailRow("Achtsamkeit / Meditation", mindfulMin > 0 ? "\(Int(mindfulMin.rounded())) min" : "–")
            Text("Atemübungen, Meditation oder Sauna, die als Achtsamkeit in Apple Health landen, zählen hier mit.")
                .font(.caption2).foregroundStyle(.secondary)
        }
    }

    // MARK: Bausteine

    private func scorePill(title: String, value: String, unit: String, color: Color) -> some View {
        VStack(spacing: 4) {
            Text(title).font(.caption).foregroundStyle(.secondary)
            HStack(alignment: .firstTextBaseline, spacing: 2) {
                Text(value).font(.system(size: 28, weight: .bold, design: .rounded)).foregroundStyle(color)
                Text(unit).font(.caption).foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity).padding(.vertical, 8)
        .background(Color(.tertiarySystemFill), in: RoundedRectangle(cornerRadius: 12))
    }

    private func stageBar(_ s: SleepSummary) -> some View {
        let total = max(s.deepHours + s.remHours + s.coreHours + s.awakeHours, 0.001)
        return GeometryReader { geo in
            HStack(spacing: 0) {
                Rectangle().fill(Color.indigo).frame(width: geo.size.width * s.deepHours / total)
                Rectangle().fill(Color.purple).frame(width: geo.size.width * s.remHours / total)
                Rectangle().fill(Color.blue).frame(width: geo.size.width * s.coreHours / total)
                Rectangle().fill(Color.gray).frame(width: geo.size.width * s.awakeHours / total)
            }
        }
        .frame(height: 10).clipShape(Capsule())
        .listRowSeparator(.hidden)
    }

    private func stageRow(_ label: String, _ hours: Double, _ color: Color) -> some View {
        HStack {
            Circle().fill(color).frame(width: 8, height: 8)
            Text(label).font(.subheadline)
            Spacer()
            Text(hm(hours)).font(.subheadline).foregroundStyle(.secondary).monospacedDigit()
        }
    }

    private func detailRow(_ label: String, _ value: String) -> some View {
        HStack { Text(label); Spacer(); Text(value).foregroundStyle(.secondary).monospacedDigit() }
    }

    private func hm(_ hours: Double) -> String {
        let m = Int((hours * 60).rounded())
        return "\(m / 60) h \(m % 60) min"
    }

    private func scoreColor(_ score: Int?) -> Color {
        switch score ?? -1 { case 66...: return .green; case 40..<66: return .orange; case 0..<40: return .red; default: return .secondary }
    }

    private func load() async {
        loading = true
        try? await health.requestAuthorization()
        async let s = health.lastNightSleep()
        async let s7 = health.sleepHoursHistory(days: 7)
        async let r = health.readiness()
        async let m = health.todayMindfulMinutes()
        let (sleepVal, hist, ready, mind) = await (s, s7, r, m)
        await MainActor.run {
            sleep = sleepVal
            sleep7 = hist
            readiness = ready
            mindfulMin = mind
            loading = false
        }
    }
}
