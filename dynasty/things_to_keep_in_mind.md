Below is an updated and slightly more comprehensive guide incorporating your original list and adding a few additional points for clarity and best practices.

Things to Keep in Mind for SwiftUI + Firebase

SwiftUI is reactive and updates the UI when @Published properties change. Firebase operations and image processing often happen off the main thread. Balancing these is crucial for performance and responsiveness.

@Published Properties and Main Thread Rules
	1.	Never Update @Published Properties Directly from Background Threads
	•	Bad:

self.isLoading = true // on a background thread


	•	Good:

await MainActor.run { self.isLoading = true }


	•	Alternative: Create @MainActor helper functions for all UI state updates:

@MainActor
private func setLoading(_ value: Bool) {
    isLoading = value
}


	2.	Avoid Making Entire ViewModels @MainActor
	•	Why? Marking the entire ViewModel as @MainActor forces all code, including heavy operations, to run on the main thread. This will cause UI freezes and slow responsiveness.
	•	Best Practice: Only wrap UI property updates in MainActor and keep heavy work off the main thread.
	3.	Separate UI Updates From Data Processing
	•	Do data transformations on a background thread first, then switch to the main thread to update UI state.
	•	Bad:

await MainActor.run {
    self.items = items.sorted { $0.date > $1.date }
}


	•	Good:

let sortedItems = items.sorted { $0.date > $1.date }
await MainActor.run { self.items = sortedItems }



Best Practices for ViewModels
	1.	Loading States

@MainActor
private func setLoading(_ value: Bool) {
    isLoading = value
}

// Usage in async functions
await setLoading(true)
defer { Task { @MainActor in self.isLoading = false } }


	2.	Error Handling

@MainActor
private func setError(_ error: Error) {
    self.error = error
}

// Usage in async functions
do {
    let snapshot = try await db.collection("stories").getDocuments()
    // Process and assign to published properties on MainActor
} catch {
    await setError(error)
    throw error
}


	3.	Data Updates
	•	Process data off the main thread:

let processedData = await Task.detached {
    return heavyDataProcessing()
}.value

await MainActor.run {
    self.data = processedData
}



Common Patterns to Follow
	1.	Firebase Operations
	•	Perform Firestore queries on a background thread (default).
	•	Use await MainActor.run only to update @Published properties.

let snapshot = try await db.collection("items").getDocuments()
let items = snapshot.documents.compactMap { try? $0.data(as: Item.self) }

// Sort, filter, or map items on background thread if needed:
let sortedItems = items.sorted { $0.date > $1.date }

await MainActor.run {
    self.items = sortedItems
}


	2.	Async Operations & Defer Blocks
	•	Use defer to ensure UI states like isLoading are reset properly.
	•	Make sure to switch to the main thread in defer:

await setLoading(true)
defer { Task { @MainActor in self.isLoading = false } }

// Perform async work here


	3.	Minimize UI-Freezes
	•	If you notice the UI freezing (e.g., delayed keyboard appearance, slow navigation), check if you’re doing heavy work on the main thread.
	•	Move image compression, JSON parsing, or any CPU-intensive operation off the main thread.

Additional Tips
	1.	Testing UI Performance
	•	Test on real devices and older hardware.
	•	If UI hangs, consider profiling with Instruments to identify main thread bottlenecks.
	2.	Use Task.detached for Background Work
	•	Example: Compressing images

let imageData = await Task.detached {
    return image.jpegData(compressionQuality: 0.7)
}.value


	3.	Use Small, Focused Helper Functions
	•	Functions like setLoading(_:) and setError(_:) keep your code clean and ensure thread safety.
	•	Helper functions also make it explicit when and where you touch UI state.

Red Flags to Watch For
	1.	Direct @Published Updates on Background Threads
	•	Always use MainActor.run or a @MainActor function.
	2.	@MainActor on Entire ViewModels
	•	This could force all operations, including heavy tasks, onto the main thread.
	3.	Heavy Processing Inside MainActor.run
	•	Sort or filter your arrays off the main thread first.
	4.	No Error Handling
	•	If you catch an error, communicate it to the UI on the main thread so the user can see the issue.

When to Use @MainActor
	1.	UI State Changes
	•	Setting isLoading, error, stories, or other @Published properties.
	2.	View-Specific Code
	•	Anything that must interact directly with SwiftUI views or published states that the view depends on.
	3.	Avoid @MainActor for:
	•	Database reads/writes
	•	Network requests
	•	Data transformations, sorting, filtering, or other heavy processing

Remember: The main thread is for UI updates only. Offload all other work to background threads.

Full File (with the updated guidelines as comments for reference):

// MARK: - Things to Keep in Mind for SwiftUI + Firebase
//
// 1. Never update @Published properties from a background thread directly.
//    Use await MainActor.run { ... } or @MainActor helper functions.
//
// 2. Avoid marking entire ViewModels as @MainActor.
//    Only UI-related updates should be on the main thread.
//
// 3. Process data off the main thread, then update UI state on the main thread.
//
// 4. Use helper functions for loading/error states to keep code clean.
//    @MainActor private func setLoading(_ value: Bool) { isLoading = value }
//
// 5. Handle errors gracefully and communicate them to the UI on main thread.
//    @MainActor private func setError(_ error: Error) { self.error = error }
//
// 6. Test on real devices and use Instruments if UI hangs. Move heavy work off the main thread.

import SwiftUI
import FirebaseFirestore
import Combine

class HistoryBookViewModel: ObservableObject {
    @Published var stories: [Story] = []
    @Published var isLoading = false
    @Published var error: Error?
    
    private let db = FirestoreManager.shared.getDB()
    
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
            // Perform Firebase reads on background (this is async by default)
            let publicSnapshot = try await db.collection("stories")
                .whereField("familyTreeID", isEqualTo: familyTreeID)
                .whereField("privacy", isEqualTo: "public")
                .getDocuments()
            
            let privateSnapshot = try await db.collection("stories")
                .whereField("creatorUserID", isEqualTo: currentUserId)
                .whereField("privacy", isEqualTo: "private")
                .getDocuments()
            
            // Data processing off main
            var allStories: [Story] = []
            allStories.append(contentsOf: publicSnapshot.documents.compactMap { try? $0.data(as: Story.self) })
            allStories.append(contentsOf: privateSnapshot.documents.compactMap { try? $0.data(as: Story.self) })
            
            // Sort off main thread
            let sortedStories = allStories.sorted { ($0.createdAt ?? Date()) > ($1.createdAt ?? Date()) }
            
            // Update UI on main
            await MainActor.run {
                self.stories = sortedStories
            }
        } catch {
            await setError(error)
        }
    }
    
    func addStory(_ story: Story) async throws {
        await setLoading(true)
        defer { Task { @MainActor in self.isLoading = false } }
        
        do {
            // Writing to Firestore (still async, no main thread needed)
            let docRef = db.collection("stories").document()
            try await docRef.setData(from: story)
        } catch {
            await setError(error)
            throw error
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
        } catch {
            await setError(error)
            throw error
        }
    }
    
    func deleteStory(_ storyId: String) async throws {
        await setLoading(true)
        defer { Task { @MainActor in self.isLoading = false } }
        
        do {
            try await db.collection("stories").document(storyId).delete()
        } catch {
            await setError(error)
            throw error
        }
    }
}