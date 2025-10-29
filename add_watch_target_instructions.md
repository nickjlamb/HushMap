# Adding Watch App Target to HushMap

## Files Created
All Watch app files have been created and are ready:
- ✅ `HushMapWatch Watch App/HushMapWatchApp.swift` - Main app entry point
- ✅ `HushMapWatch Watch App/ContentView.swift` - Tab-based main view
- ✅ `HushMapWatch Watch App/Views/GlanceView.swift` - Quiet score dashboard
- ✅ `HushMapWatch Watch App/Views/LogView.swift` - Quick log interface
- ✅ `HushMapWatch Watch App/Models/Place.swift` - Place data model
- ✅ `HushMapWatch Watch App/Managers/WCSessionManager.swift` - Watch connectivity manager
- ✅ `HushMap/Services/WatchConnectivityService.swift` - iPhone-side handler

## Steps to Add Watch Target in Xcode

### Option 1: Manual Target Creation (Recommended)
1. Open `HushMap.xcodeproj` in Xcode
2. Click the "+" button at the bottom of the target list
3. Select "watchOS" → "Watch App for iOS App"
4. Name it "HushMapWatch"
5. Select "HushMap" as the companion iOS app
6. **IMPORTANT**: Choose "SwiftUI" and uncheck "Include Notification Scene"
7. Delete the automatically generated files
8. Add the existing Watch app folder to the target:
   - Right-click on HushMapWatch target
   - Add Files to "HushMapWatch"
   - Select the "HushMapWatch Watch App" folder
   - Ensure "Copy items if needed" is UNCHECKED
   - Add to HushMapWatch target

### Option 2: Using Command Line (Alternative)
If you prefer to manually add the target to the project file, you'll need to:
1. Add a new native target to `HushMap.xcodeproj/project.pbxproj`
2. Set `WATCHOS_DEPLOYMENT_TARGET` to `10.0` or higher
3. Add all Watch app source files to the target's build phases

## Required Capabilities
Make sure to add these capabilities in Xcode:
- **iOS App**: Background Modes (for Watch Connectivity)
- **Watch App**: WatchKit App

## Testing the Watch App
After adding the target:
1. Build the iOS app first: `⌘+B`
2. Select the HushMapWatch scheme
3. Choose a Watch simulator (e.g., Apple Watch Series 9 45mm)
4. Run the Watch app: `⌘+R`
5. The Watch app should connect to the iPhone app automatically

## Key Features
- **GlanceView**: Shows real-time quiet score and nearest place
- **LogView**: Quick "Quiet" or "Noisy" logging buttons
- **Auto-sync**: Queues logs when offline, syncs when iPhone is reachable
- **Haptic feedback**: Success/notification feedback on logging

## Communication Flow
```
Watch App (WCSessionManager)
    ↕ WatchConnectivity
iPhone App (WatchConnectivityService)
    ↕ SwiftData
Report Database
```

## Next Steps After Adding Target
1. Build both targets to verify setup
2. Test on simulators
3. Test on physical devices (requires developer account)
4. Submit to App Store as a bundle
