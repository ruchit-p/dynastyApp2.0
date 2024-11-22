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
                    fetchUser()
                }
        } else {
            NavigationView {
                SignInView()
            }
        }
    }

    private func fetchUser() {
        guard let currentUser = authManager.user else {
            print("User is not authenticated.")
            return
        }
        let db = Firestore.firestore()

        let userRef = db.collection(Constants.Firebase.usersCollection).document(currentUser.id!)
        userRef.getDocument { document, error in
            if let error = error {
                print("Error fetching user document: \(error.localizedDescription)")
                return
            }

            if let document = document, document.exists {
                // User document exists, verify collections
                verifyUserCollections(userID: currentUser.id!)
            } else {
                // User document does not exist, sign out the user
                do {
                    try authManager.signOut()
                    print("User document does not exist, signing out")
                } catch {
                    print("Error signing out: \(error.localizedDescription)")
                }
            }
        }
    }

    private func verifyUserCollections(userID: String) {
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



