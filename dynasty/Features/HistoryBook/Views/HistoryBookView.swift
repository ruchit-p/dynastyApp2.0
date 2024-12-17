import SwiftUI
import FirebaseFirestore
import FirebaseAuth

struct HistoryBookView: View {
    @StateObject private var viewModel = HistoryBookViewModel()
    @State private var historyBook: HistoryBook?
    @State private var showAddStoryView = false
    @State private var user: User?
    @Environment(\.scenePhase) private var scenePhase
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack {
                    // Title and story count
                    HStack {
                        Text("History Book")
                            .font(.largeTitle)
                            .fontWeight(.bold)
                        Spacer()
                        Text("\(viewModel.stories.count) Stories")
                            .font(.subheadline)
                            .foregroundColor(.gray)
                    }
                    .padding(.horizontal)
                    .padding(.top, 20)
                    
                    // Offline indicator
                    if viewModel.isOffline {
                        HStack {
                            Image(systemName: "wifi.slash")
                            Text("Offline Mode")
                            Spacer()
                            Button("Sync") {
                                Task {
                                    await viewModel.syncPendingChanges()
                                    await fetchHistoryBook()
                                }
                            }
                        }
                        .padding()
                        .background(Color.yellow.opacity(0.2))
                        .cornerRadius(8)
                        .padding(.horizontal)
                    }
                    
                    if viewModel.isLoading {
                        ProgressView("Loading stories...")
                            .padding()
                    } else if let error = viewModel.error {
                        VStack {
                            Text(error.localizedDescription)
                                .font(.headline)
                                .foregroundColor(.red)
                                .padding()
                            
                            Button("Try Again") {
                                fetchHistoryBook()
                            }
                            .buttonStyle(.bordered)
                        }
                    } else if viewModel.stories.isEmpty {
                        Text("Add your first story by clicking the add button!")
                            .font(.headline)
                            .foregroundColor(.gray)
                            .padding()
                    } else {
                        // Grid of stories
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 20) {
                                ForEach(viewModel.stories) { story in
                                    NavigationLink(destination: StoryDetailView(story: story, historyBookId: historyBook?.id ?? "")) {
                                        VStack {
                                            if let coverImageURL = story.coverImageURL, let url = URL(string: coverImageURL) {
                                                AsyncImage(url: url) { image in
                                                    image
                                                        .resizable()
                                                        .aspectRatio(contentMode: .fill)
                                                } placeholder: {
                                                    ProgressView()
                                                }
                                                .frame(width: 100, height: 100)
                                                .clipped()
                                                .cornerRadius(10)
                                            } else {
                                                Image("defaultImage")
                                                    .resizable()
                                                    .aspectRatio(contentMode: .fill)
                                                    .frame(width: 100, height: 100)
                                                    .clipped()
                                                    .cornerRadius(10)
                                            }

                                            Text(story.title)
                                                .font(.caption)
                                                .lineLimit(1)
                                        }
                                    }
                                }
                            }
                            .padding()
                        }
                    }
                    
                    Spacer()
                }
            }
            .refreshable {
                fetchHistoryBook()
            }
            .navigationBarTitleDisplayMode(.inline)
            .onAppear {
                fetchHistoryBook()
            }
            .onChange(of: showAddStoryView) { oldValue, newValue in
                if !newValue {
                    if let historyBookID = historyBook?.id {
                        Task {
                            guard let currentUser = Auth.auth().currentUser else { return }
                            await viewModel.fetchStories(familyTreeID: historyBookID, currentUserId: currentUser.uid)
                        }
                    }
                }
            }
            .onChange(of: scenePhase) { oldPhase, newPhase in
                if newPhase == .active {
                    // Try to sync when app becomes active
                    Task {
                        await viewModel.syncPendingChanges()
                        await fetchHistoryBook()
                    }
                }
            }
            .sheet(isPresented: $showAddStoryView) {
                if let historyBookID = historyBook?.id {
                    AddStoryView(historyBookID: historyBookID, familyTreeID: historyBook?.familyTreeID ?? "")
                } else {
                    Text("Unable to add a story. History book ID is missing.")
                        .font(.headline)
                        .foregroundColor(.red)
                        .padding()
                }
            }
        }
        .withPlusButton {
            showAddStoryView = true
        }
    }
    
    private func fetchHistoryBook() {
        guard let currentUser = Auth.auth().currentUser else {
            viewModel.error = NSError(domain: "HistoryBook", code: 1, userInfo: [NSLocalizedDescriptionKey: "Please log in to view your history book."])
            return
        }
        
        let db = FirestoreManager.shared.getDB()
        let historyBookRef = db.collection("historyBooks").document(currentUser.uid)
        
        Task {
            do {
                let document = try await historyBookRef.getDocument()
                if document.exists {
                    if let fetchedHistoryBook = try? document.data(as: HistoryBook.self) {
                        await MainActor.run {
                            self.historyBook = fetchedHistoryBook
                        }
                        if let historyBookID = fetchedHistoryBook.id {
                            await viewModel.fetchStories(familyTreeID: historyBookID, currentUserId: currentUser.uid)
                        }
                    }
                } else {
                    // History book doesn't exist, create a new one
                    await createNewHistoryBook(for: currentUser)
                }
            } catch {
                await MainActor.run {
                    viewModel.error = error
                }
            }
        }
    }
    
    private func createNewHistoryBook(for firebaseUser: FirebaseAuth.User) async {
        let db = FirestoreManager.shared.getDB()
        
        do {
            let document = try await db.collection("users").document(firebaseUser.uid).getDocument()
            if let dynastyUser = try? document.data(as: User.self),
               let userId = dynastyUser.id,
               let familyTreeID = dynastyUser.familyTreeID {
                
                let newHistoryBook = HistoryBook(ownerUserID: userId,
                                               familyTreeID: familyTreeID)
                
                try await db.collection("historyBooks").document(userId).setData(from: newHistoryBook)
                
                await MainActor.run {
                    self.historyBook = newHistoryBook
                }
            }
        } catch {
            await MainActor.run {
                viewModel.error = error
            }
        }
    }
}

#Preview {
    HistoryBookView()
} 
