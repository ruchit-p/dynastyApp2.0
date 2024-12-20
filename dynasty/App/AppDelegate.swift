import UIKit
import FirebaseCore
import FirebaseFirestore
import FirebaseAuth
import FirebaseStorage
import FirebaseAnalytics

class AppDelegate: NSObject, UIApplicationDelegate {
    func application(
        _ application: UIApplication, 
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
        FirebaseApp.configure()
        
        // Enable analytics data collection
        Analytics.setAnalyticsCollectionEnabled(true)
        
        // Set default event parameters
        Analytics.setDefaultEventParameters([
            "app_version": Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "unknown",
            "os_version": UIDevice.current.systemVersion
        ])
        
        return true
    }
    
    func applicationWillTerminate(_ application: UIApplication) {
        saveLastKnownState()
        cleanupTemporaryResources()
        performFinalSync()
    }
    
    private func saveLastKnownState() {
        let defaults = UserDefaults.standard
        
        if let currentUser = Auth.auth().currentUser {
            Firestore.firestore()
                .collection("users")
                .document(currentUser.uid)
                .getDocument { (document, error) in
                    if let error = error {
                        print("Error fetching user document: \(error.localizedDescription)")
                        return
                    }
                    
                    guard let document = document, document.exists else {
                        print("User document does not exist.")
                        return
                    }
                    
                    if let familyTreeID = document.data()?["familyTreeID"] as? String {
                        defaults.set(familyTreeID, forKey: Constants.UserDefaults.lastActiveFamilyTreeID)
                        defaults.synchronize()
                    } else {
                        print("FamilyTreeID not found in user document.")
                    }
                }
        } else {
            print("No authenticated user.")
        }
    }
    
    private func cleanupTemporaryResources() {
        let fileManager = FileManager.default
        if let tempFolderURL = try? fileManager.url(
            for: .cachesDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: false
        ) {
            try? fileManager.removeItem(at: tempFolderURL)
        }
    }
    
    private func performFinalSync() {
        guard let currentUser = Auth.auth().currentUser else { return }
        
        let group = DispatchGroup()
        group.enter()
        
        let db = Firestore.firestore()
        db.collection("users")
            .document(currentUser.uid)
            .updateData([
                "lastActiveTimestamp": FieldValue.serverTimestamp(),
                "isOnline": false,
                "lastUpdateType": "logout",
                "deviceInfo": UIDevice.current.systemVersion
            ]) { error in
                if let error = error {
                    print("Error updating final sync: \(error.localizedDescription)")
                }
                group.leave()
            }
        
        _ = group.wait(timeout: .now() + 3.0)
    }
} 