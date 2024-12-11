import SwiftUI
import os.log

class VaultSceneHandlingFunctions {
    private static let logger = Logger(subsystem: "com.dynasty.VaultView", category: "SceneHandling")
    
    @MainActor static func handleScenePhaseChange(to newPhase: ScenePhase, vaultManager: VaultManager) {
        switch newPhase {
        case .inactive, .background:
            vaultManager.lock()
            logger.info("App moved to background. Vault locked.")
        case .active:
            break
        @unknown default:
            break
        }
    }
} 
