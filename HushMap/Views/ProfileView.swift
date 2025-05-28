import SwiftUI
import SwiftData
import AuthenticationServices

struct ProfileView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var badges: [Badge]
    @Query private var user: [User]
    @StateObject private var authService = AuthenticationService.shared
    @AppStorage("hasSeenWelcome") private var hasSeenWelcome: Bool = false
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding: Bool = false
    @State private var showingDeleteConfirmation = false
    @State private var isDeleting = false
    
    private var currentUser: User {
        // Get the user or create one if needed
        if let existingUser = user.first {
            return existingUser
        } else {
            let userService = UserService(modelContext: modelContext)
            return userService.getCurrentUser()
        }
    }
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Authentication Section
                    authenticationSectionView
                    
                    // Points Section
                    pointsSummaryView
                    
                    // Badges Section
                    badgesSectionView
                    
                    // Settings Section
                    settingsSectionView
                }
                .padding()
            }
            .navigationTitle("Your Profile")
            .onAppear {
                // Ensure user exists when view appears
                if user.isEmpty {
                    let userService = UserService(modelContext: modelContext)
                    _ = userService.getCurrentUser()
                }
                
                // Restore previous sign in
                authService.restorePreviousSignIn()
            }
            .alert("Delete Account", isPresented: $showingDeleteConfirmation) {
                Button("Cancel", role: .cancel) { }
                Button("Delete", role: .destructive) {
                    Task {
                        await deleteUserAccount()
                    }
                }
            } message: {
                Text("This will permanently delete your account and all associated data including reports, badges, and preferences. This action cannot be undone.")
            }
        }
    }
    
    private var authenticationSectionView: some View {
        VStack(alignment: .leading, spacing: 16) {
            if authService.isSignedIn, let authenticatedUser = authService.currentUser {
                // Signed in state
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        AsyncImage(url: authenticatedUser.profileImageURL) { image in
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                        } placeholder: {
                            Image(systemName: "person.circle.fill")
                                .foregroundColor(.hushBackground)
                        }
                        .frame(width: 50, height: 50)
                        .clipShape(Circle())
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text(authenticatedUser.name)
                                .font(.headline)
                                .foregroundColor(.primary)
                            
                            Text(authenticatedUser.email)
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            
                            Text(authService.signInMethod == .google ? "Google Account" : "Apple Account")
                                .font(.caption)
                                .foregroundColor(.hushBackground)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 2)
                                .background(Color.hushBackground.opacity(0.2))
                                .cornerRadius(4)
                        }
                        
                        Spacer()
                    }
                    
                    if isDeleting {
                        HStack {
                            ProgressView()
                                .scaleEffect(0.8)
                            Text("Deleting account...")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                    } else {
                        HStack(spacing: 16) {
                            Button("Sign Out") {
                                authService.signOut()
                            }
                            .foregroundColor(.orange)
                            .font(.subheadline)
                            
                            Button("Delete Account") {
                                showingDeleteConfirmation = true
                            }
                            .foregroundColor(.red)
                            .font(.subheadline)
                        }
                    }
                }
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.hushMapLines.opacity(0.2))
                )
            } else {
                // Not signed in state
                VStack(spacing: 12) {
                    HStack {
                        Image(systemName: "person.circle")
                            .font(.system(size: 40))
                            .foregroundColor(.hushBackground)
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Anonymous User")
                                .font(.headline)
                                .foregroundColor(.primary)
                            
                            Text("Sign in to sync your data")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                    }
                    
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
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.hushBackground.opacity(0.3), lineWidth: 1)
                        .background(Color.clear)
                )
            }
        }
    }
    
    private var pointsSummaryView: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Quiet Explorer Points")
                .font(.headline)
                .foregroundColor(.secondary)
            
            HStack(spacing: 16) {
                Image(systemName: "star.fill")
                    .font(.system(size: 36))
                    .foregroundColor(.yellow)
                    .accessibilityHidden(true)
                
                VStack(alignment: .leading) {
                    Text("\(currentUser.points)")
                        .font(.system(size: 36, weight: .bold))
                        .foregroundColor(.primary)
                    
                    Text("Total Points")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.hushMapLines.opacity(0.2))
            )
            .accessibilityElement(children: .combine)
            .accessibilityLabel("You have \(currentUser.points) quiet explorer points")
        }
    }
    
    private var badgesSectionView: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Achievements")
                    .font(.headline)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                Text("\(currentUser.badges.count) of \(BadgeType.allCases.count)")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            if currentUser.badges.isEmpty {
                emptyBadgesView
            } else {
                badgesGridView
            }
        }
    }
    
    private var emptyBadgesView: some View {
        VStack(spacing: 16) {
            Image(systemName: "trophy")
                .font(.system(size: 48))
                .foregroundColor(.gray.opacity(0.6))
            
            Text("Submit reports to earn achievements")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.hushMapLines.opacity(0.1))
        )
    }
    
    private var badgesGridView: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 120))], spacing: 16) {
            ForEach(currentUser.badges) { badge in
                badgeView(badge)
            }
            
            // Add placeholder badges for locked achievements
            ForEach(BadgeType.allCases.filter { type in
                !currentUser.hasBadge(ofType: type)
            }, id: \.rawValue) { type in
                lockedBadgeView(type)
            }
        }
    }
    
    private func badgeView(_ badge: Badge) -> some View {
        VStack {
            Image(systemName: badge.iconName)
                .font(.system(size: 36))
                .foregroundColor(.purple)
                .frame(width: 60, height: 60)
                .background(Circle().fill(Color.purple.opacity(0.2)))
            
            Text(badge.title)
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(.primary)
                .lineLimit(2)
                .multilineTextAlignment(.center)
            
            Text(badge.earnedDate.formatted(date: .abbreviated, time: .omitted))
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding()
        .frame(minHeight: 160)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.hushMapLines.opacity(0.15))
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(badge.title) badge earned on \(badge.earnedDate.formatted(date: .long, time: .omitted))")
        .accessibilityHint(badge.descriptionText)
    }
    
    private func lockedBadgeView(_ type: BadgeType) -> some View {
        VStack {
            Image(systemName: "lock.fill")
                .font(.system(size: 24))
                .foregroundColor(.gray)
                .frame(width: 60, height: 60)
                .background(Circle().fill(Color.gray.opacity(0.2)))
            
            Text(type.rawValue)
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(.gray)
                .lineLimit(2)
                .multilineTextAlignment(.center)
            
            Text("Not yet earned")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding()
        .frame(minHeight: 160)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                .background(Color.clear)
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(type.rawValue) badge not yet earned")
        .accessibilityHint(type.description)
    }
    
    private var settingsSectionView: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Settings")
                .font(.headline)
                .foregroundColor(.secondary)
            
            VStack(spacing: 0) {
                // Reset Welcome Screen option
                Button(action: {
                    hasSeenWelcome = false
                    // Send notification to switch to welcome screen
                    NotificationCenter.default.post(
                        name: Notification.Name("ShowWelcomeScreen"),
                        object: nil
                    )
                }) {
                    HStack {
                        Image(systemName: "arrow.clockwise")
                            .foregroundColor(.hushBackground)
                            .frame(width: 24)
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Show Welcome Screen")
                                .font(.body)
                                .foregroundColor(.primary)
                            
                            Text("Review app introduction and sign-in options")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                        
                        Image(systemName: "chevron.right")
                            .foregroundColor(.secondary)
                            .font(.caption)
                    }
                    .padding(.vertical, 12)
                    .padding(.horizontal, 16)
                }
                .buttonStyle(PlainButtonStyle())
                
                Divider()
                    .padding(.horizontal, 16)
                
                // Reset Onboarding option
                Button(action: {
                    hasCompletedOnboarding = false
                }) {
                    HStack {
                        Image(systemName: "graduationcap")
                            .foregroundColor(.hushBackground)
                            .frame(width: 24)
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Show Tutorial")
                                .font(.body)
                                .foregroundColor(.primary)
                            
                            Text("Learn about sensory levels and predictions")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                        
                        Image(systemName: "chevron.right")
                            .foregroundColor(.secondary)
                            .font(.caption)
                    }
                    .padding(.vertical, 12)
                    .padding(.horizontal, 16)
                }
                .buttonStyle(PlainButtonStyle())
                
                Divider()
                    .padding(.horizontal, 16)
                
                // Privacy Policy
                Button(action: {
                    if let url = URL(string: "https://www.pharmatools.ai/privacy-policy") {
                        UIApplication.shared.open(url)
                    }
                }) {
                    HStack {
                        Image(systemName: "hand.raised")
                            .foregroundColor(.hushBackground)
                            .frame(width: 24)
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Privacy Policy")
                                .font(.body)
                                .foregroundColor(.primary)
                            
                            Text("How we protect your data and privacy")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                        
                        Image(systemName: "arrow.up.right")
                            .foregroundColor(.secondary)
                            .font(.caption)
                    }
                    .padding(.vertical, 12)
                    .padding(.horizontal, 16)
                }
                .buttonStyle(PlainButtonStyle())
                
                Divider()
                    .padding(.horizontal, 16)
                
                // Terms of Service
                Button(action: {
                    if let url = URL(string: "https://www.pharmatools.ai/terms") {
                        UIApplication.shared.open(url)
                    }
                }) {
                    HStack {
                        Image(systemName: "doc.text")
                            .foregroundColor(.hushBackground)
                            .frame(width: 24)
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Terms of Service")
                                .font(.body)
                                .foregroundColor(.primary)
                            
                            Text("Terms and conditions for using HushMap")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                        
                        Image(systemName: "arrow.up.right")
                            .foregroundColor(.secondary)
                            .font(.caption)
                    }
                    .padding(.vertical, 12)
                    .padding(.horizontal, 16)
                }
                .buttonStyle(PlainButtonStyle())
                
                Divider()
                    .padding(.horizontal, 16)
                
                // App Version Info
                HStack {
                    Image(systemName: "info.circle")
                        .foregroundColor(.secondary)
                        .frame(width: 24)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text("App Version")
                            .font(.body)
                            .foregroundColor(.primary)
                        
                        Text("1.0")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                }
                .padding(.vertical, 12)
                .padding(.horizontal, 16)
            }
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.hushMapLines.opacity(0.2))
            )
        }
    }
    
    private func deleteUserAccount() async {
        isDeleting = true
        
        // Step 1: Delete all user data from SwiftData
        await deleteAllUserData()
        
        // Step 2: Clear authentication tokens and user defaults
        await MainActor.run {
            authService.signOut()
            
            // Clear any additional user preferences
            UserDefaults.standard.removeObject(forKey: "hasSeenWelcome")
            
            // Reset any other app-specific storage
            clearUserPreferences()
        }
        
        // Step 3: Show success message (optional)
        print("Account successfully deleted")
        
        isDeleting = false
    }
    
    @MainActor
    private func deleteAllUserData() async {
        // Delete all reports
        let allReports = try? modelContext.fetch(FetchDescriptor<Report>())
        allReports?.forEach { report in
            modelContext.delete(report)
        }
        
        // Delete all badges
        let allBadges = try? modelContext.fetch(FetchDescriptor<Badge>())
        allBadges?.forEach { badge in
            modelContext.delete(badge)
        }
        
        // Delete all users
        let allUsers = try? modelContext.fetch(FetchDescriptor<User>())
        allUsers?.forEach { user in
            modelContext.delete(user)
        }
        
        // Delete any other models if they exist
        let allItems = try? modelContext.fetch(FetchDescriptor<Item>())
        allItems?.forEach { item in
            modelContext.delete(item)
        }
        
        // Save changes
        try? modelContext.save()
    }
    
    private func clearUserPreferences() {
        // Clear any additional UserDefaults keys
        let userDefaults = UserDefaults.standard
        
        // Remove app-specific preferences
        userDefaults.removeObject(forKey: "appleUserID")
        userDefaults.removeObject(forKey: "appleUserName")
        userDefaults.removeObject(forKey: "appleUserEmail")
        
        // You can add more UserDefaults cleanup here as needed
        // userDefaults.removeObject(forKey: "userPreferences")
        // userDefaults.removeObject(forKey: "appSettings")
    }
}

#Preview {
    ProfileView()
}