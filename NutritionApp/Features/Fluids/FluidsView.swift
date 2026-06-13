import SwiftUI
import SwiftData
import Charts
import Combine

/// „Trinken"-Reiter (BL4): Flüssigkeitshaushalt nach Hydrate-Prinzip (Ziel nach Körpergewicht)
/// und Koffein nach HiCoffee-Prinzip (wirksame Menge + Abbaukurve nach Halbwertszeit).
struct FluidsView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \IntakeEntry.date) private var intakes: [IntakeEntry]
    @Query private var profiles: [UserProfile]
    private let health = NutritionHealthStore()

    /// Tickt jede Minute, damit „aktuell wirksam" live abklingt.
    @State private var now = Date()
    @State private var showCustomWater = false
    @State private var customWaterText = ""
    // BL33: „Rückgängig"-Snackbar nach dem Hinzufügen.
    @State private var lastAdded: [IntakeEntry] = []
    @State private var undoLabel = ""
    @State private var showUndo = false
    @State private var undoToken = 0

    private var weightKg: Double { profiles.first?.weightKg ?? 75 }
    private var guide: CaffeineGuide { CaffeineGuide(weightKg: weightKg) }

    // Hydration: 35 ml/kg, auf 50 ml gerundet.
    private var waterGoal: Double { ((weightKg * 35) / 50).rounded() * 50 }
    private var todayWater: Double {
        intakes.filter { $0.kind == .water && Calendar.current.isDateInToday($0.date) }
            .reduce(0) { $0 + $1.amount }
    }

    // Koffein-Dosen der letzten 24 h (für Kinetik) und heutiges Tagestotal (für Limit).
    private var caffeineDoses: [(date: Date, mg: Double)] {
        let cutoff = now.addingTimeInterval(-24 * 3600)
        return intakes.filter { $0.kind == .caffeine && $0.date >= cutoff }
            .map { (date: $0.date, mg: $0.amount) }
    }
    private var todayCaffeine: Double {
        intakes.filter { $0.kind == .caffeine && Calendar.current.isDateInToday($0.date) }
            .reduce(0) { $0 + $1.amount }
    }
    private var activeCaffeine: Double {
        CaffeineKinetics.active(at: now, doses: caffeineDoses)
    }
    private var sleepSafeTime: Date? {
        CaffeineKinetics.timeBelow(guide.sleepThresholdMg, doses: caffeineDoses, from: now)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    hydrationCard
                    WeeklyHydrationRingsView()
                    caffeineStatusCard
                    if !caffeineDoses.isEmpty { caffeineChartCard }
                    drinkGridCard
                    if !todayIntakes.isEmpty { historyCard }
                }
                .padding(16)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("tab.drink".localized())
            .accessibilityIdentifier("screen.fluids")
            .overlay(alignment: .bottom) { if showUndo { undoBar } }
        }
        .onAppear { now = Date() }
        .onReceive(Timer.publish(every: 60, on: .main, in: .common).autoconnect()) { now = $0 }
        .alert("fluids.add_water".localized(), isPresented: $showCustomWater) {
            TextField("fluids.amount_ml".localized(), text: $customWaterText).keyboardType(.numberPad)
                .accessibilityIdentifier("fluids.water.customField")
            Button("common.add".localized()) {
                if let ml = Double(customWaterText), ml > 0 { addWater(ml) }
                customWaterText = ""
            }
            Button("common.cancel".localized(), role: .cancel) { customWaterText = "" }
        }
    }

    // MARK: Hydration

    private var hydrationCard: some View {
        let progress = waterGoal > 0 ? min(todayWater / waterGoal, 1) : 0
        let remaining = max(0, waterGoal - todayWater)
        let cal = Calendar.current
        let hourNow = Double(cal.component(.hour, from: now)) + Double(cal.component(.minute, from: now)) / 60
        let dayFrac = min(max((hourNow - 7) / (23 - 7), 0), 1)   // Wachfenster 7–23 Uhr
        let behind = waterGoal * dayFrac - todayWater             // >0 = im Rückstand
        return VStack(alignment: .leading, spacing: 16) {
            HStack {
                Label("fluids.title".localized(), systemImage: "drop.fill").font(.headline).foregroundStyle(.blue)
                Spacer()
                Text("\(Int(todayWater)) / \(Int(waterGoal)) ml")
                    .font(.subheadline.weight(.semibold)).monospacedDigit().foregroundStyle(.secondary)
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color(.systemGray5))
                    Capsule().fill(.blue).frame(width: geo.size.width * progress)
                        .animation(.easeOut(duration: 0.4), value: progress)
                    // „Soll bis jetzt"-Marke (lineares Tagesziel über den Tag verteilt).
                    Rectangle().fill(Color.primary.opacity(0.5))
                        .frame(width: 2, height: 18)
                        .offset(x: geo.size.width * dayFrac - 1)
                }
            }
            .frame(height: 12)
            Text(pacingText(behind: behind))
                .font(.caption.weight(.medium))
                .foregroundStyle(behind > 200 ? .orange : (behind < -200 ? .green : .secondary))
            Text(remaining > 0
                 ? "Noch \(Int(remaining)) ml bis zum Ziel (\(Int(weightKg * 35)) ml ≈ 35 ml/kg)."
                 : "fluids.goal_reached".localized())
                .font(.caption2).foregroundStyle(.tertiary)
            HStack(spacing: 8) {
                quickButton("fluids.glass".localized(), "200 ml") { addWater(200) }
                    .accessibilityIdentifier("fluids.water.add200")
                quickButton("+250", "ml") { addWater(250) }
                    .accessibilityIdentifier("fluids.water.add250")
                quickButton("+500", "ml") { addWater(500) }
                    .accessibilityIdentifier("fluids.water.add500")
                quickButton("…", "fluids.custom".localized()) { showCustomWater = true }
                    .accessibilityIdentifier("fluids.water.addCustom")
            }
        }
        .cardBackground()
    }

    // MARK: Koffein-Status

    private var caffeineStatusCard: some View {
        let overSingle = todayCaffeine > 0 && caffeineDoses.contains { $0.mg > guide.singleLimitMg }
        let overDaily = todayCaffeine > guide.dailyLimitMg
        return VStack(alignment: .leading, spacing: 14) {
            HStack {
                Label("Koffein", systemImage: "cup.and.saucer.fill").font(.headline).foregroundStyle(.brown)
                Spacer()
                Text("fluids.half_life".localized()).font(.caption2).foregroundStyle(.tertiary)
            }
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text("\(Int(activeCaffeine.rounded()))")
                    .font(.system(size: 40, weight: .bold, design: .rounded))
                    .contentTransition(.numericText()).monospacedDigit()
                    .accessibilityIdentifier("fluids.caffeine.activeValue")
                Text("fluids.mg_active".localized()).font(.subheadline).foregroundStyle(.secondary)
            }
            HStack(spacing: 8) {
                Image(systemName: sleepIcon).foregroundStyle(sleepColor)
                Text(sleepText).font(.subheadline).foregroundStyle(sleepColor)
            }
            Divider()
            HStack {
                statColumn("tab.today".localized(), "\(Int(todayCaffeine)) mg",
                           overDaily ? .red : .primary)
                Spacer()
                statColumn("fluids.daily_limit".localized(), "\(Int(guide.dailyLimitMg)) mg", .secondary)
                Spacer()
                statColumn("pro kg", String(format: "%.1f mg", weightKg > 0 ? todayCaffeine / weightKg : 0), .secondary)
            }
            if overDaily {
                warn(String(format: "fluids.over_limit".localized(), Int(guide.dailyLimitMg)))
            } else if overSingle {
                warn(String(format: "fluids.single_dose".localized(), Int(guide.singleLimitMg)))
            }
            Divider()
            NavigationLink {
                CaffeineHistoryView()
            } label: {
                HStack {
                    Label("fluids.caffeine_history".localized(), systemImage: "chart.bar.xaxis")
                    Spacer()
                    Image(systemName: "chevron.right").font(.footnote).foregroundStyle(.tertiary)
                }
                .font(.subheadline)
            }
            .accessibilityIdentifier("fluids.caffeineHistory.open")
        }
        .cardBackground()
    }

    private var sleepIcon: String {
        if activeCaffeine < guide.sleepThresholdMg { return "moon.zzz.fill" }
        return "moon.stars.fill"
    }
    private var sleepColor: Color {
        activeCaffeine < guide.sleepThresholdMg ? Theme.accent : .orange
    }
    private var sleepText: String {
        if activeCaffeine < guide.sleepThresholdMg {
            return "Schlaf-unbedenklich (unter \(Int(guide.sleepThresholdMg)) mg)."
        }
        if let safe = sleepSafeTime {
            return "Schlaf-ok ab \(safe.formatted(date: .omitted, time: .shortened))"
        }
        return "fluids.still_active".localized()
    }

    // MARK: Abbaukurve

    private var caffeineChartCard: some View {
        let start = (caffeineDoses.map(\.date).min() ?? now).addingTimeInterval(-1800)
        let end = max(now.addingTimeInterval(2 * 3600),
                      (sleepSafeTime ?? now.addingTimeInterval(8 * 3600)).addingTimeInterval(3600))
        let curve = CaffeineKinetics.curve(doses: caffeineDoses, from: start, to: end)
        return VStack(alignment: .leading, spacing: 12) {
            Text("fluids.caffeine_decay".localized()).font(.headline)
            Chart {
                ForEach(curve) { p in
                    AreaMark(x: .value("common.time".localized(), p.date), y: .value("mg", p.mg))
                        .foregroundStyle(.brown.opacity(0.12))
                    LineMark(x: .value("common.time".localized(), p.date), y: .value("mg", p.mg))
                        .foregroundStyle(.brown)
                        .interpolationMethod(.monotone)
                }
                RuleMark(y: .value("recovery.sleep".localized(), guide.sleepThresholdMg))
                    .foregroundStyle(Theme.accent.opacity(0.7))
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [5, 4]))
                    .annotation(position: .top, alignment: .leading) {
                        Text("fluids.sleep_threshold".localized()).font(.caption2).foregroundStyle(Theme.accent)
                    }
                RuleMark(x: .value("fluids.now".localized(), now))
                    .foregroundStyle(.secondary.opacity(0.4))
                    .lineStyle(StrokeStyle(lineWidth: 1))
                ForEach(caffeineDoses, id: \.date) { dose in
                    PointMark(x: .value("common.time".localized(), dose.date),
                              y: .value("mg", CaffeineKinetics.active(at: dose.date, doses: caffeineDoses)))
                        .foregroundStyle(.brown)
                        .symbolSize(40)
                }
            }
            .frame(height: 180)
            .chartXAxis { AxisMarks(values: .stride(by: .hour, count: 3)) { _ in
                AxisGridLine(); AxisValueLabel(format: .dateTime.hour())
            } }
        }
        .cardBackground()
    }

    // MARK: Getränke-Schnellwahl

    private var drinkGridCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("fluids.add_drink".localized()).font(.headline)
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 100), spacing: 10)], spacing: 10) {
                ForEach(DrinkPreset.caffeinated) { d in
                    Button { addDrink(d) } label: {
                        VStack(spacing: 4) {
                            Image(systemName: d.symbol).font(.title3).foregroundStyle(.brown)
                            Text(d.name).font(.caption.weight(.medium)).foregroundStyle(.primary)
                            Text("\(Int(d.caffeineMg)) mg").font(.caption2).foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity).padding(.vertical, 10)
                        .background(Color(.tertiarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 12))
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("fluids.drink.\(d.name)")
                }
            }
        }
        .cardBackground()
    }

    // MARK: Heutige Einträge

    private var todayIntakes: [IntakeEntry] {
        intakes.filter { Calendar.current.isDateInToday($0.date) }.sorted { $0.date > $1.date }
    }

    private var historyCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("tab.today".localized()).font(.headline)
            Text("fluids.mislogged_hint".localized())
                .font(.caption2).foregroundStyle(.secondary).padding(.top, 2).padding(.bottom, 8)
            ForEach(todayIntakes) { e in
                HStack {
                    Image(systemName: e.kind == .water ? "drop.fill" : "cup.and.saucer.fill")
                        .foregroundStyle(e.kind == .water ? .blue : .brown).frame(width: 24)
                    Text(e.kind == .water ? "Wasser" : "Koffein")
                    Spacer()
                    Text(e.kind == .water ? "\(Int(e.amount)) ml" : "\(Int(e.amount)) mg")
                        .foregroundStyle(.secondary).monospacedDigit()
                    Text(e.date.formatted(date: .omitted, time: .shortened))
                        .font(.caption).foregroundStyle(.tertiary).frame(width: 60, alignment: .trailing)
                    Button { delete(e) } label: {
                        Image(systemName: "trash").font(.caption).foregroundStyle(.red)
                    }.buttonStyle(.plain)
                    .accessibilityIdentifier("fluids.entry.delete")
                }
                .padding(.vertical, 8)
                .accessibilityElement(children: .contain)
                .accessibilityIdentifier(e.kind == .water ? "fluids.entry.water" : "fluids.entry.caffeine")
                if e.id != todayIntakes.last?.id { Divider() }
            }
        }
        .cardBackground()
    }

    // MARK: Bausteine & Aktionen

    private func quickButton(_ top: String, _ bottom: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 1) {
                Text(top).font(.subheadline.weight(.semibold))
                Text(bottom).font(.caption2).foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity).padding(.vertical, 8)
            .background(Color(.tertiarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 10))
        }
        .buttonStyle(.plain)
    }

    private func statColumn(_ label: String, _ value: String, _ color: Color) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label).font(.caption2).foregroundStyle(.secondary)
            Text(value).font(.subheadline.weight(.semibold)).foregroundStyle(color).monospacedDigit()
        }
    }

    private func warn(_ text: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(.orange)
            Text(text).font(.caption).foregroundStyle(.secondary)
        }
    }

    private func pacingText(behind: Double) -> String {
        if behind > 200 { return String(format: "fluids.behind".localized(), Int(behind)) }
        if behind < -200 { return String(format: "fluids.ahead".localized(), Int(-behind)) }
        return "fluids.on_plan".localized()
    }

    private var undoBar: some View {
        HStack(spacing: 12) {
            Text(undoLabel).font(.subheadline).foregroundStyle(.white)
            Spacer()
            Button("common.undo".localized()) { undoLast() }
                .font(.subheadline.weight(.semibold)).foregroundStyle(.yellow)
                .accessibilityIdentifier("fluids.undo")
        }
        .padding(.horizontal, 18).padding(.vertical, 12)
        .background(Color.black.opacity(0.85), in: Capsule())
        .padding(.horizontal, 20).padding(.bottom, 16)
        .transition(.move(edge: .bottom).combined(with: .opacity))
    }

    /// Zeigt die „Rückgängig"-Snackbar für ~4 s und merkt sich die eben angelegten Einträge.
    private func flashUndo(_ label: String, _ entries: [IntakeEntry]) {
        lastAdded = entries
        undoLabel = label
        undoToken += 1
        let token = undoToken
        withAnimation { showUndo = true }
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(4))
            if token == undoToken { withAnimation { showUndo = false } }
        }
    }

    private func undoLast() {
        // HK-UUIDs VOR dem SwiftData-Delete sichern (gelöschte Models nicht mehr anfassen).
        let hkRefs: [(uuid: UUID, kind: IntakeKind)] = lastAdded.compactMap { e in
            e.healthKitUUID.map { ($0, e.kind) }
        }
        for e in lastAdded { context.delete(e) }
        try? context.save()
        lastAdded = []
        now = Date()
        withAnimation { showUndo = false }
        if !hkRefs.isEmpty {
            Task {
                for ref in hkRefs { await health.deleteIntakeSample(uuid: ref.uuid, kind: ref.kind) }
            }
        }
    }

    private func addWater(_ ml: Double) {
        let e = IntakeEntry(kind: .water, amount: ml)
        context.insert(e)
        try? context.save()
        now = Date()
        flashUndo("Wasser +\(Int(ml)) ml", [e])
        Task { @MainActor in
            let uuid = await health.saveWater(ml: ml)
            if e.isDeleted || e.modelContext == nil {
                // Eintrag wurde waehrend des HK-Writes geloescht (Undo-Rennen): Sample direkt entsorgen.
                if let uuid { await health.deleteIntakeSample(uuid: uuid, kind: .water) }
            } else {
                e.healthKitUUID = uuid
                try? context.save()
            }
        }
    }

    private func addDrink(_ d: DrinkPreset) {
        var added: [IntakeEntry] = []
        if d.caffeineMg > 0 {
            let c = IntakeEntry(kind: .caffeine, amount: d.caffeineMg)
            context.insert(c); added.append(c)
            Task { @MainActor in
                let uuid = await health.saveCaffeine(mg: d.caffeineMg)
                if c.isDeleted || c.modelContext == nil {
                    if let uuid { await health.deleteIntakeSample(uuid: uuid, kind: .caffeine) }
                } else {
                    c.healthKitUUID = uuid
                    try? context.save()
                }
            }
        }
        if d.waterMl > 0 {
            let w = IntakeEntry(kind: .water, amount: d.waterMl)
            context.insert(w); added.append(w)
            Task { @MainActor in
                let uuid = await health.saveWater(ml: d.waterMl)
                if w.isDeleted || w.modelContext == nil {
                    if let uuid { await health.deleteIntakeSample(uuid: uuid, kind: .water) }
                } else {
                    w.healthKitUUID = uuid
                    try? context.save()
                }
            }
        }
        try? context.save()
        now = Date()   // sofort aktualisieren, damit die neue Dosis als „aktiv" zählt
        flashUndo(String(format: "fluids.added".localized(), d.name), added)
    }

    private func delete(_ e: IntakeEntry) {
        // HK-Referenz VOR dem SwiftData-Delete sichern; Bestandseinträge ohne UUID: nur SwiftData.
        let hkUUID = e.healthKitUUID
        let kind = e.kind
        context.delete(e)
        try? context.save()
        if let hkUUID {
            Task { await health.deleteIntakeSample(uuid: hkUUID, kind: kind) }
        }
    }
}

private extension View {
    /// Einheitlicher Karten-Hintergrund passend zum App-Design.
    func cardBackground() -> some View {
        self.padding(20)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16))
    }
}
