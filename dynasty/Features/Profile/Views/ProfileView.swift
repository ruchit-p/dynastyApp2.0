import SwiftUI
import FirebaseAuth
import FirebaseFirestore

struct ProfileView: View {
    @Binding var showingSignUp: Bool
    @State private var userData: User?
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var authManager: AuthManager
    
    var body: some View {
        NavigationView {
            VStack {
                // Title and user greeting
                HStack {
                    Text("Profile")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                    Spacer()
                    
                    // Avatar with edit option
                    NavigationLink(destination: UserProfileEditView(currentUser: userData ?? .init(id: "", displayName: "", email: "", dateOfBirth: Date(), firstName: "", lastName: "", phoneNumber: "", familyTreeID: "", historyBookID: "", parentIds: [], childrenIds: [], isAdmin: false, canAddMembers: false, canEdit: false, photoURL: "", createdAt: Timestamp(), updatedAt: nil))) {
                        if let photoURL = userData?.photoURL, let url = URL(string: photoURL) {
                            AsyncImage(url: url) { image in
                                image.resizable()
                            } placeholder: {
                                ProgressView()
                            }
                            .frame(width: 60, height: 60)
                            .clipShape(Circle())
                        } else {
                            Image(systemName: "person.circle.fill")
                                .resizable()
                                .frame(width: 60, height: 60)
                        }
                    }
                }
                .padding(.horizontal)
                .padding(.top, 20)
                
                if let userData = userData {
                    Text("Hey, \(userData.displayName)!")
                        .font(.title2)
                        .padding(.top, 10)
                } else {
                    Text("Loading profile...")
                        .font(.title2)
                        .padding(.top, 10)
                }
                
                Spacer()
                
                // Profile options
                VStack(spacing: 20) {
                    // Category buttons
                    NavigationLink(destination: UserProfileEditView(currentUser: userData ?? .init(id: "", displayName: "", email: "", dateOfBirth: Date(), firstName: "", lastName: "", phoneNumber: "", familyTreeID: "", historyBookID: "", parentIds: [], childrenIds: [], isAdmin: false, canAddMembers: false, canEdit: false, photoURL: "", createdAt: Timestamp(), updatedAt: nil))) {
                        ProfileCategoryRow(title: "Personal Information", systemImage: "person")
                    }
                    
                    // ... other buttons ...
                    
                    Button(action: {
                        // Log Out action
                        signOut()
                    }) {
                        Text("Log Out")
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.green)
                            .foregroundColor(.white)
                            .cornerRadius(10)
                    }
                }
                .padding(.horizontal, 40)
                .padding(.bottom, 40)
            }
            .navigationBarHidden(true)
            .onAppear {
                fetchUserData()
            }
        }
    }
    
    // Function to handle sign out
    func signOut() {
        do {
            try Auth.auth().signOut()
        } catch {
            // Handle sign out error
            print("Error signing out: \(error.localizedDescription)")
        }
    }
    
    private func fetchUserData() {
        guard let currentUser = Auth.auth().currentUser else { return }

        let db = Firestore.firestore()
        let docRef = db.collection("users").document(currentUser.uid)
        docRef.getDocument { document, error in
            if let document = document, document.exists {
                do {
                    let user = try document.data(as: User.self)
                    DispatchQueue.main.async {
                        self.userData = user
                    }
                } catch {
                    print("Error decoding user data: \(error.localizedDescription)")
                }
            } else {
                print("User document does not exist.")
            }
        }
    }
}

// Helper view for category rows
struct ProfileCategoryRow: View {
    var title: String
    var systemImage: String

    var body: some View {
        HStack {
            Image(systemName: systemImage)
                .font(.headline)
            Text(title)
                .font(.headline)
            Spacer()
            Image(systemName: "chevron.right")
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(10)
    }
}

#Preview {
    ProfileView(showingSignUp: .constant(false))
} 
