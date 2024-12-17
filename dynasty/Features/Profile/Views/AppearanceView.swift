import SwiftUI

struct AppearanceSettingsView: View {
    @StateObject private var settingsManager = UserSettingsManager.shared
    @State private var showingResetConfirmation = false
    @State private var showingErrorAlert = false
    
    let themes = ["System", "Light", "Dark"]
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                if settingsManager.isLoading {
                    LoadingView(message: "Loading appearance settings...")
                } else {
                    // Theme Selection
                    SettingsSection(title: "Theme") {
                        PickerSettingRow(
                            icon: "paintbrush.fill",
                            title: "App Theme",
                            description: "Choose your preferred app theme",
                            color: .blue,
                            selection: Binding(
                                get: { settingsManager.settings.appearance.theme },
                                set: { settingsManager.settings.appearance.theme = $0 }
                            ),
                            options: themes
                        )
                    }
                    
                    // Text Size
                    SettingsSection(title: "Text") {
                        VStack(spacing: 16) {
                            ToggleSettingRow(
                                icon: "textformat.size",
                                title: "Bold Text",
                                description: "Make text bold throughout the app",
                                color: .green,
                                isOn: Binding(
                                    get: { settingsManager.settings.appearance.boldText },
                                    set: { settingsManager.settings.appearance.boldText = $0 }
                                )
                            )
                            
                            VStack(alignment: .leading, spacing: 8) {
                                HStack {
                                    Image(systemName: "textformat")
                                        .foregroundColor(.orange)
                                        .frame(width: 30)
                                    
                                    Text("Text Size")
                                        .font(.headline)
                                }
                                
                                HStack {
                                    Text("A")
                                        .font(.system(size: 12))
                                    Slider(
                                        value: Binding(
                                            get: { settingsManager.settings.appearance.textSize },
                                            set: { settingsManager.settings.appearance.textSize = $0 }
                                        ),
                                        in: 0.8...1.4,
                                        step: 0.1
                                    )
                                    Text("A")
                                        .font(.system(size: 24))
                                }
                            }
                            .padding()
                            .background(Color(.systemGray6))
                            .cornerRadius(10)
                        }
                    }
                    
                    // Accessibility
                    SettingsSection(title: "Accessibility") {
                        VStack(spacing: 8) {
                            ToggleSettingRow(
                                icon: "circle.lefthalf.fill",
                                title: "Increase Contrast",
                                description: "Enhance visual contrast for better readability",
                                color: .purple,
                                isOn: Binding(
                                    get: { settingsManager.settings.appearance.highContrast },
                                    set: { settingsManager.settings.appearance.highContrast = $0 }
                                )
                            )
                            
                            ToggleSettingRow(
                                icon: "square.fill.on.square",
                                title: "Reduce Transparency",
                                description: "Reduce transparency effects",
                                color: .red,
                                isOn: Binding(
                                    get: { settingsManager.settings.appearance.reduceTransparency },
                                    set: { settingsManager.settings.appearance.reduceTransparency = $0 }
                                )
                            )
                        }
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
        .navigationTitle("Appearance")
        .confirmationDialog(
            title: "Reset Settings",
            message: "Are you sure you want to reset all appearance settings to their default values?",
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
        AppearanceSettingsView()
    }
} 