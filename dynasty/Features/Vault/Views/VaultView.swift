import SwiftUI
import Firebase
import CryptoKit
import Security
import UIKit
import FirebaseAuth
import FirebaseFirestore

struct VaultView: View {
    @State private var isAuthenticated = false
    @State private var vaultData: Data?
    @State private var decryptedData: Data?
    @State private var encryptionKey: SymmetricKey?

    var body: some View {
        VStack {
            if isAuthenticated {
                if let decryptedData = decryptedData, let content = String(data: decryptedData, encoding: .utf8) {
                    Text("Vault Content:")
                        .font(.headline)
                    Text(content)
                        .padding()
                } else {
                    Text("Your vault is empty or cannot be decrypted.")
                }

                Button("Add Data to Vault") {
                    addDataToVault()
                }
                .padding()
            } else {
                Button("Unlock Vault") {
                    reauthenticateUser { success in
                        if success {
                            loadEncryptionKey()
                            loadVaultData()
                        }
                    }
                }
                .padding()
            }
        }
        .onAppear {
            if Auth.auth().currentUser != nil {
                isAuthenticated = true
            }
        }
    }

    func reauthenticateUser(completion: @escaping (Bool) -> Void) {
        guard let user = Auth.auth().currentUser else {
            completion(false)
            return
        }

        // Prompt user for password
        let alertController = UIAlertController(
            title: "Re-enter Password",
            message: "Please enter your password to access the vault.",
            preferredStyle: .alert
        )
        
        alertController.addTextField { textField in
            textField.isSecureTextEntry = true
        }
        
        let confirmAction = UIAlertAction(title: "Confirm", style: .default) { _ in
            guard let password = alertController.textFields?.first?.text else {
                completion(false)
                return
            }
            
            // Create credential
            let credential = EmailAuthProvider.credential(
                withEmail: user.email ?? "",
                password: password
            )
            
            // Reauthenticate
            user.reauthenticate(with: credential) { _, error in
                if let error = error {
                    print("Error reauthenticating: \(error.localizedDescription)")
                    completion(false)
                } else {
                    completion(true)
                }
            }
        }
        
        let cancelAction = UIAlertAction(title: "Cancel", style: .cancel) { _ in
            completion(false)
        }
        
        alertController.addAction(confirmAction)
        alertController.addAction(cancelAction)
        
        // Present the alert controller
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let rootViewController = windowScene.windows.first?.rootViewController {
            rootViewController.present(alertController, animated: true)
        }
    }

    func loadEncryptionKey() {
        // Retrieve the key from Keychain
        let tag = "com.yourapp.encryptionkey".data(using: .utf8)!
        let query: [String: Any] = [
            kSecClass as String: kSecClassKey,
            kSecAttrApplicationTag as String: tag,
            kSecReturnData as String: kCFBooleanTrue!,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var dataTypeRef: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &dataTypeRef)
        if status == errSecSuccess {
            if let retrievedData = dataTypeRef as? Data {
                encryptionKey = SymmetricKey(data: retrievedData)
            }
        } else {
            // Generate and store a new key
            let newKey = SymmetricKey(size: .bits256)
            encryptionKey = newKey
            let keyData = newKey.withUnsafeBytes { Data(Array($0)) }
            let addQuery: [String: Any] = [
                kSecClass as String: kSecClassKey,
                kSecAttrApplicationTag as String: tag,
                kSecValueData as String: keyData
            ]
            SecItemAdd(addQuery as CFDictionary, nil)
        }
    }

    func loadVaultData() {
        guard let currentUser = Auth.auth().currentUser else { return }
        let db = Firestore.firestore()
        let vaultRef = db.collection("vaults").document(currentUser.uid)
        vaultRef.getDocument { document, error in
            if let document = document, 
               document.exists, 
               let base64Data = document.data()?["encryptedData"] as? String,
               let encryptedData = Data(base64Encoded: base64Data) {
                vaultData = encryptedData
                decryptVaultData()
            } else {
                print("Vault is empty or does not exist.")
            }
        }
    }

    func decryptVaultData() {
        guard let encryptionKey = encryptionKey, let vaultData = vaultData else { return }
        do {
            decryptedData = try decryptData(vaultData, key: encryptionKey)
        } catch {
            print("Failed to decrypt data: \(error.localizedDescription)")
        }
    }

    func addDataToVault() {
        guard let encryptionKey = encryptionKey else { return }
        // For example purposes, we'll add a simple string to the vault
        let content = "This is confidential data."
        if let data = content.data(using: .utf8) {
            do {
                let encryptedData = try encryptData(data, key: encryptionKey)
                // Save encrypted data to Firestore
                saveVaultData(encryptedData)
            } catch {
                print("Failed to encrypt data: \(error.localizedDescription)")
            }
        }
    }

    func saveVaultData(_ data: Data) {
        guard let currentUser = Auth.auth().currentUser else { return }
        let db = Firestore.firestore()
        let vaultRef = db.collection("vaults").document(currentUser.uid)
        
        // Convert Data to Base64 string
        let base64String = data.base64EncodedString()
        
        vaultRef.setData([
            "encryptedData": base64String,
            "createdAt": FieldValue.serverTimestamp(),
            "updatedAt": FieldValue.serverTimestamp()
        ]) { error in
            if let error = error {
                print("Failed to save vault data: \(error.localizedDescription)")
            } else {
                print("Vault data saved successfully.")
                vaultData = data
                decryptVaultData()
            }
        }
    }

    // Encryption and decryption functions
    func encryptData(_ data: Data, key: SymmetricKey) throws -> Data {
        let sealedBox = try AES.GCM.seal(data, using: key)
        return sealedBox.combined!
    }

    func decryptData(_ data: Data, key: SymmetricKey) throws -> Data {
        let sealedBox = try AES.GCM.SealedBox(combined: data)
        return try AES.GCM.open(sealedBox, using: key)
    }

    func storeKeyInKeychain(key: SymmetricKey, account: String) {
        let keyData = key.withUnsafeBytes { Data(Array($0)) }
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: account,
            kSecValueData as String: keyData
        ]
        let status = SecItemAdd(query as CFDictionary, nil)
        if status != errSecSuccess {
            print("Error storing key: \(status)")
        }
    }

    func retrieveKeyFromKeychain(account: String) -> SymmetricKey? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: account,
            kSecReturnData as String: kCFBooleanTrue!,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var dataTypeRef: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &dataTypeRef)
        if status == errSecSuccess {
            if let keyData = dataTypeRef as? Data {
                return SymmetricKey(data: keyData)
            }
        } else {
            print("Error retrieving key: \(status)")
        }
        return nil
    }
}

#Preview {
    VaultView()
} 
