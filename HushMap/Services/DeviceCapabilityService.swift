import UIKit
import Foundation
import Darwin

// MARK: - Device Performance Tiers
enum DevicePerformanceTier: String, CaseIterable {
    case high = "High"
    case medium = "Medium"
    case low = "Low"
    
    var description: String {
        switch self {
        case .high:
            return "Modern device with excellent performance"
        case .medium:
            return "Capable device with good performance"
        case .low:
            return "Older device requiring optimizations"
        }
    }
}

// MARK: - Map Performance Settings
struct MapPerformanceSettings {
    let maxPinsBeforeClustering: Int
    let animationDuration: Double
    let shadowsEnabled: Bool
    let buildingsEnabled: Bool
    let trafficEnabled: Bool
    let markerOptimization: MarkerOptimizationLevel
    let cameraTransitionDuration: Double
    let updateThrottling: TimeInterval
    
    enum MarkerOptimizationLevel {
        case none       // Full custom views with animations
        case moderate   // Simplified views, reduced animations
        case aggressive // Basic markers, no animations
    }
}

// MARK: - Device Capability Service
class DeviceCapabilityService: ObservableObject {
    static let shared = DeviceCapabilityService()
    
    @Published private(set) var performanceTier: DevicePerformanceTier
    @Published private(set) var mapSettings: MapPerformanceSettings
    @Published private(set) var availableMemoryMB: Double
    @Published private(set) var deviceModel: String
    
    private init() {
        self.deviceModel = Self.getDeviceModel()
        self.performanceTier = Self.detectPerformanceTier()
        self.mapSettings = Self.getMapSettings(for: Self.detectPerformanceTier())
        self.availableMemoryMB = Self.getAvailableMemoryMB()
        
        // Start memory monitoring
        startMemoryMonitoring()
        
        print("📱 Device: \(deviceModel)")
        print("⚡ Performance Tier: \(performanceTier.rawValue)")
        print("💾 Available Memory: \(String(format: "%.0f", availableMemoryMB))MB")
    }
    
    // MARK: - Device Detection
    
    private static func getDeviceModel() -> String {
        var systemInfo = utsname()
        uname(&systemInfo)
        let machineMirror = Mirror(reflecting: systemInfo.machine)
        let identifier = machineMirror.children.reduce("") { identifier, element in
            guard let value = element.value as? Int8, value != 0 else { return identifier }
            let unicodeScalar = UnicodeScalar(UInt8(value))
            return identifier + String(unicodeScalar)
        }
        
        // Map common identifiers to readable names
        switch identifier {
        // iPhone Models (Performance Tier: High)
        case "iPhone15,2", "iPhone15,3", "iPhone15,4", "iPhone15,5": return "iPhone 15"
        case "iPhone14,7", "iPhone14,8": return "iPhone 14"
        case "iPhone14,2", "iPhone14,3", "iPhone14,4", "iPhone14,5": return "iPhone 13"
        case "iPhone13,1", "iPhone13,2", "iPhone13,3", "iPhone13,4": return "iPhone 12"
        case "iPhone12,1", "iPhone12,3", "iPhone12,5": return "iPhone 11"
        
        // iPhone Models (Performance Tier: Medium)
        case "iPhone11,2", "iPhone11,4", "iPhone11,6", "iPhone11,8": return "iPhone XS/XR"
        case "iPhone10,1", "iPhone10,2", "iPhone10,3", "iPhone10,4", "iPhone10,5", "iPhone10,6": return "iPhone X/8"
        case "iPhone9,1", "iPhone9,2", "iPhone9,3", "iPhone9,4": return "iPhone 7"
        case "iPhone8,1", "iPhone8,2", "iPhone8,4": return "iPhone 6s"
        
        // iPhone Models (Performance Tier: Low)
        case "iPhone7,1", "iPhone7,2": return "iPhone 6"
        case "iPhone6,1", "iPhone6,2": return "iPhone 5s"
        case "iPhone5,1", "iPhone5,2", "iPhone5,3", "iPhone5,4": return "iPhone 5"
        
        // iPad Models (Generally High Performance)
        case let identifier where identifier.hasPrefix("iPad"):
            // Most iPads have good performance, classify as high by default
            return "iPad (\(identifier))"
        
        // Simulator
        case "x86_64", "arm64":
            if ProcessInfo.processInfo.environment["SIMULATOR_MODEL_IDENTIFIER"] != nil {
                return "Simulator"
            }
            return identifier
        
        default:
            return identifier
        }
    }
    
    private static func detectPerformanceTier() -> DevicePerformanceTier {
        let deviceModel = getDeviceModel()
        let processorCount = ProcessInfo.processInfo.processorCount
        let physicalMemory = ProcessInfo.processInfo.physicalMemory
        let memoryGB = Double(physicalMemory) / (1024 * 1024 * 1024)
        
        // Check for simulator (always high performance)
        if deviceModel.contains("Simulator") {
            return .high
        }
        
        // High-performance devices
        if deviceModel.contains("iPhone 15") ||
           deviceModel.contains("iPhone 14") ||
           deviceModel.contains("iPhone 13") ||
           deviceModel.contains("iPhone 12") ||
           deviceModel.contains("iPad") ||
           (processorCount >= 6 && memoryGB >= 4) {
            return .high
        }
        
        // Medium-performance devices
        if deviceModel.contains("iPhone 11") ||
           deviceModel.contains("iPhone XS") ||
           deviceModel.contains("iPhone XR") ||
           deviceModel.contains("iPhone X") ||
           deviceModel.contains("iPhone 8") ||
           deviceModel.contains("iPhone 7") ||
           (processorCount >= 4 && memoryGB >= 2) {
            return .medium
        }
        
        // Low-performance devices (older iPhones)
        return .low
    }
    
    private static func getAvailableMemoryMB() -> Double {
        // Simplified memory check for compatibility
        let physicalMemory = ProcessInfo.processInfo.physicalMemory
        let physicalMemoryMB = Double(physicalMemory) / (1024 * 1024)
        
        // Estimate available memory as a percentage of physical memory
        // This is a simplified approach that avoids mach kernel calls
        return physicalMemoryMB * 0.6 // Assume ~60% is typically available
    }
    
    // MARK: - Performance Settings
    
    private static func getMapSettings(for tier: DevicePerformanceTier) -> MapPerformanceSettings {
        switch tier {
        case .high:
            return MapPerformanceSettings(
                maxPinsBeforeClustering: 200,
                animationDuration: 0.3,
                shadowsEnabled: true,
                buildingsEnabled: true,
                trafficEnabled: true,
                markerOptimization: .none,
                cameraTransitionDuration: 0.5,
                updateThrottling: 0.1
            )
            
        case .medium:
            return MapPerformanceSettings(
                maxPinsBeforeClustering: 100,
                animationDuration: 0.2,
                shadowsEnabled: true,
                buildingsEnabled: true,
                trafficEnabled: false,
                markerOptimization: .moderate,
                cameraTransitionDuration: 0.3,
                updateThrottling: 0.2
            )
            
        case .low:
            return MapPerformanceSettings(
                maxPinsBeforeClustering: 50,
                animationDuration: 0.1,
                shadowsEnabled: false,
                buildingsEnabled: false,
                trafficEnabled: false,
                markerOptimization: .aggressive,
                cameraTransitionDuration: 0.2,
                updateThrottling: 0.5
            )
        }
    }
    
    // MARK: - Memory Monitoring
    
    private func startMemoryMonitoring() {
        // Simplified monitoring - update less frequently for better performance
        Timer.scheduledTimer(withTimeInterval: 30.0, repeats: true) { [weak self] _ in
            DispatchQueue.global(qos: .utility).async {
                let newMemory = Self.getAvailableMemoryMB()
                DispatchQueue.main.async {
                    self?.availableMemoryMB = newMemory
                    self?.adjustSettingsForMemoryPressure()
                }
            }
        }
    }
    
    private func adjustSettingsForMemoryPressure() {
        // If available memory drops below threshold, temporarily reduce settings
        let lowMemoryThreshold: Double = 200 // MB
        
        if availableMemoryMB < lowMemoryThreshold {
            print("⚠️ Low memory detected (\(String(format: "%.0f", availableMemoryMB))MB), adjusting settings")
            
            // Temporarily reduce performance settings
            let adjustedSettings = MapPerformanceSettings(
                maxPinsBeforeClustering: max(25, mapSettings.maxPinsBeforeClustering / 2),
                animationDuration: 0.1,
                shadowsEnabled: false,
                buildingsEnabled: false,
                trafficEnabled: false,
                markerOptimization: .aggressive,
                cameraTransitionDuration: 0.1,
                updateThrottling: 1.0
            )
            
            self.mapSettings = adjustedSettings
        } else if availableMemoryMB > lowMemoryThreshold * 2 {
            // Restore original settings when memory recovers
            self.mapSettings = Self.getMapSettings(for: performanceTier)
        }
    }
    
    // MARK: - Public Interface
    
    func shouldUseClustering(for pinCount: Int) -> Bool {
        return pinCount > mapSettings.maxPinsBeforeClustering
    }
    
    func getOptimalAnimationDuration() -> Double {
        return mapSettings.animationDuration
    }
    
    func shouldEnableShadows() -> Bool {
        return mapSettings.shadowsEnabled
    }
    
    func shouldEnableBuildings() -> Bool {
        return mapSettings.buildingsEnabled
    }
    
    func getMarkerOptimizationLevel() -> MapPerformanceSettings.MarkerOptimizationLevel {
        return mapSettings.markerOptimization
    }
    
    func getCameraTransitionDuration() -> Double {
        return mapSettings.cameraTransitionDuration
    }
    
    func getUpdateThrottling() -> TimeInterval {
        return mapSettings.updateThrottling
    }
    
    // MARK: - Debug Information
    
    func getPerformanceInfo() -> String {
        return """
        Device: \(deviceModel)
        Performance Tier: \(performanceTier.rawValue)
        Available Memory: \(String(format: "%.0f", availableMemoryMB))MB
        Max Pins Before Clustering: \(mapSettings.maxPinsBeforeClustering)
        Shadows Enabled: \(mapSettings.shadowsEnabled)
        Buildings Enabled: \(mapSettings.buildingsEnabled)
        Marker Optimization: \(mapSettings.markerOptimization)
        """
    }
}