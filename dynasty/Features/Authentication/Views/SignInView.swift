import SwiftUI
import FirebaseAuth
import AuthenticationServices
import CryptoKit
import LocalAuthentication
import os.log

struct SignInView: View {
    @EnvironmentObject private var authManager: AuthManager
    @State private var email: String = ""
    @State private var password: String = ""
    @State private var errorMessage: String?
    @State private var currentNonce: String?
    @State private var showingFaceIDSetup = false
    private let logger = Logger(subsystem: "com.dynasty.SignInView", category: "Authentication")
    
    var body: some View {
        NavigationView {
            VStack {
                // Image at the top
                Image("tree")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(height: 200)
                    .padding(.top, 50)
                
                // Title
                Text("Dynasty")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .padding(.top, 20)
                
                Spacer()
                
                // Email TextField
                TextField("Enter your email", text: $email)
                    .keyboardType(.emailAddress)
                    .autocapitalization(.none)
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(10)
                    .padding(.horizontal, 40)
                    .onAppear {
                        // Pre-fill email if available
                        if let savedEmail = authManager.getLastSignInEmail() {
                            email = savedEmail
                        }
                    }
                
                // Password SecureField
                SecureField("Enter your password", text: $password)
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(10)
                    .padding(.horizontal, 40)
                    .padding(.top, 10)
                
                // Sign in Button
                Button(action: {
                    signIn()
                }) {
                    Text("Sign in")
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.green)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                }
                .padding(.horizontal, 40)
                .padding(.top, 20)
                
                // Sign in with Apple Button
                SignInWithAppleButton(
                    .signIn,
                    onRequest: configureSignInWithApple,
                    onCompletion: handleSignInWithApple
                )
                .signInWithAppleButtonStyle(.black)
                .frame(height: 50)
                .padding(.horizontal, 40)
                .padding(.top, 10)
                
                // Display error message if any
                if let errorMessage = errorMessage {
                    Text(errorMessage)
                        .foregroundColor(.red)
                        .padding(.top, 10)
                }
                
                // Sign up Button
                NavigationLink(destination: SignUpView()) {
                    Text("Sign up")
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.green)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                }
                .padding(.horizontal, 40)
                .padding(.top, 10)
                
                Spacer()
            }
            .navigationBarHidden(true)
            .alert("Enable Face ID", isPresented: $showingFaceIDSetup) {
                Button("Enable") {
                    authManager.enableFaceID()
                }
                Button("Not Now", role: .cancel) { }
            } message: {
                Text("Would you like to enable Face ID for quick sign-in next time?")
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemBackground))
        .onAppear {
            // Check if Face ID is enabled and try to authenticate
            if authManager.isFaceIDEnabled() {
                authenticateWithFaceID()
            }
        }
    }
    
    private func authenticateWithFaceID() {
        let context = LAContext()
        var error: NSError?
        
        if context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) {
            context.evaluatePolicy(.deviceOwnerAuthenticationWithBiometrics,
                                 localizedReason: "Sign in to Dynasty") { success, error in
                if success {
                    // If we have saved email, try to sign in
                    if let savedEmail = authManager.getLastSignInEmail() {
                        email = savedEmail
                        // Note: Password should be handled securely through Keychain
                        // For now, user will need to enter password
                    }
                }
            }
        }
    }
    
    // Function to handle email/password sign-in
    private func signIn() {
        Task {
            do {
                try await authManager.signIn(email: email, password: password)
            } catch let error as AuthError {
                errorMessage = error.description
            } catch {
                errorMessage = "An unexpected error occurred"
            }
        }
    }
    
    // Configure the Sign in with Apple request
    private func configureSignInWithApple(_ request: ASAuthorizationAppleIDRequest) {
        let nonce = randomNonceString()
        currentNonce = nonce
        request.requestedScopes = [.fullName, .email]
        request.nonce = sha256(nonce)
    }
    
    // Handle the Sign in with Apple completion
    private func handleSignInWithApple(_ result: Result<ASAuthorization, Error>) {
        switch result {
        case .success(let authResults):
            logger.info("Apple Sign In authorization successful")
            
            // Validate Apple ID Credential
            guard let appleIDCredential = authResults.credential as? ASAuthorizationAppleIDCredential else {
                logger.error("Failed to get Apple ID credential")
                errorMessage = "Unable to access Apple ID credentials"
                return
            }
            
            // Validate nonce
            guard let nonce = currentNonce else {
                logger.error("Invalid state: Missing nonce")
                errorMessage = "An error occurred during authentication"
                return
            }
            
            // Validate identity token
            guard let appleIDToken = appleIDCredential.identityToken else {
                logger.error("Failed to get identity token")
                errorMessage = "Unable to verify identity with Apple"
                return
            }
            
            // Convert token to string
            guard let idTokenString = String(data: appleIDToken, encoding: .utf8) else {
                logger.error("Failed to convert identity token to string")
                errorMessage = "Unable to process authentication data"
                return
            }
            
            logger.info("Got Apple ID credentials, creating Firebase credential")
            
            // Log user information (safely)
            if let email = appleIDCredential.email {
                logger.info("User email provided: \(email)")
            } else {
                logger.info("No email provided (might be private relay)")
            }
            
            if let fullName = appleIDCredential.fullName {
                logger.info("User name provided: \(fullName.givenName ?? "") \(fullName.familyName ?? "")")
            } else {
                logger.info("No name information provided")
            }
            
            // Create the Firebase credential
            let credential = OAuthProvider.credential(
                providerID: AuthProviderID.apple,
                idToken: idTokenString,
                rawNonce: nonce,
                accessToken: nil
            )
            
            Task {
                do {
                    logger.info("Attempting to sign in with Apple credential")
                    try await authManager.signInWithApple(credential: credential)
                    logger.info("Apple Sign In successful")
                    
                    // Check if this was first time sign in
                    if appleIDCredential.email != nil {
                        logger.info("First time Apple Sign In detected")
                        // Show Face ID setup prompt if needed
                        if !authManager.isFaceIDEnabled() {
                            showingFaceIDSetup = true
                        }
                    }
                    
                } catch let error as AuthError {
                    logger.error("Apple Sign In failed with AuthError: \(error.description)")
                    errorMessage = error.description
                } catch {
                    logger.error("Apple Sign In failed with unexpected error: \(error.localizedDescription)")
                    errorMessage = "An unexpected error occurred during sign in"
                }
            }
            
        case .failure(let error as ASAuthorizationError):
            // Handle ASAuthorizationError specifically
            switch error.code {
            case .canceled:
                logger.info("User cancelled Apple Sign In")
                errorMessage = "Sign in was cancelled"
            case .invalidResponse:
                logger.error("Invalid response during Apple Sign In")
                errorMessage = "Invalid response received"
            case .failed:
                logger.error("Apple Sign In failed")
                errorMessage = "Sign in failed"
            case .notHandled:
                logger.error("Apple Sign In not handled")
                errorMessage = "Sign in request not handled"
            case .unknown:
                logger.error("Unknown Apple Sign In error")
                errorMessage = "An unknown error occurred"
            case .notInteractive:
                logger.error("Sign in requires user interaction")
                errorMessage = "Sign in requires user interaction"
            case .matchedExcludedCredential:
                logger.error("Credential matches an excluded one")
                errorMessage = "This credential cannot be used"
            @unknown default:
                logger.error("Unexpected Apple Sign In error: \(error.localizedDescription)")
                errorMessage = "An unexpected error occurred"
            }
        case .failure(let error):
            logger.error("Apple Sign In failed with error: \(error.localizedDescription)")
            errorMessage = "Sign in failed: \(error.localizedDescription)"
        }
    }
    
    // Generates a cryptographically secure random nonce string
    private func randomNonceString(length: Int = 32) -> String {
        precondition(length > 0)
        var randomBytes = [UInt8](repeating: 0, count: length)
        let errorCode = SecRandomCopyBytes(kSecRandomDefault, randomBytes.count, &randomBytes)
        if errorCode != errSecSuccess {
            fatalError("Unable to generate nonce. SecRandomCopyBytes failed with OSStatus \(errorCode)")
        }

        let charset: [Character] = Array("0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._")
        let nonce = randomBytes.map { byte in
            charset[Int(byte) % charset.count]
        }
        return String(nonce)
    }
    
    // Hashes the nonce using SHA256
    private func sha256(_ input: String) -> String {
        let inputData = Data(input.utf8)
        let hashedData = SHA256.hash(data: inputData)
        let hashString = hashedData.compactMap {
            String(format: "%02x", $0)
        }.joined()
        return hashString
    }
}

#Preview {
    SignInView()
} 
