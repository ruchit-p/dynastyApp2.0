import SwiftUI
import FirebaseAuth
import FirebaseFirestore

@MainActor
class AppearanceViewModel: ObservableObject {
    @Published var selectedTheme = 0
    @Published var textSize = 1.0
    @Published var boldText = false
    @Published var highContrast = false
    @Published var reduceTransparency = false
    @Published var error: Error?
    @Published var isLoading = false
    
    private let db = Firestore.firestore()
    
    func saveSettings() async {
        guard let userId = Auth.auth().currentUser?.uid else { return }
        
        do {
            try await db.collection("userSettings").document(userId).setData([
                "appearance": [
                    "theme": selectedTheme,
                    "textSize": textSize,
                    "boldText": boldText,
                    "highContrast": highContrast,
                    "reduceTransparency": reduceTransparency
                ]
            ], merge: true)
            
            // Apply settings immediately
            applySettings()
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
               let appearance = data["appearance"] as? [String: Any] {
                self.selectedTheme = appearance["theme"] as? Int ?? 0
                self.textSize = appearance["textSize"] as? Double ?? 1.0
                self.boldText = appearance["boldText"] as? Bool ?? false
                self.highContrast = appearance["highContrast"] as? Bool ?? false
                self.reduceTransparency = appearance["reduceTransparency"] as? Bool ?? false
                
                // Apply loaded settings
                applySettings()
            }
        } catch {
            self.error = error
        }
        isLoading = false
    }
    
    private func applySettings() {
        // Here you would implement the actual application of settings
        // For example:
        UserDefaults.standard.set(selectedTheme, forKey: "AppTheme")
        UserDefaults.standard.set(textSize, forKey: "TextSize")
        UserDefaults.standard.set(boldText, forKey: "BoldText")
        UserDefaults.standard.set(highContrast, forKey: "HighContrast")
        UserDefaults.standard.set(reduceTransparency, forKey: "ReduceTransparency")
    }
}

struct AppearanceSettingsView: View {
    @StateObject private var viewModel = AppearanceViewModel()
    @State private var showAlert = false
    @State private var alertMessage = ""
    
    let themes = ["System", "Light", "Dark"]
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                if viewModel.isLoading {
                    ProgressView()
                        .padding()
                } else {
                    // Theme Selection
                    PickerSettingRow(
                        icon: "paintbrush.fill",
                        title: "Theme",
                        description: "Choose your preferred app theme",
                        color: .blue,
                        selection: $viewModel.selectedTheme,
                        options: themes
                    )
                    .onChange(of: viewModel.selectedTheme) { oldValue, newValue in
                        Task {
                            await viewModel.saveSettings()
                        }
                    }
                    
                    // Text Size
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Image(systemName: "textformat.size")
                                .foregroundColor(.green)
                                .frame(width: 30)
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Text Size")
                                    .font(.headline)
                                Text("Adjust the size of text throughout the app")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                        
                        HStack {
                            Text("A")
                                .font(.system(size: 12))
                            Slider(value: $viewModel.textSize, in: 0.8...1.4, step: 0.1)
                                .onChange(of: viewModel.textSize) { oldValue, newValue in
                                    Task {
                                        await viewModel.saveSettings()
                                    }
                                }
                            Text("A")
                                .font(.system(size: 24))
                        }
                    }
                    .padding()
                    .background(Color(.systemBackground))
                    .cornerRadius(15)
                    
                    // Accessibility Options
                    VStack(spacing: 8) {
                        ToggleSettingRow(
                            icon: "bold",
                            title: "Bold Text",
                            description: "Make text bold throughout the app",
                            color: .orange,
                            isOn: $viewModel.boldText
                        )
                        .onChange(of: viewModel.boldText) { oldValue, newValue in
                            Task {
                                await viewModel.saveSettings()
                            }
                        }
                        
                        ToggleSettingRow(
                            icon: "circle.lefthalf.fill",
                            title: "Increase Contrast",
                            description: "Enhance visual contrast for better readability",
                            color: .purple,
                            isOn: $viewModel.highContrast
                        )
                        .onChange(of: viewModel.highContrast) { oldValue, newValue in
                            Task {
                                await viewModel.saveSettings()
                            }
                        }
                        
                        ToggleSettingRow(
                            icon: "square.fill.on.square",
                            title: "Reduce Transparency",
                            description: "Reduce transparency effects",
                            color: .red,
                            isOn: $viewModel.reduceTransparency
                        )
                        .onChange(of: viewModel.reduceTransparency) { oldValue, newValue in
                            Task {
                                await viewModel.saveSettings()
                            }
                        }
                    }
                    .background(Color(.systemBackground))
                    .cornerRadius(15)
                }
                
                if let error = viewModel.error {
                    Text(error.localizedDescription)
                        .foregroundColor(.red)
                        .padding()
                }
            }
            .padding()
        }
        .navigationTitle("Appearance")
        .onAppear {
            Task {
                await viewModel.loadSettings()
            }
        }
    }
}

#Preview {
    NavigationView {
        AppearanceSettingsView()
    }
} 