import SwiftUI

struct MainTabView: View {
    var body: some View {
        TabView {
            FeedView()
                .tabItem {
                    Image(systemName: "house.fill")
                    Text("Feed")
                }
            
            FamilyTreeView()
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