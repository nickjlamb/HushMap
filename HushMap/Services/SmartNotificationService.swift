import Foundation
import CoreLocation
import UserNotifications
import SwiftData

class SmartNotificationService: NSObject, ObservableObject {
    @Published var isMonitoring: Bool = false
    @Published var lastNotificationTime: Date?
    
    private let locationManager = CLLocationManager()
    private let notificationCenter = UNUserNotificationCenter.current()
    private var modelContext: ModelContext
    private var sensoryProfileService: SensoryProfileService
    
    // Notification settings
    private let minimumNotificationInterval: TimeInterval = 300 // 5 minutes between notifications
    private let monitoringRadius: CLLocationDistance = 100 // 100 meters
    private let confidenceThreshold: Double = 0.3 // Minimum profile confidence to send notifications
    
    init(modelContext: ModelContext) {
        self.modelContext = modelContext
        self.sensoryProfileService = SensoryProfileService(modelContext: modelContext)
        
        super.init()
        
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        locationManager.distanceFilter = 50 // Update every 50 meters
        
        setupNotifications()
    }
    
    // MARK: - Setup and Permissions
    
    func setupNotifications() {
        requestNotificationPermission()
        requestLocationPermission()
    }
    
    private func requestNotificationPermission() {
        notificationCenter.requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            DispatchQueue.main.async {
                if granted {
                    print("Notification permission granted")
                } else {
                    print("Notification permission denied: \(error?.localizedDescription ?? "Unknown error")")
                }
            }
        }
    }
    
    private func requestLocationPermission() {
        switch locationManager.authorizationStatus {
        case .notDetermined:
            locationManager.requestWhenInUseAuthorization()
        case .denied, .restricted:
            print("Location permission denied")
        case .authorizedWhenInUse:
            startLocationMonitoring()
        case .authorizedAlways:
            startLocationMonitoring()
        @unknown default:
            break
        }
    }
    
    // MARK: - Location Monitoring
    
    func startLocationMonitoring() {
        guard locationManager.authorizationStatus == .authorizedWhenInUse ||
              locationManager.authorizationStatus == .authorizedAlways else {
            print("Location permission not granted")
            return
        }
        
        locationManager.startUpdatingLocation()
        isMonitoring = true
        print("Started smart notification monitoring")
    }
    
    func stopLocationMonitoring() {
        locationManager.stopUpdatingLocation()
        isMonitoring = false
        print("Stopped smart notification monitoring")
    }
    
    // MARK: - Smart Notification Logic
    
    private func checkForSensoryWarnings(at location: CLLocation) {
        // Don't send notifications too frequently
        if let lastTime = lastNotificationTime,
           Date().timeIntervalSince(lastTime) < minimumNotificationInterval {
            return
        }
        
        // Get current user and their sensory profile
        let userService = UserService(modelContext: modelContext)
        let currentUser = userService.getCurrentUser()
        
        guard let profile = currentUser.sensoryProfile,
              profile.confidenceScore >= confidenceThreshold else {
            return // Profile not confident enough for notifications
        }
        
        // Find nearby reports to analyze sensory conditions
        let nearbyReports = findNearbyReports(location: location, radius: monitoringRadius)
        
        guard !nearbyReports.isEmpty else { return }
        
        // Calculate average sensory levels for the area
        let averageNoise = nearbyReports.map { $0.noise }.reduce(0, +) / Double(nearbyReports.count)
        let averageCrowds = nearbyReports.map { $0.crowds }.reduce(0, +) / Double(nearbyReports.count)
        let averageLighting = nearbyReports.map { $0.lighting }.reduce(0, +) / Double(nearbyReports.count)
        
        // Check if this area should trigger a warning
        let warningResult = profile.shouldWarnFor(
            noise: averageNoise,
            crowds: averageCrowds,
            lighting: averageLighting,
            threshold: 0.25 // Slightly more sensitive for proactive warnings
        )
        
        if warningResult.shouldWarn {
            sendSensoryWarningNotification(
                location: location,
                reasons: warningResult.reasons,
                reportCount: nearbyReports.count
            )
        }
    }
    
    private func findNearbyReports(location: CLLocation, radius: CLLocationDistance) -> [Report] {
        let fetchDescriptor = FetchDescriptor<Report>()
        
        do {
            let allReports = try modelContext.fetch(fetchDescriptor)
            
            // Filter reports within radius
            let nearbyReports = allReports.filter { report in
                let reportLocation = CLLocation(latitude: report.latitude, longitude: report.longitude)
                return location.distance(from: reportLocation) <= radius
            }
            
            // Only consider recent reports (within last 30 days)
            let thirtyDaysAgo = Date().addingTimeInterval(-30 * 24 * 60 * 60)
            return nearbyReports.filter { $0.timestamp >= thirtyDaysAgo }
            
        } catch {
            print("Error fetching nearby reports: \(error)")
            return []
        }
    }
    
    // MARK: - Notification Sending
    
    private func sendSensoryWarningNotification(
        location: CLLocation,
        reasons: [String],
        reportCount: Int
    ) {
        let content = UNMutableNotificationContent()
        content.title = "🔔 Sensory Alert"
        
        let reasonText = reasons.joined(separator: " and ")
        content.body = "This area tends to be \(reasonText) based on \(reportCount) recent reports. Consider alternative routes."
        
        content.sound = .default
        content.categoryIdentifier = "SENSORY_WARNING"
        
        // Add custom data
        content.userInfo = [
            "type": "sensory_warning",
            "latitude": location.coordinate.latitude,
            "longitude": location.coordinate.longitude,
            "reasons": reasons,
            "reportCount": reportCount
        ]
        
        // Create trigger (immediate notification)
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 0.1, repeats: false)
        
        // Create request
        let request = UNNotificationRequest(
            identifier: "sensory_warning_\(Date().timeIntervalSince1970)",
            content: content,
            trigger: trigger
        )
        
        // Schedule notification
        notificationCenter.add(request) { error in
            DispatchQueue.main.async {
                if let error = error {
                    print("Error sending notification: \(error)")
                } else {
                    self.lastNotificationTime = Date()
                    print("Sent sensory warning notification")
                }
            }
        }
    }
    
    // MARK: - Helpful Areas Notifications
    
    private func sendHelpfulAreaNotification(location: CLLocation, reportCount: Int) {
        let content = UNMutableNotificationContent()
        content.title = "😌 Sensory-Friendly Area"
        content.body = "You're near an area that matches your sensory preferences! Based on \(reportCount) reports, this area tends to be comfortable for you."
        content.sound = .default
        content.categoryIdentifier = "HELPFUL_AREA"
        
        content.userInfo = [
            "type": "helpful_area",
            "latitude": location.coordinate.latitude,
            "longitude": location.coordinate.longitude,
            "reportCount": reportCount
        ]
        
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 0.1, repeats: false)
        let request = UNNotificationRequest(
            identifier: "helpful_area_\(Date().timeIntervalSince1970)",
            content: content,
            trigger: trigger
        )
        
        notificationCenter.add(request) { error in
            DispatchQueue.main.async {
                if let error = error {
                    print("Error sending helpful area notification: \(error)")
                } else {
                    self.lastNotificationTime = Date()
                    print("Sent helpful area notification")
                }
            }
        }
    }
    
    // MARK: - Settings and Management
    
    func enableSmartNotifications() {
        startLocationMonitoring()
    }
    
    func disableSmartNotifications() {
        stopLocationMonitoring()
    }
    
    func getNotificationSettings() -> (enabled: Bool, lastNotification: Date?) {
        return (isMonitoring, lastNotificationTime)
    }
    
    // Test notification for demo purposes
    func sendTestNotification() {
        let content = UNMutableNotificationContent()
        content.title = "🧠 HushMap AI Test"
        content.body = "Smart notifications are working! HushMap will now warn you about areas that don't match your sensory preferences."
        content.sound = .default
        
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        let request = UNNotificationRequest(identifier: "test_notification", content: content, trigger: trigger)
        
        notificationCenter.add(request) { error in
            if let error = error {
                print("Error sending test notification: \(error)")
            } else {
                print("Sent test notification")
            }
        }
    }
    
    // Demo: Send a sample sensory warning notification
    func sendDemoSensoryWarning() {
        let content = UNMutableNotificationContent()
        content.title = "🔔 Sensory Alert"
        content.body = "This area tends to be louder than your preference and more crowded than your preference based on 3 recent reports. Consider alternative routes."
        content.sound = .default
        content.categoryIdentifier = "SENSORY_WARNING"
        
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 2, repeats: false)
        let request = UNNotificationRequest(identifier: "demo_sensory_warning", content: content, trigger: trigger)
        
        notificationCenter.add(request) { error in
            if let error = error {
                print("Error sending demo warning: \(error)")
            } else {
                print("Sent demo sensory warning")
                self.lastNotificationTime = Date()
            }
        }
    }
}

// MARK: - CLLocationManagerDelegate

extension SmartNotificationService: CLLocationManagerDelegate {
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let currentLocation = locations.last else { return }
        
        // Check for sensory warnings at new location
        checkForSensoryWarnings(at: currentLocation)
    }
    
    func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
        switch status {
        case .authorizedWhenInUse, .authorizedAlways:
            startLocationMonitoring()
        case .denied, .restricted:
            stopLocationMonitoring()
            print("Location access denied - smart notifications disabled")
        case .notDetermined:
            requestLocationPermission()
        @unknown default:
            break
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("Location manager error: \(error.localizedDescription)")
    }
}