# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

HushMap is an advanced iOS application for sensory accessibility mapping, built with SwiftUI and SwiftData. It helps users with sensory sensitivities find comfortable environments through AI-powered predictions and community-driven data. Developed for the Google Maps Platform Awards.

## Build Commands

```bash
# Build for simulator
xcodebuild -project HushMap.xcodeproj -scheme HushMap -configuration Debug build

# Clean build
xcodebuild -project HushMap.xcodeproj -scheme HushMap clean build

# Build for device deployment
xcodebuild -project HushMap.xcodeproj -scheme HushMap -sdk iphoneos -configuration Release build

# Run tests (when available)
xcodebuild -project HushMap.xcodeproj -scheme HushMap test

# Open in Xcode IDE
open HushMap.xcodeproj
```

## Architecture Overview

### Core Pattern: MVVM + SwiftUI + SwiftData

The app uses a layered architecture with clear separation of concerns:

1. **Data Layer** (`Models/`): SwiftData models with `@Model` macro
   - `Report`: Sensory environment data (noise, crowds, lighting, comfort)
   - `User`: Authentication, points, badges, sensory profile
   - `SensoryProfile`: AI learning system tracking user preferences
   - Relationships: User ↔ Reports ↔ SensoryProfile with proper inverses

2. **Service Layer** (`Services/`): @MainActor singleton services
   - All services use `shared` singleton pattern for thread safety
   - Services handle external APIs, device capabilities, and business logic
   - Error handling through `AppError` enum with comprehensive cases

3. **Presentation Layer**: SwiftUI views with reactive state
   - Views in `Views/` use `@State`, `@StateObject`, `@ObservedObject`
   - ViewModels use `@Published` for reactive updates
   - SwiftData `@Query` for automatic UI updates from database

### Key Architectural Components

#### AI Prediction System
The app implements a sophisticated hybrid prediction system:
- **Primary**: OpenAI GPT-4 predictions via `PredictionService` → `OpenAIService`
- **Fallback**: Algorithmic predictions based on venue type, time, weather
- **Learning**: `SensoryProfile` adapts to user comfort levels using exponential moving averages
- **Validation**: Multi-stage AI response validation with structured parsing

#### Performance Optimization
Device capability-aware rendering system:
- `DeviceCapabilityService` categorizes devices (High/Medium/Low)
- Map markers adapt complexity based on device tier
- Clustering algorithms scale with performance capabilities
- Animation durations adjust to maintain smooth UX

#### Authentication Flow
Multi-provider authentication with privacy support:
- Google Sign-In and Apple Sign-In via `AuthenticationService`
- Anonymous mode with full functionality
- User data association after authentication
- GDPR-compliant account deletion

## Critical Development Patterns

### State Management Rules
1. **Services**: Always `@MainActor` singletons with `shared` instance
2. **ViewModels**: Use `@Published` for properties that trigger UI updates
3. **Views**: `@StateObject` for owned ViewModels, `@ObservedObject` for injected
4. **SwiftData**: `@Query` in views for reactive database updates

### Navigation Architecture
- Sheet-based modal presentation (no UIKit navigation controllers)
- State cleanup in `.onDisappear` modifiers
- Welcome/onboarding flow managed at app level in `HushMapApp`

### Error Handling Pattern
```swift
// Services throw errors
func fetchData() async throws -> Data

// ViewModels handle and display
do {
    data = try await service.fetchData()
} catch {
    self.error = error
    self.showAlert = true
}
```

### Google Maps Integration
- Always check `GoogleMapsService.shared.isConfigured` before map operations
- Use `GoogleMapsView` wrapper component for SwiftUI integration
- Handle POI taps, map taps, and marker interactions separately
- Device-aware marker rendering for performance

## Configuration Requirements

1. Create `Config-Local.xcconfig` from `Config.xcconfig` template
2. Required API keys:
   - `GOOGLE_MAPS_API_KEY`: Maps SDK and Places API
   - `GOOGLE_PLACES_API_KEY`: Place search and autocomplete
   - `OPENAI_API_KEY`: AI predictions
3. Configure Google Cloud Console:
   - Enable Maps SDK for iOS
   - Enable Places API
   - Add bundle identifier to API key restrictions

## Working with Key Features

### Adding New Sensory Data Types
1. Update `Report` model with new property
2. Modify `PredictionService.generatePrediction()` prompt
3. Add UI controls in `AddReportView`
4. Update `SensoryProfile` learning algorithm if needed

### Implementing New AI Features
1. Add method to `OpenAIService` for API call
2. Create validation in `PredictionService`
3. Implement fallback algorithm for when AI unavailable
4. Cache results in SwiftData model if appropriate

### Modifying Map Behavior
1. Edit `GoogleMapsView` for map configuration
2. Update `HomeMapViewModel` for data management
3. Adjust `DeviceCapabilityService` thresholds for performance
4. Test on low-end devices (iPhone 12 or older)

### Database Migrations
- SwiftData handles simple migrations automatically
- For complex changes, implement migration plan in `modelContainer` initialization
- Test migration path from previous app version

## Performance Considerations

- **Map Markers**: Limited to 100 on low-end devices, 500 on high-end
- **Clustering**: Enabled when >50 markers visible
- **AI Predictions**: Cached for 24 hours to reduce API calls
- **Images**: Lazy loaded in lists, cached in memory
- **Animations**: Duration scales with device capability

## Privacy & Permissions

Required Info.plist keys already configured:
- `NSLocationWhenInUseUsageDescription`: Location for nearby places
- `NSMicrophoneUsageDescription`: Sound level measurement
- `NSCameraUsageDescription`: Photo uploads (if implemented)

## Testing Approach

Manual testing checklist:
1. Test on iPhone 12 (low-end) and iPhone 15 Pro (high-end)
2. Verify anonymous mode → authenticated transition
3. Test offline behavior and error states
4. Validate AI prediction fallbacks
5. Check accessibility with VoiceOver
6. Test Dynamic Type scaling

## Important Technical Constraints

- **Minimum iOS**: 17.0 (required for SwiftData)
- **Swift Concurrency**: All async operations use async/await
- **Thread Safety**: All UI updates on @MainActor
- **Memory**: Profile with Instruments for leaks
- **API Quotas**: Monitor Google Maps and OpenAI usage