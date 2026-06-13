import SwiftUI
import SwiftData
import Charts

/// Fortschritt: Gewichtsverlauf als Diagramm + schnelles Eintragen.
struct WeightProgressView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \WeightEntry.date) private var entries: [WeightEntry]
    @Query private var profiles: [UserProfile]
    private let health = NutritionHealthStore()

    @State private var showLog = false
    @State private var bodyData: BodyData?

    private var latest: WeightEntry? { entries.last }
    private var change: Double? {
        guard let first = entries.first, let last = entries.last, entries.count > 1 else { return nil }
        return last.weightKg - first.weightKg
    }

    var body: some View {
        ScrollView {
                VStack(spacing: 16) {
                    if entries.isEmpty {
                        ContentUnavailableView("weight.empty_title".localized(),
                            systemImage: "scalemass",
                            description: Text("weight.empty_desc".localized()))
                            .padding(.top, 60)
                    } else {
                        summaryCard
                        if bodyData?.hasAny == true { bodyCompositionCard }
                        chartCard
                        historyCard
                    }
                }
                .padding(16)
            }
            .task { bodyData = await health.readBodyData() }
            .background(Color(.systemGroupedBackground))
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showLog = true } label: { Image(systemName: "plus") }
                        .accessibilityIdentifier("logWeight")
                }
            }
            .sheet(isPresented: $showLog) {
                LogWeightView(initialKg: latest?.weightKg ?? profiles.first?.weightKg ?? 75) { kg, date in
                    addWeight(kg, date)
                }
            }
    }

    private var summaryCard: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("weight.current".localized()).font(.caption).foregroundStyle(.secondary)
                Text("\(latest.map { String(format: "%.1f", $0.weightKg) } ?? "–") kg")
                    .font(.title2.bold())
            }
            Spacer()
            if let change {
                VStack(alignment: .trailing, spacing: 4) {
                    Text("weight.change".localized()).font(.caption).foregroundStyle(.secondary)
                    Text("\(change >= 0 ? "+" : "")\(String(format: "%.1f", change)) kg")
                        .font(.title3.bold())
                        .foregroundStyle(change <= 0 ? .green : .orange)
                }
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16))
    }

    private var chartCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("weight.history".localized()).font(.headline)
            Chart(entries) { entry in
                LineMark(x: .value("common.date".localized(), entry.date),
                         y: .value("settings.weight".localized(), entry.weightKg))
                    .interpolationMethod(.catmullRom)
                PointMark(x: .value("common.date".localized(), entry.date),
                          y: .value("settings.weight".localized(), entry.weightKg))
            }
            .chartYScale(domain: .automatic(includesZero: false))
            .frame(height: 220)
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16))
    }

    // MARK: Körperzusammensetzung (aus Apple Health, plus Ableitungen)

    private var currentWeight: Double? { latest?.weightKg ?? bodyData?.weightKg }

    private var bmi: Double? {
        let h = bodyData?.heightCm ?? profiles.first?.heightCm
        guard let h, h > 0, let w = currentWeight else { return nil }
        let m = h / 100
        return w / (m * m)
    }

    private var bodyCompositionCard: some View {
        let w = currentWeight
        let bf = bodyData?.bodyFatPercent
        let lean = bodyData?.leanBodyMassKg ?? (w.flatMap { wt in bf.map { wt * (1 - $0 / 100) } })
        let fatMass = (w != nil && bf != nil) ? w! * bf! / 100 : nil
        let water = lean.map { $0 * 0.73 }   // fettfreie Masse ist ~73 % Wasser

        var tiles: [(String, String, String, Color)] = []
        if let bf { tiles.append(("settings.bodyfat".localized(), String(format: "%.1f %%", bf), "drop.triangle.fill", .orange)) }
        if let fatMass { tiles.append(("weight.fatmass".localized(), String(format: "%.1f kg", fatMass), "scalemass.fill", .orange)) }
        if let lean { tiles.append(("weight.leanmass".localized(), String(format: "%.1f kg", lean), "figure.strengthtraining.traditional", .blue)) }
        if let water { tiles.append(("weight.bodywater".localized(), String(format: "%.1f kg", water), "drop.fill", .teal)) }
        if let bmi { tiles.append(("BMI", String(format: "%.1f", bmi), "ruler.fill", .secondary)) }

        return VStack(alignment: .leading, spacing: 12) {
            Text("weight.composition".localized()).font(.headline)
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                ForEach(tiles, id: \.0) { t in
                    HStack(spacing: 10) {
                        Image(systemName: t.2).foregroundStyle(t.3).frame(width: 22)
                        VStack(alignment: .leading, spacing: 1) {
                            Text(t.0).font(.caption2).foregroundStyle(.secondary)
                            Text(t.1).font(.subheadline.weight(.semibold)).monospacedDigit()
                        }
                        Spacer(minLength: 0)
                    }
                    .padding(10)
                    .background(Color(.tertiarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 12))
                }
            }
            Text("weight.composition_note".localized())
                .font(.caption2).foregroundStyle(.secondary)
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16))
    }

    // MARK: Historie der Gewichtseinträge (neueste zuerst, mit Differenz)

    private var historyCard: some View {
        let recent = Array(entries.suffix(40))   // jüngste 40, chronologisch
        return VStack(alignment: .leading, spacing: 0) {
            Text("weight.entries".localized()).font(.headline).padding(.bottom, 8)
            ForEach(recent.indices.reversed(), id: \.self) { i in
                let e = recent[i]
                let delta = i > 0 ? e.weightKg - recent[i - 1].weightKg : nil
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(String(format: "%.1f kg", e.weightKg)).font(.subheadline.weight(.medium)).monospacedDigit()
                        Text(e.date.formatted(date: .abbreviated, time: .omitted))
                            .font(.caption).foregroundStyle(.secondary)
                    }
                    Spacer()
                    if let delta, abs(delta) >= 0.05 {
                        Text("\(delta >= 0 ? "+" : "")\(String(format: "%.1f", delta)) kg")
                            .font(.caption.weight(.medium))
                            .foregroundStyle(delta <= 0 ? .green : .orange).monospacedDigit()
                    }
                    if e.healthKitUUID != nil {
                        Image(systemName: "heart.fill").font(.caption2).foregroundStyle(.pink).padding(.leading, 6)
                    }
                }
                .padding(.vertical, 8)
                if i > 0 { Divider() }
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16))
    }

    private func addWeight(_ kg: Double, _ date: Date) {
        let entry = WeightEntry(date: date, weightKg: kg)
        context.insert(entry)
        // Aktuelles Gewicht ins Profil übernehmen (fließt in die Kalorienberechnung).
        profiles.first?.weightKg = kg
        try? context.save()
        Task { await health.saveWeight(kg: kg, date: date) }
    }
}

/// Eingabemaske für einen Gewichtswert.
private struct LogWeightView: View {
    @Environment(\.dismiss) private var dismiss
    let initialKg: Double
    let onSave: (Double, Date) -> Void

    @State private var kg: Double
    @State private var date: Date = .now

    init(initialKg: Double, onSave: @escaping (Double, Date) -> Void) {
        self.initialKg = initialKg
        self.onSave = onSave
        _kg = State(initialValue: initialKg)
    }

    var body: some View {
        NavigationStack {
            Form {
                HStack {
                    Text("settings.weight".localized())
                    Spacer()
                    TextField("kg", value: $kg, format: .number)
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.trailing)
                        .frame(width: 90)
                    Text("kg").foregroundStyle(.secondary)
                }
                DatePicker("common.date".localized(), selection: $date, displayedComponents: .date)
            }
            .navigationTitle("weight.add_title".localized())
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("common.cancel".localized()) { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("common.save".localized()) { onSave(kg, date); dismiss() }.disabled(kg <= 0)
                }
            }
        }
    }
}
