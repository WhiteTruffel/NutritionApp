import SwiftUI
import SwiftData

/// Tagebuch im MyFitnessPal-Stil: Datumsnavigation oben, Abschnitte pro Mahlzeit
/// (Frühstück/Mittag/Abend/Snacks) mit Subtotalen und „Eintrag hinzufügen".
struct DiaryView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \FoodEntry.date, order: .reverse) private var allEntries: [FoodEntry]

    private let health = NutritionHealthStore()

    @State private var selectedDay: Date = .now
    @State private var addMeal: MealType?
    @State private var showScanner = false
    @State private var savingMeal: MealType?     // BL8: aktuelle Mahlzeit als Vorlage speichern
    @State private var mealName = ""

    // MARK: Abgeleitete Daten

    private var dayEntries: [FoodEntry] {
        allEntries.filter { Calendar.current.isDate($0.date, inSameDayAs: selectedDay) }
    }
    private func entries(for meal: MealType) -> [FoodEntry] {
        dayEntries.filter { $0.mealType == meal }
    }
    /// A6: Einträge der gleichen Mahlzeit am Vortag des gewählten Tages.
    private func yesterdayEntries(for meal: MealType) -> [FoodEntry] {
        guard let y = Calendar.current.date(byAdding: .day, value: -1, to: selectedDay) else { return [] }
        return allEntries.filter { Calendar.current.isDate($0.date, inSameDayAs: y) && $0.mealType == meal }
    }
    private var dayTotals: MacroTotals { dayEntries.totals() }

    var body: some View {
        NavigationStack {
            List {
                ForEach(MealType.allCases) { meal in
                    mealSection(meal)
                }

                Section {
                    HStack {
                        Text("diary.day_total".localized()).font(.subheadline.bold())
                        Spacer()
                        Text("\(Int(dayTotals.kcal.rounded())) kcal")
                            .font(.subheadline.bold())
                            .foregroundStyle(Theme.accent)
                    }
                }
            }
            .navigationTitle("tab.diary".localized())
            .navigationBarTitleDisplayMode(.inline)
            .safeAreaInset(edge: .top) { dateBar }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showScanner = true } label: {
                        Image(systemName: "barcode.viewfinder")
                    }
                }
            }
            .sheet(item: $addMeal) { meal in
                AddFoodView(presetMeal: meal) { addEntry($0) }
            }
            .sheet(isPresented: $showScanner) {
                ScanFlowView { addEntry($0) }
            }
            .alert("diary.save_meal_title".localized(), isPresented: Binding(
                get: { savingMeal != nil },
                set: { if !$0 { savingMeal = nil } }
            )) {
                TextField("diary.meal_name_placeholder".localized(), text: $mealName)
                Button("common.save".localized()) { if let m = savingMeal { saveMeal(m) }; savingMeal = nil }
                Button("common.cancel".localized(), role: .cancel) { savingMeal = nil }
            } message: {
                Text("diary.save_meal_msg".localized())
            }
        }
    }

    /// BL8: aktuelle Mahlzeit als wiederverwendbare Vorlage speichern.
    private func saveMeal(_ meal: MealType) {
        let comps = entries(for: meal).map { e in
            MealComponent(name: e.food?.name ?? "diary.meal_fallback".localized(), grams: e.grams,
                          kcalPer100g: e.food?.kcalPer100g, proteinPer100g: e.food?.proteinPer100g,
                          carbsPer100g: e.food?.carbsPer100g, fatPer100g: e.food?.fatPer100g,
                          fiberPer100g: e.food?.fiberPer100g, sugarPer100g: e.food?.sugarPer100g,
                          sodiumMgPer100g: e.food?.sodiumMgPer100g)
        }
        guard !comps.isEmpty else { return }
        let trimmed = mealName.trimmingCharacters(in: .whitespaces)
        let name = trimmed.isEmpty ? meal.label : trimmed
        context.insert(MealTemplate(name: name, components: comps))
        try? context.save()
    }

    // MARK: Mahlzeit-Abschnitt

    @ViewBuilder
    private func mealSection(_ meal: MealType) -> some View {
        let items = entries(for: meal)
        Section {
            ForEach(items) { entry in
                NavigationLink { EntryDetailView(entry: entry) } label: { EntryRow(entry: entry) }
            }
            .onDelete { offsets in delete(items, at: offsets) }

            Button {
                addMeal = meal
            } label: {
                Label("diary.add_entry".localized(), systemImage: "plus.circle.fill")
                    .font(.subheadline)
            }

            if !yesterdayEntries(for: meal).isEmpty {
                Button { copyYesterday(meal) } label: {
                    Label("Von gestern kopieren", systemImage: "arrow.uturn.down.circle")
                        .font(.subheadline)
                }
            }

            if !items.isEmpty {
                Button { savingMeal = meal; mealName = "" } label: {
                    Label("diary.save_as_meal".localized(), systemImage: "square.and.arrow.down")
                        .font(.subheadline)
                }
            }
        } header: {
            HStack {
                Text(meal.label)
                Spacer()
                Text("\(Int(items.totals().kcal.rounded())) kcal")
                    .foregroundStyle(.secondary)
            }
        }
    }

    // MARK: Datumsleiste

    private var dateBar: some View {
        HStack {
            Button { shiftDay(-1) } label: {
                Image(systemName: "chevron.left").frame(width: 44, height: 36)
            }
            Spacer()
            Text(dayLabel)
                .font(.headline)
            Spacer()
            Button { shiftDay(1) } label: {
                Image(systemName: "chevron.right").frame(width: 44, height: 36)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(.bar)
    }

    private var dayLabel: String {
        let cal = Calendar.current
        if cal.isDateInToday(selectedDay) { return "tab.today".localized() }
        if cal.isDateInYesterday(selectedDay) { return "diary.yesterday".localized() }
        if cal.isDateInTomorrow(selectedDay) { return "diary.tomorrow".localized() }
        return selectedDay.formatted(.dateTime.weekday(.wide).day().month(.abbreviated))
    }

    private func shiftDay(_ delta: Int) {
        if let d = Calendar.current.date(byAdding: .day, value: delta, to: selectedDay) {
            selectedDay = d
        }
    }

    // MARK: Schreiben / Löschen

    private func addEntry(_ entry: FoodEntry) {
        context.insert(entry)
        try? context.save()
        let payload = entry.makePayload()
        // MainActor-isoliert: entry (@Model) und context sind nicht Sendable.
        Task { @MainActor in
            do {
                try await health.save(payload)
                entry.syncedToHealthKit = true
                try? context.save()
            } catch {
                // Sync fehlgeschlagen: bleibt lokal, später erneut versuchen.
            }
        }
    }

    /// A6: alle Einträge der gestrigen Mahlzeit auf den gewählten Tag übernehmen.
    private func copyYesterday(_ meal: MealType) {
        let targetDate = Calendar.current.isDateInToday(selectedDay) ? Date() : selectedDay
        for src in yesterdayEntries(for: meal) {
            let copy = FoodEntry(date: targetDate, grams: src.grams, mealType: meal, food: src.food)
            addEntry(copy)
        }
    }

    /// A3: geänderten Eintrag in HealthKit neu synchronisieren (alte Korrelation ersetzen).

    private func delete(_ items: [FoodEntry], at offsets: IndexSet) {
        for index in offsets {
            let entry = items[index]
            let id = entry.id
            context.delete(entry)
            Task { try? await health.delete(mealID: id) }
        }
        try? context.save()
    }
}

// MARK: - Zeile

private struct EntryRow: View {
    let entry: FoodEntry
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(entry.food?.name ?? "diary.meal_fallback".localized())
                Text("\(Int(entry.grams)) g")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            HStack(spacing: 6) {
                if entry.syncedToHealthKit {
                    Image(systemName: "heart.fill")
                        .font(.caption2)
                        .foregroundStyle(.pink)
                }
                Text("\(Int((entry.kcal ?? 0).rounded())) kcal")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }
        }
    }
}
