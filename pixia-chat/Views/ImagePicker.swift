import SwiftUI
import PhotosUI
import UniformTypeIdentifiers
import UIKit

struct ImagePicker: UIViewControllerRepresentable {
    @Binding var image: UIImage?
    @Binding var imageData: Data?
    @Binding var mimeType: String?

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    func makeUIViewController(context: Context) -> PHPickerViewController {
        var config = PHPickerConfiguration()
        config.filter = .images
        config.selectionLimit = 1
        let picker = PHPickerViewController(configuration: config)
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: PHPickerViewController, context: Context) {
    }

    final class Coordinator: NSObject, PHPickerViewControllerDelegate {
        private let parent: ImagePicker

        init(parent: ImagePicker) {
            self.parent = parent
        }

        func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
            picker.dismiss(animated: true)
            guard let result = results.first else { return }
            let provider = result.itemProvider

            if provider.canLoadObject(ofClass: UIImage.self) {
                provider.loadObject(ofClass: UIImage.self) { [weak self] object, _ in
                    guard let self, let image = object as? UIImage else { return }
                    DispatchQueue.main.async {
                        self.parent.image = image
                    }
                }
            }

            if provider.hasItemConformingToTypeIdentifier(UTType.png.identifier) {
                provider.loadDataRepresentation(forTypeIdentifier: UTType.png.identifier) { [weak self] data, _ in
                    guard let self else { return }
                    DispatchQueue.main.async {
                        self.parent.imageData = data
                        self.parent.mimeType = "image/png"
                    }
                }
            } else if provider.hasItemConformingToTypeIdentifier(UTType.jpeg.identifier) {
                provider.loadDataRepresentation(forTypeIdentifier: UTType.jpeg.identifier) { [weak self] data, _ in
                    guard let self else { return }
                    DispatchQueue.main.async {
                        self.parent.imageData = data
                        self.parent.mimeType = "image/jpeg"
                    }
                }
            } else if provider.hasItemConformingToTypeIdentifier(UTType.image.identifier) {
                provider.loadDataRepresentation(forTypeIdentifier: UTType.image.identifier) { [weak self] data, _ in
                    guard let self else { return }
                    DispatchQueue.main.async {
                        self.parent.imageData = data
                        self.parent.mimeType = "image/jpeg"
                    }
                }
            }
        }
    }
}
