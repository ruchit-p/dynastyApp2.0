//
//  ContentView.swift
//  Dynasty
//
//  Created by Ruchit Patel on 10/30/24.
//

import SwiftUI
import FirebaseAuth
import FirebaseFirestore
import Combine

struct ContentView: View {
    @EnvironmentObject var authManager: AuthManager

    var body: some View {
        if authManager.isAuthenticated {
            MainTabView()
                .onAppear {
                    Task {
                        await fetchUser()
                    }
                }
        } else {
            NavigationView {
                SignInView()
            }
        }
    }

    private func fetchUser() async {
        guard let currentUser = authManager.user else {
            print("User is not authenticated.")
            return
        }
        let db = Firestore.firestore()

        do {
            let document = try await db.collection(Constants.Firebase.usersCollection)
                .document(currentUser.id!)
                .getDocument()

            if document.exists {
                // User document exists, verify collections
                await verifyUserCollections(userID: currentUser.id!)
            } else {
                // User document does not exist, sign out the user
                try await authManager.signOut()
                print("User document does not exist, signing out")
            }
        } catch {
            print("Error fetching user document: \(error.localizedDescription)")
        }
    }

    private func verifyUserCollections(userID: String) async {
        // Implement your verification logic here
        // For example, check if the user's family tree and other related collections exist
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
            .environmentObject(AuthManager())
    }
}



