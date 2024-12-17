import Foundation

class ValidationService {
    static let shared = ValidationService()
    
    private init() {}
    
    // MARK: - Email Validation
    
    func validateEmail(_ email: String) -> ValidationResult {
        let emailRegex = "[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,64}"
        let emailPredicate = NSPredicate(format: "SELF MATCHES %@", emailRegex)
        
        if email.isEmpty {
            return .failure(ValidationError.custom("Email cannot be empty"))
        }
        
        if !emailPredicate.evaluate(with: email) {
            return .failure(ValidationError.invalidEmail)
        }
        
        return .success
    }
    
    // MARK: - Phone Validation
    
    func validatePhone(_ phone: String) -> ValidationResult {
        let phoneRegex = "^[+]?[(]?[0-9]{3}[)]?[-\\s.]?[0-9]{3}[-\\s.]?[0-9]{4,6}$"
        let phonePredicate = NSPredicate(format: "SELF MATCHES %@", phoneRegex)
        
        if phone.isEmpty {
            return .success // Phone is optional
        }
        
        if !phonePredicate.evaluate(with: phone) {
            return .failure(ValidationError.invalidPhone)
        }
        
        return .success
    }
    
    // MARK: - Name Validation
    
    func validateName(_ name: String, field: String) -> ValidationResult {
        if name.isEmpty {
            return .failure(ValidationError.custom("\(field) cannot be empty"))
        }
        
        if name.count < 2 {
            return .failure(ValidationError.custom("\(field) must be at least 2 characters long"))
        }
        
        if name.count > 50 {
            return .failure(ValidationError.custom("\(field) cannot be longer than 50 characters"))
        }
        
        // Check for valid characters (letters, spaces, hyphens, and apostrophes)
        let nameRegex = "^[\\p{L}'\\s-]+$"
        let namePredicate = NSPredicate(format: "SELF MATCHES %@", nameRegex)
        
        if !namePredicate.evaluate(with: name) {
            return .failure(ValidationError.custom("\(field) contains invalid characters"))
        }
        
        return .success
    }
    
    // MARK: - Password Validation
    
    func validatePassword(_ password: String) -> ValidationResult {
        if password.isEmpty {
            return .failure(ValidationError.custom("Password cannot be empty"))
        }
        
        if password.count < 8 {
            return .failure(ValidationError.custom("Password must be at least 8 characters long"))
        }
        
        let hasUppercase = password.contains(where: { $0.isUppercase })
        let hasLowercase = password.contains(where: { $0.isLowercase })
        let hasNumber = password.contains(where: { $0.isNumber })
        let hasSpecialCharacter = password.contains(where: { "!@#$%^&*()_+-=[]{}|;:,.<>?".contains($0) })
        
        if !hasUppercase {
            return .failure(ValidationError.custom("Password must contain at least one uppercase letter"))
        }
        
        if !hasLowercase {
            return .failure(ValidationError.custom("Password must contain at least one lowercase letter"))
        }
        
        if !hasNumber {
            return .failure(ValidationError.custom("Password must contain at least one number"))
        }
        
        if !hasSpecialCharacter {
            return .failure(ValidationError.custom("Password must contain at least one special character"))
        }
        
        return .success
    }
    
    // MARK: - Profile Validation
    
    func validateProfileUpdate(firstName: String, lastName: String, email: String, phone: String) -> ValidationResult {
        // Validate first name
        let firstNameResult = validateName(firstName, field: "First name")
        if case .failure(let error) = firstNameResult {
            return .failure(error)
        }
        
        // Validate last name
        let lastNameResult = validateName(lastName, field: "Last name")
        if case .failure(let error) = lastNameResult {
            return .failure(error)
        }
        
        // Validate email
        let emailResult = validateEmail(email)
        if case .failure(let error) = emailResult {
            return .failure(error)
        }
        
        // Validate phone if provided
        if !phone.isEmpty {
            let phoneResult = validatePhone(phone)
            if case .failure(let error) = phoneResult {
                return .failure(error)
            }
        }
        
        return .success
    }
}

enum ValidationResult {
    case success
    case failure(ValidationError)
}

extension ValidationResult {
    var isValid: Bool {
        switch self {
        case .success:
            return true
        case .failure:
            return false
        }
    }
    
    var errorMessage: String? {
        switch self {
        case .success:
            return nil
        case .failure(let error):
            return error.message
        }
    }
} 