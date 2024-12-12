import SwiftUI
import PhotosUI
import OSLog

struct MediaPicker: UIViewControllerRepresentable {
    @Binding var mediaType: PHPickerFilter
    @Binding var selectedMediaURL: URL?
    private let logger = Logger(subsystem: "com.yourapp.MediaPicker", category: "MediaPicker")

    func makeUIViewController(context: Context) -> PHPickerViewController {
        var config = PHPickerConfiguration()
        config.filter = mediaType
        config.selectionLimit = 1
        let picker = PHPickerViewController(configuration: config)
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: PHPickerViewController, context: Context) {
        // No updates needed
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, PHPickerViewControllerDelegate {
        let parent: MediaPicker

        init(_ parent: MediaPicker) {
            self.parent = parent
        }

        func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
            picker.dismiss(animated: true)

            guard let provider = results.first?.itemProvider else { return }

            if provider.hasItemConformingToTypeIdentifier(UTType.movie.identifier) {
                provider.loadFileRepresentation(forTypeIdentifier: UTType.movie.identifier) { [weak self] url, error in
                    self?.handleMediaSelection(url: url, error: error)
                }
            } else if provider.hasItemConformingToTypeIdentifier(UTType.image.identifier) {
                provider.loadFileRepresentation(forTypeIdentifier: UTType.image.identifier) { [weak self] url, error in
                    self?.handleMediaSelection(url: url, error: error)
                }
            } else if provider.hasItemConformingToTypeIdentifier(UTType.audio.identifier) {
                provider.loadFileRepresentation(forTypeIdentifier: UTType.audio.identifier) { [weak self] url, error in
                    self?.handleMediaSelection(url: url, error: error)
                }
            }
        }

        private func handleMediaSelection(url: URL?, error: Error?) {
            if let error = error {
                parent.logger.error("Error loading media: \(error.localizedDescription)")
                return
            }

            guard let url = url else {
                parent.logger.error("Failed to get URL for selected media")
                return
            }

            DispatchQueue.main.async {
                self.parent.selectedMediaURL = url
            }
        }
    }
}
