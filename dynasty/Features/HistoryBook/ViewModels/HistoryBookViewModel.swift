import SwiftUI
import FirebaseFirestore
import Combine

class HistoryBookViewModel: ObservableObject {
    @Published var stories: [Story] = []
    @Published var isLoading = false
    @Published var error: Error?
    @Published var isOffline = false
    
    private let db = FirestoreManager.shared.getDB()
    private let cache = HistoryBookCacheService.shared
    
    @MainActor
    private func setLoading(_ value: Bool) {
        isLoading = value
    }
    
    @MainActor
    private func setError(_ error: Error) {
        self.error = error
    }
    
    func fetchStories(familyTreeID: String, currentUserId: String) async {
        await setLoading(true)
        defer { Task { @MainActor in self.isLoading = false } }
        
        do {
            // Try to fetch from network first
            let publicSnapshot = try await db.collection("stories")
                .whereField("familyTreeID", isEqualTo: familyTreeID)
                .whereField("privacy", isEqualTo: "public")
                .getDocuments()
            
            let privateSnapshot = try await db.collection("stories")
                .whereField("creatorUserID", isEqualTo: currentUserId)
                .whereField("privacy", isEqualTo: "private")
                .getDocuments()
            
            var allStories: [Story] = []
            allStories.append(contentsOf: publicSnapshot.documents.compactMap { try? $0.data(as: Story.self) })
            allStories.append(contentsOf: privateSnapshot.documents.compactMap { try? $0.data(as: Story.self) })
            
            // Sort combined results
            let sortedStories = allStories.sorted(by: { ($0.createdAt ?? Date()) > ($1.createdAt ?? Date()) })
            
            // Cache the fetched stories
            try cache.cacheStories(sortedStories, forHistoryBook: familyTreeID)
            
            await MainActor.run {
                self.stories = sortedStories
                self.isOffline = false
            }
        } catch {
            // If network fetch fails, try to load from cache
            if let cachedStories = cache.getCachedStories(forHistoryBook: familyTreeID) {
                await MainActor.run {
                    self.stories = cachedStories
                    self.isOffline = true
                }
            } else {
                await setError(error)
            }
        }
    }
    
    func addStory(_ story: Story) async throws {
        await setLoading(true)
        defer { Task { @MainActor in self.isLoading = false } }
        
        do {
            let docRef = db.collection("stories").document()
            try await docRef.setData(from: story)
            
            // Update local cache
            var cachedStories = cache.getCachedStories(forHistoryBook: story.familyTreeID) ?? []
            cachedStories.insert(story, at: 0)
            try cache.cacheStories(cachedStories, forHistoryBook: story.familyTreeID)
            
            await MainActor.run {
                self.stories.insert(story, at: 0)
            }
        } catch {
            // If offline, mark for sync later
            try cache.markForSync(story)
            
            // Update local cache and UI
            var cachedStories = cache.getCachedStories(forHistoryBook: story.familyTreeID) ?? []
            cachedStories.insert(story, at: 0)
            try cache.cacheStories(cachedStories, forHistoryBook: story.familyTreeID)
            
            await MainActor.run {
                self.stories.insert(story, at: 0)
                self.isOffline = true
            }
        }
    }
    
    func updateStory(_ story: Story) async throws {
        guard let storyId = story.id else {
            throw NSError(domain: "HistoryBook", code: 1, userInfo: [NSLocalizedDescriptionKey: "Invalid story ID"])
        }
        
        await setLoading(true)
        defer { Task { @MainActor in self.isLoading = false } }
        
        do {
            try await db.collection("stories").document(storyId).setData(from: story)
            
            // Update local cache
            if var cachedStories = cache.getCachedStories(forHistoryBook: story.familyTreeID) {
                if let index = cachedStories.firstIndex(where: { $0.id == story.id }) {
                    cachedStories[index] = story
                    try cache.cacheStories(cachedStories, forHistoryBook: story.familyTreeID)
                }
            }
            
            await MainActor.run {
                if let index = self.stories.firstIndex(where: { $0.id == story.id }) {
                    self.stories[index] = story
                }
            }
        } catch {
            // If offline, mark for sync later
            try cache.markForSync(story)
            
            // Update local cache and UI
            if var cachedStories = cache.getCachedStories(forHistoryBook: story.familyTreeID) {
                if let index = cachedStories.firstIndex(where: { $0.id == story.id }) {
                    cachedStories[index] = story
                    try cache.cacheStories(cachedStories, forHistoryBook: story.familyTreeID)
                }
            }
            
            await MainActor.run {
                if let index = self.stories.firstIndex(where: { $0.id == story.id }) {
                    self.stories[index] = story
                }
                self.isOffline = true
            }
        }
    }
    
    func deleteStory(_ storyId: String) async throws {
        await setLoading(true)
        defer { Task { @MainActor in self.isLoading = false } }
        
        do {
            try await db.collection("stories").document(storyId).delete()
            
            // Update local cache
            if let story = stories.first(where: { $0.id == storyId }),
               var cachedStories = cache.getCachedStories(forHistoryBook: story.familyTreeID) {
                cachedStories.removeAll { $0.id == storyId }
                try cache.cacheStories(cachedStories, forHistoryBook: story.familyTreeID)
            }
            
            await MainActor.run {
                self.stories.removeAll { $0.id == storyId }
            }
        } catch {
            await setError(error)
        }
    }
    
    // MARK: - Background Sync
    
    func syncPendingChanges() async {
        let pendingStories = cache.getPendingSyncItems()
        
        for story in pendingStories {
            do {
                if let id = story.id {
                    try await db.collection("stories").document(id).setData(from: story)
                } else {
                    let docRef = db.collection("stories").document()
                    try await docRef.setData(from: story)
                }
            } catch {
                print("Failed to sync story: \(error.localizedDescription)")
                continue
            }
        }
        
        cache.clearPendingSyncItems()
        await MainActor.run {
            self.isOffline = false
        }
    }
} 