import SwiftUI
import GoogleSignIn
import GoogleSignInSwift
import AuthenticationServices

@MainActor
class AuthenticationService: NSObject, ObservableObject {
    static let shared = AuthenticationService()
    
    @Published var currentUser: AuthenticatedUser?
    @Published var isSignedIn = false
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var signInMethod: SignInMethod = .none
    
    private override init() {
        // Check if user is already signed in with Google
        if let user = GIDSignIn.sharedInstance.currentUser {
            self.currentUser = AuthenticatedUser(from: user)
            self.isSignedIn = true
            self.signInMethod = .google
        }
        
        // Check for Apple Sign In (we'll store the Apple ID in UserDefaults)
        if let appleUserID = UserDefaults.standard.string(forKey: "appleUserID"),
           let userName = UserDefaults.standard.string(forKey: "appleUserName"),
           let userEmail = UserDefaults.standard.string(forKey: "appleUserEmail") {
            self.currentUser = AuthenticatedUser(
                id: appleUserID,
                email: userEmail,
                name: userName,
                profileImageURL: nil,
                signInMethod: .apple
            )
            self.isSignedIn = true
            self.signInMethod = .apple
        }
    }
    
    func signInWithGoogle() {
        guard let presentingViewController = getRootViewController() else {
            errorMessage = "Unable to find root view controller"
            return
        }
        
        isLoading = true
        errorMessage = nil
        
        GIDSignIn.sharedInstance.signIn(withPresenting: presentingViewController) { [weak self] result, error in
            DispatchQueue.main.async {
                self?.isLoading = false
                
                if let error = error {
                    self?.errorMessage = error.localizedDescription
                    return
                }
                
                guard let user = result?.user else {
                    self?.errorMessage = "Failed to get user information"
                    return
                }
                
                self?.currentUser = AuthenticatedUser(from: user)
                self?.isSignedIn = true
                self?.signInMethod = .google
            }
        }
    }
    
    func signInWithApple() {
        isLoading = true
        errorMessage = nil
        
        let request = ASAuthorizationAppleIDProvider().createRequest()
        request.requestedScopes = [.fullName, .email]
        
        let authorizationController = ASAuthorizationController(authorizationRequests: [request])
        authorizationController.delegate = self
        authorizationController.presentationContextProvider = self
        authorizationController.performRequests()
    }
    
    func signOut() {
        // Clear Google Sign In
        GIDSignIn.sharedInstance.signOut()
        
        // Clear Apple Sign In data
        UserDefaults.standard.removeObject(forKey: "appleUserID")
        UserDefaults.standard.removeObject(forKey: "appleUserName")
        UserDefaults.standard.removeObject(forKey: "appleUserEmail")
        
        // Reset state
        currentUser = nil
        isSignedIn = false
        signInMethod = .none
    }
    
    func restorePreviousSignIn() {
        isLoading = true
        
        GIDSignIn.sharedInstance.restorePreviousSignIn { [weak self] user, error in
            DispatchQueue.main.async {
                self?.isLoading = false
                
                if let user = user {
                    self?.currentUser = AuthenticatedUser(from: user)
                    self?.isSignedIn = true
                    self?.signInMethod = .google
                } else if let error = error {
                    print("Error restoring sign in: \(error.localizedDescription)")
                }
            }
        }
    }
    
    private func getRootViewController() -> UIViewController? {
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let window = windowScene.windows.first else {
            return nil
        }
        return window.rootViewController
    }
}

// MARK: - Apple Sign In Delegate
extension AuthenticationService: ASAuthorizationControllerDelegate, ASAuthorizationControllerPresentationContextProviding {
    
    func authorizationController(controller: ASAuthorizationController, didCompleteWithAuthorization authorization: ASAuthorization) {
        isLoading = false
        
        switch authorization.credential {
        case let appleIDCredential as ASAuthorizationAppleIDCredential:
            let userID = appleIDCredential.user
            let email = appleIDCredential.email ?? ""
            let fullName = appleIDCredential.fullName
            let name = [fullName?.givenName, fullName?.familyName]
                .compactMap { $0 }
                .joined(separator: " ")
            
            // Store Apple ID data
            UserDefaults.standard.set(userID, forKey: "appleUserID")
            UserDefaults.standard.set(name.isEmpty ? "Apple User" : name, forKey: "appleUserName")
            UserDefaults.standard.set(email, forKey: "appleUserEmail")
            
            // Update current user
            self.currentUser = AuthenticatedUser(
                id: userID,
                email: email,
                name: name.isEmpty ? "Apple User" : name,
                profileImageURL: nil,
                signInMethod: .apple
            )
            self.isSignedIn = true
            self.signInMethod = .apple
            
        default:
            errorMessage = "Unknown authorization type"
        }
    }
    
    func authorizationController(controller: ASAuthorizationController, didCompleteWithError error: Error) {
        isLoading = false
        print("Apple Sign In Error: \(error)")
        
        if let authError = error as? ASAuthorizationError {
            switch authError.code {
            case .canceled:
                errorMessage = "Sign in was canceled"
            case .failed:
                errorMessage = "Sign in failed. Please try again."
            case .invalidResponse:
                errorMessage = "Invalid response from Apple"
            case .notHandled:
                errorMessage = "Sign in could not be handled"
            case .notInteractive:
                errorMessage = "Sign in requires user interaction"
            case .matchedExcludedCredential:
                errorMessage = "Credential was excluded"
            case .unknown:
                errorMessage = "An unknown error occurred"
            default:
                errorMessage = "Sign in failed with error: \(authError.localizedDescription)"
            }
        } else {
            errorMessage = error.localizedDescription
        }
    }
    
    func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
        return getRootViewController()?.view.window ?? ASPresentationAnchor()
    }
}

// MARK: - User Models
enum SignInMethod {
    case none
    case google
    case apple
}

struct AuthenticatedUser {
    let id: String
    let email: String
    let name: String
    let profileImageURL: URL?
    let signInMethod: SignInMethod
    
    init(from gidUser: GIDGoogleUser) {
        self.id = gidUser.userID ?? ""
        self.email = gidUser.profile?.email ?? ""
        self.name = gidUser.profile?.name ?? ""
        self.profileImageURL = gidUser.profile?.imageURL(withDimension: 100)
        self.signInMethod = .google
    }
    
    init(id: String, email: String, name: String, profileImageURL: URL?, signInMethod: SignInMethod) {
        self.id = id
        self.email = email
        self.name = name
        self.profileImageURL = profileImageURL
        self.signInMethod = signInMethod
    }
}