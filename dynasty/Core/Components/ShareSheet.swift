import SwiftUI

struct ShareSheet: UIViewControllerRepresentable {
    let activityItems: [Any]
    let applicationActivities: [UIActivity]?
    let completion: UIActivityViewController.CompletionWithItemsHandler?
    
    init(
        activityItems: [Any],
        applicationActivities: [UIActivity]? = nil,
        completion: UIActivityViewController.CompletionWithItemsHandler? = nil
    ) {
        self.activityItems = activityItems
        self.applicationActivities = applicationActivities
        self.completion = completion
    }
    
    func makeUIViewController(context: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(
            activityItems: activityItems,
            applicationActivities: applicationActivities
        )
        controller.completionWithItemsHandler = completion
        return controller
    }
    
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
} 