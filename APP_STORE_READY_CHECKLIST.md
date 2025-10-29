# HushMap App Store Ready Checklist

Comprehensive pre-submission checklist combining technical excellence with App Store compliance.

---

## 1. 🚀 Performance & Responsiveness

### Main Thread Optimization
- [ ] Audit all `@Published` properties - ensure updates happen on `@MainActor`
- [ ] Review all async/await calls for redundancy
- [ ] Profile app launch time with Instruments (target: <2 seconds to first screen)
- [ ] Verify heavy tasks (AI predictions, geocoding) run on background queues

### SwiftUI Performance
- [ ] Profile for excessive re-renders using SwiftUI Instruments
- [ ] Check `GoogleMapsView` marker rendering performance (especially on iPhone 12/13)
- [ ] Verify map clustering activates at correct thresholds (50+ markers)
- [ ] Test scroll performance in `NearbyView` with 100+ reports
- [ ] Review `AddReportView` form performance with real-time validation

### Specific HushMap Concerns
- [ ] `PredictionService` - Cache AI predictions properly (24h TTL)
- [ ] `PlaceService` - Debounce search queries to avoid API spam
- [ ] `LocationManager` - Ensure location updates don't drain battery
- [ ] Watch app - Verify WatchConnectivity messages don't block UI

**Target Metrics:**
- App launch: <2s
- Map load with 50 markers: <1s
- Search autocomplete: <300ms response
- AI prediction: <3s (with loading state)

---

## 2. 🧠 Memory & Thread Safety

### Memory Leak Hunting
- [ ] Run Instruments Leaks tool on 15-minute session
- [ ] Check all view models for strong reference cycles
- [ ] Verify `[weak self]` in all closures and async tasks
- [ ] Review delegates (especially `GoogleMapsDelegate`, `WCSessionDelegate`)
- [ ] Test memory on iPhone 12 with low memory warnings

### Thread Safety Audit
- [ ] Search for `DispatchQueue.main.async` - replace with `@MainActor` where possible
- [ ] Verify all services marked `@MainActor` or thread-safe
- [ ] Check `WCSessionManager` (Watch) for thread safety
- [ ] Review `EnvironmentalSoundMonitor` HealthKit callbacks
- [ ] Ensure `GoogleGeocoderAdapter` handles concurrent requests safely

### Singleton Services Review
✅ Already singletons:
- `AuthenticationService.shared`
- `GoogleMapsService.shared`
- `OpenAIService.shared`
- `DeviceCapabilityService.shared`
- `ReportSyncService.shared`
- `WCSessionManager.shared` (Watch)
- `EnvironmentalSoundMonitor.shared` (Watch)

- [ ] Verify no duplicate instances created
- [ ] Check initialization order doesn't cause crashes

**Target Metrics:**
- No leaks in 15-minute Instruments session
- Memory usage: <150MB on iPhone 12
- Watch app: <50MB memory usage

---

## 3. ✨ UI/UX Polish

### Visual Consistency
- [ ] Review all views use standardized spacing from `StandardizedSheetDesign`
- [ ] Verify typography uses `Typography.swift` helpers consistently
- [ ] Check color usage - all use semantic colors (`.hushBackground`, `.hushPrimaryText`)
- [ ] Test high contrast mode on all screens
- [ ] Verify Dynamic Type scaling (test at largest accessibility size)

### Animations & Feedback
- [ ] Add haptic feedback to all primary actions:
  - [ ] "Log Quiet" / "Log Noisy" (Watch app) ✅
  - [ ] Submit report (iOS app)
  - [ ] Toggle filters
  - [ ] Favorite locations
- [ ] Smooth transitions between sheets and modals
- [ ] Loading states for all async operations:
  - [ ] AI predictions
  - [ ] Place search
  - [ ] Map loading
  - [ ] Account deletion

### State Management Simplification
- [ ] Review `HomeMapView` + `HomeMapViewModel` - eliminate redundant `@State`
- [ ] Check `AddReportView` form state - simplify validation logic
- [ ] Verify `ProfileView` doesn't trigger unnecessary re-renders
- [ ] Test Watch app state sync - ensure no flicker/jumps

### Premium Feel Checklist
- [ ] All buttons have visual press states
- [ ] Empty states are helpful and encouraging (not just "No data")
- [ ] Error states provide actionable next steps
- [ ] Success confirmations feel rewarding (not just "Done")
- [ ] Onboarding feels welcoming, not overwhelming

**Critical Screens to Polish:**
1. `HomeMapView` - Main experience, must be flawless
2. `AddReportView` - Core user action, must feel effortless
3. `ProfileView` - User's personal space, must feel special
4. Watch `GlanceView` - First impression, must be stunning ✅
5. Watch `LogView` - Primary action, must be instant ✅

---

## 4. 🛡️ Error Handling & Resilience

### Network Error Handling
- [ ] Test all API calls with airplane mode:
  - [ ] Google Maps Places API
  - [ ] Google Maps Geocoding API
  - [ ] OpenAI API
- [ ] Verify user-friendly error messages (no "Error 500" or JSON dumps)
- [ ] Implement retry logic for transient failures:
  - [ ] `OpenAIService` - Retry on 429/503
  - [ ] `PlaceService` - Retry on network timeout
- [ ] Test with flaky network (use Network Link Conditioner)

### API Response Validation
- [ ] `OpenAIService` - Handle malformed JSON gracefully
- [ ] `PlaceService` - Handle empty results without crashing
- [ ] `GoogleGeocoderAdapter` - Handle geocoding failures
- [ ] Watch sync - Handle missing/stale data from iPhone

### Crash Prevention
- [ ] Review all force unwraps (`!`) - replace with safe unwrapping
- [ ] Check all array/dictionary access - use safe subscripts
- [ ] Verify all `try!` calls - replace with `try?` or proper error handling
- [ ] Test edge cases:
  - [ ] No internet connection
  - [ ] GPS disabled
  - [ ] Microphone permission denied (Watch)
  - [ ] HealthKit permission denied (Watch)
  - [ ] API key missing/invalid

### Centralized Error Logic
- [ ] Review `AppError` enum - ensure all error types covered
- [ ] Implement consistent error presentation (alert vs. inline vs. toast)
- [ ] Add error logging for debugging (without exposing to users)

**Test Scenarios:**
- Fresh install with no network
- API key quota exceeded
- Invalid GPS coordinates
- Malformed API responses
- Watch app disconnected from iPhone

---

## 5. 🧹 Code Tidiness & Consistency

### Code Cleanup
- [ ] Remove all commented-out code
- [ ] Remove unused imports (use Xcode organizer)
- [ ] Delete unused files:
  - [ ] `comfort-slider-embed.html` (already deleted)
  - [ ] `hushmap-landing-fullwidth.html` (already deleted)
  - [ ] Any other test/prototype files
- [ ] Remove debug `print()` statements (or wrap in `#if DEBUG`)
- [ ] Check for TODO comments - resolve or track separately

### Code Consolidation
- [ ] Review duplicate color definitions - consolidate into `ColorExtensions.swift`
- [ ] Check for duplicate networking logic - move to shared service
- [ ] Review map marker rendering - eliminate code duplication
- [ ] Consolidate sheet presentation logic

### Naming Conventions
- [ ] Services: `PascalCase` (✅ already consistent)
- [ ] Methods: `camelCase` (✅ already consistent)
- [ ] Properties: `camelCase` (✅ already consistent)
- [ ] Constants: `camelCase` or `UPPER_SNAKE_CASE` for globals
- [ ] Review all variable names for clarity

### Documentation
- [ ] Add docstrings to all public service methods
- [ ] Document `PredictionService.generatePrediction()` algorithm
- [ ] Explain `SensoryProfile` learning system
- [ ] Document Watch sync protocol
- [ ] Add README sections for new features

**Files to Review:**
- `Models/` - Ensure all SwiftData models documented
- `Services/` - All public methods have docstrings
- `Views/Components/` - Reusable components explained
- `Utilities/` - Helper functions documented

---

## 6. ✅ Pre-Release Sign-Off Checklist

### App Store Compliance

#### Required Metadata
- [✅] App name: HushMap
- [✅] Bundle ID configured
- [✅] Version: 1.1.2
- [✅] App icon (1024x1024)
- [ ] Screenshots for all device sizes:
  - [ ] iPhone 6.7" (Pro Max)
  - [ ] iPhone 6.5"
  - [ ] Apple Watch Series 7+ (41mm & 45mm)
- [ ] App description written
- [ ] Keywords selected (accessibility, sensory, autism, ADHD, quiet, noise, neurodiverse)
- [ ] Support URL or email
- [ ] Marketing URL (optional)

#### Privacy & Legal
- [✅] Privacy Policy URL: https://www.pharmatools.ai/privacy-policy
  - [ ] Verify URL is live and accessible
  - [ ] Confirm covers location data, HealthKit, Google Maps, OpenAI
- [✅] Terms of Service URL: https://www.pharmatools.ai/terms
  - [ ] Verify URL is live and accessible
- [✅] Account deletion implemented (ProfileView.swift:671-722)
- [✅] NSLocationWhenInUseUsageDescription in Info.plist
- [✅] NSMicrophoneUsageDescription in Info.plist (Watch)
- [✅] NSHealthShareUsageDescription in Info.plist (Watch)
- [ ] Age rating selected (recommend: 4+)
- [ ] Export compliance declaration (encryption: YES - HTTPS/OAuth)

#### Permissions Testing
- [ ] Test location permission flow (first launch)
- [ ] Test microphone permission (Watch app)
- [ ] Test HealthKit permission (Watch app)
- [ ] Verify graceful handling when permissions denied
- [ ] Test "Always Allow" vs "While Using" location

### Performance Metrics (from Instruments)

#### iOS App
- [ ] App launch time: ____s (target: <2s)
- [ ] Memory usage (typical): ____MB (target: <150MB)
- [ ] Memory usage (peak): ____MB (target: <200MB)
- [ ] No memory leaks in 15-minute session
- [ ] No frame drops during map interaction (60fps)

#### Watch App
- [ ] App launch time: ____s (target: <1.5s)
- [ ] Memory usage: ____MB (target: <50MB)
- [ ] HealthKit query latency: ____ms
- [ ] Watch sync latency: ____ms (target: <500ms)

### Device Testing

#### iOS Testing
- [ ] iPhone 15 Pro (high-end) - All features work
- [ ] iPhone 12 (low-end threshold) - Acceptable performance
- [ ] iPad (if supported) - Layout adapts properly
- [ ] iOS 17.0 (minimum version) - No crashes
- [ ] iOS 18.5 (latest) - All features work

#### watchOS Testing
- [ ] Apple Watch Series 7+ - All features work
- [ ] Test on physical Watch (not just simulator)
- [ ] HealthKit integration works on device
- [ ] Watch Connectivity syncs properly
- [ ] Complications display correctly (if implemented)

### Feature Testing

#### Core Functionality
- [ ] Map displays with Google Maps API key
- [ ] Add report flow (anonymous + authenticated)
- [ ] AI predictions generate successfully
- [ ] Nearby view loads and sorts correctly
- [ ] Filters work (quiet/noisy, open now, distance)
- [ ] Authentication flows:
  - [ ] Google Sign-In
  - [ ] Apple Sign-In
  - [ ] Anonymous mode
  - [ ] Sign out
  - [ ] Account deletion

#### Watch App
- [ ] GlanceView shows quiet score
- [ ] LogView sends reports to iPhone
- [ ] HealthKit sound monitoring works
- [ ] Offline queueing (reports sync later)
- [ ] Watch Connectivity syncs both directions

#### Offline Mode
- [ ] App doesn't crash without internet
- [ ] Reports queue locally
- [ ] Map shows cached data
- [ ] Error messages are user-friendly
- [ ] Sync works when connection restored

### Accessibility

#### VoiceOver Testing
- [ ] All buttons have descriptive labels
- [ ] Map markers are accessible
- [ ] Forms are navigable
- [ ] Images have alt text (where meaningful)
- [ ] No accessibility traps (can navigate everywhere)

#### Dynamic Type
- [ ] Test at largest text size (AX5)
- [ ] No text truncation
- [ ] Layouts adjust properly
- [ ] Buttons remain tappable

#### High Contrast Mode
- [ ] Toggle in ProfileView works
- [ ] All text is readable
- [ ] Important UI elements stand out

#### Sensory Accessibility (Meta - HushMap helps with this!)
- [ ] No flashing animations
- [ ] Haptics are gentle/optional
- [ ] Color is not sole indicator of meaning

### Error Testing

#### Network Errors
- [ ] Test with airplane mode
- [ ] Test with slow 3G connection
- [ ] Test API quota exceeded
- [ ] Test invalid API responses

#### Permission Errors
- [ ] Location denied
- [ ] Microphone denied (Watch)
- [ ] HealthKit denied (Watch)

#### Data Errors
- [ ] Empty database (first launch)
- [ ] Corrupted SwiftData store
- [ ] Invalid report data
- [ ] Malformed AI predictions

### App Store Rejection Risks

#### High Risk - Must Fix
- [ ] Privacy policy URL must be accessible
- [ ] Account deletion must work properly
- [ ] All permissions must have clear descriptions
- [ ] App must not crash on first launch
- [ ] Must handle network errors gracefully

#### Medium Risk - Review Carefully
- [ ] API keys properly secured (consider backend proxy)
- [ ] OpenAI usage monitored (cost control)
- [ ] Google Maps quota monitored
- [ ] User data properly encrypted at rest
- [ ] No hard-coded credentials in code

#### Low Risk - Best Practices
- [ ] Accessibility best practices followed
- [ ] Performance meets expectations
- [ ] UI polish matches competition
- [ ] Error messages are helpful

### Pre-Submission Final Steps

- [ ] Clean build with zero warnings
- [ ] Archive builds successfully for distribution
- [ ] Test archived build on physical device (not just Xcode build)
- [ ] Verify version number incremented
- [ ] Verify bundle ID matches App Store Connect
- [ ] Update release notes for this version
- [ ] Screenshot all required device sizes
- [ ] Prepare App Store description and marketing copy

---

## 🎯 Sign-Off Statement

**Before submitting, confirm:**

> I have tested HushMap on physical devices (iPhone and Apple Watch), verified all core features work correctly, confirmed the app handles errors gracefully, validated performance is acceptable on low-end devices, and ensured all App Store requirements are met.

**Signed:** _____________
**Date:** _____________

**Known Issues (if any):**
-
-

**Next Steps After Approval:**
- Backend server for shared community reports
- Real cloud sync (currently placeholder)
- Watch complications
- In-app tutorial/help
- Advanced AI features (mood tracking, pattern analysis)

---

## 📊 Estimated Time to Complete

- **Performance audit:** 2-3 hours
- **Memory profiling:** 1-2 hours
- **UI polish:** 3-4 hours
- **Error handling review:** 2-3 hours
- **Code cleanup:** 1-2 hours
- **Testing (all scenarios):** 4-6 hours
- **Documentation:** 1-2 hours

**Total:** 14-22 hours of focused work

---

## 🚨 Critical Path Items (Must Do First)

1. Verify privacy policy URLs are live and accurate
2. Test account deletion flow end-to-end
3. Profile for memory leaks and crashes
4. Test on physical iPhone 12 (low-end device)
5. Test Watch app on physical Apple Watch
6. Complete accessibility testing with VoiceOver

Everything else can be done in parallel or as time permits.
