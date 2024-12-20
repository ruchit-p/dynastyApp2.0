import SwiftUI
import os.log
import FirebaseAuth 
import FirebaseFirestore

class VaultAuthenticationFunctions {
    private static let logger = Logger(subsystem: "com.dynasty.VaultView", category: "Authentication")
    
    @MainActor static func handleUserChange(_ user: FirebaseAuth.User?, vaultManager: VaultManager, authManager: AuthManager) {
        guard let user = user else {
            // User is logged out, handle accordingly
            vaultManager.lock()
            return
        }
        
        // User is logged in, initialize the vault
        Task {
            do {
                vaultManager.setCurrentUser(authManager.user)
                try await vaultManager.unlock()
            } catch {
                logger.error("Error initializing vault: \(error.localizedDescription)")
            }
        }
    }
    
    @MainActor static func authenticate(userId: String, vaultManager: VaultManager, authManager: AuthManager) {
        guard !vaultManager.isAuthenticating else { return }
        
        logger.info("Starting vault authentication for user: \(userId)")
        
        // Use the current user from authManager
        if let user = authManager.user {
            vaultManager.setCurrentUser(user)
        }
        
        Task {
            do {
                try await vaultManager.unlock()
            } catch VaultError.authenticationCancelled {
                logger.info("Authentication cancelled by user")
            } catch {
                logger.error("Authentication failed: \(error.localizedDescription)")
                await MainActor.run {
                    // Note: Error handling should be implemented by the view using this function
                    NotificationCenter.default.post(name: NSNotification.Name("VaultAuthenticationError"), object: error)
                }
            }
        }
    }
} 
