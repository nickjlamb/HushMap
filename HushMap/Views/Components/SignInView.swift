import SwiftUI
import GoogleSignInSwift
import AuthenticationServices

struct SignInView: View {
    @StateObject private var authService = AuthenticationService.shared
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            VStack(spacing: 32) {
                Spacer()
                
                // App logo and welcome text
                VStack(spacing: 16) {
                    Image("HushMapIcon")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 100, height: 100)
                        .cornerRadius(20)
                    
                    VStack(spacing: 8) {
                        Text("Welcome to HushMap")
                            .font(.title)
                            .fontWeight(.bold)
                            .foregroundColor(.hushBackground)
                        
                        Text("Sign in to save your reports and track your contributions")
                            .font(.body)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    }
                }
                
                Spacer()
                
                // Sign in options
                VStack(spacing: 16) {
                    if authService.isLoading {
                        ProgressView()
                            .scaleEffect(1.2)
                            .frame(height: 50)
                    } else {
                        // Apple Sign In Button
                        SignInWithAppleButton(.signIn) { request in
                            authService.signInWithApple()
                        } onCompletion: { _ in
                            // Handled by AuthenticationService delegate
                        }
                        .signInWithAppleButtonStyle(.black)
                        .frame(height: 50)
                        .cornerRadius(8)
                        
                        // Google Sign In Button - Custom styled to match Apple button
                        Button(action: {
                            authService.signInWithGoogle()
                        }) {
                            HStack {
                                Image(systemName: "globe")
                                    .foregroundColor(.white)
                                Text("Sign in with Google")
                                    .foregroundColor(.white)
                                    .font(.system(size: 17, weight: .medium))
                            }
                            .frame(maxWidth: .infinity)
                            .frame(height: 50)
                            .background(Color.black)
                            .cornerRadius(8)
                        }
                    }
                    
                    // Continue as guest button
                    Button("Continue as Guest") {
                        dismiss()
                    }
                    .foregroundColor(.hushBackground)
                    .font(.body)
                    .fontWeight(.medium)
                    
                    // Error message
                    if let errorMessage = authService.errorMessage {
                        Text(errorMessage)
                            .foregroundColor(.red)
                            .font(.caption)
                            .multilineTextAlignment(.center)
                    }
                }
                .padding(.horizontal, 32)
                
                Spacer()
                
                // Privacy note
                Text("Your privacy is important to us. We only collect the minimum data needed to provide our service.")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
                    .padding(.bottom, 32)
            }
            .background(Color.hushMapShape.opacity(0.1))
            .navigationBarHidden(true)
        }
        .onChange(of: authService.isSignedIn) { oldValue, newValue in
            if newValue {
                dismiss()
            }
        }
    }
}

struct CompactSignInView: View {
    @StateObject private var authService = AuthenticationService.shared
    
    var body: some View {
        // Only show if user is not signed in
        if !authService.isSignedIn {
            VStack(spacing: 12) {
                if authService.isLoading {
                    ProgressView()
                        .scaleEffect(1.2)
                } else {
                    VStack(spacing: 8) {
                        // Apple Sign In Button
                        SignInWithAppleButton(.signIn) { request in
                            authService.signInWithApple()
                        } onCompletion: { _ in
                            // Handled by AuthenticationService delegate
                        }
                        .signInWithAppleButtonStyle(.white)
                        .frame(height: 44)
                        .cornerRadius(8)
                        
                        // Google Sign In Button - Custom styled to match Apple button
                        Button(action: {
                            authService.signInWithGoogle()
                        }) {
                            HStack {
                                Image(systemName: "globe")
                                    .foregroundColor(.primary)
                                Text("Sign in with Google")
                                    .foregroundColor(.primary)
                                    .font(.system(size: 17, weight: .medium))
                            }
                            .frame(maxWidth: .infinity)
                            .frame(height: 44)
                            .background(Color.white)
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(Color.black.opacity(0.1), lineWidth: 1)
                            )
                            .cornerRadius(8)
                        }
                    }
                }
                
                if let errorMessage = authService.errorMessage {
                    Text(errorMessage)
                        .foregroundColor(.red)
                        .font(.caption)
                        .multilineTextAlignment(.center)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(Color.hushMapShape.opacity(0.2))
            .cornerRadius(12)
        } else {
            // Show a signed-in confirmation
            VStack(spacing: 8) {
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                    Text("Signed in as \(authService.currentUser?.name ?? "User")")
                        .font(.subheadline)
                        .foregroundColor(.primary)
                }
                
                Text("Your reports will be saved to your account")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding()
            .background(Color.green.opacity(0.1))
            .cornerRadius(12)
        }
    }
}

#Preview {
    SignInView()
}