import SwiftUI
import SwiftData

/// „Heute" im Whoop-Prinzip (BL6): Kopfzeile mit Status, drei Ringe (Ernährung, Belastung,
/// Erholung) mit Drill-down, plus MyFitnessPal-artige Schnellerfassung und Mini-Statistiken,
/// damit der Einstieg lebendig statt leer wirkt.
struct OverviewView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \FoodEntry.date, order: .reverse) private var entries: [FoodEntry]
    @Query private var profiles: [UserProfile]
    @Query private var weights: [WeightEntry]
    @Query private var intakes: [IntakeEntry]
    private let health = NutritionHealthStore()

    @State private var activity: ActivityRings?
    @State private var readiness: ReadinessResult?
    @State private var steps: Double = 0
    @State private var showGoals = false
    @State private var showAddFood = false
    @AppStorage("fastingStartEpoch") private var fastingStartEpoch: Double = 0

    private var profile: UserProfile? { profiles.first }
    private var todayEntries: [FoodEntry] { entries.filter { Calendar.current.isDateInToday($0.date) } }
    private var totals: MacroTotals { todayEntries.totals() }

    // Ernährung (adaptiv wie das Detail).
    private var adaptive: AdaptiveEnergyResult? {
        guard profile?.useAdaptiveTDEE == true else { return nil }
        let daily = Dictionary(grouping: entries) { Calendar.current.startOfDay(for: $0.date) }
            .map { (day: $0.key, kcal: $0.value.reduce(0.0) { $0 + ($1.kcal ?? 0) }) }
        let pts = weights.map { (date: $0.date, kg: $0.weightKg) }
        return AdaptiveEnergy.estimate(weights: pts, dailyKcal: daily)
    }
    private var goalKcal: Double {
        if let a = adaptive, let p = profile { return p.adaptiveKcalTarget(tdee: a.tdee) }
        return profile?.kcalTarget ?? NutritionTargets.default.kcal
    }
    private var remainingKcal: Int { Int((goalKcal - totals.kcal).rounded()) }
    private var nutritionProgress: Double { goalKcal > 0 ? totals.kcal / goalKcal : 0 }

    private var moveKcal: Double { activity?.moveKcal ?? 0 }
    private var loadProgress: Double { let g = activity?.moveGoal ?? 0; return g > 0 ? moveKcal / g : 0 }
    private var recoveryScore: Int? { readiness?.score }
    private var recoveryProgress: Double { Double(recoveryScore ?? 0) / 100 }

    private var todayWater: Double {
        intakes.filter { $0.kind == .water && Calendar.current.isDateInToday($0.date) }.reduce(0) { $0 + $1.amount }
    }
    private var waterGoal: Double { (((profile?.weightKg ?? 75) * 35) / 50).rounded() * 50 }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 14) {
                    header

                    NavigationLink { DashboardView() } label: {
                        RingCard(title: "today.nutrition".localized(), value: "\(remainingKcal)", unit: "today.kcal_left".localized(),
                                 progress: nutritionProgress, color: Theme.accent, symbol: "fork.knife")
                    }.buttonStyle(.plain)

                    NavigationLink { LoadDetailView().navigationTitle("today.load".localized()).navigationBarTitleDisplayMode(.inline) } label: {
                        RingCard(title: "today.load".localized(), value: "\(Int(moveKcal.rounded()))", unit: "today.kcal_today".localized(),
                                 progress: loadProgress, color: .orange, symbol: "flame.fill")
                    }.buttonStyle(.plain)

                    NavigationLink { RecoveryDetailView().navigationTitle("today.recovery".localized()).navigationBarTitleDisplayMode(.inline) } label: {
                        RingCard(title: "today.recovery".localized(), value: recoveryScore.map { "\($0)" } ?? "–", unit: "today.of_100".localized(),
                                 progress: recoveryProgress, color: .blue, symbol: "bed.double.fill")
                    }.buttonStyle(.plain)

                    quickActions
                    statsStrip
                    consistencyCard
                    trendsEntry
                }
                .padding(16)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("tab.today".localized())
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showGoals = true } label: { Image(systemName: "gearshape.fill") }
                }
            }
            .sheet(isPresented: $showGoals) { if let profile { GoalsView(profile: profile) } }
            .sheet(isPresented: $showAddFood) {
                AddFoodView(presetMeal: .snack) { addEntry($0) }
            }
            .task {
                activity = await health.todayActivity()
                readiness = await health.readiness()
                steps = await health.todaySteps()
            }
        }
    }

    // MARK: Kopf

    private var header: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(Date().formatted(.dateTime.weekday(.wide).day().month(.wide).locale(Locale(identifier: LocalizationManager.shared.currentLanguage.languageCode))))
                .font(.subheadline).foregroundStyle(.secondary)
            Text(statusLine).font(.title3.weight(.semibold))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
    private var statusLine: String {
        if let s = recoveryScore { return "\(recoveryWord(s)) · \(remainingKcal) \("today.kcal_left".localized())" }
        return "\(remainingKcal) \("today.kcal_left_today".localized())"
    }
    private func recoveryWord(_ s: Int) -> String {
        switch s { case 66...: return "today.recovery.good".localized(); case 40..<66: return "today.recovery.moderate".localized(); default: return "today.recovery.low".localized() }
    }

    // MARK: Schnellerfassung

    private var quickActions: some View {
        HStack(spacing: 10) {
            actionButton("plus.circle.fill", "today.eat".localized()) { showAddFood = true }
                .accessibilityIdentifier("overview.quick.essen")
            actionButton("drop.fill", "today.water".localized()) { addIntake(.water, 250) }
                .accessibilityIdentifier("overview.quick.wasser")
            actionButton("cup.and.saucer.fill", "today.coffee".localized()) { addIntake(.caffeine, 95); addIntake(.water, 200) }
                .accessibilityIdentifier("overview.quick.kaffee")
        }
    }
    private func actionButton(_ icon: String, _ label: String, _ action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 5) {
                Image(systemName: icon).font(.title3).foregroundStyle(Theme.accent)
                Text(label).font(.caption).foregroundStyle(.primary)
            }
            .frame(maxWidth: .infinity).padding(.vertical, 12)
            .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 14))
        }
        .buttonStyle(.plain)
    }

    // MARK: Konsistenz / Streak (BL21 – bewusst nicht-wertend, ermutigend)

    private var loggedDays: Set<Date> {
        Set(entries.map { Calendar.current.startOfDay(for: $0.date) })
    }
    /// Tage in Folge mit mindestens einem Eintrag. „Heute noch leer" bricht die Serie NICHT,
    /// solange gestern erfasst wurde – so fühlt sich der Tag nicht wie ein Versagen an.
    private var streak: Int {
        let cal = Calendar.current
        var day = cal.startOfDay(for: .now)
        if !loggedDays.contains(day) { day = cal.date(byAdding: .day, value: -1, to: day) ?? day }
        var count = 0
        while loggedDays.contains(day) {
            count += 1
            guard let prev = cal.date(byAdding: .day, value: -1, to: day) else { break }
            day = prev
        }
        return count
    }
    private var last7: [(date: Date, logged: Bool)] {
        let cal = Calendar.current
        return (0..<7).reversed().map { off in
            let d = cal.date(byAdding: .day, value: -off, to: cal.startOfDay(for: .now)) ?? .now
            return (d, loggedDays.contains(d))
        }
    }
    private var daysLogged7: Int { last7.filter(\.logged).count }

    private var consistencyCard: some View {
        HStack(spacing: 14) {
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Image(systemName: "flame.fill").foregroundStyle(.orange)
                    Text(streak > 0 ? "\(streak) \("today.streak".localized())" : "today.start_today".localized())
                        .font(.headline)
                }
                Text(streak > 0 ? "\(daysLogged7) \("today.streak_sub_logged".localized())"
                                : "today.streak_sub_start".localized())
                    .font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            HStack(spacing: 5) {
                ForEach(last7, id: \.date) { d in
                    Circle()
                        .fill(d.logged ? Theme.accent : Color(.systemGray5))
                        .frame(width: 9, height: 9)
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16))
    }

    // MARK: Trends-Einstieg

    private var trendsEntry: some View {
        NavigationLink { TrendsView() } label: {
            HStack(spacing: 14) {
                Image(systemName: "chart.xyaxis.line").font(.title3).foregroundStyle(Theme.accent)
                    .frame(width: 32)
                VStack(alignment: .leading, spacing: 2) {
                    Text("today.trends".localized()).font(.headline)
                    Text("today.trends_sub".localized())
                        .font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                Image(systemName: "chevron.right").font(.footnote).foregroundStyle(.tertiary)
            }
            .padding(16)
            .frame(maxWidth: .infinity)
            .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16))
        }
        .buttonStyle(.plain)
    }

    // MARK: Mini-Statistiken

    private var statsStrip: some View {
        HStack(spacing: 10) {
            miniTile("figure.walk", steps > 0 ? steps.formatted(.number.precision(.fractionLength(0))) : "–", "today.steps".localized(), .green)
            miniTile("drop.fill", "\(Int(todayWater)) ml", "today.water".localized(), .blue)
            miniTile("timer", fastingStatus, "today.fasting".localized(), .purple)
        }
    }
    private func miniTile(_ icon: String, _ value: String, _ label: String, _ color: Color) -> some View {
        VStack(spacing: 3) {
            Image(systemName: icon).foregroundStyle(color)
            Text(value).font(.subheadline.weight(.semibold)).monospacedDigit().lineLimit(1).minimumScaleFactor(0.7)
            Text(label).font(.caption2).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity).padding(.vertical, 12)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 14))
    }
    private var fastingStatus: String {
        guard fastingStartEpoch > 0 else { return "—" }
        let h = (Date().timeIntervalSince1970 - fastingStartEpoch) / 3600
        return "\(Int(h)) h"
    }

    // MARK: Aktionen

    private func addEntry(_ entry: FoodEntry) {
        context.insert(entry); try? context.save()
        let payload = entry.makePayload()
        Task { @MainActor in
            do { try await health.save(payload); entry.syncedToHealthKit = true; try? context.save() } catch {}
        }
    }
    private func addIntake(_ kind: IntakeKind, _ amount: Double) {
        let e = IntakeEntry(kind: kind, amount: amount)
        context.insert(e); try? context.save()
        Task { @MainActor in
            let uuid: UUID?
            switch kind {
            case .water:    uuid = await health.saveWater(ml: amount)
            case .caffeine: uuid = await health.saveCaffeine(mg: amount)
            }
            if e.isDeleted || e.modelContext == nil {
                if let uuid { await health.deleteIntakeSample(uuid: uuid, kind: kind) }
            } else {
                e.healthKitUUID = uuid
                try? context.save()
            }
        }
    }
}

/// Eine Ring-Karte der Übersicht: großer Fortschrittsring + Wert, als Drill-down-Einstieg.
private struct RingCard: View {
    let title: String
    let value: String
    let unit: String
    let progress: Double
    let color: Color
    let symbol: String

    private var clamped: Double { min(max(progress, 0), 1) }

    var body: some View {
        HStack(spacing: 16) {
            ZStack {
                Circle().stroke(Color(.systemGray5), lineWidth: 8)
                Circle().trim(from: 0, to: clamped)
                    .stroke(color, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .animation(.easeOut(duration: 0.4), value: clamped)
                Image(systemName: symbol).font(.system(size: 18)).foregroundStyle(color)
            }
            .frame(width: 64, height: 64)

            VStack(alignment: .leading, spacing: 3) {
                Text(title).font(.headline)
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text(value).font(.title2.weight(.bold)).monospacedDigit().foregroundStyle(color)
                    Text(unit).font(.caption).foregroundStyle(.secondary)
                }
            }
            Spacer()
            Image(systemName: "chevron.right").font(.footnote).foregroundStyle(.tertiary)
        }
        .padding(18)
        .frame(maxWidth: .infinity)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16))
    }
}
