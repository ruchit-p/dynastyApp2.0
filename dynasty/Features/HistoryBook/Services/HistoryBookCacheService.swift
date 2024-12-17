import Foundation
import FirebaseFirestore
import UIKit

/// Service responsible for caching history book data
final class HistoryBookCacheService {
    static let shared = HistoryBookCacheService()
    
    private let defaults = UserDefaults.standard
    private let fileManager = FileManager.default
    private let cacheDirectory: URL
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()
    
    // Cache keys
    private enum CacheKey: String, CaseIterable {
        case historyBook = "cached_history_book"
        case stories = "cached_stories"
        case comments = "cached_comments"
        case lastSyncTimestamp = "history_book_last_sync"
    }
    
    private init() {
        let urls = fileManager.urls(for: .cachesDirectory, in: .userDomainMask)
        cacheDirectory = urls[0].appendingPathComponent("HistoryBookCache")
        try? fileManager.createDirectory(at: cacheDirectory, withIntermediateDirectories: true)
        
        // Setup timestamp handling
        encoder.dateEncodingStrategy = .iso8601
        decoder.dateDecodingStrategy = .iso8601
    }
    
    // MARK: - History Book Caching
    
    func cacheHistoryBook(_ historyBook: HistoryBook) throws {
        let data = try encoder.encode(historyBook)
        defaults.set(data, forKey: CacheKey.historyBook.rawValue)
        updateLastSyncTimestamp()
    }
    
    func getCachedHistoryBook() -> HistoryBook? {
        guard let data = defaults.data(forKey: CacheKey.historyBook.rawValue) else { return nil }
        return try? decoder.decode(HistoryBook.self, from: data)
    }
    
    // MARK: - Stories Caching
    
    func cacheStories(_ stories: [Story], forHistoryBook historyBookId: String) throws {
        let data = try encoder.encode(stories)
        let key = "\(CacheKey.stories.rawValue)_\(historyBookId)"
        defaults.set(data, forKey: key)
        updateLastSyncTimestamp()
    }
    
    func getCachedStories(forHistoryBook historyBookId: String) -> [Story]? {
        let key = "\(CacheKey.stories.rawValue)_\(historyBookId)"
        guard let data = defaults.data(forKey: key) else { return nil }
        return try? decoder.decode([Story].self, from: data)
    }
    
    // MARK: - Comments Caching
    
    func cacheComments(_ comments: [Comment], forStory storyId: String) throws {
        let data = try encoder.encode(comments)
        let key = "\(CacheKey.comments.rawValue)_\(storyId)"
        defaults.set(data, forKey: key)
        updateLastSyncTimestamp()
    }
    
    func getCachedComments(forStory storyId: String) -> [Comment]? {
        let key = "\(CacheKey.comments.rawValue)_\(storyId)"
        guard let data = defaults.data(forKey: key) else { return nil }
        return try? decoder.decode([Comment].self, from: data)
    }
    
    // MARK: - Media Caching
    
    func cacheMedia(_ data: Data, forURL urlString: String) throws {
        let filename = urlString.replacingOccurrences(of: "/", with: "_")
        let fileURL = cacheDirectory.appendingPathComponent(filename)
        try data.write(to: fileURL)
    }
    
    func getCachedMedia(forURL urlString: String) -> Data? {
        let filename = urlString.replacingOccurrences(of: "/", with: "_")
        let fileURL = cacheDirectory.appendingPathComponent(filename)
        return try? Data(contentsOf: fileURL)
    }
    
    // MARK: - Cache Management
    
    private func updateLastSyncTimestamp() {
        defaults.set(Date(), forKey: CacheKey.lastSyncTimestamp.rawValue)
    }
    
    func isCacheStale() -> Bool {
        guard let lastSync = defaults.object(forKey: CacheKey.lastSyncTimestamp.rawValue) as? Date else {
            return true
        }
        // Consider cache stale after 1 hour
        return Date().timeIntervalSince(lastSync) > 3600
    }
    
    func clearCache() {
        // Clear UserDefaults cache
        CacheKey.allCases.forEach { key in
            defaults.removeObject(forKey: key.rawValue)
        }
        
        // Clear media cache
        try? fileManager.removeItem(at: cacheDirectory)
        try? fileManager.createDirectory(at: cacheDirectory, withIntermediateDirectories: true)
    }
    
    // MARK: - Background Sync
    
    func markForSync(_ story: Story) throws {
        var pendingSync = getPendingSyncItems()
        pendingSync.append(story)
        let data = try encoder.encode(pendingSync)
        defaults.set(data, forKey: "pending_sync_stories")
    }
    
    func getPendingSyncItems() -> [Story] {
        guard let data = defaults.data(forKey: "pending_sync_stories") else { return [] }
        return (try? decoder.decode([Story].self, from: data)) ?? []
    }
    
    func clearPendingSyncItems() {
        defaults.removeObject(forKey: "pending_sync_stories")
    }
} 