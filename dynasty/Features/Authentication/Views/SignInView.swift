import SwiftUI
import FirebaseAuth

struct SignInView: View {
    @EnvironmentObject private var authManager: AuthManager
    @State private var email: String = ""
    @State private var password: String = ""
    @State private var errorMessage: String?

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
}

#Preview {
    SignInView()
} 
