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
    @StateObject private var vaultManager = VaultManager.shared
    @EnvironmentObject private var authManager: AuthManager
    @Environment(\.scenePhase) private var scenePhase
    
    @State private var showingAuthError = false
    @State private var errorMessage = ""
    @State private var authAttempts = 0
    @State private var isLockedOut = false
    @State private var lockoutTimer: Timer?
    @State private var isPresentingDocumentPicker = false
    @State private var shouldNavigateBack = false
    
    private let logger = Logger(subsystem: "com.dynasty.VaultView", category: "Security")
    private let maxAuthAttempts = 5
    private let lockoutDuration: TimeInterval = 300 // 5 minutes
    
    var body: some View {
        NavigationView {
            Group {
                if !vaultManager.isLocked {
                    VaultContentView(isPresentingDocumentPicker: $isPresentingDocumentPicker)
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
                        
                        if vaultManager.isAuthenticating {
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
                            
                            Button("Cancel") {
                                shouldNavigateBack = true
                            }
                            .padding()
                        }
                        
                        if authAttempts > 0 {
                            Text("Attempts remaining: \(maxAuthAttempts - authAttempts)")
                                .foregroundColor(.red)
                                .padding(.top)
                        }
                    }
                }
            }
            .navigationBarHidden(true)
        }
        .onChange(of: shouldNavigateBack) { _, shouldNavigate in
            if shouldNavigate {
                selectedTab = .feed
                shouldNavigateBack = false
            }
        }
        .onAppear {
            // Only trigger authentication when first appearing and vault is locked
            if selectedTab == .vault && vaultManager.isLocked && !vaultManager.isAuthenticating {
                authenticate()
            }
        }
        .onDisappear {
            // Lock vault when leaving the view
            if !isPresentingDocumentPicker {
                lockVault()
            }
        }
        .onChange(of: selectedTab) { oldValue, newValue in
            if oldValue == .vault && newValue != .vault {
                // Lock when switching away from vault tab
                if !isPresentingDocumentPicker {
                    lockVault()
                }
            } else if newValue == .vault && vaultManager.isLocked && !vaultManager.isAuthenticating {
                // Authenticate when switching to vault tab
                authenticate()
            }
        }
        .onChange(of: scenePhase) { oldPhase, newPhase in
            switch newPhase {
            case .inactive, .background:
                if !vaultManager.isAuthenticating && !isPresentingDocumentPicker {
                    logger.info("App entering background, locking vault")
                    lockVault()
                }
            case .active:
                // Only trigger authentication if coming from background and vault is selected and locked
                if selectedTab == .vault && vaultManager.isLocked && oldPhase == .background && !vaultManager.isAuthenticating {
                    logger.info("App becoming active, authenticating vault")
                    authenticate()
                }
            @unknown default:
                break
            }
        }
        .onChange(of: isPresentingDocumentPicker) { wasPresenting, isPresenting in
            vaultManager.setDocumentPickerPresented(isPresenting)
        }
        .alert("Authentication Error", isPresented: $showingAuthError) {
            Button("Try Again", action: authenticate)
                .disabled(isLockedOut)
            Button("Cancel", role: .cancel) {
                shouldNavigateBack = true
            }
        } message: {
            Text(errorMessage)
        }
    }
    
    private func authenticate() {
        guard !isLockedOut && !vaultManager.isAuthenticating else { return }
        
        logger.info("Starting vault authentication attempt \(authAttempts + 1) of \(maxAuthAttempts)")
        
        Task {
            do {
                try await vaultManager.unlock()
                // Reset attempts on success
                authAttempts = 0
            } catch VaultError.authenticationCancelled {
                logger.info("Authentication cancelled by user")
                shouldNavigateBack = true
            } catch {
                handleAuthenticationError(error: error)
            }
        }
    }
    
    private func handleAuthenticationError(error: Error) {
        authAttempts += 1
        logger.error("Authentication failed (Attempt \(authAttempts)): \(error.localizedDescription)")
        
        if authAttempts >= maxAuthAttempts {
            handleLockout()
        } else {
            errorMessage = error.localizedDescription
            showingAuthError = true
        }
    }
    
    private func handleLockout() {
        logger.warning("Maximum authentication attempts reached, initiating lockout")
        isLockedOut = true
        errorMessage = "Too many failed attempts. Please try again in 5 minutes."
        showingAuthError = true
        
        lockoutTimer = Timer.scheduledTimer(withTimeInterval: lockoutDuration, repeats: false) { _ in
            logger.info("Lockout period ended")
            isLockedOut = false
            authAttempts = 0
        }
    }
    
    private func lockVault() {
        logger.info("Locking vault")
        vaultManager.lock()
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
    @Binding var isPresentingDocumentPicker: Bool
    
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
                        isPresentingDocumentPicker = true
                    }) {
                        Image(systemName: "plus")
                    }
                }
            }
        }
    }
}

// Placeholder Views
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
