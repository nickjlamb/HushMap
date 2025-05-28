import Foundation
import CoreLocation

class LocationManager: NSObject, ObservableObject, CLLocationManagerDelegate {
    private let locationManager = CLLocationManager()
    @Published var lastLocation: CLLocationCoordinate2D?
    @Published var authorizationStatus: CLAuthorizationStatus = .notDetermined
    @Published var locationError: AppError?
    
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
        // Check location services asynchronously before requesting permission
        Task {
            let servicesEnabled = CLLocationManager.locationServicesEnabled()
            
            await MainActor.run {
                if !servicesEnabled {
                    self.locationError = AppError.location(.serviceDisabled)
                } else {
                    // Only request permission if services are enabled
                    self.locationManager.requestWhenInUseAuthorization()
                }
            }
        }
    }
    
    // Called by delegate when authorization changes
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.authorizationStatus = manager.authorizationStatus
            self.locationError = nil // Clear any previous errors
            
            switch manager.authorizationStatus {
            case .authorizedWhenInUse, .authorizedAlways:
                self.locationManager.startUpdatingLocation()
                self.isLocationReady = true
            case .denied:
                self.locationError = AppError.location(.permissionDenied)
                self.isLocationReady = false
            case .restricted:
                self.locationError = AppError.location(.permissionRestricted)
                self.isLocationReady = false
            case .notDetermined:
                // Wait for user to make a choice
                self.isLocationReady = false
            @unknown default:
                self.locationError = AppError.general(.unexpectedError)
                self.isLocationReady = false
            }
        }
    }

    // Called by delegate when location updates
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        DispatchQueue.main.async { [weak self] in
            guard let location = locations.last else { return }
            self?.lastLocation = location.coordinate
            self?.locationError = nil // Clear any location errors on success
        }
    }
    
    // Called by delegate when location update fails
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            if let clError = error as? CLError {
                switch clError.code {
                case .denied:
                    self.locationError = AppError.location(.permissionDenied)
                case .locationUnknown:
                    self.locationError = AppError.location(.locationUnavailable)
                case .network:
                    self.locationError = AppError.network(.noConnection)
                default:
                    self.locationError = AppError.location(.locationUnavailable)
                }
            } else {
                self.locationError = AppError.general(.unexpectedError)
            }
        }
    }
}