import SwiftUI

struct MainTabView: View {
    @EnvironmentObject private var authManager: AuthManager
    
    var body: some View {
        TabView {
            FeedView()
                .tabItem {
                    Image(systemName: "house.fill")
                    Text("Feed")
                }
            
            Group {
                if let user = authManager.user,
                   let userId = user.id,
                   let treeId = user.familyTreeID {
                    FamilyTreeView(treeId: treeId, userId: userId)
                } else {
                    // Fallback view when user or treeId is not available
                    VStack {
                        Text("Family Tree Not Available")
                            .font(.headline)
                        Text("Please complete your profile setup")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .tabItem {
                Image(systemName: "tree")
                Text("Family Tree")
            }
            
            VaultView()
                .tabItem {
                    Image(systemName: "lock.fill")
                    Text("Vault")
                }
            
            HistoryBookView()
                .tabItem {
                    Image(systemName: "book.fill")
                    Text("History Book")
                }
            
            ProfileView(showingSignUp: .constant(false))
                .tabItem {
                    Image(systemName: "person.fill")
                    Text("Profile")
                }
        }
    }
} 