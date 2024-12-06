import Foundation
import CryptoKit
import os.log

enum VaultEncryptionError: Error {
    case keyNotFound(String)
    case encryptionFailed(String)
    case decryptionFailed(String)
    case invalidData(String)
    case fileIntegrityCompromised
    case keychainError(String)
    
    var errorDescription: String? {
        switch self {
        case .encryptionFailed(let reason):
            return "Failed to encrypt data: \(reason)"
        case .decryptionFailed(let reason):
            return "Failed to decrypt data: \(reason)"
        case .keyNotFound(let keyId):
            return "Encryption key not found: \(keyId)"
        case .invalidData(let reason):
            return "Invalid data: \(reason)"
        case .fileIntegrityCompromised:
            return "File integrity check failed"
        case .keychainError(let reason):
            return "Keychain operation failed: \(reason)"
        }
    }
}

class VaultEncryptionService {
    let keychainHelper: KeychainHelper
    private var encryptionKeys: [String: SymmetricKey] = [:]
    private let logger = Logger(subsystem: "com.dynasty.VaultEncryptionService", category: "Encryption")
    
    init(keychainHelper: KeychainHelper) {
        self.keychainHelper = keychainHelper
    }
    
    func generateEncryptionKey() -> (key: SymmetricKey, id: String) {
        let key = SymmetricKey(size: .bits256)
        let id = UUID().uuidString
        encryptionKeys[id] = key
        
        do {
            try keychainHelper.storeEncryptionKey(key, for: id)
            logger.info("Successfully stored encryption key \(id) in Keychain")
        } catch {
            logger.error("Failed to store encryption key \(id) in Keychain: \(error.localizedDescription)")
        }
        
        return (key, id)
    }
    
    func encryptFile(data: Data, userId: String, keyId: String) throws -> Data {
        logger.info("Encrypting file for user: \(userId) with key: \(keyId)")
        
        guard !data.isEmpty else {
            logger.error("Attempted to encrypt empty data")
            throw VaultEncryptionError.invalidData("Empty data")
        }
        
        let key: SymmetricKey
        do {
            if let cachedKey = encryptionKeys[keyId] {
                key = cachedKey
            } else {
                let keyData = try keychainHelper.loadEncryptionKey(for: keyId)
                key = SymmetricKey(data: keyData)
                encryptionKeys[keyId] = key
            }
        } catch {
            logger.error("Encryption key not found: \(keyId)")
            throw VaultEncryptionError.keyNotFound(keyId)
        }
        
        do {
            let sealedBox = try AES.GCM.seal(data, using: key)
            guard let combined = sealedBox.combined else {
                logger.error("Failed to combine encrypted data")
                throw VaultEncryptionError.encryptionFailed("Failed to combine encrypted data")
            }
            
            logger.info("Successfully encrypted file: \(combined.count) bytes")
            return combined
        } catch let error as VaultEncryptionError {
            logger.error("Encryption failed with VaultEncryptionError: \(error.localizedDescription)")
            throw error
        } catch {
            logger.error("Encryption failed with unexpected error: \(error.localizedDescription)")
            throw VaultEncryptionError.encryptionFailed(error.localizedDescription)
        }
    }
    
    func decryptFile(encryptedData: Data, userId: String, keyId: String) throws -> Data {
        logger.info("Decrypting file for user: \(userId) with key: \(keyId)")
        
        guard !encryptedData.isEmpty else {
            logger.error("Attempted to decrypt empty data")
            throw VaultEncryptionError.invalidData("Empty encrypted data")
        }
        
        let key: SymmetricKey
        do {
            if let cachedKey = encryptionKeys[keyId] {
                key = cachedKey
            } else {
                let keyData = try keychainHelper.loadEncryptionKey(for: keyId)
                key = SymmetricKey(data: keyData)
                encryptionKeys[keyId] = key
            }
        } catch {
            logger.error("Decryption key not found: \(keyId)")
            throw VaultEncryptionError.keyNotFound(keyId)
        }
        
        do {
            let sealedBox = try AES.GCM.SealedBox(combined: encryptedData)
            let decryptedData = try AES.GCM.open(sealedBox, using: key)
            
            logger.info("Successfully decrypted file: \(decryptedData.count) bytes")
            return decryptedData
        } catch let error as VaultEncryptionError {
            logger.error("Decryption failed with VaultEncryptionError: \(error.localizedDescription)")
            throw error
        } catch {
            logger.error("Decryption failed with unexpected error: \(error.localizedDescription)")
            throw VaultEncryptionError.decryptionFailed(error.localizedDescription)
        }
    }
    
    func generateFileHash(for data: Data) -> String {
        let hash = SHA256.hash(data: data)
        return hash.compactMap { String(format: "%02x", $0) }.joined()
    }
} 
