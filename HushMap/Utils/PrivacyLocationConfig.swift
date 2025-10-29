import Foundation

/// Configuration for Places POI snapping and confidence tuning
struct PlacesTuning {
    var poiMaxRadiusMeters: Double = 35   // widened from 25
    var snapWindowMeters: Double = 18     // hard "snap" window
    var denseCompetitionMeters: Double = 12
    var minConfidenceForDirectPOI: Double = 0.80
    var minConfidenceForHedgedPOI: Double = 0.65
    var poiTypePriority: [String] = [
        "lodging","supermarket","grocery_or_supermarket","pharmacy",
        "restaurant","cafe","bank","book_store","clothing_store",
        "shopping_mall","department_store","convenience_store"
    ]
}

/// Configuration for privacy-aware location labeling with kill-switch and tuning controls
struct PrivacyLocationConfig {
    
    // MARK: - Keys
    private enum Keys {
        static let areaOnlyOverride = "privacy.location.areaOnlyOverride"
        static let confidenceHedgeThreshold = "privacy.location.confidenceHedgeThreshold"
        static let usePlacesEnrichment = "privacy.location.usePlacesEnrichment"
        static let poiMaxRadiusMeters = "privacy.location.poiMaxRadiusMeters"
        static let snapWindowMeters = "privacy.location.snapWindowMeters"
        static let denseCompetitionMeters = "privacy.location.denseCompetitionMeters"
        static let minConfidenceForDirectPOI = "privacy.location.minConfidenceForDirectPOI"
        static let minConfidenceForHedgedPOI = "privacy.location.minConfidenceForHedgedPOI"
    }
    
    // MARK: - Properties
    
    /// Kill-switch: forces .area tier everywhere, bypassing POI/street resolution
    var areaOnlyOverride: Bool {
        get { UserDefaults.standard.bool(forKey: Keys.areaOnlyOverride) }
        set { UserDefaults.standard.set(newValue, forKey: Keys.areaOnlyOverride) }
    }
    
    /// Confidence threshold for hedged copy (e.g., "near Cafe" instead of "Cafe")
    var confidenceHedgeThreshold: Double {
        get { 
            let value = UserDefaults.standard.double(forKey: Keys.confidenceHedgeThreshold)
            return value > 0 ? value : 0.80 // Default to 0.80 if not set
        }
        set { UserDefaults.standard.set(newValue, forKey: Keys.confidenceHedgeThreshold) }
    }
    
    /// Feature flag to enable Google Places API enrichment
    var usePlacesEnrichment: Bool {
        get { 
            // Check if value exists in UserDefaults
            if UserDefaults.standard.object(forKey: Keys.usePlacesEnrichment) != nil {
                return UserDefaults.standard.bool(forKey: Keys.usePlacesEnrichment)
            }
            return true // Default to true if not set
        }
        set { UserDefaults.standard.set(newValue, forKey: Keys.usePlacesEnrichment) }
    }
    
    /// Maximum radius in meters for POI search
    var poiMaxRadiusMeters: Double {
        get {
            let value = UserDefaults.standard.double(forKey: Keys.poiMaxRadiusMeters)
            return value > 0 ? value : 35.0 // Default to 35m (widened from 25)
        }
        set { UserDefaults.standard.set(newValue, forKey: Keys.poiMaxRadiusMeters) }
    }
    
    /// Distance for hard "snap" window to POI
    var snapWindowMeters: Double {
        get {
            let value = UserDefaults.standard.double(forKey: Keys.snapWindowMeters)
            return value > 0 ? value : 18.0
        }
        set { UserDefaults.standard.set(newValue, forKey: Keys.snapWindowMeters) }
    }
    
    /// Distance threshold for considering POIs as competing (dense area detection)
    var denseCompetitionMeters: Double {
        get {
            let value = UserDefaults.standard.double(forKey: Keys.denseCompetitionMeters)
            return value > 0 ? value : 12.0
        }
        set { UserDefaults.standard.set(newValue, forKey: Keys.denseCompetitionMeters) }
    }
    
    /// Minimum confidence for direct POI name (no hedging)
    var minConfidenceForDirectPOI: Double {
        get {
            let value = UserDefaults.standard.double(forKey: Keys.minConfidenceForDirectPOI)
            return value > 0 ? value : 0.80
        }
        set { UserDefaults.standard.set(newValue, forKey: Keys.minConfidenceForDirectPOI) }
    }
    
    /// Minimum confidence for hedged POI ("near {name}")
    var minConfidenceForHedgedPOI: Double {
        get {
            let value = UserDefaults.standard.double(forKey: Keys.minConfidenceForHedgedPOI)
            return value > 0 ? value : 0.65
        }
        set { UserDefaults.standard.set(newValue, forKey: Keys.minConfidenceForHedgedPOI) }
    }
    
    /// POI type priority for tie-breaking
    var poiTypePriority: [String] {
        return [
            "lodging","supermarket","grocery_or_supermarket","pharmacy",
            "restaurant","cafe","bank","book_store","clothing_store",
            "shopping_mall","department_store","convenience_store"
        ]
    }
    
    /// Get PlacesTuning configuration from current settings
    var placesTuning: PlacesTuning {
        return PlacesTuning(
            poiMaxRadiusMeters: poiMaxRadiusMeters,
            snapWindowMeters: snapWindowMeters,
            denseCompetitionMeters: denseCompetitionMeters,
            minConfidenceForDirectPOI: minConfidenceForDirectPOI,
            minConfidenceForHedgedPOI: minConfidenceForHedgedPOI,
            poiTypePriority: poiTypePriority
        )
    }
    
    // MARK: - Singleton
    static let shared = PrivacyLocationConfig()
    private init() {}
}