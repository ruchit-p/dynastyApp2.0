import SwiftUI
import FirebaseFirestore
import FirebaseStorage
import FirebaseAuth
import Combine
import OSLog

/// Errors that can occur during profile operations
enum ProfileError: Error {
    case invalidImage
    case uploadFailed
    case invalidUser
    case downloadURLFailed
    case unknown
    case custom(String)
    case sizeLimitExceeded
    case timeout
    case quotaExceeded
    case unauthorized
    
    var localizedDescription: String {
        switch self {
        case .invalidImage:
            return "The selected image is invalid. Please try another image."
        case .uploadFailed:
            return "Failed to upload the image. Please try again."
        case .invalidUser:
            return "Could not find user information. Please try again."
        case .downloadURLFailed:
            return "Failed to get image URL. Please try again."
        case .unknown:
            return "An unknown error occurred. Please try again."
        case .custom(let message):
            return message
        case .sizeLimitExceeded:
            return "Image size exceeds the maximum allowed limit (5MB). Please choose a smaller image."
        case .timeout:
            return "The upload timed out. Please check your internet connection and try again."
        case .quotaExceeded:
            return "Storage quota exceeded. Please contact support."
        case .unauthorized:
            return "You are not authorized to perform this action. Please sign in again."
        }
    }
}

/// ViewModel responsible for managing user profile editing operations
/// This includes profile updates, image uploads, and validation
@MainActor
class UserProfileEditViewModel: ObservableObject {
    // MARK: - Published Properties
    /// The current user being edited
    @Published var user: User?
    
    /// Loading state for profile operations
    @Published var isLoading = false
    
    /// Loading state for image upload operations
    @Published var isUploading = false
    
    /// Progress of the current image upload (0.0 to 1.0)
    @Published var uploadProgress: Double = 0
    
    /// Current error state
    @Published var error: Error?
    
    /// Dictionary of validation errors by field
    @Published var validationErrors: [String: String] = [:]
    
    /// The current profile image URL for display
    @Published var profileImageURL: URL?
    
    /// The current profile image
    @Published var profileImage: UIImage?
    
    // MARK: - Dependencies
    private let db = FirestoreManager.shared.getDB()
    private let storage = Storage.storage()
    private let logger = Logger(subsystem: "com.dynasty.UserProfileEditViewModel", category: "Profile")
    private let analytics = AnalyticsService.shared
    private let errorHandler = ErrorHandlingService.shared
    private let validation = ValidationService.shared
    
    // MARK: - Initialization
    /// Creates a new UserProfileEditViewModel
    /// - Parameter user: Optional user to edit. If provided, will be cached.
    init(user: User? = nil) {
        self.user = user
        setupValidation()
    }
    
    private func setupValidation() {
        // Setup validation rules
        validationErrors = [:]
    }
    
    // MARK: - Validation
    /// Validates user input for profile update
    /// - Parameters:
    ///   - firstName: User's first name
    ///   - lastName: User's last name
    ///   - email: User's email address
    ///   - phone: User's phone number
    /// - Returns: True if validation passes, false otherwise
    func validateInput(firstName: String, lastName: String, email: String, phone: String) -> Bool {
        validationErrors.removeAll()
        
        let result = validation.validateProfileUpdate(
            firstName: firstName,
            lastName: lastName,
            email: email,
            phone: phone
        )
        
        if case .failure(let error) = result {
            validationErrors["form"] = error.message
            return false
        }
        
        return true
    }
    
    // MARK: - Profile Update
    /// Updates the user's profile information in Firestore
    /// - Parameters:
    ///   - userId: ID of the user to update
    ///   - updatedData: Dictionary of fields to update
    /// - Throws: ValidationError if input is invalid, or other Firestore errors
    func updateProfile(userId: String, updatedData: [String: Any]) async throws {
        let startTime = Date()
        isLoading = true
        defer { 
            isLoading = false
            let duration = Date().timeIntervalSince(startTime)
            analytics.logOperationTime(operation: "profile_update", duration: duration)
        }
        
        do {
            // Validate input
            guard let firstName = updatedData["firstName"] as? String,
                  let lastName = updatedData["lastName"] as? String,
                  let email = updatedData["email"] as? String,
                  let phone = updatedData["phoneNumber"] as? String else {
                throw ValidationError.custom("Invalid input data")
            }
            
            guard validateInput(firstName: firstName, lastName: lastName, email: email, phone: phone) else {
                throw ValidationError.custom(validationErrors["form"] ?? "Invalid input")
            }
            
            // Create a clean copy of data with only Firestore-compatible types
            var cleanData: [String: Any] = [
                "firstName": firstName.trimmingCharacters(in: .whitespacesAndNewlines),
                "lastName": lastName.trimmingCharacters(in: .whitespacesAndNewlines),
                "email": email.trimmingCharacters(in: .whitespacesAndNewlines),
                "phoneNumber": phone.trimmingCharacters(in: .whitespacesAndNewlines)
            ]
            
            // Handle photoURL separately if it exists
            // Ensure it's stored as a string in Firestore
            if let photoURL = updatedData["photoURL"] {
                switch photoURL {
                case let urlString as String:
                    cleanData["photoURL"] = urlString
                case let url as URL:
                    cleanData["photoURL"] = url.absoluteString
                default:
                    logger.warning("Invalid photoURL type: \(type(of: photoURL))")
                }
            }
            
            // Add any additional Firestore-compatible fields
            for (key, value) in updatedData {
                if key != "firstName" && key != "lastName" && 
                   key != "email" && key != "phoneNumber" && 
                   key != "photoURL" {
                    // Only add if it's a Firestore-compatible type
                    switch value {
                    case is String, is Int, is Double, is Bool, 
                         is [String], is [Int], is [Double], is [Bool],
                         is Date, is GeoPoint, is DocumentReference:
                        cleanData[key] = value
                    case let url as URL:
                        cleanData[key] = url.absoluteString
                    default:
                        logger.warning("Skipping field '\(key)' due to incompatible type: \(type(of: value))")
                    }
                }
            }
            
            // Validate all data before update
            for (key, value) in cleanData {
                guard value is String || value is Int || value is Double || value is Bool ||
                      value is [String] || value is [Int] || value is [Double] || value is [Bool] ||
                      value is Date || value is GeoPoint || value is DocumentReference else {
                    logger.error("Invalid type for key '\(key)': \(type(of: value))")
                    throw ValidationError.custom("Invalid data type for field: \(key)")
                }
            }
            
            // Update Firestore with clean data
            try await db.collection("users").document(userId).updateData(cleanData)
            
            // Fetch updated profile
            let updatedDoc = try await db.collection("users").document(userId).getDocument()
            if let updatedUser = try? updatedDoc.data(as: User.self) {
                await MainActor.run {
                    self.user = updatedUser
                    // Clear validation errors after successful update
                    self.validationErrors.removeAll()
                }
                
                // Log analytics
                analytics.logProfileEdit(fields: Array(cleanData.keys))
                analytics.setUserProperties(user: updatedUser)
            }
        } catch {
            logger.error("Profile update error: \(error.localizedDescription)")
            errorHandler.handle(error, context: "ProfileUpdate")
            throw error
        }
    }
    
    // MARK: - Image Handling
    
    /// Uploads and processes a new profile image
    /// - Parameter image: The UIImage to upload
    /// - Returns: The download URL of the uploaded image
    func uploadProfileImage(image: UIImage) async throws -> String {
        let startTime = Date()
        isLoading = true
        uploadProgress = 0
        isUploading = true
        
        defer {
            isLoading = false
            isUploading = false
        }
        
        // Check authentication state
        guard let currentUser = Auth.auth().currentUser else {
            self.logger.error("Authentication error: No user is currently signed in")
            throw ProfileError.unauthorized
        }
        
        // Log authentication state
        self.logger.info("""
        Authentication State:
        - User ID: \(currentUser.uid)
        - Email: \(currentUser.email ?? "Not available")
        - Email Verified: \(currentUser.isEmailVerified)
        - Provider ID: \(currentUser.providerID)
        - Token Valid: \(!(currentUser.refreshToken?.isEmpty ?? true))
        """)
        
        // Proceed with upload using verified user ID
        let userId = currentUser.uid
        
        do {
            // Compress image first
            let imageData = try compressImage(image, maxSizeKB: 5120)
            
            // Setup storage reference
            let storageRef = storage.reference()
            let photoRef = storageRef.child("profile_images/\(userId)_\(Date().timeIntervalSince1970).jpg")
            
            let metadata = StorageMetadata()
            metadata.contentType = "image/jpeg"
            
            // Create a promise to handle upload completion
            return try await withCheckedThrowingContinuation { continuation in
                let uploadTask = photoRef.putData(imageData, metadata: metadata)
                
                // Monitor progress
                uploadTask.observe(.progress) { [weak self] snapshot in
                    guard let self = self else { return }
                    let percentComplete = Double(snapshot.progress?.completedUnitCount ?? 0) / Double(snapshot.progress?.totalUnitCount ?? 1)
                    Task { @MainActor in
                        self.uploadProgress = percentComplete
                    }
                }
                
                // Handle upload completion
                uploadTask.observe(.success) { _ in
                    Task {
                        do {
                            let downloadURL = try await photoRef.downloadURL()
                            await MainActor.run {
                                self.profileImageURL = downloadURL
                            }
                            continuation.resume(returning: downloadURL.absoluteString)
                        } catch {
                            continuation.resume(throwing: error)
                        }
                    }
                }
                
                // Handle upload failure
                uploadTask.observe(.failure) { snapshot in
                    if let error = snapshot.error {
                        continuation.resume(throwing: error)
                    } else {
                        continuation.resume(throwing: ProfileError.uploadFailed)
                    }
                }
            }
        } catch {
            logger.error("Image processing failed: \(error.localizedDescription)")
            throw error
        }
    }
    
    /// Updates the profile image cache and UI
    /// - Parameters:
    ///   - userId: The user ID
    ///   - imageData: The image data to cache
    ///   - url: The download URL of the image
    private func updateProfileImageCache(userId: String, imageData: Data, url: URL) async throws {
        // Cache the image data
        try await CacheService.shared.cacheProfileImage(userId: userId, imageData: imageData)
        
        // Update UI
        await MainActor.run {
            self.profileImageURL = url
            self.profileImage = UIImage(data: imageData)
            self.uploadProgress = 1.0
        }
    }
    
    /// Loads the profile image, using cache if available
    /// - Parameter userId: The user ID whose profile image to load
    /// - Returns: True if the image was loaded successfully
    @MainActor
    func loadProfileImage(userId: String) async -> Bool {
        // Try cache first
        if let cachedImage = await loadCachedProfileImage(userId: userId) {
            self.profileImage = cachedImage
            return true
        }
        
        // Fall back to network if needed
        guard let profileURL = profileImageURL else {
            return false
        }
        
        do {
            let (data, _) = try await URLSession.shared.data(from: profileURL)
            
            // Cache the downloaded image
            try await CacheService.shared.cacheProfileImage(userId: userId, imageData: data)
            
            // Update UI
            self.profileImage = UIImage(data: data)
            return true
        } catch {
            logger.error("Failed to load profile image from network: \(error.localizedDescription)")
            return false
        }
    }
    
    /// Loads the cached profile image for a user
    /// - Parameter userId: The user ID whose profile image to load
    /// - Returns: Optional UIImage if cached image exists
    private func loadCachedProfileImage(userId: String) async -> UIImage? {
        guard let imageData = await CacheService.shared.getCachedProfileImage(userId: userId) else {
            return nil
        }
        return UIImage(data: imageData)
    }
    
    /// Compresses an image while maintaining reasonable quality
    /// - Parameters:
    ///   - image: The original UIImage
    ///   - maxSizeKB: Maximum size in kilobytes (default: 5120)
    /// - Returns: Compressed image data
    private func compressImage(_ image: UIImage, maxSizeKB: Int = 5120) throws -> Data {
        var compression: CGFloat = 0.8
        let maxBytes = maxSizeKB * 1024 // 5MB limit
        
        guard var imageData = image.jpegData(compressionQuality: compression) else {
            throw ProfileError.invalidImage
        }
        
        // Try compression first
        while imageData.count > maxBytes && compression > 0.1 {
            compression -= 0.1
            if let compressedData = image.jpegData(compressionQuality: compression) {
                imageData = compressedData
            }
        }
        
        // If still too large, resize the image
        if imageData.count > maxBytes {
            let scale = sqrt(Double(maxBytes) / Double(imageData.count))
            let newSize = CGSize(
                width: image.size.width * scale,
                height: image.size.height * scale
            )
            
            UIGraphicsBeginImageContextWithOptions(newSize, false, image.scale)
            image.draw(in: CGRect(origin: .zero, size: newSize))
            let resizedImage = UIGraphicsGetImageFromCurrentImageContext()
            UIGraphicsEndImageContext()
            
            guard let resizedImageData = resizedImage?.jpegData(compressionQuality: compression) else {
                throw ProfileError.invalidImage
            }
            
            imageData = resizedImageData
            
            if imageData.count > maxBytes {
                throw ProfileError.sizeLimitExceeded
            }
        }
        
        return imageData
    }
    
    // Helper function to retry operations
    private func withRetry<T>(
        maxAttempts: Int,
        delay: TimeInterval,
        operation: () async throws -> T
    ) async throws -> T {
        var attempts = 0
        var lastError: Error?
        
        while attempts < maxAttempts {
            do {
                return try await operation()
            } catch {
                attempts += 1
                lastError = error
                
                if attempts < maxAttempts {
                    try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                }
            }
        }
        
        throw lastError ?? ProfileError.unknown
    }
    
    // MARK: - Cache Management
    /// Loads the user profile from cache if available
    func loadCachedProfile() {
        // Removed cache management
    }
    
    /// Clears all validation errors
    func clearValidationErrors() {
        validationErrors.removeAll()
    }
}
