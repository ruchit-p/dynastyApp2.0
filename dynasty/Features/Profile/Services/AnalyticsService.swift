import Foundation
import FirebaseAnalytics

class AnalyticsService {
    static let shared = AnalyticsService()
    
    private init() {}
    
    // MARK: - Profile Events
    
    func logProfileView() {
        Analytics.logEvent("profile_view", parameters: nil)
    }
    
    func logProfileEdit(fields: [String]) {
        Analytics.logEvent("profile_edit", parameters: [
            "edited_fields": fields.joined(separator: ",")
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
            "value": "\(value)"
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
            "error_message": errorMessage,
            "context": context
        ])
    }
    
    // MARK: - Performance Events
    
    func logOperationTime(operation: String, duration: TimeInterval) {
        Analytics.logEvent("operation_performance", parameters: [
            "operation": operation,
            "duration_ms": Int(duration * 1000)
        ])
    }
    
    // MARK: - User Properties
    
    func setUserProperties(user: User) {
        Analytics.setUserProperty(user.id, forName: "user_id")
        Analytics.setUserProperty(user.isAdmin ? "admin" : "user", forName: "user_role")
        Analytics.setUserProperty(user.canAddMembers ? "yes" : "no", forName: "can_add_members")
        Analytics.setUserProperty(user.canEdit ? "yes" : "no", forName: "can_edit")
    }
} 