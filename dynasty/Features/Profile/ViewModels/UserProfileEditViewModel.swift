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
    
    /// Uploads a profile image to Firebase Storage
    /// - Parameters:
    ///   - image: UIImage to upload
    /// - Returns: Download URL string of the uploaded image
    /// - Throws: ProfileError if upload fails
    func uploadProfileImage(image: UIImage) async throws -> String {
        let startTime = Date()
        isLoading = true
        uploadProgress = 0
        isUploading = true
        
        defer {
            Task { @MainActor in
                self.isUploading = false
                self.uploadProgress = 0
            }
            let duration = Date().timeIntervalSince(startTime)
            analytics.logOperationTime(operation: "profile_image_upload", duration: duration)
        }
        
        do {
            // Get current user ID
            guard let userId = Auth.auth().currentUser?.uid else {
                throw ProfileError.invalidUser
            }
            
            // Compress image
            let imageData = try compressImage(image)
            
            // Create a unique filename
            let filename = "\(UUID().uuidString).jpg"
            let path = "profile_images/\(userId)/\(filename)"
            
            // Create storage reference
            let photoRef = storage.reference(withPath: path)
            
            // Set metadata with caching
            let metadata = StorageMetadata()
            metadata.contentType = "image/jpeg"
            metadata.cacheControl = "public, max-age=31536000" // Cache for 1 year
            
            // Create a promise to handle upload completion
            return try await withCheckedThrowingContinuation { continuation in
                let uploadTask = photoRef.putData(imageData, metadata: metadata)
                
                // Monitor progress
                uploadTask.observe(.progress) { [weak self] snapshot in
                    guard let progress = snapshot.progress else { return }
                    let percentage = Double(progress.completedUnitCount) / Double(progress.totalUnitCount)
                    Task { @MainActor in
                        self?.uploadProgress = percentage
                    }
                }
                
                // Handle upload completion
                uploadTask.observe(.success) { [weak self] _ in
                    Task {
                        do {
                            let downloadURL = try await photoRef.downloadURL()
                            await MainActor.run {
                                self?.profileImageURL = downloadURL
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
                    }
                }
            }
        } catch {
            self.errorHandler.handle(error, context: "Error uploading profile image")
            throw error
        }
    }
    
    /// Gets the cached profile image
    /// - Parameter userId: ID of the user
    /// - Returns: The cached profile image, or nil if not found
    func getCachedProfileImage(userId: String) async throws -> UIImage? {
        let fileManager = FileManager.default
        let cacheDirectory = try fileManager.url(for: .cachesDirectory, in: .userDomainMask, appropriateFor: nil, create: false)
        let localURL = cacheDirectory.appendingPathComponent("\(userId)_profile.jpg")
        
        if fileManager.fileExists(atPath: localURL.path) {
            // Load from local cache
            if let imageData = try? Data(contentsOf: localURL),
               let image = UIImage(data: imageData) {
                return image
            }
        }
        
        // If not in cache, download from Firebase
        guard let photoURL = user?.photoURL,
              let url = URL(string: photoURL) else {
            return nil
        }
        
        let photoRef = storage.reference(forURL: photoURL)
        
        do {
            // Download and cache the image
            _ = try await photoRef.write(toFile: localURL)
            
            // Load the newly cached image
            if let imageData = try? Data(contentsOf: localURL),
               let image = UIImage(data: imageData) {
                return image
            }
        } catch {
            logger.error("Failed to download profile image: \(error.localizedDescription)")
            throw error
        }
        
        return nil
    }
    
    /// Compresses an image while maintaining reasonable quality
    /// - Parameters:
    ///   - image: The original UIImage
    ///   - maxSizeKB: Maximum size in kilobytes (default: 500)
    /// - Returns: Compressed image data
    private func compressImage(_ image: UIImage, maxSizeKB: Int = 500) throws -> Data {
        var compression: CGFloat = 0.8
        let maxBytes = maxSizeKB * 1024
        
        guard var imageData = image.jpegData(compressionQuality: compression) else {
            throw ProfileError.invalidImage
        }
        
        // If already under max size, return
        if imageData.count <= maxBytes {
            return imageData
        }
        
        // Binary search for appropriate compression level
        var min: CGFloat = 0
        var max: CGFloat = 1
        
        for _ in 0..<6 { // Maximum 6 attempts
            compression = (max + min) / 2
            
            if let data = image.jpegData(compressionQuality: compression) {
                if data.count < Int(Double(maxBytes) * 0.9) {
                    min = compression
                } else if data.count > maxBytes {
                    max = compression
                } else {
                    imageData = data
                    break
                }
                imageData = data
            }
        }
        
        // If still too large, resize the image
        if imageData.count > maxBytes {
            let scale = sqrt(Double(maxBytes) / Double(imageData.count))
            let size = CGSize(
                width: image.size.width * scale,
                height: image.size.height * scale
            )
            
            UIGraphicsBeginImageContextWithOptions(size, false, image.scale)
            image.draw(in: CGRect(origin: .zero, size: size))
            let resizedImage = UIGraphicsGetImageFromCurrentImageContext()
            UIGraphicsEndImageContext()
            
            guard let finalData = resizedImage?.jpegData(compressionQuality: compression) else {
                throw ProfileError.invalidImage
            }
            
            imageData = finalData
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
