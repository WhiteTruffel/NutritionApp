import SwiftUI

/// Mahlzeit per Freitext erfassen (BL11): Beschreibung → KI zerlegt in Lebensmittel →
/// auswählen → als Einträge übernehmen.
struct TextMealView: View {
    @Environment(\.dismiss) private var dismiss
    let presetMeal: MealType
    let onAdd: ([GeminiFoodResult]) -> Void

    @State private var text = ""
    @State private var results: [GeminiFoodResult] = []
    @State private var selected: Set<Int> = []
    @State private var loading = false
    @State private var error: String?

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("z. B. 2 Eier, 1 Scheibe Toast mit Butter und ein Kaffee",
                              text: $text, axis: .vertical)
                        .lineLimit(2...5)
                    Button { analyze() } label: {
                        HStack(spacing: 8) {
                            if loading { ProgressView() }
                            Text("Analysieren")
                        }
                    }
                    .disabled(text.trimmingCharacters(in: .whitespaces).isEmpty || loading)
                } header: {
                    Text("Beschreibung")
                } footer: {
                    if !GeminiFoodVision.isConfigured {
                        Text("Benötigt einen Gemini-API-Key (in den Einstellungen).")
                    } else if let error {
                        Text(error).foregroundStyle(.red)
                    }
                }

                if !results.isEmpty {
                    Section("Erkannt – zum Übernehmen antippen") {
                        ForEach(results.indices, id: \.self) { i in
                            let r = results[i]
                            Button { toggle(i) } label: {
                                HStack(spacing: 12) {
                                    Image(systemName: selected.contains(i) ? "checkmark.circle.fill" : "circle")
                                        .foregroundStyle(selected.contains(i) ? Theme.accent : .secondary)
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(r.name).foregroundStyle(.primary)
                                        Text("\(Int(r.portionGrams ?? 100)) g · \(Int((((r.kcalPer100g ?? 0) * (r.portionGrams ?? 100)) / 100).rounded())) kcal")
                                            .font(.caption).foregroundStyle(.secondary)
                                    }
                                    Spacer()
                                }
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
            .navigationTitle("Per Text erfassen")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Abbrechen") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Hinzufügen") {
                        onAdd(selected.sorted().map { results[$0] }); dismiss()
                    }
                    .disabled(selected.isEmpty)
                }
            }
        }
    }

    private func toggle(_ i: Int) {
        if selected.contains(i) { selected.remove(i) } else { selected.insert(i) }
    }

    private func analyze() {
        let q = text
        loading = true; error = nil
        Task { @MainActor in
            do {
                let res = try await GeminiFoodVision.recognizeText(q)
                results = res
                selected = Set(res.indices)
                if res.isEmpty { error = "Nichts erkannt – Beschreibung anpassen." }
            } catch {
                self.error = "KI-Fehler: \((error as? GeminiFoodVision.VisionError)?.errorDescription ?? error.localizedDescription)"
            }
            loading = false
        }
    }
}
