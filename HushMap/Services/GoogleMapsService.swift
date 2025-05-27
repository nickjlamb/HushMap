import Foundation
import GoogleMaps

class GoogleMapsService {
    static let shared = GoogleMapsService()
    
    private init() {}
    
    func configure() {
        let apiKey = "AIzaSyDm5Wy2ItNOE9pX4WfIFyvlMVKE02WFNgw"
        
        if apiKey == "YOUR_GOOGLE_MAPS_API_KEY_HERE" {
            print("⚠️ WARNING: Please set your Google Maps API key in GoogleMapsService.swift")
            print("📝 Get your API key from: https://console.cloud.google.com/")
            print("🔗 Enable Maps SDK for iOS")
        } else {
            GMSServices.provideAPIKey(apiKey)
            print("✅ Google Maps configured successfully")
        }
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
