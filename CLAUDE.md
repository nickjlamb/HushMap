# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

HushMap is a SwiftUI-based iOS application for sensory mapping and accessibility, helping users find quiet or stimulating environments based on their sensory preferences. Built for the Google Maps Platform Awards.

## Build Commands

```bash
# Build the project
xcodebuild -project HushMap.xcodeproj -scheme HushMap -configuration Debug build

# Clean and build
xcodebuild -project HushMap.xcodeproj -scheme HushMap clean build

# Build for device
xcodebuild -project HushMap.xcodeproj -scheme HushMap -sdk iphoneos build

# Run in simulator (requires Xcode)
open HushMap.xcodeproj
# Then press Cmd+R in Xcode
```

## Architecture

The app follows **MVVM + SwiftUI + SwiftData** architecture:

- **Models** (`HushMap/Models/`): SwiftData models for persistence
  - Core models: `Report`, `User`, `Badge`, `SensoryProfile`, `SensoryPrediction`
  
- **Services** (`HushMap/Services/`): Singleton services (@MainActor)
  - `AuthenticationService`: Google/Apple Sign-In
  - `LocationManager`: Core Location wrapper
  - `PlaceService` + `GoogleMapsService`: Maps integration
  - `OpenAIService` + `PredictionService`: AI predictions
  - `AudioAnalysisService`: Sound level measurement

- **Views** (`HushMap/Views/`): SwiftUI views
  - Main views: `HomeMapView`, `ProfileView`, `NearbyView`
  - Components in `Views/Components/`

- **ViewModels** (`HushMap/ViewModels/`): ObservableObject view models

## Key Development Patterns

1. **State Management**: Use `@Published` in ViewModels, `@State`/`@StateObject` in Views
2. **Navigation**: SwiftUI sheets and navigation stacks (no UIKit navigation)
3. **Async/Await**: All network calls use modern Swift concurrency
4. **Error Handling**: Services throw errors, ViewModels handle and display them
5. **SwiftData**: Models use `@Model` macro, container initialized in `HushMapApp.swift`

## Configuration Setup

1. Copy `Config.xcconfig` to `Config-Local.xcconfig`
2. Add required API keys:
   - `GOOGLE_MAPS_API_KEY`
   - `GOOGLE_PLACES_API_KEY`
   - `OPENAI_API_KEY`

## Common Tasks

### Adding a New Feature
1. Create model in `Models/` if needed (use `@Model` for persistence)
2. Add service logic to existing service or create new one in `Services/`
3. Create ViewModel in `ViewModels/` with `@Published` properties
4. Build SwiftUI view in `Views/`
5. Add navigation from appropriate parent view

### Working with Google Maps
- Maps views use `GoogleMapsView` wrapper in `Views/Components/`
- Place searches go through `PlaceService.searchPlaces()`
- Always check `isConfigured` before using map services

### Working with AI Predictions
- Predictions flow: `PredictionService` → `OpenAIService` → OpenAI API
- CSV data loaded via `CSVLoader` utility
- Predictions cached in SwiftData via `SensoryPrediction` model

### Handling Authentication
- All auth through `AuthenticationService.shared`
- User state in `authService.currentUser`
- Sign-in methods: `signInWithGoogle()`, `signInWithApple()`

## Testing
Currently no unit tests configured. Test manually through Xcode simulator or device.

## Important Notes
- Minimum iOS version: 17.0
- Uses SwiftData (iOS 17+ only)
- All services are `@MainActor` singletons
- API keys must be properly configured in Google Cloud Console
- Privacy permissions required: location, microphone