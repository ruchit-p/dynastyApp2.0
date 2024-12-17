import Foundation
import OSLog

enum AppError: LocalizedError {
    case network(Error)
    case validation(String)
    case authentication(String)
    case database(Error)
    case unknown(Error)
    case custom(String)
    
    var errorDescription: String? {
        switch self {
        case .network(let error):
            return "Network error: \(error.localizedDescription)"
        case .validation(let message):
            return message
        case .authentication(let message):
            return message
        case .database(let error):
            return "Database error: \(error.localizedDescription)"
        case .unknown(let error):
            return "Unknown error: \(error.localizedDescription)"
        case .custom(let message):
            return message
        }
    }
}

class ErrorHandlingService {
    static let shared = ErrorHandlingService()
    private let logger = Logger(subsystem: "com.dynasty", category: "ErrorHandling")
    private let analytics = AnalyticsService.shared
    
    private init() {}
    
    func handle(_ error: Error, context: String) {
        // Log the error
        logger.error("\(context): \(error.localizedDescription)")
        
        // Convert to AppError if needed
        let appError = convertToAppError(error)
        
        // Log to analytics
        analytics.logError(appError, context: context)
        
        // Additional handling like crash reporting could be added here
    }
    
    func convertToAppError(_ error: Error) -> AppError {
        if let appError = error as? AppError {
            return appError
        }
        
        // Convert common error types
        switch error {
        case let urlError as URLError:
            return .network(urlError)
        case let validationError as ValidationError:
            return .validation(validationError.message)
        default:
            return .unknown(error)
        }
    }
}

enum ValidationError: Error {
    case invalidEmail
    case invalidPhone
    case invalidName
    case custom(String)
    
    var message: String {
        switch self {
        case .invalidEmail:
            return "Please enter a valid email address"
        case .invalidPhone:
            return "Please enter a valid phone number"
        case .invalidName:
            return "Name cannot be empty"
        case .custom(let message):
            return message
        }
    }
} 