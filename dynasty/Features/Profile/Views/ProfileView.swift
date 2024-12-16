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
            ScrollView {
                VStack(spacing: 24) {
                    // Profile Header
                    VStack(spacing: 16) {
                        if let user = viewModel.user {
                            if let photoURL = user.photoURL, let url = URL(string: photoURL) {
                                AsyncImage(url: url) { image in
                                    image.resizable()
                                } placeholder: {
                                    ProgressView()
                                }
                                .aspectRatio(contentMode: .fit)
                                .frame(width: 100, height: 100)
                                .clipShape(Circle())
                            } else {
                                Image(systemName: "person.circle.fill")
                                    .resizable()
                                    .aspectRatio(contentMode: .fit)
                                    .frame(width: 100, height: 100)
                                    .foregroundColor(.blue)
                            }
                            
                            Text("Hey, \(user.displayName)!")
                                .font(.title)
                                .fontWeight(.semibold)
                        } else {
                            Image(systemName: "person.circle.fill")
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(width: 100, height: 100)
                                .foregroundColor(.blue)
                            
                            if viewModel.isLoading {
                                ProgressView()
                            } else {
                                Text("Loading profile...")
                            }
                        }
                    }
                    .padding(.vertical, 32)
                    
                    if let error = viewModel.error {
                        Text(error.localizedDescription)
                            .foregroundColor(.red)
                            .padding()
                    }
                    
                    // Settings Categories
                    VStack(spacing: 8) {
                        if let user = viewModel.user {
                            NavigationLink(destination: UserProfileEditView(currentUser: user)) {
                                SettingsRow(icon: "person.fill", title: "Personal Information", color: .blue)
                            }
                        }
                        
                        NavigationLink(destination: NotificationSettingsView()) {
                            SettingsRow(icon: "bell.fill", title: "Notifications", color: .red)
                        }
                        
                        NavigationLink(destination: PrivacySecurityDetailView()) {
                            SettingsRow(icon: "lock.fill", title: "Privacy & Security", color: .purple)
                        }
                        
                        NavigationLink(destination: AppearanceSettingsView()) {
                            SettingsRow(icon: "paintbrush.fill", title: "Appearance", color: .orange)
                        }
                        
                        NavigationLink(destination: HelpAndSupportView()) {
                            SettingsRow(icon: "questionmark.circle.fill", title: "Help & Support", color: .green)
                        }
                    }
                    .background(Color(.systemBackground))
                    .cornerRadius(15)
                    .shadow(radius: 2)
                    
                    // Log Out Button
                    Button(action: signOut) {
                        Text("Log Out")
                            .font(.headline)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.green)
                            .cornerRadius(15)
                    }
                }
                .padding()
            }
            .navigationTitle("Profile")
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
    
    func signOut() {
        do {
            try Auth.auth().signOut()
        } catch {
            print("Error signing out: \(error.localizedDescription)")
        }
    }
}

struct SettingsRow: View {
    let icon: String
    let title: String
    let color: Color
    
    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(color)
                .frame(width: 30)
            
            Text(title)
                .foregroundColor(.primary)
            
            Spacer()
            
            Image(systemName: "chevron.right")
                .foregroundColor(.gray)
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(10)
    }
}

// Placeholder Views for Navigation
struct NotificationsView: View {
    var body: some View {
        Text("Notifications Settings")
    }
}

struct PrivacySecurityView: View {
    var body: some View {
        Text("Privacy & Security Settings")
    }
}

struct AppearanceView: View {
    var body: some View {
        Text("Appearance Settings")
    }
}

struct HelpSupportView: View {
    var body: some View {
        Text("Help & Support")
    }
}

#Preview {
    ProfileView(showingSignUp: .constant(false))
} 
