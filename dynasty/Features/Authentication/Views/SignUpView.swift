import SwiftUI
import FirebaseAuth
import AuthenticationServices
import FirebaseFirestore
import Firebase

struct SignUpView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var authManager: AuthManager
    @State private var firstName: String = ""
    @State private var lastName: String = ""
    @State private var phoneNumber: String = ""
    @State private var email: String = ""
    @State private var password: String = ""
    @State private var dateOfBirth: Date = Date()
    @State private var errorMessage: String?
    @State private var referralCode: String = ""
    @State private var isLoading = false

    var body: some View {
        VStack {
            // Title
            Text("Sign Up")
                .font(.largeTitle)
                .fontWeight(.bold)
                .padding(.top, 50)
            
            Spacer()
            
            // TextFields for user input
            Group {
                TextField("First Name", text: $firstName)
                TextField("Last Name", text: $lastName)
                TextField("Email", text: $email)
                    .keyboardType(.emailAddress)
                SecureField("Password", text: $password)
            }
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(10)
            .padding(.horizontal, 40)
            .padding(.top, 10)
            
            // Phone Number TextField
            TextField("Enter your phone number", text: $phoneNumber)
                .keyboardType(.phonePad)
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(10)
                .padding(.horizontal, 40)
                .padding(.top, 10)
            
            // Add the DatePicker
            DatePicker("Date of Birth", selection: $dateOfBirth, displayedComponents: .date)
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(10)
                .padding(.horizontal, 40)
                .padding(.top, 10)
            
            // Referral Code TextField
            TextField("Referral Code (if any)", text: $referralCode)
                .autocapitalization(.none)
                .disableAutocorrection(true)
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(10)
                .padding(.horizontal, 40)
                .padding(.top, 10)
            
            // Sign Up Button
            Button(action: signUp) {
                if isLoading {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                } else {
                    Text("Sign Up")
                }
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(Color.green)
            .foregroundColor(.white)
            .cornerRadius(10)
            .padding(.horizontal, 40)
            .padding(.top, 20)
            .disabled(isLoading)
            
            // Display error message if any
            if let errorMessage = errorMessage {
                Text(errorMessage)
                    .foregroundColor(.red)
                    .padding(.top, 10)
            }
            
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemBackground))
        .navigationBarTitle("Sign Up", displayMode: .inline)
    }
    
    private func signUp() {
        isLoading = true
        errorMessage = nil
        
        Task {
            do {
                try await authManager.signUp(
                    email: email,
                    password: password,
                    firstName: firstName,
                    lastName: lastName,
                    phoneNumber: phoneNumber,
                    dateOfBirth: dateOfBirth,
                    referralCode: referralCode.isEmpty ? nil : referralCode
                )
                
                isLoading = false
            } catch let error as AuthError {
                isLoading = false
                errorMessage = error.description
            } catch {
                isLoading = false
                errorMessage = "An unexpected error occurred"
            }
        }
    }
}

#Preview {
    SignUpView()
}
