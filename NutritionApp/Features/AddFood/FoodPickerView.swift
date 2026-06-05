import SwiftUI

/// Auswahl-Liste für KI-erkannte Lebensmittel (BL12, auch für Multi-Foto): antippen,
/// um zu übernehmen; „Hinzufügen" loggt die ausgewählten Komponenten.
struct FoodPickerView: View {
    @Environment(\.dismiss) private var dismiss
    let title: String
    let results: [GeminiFoodResult]
    let onAdd: ([GeminiFoodResult]) -> Void

    @State private var selected: Set<Int>

    init(title: String, results: [GeminiFoodResult], onAdd: @escaping ([GeminiFoodResult]) -> Void) {
        self.title = title
        self.results = results
        self.onAdd = onAdd
        _selected = State(initialValue: Set(results.indices))
    }

    var body: some View {
        NavigationStack {
            Form {
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
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Abbrechen") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Hinzufügen") { onAdd(selected.sorted().map { results[$0] }); dismiss() }
                        .disabled(selected.isEmpty)
                }
            }
        }
    }

    private func toggle(_ i: Int) {
        if selected.contains(i) { selected.remove(i) } else { selected.insert(i) }
    }
}
