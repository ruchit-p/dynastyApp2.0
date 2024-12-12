import SwiftUI
import FirebaseFirestore
import FirebaseAuth
import FirebaseStorage
import PhotosUI

struct AppError: Identifiable {
    let id = UUID()
    let message: String
}

struct AddStoryView: View {
    @StateObject private var viewModel = AddStoryViewModel()
    @State private var title: String = ""
    @State private var content: String = ""
    @State private var privacy: Story.PrivacyLevel = .familyPublic
    @Environment(\.dismiss) private var dismiss
    @State private var selectedDate = Date()
    @State private var selectedImages: [UIImage] = []
    @State private var showImagePicker = false
    @State private var selectedItems: [PhotosPickerItem] = []
    @State private var contentElements: [ContentElement] = [
        ContentElement(id: UUID().uuidString, type: .text, value: "") // Start with an empty text element
    ]
    
    var historyBookID: String
    var familyTreeID: String
    
    var body: some View {
        NavigationView {
            Form {
                Section {
                    TextField("Title", text: $title)
                    
                    // Display selected media (you might want a more sophisticated preview)
                    ForEach(contentElements.filter { $0.type != .text }) { element in
                        ContentElementView(element: element)
                    }
                }
                
                Section {
                    Picker("Privacy", selection: $privacy) {
                        ForEach(Story.PrivacyLevel.allCases, id: \.self) { level in
                            Text(level.rawValue).tag(level)
                        }
                    }
                }
                
                // Text Input
                Section(header: Text("Story Content")) {
                    RichTextEditorView(contentElements: $contentElements)
                        .frame(minHeight: 200)
                }
            }
            .navigationBarTitle("Add Story", displayMode: .inline)
            .navigationBarItems(
                leading: Button("Cancel") {
                    dismiss()
                },
                trailing: Button("Add") {
                    addStory()
                }
                .disabled(viewModel.isLoading || !viewModel.validateStory(title: title, content: content))
            )
        }
    }
    
    private func addStory() {
        guard let currentUser = Auth.auth().currentUser else { return }
        
        // Convert contentElements to JSON string
        let contentJSON = convertContentElementsToJSON(contentElements)

        Task {
            do {
                try await viewModel.createStory(
                    title: title,
                    content: contentJSON, // Pass the JSON string here
                    privacy: privacy.rawValue,
                    familyTreeId: familyTreeID,
                    creatorUserId: currentUser.uid
                )
                await MainActor.run {
                    dismiss()
                }
            } catch {
                // Error is handled by ViewModel
                print("Failed to create story: \(error.localizedDescription)")
            }
        }
    }

    // Helper function to convert contentElements to JSON
    private func convertContentElementsToJSON(_ elements: [ContentElement]) -> String {
        let content = ["elements": elements]
        do {
            let jsonData = try JSONEncoder().encode(content)
            if let jsonString = String(data: jsonData, encoding: .utf8) {
                return jsonString
            } else {
                return ""
            }
        } catch {
            print("Error converting content elements to JSON: \(error)")
            return ""
        }
    }
} 
