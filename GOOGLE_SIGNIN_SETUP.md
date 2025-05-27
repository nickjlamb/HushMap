# Google Sign In Setup Instructions

## 1. Add Google Sign In SDK to Xcode

1. Open your project in Xcode
2. Go to File → Add Package Dependencies
3. Enter this URL: `https://github.com/google/GoogleSignIn-iOS`
4. Choose "Up to Next Major Version" and select the latest version
5. Add the following products to your target:
   - GoogleSignIn
   - GoogleSignInSwift

## 2. Configure URL Scheme

1. In Xcode, select your project in the navigator
2. Select your app target
3. Go to the "Info" tab
4. Expand "URL Types" 
5. Click the "+" button to add a new URL Type
6. Set the Identifier to `com.googleusercontent.apps.YOUR_CLIENT_ID`
7. Set the URL Schemes to your REVERSED_CLIENT_ID (from GoogleService-Info.plist)

## 3. Create GoogleService-Info.plist

1. Go to [Google Cloud Console](https://console.cloud.google.com/)
2. Create a new project or select existing one
3. Enable Google Sign In API
4. Create OAuth 2.0 credentials for iOS
5. Download the GoogleService-Info.plist file
6. Drag it into your Xcode project (make sure "Add to target" is checked)

## 4. Update Info.plist

The app will automatically add the required URL scheme when you add GoogleService-Info.plist.

## Files Created by This Setup:
- AuthenticationService.swift - Handles Google Sign In logic
- Updated User.swift model - Adds Google user data
- SignInView.swift - Sign in UI component
- Updated ProfileView.swift - Shows authentication state

## Next Steps:
1. Complete the manual Xcode setup above
2. Add your GoogleService-Info.plist file
3. The code files have been created and are ready to use