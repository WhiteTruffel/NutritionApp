import SwiftUI
import SwiftData
import UIKit

/// MyFitnessPal-artiger „Add Food"-Flow: Namenssuche über alle aktiven Datenquellen,
/// „Zuletzt verwendet" aus dem lokalen Cache, plus Barcode-Scan und manuelle Erfassung.
struct AddFoodView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @Query(sort: \FoodItem.lastFetched, order: .reverse) private var cachedFoods: [FoodItem]
    @Query(sort: \MealTemplate.useCount, order: .reverse) private var mealTemplates: [MealTemplate]

    let presetMeal: MealType
    let onSave: (FoodEntry) -> Void

    @State private var query = ""
    @State private var results: [FoodSearchResult] = []
    @State private var isSearching = false
    @State private var selectedFood: FoodItem?
    @State private var showManual = false
    @State private var showScanner = false
    @State private var showLabelOptions = false
    @State private var showFoodOptions = false
    @State private var pickerSource: PickerSource?
    @State private var pendingImage: UIImage?       // Bild zwischenspeichern, erst nach Sheet-Dismiss verarbeiten
    @State private var captureIsFood = false        // true = Gericht erkennen, false = Etikett lesen
    @State private var isParsingLabel = false
    @State private var isClassifying = false
    @State private var recognitionNote: String?
    @State private var showQuickAdd = false
    @State private var showTextMeal = false
    @State private var photoAlert: String?      // unmissverständliche Rückmeldung nach Gericht-Foto
    @State private var labelParsed: LabelPrefill?   // Etikett-OCR-Ergebnis → editierbare Prüf-Maske
    @State private var photoResults: PhotoResults?  // Multi-Tellerfoto → Auswahl der Komponenten

    private let service = FoodSearchService.shared

    var body: some View {
        NavigationStack {
            List {
                if query.trimmingCharacters(in: .whitespaces).count < 2 {
                    Section {
                        Button { showScanner = true } label: {
                            Label("Barcode scannen", systemImage: "barcode.viewfinder")
                        }
                        Button { showLabelOptions = true } label: {
                            Label("Etikett fotografieren", systemImage: "text.viewfinder")
                        }
                        Button { showFoodOptions = true } label: {
                            Label("Gericht fotografieren", systemImage: "fork.knife")
                        }
                        Button { showTextMeal = true } label: {
                            Label("Mahlzeit per Text (KI)", systemImage: "text.bubble")
                        }
                        Button { showManual = true } label: {
                            Label("Manuell erfassen", systemImage: "square.and.pencil")
                        }
                        Button { showQuickAdd = true } label: {
                            Label("Schnelleintrag (nur kcal)", systemImage: "bolt.fill")
                        }
                        if let recognitionNote {
                            Text(recognitionNote).font(.caption).foregroundStyle(.secondary)
                        }
                    }
                    if !mealTemplates.isEmpty {
                        Section("Meine Mahlzeiten") {
                            ForEach(mealTemplates) { t in
                                Button { logMeal(t) } label: {
                                    HStack {
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(t.name)
                                            Text("\(t.components.count) Zutaten")
                                                .font(.caption).foregroundStyle(.secondary)
                                        }
                                        Spacer()
                                        Text("\(Int(t.totalKcal.rounded())) kcal")
                                            .font(.caption).foregroundStyle(.secondary).monospacedDigit()
                                        Image(systemName: "plus.circle.fill").font(.title2).foregroundStyle(.green)
                                    }
                                }
                                .buttonStyle(.plain)
                            }
                            .onDelete { offsets in
                                for i in offsets { context.delete(mealTemplates[i]) }
                                try? context.save()
                            }
                        }
                    }
                    if !favoriteFoods.isEmpty {
                        Section("Favoriten") {
                            ForEach(favoriteFoods) { foodRowItem($0) }
                        }
                    }
                    if !recentFoods.isEmpty {
                        Section("Zuletzt verwendet") {
                            ForEach(recentFoods) { foodRowItem($0) }
                        }
                    }
                } else {
                    if !localMatches.isEmpty {
                        Section("Eigene Lebensmittel") {
                            ForEach(localMatches) { food in
                                Button { selectedFood = food } label: {
                                    FoodRow(name: food.name, brand: food.brand,
                                            kcalPer100g: food.kcalPer100g, source: nil)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                    Section("Datenbanken") {
                        if isSearching {
                            HStack { ProgressView(); Text("Suche …").foregroundStyle(.secondary) }
                        }
                        ForEach(results) { result in
                            Button { pick(result) } label: {
                                FoodRow(name: result.name, brand: result.brand,
                                        kcalPer100g: result.kcalPer100g, source: result.source)
                            }
                            .buttonStyle(.plain)
                        }
                        if !isSearching && results.isEmpty {
                            Text("Keine Treffer. Tipp: manuell erfassen.")
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
            .navigationTitle("Hinzufügen")
            .navigationBarTitleDisplayMode(.inline)
            .searchable(text: $query, prompt: "Lebensmittel suchen")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Abbrechen") { dismiss() } }
            }
            .task(id: query) { await runSearch() }
            .sheet(item: $selectedFood) { food in
                LogEntryView(scannedFood: food, presetMeal: presetMeal) { entry in
                    onSave(entry); dismiss()
                }
            }
            .sheet(isPresented: $showManual) {
                LogEntryView(scannedFood: nil, presetMeal: presetMeal) { entry in
                    onSave(entry); dismiss()
                }
            }
            .sheet(item: $labelParsed) { item in
                LogEntryView(labelPrefill: item.parsed, presetMeal: presetMeal) { entry in
                    onSave(entry); dismiss()
                }
            }
            .sheet(isPresented: $showTextMeal) {
                TextMealView(presetMeal: presetMeal) { items in logResults(items) }
            }
            .sheet(item: $photoResults) { pr in
                FoodPickerView(title: "Gericht erkannt", results: pr.items) { items in logResults(items) }
            }
            .sheet(isPresented: $showScanner) {
                ScanFlowView { entry in onSave(entry); dismiss() }
            }
            .sheet(isPresented: $showQuickAdd) {
                QuickAddView(presetMeal: presetMeal) { entry in onSave(entry); dismiss() }
            }
            .confirmationDialog("Nährwert-Etikett", isPresented: $showLabelOptions, titleVisibility: .visible) {
                if UIImagePickerController.isSourceTypeAvailable(.camera) {
                    Button("Kamera") { captureIsFood = false; pickerSource = .camera }
                }
                Button("Fotomediathek") { captureIsFood = false; pickerSource = .library }
                Button("Abbrechen", role: .cancel) { }
            } message: {
                Text("Fotografiere die Nährwerttabelle – die Werte werden automatisch erkannt.")
            }
            .confirmationDialog("Gericht erkennen", isPresented: $showFoodOptions, titleVisibility: .visible) {
                if UIImagePickerController.isSourceTypeAvailable(.camera) {
                    Button("Kamera") { captureIsFood = true; pickerSource = .camera }
                }
                Button("Fotomediathek") { captureIsFood = true; pickerSource = .library }
                Button("Abbrechen", role: .cancel) { }
            } message: {
                Text("Schätzung per Bilderkennung – das Ergebnis wird in die Suche übernommen, dort verfeinern.")
            }
            // Foto-Picker im EIGENEN Präsentations-Kanal (fullScreenCover), getrennt
            // von den .sheet(...)-Masken. Sonst blockieren sich schließender Picker und
            // öffnende Ergebnis-Maske im selben Sheet-Kanal → „nichts passiert".
            // Die Bildverarbeitung läuft erst im onDismiss, wenn der Picker komplett zu ist.
            .alert("Gericht-Foto", isPresented: Binding(
                get: { photoAlert != nil },
                set: { if !$0 { photoAlert = nil } }
            )) {
                Button("OK", role: .cancel) { photoAlert = nil }
            } message: {
                Text(photoAlert ?? "")
            }
            .fullScreenCover(item: $pickerSource, onDismiss: processPendingImage) { source in
                ImagePicker(
                    sourceType: source.uiType,
                    onImage: { image in
                        pendingImage = image     // merken; Verarbeitung läuft in onDismiss
                        pickerSource = nil        // schließt den Cover NUR über SwiftUI
                    },
                    onCancel: { pickerSource = nil }
                )
                .ignoresSafeArea()
            }
            .overlay {
                if isParsingLabel || isClassifying {
                    ZStack {
                        Color.black.opacity(0.25).ignoresSafeArea()
                        VStack(spacing: 12) {
                            ProgressView()
                            Text(isClassifying ? "Erkenne Gericht …" : "Etikett wird gelesen …").font(.subheadline)
                        }
                        .padding(24)
                        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
                    }
                }
            }
        }
    }

    /// A7: nach Häufigkeit, dann Aktualität; leere Platzhalter-Namen ausblenden (D-04).
    private var recentFoods: [FoodItem] {
        cachedFoods
            .filter { !$0.name.trimmingCharacters(in: .whitespaces).isEmpty }
            .sorted { ($0.useCount, $0.lastFetched ?? .distantPast) > ($1.useCount, $1.lastFetched ?? .distantPast) }
            .prefix(15).map { $0 }
    }

    /// A2: 1-Tipp-Wiederholung mit der zuletzt genutzten Portion.
    private func quickAdd(_ food: FoodItem) {
        food.useCount += 1
        food.lastFetched = .now
        try? context.save()
        let entry = FoodEntry(grams: food.lastGrams > 0 ? food.lastGrams : 100,
                              mealType: presetMeal, food: food)
        onSave(entry)
        dismiss()
    }

    /// A5: Favoriten (oben in der Liste).
    private var favoriteFoods: [FoodItem] {
        cachedFoods.filter { $0.isFavorite && !$0.name.trimmingCharacters(in: .whitespaces).isEmpty }
    }

    private func toggleFavorite(_ food: FoodItem) {
        food.isFavorite.toggle()
        try? context.save()
    }

    /// Zeile mit Auswählen (tippen), Favoriten-Stern (A5) und Schnell-„+" (A2).
    @ViewBuilder
    private func foodRowItem(_ food: FoodItem) -> some View {
        HStack(spacing: 8) {
            Button { selectedFood = food } label: {
                FoodRow(name: food.name, brand: food.brand, kcalPer100g: food.kcalPer100g, source: nil)
            }
            .buttonStyle(.plain)
            Button { toggleFavorite(food) } label: {
                Image(systemName: food.isFavorite ? "star.fill" : "star")
                    .foregroundStyle(food.isFavorite ? .yellow : .secondary)
            }
            .buttonStyle(.borderless)
            Button { quickAdd(food) } label: {
                Image(systemName: "plus.circle.fill").font(.title2)
            }
            .buttonStyle(.borderless).tint(.green)
        }
    }

    private var localMatches: [FoodItem] {
        let q = query.trimmingCharacters(in: .whitespaces)
        guard q.count >= 2 else { return [] }
        return cachedFoods.filter { $0.name.localizedCaseInsensitiveContains(q) }
    }

    // MARK: Suche (entprellt über task-id-Cancel + kurze Verzögerung)

    private func runSearch() async {
        let q = query.trimmingCharacters(in: .whitespaces)
        guard q.count >= 2 else { results = []; isSearching = false; return }
        try? await Task.sleep(for: .milliseconds(350))   // Debounce
        if Task.isCancelled { return }
        isSearching = true
        let found = await service.search(q)
        if Task.isCancelled { return }
        results = found
        isSearching = false
    }

    // MARK: Auswahl → Nährwerte nachladen → Erfassungsmaske

    private func pick(_ result: FoodSearchResult) {
        Task { @MainActor in
            let hydrated = (try? await service.hydrate(result)) ?? result
            selectedFood = makeFood(from: hydrated)
        }
    }

    // MARK: Bildverarbeitung erst NACH dem Schließen des Picker-Sheets

    /// Wird vom `onDismiss` des Picker-Sheets aufgerufen. Erst jetzt ist das Sheet
    /// vollständig zu, sodass das Folge-Sheet (Erfassungsmaske) sauber öffnet.
    private func processPendingImage() {
        guard let image = pendingImage else { return }
        pendingImage = nil
        if captureIsFood { handleFoodImage(image) } else { handleLabelImage(image) }
    }

    // MARK: Etikett-Foto → OCR → Nährwerte → Maske

    private func handleLabelImage(_ image: UIImage) {
        guard let data = image.jpegData(compressionQuality: 0.9) else { return }
        let orientation = TextRecognizer.cgOrientation(image.imageOrientation)
        isParsingLabel = true
        Task { @MainActor in
            // Erst räumlich (Name↔Wert paaren, zweispaltige Etiketten); sonst zeilenbasiert.
            let tokens = await TextRecognizer.recognizeTokens(from: data, orientation: orientation)
            var parsed = NutritionLabelParser.parse(tokens)
            if !parsed.hasAny {
                let lines = await TextRecognizer.recognizeLines(from: data, orientation: orientation)
                parsed = NutritionLabelParser.parse(lines)
            }
            isParsingLabel = false
            // Editierbare Prüf-Maske: Name eintippbar, erkannte Nährwerte vorbefüllt & korrigierbar.
            // (Kein FoodItem mit leerem Namen mehr anlegen.)
            labelParsed = LabelPrefill(parsed: parsed)
        }
    }

    // MARK: Gericht-Foto → on-device Erkennung → Suche füttern

    private func handleFoodImage(_ image: UIImage) {
        guard let data = image.jpegData(compressionQuality: 0.9) else { return }
        let orientation = TextRecognizer.cgOrientation(image.imageOrientation)
        isClassifying = true
        recognitionNote = nil
        Task { @MainActor in
            // Bevorzugt KI (Gemini), wenn ein API-Key hinterlegt ist: erkennt konkrete
            // Gerichte auf Deutsch und schätzt Nährwerte → Maske direkt vorausfüllen.
            if GeminiFoodVision.isConfigured {
                do {
                    let multi = try await GeminiFoodVision.recognizeMulti(jpegData: data)
                    isClassifying = false
                    if multi.count > 1 {
                        photoResults = PhotoResults(items: multi)   // ganze Mahlzeit → Auswahl
                        return
                    }
                    if let r = multi.first, !r.name.isEmpty {
                        let food = FoodItem(name: r.name)
                        food.kcalPer100g    = r.kcalPer100g
                        food.proteinPer100g = r.proteinPer100g
                        food.carbsPer100g   = r.carbsPer100g
                        food.fatPer100g     = r.fatPer100g
                        if let g = r.portionGrams, g > 0 {
                            food.lastGrams = g                 // KI-Portionsschätzung
                            food.aiPortionGrams = g
                            food.aiPortionLabel = r.portionLabel
                        }
                        food.lastFetched = .now
                        context.insert(food)
                        try? context.save()
                        selectedFood = food      // öffnet die Erfassungsmaske, vorausgefüllt
                        return
                    }
                    photoAlert = "Die KI hat auf dem Foto kein Gericht erkannt. Versuch es mit einem klareren Foto oder erfasse über Suche/Barcode."
                    return
                } catch {
                    // KI fehlgeschlagen → klare Meldung mit Grund (kein stilles Scheitern).
                    isClassifying = false
                    let reason = (error as? GeminiFoodVision.VisionError)?.errorDescription
                        ?? error.localizedDescription
                    photoAlert = "KI-Erkennung nicht möglich: \(reason).\n\nPrüfe, ob der API-Key korrekt ist und Internet besteht. Du kannst stattdessen Suche, Barcode oder manuelle Eingabe nutzen."
                    return
                }
            }
            // Fallback: generischer On-Device-Klassifikator → füttert die Suche.
            isClassifying = true
            let labels = await FoodImageClassifier.classify(from: data, orientation: orientation)
            isClassifying = false
            if let best = labels.first {
                query = best
                recognitionNote = "Erkannt: \(labels.prefix(3).joined(separator: ", ")) – in der Suche verfeinern."
            } else if recognitionNote == nil {
                recognitionNote = "Nicht erkannt. Bitte über Suche, Barcode oder manuell erfassen."
            }
        }
    }

    /// BL8: gespeicherte Mahlzeit mit einem Tipp loggen – jede Komponente wird als Eintrag
    /// in die aktuelle Mahlzeit übernommen (Lebensmittel werden bei Bedarf wiederverwendet).
    private func logMeal(_ template: MealTemplate) {
        for c in template.components {
            let food: FoodItem
            if let existing = cachedFoods.first(where: { $0.name == c.name }) {
                food = existing
            } else {
                food = FoodItem(name: c.name)
                food.kcalPer100g = c.kcalPer100g; food.proteinPer100g = c.proteinPer100g
                food.carbsPer100g = c.carbsPer100g; food.fatPer100g = c.fatPer100g
                food.fiberPer100g = c.fiberPer100g; food.sugarPer100g = c.sugarPer100g
                food.sodiumMgPer100g = c.sodiumMgPer100g
                food.lastFetched = .now
                context.insert(food)
            }
            onSave(FoodEntry(grams: c.grams, mealType: presetMeal, food: food))
        }
        template.useCount += 1
        try? context.save()
        dismiss()
    }

    /// Mehrere KI-Ergebnisse (Text oder Multi-Foto) als Einträge übernehmen.
    private func logResults(_ items: [GeminiFoodResult]) {
        for r in items {
            let food = FoodItem(name: r.name)
            food.kcalPer100g = r.kcalPer100g; food.proteinPer100g = r.proteinPer100g
            food.carbsPer100g = r.carbsPer100g; food.fatPer100g = r.fatPer100g
            food.lastFetched = .now
            context.insert(food)
            let grams = (r.portionGrams ?? 100) > 0 ? (r.portionGrams ?? 100) : 100
            onSave(FoodEntry(grams: grams, mealType: presetMeal, food: food))
        }
        try? context.save()
        dismiss()
    }

    private func makeFood(from r: FoodSearchResult) -> FoodItem {
        if let bc = r.barcode, let existing = cachedFoods.first(where: { $0.barcode == bc }) {
            return existing
        }
        let f = FoodItem(name: r.name, barcode: r.barcode, brand: r.brand)
        f.kcalPer100g     = r.kcalPer100g
        f.proteinPer100g  = r.proteinPer100g
        f.carbsPer100g    = r.carbsPer100g
        f.fatPer100g      = r.fatPer100g
        f.saturatedFatPer100g = r.saturatedFatPer100g
        f.fiberPer100g    = r.fiberPer100g
        f.sugarPer100g    = r.sugarPer100g
        f.sodiumMgPer100g = r.sodiumMgPer100g
        f.servingSizeG    = r.servingSizeG
        f.micros          = r.micros
        f.lastFetched = .now
        context.insert(f)
        try? context.save()
        return f
    }
}

/// Identifizierbarer Wrapper, um ein OCR-Etikett-Ergebnis per `.sheet(item:)` zu präsentieren.
private struct LabelPrefill: Identifiable {
    let id = UUID()
    let parsed: ParsedLabel
}

/// Wrapper für ein Multi-Foto-Erkennungsergebnis (BL12) für `.sheet(item:)`.
private struct PhotoResults: Identifiable {
    let id = UUID()
    let items: [GeminiFoodResult]
}

// MARK: - Trefferzeile

private struct FoodRow: View {
    let name: String
    let brand: String?
    let kcalPer100g: Double?
    let source: String?

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(name).foregroundStyle(.primary)
                HStack(spacing: 6) {
                    if let brand, !brand.isEmpty {
                        Text(brand)
                    }
                    if let source {
                        Text(source)
                            .font(.caption2)
                            .padding(.horizontal, 5).padding(.vertical, 1)
                            .background(Color(.systemGray5), in: Capsule())
                    }
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }
            Spacer()
            if let kcal = kcalPer100g {
                Text("\(Int(kcal)) kcal/100 g")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }
        }
    }
}

// MARK: - Schnelleintrag (A4): nur Kalorien (optional Makros), ohne Lebensmittel

private struct QuickAddView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    let presetMeal: MealType
    let onSave: (FoodEntry) -> Void

    @State private var label = "Schnelleintrag"
    @State private var kcal = ""
    @State private var protein = ""
    @State private var carbs = ""
    @State private var fat = ""

    private func num(_ s: String) -> Double? { Double(s.replacingOccurrences(of: ",", with: ".")) }
    private var kcalValue: Double? { if let v = num(kcal), v > 0 { return v }; return nil }

    var body: some View {
        NavigationStack {
            Form {
                Section("Schnelleintrag") {
                    HStack {
                        Text("Bezeichnung"); Spacer()
                        TextField("Schnelleintrag", text: $label).multilineTextAlignment(.trailing)
                    }
                    field("Kalorien (kcal)", $kcal)
                }
                Section("Optional (Makros)") {
                    field("Eiweiß (g)", $protein)
                    field("Kohlenhydrate (g)", $carbs)
                    field("Fett (g)", $fat)
                }
            }
            .navigationTitle("Schnelleintrag")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Abbrechen") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Sichern") { save() }.disabled(kcalValue == nil)
                }
            }
        }
    }

    private func field(_ t: String, _ b: Binding<String>) -> some View {
        HStack {
            Text(t); Spacer()
            TextField("–", text: b).keyboardType(.decimalPad)
                .multilineTextAlignment(.trailing).frame(width: 90)
        }
    }

    private func save() {
        // Absolute Werte als „pro 100 g" mit 100 g Menge ablegen → Tagessumme = eingegebener Wert.
        let food = FoodItem(name: label.trimmingCharacters(in: .whitespaces).isEmpty ? "Schnelleintrag" : label)
        food.kcalPer100g = kcalValue
        food.proteinPer100g = num(protein)
        food.carbsPer100g = num(carbs)
        food.fatPer100g = num(fat)
        food.lastFetched = .now
        context.insert(food)
        let entry = FoodEntry(grams: 100, mealType: presetMeal, food: food)
        onSave(entry)
        dismiss()
    }
}
