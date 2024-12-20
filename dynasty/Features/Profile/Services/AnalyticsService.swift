import Foundation
import FirebaseAnalytics

class AnalyticsService {
    static let shared = AnalyticsService()
    
    private init() {}
    
    // MARK: - Authentication Events
    
    func logSignIn(method: String) {
        Analytics.logEvent("user_sign_in", parameters: [
            "method": method
        ])
    }
    
    func logSignUp(method: String, hasReferral: Bool) {
        Analytics.logEvent("user_sign_up", parameters: [
            "method": method,
            "has_referral": hasReferral as NSNumber
        ])
    }
    
    func logSignOut() {
        Analytics.logEvent("user_sign_out", parameters: nil)
    }
    
    // MARK: - Profile Events
    
    func logProfileView() {
        Analytics.logEvent("profile_view", parameters: nil)
    }
    
    func logProfileEdit(fields: [String]) {
        Analytics.logEvent("profile_edit", parameters: [
            "edited_fields": fields.joined(separator: ","),
            "field_count": fields.count as NSNumber
        ])
    }
    
    func logProfilePhotoUpdate() {
        Analytics.logEvent("profile_photo_update", parameters: nil)
    }
    
    // MARK: - Settings Events
    
    func logSettingsChange(category: String, setting: String, value: Any) {
        Analytics.logEvent("settings_change", parameters: [
            "category": category,
            "setting": setting,
            "value": "\(value)",
            "timestamp": Date().timeIntervalSince1970 as NSNumber
        ])
    }
    
    func logSettingsView(category: String) {
        Analytics.logEvent("settings_view", parameters: [
            "category": category
        ])
    }
    
    // MARK: - Support Events
    
    func logSupportRequest(type: String) {
        Analytics.logEvent("support_request", parameters: [
            "type": type
        ])
    }
    
    func logFAQView(questionId: String) {
        Analytics.logEvent("faq_view", parameters: [
            "question_id": questionId
        ])
    }
    
    // MARK: - Error Events
    
    func logError(_ error: Error, context: String) {
        let errorType = String(describing: type(of: error))
        let errorMessage = error.localizedDescription
        
        Analytics.logEvent("app_error", parameters: [
            "error_type": errorType,
            "error_message": errorMessage.prefix(100),
            "context": context,
            "timestamp": Date().timeIntervalSince1970 as NSNumber
        ])
    }
    
    // MARK: - Performance Events
    
    func logOperationTime(operation: String, duration: TimeInterval) {
        Analytics.logEvent("operation_performance", parameters: [
            "operation": operation,
            "duration_ms": Int(duration * 1000) as NSNumber
        ])
    }
    
    // MARK: - User Properties
    
    func setUserProperties(user: User) {
        // Use dedicated method for user ID
        Analytics.setUserID(user.id)
        
        // Set other user properties
        Analytics.setUserProperty(user.role.rawValue, forName: "user_role")
        Analytics.setUserProperty(user.canAddMembers ? "true" : "false", forName: "can_add_members")
        Analytics.setUserProperty(user.canEdit ? "true" : "false", forName: "can_edit")
        
        // Add app version for tracking
        if let appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String {
            Analytics.setUserProperty(appVersion, forName: "app_version")
        }
    }
} 