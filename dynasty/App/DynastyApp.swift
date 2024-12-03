//
//  DynastyApp.swift
//  Dynasty
//
//  Created by Ruchit Patel on 10/30/24.
//

import SwiftUI
import FirebaseCore

@main
struct DynastyApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var authManager = AuthManager()
    @StateObject private var vaultManager = VaultManager.shared
    
    var body: some Scene {
        WindowGroup {
            if authManager.isAuthenticated {
                ContentView()
                    .environmentObject(authManager)
                    .environmentObject(vaultManager)
            } else {
                SignInView()
                    .environmentObject(authManager)
            }
        }
    }
}
