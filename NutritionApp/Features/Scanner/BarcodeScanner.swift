import SwiftUI
import VisionKit
import Vision   // VNBarcodeSymbology (.ean13/.ean8/.upce) stammt aus dem Vision-Framework

/// VisionKit-Scanner in SwiftUI. Nur auf echtem Gerät mit Kamera (A12+, iOS 16+).
struct BarcodeScanner: UIViewControllerRepresentable {
    var onScan: (String) -> Void

    static var isSupported: Bool {
        DataScannerViewController.isSupported && DataScannerViewController.isAvailable
    }

    func makeUIViewController(context: Context) -> DataScannerViewController {
        let vc = DataScannerViewController(
            recognizedDataTypes: [.barcode(symbologies: [.ean13, .ean8, .upce])],
            qualityLevel: .balanced,
            recognizesMultipleItems: false,
            isHighFrameRateTrackingEnabled: false,
            isHighlightingEnabled: true
        )
        vc.delegate = context.coordinator
        return vc
    }

    func updateUIViewController(_ vc: DataScannerViewController, context: Context) {
        try? vc.startScanning()
    }

    func makeCoordinator() -> Coordinator { Coordinator(onScan: onScan) }

    final class Coordinator: NSObject, DataScannerViewControllerDelegate {
        let onScan: (String) -> Void
        private var didScan = false
        init(onScan: @escaping (String) -> Void) { self.onScan = onScan }

        func dataScanner(_ scanner: DataScannerViewController,
                         didAdd addedItems: [RecognizedItem],
                         allItems: [RecognizedItem]) {
            guard !didScan else { return }
            for case let .barcode(barcode) in addedItems {
                if let code = barcode.payloadStringValue {
                    didScan = true               // nur ein Treffer
                    scanner.stopScanning()
                    onScan(code)
                    break
                }
            }
        }
    }
}
