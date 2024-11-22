import SwiftUI
import LocalAuthentication
import CryptoKit
import Security
import FirebaseAuth
import FirebaseFirestore

struct VaultItemDetailView: View {
    let vaultItem: VaultItem
    @State private var decryptedData: String?
    @State private var showError: Bool = false

    var body: some View {
        VStack {
            if let decryptedData = decryptedData {
                Text("Content:")
                    .font(.headline)
                Text(decryptedData)
                    .padding()
            } else {
                Text("Unlock to view the content.")
                    .font(.subheadline)
                    .foregroundColor(.gray)
            }

            Spacer()

            Button(action: authenticate) {
                Label("Unlock", systemImage: "lock.open")
                    .padding()
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(8)
            }
        }
        .navigationTitle(vaultItem.title)
        .alert(isPresented: $showError) {
            Alert(title: Text("Authentication Failed"),
                  message: Text("Could not verify your identity."),
                  dismissButton: .default(Text("OK")))
        }
    }

    private func authenticate() {
        let context = LAContext()
        var error: NSError?

        if context.canEvaluatePolicy(.deviceOwnerAuthentication, error: &error) {
            let reason = "Authenticate to view vault item."

            context.evaluatePolicy(.deviceOwnerAuthentication, localizedReason: reason) { success, authenticationError in
                if success {
                    decryptData()
                } else {
                    showError = true
                }
            }
        } else {
            // No biometrics
            showError = true
        }
    }

    private func decryptData() {
        guard let currentUser = Auth.auth().currentUser else { return }
        
        do {
            // Get encryption key from Keychain
            let query: [String: Any] = [
                kSecClass as String: kSecClassKey,
                kSecAttrApplicationTag as String: "com.dynasty.vaultkey.\(currentUser.uid)",
                kSecReturnData as String: true
            ]
            
            var result: AnyObject?
            let status = SecItemCopyMatching(query as CFDictionary, &result)
            
            guard status == errSecSuccess,
                  let keyData = result as? Data,
                  let key = try? SymmetricKey(data: keyData) else {
                print("Error retrieving encryption key from Keychain")
                return
            }
            
            // Convert base64 encrypted content to Data
            guard let encryptedData = Data(base64Encoded: vaultItem.encryptedContent) else {
                print("Error decoding base64 encrypted content")
                return
            }
            
            // Split the encrypted data into nonce and sealed box
            let nonceSize = 12  // AES-GCM uses a 12-byte nonce
            guard encryptedData.count > nonceSize else {
                print("Encrypted data is invalid")
                return
            }
            
            let nonce = try AES.GCM.Nonce(data: encryptedData.prefix(nonceSize))
            let sealedBox = try AES.GCM.SealedBox(
                nonce: nonce,
                ciphertext: encryptedData.dropFirst(nonceSize).dropLast(16),
                tag: encryptedData.suffix(16)
            )
            
            // Decrypt the data
            let decryptedData = try AES.GCM.open(sealedBox, using: key)
            
            // Convert decrypted data to string
            guard let decryptedString = String(data: decryptedData, encoding: .utf8) else {
                print("Error converting decrypted data to string")
                return
            }
            
            self.decryptedData = decryptedString
            
        } catch {
            print("Decryption error: \(error.localizedDescription)")
            showError = true
        }
    }
}

// Vault item model
struct VaultItem: Identifiable, Codable {
    @DocumentID var id: String?
    var title: String
    var encryptedContent: String
    var timestamp: Date
} 