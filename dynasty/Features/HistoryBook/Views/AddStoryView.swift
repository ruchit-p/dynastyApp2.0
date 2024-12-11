import SwiftUI
import FirebaseFirestore
import FirebaseAuth
import FirebaseStorage

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
    
    var historyBookID: String
    var familyTreeID: String
    
    var body: some View {
        NavigationView {
            VStack {
                // Cover Image Selection
                Button(action: {
                    showImagePicker = true
                }) {
                    if let image = selectedImages.first {
                        Image(uiImage: image)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(height: 200)
                            .clipped()
                    } else {
                        ZStack {
                            Rectangle()
                                .fill(Color.gray.opacity(0.3))
                                .frame(height: 200)
                            Text("Tap to select a cover image")
                                .foregroundColor(.gray)
                        }
                    }
                }
                .sheet(isPresented: $showImagePicker) {
                    ImagePicker(selectedImage: Binding(
                        get: { selectedImages.first },
                        set: { if let image = $0 { selectedImages = [image] } }
                    ))
                }
                
                // Title
                TextField("Title", text: $title)
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(8)
                    .padding(.horizontal)
                
                // Content (Markdown Editor)
                MarkdownTextView(text: $content, placeholder: "Write your story here...")
                    .frame(height: 200)
                    .padding(.horizontal)
                
                // Privacy Picker
                Picker("Privacy", selection: $privacy) {
                    Text("Public").tag(Story.PrivacyLevel.familyPublic)
                    Text("Private").tag(Story.PrivacyLevel.privateAccess)
                }
                .pickerStyle(SegmentedPickerStyle())
                .padding()
                
                if viewModel.isLoading {
                    VStack {
                        ProgressView("Uploading...")
                        Text("\(Int(viewModel.uploadProgress * 100))%")
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color.black.opacity(0.3))
                }
                
                if let error = viewModel.error {
                    Text(error.localizedDescription)
                        .foregroundColor(.red)
                        .padding()
                }
                
                Spacer()
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
        
        Task {
            do {
                try await viewModel.createStory(
                    title: title,
                    content: content,
                    images: selectedImages,
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
} 
