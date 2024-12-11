import SwiftUI
import FirebaseAuth
import FirebaseFirestore

struct ProfileView: View {
    @Binding var showingSignUp: Bool
    @StateObject private var viewModel = ProfileViewModel()
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
                    if let user = viewModel.user {
                        NavigationLink(destination: UserProfileEditView(currentUser: user)) {
                            if let photoURL = user.photoURL, let url = URL(string: photoURL) {
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
                }
                .padding(.horizontal)
                .padding(.top, 20)
                
                if let user = viewModel.user {
                    Text("Hey, \(user.displayName)!")
                        .font(.title2)
                        .padding(.top, 10)
                } else if viewModel.isLoading {
                    ProgressView()
                        .padding(.top, 10)
                } else {
                    Text("Loading profile...")
                        .font(.title2)
                        .padding(.top, 10)
                }
                
                if let error = viewModel.error {
                    Text("Error: \(error.localizedDescription)")
                        .foregroundColor(.red)
                        .padding()
                }
                
                Spacer()
                
                // Profile options
                VStack(spacing: 20) {
                    if let user = viewModel.user {
                        NavigationLink(destination: UserProfileEditView(currentUser: user)) {
                            ProfileCategoryRow(title: "Personal Information", systemImage: "person")
                        }
                    }
                    
                    // ... existing buttons ...
                    
                    Button(action: signOut) {
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
                if let userId = Auth.auth().currentUser?.uid {
                    Task {
                        await viewModel.fetchUserProfile(userId: userId)
                    }
                }
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
