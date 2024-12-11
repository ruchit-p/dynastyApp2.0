import SwiftUI

struct VaultLockedView: View {
    @EnvironmentObject private var vaultManager: VaultManager
    @EnvironmentObject private var authManager: AuthManager
    @Binding var error: Error?
    @Binding var showError: Bool

    var body: some View {
        VStack {
            Text("Vault is Locked")
                .font(.title2)
                .padding()

            Text("Press the button below to authenticate with Face ID or passcode.")
                .foregroundColor(.secondary)
                .padding(.horizontal)

            Button(action: {
                Task {
                    // Ensure you're passing the current user's ID here
                    if let userId = authManager.user?.id {
                        VaultAuthenticationFunctions.authenticate(userId: userId, vaultManager: vaultManager)
                    } else {
                        // Handle the case where the user ID is not available
                        error = VaultError.authenticationFailed("User not found")
                        showError = true
                    }
                }
            }) {
                Label("Authenticate to Unlock", systemImage: getBiometricButtonIcon())
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(8)
                    .padding(.horizontal)
            }
            .disabled(vaultManager.isAuthenticating)
        }
    }

    private func getBiometricButtonIcon() -> String {
        let (_, type, _) = authManager.checkBiometricAvailability()
        switch type {
        case .faceID: return "faceid"
        case .touchID: return "touchid"
        default: return "key.fill"
        }
    }
} 