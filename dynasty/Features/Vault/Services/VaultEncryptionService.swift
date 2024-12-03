import Foundation
import CryptoKit
import LocalAuthentication
import os.log

enum VaultEncryptionError: LocalizedError {
    case keyGenerationFailed(String)
    case encryptionFailed(String)
    case decryptionFailed(String)
    case keyNotFound(String)
    case invalidData(String)
    case fileIntegrityCompromised
    case keychainError(String)
    
    var errorDescription: String? {
        switch self {
        case .keyGenerationFailed(let reason):
            return "Failed to generate encryption key: \(reason)"
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
    static let shared = VaultEncryptionService()
    
    private var encryptionKeys: [String: SymmetricKey] = [:]
    private let keychainHelper = KeychainHelper.shared
    private let logger = Logger(subsystem: "com.dynasty.VaultEncryptionService", category: "Encryption")
    
    init() {
        logger.info("VaultEncryptionService initialized")
    }
    
    func initialize() async throws {
        logger.info("Initializing encryption service")
        do {
            let existingKeys = try keychainHelper.loadEncryptionKeys()
            encryptionKeys = existingKeys
            logger.info("Successfully loaded \(existingKeys.count) encryption keys")
        } catch {
            logger.error("Failed to load encryption keys: \(error.localizedDescription)")
            throw VaultEncryptionError.keychainError(error.localizedDescription)
        }
    }
    
    func clearKeys() {
        logger.info("Clearing encryption keys from memory")
        encryptionKeys.removeAll()
    }
    
    func generateEncryptionKey(for userId: String) throws -> String {
        logger.info("Generating new encryption key for user: \(userId)")
        
        do {
            let key = SymmetricKey(size: .bits256)
            let keyId = UUID().uuidString
            
            // Store key in memory
            encryptionKeys[keyId] = key
            
            // Store key in keychain
            try keychainHelper.storeEncryptionKey(key, for: keyId)
            
            logger.info("Successfully generated and stored encryption key: \(keyId)")
            return keyId
        } catch {
            logger.error("Failed to generate encryption key: \(error.localizedDescription)")
            throw VaultEncryptionError.keyGenerationFailed(error.localizedDescription)
        }
    }
    
    func encryptFile(data: Data, userId: String, keyId: String) throws -> (encryptedData: Data, iv: Data) {
        logger.info("Encrypting file for user: \(userId) with key: \(keyId)")
        
        // Validate input data
        guard !data.isEmpty else {
            logger.error("Attempted to encrypt empty data")
            throw VaultEncryptionError.invalidData("Empty data")
        }
        
        // Get encryption key
        let key: SymmetricKey
        do {
            if let cachedKey = encryptionKeys[keyId] {
                key = cachedKey
            } else {
                key = try keychainHelper.loadEncryptionKey(for: keyId)
                encryptionKeys[keyId] = key
            }
        } catch {
            logger.error("Encryption key not found: \(keyId)")
            throw VaultEncryptionError.keyNotFound(keyId)
        }
        
        do {
            // Generate random IV
            let iv = Data((0..<12).map { _ in UInt8.random(in: 0...255) })
            let nonce = try AES.GCM.Nonce(data: iv)
            
            // Encrypt data
            let sealedBox = try AES.GCM.seal(data, using: key, nonce: nonce)
            
            guard let combined = sealedBox.combined else {
                logger.error("Failed to combine encrypted data")
                throw VaultEncryptionError.encryptionFailed("Failed to combine encrypted data")
            }
            
            logger.info("Successfully encrypted file: \(combined.count) bytes")
            return (combined, iv)
        } catch let error as VaultEncryptionError {
            logger.error("Encryption failed with VaultEncryptionError: \(error.localizedDescription)")
            throw error
        } catch {
            logger.error("Encryption failed with unexpected error: \(error.localizedDescription)")
            throw VaultEncryptionError.encryptionFailed(error.localizedDescription)
        }
    }
    
    func decryptFile(encryptedData: Data, userId: String, keyId: String, iv: Data) throws -> Data {
        logger.info("Decrypting file for user: \(userId) with key: \(keyId)")
        
        // Validate input data
        guard !encryptedData.isEmpty else {
            logger.error("Attempted to decrypt empty data")
            throw VaultEncryptionError.invalidData("Empty encrypted data")
        }
        
        guard !iv.isEmpty else {
            logger.error("Invalid IV: empty")
            throw VaultEncryptionError.invalidData("Empty IV")
        }
        
        // Get encryption key
        let key: SymmetricKey
        do {
            if let cachedKey = encryptionKeys[keyId] {
                key = cachedKey
            } else {
                key = try keychainHelper.loadEncryptionKey(for: keyId)
                encryptionKeys[keyId] = key
            }
        } catch {
            logger.error("Decryption key not found: \(keyId)")
            throw VaultEncryptionError.keyNotFound(keyId)
        }
        
        do {
            let nonce = try AES.GCM.Nonce(data: iv)
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
        logger.debug("Generating file hash")
        let hash = SHA256.hash(data: data)
        let hashString = hash.compactMap { String(format: "%02x", $0) }.joined()
        logger.debug("Generated hash: \(hashString)")
        return hashString
    }
} 