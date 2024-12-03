import SwiftUI
import LocalAuthentication
import os.log
import SQLite3

// DatabaseManager to handle SQLite connections and cache cleanup
class DatabaseManager {
    static let shared = DatabaseManager()
    private var db: OpaquePointer?
    private let logger = Logger(subsystem: "com.dynasty.DatabaseManager", category: "Database")
    
    private init() {}
    
    func openDatabase() {
        guard db == nil else { return }
        
        if let cacheURL = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first?.appendingPathComponent("Cache.db") {
            if sqlite3_open(cacheURL.path, &db) == SQLITE_OK {
                logger.info("Successfully opened database")
            } else {
                logger.error("Error opening database")
            }
        }
    }
    
    func closeDatabase() {
        if let db = db {
            if sqlite3_close(db) == SQLITE_OK {
                logger.info("Successfully closed database")
                self.db = nil
            } else {
                logger.error("Error closing database")
            }
        }
    }
    
    func cleanupCacheExcludingDB() {
        guard let cacheDirectory = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first else { return }
        
        do {
            let files = try FileManager.default.contentsOfDirectory(atPath: cacheDirectory.path)
            for file in files {
                // Skip database files
                if !file.contains("Cache.db") {
                    let filePath = cacheDirectory.appendingPathComponent(file)
                    try FileManager.default.removeItem(at: filePath)
                    logger.info("Removed cache file: \(file)")
                }
            }
        } catch {
            logger.error("Error clearing cache: \(error.localizedDescription)")
        }
    }
}

// Add AuthState enum
enum VaultAuthState {
    case initial
    case authenticating
    case success
    case failed(Error)
}

struct VaultView: View {
    @Binding var selectedTab: Tab
    @State private var isUnlocked = false
    @State private var showingAuthError = false
    @State private var errorMessage = ""
    @State private var authAttempts = 0
    @State private var isLockedOut = false
    @State private var lockoutTimer: Timer?
    @State private var vaultLockTimer: Timer?
    @State private var authState: VaultAuthState = .initial
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase
    @EnvironmentObject private var authManager: AuthManager
    
    private let logger = Logger(subsystem: "com.dynasty.VaultView", category: "Security")
    private let maxAuthAttempts = 5
    private let lockoutDuration: TimeInterval = 300 // 5 minutes
    private let vaultAutoLockDuration: TimeInterval = 60 // 1 minute
    
    var body: some View {
        NavigationView {
            Group {
                if isUnlocked {
                    VaultContentView()
                } else if isLockedOut {
                    LockoutView(remainingTime: $lockoutTimer)
                } else {
                    // Lock Screen
                    VStack {
                        Image(systemName: "lock.fill")
                            .font(.system(size: 60))
                            .foregroundColor(.gray)
                            .padding()
                        
                        Text("Vault is Locked")
                            .font(.title)
                            .padding()
                        
                        Text("Authenticate to access your secure vault")
                            .foregroundColor(.secondary)
                            .padding(.bottom)
                        
                        if case .authenticating = authState {
                            ProgressView()
                                .padding()
                        } else {
                            Button(action: authenticate) {
                                Label(getBiometricButtonLabel(), systemImage: getBiometricButtonIcon())
                                    .padding()
                                    .frame(maxWidth: .infinity)
                                    .background(Color.blue)
                                    .foregroundColor(.white)
                                    .cornerRadius(10)
                            }
                            .padding(.horizontal)
                            .disabled(isLockedOut)
                        }
                        
                        if authAttempts > 0 {
                            Text("Attempts remaining: \(maxAuthAttempts - authAttempts)")
                                .foregroundColor(.red)
                                .padding(.top)
                        }
                    }
                    .alert("Authentication Error", isPresented: $showingAuthError) {
                        Button("Try Again", action: authenticate)
                            .disabled(isLockedOut)
                        Button("Cancel", role: .cancel) {
                            dismiss()
                        }
                    } message: {
                        Text(errorMessage)
                    }
                }
            }
            .navigationBarHidden(true)
        }
        .onAppear {
            // Initialize database and start authentication only if not already unlocked
            DatabaseManager.shared.openDatabase()
            if !isUnlocked {
                authState = .initial
                authenticate()
            }
            cancelVaultLockTimer()
        }
        .onDisappear {
            // Start the timer when the view disappears
            startVaultLockTimer()
        }
        .onChange(of: selectedTab) { oldValue, newValue in
            if newValue != .vault {
                // User has left the vault tab
                logger.info("User left vault tab, starting auto-lock timer")
                startVaultLockTimer()
            } else {
                // User has returned to the vault tab
                logger.info("User returned to vault tab")
                cancelVaultLockTimer()
                if !isUnlocked {
                    authenticate()
                }
            }
        }
        .onChange(of: scenePhase) { oldPhase, newPhase in
            switch newPhase {
            case .inactive, .background:
                // Lock vault when app goes to background
                logger.info("App entering background, locking vault")
                lockVault()
            case .active:
                // Require authentication when becoming active
                logger.info("App becoming active")
                if !isUnlocked {
                    authenticate()
                }
            @unknown default:
                break
            }
        }
    }
    
    private func startVaultLockTimer() {
        cancelVaultLockTimer()
        logger.info("Starting vault auto-lock timer for \(vaultAutoLockDuration) seconds")
        vaultLockTimer = Timer.scheduledTimer(withTimeInterval: vaultAutoLockDuration, repeats: false) { _ in
            DispatchQueue.main.async {
                logger.info("Auto-lock timer expired, locking vault")
                lockVault()
            }
        }
    }
    
    private func cancelVaultLockTimer() {
        if vaultLockTimer != nil {
            logger.info("Cancelling vault auto-lock timer")
            vaultLockTimer?.invalidate()
            vaultLockTimer = nil
        }
    }
    
    private func lockVault() {
        logger.info("Locking vault")
        isUnlocked = false
        authState = .initial
        authAttempts = 0
        DatabaseManager.shared.closeDatabase()
        cancelVaultLockTimer()
    }
    
    private func authenticate() {
        guard !isLockedOut else {
            logger.warning("Authentication attempted while locked out")
            return
        }
        
        let context = LAContext()
        var error: NSError?
        
        logger.info("Starting vault authentication attempt \(authAttempts + 1) of \(maxAuthAttempts)")
        authState = .authenticating
        
        guard context.canEvaluatePolicy(.deviceOwnerAuthentication, error: &error) else {
            let errorDescription = error?.localizedDescription ?? "Authentication not available"
            logger.error("Authentication not available: \(errorDescription)")
            handleAuthenticationError(error: error ?? NSError(domain: "VaultView", code: -1, userInfo: [NSLocalizedDescriptionKey: errorDescription]))
            return
        }
        
        let authReason = "Authenticate to access your secure vault"
        logger.info("Attempting authentication with \(context.biometryType == .faceID ? "Face ID" : context.biometryType == .touchID ? "Touch ID" : "passcode")")
        
        context.evaluatePolicy(.deviceOwnerAuthentication, localizedReason: authReason) { success, error in
            DispatchQueue.main.async {
                if success {
                    logger.info("Authentication successful")
                    withAnimation {
                        isUnlocked = true
                        authState = .success
                        authAttempts = 0
                        DatabaseManager.shared.openDatabase()
                    }
                } else {
                    authAttempts += 1
                    logger.error("Authentication failed (Attempt \(authAttempts)): \(error?.localizedDescription ?? "Unknown error")")
                    
                    if authAttempts >= maxAuthAttempts {
                        handleLockout()
                    } else if let error = error {
                        handleAuthenticationError(error: error)
                    }
                }
            }
        }
    }
    
    private func getBiometricButtonLabel() -> String {
        let (_, type, _) = authManager.checkBiometricAvailability()
        switch type {
        case .faceID:
            return "Unlock with Face ID"
        case .touchID:
            return "Unlock with Touch ID"
        default:
            return "Unlock with Passcode"
        }
    }
    
    private func getBiometricButtonIcon() -> String {
        let (_, type, _) = authManager.checkBiometricAvailability()
        switch type {
        case .faceID:
            return "faceid"
        case .touchID:
            return "touchid"
        default:
            return "key.fill"
        }
    }
    
    private func handleLockout() {
        logger.warning("Maximum authentication attempts reached, initiating lockout")
        isLockedOut = true
        errorMessage = "Too many failed attempts. Please try again in 5 minutes."
        showingAuthError = true
        
        // Start lockout timer
        lockoutTimer = Timer.scheduledTimer(withTimeInterval: lockoutDuration, repeats: false) { _ in
            logger.info("Lockout period ended")
            isLockedOut = false
            authAttempts = 0
        }
    }
    
    private func handleAuthenticationError(error: Error) {
        authState = .failed(error)
        
        if let laError = error as? LAError {
            switch laError.code {
            case .authenticationFailed:
                errorMessage = "Authentication failed. Please try again."
                logger.error("Authentication failed: Invalid biometric or passcode")
            case .userCancel:
                errorMessage = "Authentication cancelled."
                logger.info("User cancelled authentication")
                dismiss()
                return
            case .userFallback:
                logger.info("User requested fallback to passcode")
                return
            case .biometryNotAvailable:
                errorMessage = "Face ID/Touch ID is not available on this device."
                logger.error("Biometric authentication not available")
            case .biometryNotEnrolled:
                errorMessage = "Please set up Face ID/Touch ID in your device settings or use your passcode."
                logger.warning("Biometric authentication not enrolled")
            case .biometryLockout:
                errorMessage = "Too many failed attempts. Please use your device passcode."
                logger.warning("Biometric authentication locked out")
            default:
                errorMessage = error.localizedDescription
                logger.error("Unexpected authentication error: \(error.localizedDescription)")
            }
        } else {
            errorMessage = error.localizedDescription
            logger.error("Unknown authentication error: \(error.localizedDescription)")
        }
        
        showingAuthError = true
    }
}

struct LockoutView: View {
    @Binding var remainingTime: Timer?
    @State private var timeRemaining: TimeInterval = 300 // 5 minutes
    
    var body: some View {
        VStack {
            Image(systemName: "lock.shield")
                .font(.system(size: 60))
                .foregroundColor(.red)
                .padding()
            
            Text("Vault Access Locked")
                .font(.title)
                .padding()
            
            Text("Too many failed attempts.\nPlease try again in \(Int(timeRemaining / 60)) minutes.")
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
                .padding()
        }
        .onAppear {
            startTimer()
        }
    }
    
    private func startTimer() {
        remainingTime = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
            if timeRemaining > 0 {
                timeRemaining -= 1
            } else {
                remainingTime?.invalidate()
                remainingTime = nil
            }
        }
    }
}

struct VaultContentView: View {
    var body: some View {
        NavigationView {
            List {
                Section(header: Text("Documents")) {
                    NavigationLink(destination: DocumentsView()) {
                        Label("All Documents", systemImage: "doc.fill")
                    }
                    NavigationLink(destination: PhotosView()) {
                        Label("Photos", systemImage: "photo.fill")
                    }
                }
                
                Section(header: Text("Security")) {
                    NavigationLink(destination: SharedItemsView()) {
                        Label("Shared Items", systemImage: "person.2.fill")
                    }
                    NavigationLink(destination: TrashView()) {
                        Label("Trash", systemImage: "trash.fill")
                    }
                }
            }
            .navigationTitle("Vault")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        // Add new document/photo
                    }) {
                        Image(systemName: "plus")
                    }
                }
            }
        }
    }
}

// Placeholder Views
struct DocumentsView: View {
    var body: some View {
        Text("Documents View")
    }
}

struct PhotosView: View {
    var body: some View {
        Text("Photos View")
    }
}

struct SharedItemsView: View {
    var body: some View {
        Text("Shared Items View")
    }
}

struct TrashView: View {
    var body: some View {
        Text("Trash View")
    }
}

#Preview {
    VaultView(selectedTab: .constant(.vault))
} 
