import SwiftUI

enum Tab {
    case feed
    case familyTree
    case vault
    case historyBook
    case profile
}

struct MainTabView: View {
    @EnvironmentObject private var authManager: AuthManager
    @State private var selectedTab: Tab = .feed
    
    var body: some View {
        TabView(selection: $selectedTab) {
            FeedView()
                .tabItem {
                    Image(systemName: "house.fill")
                    Text("Feed")
                }
                .tag(Tab.feed)
            
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
            .tag(Tab.familyTree)
            
            VaultView(selectedTab: $selectedTab)
                .tabItem {
                    Image(systemName: "lock.fill")
                    Text("Vault")
                }
                .tag(Tab.vault)
            
            HistoryBookView()
                .tabItem {
                    Image(systemName: "book.fill")
                    Text("History Book")
                }
                .tag(Tab.historyBook)
            
            ProfileView(showingSignUp: .constant(false))
                .tabItem {
                    Image(systemName: "person.fill")
                    Text("Profile")
                }
                .tag(Tab.profile)
        }
    }
} 