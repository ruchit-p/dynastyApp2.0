import SwiftUI
import FirebaseAuth
import FirebaseFirestore

@MainActor
class PrivacySecurityViewModel: ObservableObject {
    @Published var isLocationEnabled = false
    @Published var isFaceIDEnabled = true
    @Published var isAnalyticsEnabled = true
    @Published var selectedDataRetention = 1
    @Published var error: Error?
    @Published var isLoading = false
    
    private let db = Firestore.firestore()
    
    func saveSettings() async {
        guard let userId = Auth.auth().currentUser?.uid else { return }
        
        do {
            try await db.collection("userSettings").document(userId).setData([
                "locationEnabled": isLocationEnabled,
                "faceIDEnabled": isFaceIDEnabled,
                "analyticsEnabled": isAnalyticsEnabled,
                "dataRetention": selectedDataRetention
            ], merge: true)
        } catch {
            self.error = error
        }
    }
    
    func loadSettings() async {
        guard let userId = Auth.auth().currentUser?.uid else { return }
        isLoading = true
        
        do {
            let document = try await db.collection("userSettings").document(userId).getDocument()
            if let data = document.data() {
                self.isLocationEnabled = data["locationEnabled"] as? Bool ?? false
                self.isFaceIDEnabled = data["faceIDEnabled"] as? Bool ?? true
                self.isAnalyticsEnabled = data["analyticsEnabled"] as? Bool ?? true
                self.selectedDataRetention = data["dataRetention"] as? Int ?? 1
            }
        } catch {
            self.error = error
        }
        isLoading = false
    }
    
    func deleteAccount() async -> Bool {
        guard let user = Auth.auth().currentUser else { return false }
        
        do {
            // Delete user data from Firestore
            try await db.collection("users").document(user.uid).delete()
            try await db.collection("userSettings").document(user.uid).delete()
            
            // Delete Firebase Auth account
            try await user.delete()
            return true
        } catch {
            self.error = error
            return false
        }
    }
}

struct PrivacySecurityDetailView: View {
    @StateObject private var viewModel = PrivacySecurityViewModel()
    @Environment(\.dismiss) private var dismiss
    
    let dataRetentionOptions = ["30 days", "90 days", "1 year", "Forever"]
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                if viewModel.isLoading {
                    ProgressView()
                        .padding()
                } else {
                    // Location Services
                    ToggleSettingRow(
                        icon: "location.fill",
                        title: "Location Services",
                        description: "Allow app to access your location for family tree mapping",
                        color: .blue,
                        isOn: $viewModel.isLocationEnabled
                    )
                    .onChange(of: viewModel.isLocationEnabled) { oldValue, newValue in
                        Task {
                            await viewModel.saveSettings()
                        }
                    }
                    
                    // Face ID / Touch ID
                    ToggleSettingRow(
                        icon: "faceid",
                        title: "Face ID / Touch ID",
                        description: "Use biometric authentication for secure access",
                        color: .green,
                        isOn: $viewModel.isFaceIDEnabled
                    )
                    .onChange(of: viewModel.isFaceIDEnabled) { oldValue, newValue in
                        Task {
                            await viewModel.saveSettings()
                        }
                    }
                    
                    // Analytics
                    ToggleSettingRow(
                        icon: "chart.bar.fill",
                        title: "Analytics",
                        description: "Help improve the app by sharing anonymous usage data",
                        color: .orange,
                        isOn: $viewModel.isAnalyticsEnabled
                    )
                    .onChange(of: viewModel.isAnalyticsEnabled) { oldValue, newValue in
                        Task {
                            await viewModel.saveSettings()
                        }
                    }
                    
                    // Data Retention
                    PickerSettingRow(
                        icon: "clock.fill",
                        title: "Data Retention",
                        description: "Choose how long to keep your family history data",
                        color: .purple,
                        selection: $viewModel.selectedDataRetention,
                        options: dataRetentionOptions
                    )
                    .onChange(of: viewModel.selectedDataRetention) { oldValue, newValue in
                        Task {
                            await viewModel.saveSettings()
                        }
                    }
                    
                    // Change Password
                    NavigationLink(destination: ChangePasswordView()) {
                        SettingRow(
                            icon: "lock.rotation",
                            title: "Change Password",
                            description: "Update your account password",
                            color: .blue
                        )
                    }
                    
                    // Two-Factor Authentication
                    NavigationLink(destination: TwoFactorAuthView()) {
                        SettingRow(
                            icon: "shield.lefthalf.fill",
                            title: "Two-Factor Authentication",
                            description: "Add an extra layer of security",
                            color: .green
                        )
                    }
                    
                    // Privacy Policy
                    Link(destination: URL(string: "https://example.com/privacy-policy")!) {
                        SettingRow(
                            icon: "doc.text.fill",
                            title: "Privacy Policy",
                            description: "Read our privacy policy",
                            color: .gray
                        )
                    }
                    
                    // Delete Account
                    Button(action: {
                        Task {
                            if await viewModel.deleteAccount() {
                                dismiss()
                            }
                        }
                    }) {
                        SettingRow(
                            icon: "trash.fill",
                            title: "Delete Account",
                            description: "Permanently delete your account and all data",
                            color: .red
                        )
                    }
                }
                
                if let error = viewModel.error {
                    Text(error.localizedDescription)
                        .foregroundColor(.red)
                        .padding()
                }
            }
            .padding()
        }
        .navigationTitle("Privacy & Security")
        .onAppear {
            Task {
                await viewModel.loadSettings()
            }
        }
    }
}

struct ToggleSettingRow: View {
    let icon: String
    let title: String
    let description: String
    let color: Color
    @Binding var isOn: Bool
    
    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(color)
                .frame(width: 30)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .foregroundColor(.primary)
                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Toggle("", isOn: $isOn)
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(10)
    }
}

struct PickerSettingRow: View {
    let icon: String
    let title: String
    let description: String
    let color: Color
    @Binding var selection: Int
    let options: [String]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(color)
                    .frame(width: 30)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .foregroundColor(.primary)
                    Text(description)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            Picker(selection: $selection, label: Text("")) {
                ForEach(Array(options.enumerated()), id: \.offset) { index, option in
                    Text(option).tag(index)
                }
            }
            .pickerStyle(SegmentedPickerStyle())
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(10)
    }
}

struct SettingRow: View {
    let icon: String
    let title: String
    let description: String
    let color: Color
    
    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(color)
                .frame(width: 30)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .foregroundColor(.primary)
                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Image(systemName: "chevron.right")
                .foregroundColor(.gray)
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(10)
    }
}

struct ChangePasswordView: View {
    @State private var currentPassword = ""
    @State private var newPassword = ""
    @State private var confirmPassword = ""
    @State private var error: Error?
    @State private var showAlert = false
    @State private var isLoading = false
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        Form {
            Section(header: Text("Change Password")) {
                SecureField("Current Password", text: $currentPassword)
                SecureField("New Password", text: $newPassword)
                SecureField("Confirm New Password", text: $confirmPassword)
            }
            
            Section {
                Button(action: {
                    Task {
                        await updatePassword()
                    }
                }) {
                    if isLoading {
                        ProgressView()
                    } else {
                        Text("Update Password")
                    }
                }
                .disabled(currentPassword.isEmpty || newPassword.isEmpty || confirmPassword.isEmpty || isLoading)
            }
        }
        .navigationTitle("Change Password")
        .alert(isPresented: $showAlert) {
            Alert(
                title: Text("Error"),
                message: Text(error?.localizedDescription ?? "An error occurred"),
                dismissButton: .default(Text("OK"))
            )
        }
    }
    
    private func updatePassword() async {
        guard newPassword == confirmPassword else {
            error = NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "New passwords do not match"])
            showAlert = true
            return
        }
        
        isLoading = true
        
        guard let user = Auth.auth().currentUser else {
            isLoading = false
            return
        }
        
        let credential = EmailAuthProvider.credential(
            withEmail: user.email ?? "",
            password: currentPassword
        )
        
        do {
            try await user.reauthenticate(with: credential)
            try await user.updatePassword(to: newPassword)
            dismiss()
        } catch {
            self.error = error
            showAlert = true
        }
        
        isLoading = false
    }
}

struct TwoFactorAuthView: View {
    @State private var is2FAEnabled = false
    @State private var verificationCode = ""
    @State private var error: Error?
    @State private var showAlert = false
    @State private var isLoading = false
    
    var body: some View {
        Form {
            Section(header: Text("Two-Factor Authentication")) {
                Toggle("Enable 2FA", isOn: $is2FAEnabled)
                    .onChange(of: is2FAEnabled) { oldValue, newValue in
                        // Handle 2FA toggle
                    }
                
                if is2FAEnabled {
                    SecureField("Verification Code", text: $verificationCode)
                    Button("Verify") {
                        // Handle verification
                    }
                    .disabled(verificationCode.isEmpty)
                }
            }
            
            Section(header: Text("Info")) {
                Text("Two-factor authentication adds an extra layer of security to your account by requiring a verification code in addition to your password.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .navigationTitle("Two-Factor Authentication")
        .alert(isPresented: $showAlert) {
            Alert(
                title: Text("Error"),
                message: Text(error?.localizedDescription ?? "An error occurred"),
                dismissButton: .default(Text("OK"))
            )
        }
    }
}

#Preview {
    NavigationView {
        PrivacySecurityDetailView()
    }
} 