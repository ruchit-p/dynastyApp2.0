import SwiftUI
import os.log

enum Tab {
    case feed
    case familyTree
    case vault
    case historyBook
    case profile
    
    var name: String {
        switch self {
        case .feed: return "Feed"
        case .familyTree: return "Family Tree"
        case .vault: return "Vault"
        case .historyBook: return "History Book"
        case .profile: return "Profile"
        }
    }
}

struct MainTabView: View {
    @EnvironmentObject private var authManager: AuthManager
    @State private var selectedTab: Tab = .feed
    private let logger = Logger(subsystem: "com.dynasty.MainTabView", category: "Navigation")
    
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
                    FamilyTreeView(treeId: treeId)
                        .tabItem {
                            Image(systemName: "person.2.fill")
                            Text("Family Tree")
                        }
                        .tag(Tab.familyTree)
                } else {
                    // Fallback view when user or treeId is not available
                    VStack {
                        Text("Family Tree Not Available")
                            .font(.headline)
                        Text("Please complete your profile setup")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .tabItem {
                        Image(systemName: "person.2.fill")
                        Text("Family Tree")
                    }
                    .tag(Tab.familyTree)
                }
            }
            
            VaultView()
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
        .onChange(of: selectedTab) { oldTab, newTab in
            logger.info("User navigated from \(oldTab.name) to \(newTab.name)")
            
            // Log additional context if needed
            if let userId = authManager.user?.id {
                logger.info("User \(userId) navigated to \(newTab.name)")
            }
        }
    }
}
