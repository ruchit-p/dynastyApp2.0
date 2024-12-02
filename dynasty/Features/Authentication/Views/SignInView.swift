import SwiftUI
import FirebaseAuth
import AuthenticationServices
import CryptoKit

struct SignInView: View {
    @EnvironmentObject private var authManager: AuthManager
    @State private var email: String = ""
    @State private var password: String = ""
    @State private var errorMessage: String?
    @State private var currentNonce: String?
    
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
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(10)
                    .padding(.horizontal, 40)
                
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
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemBackground))
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
            if let appleIDCredential = authResults.credential as? ASAuthorizationAppleIDCredential,
               let nonce = currentNonce,
               let appleIDToken = appleIDCredential.identityToken,
               let idTokenString = String(data: appleIDToken, encoding: .utf8) {
                
                let credential = OAuthProvider.credential(
                    withProviderID: "apple.com",
                    idToken: idTokenString,
                    rawNonce: nonce
                )
                
                Task {
                    do {
                        try await authManager.signInWithApple(credential: credential)
                    } catch {
                        errorMessage = error.localizedDescription
                    }
                }
            }
        case .failure(let error):
            errorMessage = error.localizedDescription
        }
    }
    
    // Generates a random nonce string
    @available(iOS 13, *)
    private func randomNonceString(length: Int = 32) -> String {
        let characters = "0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz-._"
        var nonce = ""
        for _ in 0..<length {
            let randomIndex = Int.random(in: 0..<characters.count)
            let randomCharacter = characters[characters.index(characters.startIndex, offsetBy: randomIndex)]
            nonce.append(randomCharacter)
        }
        return nonce
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
