import SwiftUI
import FirebaseFirestore
import FirebaseAuth

struct HistoryBookView: View {
    @State private var historyBook: HistoryBook?
    @State private var stories: [Story] = []
    @State private var isLoading: Bool = true
    @State private var errorMessage: String? = nil
    @State private var showAddStoryView = false
    @State private var user: User?

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
                        Text("\(stories.count) Stories")
                            .font(.subheadline)
                            .foregroundColor(.gray)
                    }
                    .padding(.horizontal)
                    .padding(.top, 20)
                    
                    if isLoading {
                        ProgressView("Loading stories...")
                            .padding()
                    } else if let errorMessage = errorMessage {
                        Text(errorMessage)
                            .font(.headline)
                            .foregroundColor(.red)
                            .padding()
                    } else if stories.isEmpty {
                        Text("Add your first story by clicking the add button!")
                            .font(.headline)
                            .foregroundColor(.gray)
                            .padding()
                    } else {
                        // Grid of stories
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 20) {
                                ForEach(stories) { story in
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
                        fetchStories(historyBookID: historyBookID)
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
        isLoading = true
        errorMessage = nil
        
        guard let currentUser = Auth.auth().currentUser else {
            print("No authenticated user found.")
            self.errorMessage = "Please log in to view your history book."
            self.isLoading = false
            return
        }
        
        let db = Firestore.firestore()
        let historyBookRef = db.collection("historyBooks").document(currentUser.uid)
        
        historyBookRef.getDocument { document, error in
            if let error = error {
                print("Error fetching history book: \(error.localizedDescription)")
                DispatchQueue.main.async {
                    self.errorMessage = "Failed to load history book. Please try again."
                    self.isLoading = false
                }
            } else if let document = document, document.exists {
                do {
                    let fetchedHistoryBook = try document.data(as: HistoryBook.self)
                    self.historyBook = fetchedHistoryBook
                    if let historyBookID = fetchedHistoryBook.id {
                        self.fetchStories(historyBookID: historyBookID)
                    } else {
                        DispatchQueue.main.async {
                            self.errorMessage = "History book ID is missing."
                            self.isLoading = false
                        }
                    }
                } catch {
                    print("Error decoding history book: \(error.localizedDescription)")
                    DispatchQueue.main.async {
                        self.errorMessage = "Failed to parse history book data."
                        self.isLoading = false
                    }
                }
            } else {
                // History book doesn't exist, create a new one
                self.createNewHistoryBook(for: currentUser)
            }
        }
    }
    
    private func createNewHistoryBook(for firebaseUser: FirebaseAuth.User) {
        let db = Firestore.firestore()
        db.collection("users").document(firebaseUser.uid).getDocument { document, error in
            if let error = error {
                print("Error fetching user data: \(error.localizedDescription)")
                DispatchQueue.main.async {
                    self.errorMessage = "Failed to fetch user data. Please try again."
                    self.isLoading = false
                }
                return
            }
            
            if let document = document, document.exists {
                do {
                    let dynastyUser = try document.data(as: User.self)
                    guard let userId = dynastyUser.id,
                          let familyTreeID = dynastyUser.familyTreeID else {
                        DispatchQueue.main.async {
                            self.errorMessage = "Invalid user data"
                            self.isLoading = false
                        }
                        return
                    }
                    
                    let newHistoryBook = HistoryBook(ownerUserID: userId,
                                                     familyTreeID: familyTreeID)
                    
                    try db.collection("historyBooks").document(userId).setData(from: newHistoryBook) { error in
                        if let error = error {
                            print("Error creating new history book: \(error.localizedDescription)")
                            DispatchQueue.main.async {
                                self.errorMessage = "Failed to create new history book. Please try again."
                                self.isLoading = false
                            }
                        } else {
                            self.historyBook = newHistoryBook
                            DispatchQueue.main.async {
                                self.isLoading = false
                            }
                        }
                    }
                } catch {
                    print("Error decoding user data: \(error.localizedDescription)")
                    DispatchQueue.main.async {
                        self.errorMessage = "Failed to process user data"
                        self.isLoading = false
                    }
                }
            } else {
                DispatchQueue.main.async {
                    self.errorMessage = "User data not found"
                    self.isLoading = false
                }
            }
        }
    }
    
    private func fetchStories(historyBookID: String) {
        isLoading = true
        errorMessage = nil
        
        let db = Firestore.firestore()
        db.collection("historyBooks").document(historyBookID).collection("stories")
            .order(by: "createdAt", descending: true)
            .getDocuments { snapshot, error in
                if let error = error {
                    print("Error fetching stories: \(error.localizedDescription)")
                    DispatchQueue.main.async {
                        self.errorMessage = "Failed to load stories. Please try again."
                        self.isLoading = false
                    }
                } else {
                    do {
                        self.stories = try snapshot?.documents.compactMap {
                            try $0.data(as: Story.self)
                        } ?? []
                        DispatchQueue.main.async {
                            self.isLoading = false
                        }
                    } catch {
                        print("Error decoding stories: \(error.localizedDescription)")
                        DispatchQueue.main.async {
                            self.errorMessage = "Failed to parse stories."
                            self.isLoading = false
                        }
                    }
                }
            }
    }
}

#Preview {
    HistoryBookView()
} 
