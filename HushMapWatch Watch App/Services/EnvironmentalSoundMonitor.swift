import Foundation
import HealthKit
import Combine

class EnvironmentalSoundMonitor: ObservableObject {
    static let shared = EnvironmentalSoundMonitor()

    private let healthStore = HKHealthStore()
    @Published var currentSoundLevel: Double? = nil // in decibels
    @Published var lastMeasurementDate: Date? = nil
    @Published var isMonitoring: Bool = false
    @Published var hasPermission: Bool = false

    // Sound level thresholds (in dBA)
    private let quietThreshold: Double = 50.0  // Below this is quiet
    private let moderateThreshold: Double = 70.0  // 50-70 is moderate
    private let loudThreshold: Double = 85.0  // Above 85 is loud (OSHA limit)

    private var query: HKAnchoredObjectQuery?

    private init() {
        checkAuthorizationStatus()
    }

    // MARK: - Permission Handling

    func requestPermission(completion: @escaping (Bool) -> Void) {
        guard HKHealthStore.isHealthDataAvailable() else {
            #if DEBUG
            print("HealthKit not available on this device")
            #endif
            completion(false)
            return
        }

        guard let environmentalAudioExposureType = HKObjectType.quantityType(forIdentifier: .environmentalAudioExposure) else {
            #if DEBUG
            print("Environmental audio exposure type not available")
            #endif
            completion(false)
            return
        }

        let typesToRead: Set<HKObjectType> = [environmentalAudioExposureType]

        healthStore.requestAuthorization(toShare: nil, read: typesToRead) { [weak self] success, error in
            DispatchQueue.main.async {
                if let error = error {
                    #if DEBUG
                    print("HealthKit authorization error: \(error.localizedDescription)")
                    #endif
                    self?.hasPermission = false
                    completion(false)
                } else {
                    #if DEBUG
                    print("HealthKit authorization: \(success ? "granted" : "denied")")
                    #endif
                    self?.hasPermission = success
                    completion(success)
                }
            }
        }
    }

    private func checkAuthorizationStatus() {
        guard let environmentalAudioExposureType = HKObjectType.quantityType(forIdentifier: .environmentalAudioExposure) else {
            return
        }

        let status = healthStore.authorizationStatus(for: environmentalAudioExposureType)
        hasPermission = (status == .sharingAuthorized)
    }

    // MARK: - Monitoring

    func startMonitoring() {
        guard hasPermission else {
            #if DEBUG
            print("No HealthKit permission, requesting...")
            #endif
            requestPermission { [weak self] granted in
                if granted {
                    self?.startMonitoring()
                }
            }
            return
        }

        guard let environmentalAudioExposureType = HKObjectType.quantityType(forIdentifier: .environmentalAudioExposure) else {
            #if DEBUG
            print("Environmental audio exposure type not available")
            #endif
            return
        }

        // Stop existing query if any
        stopMonitoring()

        // Create anchored object query to get updates
        let query = HKAnchoredObjectQuery(
            type: environmentalAudioExposureType,
            predicate: nil,
            anchor: nil,
            limit: HKObjectQueryNoLimit
        ) { [weak self] query, samples, deletedObjects, anchor, error in
            self?.processSoundSamples(samples)
        }

        // Set update handler for new samples
        query.updateHandler = { [weak self] query, samples, deletedObjects, anchor, error in
            self?.processSoundSamples(samples)
        }

        self.query = query
        healthStore.execute(query)

        DispatchQueue.main.async {
            self.isMonitoring = true
        }

        #if DEBUG
        print("✅ Started environmental sound monitoring")
        #endif
    }

    func stopMonitoring() {
        if let query = query {
            healthStore.stop(query)
            self.query = nil
        }

        DispatchQueue.main.async {
            self.isMonitoring = false
        }

        #if DEBUG
        print("⏸️ Stopped environmental sound monitoring")
        #endif
    }

    private func processSoundSamples(_ samples: [HKSample]?) {
        guard let samples = samples as? [HKQuantitySample], !samples.isEmpty else { return }

        // Sort by date and get the most recent
        let sortedSamples = samples.sorted { $0.endDate > $1.endDate }
        guard let latestSample = sortedSamples.first else { return }

        // Check if this sample is recent (within last 5 minutes)
        let sampleAge = Date().timeIntervalSince(latestSample.endDate)

        // Convert to decibels
        let decibelUnit = HKUnit.decibelAWeightedSoundPressureLevel()
        let soundLevel = latestSample.quantity.doubleValue(for: decibelUnit)

        DispatchQueue.main.async {
            self.currentSoundLevel = soundLevel
            self.lastMeasurementDate = latestSample.endDate

            #if DEBUG
            let ageMinutes = Int(sampleAge / 60)
            if ageMinutes > 5 {
                print("⚠️ Sound level data is \(ageMinutes) minutes old: \(Int(soundLevel)) dBA")
            } else {
                print("🔊 Current sound level: \(Int(soundLevel)) dBA (measured \(ageMinutes)m ago)")
            }
            #endif
        }
    }

    // MARK: - Helper Methods

    func getSoundLevelCategory() -> SoundCategory {
        guard let level = currentSoundLevel else {
            return .unknown
        }

        switch level {
        case ..<quietThreshold:
            return .quiet
        case quietThreshold..<moderateThreshold:
            return .moderate
        case moderateThreshold..<loudThreshold:
            return .loud
        default:
            return .veryLoud
        }
    }

    func getSoundLevelColor() -> String {
        switch getSoundLevelCategory() {
        case .quiet:
            return "green"
        case .moderate:
            return "yellow"
        case .loud:
            return "orange"
        case .veryLoud:
            return "red"
        case .unknown:
            return "gray"
        }
    }

    func getSoundLevelEmoji() -> String {
        switch getSoundLevelCategory() {
        case .quiet:
            return "😌"
        case .moderate:
            return "🙂"
        case .loud:
            return "😕"
        case .veryLoud:
            return "😣"
        case .unknown:
            return "❓"
        }
    }

    func shouldAutoLog() -> Bool {
        guard let level = currentSoundLevel else { return false }

        // Auto-log if it's very quiet (< 40 dBA) or very loud (> 80 dBA)
        return level < 40.0 || level > 80.0
    }

    func isQuiet() -> Bool {
        guard let level = currentSoundLevel else { return false }
        return level < moderateThreshold
    }
}

// MARK: - Supporting Types

enum SoundCategory {
    case quiet      // < 50 dBA (library, bedroom)
    case moderate   // 50-70 dBA (normal conversation, office)
    case loud       // 70-85 dBA (busy street, alarm clock)
    case veryLoud   // > 85 dBA (lawn mower, concerts) - hearing damage risk
    case unknown

    var description: String {
        switch self {
        case .quiet:
            return "Quiet"
        case .moderate:
            return "Moderate"
        case .loud:
            return "Loud"
        case .veryLoud:
            return "Very Loud"
        case .unknown:
            return "Unknown"
        }
    }

    var healthDescription: String {
        switch self {
        case .quiet:
            return "Comfortable for extended periods"
        case .moderate:
            return "Safe for daily activities"
        case .loud:
            return "Limit exposure time"
        case .veryLoud:
            return "Hearing protection recommended"
        case .unknown:
            return "No data available"
        }
    }
}
