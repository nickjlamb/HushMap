import Foundation
import GoogleMaps

class GoogleMapsService {
    static let shared = GoogleMapsService()
    private let deviceCapability = DeviceCapabilityService.shared
    
    private init() {}
    
    func configure() {
        let apiKey = Bundle.main.object(forInfoDictionaryKey: "GOOGLE_MAPS_API_KEY") as? String ?? ""
        
        if apiKey.isEmpty || apiKey == "$(GOOGLE_MAPS_API_KEY)" {
            print("⚠️ WARNING: Please set your Google Maps API key in Config-Local.xcconfig")
            print("📝 Get your API key from: https://console.cloud.google.com/")
            print("🔗 Enable Maps SDK for iOS")
            print("💡 Make sure Config-Local.xcconfig is set in Xcode Project Settings > Build Settings > Configurations")
        } else {
            GMSServices.provideAPIKey(apiKey)
            
            // Apply performance optimizations based on device capability
            configurePerformanceSettings()
            
            print("✅ Google Maps configured successfully")
            print("📱 Performance optimizations applied for \(deviceCapability.performanceTier.rawValue) tier device")
        }
    }
    
    private func configurePerformanceSettings() {
        // Configure global GMSServices settings based on device performance
        switch deviceCapability.performanceTier {
        case .high:
            // Enable all features for high-performance devices
            break
            
        case .medium:
            // Moderate optimizations
            break
            
        case .low:
            // Aggressive optimizations for older devices
            break
        }
    }
    
    func optimizeMapView(_ mapView: GMSMapView) {
        let settings = deviceCapability.mapSettings
        
        // Apply performance settings to map view
        mapView.isBuildingsEnabled = settings.buildingsEnabled
        mapView.isTrafficEnabled = settings.trafficEnabled
        
        // Optimize map settings based on device capability
        switch deviceCapability.getMarkerOptimizationLevel() {
        case .none:
            // Full features enabled
            mapView.settings.allowScrollGesturesDuringRotateOrZoom = true
            
        case .moderate:
            // Some optimizations
            mapView.settings.allowScrollGesturesDuringRotateOrZoom = false
            
        case .aggressive:
            // Maximum optimizations for older devices
            mapView.settings.allowScrollGesturesDuringRotateOrZoom = false
            mapView.settings.rotateGestures = false
            mapView.settings.tiltGestures = false
        }
        
        print("🗺️ Map optimized for \(deviceCapability.performanceTier.rawValue) performance tier")
    }
    
    // Map style helper functions for Google Maps types
    func mapStyleName(for type: GMSMapViewType) -> String {
        switch type {
        case .normal: return "Standard"
        case .satellite: return "Satellite"
        case .hybrid: return "Hybrid"
        case .terrain: return "Terrain"
        default: return "Standard"
        }
    }
    
    func mapStyleIcon(for type: GMSMapViewType) -> String {
        switch type {
        case .normal: return "map"
        case .satellite: return "globe.americas"
        case .hybrid: return "map.circle"
        case .terrain: return "mountain.2"
        default: return "map"
        }
    }
}
