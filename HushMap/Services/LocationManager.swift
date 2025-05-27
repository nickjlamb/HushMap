import Foundation
import CoreLocation

class LocationManager: NSObject, ObservableObject, CLLocationManagerDelegate {
    private let locationManager = CLLocationManager()
    @Published var lastLocation: CLLocationCoordinate2D?
    @Published var authorizationStatus: CLAuthorizationStatus = .notDetermined
    
    // Workaround for potential warnings about locationServicesEnabled
    @Published var isLocationReady = false

    override init() {
        super.init()
        
        // Setup manager
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
    }
    
    // This needs to be called after init, not during init
    func requestLocationPermission() {
        // This call can be made from anywhere, including HomeMapView.onAppear
        locationManager.requestWhenInUseAuthorization()
    }
    
    // Called by delegate when authorization changes
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.authorizationStatus = manager.authorizationStatus
            
            switch manager.authorizationStatus {
            case .authorizedWhenInUse, .authorizedAlways:
                self.locationManager.startUpdatingLocation()
                self.isLocationReady = true
            case .denied, .restricted:
                print("Location access was denied or restricted")
                self.isLocationReady = false
            case .notDetermined:
                // Wait for user to make a choice
                self.isLocationReady = false
            @unknown default:
                print("Unknown authorization status")
                self.isLocationReady = false
            }
        }
    }

    // Called by delegate when location updates
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        DispatchQueue.main.async { [weak self] in
            guard let location = locations.last else { return }
            self?.lastLocation = location.coordinate
        }
    }
}