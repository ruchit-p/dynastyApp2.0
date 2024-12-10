import SwiftUI
import QuickLook

// A simple QLPreviewItem wrapper
class QLPreviewItemWrapper: NSObject, QLPreviewItem {
    var previewItemURL: URL?
    var previewItemTitle: String?

    init(url: URL, title: String) {
        self.previewItemURL = url
        self.previewItemTitle = title
    }
}

// The SwiftUI view that shows a file preview with action buttons
struct FilePreviewView: UIViewControllerRepresentable {
    let fileURL: URL
    let fileName: String
    @Binding var isPresented: Bool
    
    // Callbacks for toolbar actions
    var onShare: () -> Void
    var onDownload: () -> Void
    var onDelete: () -> Void
    var onRename: () -> Void
    
    func makeUIViewController(context: Context) -> UINavigationController {
        let previewController = QLPreviewController()
        previewController.dataSource = context.coordinator
        
        // Create toolbar items
        let shareItem = UIBarButtonItem(
            title: "Share",
            style: .plain,
            target: context.coordinator,
            action: #selector(Coordinator.shareTapped)
        )
        let downloadItem = UIBarButtonItem(
            title: "Download",
            style: .plain,
            target: context.coordinator,
            action: #selector(Coordinator.downloadTapped)
        )
        let deleteItem = UIBarButtonItem(
            title: "Delete",
            style: .plain,
            target: context.coordinator,
            action: #selector(Coordinator.deleteTapped)
        )
        deleteItem.tintColor = .red // Set tint color to red for destructive action
        
        let renameItem = UIBarButtonItem(
            title: "Rename",
            style: .plain,
            target: context.coordinator,
            action: #selector(Coordinator.renameTapped)
        )
        
        previewController.navigationItem.rightBarButtonItems = [shareItem, downloadItem, deleteItem, renameItem]
        previewController.navigationItem.title = fileName
        
        // Embed in a navigation controller
        let navController = UINavigationController(rootViewController: previewController)
        navController.navigationBar.prefersLargeTitles = false
        
        // Add a Done button to close the preview
        let doneItem = UIBarButtonItem(
            title: "Done",
            style: .done,
            target: context.coordinator,
            action: #selector(Coordinator.doneTapped)
        )
        previewController.navigationItem.leftBarButtonItem = doneItem
        
        return navController
    }
    
    func updateUIViewController(_ uiViewController: UINavigationController, context: Context) {
        // No need to update the view controller on state changes
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, QLPreviewControllerDataSource {
        let parent: FilePreviewView
        
        init(_ parent: FilePreviewView) {
            self.parent = parent
        }
        
        @objc func shareTapped() {
            parent.onShare()
        }
        
        @objc func downloadTapped() {
            parent.onDownload()
        }
        
        @objc func deleteTapped() {
            parent.onDelete()
        }
        
        @objc func renameTapped() {
            parent.onRename()
        }
        
        @objc func doneTapped() {
            parent.isPresented = false
        }
        
        func numberOfPreviewItems(in controller: QLPreviewController) -> Int {
            return 1
        }
        
        func previewController(_ controller: QLPreviewController, previewItemAt index: Int) -> QLPreviewItem {
            return QLPreviewItemWrapper(url: parent.fileURL, title: parent.fileName)
        }
    }
} 