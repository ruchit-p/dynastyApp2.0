import SwiftUI
import FirebaseAuth
import FirebaseFirestore

@MainActor
class NotificationSettingsViewModel: ObservableObject {
    @Published var pushNotificationsEnabled = true
    @Published var emailNotificationsEnabled = true
    @Published var newMessageNotifications = true
    @Published var mentionNotifications = true
    @Published var friendRequestNotifications = true
    @Published var selectedSound = "Default"
    @Published var error: Error?
    @Published var isLoading = false
    
    private let db = Firestore.firestore()
    
    func saveSettings() async {
        guard let userId = Auth.auth().currentUser?.uid else { return }
        
        do {
            try await db.collection("userSettings").document(userId).setData([
                "notifications": [
                    "pushEnabled": pushNotificationsEnabled,
                    "emailEnabled": emailNotificationsEnabled,
                    "newMessageEnabled": newMessageNotifications,
                    "mentionsEnabled": mentionNotifications,
                    "friendRequestsEnabled": friendRequestNotifications,
                    "sound": selectedSound
                ]
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
            if let data = document.data(),
               let notifications = data["notifications"] as? [String: Any] {
                self.pushNotificationsEnabled = notifications["pushEnabled"] as? Bool ?? true
                self.emailNotificationsEnabled = notifications["emailEnabled"] as? Bool ?? true
                self.newMessageNotifications = notifications["newMessageEnabled"] as? Bool ?? true
                self.mentionNotifications = notifications["mentionsEnabled"] as? Bool ?? true
                self.friendRequestNotifications = notifications["friendRequestsEnabled"] as? Bool ?? true
                self.selectedSound = notifications["sound"] as? String ?? "Default"
            }
        } catch {
            self.error = error
        }
        isLoading = false
    }
}

struct NotificationSettingsView: View {
    @StateObject private var viewModel = NotificationSettingsViewModel()
    @State private var showAlert = false
    @State private var alertMessage = ""
    
    let notificationSounds = ["Default", "Chime", "Bell", "Chirp", "Marimba"]
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                if viewModel.isLoading {
                    ProgressView()
                        .padding()
                } else {
                    // General Notification Settings
                    VStack(spacing: 8) {
                        ToggleSettingRow(
                            icon: "bell.badge.fill",
                            title: "Push Notifications",
                            description: "Receive push notifications on your device",
                            color: .blue,
                            isOn: $viewModel.pushNotificationsEnabled
                        )
                        .onChange(of: viewModel.pushNotificationsEnabled) { oldValue, newValue in
                            Task {
                                await viewModel.saveSettings()
                            }
                        }
                        
                        ToggleSettingRow(
                            icon: "envelope.fill",
                            title: "Email Notifications",
                            description: "Receive notifications via email",
                            color: .green,
                            isOn: $viewModel.emailNotificationsEnabled
                        )
                        .onChange(of: viewModel.emailNotificationsEnabled) { oldValue, newValue in
                            Task {
                                await viewModel.saveSettings()
                            }
                        }
                    }
                    .background(Color(.systemBackground))
                    .cornerRadius(15)
                    
                    // Specific Notification Settings
                    VStack(spacing: 8) {
                        ToggleSettingRow(
                            icon: "message.fill",
                            title: "New Messages",
                            description: "Get notified about new messages",
                            color: .orange,
                            isOn: $viewModel.newMessageNotifications
                        )
                        .onChange(of: viewModel.newMessageNotifications) { oldValue, newValue in
                            Task {
                                await viewModel.saveSettings()
                            }
                        }
                        
                        ToggleSettingRow(
                            icon: "at",
                            title: "Mentions",
                            description: "Get notified when someone mentions you",
                            color: .purple,
                            isOn: $viewModel.mentionNotifications
                        )
                        .onChange(of: viewModel.mentionNotifications) { oldValue, newValue in
                            Task {
                                await viewModel.saveSettings()
                            }
                        }
                        
                        ToggleSettingRow(
                            icon: "person.2.fill",
                            title: "Friend Requests",
                            description: "Get notified about new friend requests",
                            color: .red,
                            isOn: $viewModel.friendRequestNotifications
                        )
                        .onChange(of: viewModel.friendRequestNotifications) { oldValue, newValue in
                            Task {
                                await viewModel.saveSettings()
                            }
                        }
                    }
                    .background(Color(.systemBackground))
                    .cornerRadius(15)
                    
                    // Notification Sound
                    PickerSettingRow(
                        icon: "speaker.wave.2.fill",
                        title: "Notification Sound",
                        description: "Choose your notification sound",
                        color: .blue,
                        selection: Binding(
                            get: { notificationSounds.firstIndex(of: viewModel.selectedSound) ?? 0 },
                            set: { viewModel.selectedSound = notificationSounds[$0] }
                        ),
                        options: notificationSounds
                    )
                    .onChange(of: viewModel.selectedSound) { oldValue, newValue in
                        Task {
                            await viewModel.saveSettings()
                        }
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
        .navigationTitle("Notifications")
        .onAppear {
            Task {
                await viewModel.loadSettings()
            }
        }
    }
}

#Preview {
    NavigationView {
        NotificationSettingsView()
    }
} 