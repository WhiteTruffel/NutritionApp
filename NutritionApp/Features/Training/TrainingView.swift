import SwiftUI

/// Zeigt die Trainings/Workouts der letzten 14 Tage aus Apple Health – rein lesend.
/// Die aktiven Kalorien fließen separat (über das Dashboard-Budget) ein; hier geht es
/// nur um Transparenz: Was wurde wann trainiert.
struct TrainingView: View {
    private let health = NutritionHealthStore()
    @State private var workouts: [WorkoutSummary] = []
    @State private var loading = true

    var body: some View {
        NavigationStack {
            List {
                if loading {
                    HStack { ProgressView(); Text("Lade Trainings …").foregroundStyle(.secondary) }
                } else if workouts.isEmpty {
                    ContentUnavailableView(
                        "Keine Trainings",
                        systemImage: "figure.run",
                        description: Text("In den letzten 14 Tagen wurden keine Workouts in Apple Health gefunden."))
                } else {
                    if let summary = weekSummary {
                        Section {
                            HStack {
                                Label("\(workouts.count) Einheiten", systemImage: "calendar")
                                Spacer()
                                Text("\(summary) kcal").bold().foregroundStyle(.orange)
                            }
                        } footer: {
                            Text("Summe der letzten 14 Tage.")
                        }
                    }
                    ForEach(groupedDays, id: \.0) { day, items in
                        Section(dayLabel(day)) {
                            ForEach(items) { row($0) }
                        }
                    }
                }
            }
            .navigationTitle("Training")
            .refreshable { await load() }
            .task { await load() }
        }
    }

    // MARK: Daten

    private var groupedDays: [(Date, [WorkoutSummary])] {
        let cal = Calendar.current
        return Dictionary(grouping: workouts) { cal.startOfDay(for: $0.start) }
            .sorted { $0.key > $1.key }
            .map { ($0.key, $0.value.sorted { $0.start > $1.start }) }
    }

    private var weekSummary: Int? {
        let total = workouts.compactMap(\.kcal).reduce(0, +)
        return total > 0 ? Int(total.rounded()) : nil
    }

    private func load() async {
        loading = true
        try? await health.requestAuthorization()
        let w = await health.fetchWorkouts()
        await MainActor.run {
            workouts = w
            loading = false
        }
    }

    // MARK: Zeile

    private func row(_ w: WorkoutSummary) -> some View {
        HStack(spacing: 12) {
            Image(systemName: w.symbol)
                .font(.title3).frame(width: 30)
                .foregroundStyle(.orange)
            VStack(alignment: .leading, spacing: 2) {
                Text(w.name)
                Text("\(w.start.formatted(date: .omitted, time: .shortened)) · \(durationText(w.durationMin))")
                    .font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                if let k = w.kcal {
                    Text("\(Int(k.rounded())) kcal").font(.subheadline).monospacedDigit()
                }
                if let m = w.distanceMeters, m > 0 {
                    Text(distanceText(m)).font(.caption).foregroundStyle(.secondary)
                }
            }
        }
    }

    // MARK: Format

    private func durationText(_ minutes: Double) -> String {
        let m = Int(minutes.rounded())
        if m >= 60 { return "\(m / 60) h \(m % 60) min" }
        return "\(m) min"
    }

    private func distanceText(_ meters: Double) -> String {
        meters >= 1000 ? String(format: "%.2f km", meters / 1000) : "\(Int(meters.rounded())) m"
    }

    private func dayLabel(_ day: Date) -> String {
        let cal = Calendar.current
        if cal.isDateInToday(day) { return "Heute" }
        if cal.isDateInYesterday(day) { return "Gestern" }
        return day.formatted(.dateTime.weekday(.wide).day().month())
    }
}
