import Foundation
import CryptoKit
import AuthenticationServices
import FirebaseAuth

class AppleSignInCoordinator: NSObject {
    // fileprivate var currentNonce: String?
    // private var onSignedIn: (() -> Void)?
    // private var onError: ((String) -> Void)?
    
    // init(onSignedIn: @escaping () -> Void, onError: @escaping (String) -> Void) {
    //     self.onSignedIn = onSignedIn
    //     self.onError = onError
    // }
    
    // @available(iOS 13, *)
    // func startSignInWithAppleFlow() {
    //     let nonce = randomNonceString()
    //     currentNonce = nonce
    //     let appleIDProvider = ASAuthorizationAppleIDProvider()
    //     let request = appleIDProvider.createRequest()
    //     request.requestedScopes = [.fullName, .email]
    //     request.nonce = sha256(nonce)
    //
    //     let authorizationController = ASAuthorizationController(authorizationRequests: [request])
    //     authorizationController.delegate = self
    //     authorizationController.presentationContextProvider = self
    // }
    
    // @available(iOS 13, *)
    // private func sha256(_ input: String) -> String {
    //     let inputData = Data(input.utf8)
    //     let hashedData = SHA256.hash(data: inputData)
    //     let hashString = hashedData.compactMap {
    //         String(format: "%02x", $0)
    //     }.joined()
    //     
    //     return hashString
    // }
    
    // private func randomNonceString(length: Int = 32) -> String {
    //     precondition(length > 0)
    //     let charset: [Character] =
    //         Array("0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._")
    //     var result = ""
    //     var remainingLength = length
    //
    //     while remainingLength > 0 {
    //         let randoms: [UInt8] = (0 ..< 16).map { _ in
    //             var random: UInt8 = 0
    //             let errorCode = SecRandomCopyBytes(kSecRandomDefault, 1, &random)
    //             if errorCode != errSecSuccess {
    //                 fatalError("Unable to generate nonce. SecRandomCopyBytes failed with OSStatus \(errorCode)")
    //             }
    //             return random
    //         }
    //         
    //         randoms.forEach { random in
    //             if remainingLength == 0 {
    //                 return
    //             }
    //             
    //             if random < charset.count {
    //                 result.append(charset[Int(random)])
    //                 remainingLength -= 1
    //             }
    //         }
    //     }
    //     
    //     return result
    // }
    
    // private func deleteCurrentUser() {
    //     do {
    //         let nonce = try randomNonceString()
    //         currentNonce = nonce
    //         let appleIDProvider = ASAuthorizationAppleIDProvider()
    //         let request = appleIDProvider.createRequest()
    //         request.nonce = sha256(nonce)
    //         
    //         let authorizationController = ASAuthorizationController(authorizationRequests: [request])
    //         authorizationController.delegate = self
    //         authorizationController.presentationContextProvider = self
    //         authorizationController.performRequests()
    //     } catch {
    //         displayError(error)
    //     }
    // }
    
    // func authorizationController(controller: ASAuthorizationController,
    //                              didCompleteWithAuthorization authorization: ASAuthorization) {
    //     guard let appleIDCredential = authorization.credential as? ASAuthorizationAppleIDCredential
    //     else {
    //         print("Unable to retrieve AppleIDCredential")
    //         return
    //     }
    //     
    //     guard let _ = currentNonce else {
    //         fatalError("Invalid state: A login callback was received, but no login request was sent.")
    //     }
    //     
    //     guard let appleAuthCode = appleIDCredential.authorizationCode else {
    //         print("Unable to fetch authorization code")
    //         return
    //     }
} 