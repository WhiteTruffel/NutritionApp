import SwiftUI

/// „Körper"-Reiter: fasst Erholung (Schlaf, Belastung, Trainings) und den Gewichtsverlauf
/// in einem Tab zusammen – umgeschaltet per Segment-Control. Hält die Tab-Leiste bei
/// fünf direkten Reitern, ohne ein „Mehr"-Menü zu erzeugen.
struct BodyView: View {
    enum Segment: String, CaseIterable, Identifiable {
        case erholung = "Erholung"
        case hrv = "HRV"
        case gewicht = "Gewicht"
        var id: String { rawValue }
    }

    @State private var segment: Segment = .erholung

    var body: some View {
        NavigationStack {
            Group {
                switch segment {
                case .erholung: RecoveryDetailView()
                case .hrv:      HRVMeasurementView()
                case .gewicht:  WeightProgressView()
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Picker("Ansicht", selection: $segment) {
                        ForEach(Segment.allCases) { Text($0.rawValue).tag($0) }
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 220)
                }
            }
        }
    }
}
