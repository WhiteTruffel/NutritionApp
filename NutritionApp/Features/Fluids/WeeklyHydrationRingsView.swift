import SwiftUI

struct WeeklyHydrationRingsView: View {
    let dailyGoal: Double = 2600 // ml
    @State private var weekOffset = 0
    @State private var hydrationHistory: [Date: Double] = [:] // Date: total ml

    var currentWeekStart: Date {
        Calendar.current.date(byAdding: .weekOfYear, value: weekOffset, to: Date.now.startOfDay) ?? Date.now
    }

    var weekDays: [Date] {
        (0..<7).compactMap { day in
            Calendar.current.date(byAdding: .day, value: day, to: currentWeekStart)
        }
    }

    var body: some View {
        VStack(spacing: 16) {
            // Week navigation
            HStack {
                Button(action: { weekOffset -= 1 }) {
                    Image(systemName: "chevron.left").font(.headline)
                }

                Spacer()
                Text("trinken.weekly_rings".localized())
                    .font(.subheadline.weight(.semibold))
                Spacer()

                Button(action: { weekOffset += 1 }) {
                    Image(systemName: "chevron.right").font(.headline)
                }
            }
            .padding(.horizontal)

            // Weekly rings
            HStack(alignment: .bottom, spacing: 8) {
                ForEach(weekDays, id: \.self) { date in
                    VStack(spacing: 8) {
                        HydrationRing(
                            progress: (hydrationHistory[date] ?? 0) / dailyGoal,
                            color: colorForCompletion((hydrationHistory[date] ?? 0) / dailyGoal)
                        )
                        .frame(height: 60)

                        Text(dayAbbreviation(for: date))
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(Color(.systemGray6), in: RoundedRectangle(cornerRadius: 12))

            // Stats
            HStack(spacing: 20) {
                StatBox(label: "Mon", value: dayValue(for: weekDays.first ?? Date.now))
                StatBox(label: "Sun", value: dayValue(for: weekDays.last ?? Date.now))
                StatBox(label: "Avg", value: String(format: "%.0f ml", weekAverage()))
            }
            .padding(.horizontal)
        }
        .onAppear {
            seedTestData()
        }
    }

    private func dayAbbreviation(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE"
        return formatter.string(from: date).prefix(3).uppercased()
    }

    private func dayValue(for date: Date) -> String {
        let ml = hydrationHistory[date] ?? 0
        return String(format: "%.0f ml", ml)
    }

    private func weekAverage() -> Double {
        let values = hydrationHistory.values
        return values.isEmpty ? 0 : values.reduce(0, +) / Double(values.count)
    }

    private func colorForCompletion(_ ratio: Double) -> Color {
        if ratio >= 0.9 { return .green }
        if ratio >= 0.7 { return .orange }
        return .red
    }

    private func seedTestData() {
        // Seed 12 weeks of test data
        for weekOffset in -11...0 {
            if let weekStart = Calendar.current.date(byAdding: .weekOfYear, value: weekOffset, to: Date.now.startOfDay) {
                for day in 0..<7 {
                    if let date = Calendar.current.date(byAdding: .day, value: day, to: weekStart) {
                        let randomIntake = Double.random(in: 1500...2700)
                        hydrationHistory[date] = randomIntake
                    }
                }
            }
        }
    }
}

struct HydrationRing: View {
    let progress: Double
    let color: Color

    var body: some View {
        ZStack {
            Circle()
                .stroke(Color(.systemGray4), lineWidth: 8)

            Circle()
                .trim(from: 0, to: min(progress, 1))
                .stroke(color, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .animation(.easeInOut, value: progress)

            VStack(spacing: 2) {
                Text(String(format: "%.0f%%", progress * 100))
                    .font(.caption.weight(.semibold))
                Text("of goal")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

struct StatBox: View {
    let label: String
    let value: String

    var body: some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.headline.weight(.semibold))
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(Color(.systemGray6), in: RoundedRectangle(cornerRadius: 8))
    }
}

#Preview {
    WeeklyHydrationRingsView()
        .padding()
}
