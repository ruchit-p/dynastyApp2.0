import FirebaseAuth
import FirebaseFirestore
import Combine
import os.log

enum AuthError: Error {
    case signInError(String)
    case signUpError(String)
    case signOutError(String)
    case userNotFound
    case invalidEmail
    case weakPassword
    case emailAlreadyInUse
    case networkError
    case wrongPassword
    case tooManyRequests
    case userDisabled
    case unknown
    case invalidReferralCode
    case familyTreeCreationFailed
    case userDocumentCreationFailed
    
    var description: String {
        switch self {
        case .signInError(let message): return "Sign in failed: \(message)"
        case .signUpError(let message): return "Sign up failed: \(message)"
        case .signOutError(let message): return "Sign out failed: \(message)"
        case .userNotFound: return "No user found with this email"
        case .invalidEmail: return "Please enter a valid email address"
        case .weakPassword: return "Password must be at least 8 characters"
        case .emailAlreadyInUse: return "This email is already registered"
        case .networkError: return "Please check your internet connection"
        case .wrongPassword: return "Incorrect password"
        case .tooManyRequests: return "Too many attempts. Please try again later."
        case .userDisabled: return "This account has been disabled."
        case .unknown: return "An unknown error occurred"
        case .invalidReferralCode: return "Invalid or expired referral code"
        case .familyTreeCreationFailed: return "Failed to create family tree"
        case .userDocumentCreationFailed: return "Failed to create user profile"
        }
    }
}

@MainActor
class AuthManager: ObservableObject {
    // MARK: - Properties
    @Published private(set) var user: User?
    @Published var isAuthenticated = false
    @Published private(set) var authState: AuthState = .unknown
    
    private var authStateListener: AuthStateDidChangeListenerHandle?
    private let db: Firestore
    private let auth: Auth
    private let logger = Logger(subsystem: "com.dynasty.AuthManager", category: "Authentication")
    
    enum AuthState {
        case unknown
        case authenticated
        case notAuthenticated
    }
    
    var currentUser: FirebaseAuth.User? {
        Auth.auth().currentUser
    }
    
    // MARK: - Initialization
    init(db: Firestore = Firestore.firestore(), auth: Auth = Auth.auth()) {
        self.db = db
        self.auth = auth
        setupAuthStateListener()
    }
    
    deinit {
        if let handle = authStateListener {
            auth.removeStateDidChangeListener(handle)
        }
    }
    
    // MARK: - Auth State Management
    private func setupAuthStateListener() {
        authStateListener = auth.addStateDidChangeListener { [weak self] _, firebaseUser in
            guard let self = self else { return }
            
            if let firebaseUser = firebaseUser {
                Task {
                    await self.loadUserData(userId: firebaseUser.uid)
                }
            } else {
                Task { @MainActor in
                    self.user = nil
                    self.isAuthenticated = false
                    self.authState = .notAuthenticated
                }
            }
        }
    }
    
    private func loadUserData(userId: String) async {
        do {
            let document = try await db.collection(Constants.Firebase.usersCollection).document(userId).getDocument()
            
            guard document.exists else {
                logger.error("User document does not exist for uid: \(userId)")
                await MainActor.run {
                    self.user = nil
                    self.isAuthenticated = false
                    self.authState = .notAuthenticated
                }
                return
            }
            
            let userData = try document.data(as: User.self)
            
            await MainActor.run {
                self.user = userData
                self.isAuthenticated = true
                self.authState = .authenticated
            }
        } catch {
            logger.error("Failed to load user data: \(error.localizedDescription)")
            await MainActor.run {
                self.user = nil
                self.isAuthenticated = false
                self.authState = .notAuthenticated
            }
        }
    }
    
    private func removeAuthStateListener() {
        if let handle = authStateListener {
            auth.removeStateDidChangeListener(handle)
        }
    }
    
    // MARK: - Authentication Methods
    func signIn(email: String, password: String) async throws {
        do {
            let result = try await auth.signIn(withEmail: email, password: password)
            await loadUserData(userId: result.user.uid)
        } catch {
            throw mapFirebaseError(error)
        }
    }
    
    func signUp(email: String,
                password: String,
                firstName: String,
                lastName: String,
                phoneNumber: String,
                dateOfBirth: Date,
                referralCode: String?) async throws {
        do {
            // Step 1: Create Firebase Auth user
            let result = try await auth.createUser(withEmail: email, password: password)
            let userId = result.user.uid

            // Step 2: Initialize user data
            var userData = User(
                id: userId,
                displayName: "\(firstName) \(lastName)",
                email: email,
                dateOfBirth: dateOfBirth,
                firstName: firstName,
                lastName: lastName,
                phoneNumber: phoneNumber,
                familyTreeID: nil,
                historyBookID: nil,
                parentIds: [],
                childrenIds: [],
                isAdmin: true,
                canAddMembers: true,
                canEdit: true,
                photoURL: nil,
                createdAt: Timestamp(),
                updatedAt: Timestamp()
            )

            // Step 3: Prepare batched write
            let batch = db.batch()

            // Document references
            let userRef = db.collection(Constants.Firebase.usersCollection).document(userId)
            let familyTreeID = db.collection(Constants.Firebase.familyTreesCollection).document().documentID
            let familyTreeRef = db.collection(Constants.Firebase.familyTreesCollection).document(familyTreeID)
            let historyBookID = db.collection(Constants.Firebase.historyBooksCollection).document().documentID
            let historyBookRef = db.collection(Constants.Firebase.historyBooksCollection).document(historyBookID)
            // Subcollection reference
            let membersRef = familyTreeRef.collection(Constants.Firebase.membersSubcollection)
            let userMemberRef = membersRef.document(userId)

            // Initialize FamilyMember data
            let familyMember = FamilyMember(
                id: userId,
                firstName: firstName,
                lastName: lastName,
                email: email,
                dateOfBirth: dateOfBirth,
                isRegisteredUser: true,
                updatedAt: Timestamp()
            )

            // Initialize Family Tree data
            let familyTree = FamilyTree(
                id: familyTreeID,
                ownerUserID: userId,
                admins: [userId],
                members: [userId],
                name: "\(firstName)'s Family Tree",
                locked: false,
                createdAt: Timestamp(),
                updatedAt: Timestamp()
            )

            // Initialize History Book data
            let historyBook = HistoryBook(
                id: historyBookID,
                ownerUserID: userId,
                familyTreeID: familyTreeID,
                title: "\(firstName)'s History Book",
                privacy: .familyPublic
            )

            // Update userData with IDs
            userData.familyTreeID = familyTreeID
            userData.historyBookID = historyBookID

            // Add operations to batch
            try batch.setData(from: userData, forDocument: userRef)
            try batch.setData(from: familyTree, forDocument: familyTreeRef)
            try batch.setData(from: historyBook, forDocument: historyBookRef)
            try batch.setData(from: familyMember, forDocument: userMemberRef)

            // Step 4: Commit the batched write
            try await batch.commit()

            // Step 5: Update local user state
            Task { @MainActor in
                self.user = userData
                self.isAuthenticated = true
                self.authState = .authenticated
            }

            logger.info("User, Family Tree, and History Book created successfully.")

        } catch {
            logger.error("Sign-up failed: \(error.localizedDescription)")
            throw mapFirebaseError(error)
        }
    }
    
    func signOut() throws {
        do {
            try Auth.auth().signOut()
            self.isAuthenticated = false
            self.user = nil
            self.authState = .notAuthenticated
        } catch {
            logger.error("Sign-out failed: \(error.localizedDescription)")
            throw AuthError.signOutError(error.localizedDescription)
        }
    }
    
    func resetPassword(for email: String) async throws {
        do {
            try await auth.sendPasswordReset(withEmail: email)
        } catch {
            logger.error("Reset password failed: \(error.localizedDescription)")
            throw mapFirebaseError(error)
        }
    }
    
    func signInWithApple(credential: AuthCredential) async throws {
        do {
            let result = try await auth.signIn(with: credential)
            await loadUserData(userId: result.user.uid)
        } catch {
            throw mapFirebaseError(error)
        }
    }
    
    // MARK: - Helper Methods
    private func mapFirebaseError(_ error: Error) -> AuthError {
        let authError = error as NSError
        
        if let code = AuthErrorCode(rawValue: authError.code) {
            switch code {
            case .userNotFound:
                return .userNotFound
            case .invalidEmail:
                return .invalidEmail
            case .weakPassword:
                return .weakPassword
            case .emailAlreadyInUse:
                return .emailAlreadyInUse
            case .networkError:
                return .networkError
            case .wrongPassword:
                return .wrongPassword
            case .tooManyRequests:
                return .tooManyRequests
            case .userDisabled:
                return .userDisabled
            default:
                return .unknown
            }
        } else {
            return .unknown
        }
    }
    
    // MARK: - User Profile Updates
    func updateUserProfile(displayName: String? = nil, photoURL: URL? = nil) async throws {
        guard let currentUser = auth.currentUser else {
            throw AuthError.userNotFound
        }
        
        let changeRequest = currentUser.createProfileChangeRequest()
        
        if let displayName = displayName {
            changeRequest.displayName = displayName
        }
        
        if let photoURL = photoURL {
            changeRequest.photoURL = photoURL
        }
        
        try await changeRequest.commitChanges()
        
        // Update Firestore document
        if displayName != nil || photoURL != nil {
            var updateData: [String: Any] = [
                "updatedAt": FieldValue.serverTimestamp()
            ]
            
            if let displayName = displayName {
                updateData["displayName"] = displayName
            }
            
            if let photoURL = photoURL {
                updateData["photoURL"] = photoURL.absoluteString
            }
            
            try await db.collection(Constants.Firebase.usersCollection).document(currentUser.uid).updateData(updateData)
        }
    }
} 
