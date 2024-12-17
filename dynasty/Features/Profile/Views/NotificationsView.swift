import SwiftUI

struct NotificationSettingsView: View {
    @StateObject private var settingsManager = UserSettingsManager.shared
    @State private var showingResetConfirmation = false
    @State private var showingErrorAlert = false
    
    let notificationSounds = ["Default", "Chime", "Bell", "Chirp", "Marimba"]
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                if settingsManager.isLoading {
                    LoadingView(message: "Loading notification settings...")
                } else {
                    // General Notification Settings
                    SettingsSection(title: "General") {
                        VStack(spacing: 8) {
                            ToggleSettingRow(
                                icon: "bell.badge.fill",
                                title: "Push Notifications",
                                description: "Receive push notifications on your device",
                                color: .blue,
                                isOn: Binding(
                                    get: { settingsManager.settings.notifications.pushEnabled },
                                    set: { settingsManager.settings.notifications.pushEnabled = $0 }
                                )
                            )
                            
                            ToggleSettingRow(
                                icon: "envelope.fill",
                                title: "Email Notifications",
                                description: "Receive notifications via email",
                                color: .green,
                                isOn: Binding(
                                    get: { settingsManager.settings.notifications.emailEnabled },
                                    set: { settingsManager.settings.notifications.emailEnabled = $0 }
                                )
                            )
                        }
                    }
                    
                    // Notification Types
                    SettingsSection(title: "Notification Types") {
                        VStack(spacing: 8) {
                            ToggleSettingRow(
                                icon: "message.fill",
                                title: "New Messages",
                                description: "Get notified about new messages",
                                color: .orange,
                                isOn: Binding(
                                    get: { settingsManager.settings.notifications.newMessageEnabled },
                                    set: { settingsManager.settings.notifications.newMessageEnabled = $0 }
                                )
                            )
                            
                            ToggleSettingRow(
                                icon: "at",
                                title: "Mentions",
                                description: "Get notified when someone mentions you",
                                color: .purple,
                                isOn: Binding(
                                    get: { settingsManager.settings.notifications.mentionsEnabled },
                                    set: { settingsManager.settings.notifications.mentionsEnabled = $0 }
                                )
                            )
                            
                            ToggleSettingRow(
                                icon: "person.2.fill",
                                title: "Friend Requests",
                                description: "Get notified about new friend requests",
                                color: .red,
                                isOn: Binding(
                                    get: { settingsManager.settings.notifications.friendRequestsEnabled },
                                    set: { settingsManager.settings.notifications.friendRequestsEnabled = $0 }
                                )
                            )
                        }
                    }
                    
                    // Sound Settings
                    SettingsSection(title: "Sound") {
                        PickerSettingRow(
                            icon: "speaker.wave.2.fill",
                            title: "Notification Sound",
                            description: "Choose your notification sound",
                            color: .blue,
                            selection: Binding(
                                get: { notificationSounds.firstIndex(of: settingsManager.settings.notifications.sound) ?? 0 },
                                set: { settingsManager.settings.notifications.sound = notificationSounds[$0] }
                            ),
                            options: notificationSounds
                        )
                    }
                    
                    // Reset Button
                    Button(action: { showingResetConfirmation = true }) {
                        Text("Reset to Defaults")
                            .foregroundColor(.red)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color(.systemGray6))
                            .cornerRadius(10)
                    }
                }
            }
            .padding()
        }
        .navigationTitle("Notifications")
        .confirmationDialog(
            title: "Reset Settings",
            message: "Are you sure you want to reset all notification settings to their default values?",
            primaryButtonTitle: "Reset",
            isPresented: $showingResetConfirmation
        ) {
            settingsManager.resetSettings()
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

#Preview {
    NavigationView {
        NotificationSettingsView()
    }
} 