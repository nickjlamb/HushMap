# HushMap

A sensory mapping iOS app that helps users find quiet or stimulating environments based on their sensory preferences, built for the Google Maps Platform Awards.

## Features

- **Sensory Mapping**: Report and discover sensory levels of venues
- **Smart Predictions**: AI-powered predictions for venue sensory levels
- **Authentication**: Google and Apple Sign In support
- **Privacy First**: Complete account deletion and data management
- **Location Services**: Find nearby venues with sensory information

## Setup

### Prerequisites

- Xcode 15.0+
- iOS 17.0+
- Google Maps SDK
- Google Places API access

### API Configuration

**⚠️ IMPORTANT: API Key Security**

1. Copy `HushMap/Config.xcconfig` to `HushMap/Config-Local.xcconfig`
2. Add your actual API keys to `Config-Local.xcconfig`:
   ```
   GOOGLE_MAPS_API_KEY = your_google_maps_api_key_here
   GOOGLE_PLACES_API_KEY = your_google_places_api_key_here
   ```
3. The `Config-Local.xcconfig` file is gitignored for security

### Google API Setup

You'll need to:
1. Enable Google Maps SDK for iOS
2. Enable Google Places API (New)
3. Configure OAuth 2.0 for Google Sign In
4. Set up proper API key restrictions

See `GOOGLE_MAPS_SETUP.md` and `NEW_PLACES_API_SETUP.md` for detailed instructions.

## Architecture

- **SwiftUI**: Modern iOS UI framework
- **SwiftData**: Local data persistence
- **MVVM Pattern**: Clean separation of concerns
- **Singleton Services**: Shared authentication and location services

## Privacy & Security

- API keys are stored in gitignored configuration files
- Complete user data deletion capabilities
- Compliance with GDPR, CCPA, and Apple privacy guidelines
- Minimal data collection approach
- Proper API key restrictions to prevent unauthorized usage (see API_KEY_SECURITY.md)

## License

MIT License - see LICENSE file for details.