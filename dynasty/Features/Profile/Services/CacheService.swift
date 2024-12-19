import Foundation
import FirebaseFirestore
import UIKit
import OSLog

/// Keys used for caching different types of data
enum CacheKey: String, CaseIterable {
    /// User profile data
    case userProfile = "cached_user_profile"
    /// User settings data
    case userSettings = "cached_user_settings"
    /// Frequently asked questions
    case faqs = "cached_faqs"
    /// Timestamp of last sync with server
    case lastSyncTimestamp = "last_sync_timestamp"
    /// Profile image data
    case profileImage = "cached_profile_image"
}

/// Errors that can occur during caching operations
enum CacheError: Error {
    case directoryCreationFailed
    case fileWriteFailed
    case fileReadFailed
    case invalidPath
    
    var localizedDescription: String {
        switch self {
        case .directoryCreationFailed:
            return "Failed to create cache directory"
        case .fileWriteFailed:
            return "Failed to write file to cache"
        case .fileReadFailed:
            return "Failed to read file from cache"
        case .invalidPath:
            return "Invalid file path"
        }
    }
}

/// Service responsible for caching app data locally
/// This includes user profiles, settings, FAQs, and profile images
actor CacheService {
    /// Shared instance for singleton access
    static let shared = CacheService()
    
    private let defaults = UserDefaults.standard
    private let fileManager = FileManager.default
    private let logger = Logger(subsystem: "com.dynasty.CacheService", category: "Cache")
    
    private init() {
        createCacheDirectoryIfNeeded()
    }
    
    // MARK: - User Profile Caching
    
    /// Caches user profile data to UserDefaults
    /// - Parameter user: User object to cache
    /// - Throws: Error if encoding fails
    func cacheUserProfile(_ user: User) throws {
        let encoder = JSONEncoder()
        let data = try encoder.encode(user)
        defaults.set(data, forKey: CacheKey.userProfile.rawValue)
        defaults.set(Date(), forKey: CacheKey.lastSyncTimestamp.rawValue)
    }
    
    /// Retrieves cached user profile from UserDefaults
    /// - Returns: Optional User object if cached data exists and can be decoded
    func getCachedUserProfile() -> User? {
        guard let data = defaults.data(forKey: CacheKey.userProfile.rawValue) else { return nil }
        return try? JSONDecoder().decode(User.self, from: data)
    }
    
    // MARK: - User Settings Caching
    
    /// Caches user settings to UserDefaults
    /// - Parameter settings: UserSettings object to cache
    /// - Throws: Error if encoding fails
    func cacheUserSettings(_ settings: UserSettingsManager.UserSettings) throws {
        let encoder = JSONEncoder()
        let data = try encoder.encode(settings)
        defaults.set(data, forKey: CacheKey.userSettings.rawValue)
    }
    
    /// Retrieves cached user settings from UserDefaults
    /// - Returns: Optional UserSettings object if cached data exists and can be decoded
    func getCachedUserSettings() -> UserSettingsManager.UserSettings? {
        guard let data = defaults.data(forKey: CacheKey.userSettings.rawValue) else { return nil }
        return try? JSONDecoder().decode(UserSettingsManager.UserSettings.self, from: data)
    }
    
    // MARK: - FAQ Caching
    
    /// Caches FAQ data to UserDefaults
    /// - Parameter faqs: Array of FAQ objects to cache
    /// - Throws: Error if encoding fails
    func cacheFAQs(_ faqs: [FAQ]) throws {
        let encoder = JSONEncoder()
        let data = try encoder.encode(faqs)
        defaults.set(data, forKey: CacheKey.faqs.rawValue)
    }
    
    /// Retrieves cached FAQs from UserDefaults
    /// - Returns: Optional array of FAQ objects if cached data exists and can be decoded
    func getCachedFAQs() -> [FAQ]? {
        guard let data = defaults.data(forKey: CacheKey.faqs.rawValue) else { return nil }
        return try? JSONDecoder().decode([FAQ].self, from: data)
    }
    
    // MARK: - Profile Image Caching
    
    /// Caches profile image data to the file system
    /// - Parameters:
    ///   - userId: User ID to associate with the cached image
    ///   - imageData: Image data to cache
    /// - Throws: CacheError if saving fails
    func cacheProfileImage(userId: String, imageData: Data) throws {
        do {
            let cacheDirectory = try getCacheDirectory()
            let imageUrl = cacheDirectory.appendingPathComponent("\(userId)_profile.jpg")
            
            try imageData.write(to: imageUrl)
            
            // Store the image path in UserDefaults for quick lookup
            let imagePath = imageUrl.path
            let key = makeProfileImageKey(userId: userId)
            defaults.set(imagePath, forKey: key)
            
            logger.debug("Successfully cached profile image for user: \(userId)")
        } catch {
            logger.error("Failed to cache profile image: \(error.localizedDescription)")
            throw CacheError.fileWriteFailed
        }
    }
    
    /// Retrieves cached profile image data for a user
    /// - Parameter userId: User ID to retrieve image for
    /// - Returns: Optional Data containing the image if it exists
    func getCachedProfileImage(userId: String) -> Data? {
        let key = makeProfileImageKey(userId: userId)
        guard let imagePath = defaults.string(forKey: key) else {
            logger.debug("No cached image path found for user: \(userId)")
            return nil
        }
        
        let imageUrl = URL(fileURLWithPath: imagePath)
        
        guard fileManager.fileExists(atPath: imagePath) else {
            logger.debug("Cached image file not found at path: \(imagePath)")
            // Clean up stale reference
            defaults.removeObject(forKey: key)
            return nil
        }
        
        do {
            let imageData = try Data(contentsOf: imageUrl)
            logger.debug("Successfully retrieved cached image for user: \(userId)")
            return imageData
        } catch {
            logger.error("Failed to read cached image: \(error.localizedDescription)")
            return nil
        }
    }
    
    // MARK: - Cache Management
    
    /// Clears all cached data, including UserDefaults and profile images
    func clearCache() {
        // Clear UserDefaults cache
        CacheKey.allCases.forEach { key in
            defaults.removeObject(forKey: key.rawValue)
        }
        
        // Clear all profile image keys
        let allKeys = defaults.dictionaryRepresentation().keys
        for key in allKeys where key.hasPrefix(CacheKey.profileImage.rawValue) {
            defaults.removeObject(forKey: key)
        }
        
        // Clear profile image cache directory
        do {
            let cacheDirectory = try getCacheDirectory()
            try fileManager.removeItem(at: cacheDirectory)
            try fileManager.createDirectory(at: cacheDirectory, withIntermediateDirectories: true)
            logger.info("Successfully cleared cache directory")
        } catch {
            logger.error("Failed to clear cache directory: \(error.localizedDescription)")
        }
    }
    
    /// Checks if the cache is considered stale
    /// - Returns: True if last sync was more than 1 hour ago or if no sync timestamp exists
    func isCacheStale() -> Bool {
        guard let lastSync = defaults.object(forKey: CacheKey.lastSyncTimestamp.rawValue) as? Date else {
            return true
        }
        
        // Consider cache stale after 1 hour
        return Date().timeIntervalSince(lastSync) > 3600
    }
    
    // MARK: - Private Helper Methods
    
    private func createCacheDirectoryIfNeeded() {
        do {
            let cacheDirectory = try getCacheDirectory()
            if !fileManager.fileExists(atPath: cacheDirectory.path) {
                try fileManager.createDirectory(at: cacheDirectory, withIntermediateDirectories: true)
                logger.info("Created cache directory at: \(cacheDirectory.path)")
            }
        } catch {
            logger.error("Failed to create cache directory: \(error.localizedDescription)")
        }
    }
    
    private func getCacheDirectory() throws -> URL {
        try fileManager.url(for: .cachesDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
            .appendingPathComponent("ProfileImages")
    }
    
    private func makeProfileImageKey(userId: String) -> String {
        "\(CacheKey.profileImage.rawValue)_\(userId)"
    }
}