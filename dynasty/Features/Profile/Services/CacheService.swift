import Foundation
import FirebaseFirestore
import UIKit

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
}

/// Service responsible for caching app data locally
/// This includes user profiles, settings, FAQs
class CacheService {
    /// Shared instance for singleton access
    static let shared = CacheService()
    
    private let defaults = UserDefaults.standard
    
    private init() {}
    
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
    
    // MARK: - Cache Management
    
    /// Clears all cached data, including UserDefaults
    func clearCache() {
        // Clear UserDefaults cache
        CacheKey.allCases.forEach { key in
            defaults.removeObject(forKey: key.rawValue)
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
}

/// Errors that can occur during caching operations
enum CacheError: Error {
    /// Failed to convert data
    case invalidData
    /// Failed to write data to cache
    case writeFailed
    /// Failed to read data from cache
    case readFailed
    
    var localizedDescription: String {
        switch self {
        case .invalidData:
            return "Invalid data format"
        case .writeFailed:
            return "Failed to write to cache"
        case .readFailed:
            return "Failed to read from cache"
        }
    }
}