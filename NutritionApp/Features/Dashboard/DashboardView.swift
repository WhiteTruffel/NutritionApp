import SwiftUI
import SwiftData

/// Home-Screen im MyFitnessPal-Stil (eigenes Design): „Verbleibend = Ziel − Nahrung"
/// als Ring, darunter der Makro-Fortschritt gegen die Tagesziele.
struct DashboardView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \FoodEntry.date, order: .reverse) private var entries: [FoodEntry]
    @Query private var profiles: [UserProfile]
    @Query private var intakes: [IntakeEntry]
    @Query private var weights: [WeightEntry]
    private let health = NutritionHealthStore()

    @State private var exerciseKcal: Double = 0
    @State private var showGoals = false
    @State private var activity: ActivityRings?
    @State private var readiness: ReadinessResult?

    private var profile: UserProfile? { profiles.first }
    private var todayEntries: [FoodEntry] {
        entries.filter { Calendar.current.isDateInToday($0.date) }
    }
    private var totals: MacroTotals { todayEntries.totals() }

    // MARK: Adaptiver Umsatz (Goldstandard) – lernt aus Gewichtstrend + Zufuhr.

    private var adaptive: AdaptiveEnergyResult? {
        guard profile?.useAdaptiveTDEE == true else { return nil }
        let daily = Dictionary(grouping: entries) { Calendar.current.startOfDay(for: $0.date) }
            .map { (day: $0.key, kcal: $0.value.reduce(0.0) { $0 + ($1.kcal ?? 0) }) }
        let pts = weights.map { (date: $0.date, kg: $0.weightKg) }
        return AdaptiveEnergy.estimate(weights: pts, dailyKcal: daily)
    }

    /// Effektives kcal-Ziel: adaptiv (falls aktiv & genug Daten), sonst Formel.
    private var goalKcal: Double {
        if let a = adaptive, let p = profile { return p.adaptiveKcalTarget(tdee: a.tdee) }
        return profile?.kcalTarget ?? NutritionTargets.default.kcal
    }

    private var targets: NutritionTargets {
        if adaptive != nil, let p = profile { return p.macroTargets(forKcal: goalKcal) }
        return profile?.targets ?? .default
    }

    /// Adaptiv eingeschaltet, aber noch zu wenig Daten?
    private var adaptiveLearning: Bool { profile?.useAdaptiveTDEE == true && adaptive == nil }

    /// Sport-Kalorien nur im klassischen Modus addieren – adaptiv ist Training schon „eingepreist".
    private var exercise: Double {
        guard adaptive == nil else { return 0 }
        return (profile?.useExerciseCalories ?? false) ? exerciseKcal : 0
    }

    private var todayIntakes: [IntakeEntry] { intakes.filter { Calendar.current.isDateInToday($0.date) } }
    private var todayWater: Double { todayIntakes.filter { $0.kind == .water }.reduce(0) { $0 + $1.amount } }
    private var todayCaffeine: Double { todayIntakes.filter { $0.kind == .caffeine }.reduce(0) { $0 + $1.amount } }

    var body: some View {
        ScrollView {
                VStack(spacing: 16) {
                    if let a = adaptive {
                        AdaptiveBanner(text: "Adaptiver Umsatz: ~\(Int(a.tdee)) kcal/Tag, aus deinen Daten gelernt (\(a.loggedDays) Tage). Sport ist bereits eingerechnet.")
                    } else if adaptiveLearning {
                        AdaptiveBanner(text: "Adaptiver Umsatz lernt noch – logge ~2 Wochen durchgehend Nahrung und trage regelmäßig dein Gewicht ein. Solange gilt das berechnete Ziel.")
                    }
                    HeroCard(consumed: totals.kcal, goal: goalKcal, exercise: exercise,
                             totals: totals, targets: targets)
                    IntakeCard(water: todayWater, caffeine: todayCaffeine) { kind, amount in
                        addIntake(kind, amount)
                    }
                    FastingCard()
                    NavigationLink {
                        WeeklyReviewView()
                    } label: {
                        HStack {
                            Label("Wochenrückblick & Insights", systemImage: "chart.bar.xaxis")
                                .font(.subheadline.weight(.medium))
                            Spacer()
                            Image(systemName: "chevron.right").font(.footnote).foregroundStyle(.tertiary)
                        }
                        .padding(18)
                        .frame(maxWidth: .infinity)
                        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16))
                    }
                    .buttonStyle(.plain)
                }
                .padding(16)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Ernährung")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showGoals = true } label: { Image(systemName: "gearshape.fill") }
                        .accessibilityIdentifier("openGoals")
                }
            }
            .sheet(isPresented: $showGoals) {
                if let profile { GoalsView(profile: profile) }
            }
            .task {
                exerciseKcal = await health.todayActiveEnergy()
                activity = await health.todayActivity()
                readiness = await health.readiness()
            }
    }

    private func addIntake(_ kind: IntakeKind, _ amount: Double) {
        context.insert(IntakeEntry(kind: kind, amount: amount))
        try? context.save()
        Task {
            switch kind {
            case .water:    await health.saveWater(ml: amount)
            case .caffeine: await health.saveCaffeine(mg: amount)
            }
        }
    }
}

// MARK: - Adaptiv-Hinweis

private struct AdaptiveBanner: View {
    let text: String
    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "wand.and.stars").foregroundStyle(.purple)
            Text(text).font(.caption).foregroundStyle(.secondary)
            Spacer(minLength: 0)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 12))
    }
}

// MARK: - Hero-Karte (Kalorien-Ring + Makro-Mini-Ringe)

private struct HeroCard: View {
    let consumed: Double
    let goal: Double
    var exercise: Double = 0
    let totals: MacroTotals
    let targets: NutritionTargets

    private var budget: Double { goal + exercise }
    private var remaining: Double { budget - consumed }
    private var progress: Double { budget > 0 ? consumed / budget : 0 }

    var body: some View {
        VStack(spacing: 22) {
            HStack(alignment: .center, spacing: 20) {
                CalorieRing(progress: progress) {
                    VStack(spacing: 0) {
                        Text("\(Int(remaining.rounded()))")
                            .font(.system(size: 34, weight: .bold, design: .rounded))
                            .foregroundStyle(remaining < 0 ? .red : .primary)
                            .contentTransition(.numericText())
                        Text("kcal übrig").font(.caption2).foregroundStyle(.secondary)
                    }
                }
                .frame(width: 140, height: 140)

                VStack(alignment: .leading, spacing: 14) {
                    miniStat("Ziel", Int(goal), .secondary)
                    miniStat("Nahrung", Int(consumed.rounded()), Theme.accent)
                    if exercise > 0 { miniStat("Sport", Int(exercise.rounded()), .orange, plus: true) }
                }
            }

            Divider()

            HStack(spacing: 12) {
                MacroRing(title: "Kohlenh.", consumed: totals.carbsG, target: targets.carbsG, color: .orange)
                MacroRing(title: "Eiweiß", consumed: totals.proteinG, target: targets.proteinG, color: Theme.accent)
                MacroRing(title: "Fett", consumed: totals.fatG, target: targets.fatG, color: .yellow)
            }
        }
        .padding(Theme.cardPadding)
        .frame(maxWidth: .infinity)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: Theme.radius))
    }

    private func miniStat(_ label: String, _ value: Int, _ color: Color, plus: Bool = false) -> some View {
        HStack {
            Text(label).font(.subheadline).foregroundStyle(.secondary)
            Spacer()
            Text("\(plus ? "+" : "")\(value) kcal").font(.subheadline.weight(.semibold)).foregroundStyle(color)
        }
    }
}

private struct MacroRing: View {
    let title: String
    let consumed: Double
    let target: Double
    let color: Color

    private var progress: Double { target > 0 ? min(consumed / target, 1) : 0 }

    var body: some View {
        VStack(spacing: 6) {
            ZStack {
                Circle().stroke(Color(.systemGray5), lineWidth: 6)
                Circle().trim(from: 0, to: progress)
                    .stroke(color, style: StrokeStyle(lineWidth: 6, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .animation(.easeOut(duration: 0.4), value: progress)
                Text("\(Int(consumed.rounded()))").font(.caption.weight(.semibold)).monospacedDigit()
            }
            .frame(width: 56, height: 56)
            Text(title).font(.caption2).foregroundStyle(.secondary)
            Text("/ \(Int(target)) g").font(.caption2).foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Kalorien-Karte

private struct CalorieSummaryCard: View {
    let consumed: Double
    let goal: Double
    var exercise: Double = 0

    private var budget: Double { goal + exercise }
    private var remaining: Double { budget - consumed }
    private var progress: Double { budget > 0 ? consumed / budget : 0 }

    var body: some View {
        VStack(spacing: 20) {
            HStack(alignment: .center, spacing: 24) {
                CalorieRing(progress: progress) {
                    VStack(spacing: 2) {
                        Text("\(Int(remaining.rounded()))")
                            .font(.system(size: 30, weight: .bold, design: .rounded))
                            .foregroundStyle(remaining < 0 ? .red : .primary)
                            .contentTransition(.numericText())
                        Text("übrig")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .frame(width: 130, height: 130)

                VStack(alignment: .leading, spacing: 12) {
                    StatRow(label: "Ziel", value: "\(Int(goal)) kcal", color: .secondary)
                    StatRow(label: "Nahrung", value: "\(Int(consumed.rounded())) kcal", color: Theme.accent)
                    if exercise > 0 {
                        StatRow(label: "Sport", value: "+\(Int(exercise.rounded())) kcal", color: .orange)
                    }
                    Divider()
                    StatRow(label: "Verbleibend",
                            value: "\(Int(remaining.rounded())) kcal",
                            color: remaining < 0 ? .red : .primary,
                            emphasized: true)
                }
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16))
    }
}

private struct StatRow: View {
    let label: String
    let value: String
    var color: Color = .primary
    var emphasized: Bool = false

    var body: some View {
        HStack {
            Text(label)
                .font(emphasized ? .subheadline.bold() : .subheadline)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .font(emphasized ? .headline : .subheadline.weight(.medium))
                .foregroundStyle(color)
        }
    }
}

/// Kreis-Fortschritt für die Kalorien. Über 100 % wird der Ring rot.
private struct CalorieRing<Center: View>: View {
    let progress: Double
    @ViewBuilder var center: () -> Center

    private var clamped: Double { min(max(progress, 0), 1) }
    private var ringColor: Color { progress > 1 ? .red : Theme.accent }

    var body: some View {
        ZStack {
            Circle()
                .stroke(Color(.systemGray5), lineWidth: 14)
            Circle()
                .trim(from: 0, to: clamped)
                .stroke(ringColor, style: StrokeStyle(lineWidth: 14, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .animation(.easeOut(duration: 0.4), value: clamped)
            center()
        }
    }
}

// MARK: - Makro-Karte

private struct MacroSummaryCard: View {
    let totals: MacroTotals
    let targets: NutritionTargets

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Makronährstoffe")
                .font(.headline)
            MacroBar(title: "Kohlenhydrate", consumed: totals.carbsG, target: targets.carbsG, color: .orange)
            MacroBar(title: "Eiweiß",        consumed: totals.proteinG, target: targets.proteinG, color: .blue)
            MacroBar(title: "Fett",          consumed: totals.fatG, target: targets.fatG, color: .yellow)
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16))
    }
}

private struct MacroBar: View {
    let title: String
    let consumed: Double
    let target: Double
    let color: Color

    private var progress: Double { target > 0 ? min(consumed / target, 1) : 0 }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(title).font(.subheadline)
                Spacer()
                Text("\(Int(consumed.rounded())) / \(Int(target)) g")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color(.systemGray5))
                    Capsule().fill(color)
                        .frame(width: geo.size.width * progress)
                        .animation(.easeOut(duration: 0.4), value: progress)
                }
            }
            .frame(height: 8)
        }
    }
}

// MARK: - Wasser & Koffein

private struct IntakeCard: View {
    let water: Double
    let caffeine: Double
    let onAdd: (IntakeKind, Double) -> Void

    private let waterGoal: Double = 2000

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Wasser & Koffein").font(.headline)

            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Label("Wasser", systemImage: "drop.fill").foregroundStyle(.blue)
                    Spacer()
                    Text("\(Int(water)) / \(Int(waterGoal)) ml")
                        .font(.subheadline).foregroundStyle(.secondary).monospacedDigit()
                }
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule().fill(Color(.systemGray5))
                        Capsule().fill(.blue)
                            .frame(width: geo.size.width * min(water / waterGoal, 1))
                    }
                }
                .frame(height: 8)
                HStack(spacing: 10) {
                    Button("+250 ml") { onAdd(.water, 250) }
                        .accessibilityIdentifier("dashboard.addWasser250")
                    Button("+500 ml") { onAdd(.water, 500) }
                        .accessibilityIdentifier("dashboard.addWasser500")
                }
                .buttonStyle(.bordered)
                .font(.footnote)
            }

            Divider()

            HStack {
                Label("Koffein", systemImage: "cup.and.saucer.fill").foregroundStyle(.brown)
                Spacer()
                Text("\(Int(caffeine)) mg")
                    .font(.subheadline).foregroundStyle(.secondary).monospacedDigit()
                Button("+ Kaffee") { onAdd(.caffeine, 95) }
                    .buttonStyle(.bordered)
                    .font(.footnote)
                    .accessibilityIdentifier("dashboard.addKaffee")
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16))
    }
}
