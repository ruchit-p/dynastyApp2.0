import SwiftUI
import FirebaseFirestore
import FirebaseAuth

struct FeedView: View {
    @StateObject private var viewModel = FeedViewModel()
    @State private var showingAddPost = false
    
    var body: some View {
        NavigationView {
            ZStack {
                ScrollView {
                    LazyVStack(spacing: 20) {
                        ForEach(viewModel.posts) { post in
                            PostCard(post: post)
                        }
                    }
                    .padding(.horizontal)
                }
                
                if viewModel.isLoading {
                    ProgressView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(Color.black.opacity(0.3))
                }
                
                if let error = viewModel.error {
                    Text("Error: \(error.localizedDescription)")
                        .foregroundColor(.red)
                        .padding()
                }
            }
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("Feed")
                        .font(.title)
                        .fontWeight(.bold)
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { showingAddPost = true }) {
                        Image(systemName: "plus")
                            .foregroundColor(.primary)
                    }
                }
            }
            .sheet(isPresented: $showingAddPost) {
                AddPostView(viewModel: viewModel)
            }
        }
        .onAppear {
            viewModel.loadPosts()
        }
        .refreshable {
            viewModel.loadPosts()
        }
    }
}

struct AddPostView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var viewModel: FeedViewModel
    @State private var caption = ""
    @State private var selectedImage: UIImage?
    @State private var showingImagePicker = false
    
    var body: some View {
        NavigationView {
            Form {
                Section {
                    TextField("Write something...", text: $caption, axis: .vertical)
                        .lineLimit(5...10)
                    
                    Button(action: { showingImagePicker = true }) {
                        HStack {
                            Image(systemName: "photo")
                            Text("Add Photo")
                        }
                    }
                    
                    if let image = selectedImage {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFit()
                            .frame(height: 200)
                    }
                }
            }
            .navigationTitle("New Post")
            .navigationBarItems(
                leading: Button("Cancel") { dismiss() },
                trailing: Button("Post") { createPost() }
            )
            .sheet(isPresented: $showingImagePicker) {
                ImagePicker(selectedImage: $selectedImage)
            }
        }
    }
    
    private func createPost() {
        Task {
            guard let currentUser = Auth.auth().currentUser else { return }
            
            let post = Post(
                username: currentUser.displayName ?? "Anonymous",
                date: Timestamp(date: Date()),
                caption: caption,
                imageURL: nil, // You'll need to upload the image first and get URL
                timestamp: Timestamp(date: Date())
            )
            
            do {
                try await viewModel.addPost(post: post)
                dismiss()
            } catch {
                // Handle error
                print("Error creating post: \(error.localizedDescription)")
            }
        }
    }
}

#Preview {
    FeedView()
}
