import SwiftUI
import SwiftData

/// Erfassungsmaske mit Portions-Picker (A1) und Bearbeiten-Modus (A3).
/// - `scannedFood` vorbefüllt aus Scan/Auswahl; nil = manuelle Eingabe.
/// - `editingEntry` gesetzt = bestehenden Tagebuch-Eintrag ändern.
struct LogEntryView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context

    let scannedFood: FoodItem?
    let editingEntry: FoodEntry?
    let presetBarcode: String?      // bei manueller Erfassung nach unbekanntem Barcode
    let prefillNutrients: ParsedLabel?   // Etikett-OCR: Nährwerte vorbefüllen (editierbar)
    let prefillName: String?             // optionaler Name-Vorschlag (Etikett-OCR)
    let onSave: (FoodEntry) -> Void

    @State private var name = ""
    @State private var grams: Double = 100
    @State private var servingLabel = "100 g/ml"
    @State private var count: Double = 1
    @State private var mealType: MealType
    @State private var kcal = ""
    @State private var protein = ""
    @State private var carbs = ""
    @State private var fat = ""

    private var isEditing: Bool { editingEntry != nil }

    private var navTitle: String {
        if isEditing { return "Eintrag bearbeiten" }
        if prefillNutrients != nil { return "Etikett prüfen" }
        return scannedFood == nil ? "Manuell erfassen" : "Erfassen"
    }

    /// Erfassen/Scan. `presetMeal` belegt die Mahlzeit vor; `presetBarcode` setzt bei manueller
    /// Erfassung den Barcode (z. B. nach „nicht gefunden"), damit der nächste Scan ihn findet.
    init(scannedFood: FoodItem?, presetMeal: MealType = .snack,
         presetBarcode: String? = nil, onSave: @escaping (FoodEntry) -> Void) {
        self.scannedFood = scannedFood
        self.editingEntry = nil
        self.presetBarcode = presetBarcode
        self.prefillNutrients = nil
        self.prefillName = nil
        self.onSave = onSave
        _mealType = State(initialValue: presetMeal)
    }

    /// Etikett-Foto: Nährwerte aus OCR vorbefüllen, aber Name UND Werte bleiben editierbar
    /// (OCR kann Werte verfehlen, der Produktname steht nicht in der Nährwerttabelle).
    /// `presetBarcode` erhält den gescannten Code, damit der nächste Scan das Produkt findet.
    init(labelPrefill parsed: ParsedLabel, suggestedName: String = "",
         presetMeal: MealType = .snack, presetBarcode: String? = nil,
         onSave: @escaping (FoodEntry) -> Void) {
        self.scannedFood = nil
        self.editingEntry = nil
        self.presetBarcode = presetBarcode
        self.prefillNutrients = parsed
        self.prefillName = suggestedName.isEmpty ? nil : suggestedName
        self.onSave = onSave
        _mealType = State(initialValue: presetMeal)
    }

    /// Bestehenden Eintrag bearbeiten (A3).
    init(editing entry: FoodEntry, onSave: @escaping (FoodEntry) -> Void) {
        self.scannedFood = entry.food
        self.editingEntry = entry
        self.presetBarcode = nil
        self.prefillNutrients = nil
        self.prefillName = nil
        self.onSave = onSave
        _mealType = State(initialValue: entry.mealType)
    }

    private var servings: [Serving] {
        let n = scannedFood?.name ?? name
        var list = n.isEmpty ? [Serving(label: "100 g/ml", grams: 100)] : Serving.presets(for: n)
        // Herstellerdeklarierte Portion (z. B. „1 Riegel = 20,7 g") als benannte Option oben.
        if let g = scannedFood?.servingSizeG, g > 0 {
            let label = "1 Portion (\(g.truncatingRemainder(dividingBy: 1) == 0 ? String(Int(g)) : String(format: "%.1f", g)) g)"
            if !list.contains(where: { abs($0.grams - g) < 0.5 }) {
                list.insert(Serving(label: label, grams: g), at: 0)
            }
        }
        // KI-geschätzte ganze Portion ganz oben anbieten und damit als Default vorwählen.
        if let g = scannedFood?.aiPortionGrams, g > 0 {
            let base = (scannedFood?.aiPortionLabel?.isEmpty == false) ? scannedFood!.aiPortionLabel! : "1 Portion"
            list.insert(Serving(label: "\(base) (≈ \(Int(g.rounded())) g)", grams: g), at: 0)
        }
        return list
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Lebensmittel") {
                    if scannedFood == nil { TextField("Name", text: $name) }
                    else { Text(name).foregroundStyle(.secondary) }
                    Picker("Mahlzeit", selection: $mealType) {
                        ForEach(MealType.allCases) { Text($0.label).tag($0) }
                    }
                }

                Section("Portion") {
                    Picker("Portion", selection: $servingLabel) {
                        ForEach(servings) { Text($0.label).tag($0.label) }
                    }
                    .onChange(of: servingLabel) { _, _ in recomputeGrams() }
                    Stepper(value: $count, in: 0.5...20, step: 0.5) {
                        HStack { Text("Anzahl"); Spacer()
                            Text(count == count.rounded() ? "\(Int(count))" : String(format: "%.1f", count))
                                .foregroundStyle(.secondary) }
                    }
                    .onChange(of: count) { _, _ in recomputeGrams() }
                    HStack {
                        Text("Menge gesamt")
                        Spacer()
                        TextField("100", value: $grams, format: .number)
                            .keyboardType(.decimalPad).multilineTextAlignment(.trailing).frame(width: 80)
                        Text("g/ml").foregroundStyle(.secondary)
                    }
                }

                if scannedFood == nil {
                    Section {
                        nutrientField("Kalorien (kcal)", $kcal)
                        nutrientField("Eiweiß (g)", $protein)
                        nutrientField("Kohlenhydrate (g)", $carbs)
                        nutrientField("Fett (g)", $fat)
                    } header: {
                        Text("Nährwerte pro 100 g")
                    } footer: {
                        if prefillNutrients != nil {
                            Label("Aus dem Etikett-Foto erkannt – bitte kurz prüfen und ggf. korrigieren.",
                                  systemImage: "text.viewfinder")
                                .font(.caption)
                        }
                    }
                } else {
                    // Foto/Scan: Nährwerte für die gewählte Menge anzeigen (read-only).
                    Section("Nährwerte für diese Menge") {
                        readout("Kalorien", scaled(scannedFood?.kcalPer100g), "kcal")
                        readout("Eiweiß", scaled(scannedFood?.proteinPer100g), "g")
                        readout("Kohlenhydrate", scaled(scannedFood?.carbsPer100g), "g")
                        readout("Fett", scaled(scannedFood?.fatPer100g), "g")
                    }
                }
            }
            .navigationTitle(navTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Abbrechen") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button(isEditing ? "Übernehmen" : "Sichern") { save() }
                        .disabled((scannedFood == nil && name.isEmpty) || grams <= 0)
                }
            }
            .onAppear(perform: prefill)
        }
    }

    /// Nährwert je 100 g auf die aktuell gewählte Menge umrechnen.
    private func scaled(_ per100g: Double?) -> Double? {
        per100g.map { $0 * grams / 100 }
    }

    /// Read-only Nährwert-Zeile (für Foto/Scan).
    private func readout(_ label: String, _ value: Double?, _ unit: String) -> some View {
        HStack {
            Text(label); Spacer()
            if let v = value {
                Text("\(Int(v.rounded())) \(unit)").foregroundStyle(.secondary).monospacedDigit()
            } else {
                Text("—").foregroundStyle(.tertiary)
            }
        }
    }

    private func nutrientField(_ label: String, _ value: Binding<String>) -> some View {
        HStack {
            Text(label); Spacer()
            TextField("–", text: value).keyboardType(.decimalPad)
                .multilineTextAlignment(.trailing).frame(width: 90)
        }
    }

    private func recomputeGrams() {
        if let s = servings.first(where: { $0.label == servingLabel }) { grams = (s.grams * count).rounded() }
    }

    private func fmt(_ v: Double) -> String { v == v.rounded() ? String(Int(v)) : String(format: "%.1f", v) }

    private func prefill() {
        if let food = scannedFood {
            name = food.name
            kcal = food.kcalPer100g.map { fmt($0) } ?? ""
            protein = food.proteinPer100g.map { fmt($0) } ?? ""
            carbs = food.carbsPer100g.map { fmt($0) } ?? ""
            fat = food.fatPer100g.map { fmt($0) } ?? ""
        } else {
            // Etikett-OCR: editierbare Felder mit erkannten Werten vorbelegen.
            if let n = prefillName { name = n }
            if let p = prefillNutrients {
                kcal = p.kcalPer100g.map { fmt($0) } ?? ""
                protein = p.proteinPer100g.map { fmt($0) } ?? ""
                carbs = p.carbsPer100g.map { fmt($0) } ?? ""
                fat = p.fatPer100g.map { fmt($0) } ?? ""
            }
        }
        if let entry = editingEntry {
            grams = entry.grams                          // bestehende Menge übernehmen
            servingLabel = "100 g/ml"; count = max(0.5, (grams / 100))
        } else {
            // Default-Portion vorwählen (erste sinnvolle Hausmaß-Portion).
            if let first = servings.first { servingLabel = first.label; grams = first.grams; count = 1 }
            // KI-/zuletzt-genutzte Portionsschätzung als Startmenge übernehmen, falls vorhanden.
            if let lg = scannedFood?.lastGrams, lg > 0, lg != 100 { grams = lg }
        }
    }

    private func num(_ s: String) -> Double? { Double(s.replacingOccurrences(of: ",", with: ".")) }

    private func save() {
        // Bearbeiten: bestehenden Eintrag aktualisieren.
        if let entry = editingEntry {
            entry.grams = grams
            entry.mealType = mealType
            entry.syncedToHealthKit = false              // löst Re-Sync aus
            entry.food?.lastGrams = grams
            try? context.save()
            onSave(entry)
            dismiss()
            return
        }
        // Neu erfassen — mit Dedup beim manuellen Anlegen (A7): bestehendes
        // Lebensmittel gleichen Namens wiederverwenden statt Dublette anzulegen.
        let food: FoodItem
        if let sf = scannedFood {
            food = sf
        } else {
            let trimmed = name.trimmingCharacters(in: .whitespaces)
            let descriptor = FetchDescriptor<FoodItem>(predicate: #Predicate { $0.name == trimmed })
            if let existing = (try? context.fetch(descriptor))?.first {
                food = existing
            } else {
                food = FoodItem(name: trimmed)
                context.insert(food)
            }
            food.name = trimmed
            food.kcalPer100g = num(kcal); food.proteinPer100g = num(protein)
            food.carbsPer100g = num(carbs); food.fatPer100g = num(fat)
            // Etikett-OCR liefert zusätzlich Ballaststoffe/Zucker/Natrium → mitspeichern.
            if let p = prefillNutrients {
                food.fiberPer100g = p.fiberPer100g
                food.sugarPer100g = p.sugarPer100g
                food.sodiumMgPer100g = p.sodiumMgPer100g
            }
            if let bc = presetBarcode, food.barcode == nil { food.barcode = bc }
        }
        food.lastFetched = .now
        food.useCount += 1                                // A7: Häufigkeit
        food.lastGrams = grams                            // A2: letzte Portion merken
        let entry = FoodEntry(grams: grams > 0 ? grams : 100, mealType: mealType, food: food)
        onSave(entry)
        dismiss()
    }
}
