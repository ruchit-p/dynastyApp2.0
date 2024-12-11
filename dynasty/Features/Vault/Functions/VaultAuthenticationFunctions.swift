import SwiftUI
import os.log

class VaultAuthenticationFunctions {
    private static let logger = Logger(subsystem: "com.dynasty.VaultView", category: "Authentication")
    
    @MainActor static func handleUserChange(_ user: User?, vaultManager: VaultManager) {
        guard let user = user, let userId = user.id else {
            vaultManager.lock()
            return
        }
        
        vaultManager.setCurrentUser(user)
        authenticate(userId: userId, vaultManager: vaultManager)
    }
    
    @MainActor static func authenticate(userId: String, vaultManager: VaultManager) {
        guard !vaultManager.isAuthenticating else { return }
        
        logger.info("Starting vault authentication for user: \(userId)")
        
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
