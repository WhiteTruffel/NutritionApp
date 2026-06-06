import SwiftUI

/// „Belastung" (BL6-Trennung): Sport, Training, Bewegung und Schritte – die Aktivseite.
/// Schlaf/Erholung liegen bewusst getrennt im Erholungs-Detail.
struct LoadDetailView: View {
    private let health = NutritionHealthStore()
    @State private var rings: ActivityRings?
    @State private var workouts: [WorkoutSummary] = []
    @State private var workoutsToday = 0
    @State private var steps: Double = 0
    @State private var loading = true

    var body: some View {
        List {
            if loading {
                HStack { ProgressView(); Text("Lade Belastungsdaten …").foregroundStyle(.secondary) }
            } else {
                Section {
                    HStack(spacing: 16) {
                        scorePill(title: "Bewegung heute",
                                  value: rings.map { "\(Int($0.moveKcal.rounded()))" } ?? "–",
                                  unit: "kcal", color: .orange)
                        scorePill(title: "Trainingsmin.",
                                  value: rings.map { "\(Int($0.exerciseMin.rounded()))" } ?? "–",
                                  unit: "min", color: .orange)
                    }
                    .padding(.vertical, 4)
                    if let rings {
                        detailRow("Bewegung", "\(Int(rings.moveKcal.rounded())) / \(Int(rings.moveGoal.rounded())) kcal")
                        detailRow("Trainingsminuten", "\(Int(rings.exerciseMin.rounded())) / \(Int(rings.exerciseGoal.rounded())) min")
                    }
                    if steps > 0 {
                        detailRow("Schritte heute", steps.formatted(.number.precision(.fractionLength(0))))
                    }
                    detailRow("Workouts heute", "\(workoutsToday)")
                } header: {
                    Text("Heute")
                }

                Section {
                    HKTrendCard(metric: .steps, range: .d7, store: health)
                        .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
                        .listRowBackground(Color.clear)
                    NavigationLink { TrendsView() } label: {
                        Label("Alle Trends ansehen", systemImage: "chart.xyaxis.line")
                    }
                } header: {
                    Text("Trend")
                }

                if !workouts.isEmpty {
                    Section("Letzte Trainings") {
                        ForEach(workouts.prefix(12)) { w in
                            HStack(spacing: 12) {
                                Image(systemName: w.symbol).font(.title3).frame(width: 28).foregroundStyle(.orange)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(w.name)
                                    Text(w.start.formatted(date: .abbreviated, time: .shortened))
                                        .font(.caption).foregroundStyle(.secondary)
                                }
                                Spacer()
                                if let k = w.kcal {
                                    Text("\(Int(k.rounded())) kcal").font(.subheadline).foregroundStyle(.secondary).monospacedDigit()
                                }
                            }
                        }
                    }
                } else {
                    Section { Text("Noch keine Trainings in Apple Health (letzte 14 Tage).")
                        .font(.caption).foregroundStyle(.secondary) }
                }
            }
        }
        .refreshable { await load() }
        .task { await load() }
    }

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

    private func detailRow(_ label: String, _ value: String) -> some View {
        HStack { Text(label); Spacer(); Text(value).foregroundStyle(.secondary).monospacedDigit() }
    }

    private func load() async {
        loading = true
        try? await health.requestAuthorization()
        async let a = health.todayActivity()
        async let w = health.fetchWorkouts(days: 14)
        async let st = health.todaySteps()
        let (act, wk, stepCount) = await (a, w, st)
        await MainActor.run {
            rings = act
            workouts = wk
            workoutsToday = wk.filter { Calendar.current.isDateInToday($0.start) }.count
            steps = stepCount
            loading = false
        }
    }
}
