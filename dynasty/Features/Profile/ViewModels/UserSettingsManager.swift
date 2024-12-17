import SwiftUI
import FirebaseFirestore
import FirebaseAuth
import Combine

@MainActor
class UserSettingsManager: ObservableObject {
    static let shared = UserSettingsManager()
    
    @Published var settings: UserSettings = UserSettings()
    @Published var isLoading = false
    @Published var error: Error?
    
    private let db = FirestoreManager.shared.getDB()
    private var cancellables = Set<AnyCancellable>()
    private let debounceInterval: TimeInterval = 0.5
    
    private init() {
        setupDebounce()
    }
    
    struct UserSettings: Codable {
        var appearance: AppearanceSettings = AppearanceSettings()
        var notifications: NotificationSettings = NotificationSettings()
        var privacy: PrivacySettings = PrivacySettings()
        
        struct AppearanceSettings: Codable {
            var theme: Int = 0
            var textSize: Double = 1.0
            var boldText: Bool = false
            var highContrast: Bool = false
            var reduceTransparency: Bool = false
        }
        
        struct NotificationSettings: Codable {
            var pushEnabled: Bool = true
            var emailEnabled: Bool = true
            var newMessageEnabled: Bool = true
            var mentionsEnabled: Bool = true
            var friendRequestsEnabled: Bool = true
            var sound: String = "Default"
        }
        
        struct PrivacySettings: Codable {
            var locationEnabled: Bool = false
            var faceIDEnabled: Bool = true
            var analyticsEnabled: Bool = true
            var dataRetention: Int = 1
        }
    }
    
    private func setupDebounce() {
        $settings
            .debounce(for: .seconds(debounceInterval), scheduler: RunLoop.main)
            .sink { [weak self] settings in
                Task {
                    try? await self?.saveSettings(settings)
                }
            }
            .store(in: &cancellables)
    }
    
    func loadSettings() async {
        guard let userId = Auth.auth().currentUser?.uid else { return }
        isLoading = true
        
        do {
            let document = try await db.collection("userSettings").document(userId).getDocument()
            if let data = document.data() {
                let jsonData = try JSONSerialization.data(withJSONObject: data)
                let settings = try JSONDecoder().decode(UserSettings.self, from: jsonData)
                await MainActor.run {
                    self.settings = settings
                }
            }
        } catch {
            self.error = error
        }
        
        isLoading = false
    }
    
    private func saveSettings(_ settings: UserSettings) async throws {
        guard let userId = Auth.auth().currentUser?.uid else { return }
        
        let encoder = JSONEncoder()
        let data = try encoder.encode(settings)
        guard let dictionary = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw NSError(domain: "UserSettingsManager", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to encode settings"])
        }
        
        try await db.collection("userSettings").document(userId).setData(dictionary, merge: true)
    }
    
    func resetSettings() {
        settings = UserSettings()
    }
    
    func handleError(_ error: Error) {
        self.error = error
        // Here you could also log to analytics/crash reporting
        print("UserSettingsManager error: \(error.localizedDescription)")
    }
} 