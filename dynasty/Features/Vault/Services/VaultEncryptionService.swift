import Foundation
import CryptoKit
import Security

enum VaultEncryptionError: LocalizedError {
    case keyGenerationFailed
    case keyNotFound
    case encryptionFailed
    case decryptionFailed
    case invalidIV
    case fileIntegrityCompromised
    
    var errorDescription: String? {
        switch self {
        case .keyGenerationFailed:
            return "Failed to generate encryption key"
        case .keyNotFound:
            return "Encryption key not found"
        case .encryptionFailed:
            return "Failed to encrypt file"
        case .decryptionFailed:
            return "Failed to decrypt file"
        case .invalidIV:
            return "Invalid initialization vector"
        case .fileIntegrityCompromised:
            return "File integrity check failed"
        }
    }
}

class VaultEncryptionService {
    static let shared = VaultEncryptionService()
    private let keychain = KeychainHelper.shared
    
    private init() {}
    
    // Generate a new encryption key for a user
    func generateEncryptionKey(for userId: String) throws -> String {
        let key = SymmetricKey(size: .bits256)
        let keyData = key.withUnsafeBytes { Data(Array($0)) }
        let keyId = UUID().uuidString
        
        // Store the key in Keychain with the keyId
        let keychainKey = "vault.key.\(userId).\(keyId)"
        guard keychain.save(key: keychainKey, data: keyData) else {
            throw VaultEncryptionError.keyGenerationFailed
        }
        
        return keyId
    }
    
    // Encrypt file data
    func encryptFile(data: Data, userId: String, keyId: String) throws -> (encryptedData: Data, iv: String) {
        guard let key = getEncryptionKey(for: userId, keyId: keyId) else {
            throw VaultEncryptionError.keyNotFound
        }
        
        let iv = AES.GCM.Nonce()
        let sealedBox = try AES.GCM.seal(data, using: key, nonce: iv)
        
        guard let combined = sealedBox.combined else {
            throw VaultEncryptionError.encryptionFailed
        }
        
        return (combined, iv.withUnsafeBytes { Data(Array($0)) }.base64EncodedString())
    }
    
    // Decrypt file data
    func decryptFile(encryptedData: Data, userId: String, keyId: String, iv: String) throws -> Data {
        guard let key = getEncryptionKey(for: userId, keyId: keyId) else {
            throw VaultEncryptionError.keyNotFound
        }
        
        guard let ivData = Data(base64Encoded: iv),
              let nonce = try? AES.GCM.Nonce(data: ivData) else {
            throw VaultEncryptionError.invalidIV
        }
        
        let sealedBox = try AES.GCM.SealedBox(combined: encryptedData)
        return try AES.GCM.open(sealedBox, using: key)
    }
    
    // Get encryption key from Keychain
    private func getEncryptionKey(for userId: String, keyId: String) -> SymmetricKey? {
        let keychainKey = "vault.key.\(userId).\(keyId)"
        guard let keyData = keychain.read(key: keychainKey) else {
            return nil
        }
        return SymmetricKey(data: keyData)
    }
    
    // Generate hash for file integrity
    func generateFileHash(for data: Data) -> String {
        let hash = SHA256.hash(data: data)
        return hash.compactMap { String(format: "%02x", $0) }.joined()
    }
    
    // Delete encryption key
    func deleteEncryptionKey(for userId: String, keyId: String) -> Bool {
        let keychainKey = "vault.key.\(userId).\(keyId)"
        return keychain.delete(key: keychainKey)
    }
} 