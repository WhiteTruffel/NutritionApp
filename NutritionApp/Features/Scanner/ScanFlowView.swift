import SwiftUI
import SwiftData
import UIKit

/// Ablauf: scannen → Cache prüfen → Open Food Facts → Erfassungsmaske.
/// Wird kein Treffer gefunden, kann der Nutzer direkt das Nährwert-Etikett fotografieren –
/// die Werte werden per OCR erkannt und vorbefüllt (Barcode bleibt erhalten).
struct ScanFlowView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    let onSave: (FoodEntry) -> Void

    private let off = OpenFoodFactsClient()
    @State private var phase: Phase = .scanning
    @State private var labelSource: PickerSource?
    @State private var pendingLabel: UIImage?
    @State private var activeCode = ""          // Barcode, zu dem gerade ein Etikett fotografiert wird

    enum Phase {
        case scanning
        case loading(String)
        case parsingLabel
        case found(FoodItem)
        case notFound(String)
        case manual(String)                       // unbekannter Barcode → manuell anlegen
        case labelReview(ParsedLabel, String)     // Etikett-OCR-Werte editierbar prüfen
    }

    var body: some View {
        NavigationStack {
            Group {
                switch phase {
                case .scanning:
                    if BarcodeScanner.isSupported {
                        BarcodeScanner { code in handle(code) }
                    } else {
                        ContentUnavailableView("Scanner nicht verfügbar",
                            systemImage: "barcode.viewfinder",
                            description: Text("Auf diesem Gerät nicht möglich – bitte manuell erfassen."))
                    }
                case .loading(let code):
                    ProgressView("Suche \(code) …")
                case .parsingLabel:
                    ProgressView("Etikett wird gelesen …")
                case .found(let food):
                    LogEntryView(scannedFood: food) { entry in
                        onSave(entry); dismiss()
                    }
                case .manual(let code):
                    LogEntryView(scannedFood: nil, presetBarcode: code) { entry in
                        onSave(entry); dismiss()
                    }
                case .labelReview(let parsed, let code):
                    LogEntryView(labelPrefill: parsed, presetBarcode: code) { entry in
                        onSave(entry); dismiss()
                    }
                case .notFound(let code):
                    ContentUnavailableView {
                        Label("Nicht gefunden", systemImage: "barcode.viewfinder")
                    } description: {
                        Text("Barcode \(code) ist in keiner Datenbank. Fotografiere einfach das Nährwert-Etikett – die Werte werden automatisch erkannt. Beim nächsten Scan ist das Produkt sofort da.")
                    } actions: {
                        VStack(spacing: 12) {
                            if UIImagePickerController.isSourceTypeAvailable(.camera) {
                                Button {
                                    activeCode = code; labelSource = .camera
                                } label: {
                                    Label("Etikett fotografieren", systemImage: "text.viewfinder")
                                        .frame(maxWidth: .infinity)
                                }
                                .buttonStyle(.borderedProminent)
                            }
                            Button {
                                activeCode = code; labelSource = .library
                            } label: {
                                Label("Aus Fotos wählen", systemImage: "photo")
                                    .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.bordered)
                            Button("Werte selbst eingeben") { phase = .manual(code) }
                                .padding(.top, 4)
                        }
                        .padding(.horizontal, 24)
                    }
                }
            }
            .navigationTitle("Scannen")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Abbrechen") { dismiss() } }
            }
            .fullScreenCover(item: $labelSource, onDismiss: processPendingLabel) { source in
                ImagePicker(
                    sourceType: source.uiType,
                    onImage: { pendingLabel = $0; labelSource = nil },
                    onCancel: { labelSource = nil }
                )
                .ignoresSafeArea()
            }
        }
    }

    /// Wird nach dem Schließen des Foto-Pickers aufgerufen: OCR auf das Etikett, dann
    /// editierbare Prüf-Maske mit den erkannten Werten (Barcode bleibt erhalten).
    private func processPendingLabel() {
        guard let image = pendingLabel else { return }
        pendingLabel = nil
        guard let data = image.jpegData(compressionQuality: 0.9) else { return }
        let orientation = TextRecognizer.cgOrientation(image.imageOrientation)
        let code = activeCode
        phase = .parsingLabel
        Task { @MainActor in
            let tokens = await TextRecognizer.recognizeTokens(from: data, orientation: orientation)
            var parsed = NutritionLabelParser.parse(tokens)
            if !parsed.hasAny {
                let lines = await TextRecognizer.recognizeLines(from: data, orientation: orientation)
                parsed = NutritionLabelParser.parse(lines)
            }
            // Erkannt → Prüf-Maske mit Werten; nichts erkannt → manuelle Eingabe (Barcode bleibt).
            phase = parsed.hasAny ? .labelReview(parsed, code) : .manual(code)
        }
    }

    private func handle(_ code: String) {
        // 1) Cache zuerst
        let descriptor = FetchDescriptor<FoodItem>(predicate: #Predicate { $0.barcode == code })
        if let cached = try? context.fetch(descriptor).first {
            phase = .found(cached)
            return
        }
        // 2) Netz
        phase = .loading(code)
        Task {
            do {
                let product = try await off.product(barcode: code)
                await MainActor.run {
                    let food = FoodItem(name: product.productName ?? "",
                                        barcode: code, brand: product.brands)
                    food.kcalPer100g    = product.nutriments?.energyKcal100g
                    food.proteinPer100g = product.nutriments?.proteins100g
                    food.carbsPer100g   = product.nutriments?.carbohydrates100g
                    food.fatPer100g     = product.nutriments?.fat100g
                    food.fiberPer100g   = product.nutriments?.fiber100g
                    food.sugarPer100g   = product.nutriments?.sugars100g
                    food.sodiumMgPer100g = product.nutriments?.sodiumMgPer100g
                    food.servingSizeG   = product.servingSizeGrams   // Hersteller-Portion (z. B. 1 Riegel)
                    food.lastFetched = .now
                    context.insert(food)
                    try? context.save()
                    phase = .found(food)
                }
            } catch {
                await MainActor.run { phase = .notFound(code) }
            }
        }
    }
}
