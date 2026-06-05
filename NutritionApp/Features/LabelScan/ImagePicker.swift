import SwiftUI
import UIKit

/// SwiftUI-Wrapper um UIImagePickerController – unterstützt Kamera (Gerät) und
/// Fotomediathek (auch im Simulator testbar).
///
/// WICHTIG: Der Picker schließt sich NICHT selbst (kein `picker.dismiss()`).
/// Stattdessen meldet er Ergebnis/Abbruch an die Eltern-View, die das Binding
/// auf nil setzt. So wird die Präsentation ausschließlich von SwiftUI gesteuert –
/// nur dann feuert `onDismiss` zuverlässig (sonst geht das Ereignis verloren und
/// die nachgelagerte Verarbeitung läuft nie).
struct ImagePicker: UIViewControllerRepresentable {
    let sourceType: UIImagePickerController.SourceType
    let onImage: (UIImage) -> Void
    let onCancel: () -> Void

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = UIImagePickerController.isSourceTypeAvailable(sourceType) ? sourceType : .photoLibrary
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator(onImage: onImage, onCancel: onCancel) }

    final class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let onImage: (UIImage) -> Void
        let onCancel: () -> Void
        init(onImage: @escaping (UIImage) -> Void, onCancel: @escaping () -> Void) {
            self.onImage = onImage
            self.onCancel = onCancel
        }

        func imagePickerController(_ picker: UIImagePickerController,
                                   didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            if let image = info[.originalImage] as? UIImage {
                onImage(image)            // Eltern-View setzt Binding=nil → SwiftUI schließt → onDismiss feuert
            } else {
                onCancel()
            }
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            onCancel()
        }
    }
}

/// Identifizierbare Bildquelle für `.sheet(item:)` bzw. `.fullScreenCover(item:)`.
enum PickerSource: Identifiable {
    case camera, library
    var id: Int { hashValue }
    var uiType: UIImagePickerController.SourceType { self == .camera ? .camera : .photoLibrary }
}
