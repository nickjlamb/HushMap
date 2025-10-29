import Foundation
import CoreLocation
import os.signpost

// MARK: - Instruments Signposts

private let locationLabelingLog = OSLog(subsystem: "com.your.bundle.HushMap", category: "LocationLabeling")

// MARK: - Cache Data Models

struct LocationKey: Hashable, Codable {
    let qlat: Int32
    let qlon: Int32
    let localeID: String
    let rulesVersion: Int16
    
    init(coordinate: CLLocationCoordinate2D, locale: Locale, rulesVersion: Int16) {
        // Quantize to ~25m grid at mid-latitudes
        // Factor 4000 gives approximately 25m per unit at 45° latitude
        self.qlat = Int32(round(coordinate.latitude * 4000))
        self.qlon = Int32(round(coordinate.longitude * 4000))
        self.localeID = locale.identifier
        self.rulesVersion = rulesVersion
    }
    
    var base64URLKey: String {
        let encoder = JSONEncoder()
        guard let data = try? encoder.encode(self) else { return "invalid" }
        return data.base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }
}

class LocationLabel: Codable {
    let name: String
    let tier: DisplayTier
    let confidence: Double
    let updatedAt: Date
    let placeID: String?
    let expiresAt: Date?
    
    init(name: String, tier: DisplayTier, confidence: Double, updatedAt: Date, placeID: String? = nil, expiresAt: Date? = nil) {
        self.name = name
        self.tier = tier
        self.confidence = confidence
        self.updatedAt = updatedAt
        self.placeID = placeID
        self.expiresAt = expiresAt
    }
    
    // Check if this cached entry is still valid (not expired)
    var isValid: Bool {
        guard let expiresAt = expiresAt else {
            return true // No expiration set, assume valid
        }
        return Date() < expiresAt
    }
}

// MARK: - Cache Store Protocol

protocol LocationLabelCacheStore {
    func get(for key: LocationKey) -> LocationLabel?
    func set(_ value: LocationLabel, for key: LocationKey)
    func evict(olderThan: Date?)
    func purge(where predicate: (LocationLabel) -> Bool) throws
}

// MARK: - In-Memory Implementation (Fallback)

class InMemoryLocationLabelCacheStore: LocationLabelCacheStore {
    private var cache: [LocationKey: LocationLabel] = [:]
    private let maxEntries: Int
    
    init(maxEntries: Int = 1000) {
        self.maxEntries = maxEntries
    }
    
    func get(for key: LocationKey) -> LocationLabel? {
        return cache[key]
    }
    
    func set(_ value: LocationLabel, for key: LocationKey) {
        // Simple eviction: remove oldest entries if at capacity
        if cache.count >= maxEntries {
            let oldestKey = cache.keys.first
            if let key = oldestKey {
                cache.removeValue(forKey: key)
            }
        }
        cache[key] = value
    }
    
    func evict(olderThan cutoffDate: Date?) {
        if let cutoff = cutoffDate {
            cache = cache.filter { $0.value.updatedAt > cutoff }
        } else {
            cache.removeAll()
        }
    }
    
    func purge(where predicate: (LocationLabel) -> Bool) throws {
        cache = cache.filter { !predicate($0.value) }
    }
}

// MARK: - Disk Implementation

class DiskLocationLabelCacheStore: LocationLabelCacheStore {
    
    private let cacheDirectory: URL
    private let maxEntries: Int
    
    enum CacheError: Error {
        case unableToAccessCachesDirectory
        case unableToCreateCacheDirectory(Error)
    }
    
    init(maxEntries: Int = 5000, cacheDirectory: URL? = nil) throws {
        self.maxEntries = maxEntries
        
        if let customCacheDirectory = cacheDirectory {
            self.cacheDirectory = customCacheDirectory
        } else {
            guard let cachesDir = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first else {
                throw CacheError.unableToAccessCachesDirectory
            }
            self.cacheDirectory = cachesDir.appendingPathComponent("HushMapLocationLabels", isDirectory: true)
        }
        
        // Create cache directory if it doesn't exist
        try setupCacheDirectory()
        
        // Cleanup on init to maintain size limit (only for production cache)
        if cacheDirectory == nil {
            Task {
                await cleanupIfNeeded()
            }
        }
    }
    
    private func setupCacheDirectory() throws {
        do {
            try FileManager.default.createDirectory(
                at: cacheDirectory,
                withIntermediateDirectories: true,
                attributes: nil
            )
            
            // Exclude from iCloud backup
            var resourceValues = URLResourceValues()
            resourceValues.isExcludedFromBackup = true
            var mutableCacheDirectory = cacheDirectory
            try mutableCacheDirectory.setResourceValues(resourceValues)
            
        } catch {
            print("❌ Failed to setup cache directory: \(error)")
            throw CacheError.unableToCreateCacheDirectory(error)
        }
    }
    
    func get(for key: LocationKey) -> LocationLabel? {
        let signpostID = OSSignpostID(log: locationLabelingLog)
        os_signpost(.begin, log: locationLabelingLog, name: "Cache Lookup", signpostID: signpostID)
        
        let fileURL = cacheDirectory.appendingPathComponent("\(key.base64URLKey).json")
        
        do {
            let data = try Data(contentsOf: fileURL)
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            let result = try decoder.decode(LocationLabel.self, from: data)
            
            // Check if cached entry has expired
            if !result.isValid {
                // Delete expired entry
                try? FileManager.default.removeItem(at: fileURL)
                print("⏰ Deleted expired cache entry: \(fileURL.lastPathComponent)")
                os_signpost(.end, log: locationLabelingLog, name: "Cache Lookup", signpostID: signpostID, "Cache EXPIRED")
                return nil
            }
            
            os_signpost(.end, log: locationLabelingLog, name: "Cache Lookup", signpostID: signpostID, "Cache HIT")
            return result
        } catch {
            // If file exists but is corrupted (decode error), delete it
            if FileManager.default.fileExists(atPath: fileURL.path) {
                try? FileManager.default.removeItem(at: fileURL)
                print("🗑️ Deleted corrupted cache file: \(fileURL.lastPathComponent)")
            }
            os_signpost(.end, log: locationLabelingLog, name: "Cache Lookup", signpostID: signpostID, "Cache MISS")
            return nil
        }
    }
    
    func set(_ value: LocationLabel, for key: LocationKey) {
        let fileURL = cacheDirectory.appendingPathComponent("\(key.base64URLKey).json")
        
        do {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            let data = try encoder.encode(value)
            try data.write(to: fileURL)
        } catch {
            print("❌ Failed to write cache entry: \(error)")
        }
    }
    
    func evict(olderThan cutoffDate: Date?) {
        guard let cutoff = cutoffDate else {
            // If no date provided, evict all
            try? FileManager.default.removeItem(at: cacheDirectory)
            try? setupCacheDirectory()
            return
        }
        
        do {
            let fileURLs = try FileManager.default.contentsOfDirectory(
                at: cacheDirectory,
                includingPropertiesForKeys: [.contentModificationDateKey],
                options: .skipsHiddenFiles
            )
            
            for fileURL in fileURLs {
                if let modDate = try? fileURL.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate,
                   modDate < cutoff {
                    try? FileManager.default.removeItem(at: fileURL)
                }
            }
        } catch {
            print("❌ Failed to evict old cache entries: \(error)")
        }
    }
    
    func purge(where predicate: (LocationLabel) -> Bool) throws {
        let fileURLs = try FileManager.default.contentsOfDirectory(
            at: cacheDirectory,
            includingPropertiesForKeys: nil,
            options: .skipsHiddenFiles
        )
        
        var purgedCount = 0
        
        for fileURL in fileURLs {
            do {
                let data = try Data(contentsOf: fileURL)
                let decoder = JSONDecoder()
                decoder.dateDecodingStrategy = .iso8601
                let locationLabel = try decoder.decode(LocationLabel.self, from: data)
                
                if predicate(locationLabel) {
                    try FileManager.default.removeItem(at: fileURL)
                    purgedCount += 1
                }
            } catch {
                // If we can't decode, it's corrupted anyway - remove it
                try? FileManager.default.removeItem(at: fileURL)
            }
        }
        
        if purgedCount > 0 {
            print("🗑️ Purged \(purgedCount) cache entries matching criteria")
        }
    }
    
    private func cleanupIfNeeded() async {
        do {
            let fileURLs = try FileManager.default.contentsOfDirectory(
                at: cacheDirectory,
                includingPropertiesForKeys: [.contentModificationDateKey],
                options: .skipsHiddenFiles
            )
            
            if fileURLs.count > maxEntries {
                // Sort by modification date (oldest first)
                let sortedURLs = fileURLs.compactMap { url -> (URL, Date)? in
                    guard let modDate = try? url.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate else {
                        return nil
                    }
                    return (url, modDate)
                }.sorted { (first: (URL, Date), second: (URL, Date)) -> Bool in
                    return first.1 < second.1
                }
                
                // Remove oldest entries to get under limit
                let toRemove = sortedURLs.prefix(fileURLs.count - maxEntries + 500) // Remove extra for headroom
                for (url, _) in toRemove {
                    try? FileManager.default.removeItem(at: url)
                }
                
                print("🧹 Cleaned up \(toRemove.count) old cache entries")
            }
        } catch {
            print("❌ Failed to cleanup cache: \(error)")
        }
    }
}