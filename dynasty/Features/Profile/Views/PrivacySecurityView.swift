import SwiftUI
import FirebaseAuth

struct PrivacySecurityDetailView: View {
    @StateObject private var settingsManager = UserSettingsManager.shared
    @State private var showingResetConfirmation = false
    @State private var showingDeleteConfirmation = false
    @State private var showingErrorAlert = false
    @Environment(\.dismiss) private var dismiss
    
    let dataRetentionOptions = ["30 days", "90 days", "1 year", "Forever"]
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                if settingsManager.isLoading {
                    LoadingView(message: "Loading privacy settings...")
                } else {
                    // Location Services
                    SettingsSection(title: "Location") {
                        ToggleSettingRow(
                            icon: "location.fill",
                            title: "Location Services",
                            description: "Allow app to access your location for family tree mapping",
                            color: .blue,
                            isOn: Binding(
                                get: { settingsManager.settings.privacy.locationEnabled },
                                set: { settingsManager.settings.privacy.locationEnabled = $0 }
                            )
                        )
                    }
                    
                    // Security
                    SettingsSection(title: "Security") {
                        VStack(spacing: 8) {
                            ToggleSettingRow(
                                icon: "faceid",
                                title: "Face ID / Touch ID",
                                description: "Use biometric authentication for secure access",
                                color: .green,
                                isOn: Binding(
                                    get: { settingsManager.settings.privacy.faceIDEnabled },
                                    set: { settingsManager.settings.privacy.faceIDEnabled = $0 }
                                )
                            )
                            
                            NavigationLink(destination: ChangePasswordView()) {
                                SettingRow(
                                    icon: "lock.rotation",
                                    title: "Change Password",
                                    description: "Update your account password",
                                    color: .blue
                                )
                            }
                            
                            NavigationLink(destination: TwoFactorAuthView()) {
                                SettingRow(
                                    icon: "shield.lefthalf.fill",
                                    title: "Two-Factor Authentication",
                                    description: "Add an extra layer of security",
                                    color: .green
                                )
                            }
                        }
                    }
                    
                    // Data & Privacy
                    SettingsSection(title: "Data & Privacy") {
                        VStack(spacing: 8) {
                            ToggleSettingRow(
                                icon: "chart.bar.fill",
                                title: "Analytics",
                                description: "Help improve the app by sharing anonymous usage data",
                                color: .orange,
                                isOn: Binding(
                                    get: { settingsManager.settings.privacy.analyticsEnabled },
                                    set: { settingsManager.settings.privacy.analyticsEnabled = $0 }
                                )
                            )
                            
                            PickerSettingRow(
                                icon: "clock.fill",
                                title: "Data Retention",
                                description: "Choose how long to keep your family history data",
                                color: .purple,
                                selection: Binding(
                                    get: { settingsManager.settings.privacy.dataRetention },
                                    set: { settingsManager.settings.privacy.dataRetention = $0 }
                                ),
                                options: dataRetentionOptions
                            )
                            
                            Link(destination: URL(string: "https://dynasty.app/privacy")!) {
                                SettingRow(
                                    icon: "doc.text.fill",
                                    title: "Privacy Policy",
                                    description: "Read our privacy policy",
                                    color: .gray
                                )
                            }
                        }
                    }
                    
                    // Account Actions
                    SettingsSection(title: "Account") {
                        VStack(spacing: 8) {
                            Button(action: { showingResetConfirmation = true }) {
                                SettingRow(
                                    icon: "arrow.counterclockwise",
                                    title: "Reset Settings",
                                    description: "Reset all privacy and security settings to defaults",
                                    color: .orange,
                                    showDisclosure: false
                                )
                            }
                            
                            Button(action: { showingDeleteConfirmation = true }) {
                                SettingRow(
                                    icon: "trash.fill",
                                    title: "Delete Account",
                                    description: "Permanently delete your account and all data",
                                    color: .red,
                                    showDisclosure: false
                                )
                            }
                        }
                    }
                }
            }
            .padding()
        }
        .navigationTitle("Privacy & Security")
        .confirmationDialog(
            title: "Reset Settings",
            message: "Are you sure you want to reset all privacy and security settings to their default values?",
            primaryButtonTitle: "Reset",
            isPresented: $showingResetConfirmation
        ) {
            settingsManager.resetSettings()
        }
        .confirmationDialog(
            title: "Delete Account",
            message: "Are you sure you want to permanently delete your account? This action cannot be undone.",
            primaryButtonTitle: "Delete",
            isPresented: $showingDeleteConfirmation
        ) {
            Task {
                if let user = Auth.auth().currentUser {
                    do {
                        try await user.delete()
                        dismiss()
                    } catch {
                        settingsManager.handleError(error)
                        showingErrorAlert = true
                    }
                }
            }
        }
        .errorOverlay(error: settingsManager.error, isPresented: $showingErrorAlert) {
            Task {
                await settingsManager.loadSettings()
            }
        }
        .onAppear {
            Task {
                await settingsManager.loadSettings()
            }
        }
    }
}

struct ChangePasswordView: View {
    @State private var currentPassword = ""
    @State private var newPassword = ""
    @State private var confirmPassword = ""
    @State private var error: Error?
    @State private var showingErrorAlert = false
    @State private var isLoading = false
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        Form {
            Section(header: Text("Change Password")) {
                SecureField("Current Password", text: $currentPassword)
                    .textContentType(.password)
                SecureField("New Password", text: $newPassword)
                    .textContentType(.newPassword)
                SecureField("Confirm New Password", text: $confirmPassword)
                    .textContentType(.newPassword)
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
        .errorOverlay(error: error, isPresented: $showingErrorAlert) {
            error = nil
        }
    }
    
    private func updatePassword() async {
        guard newPassword == confirmPassword else {
            error = NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "New passwords do not match"])
            showingErrorAlert = true
            return
        }
        
        isLoading = true
        defer { isLoading = false }
        
        guard let user = Auth.auth().currentUser else { return }
        
        do {
            let credential = EmailAuthProvider.credential(
                withEmail: user.email ?? "",
                password: currentPassword
            )
            
            try await user.reauthenticate(with: credential)
            try await user.updatePassword(to: newPassword)
            dismiss()
        } catch {
            self.error = error
            showingErrorAlert = true
        }
    }
}

struct TwoFactorAuthView: View {
    @State private var is2FAEnabled = false
    @State private var verificationCode = ""
    @State private var error: Error?
    @State private var showingErrorAlert = false
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
                        .textContentType(.oneTimeCode)
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
        .errorOverlay(error: error, isPresented: $showingErrorAlert) {
            error = nil
        }
    }
}

#Preview {
    NavigationView {
        PrivacySecurityDetailView()
    }
} 