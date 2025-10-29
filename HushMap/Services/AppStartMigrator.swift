import Foundation
import CoreLocation

/*
 AppStartMigrator.swift
 
 Background Backfill Migration System for Location Labels
 
 VERSIONING POLICY:
 • Location rules version is incremented in DefaultGeocodingService.LOCATION_RULES_VERSION
 • When version changes, all existing reports with older versions are re-resolved
 • Version changes trigger automatic backfill on next app launch
 • New fields (displayName, displayTier, confidence) are also backfilled if missing
 
 BACKFILL CADENCE:
 • Runs automatically on app start if unresolved reports exist
 • Processes up to 4 batches per launch (200 reports max) to avoid blocking
 • Uses background priority task to prevent UI interference
 • Rate-limited resolution prevents API quota exhaustion
 • Subsequent launches continue where previous left off
 
 KILL-SWITCH BEHAVIOR:
 • PrivacyLocationConfig.shared.areaOnlyOverride forces all locations to .area tier
 • When enabled, backfill respects kill-switch and only generates area labels
 • Migration system is idempotent - safe to run with kill-switch on/off
 • Kill-switch affects new resolutions, existing cached labels remain unchanged
 
 HEDGE THRESHOLD TUNING:
 • PrivacyLocationConfig.shared.confidenceHedgeThreshold controls "near {POI}" display
 • Default: 0.80 (POI confidence < 0.80 shows as "near Cafe" instead of "Cafe")
 • Recommended range: 0.60-0.90 depending on privacy sensitivity
 • Lower values = more hedged copy, higher values = more direct labels
 • Changes apply immediately to Report.friendlyDisplayName computed property
 */

// MARK: - Migration Logger

struct MigrationLogger {
    enum Event {
        case noWork
        case batchStart(count: Int)
        case batchSuccess(count: Int)  
        case batchError(Error)
    }
    
    func log(_ event: Event) {
        #if DEBUG
        switch event {
        case .noWork:
            print("🔄 [Migration] No unresolved reports found")
        case .batchStart(let count):
            print("🔄 [Migration] Starting batch: \(count) reports")
        case .batchSuccess(let count):
            print("✅ [Migration] Batch completed: \(count) reports resolved")
        case .batchError(let error):
            print("❌ [Migration] Batch failed: \(error)")
        }
        #endif
    }
}

// MARK: - App Start Migrator

@MainActor
final class AppStartMigrator {
    
    private let resolver: ReportLocationResolver
    private let store: ReportStore
    private let cacheStore: LocationLabelCacheStore
    private let batchSize: Int
    private let maxBatchesPerLaunch: Int
    private let logger: MigrationLogger
    
    init(
        resolver: ReportLocationResolver,
        store: ReportStore,
        cacheStore: LocationLabelCacheStore,
        batchSize: Int = 50,
        maxBatchesPerLaunch: Int = 4,
        logger: MigrationLogger = MigrationLogger()
    ) {
        self.resolver = resolver
        self.store = store
        self.cacheStore = cacheStore
        self.batchSize = batchSize
        self.maxBatchesPerLaunch = maxBatchesPerLaunch
        self.logger = logger
    }
    
    func runIfNeeded() {
        Task.detached(priority: .background) { @MainActor [resolver, store, cacheStore, batchSize, maxBatchesPerLaunch, logger] in
            // First, purge synthetic placeholders from cache
            do {
                try cacheStore.purge { label in
                    let syntheticPattern = "^(Area|Cell|Grid|Zone)\\s*\\d+$"
                    if let regex = try? NSRegularExpression(pattern: syntheticPattern, options: [.caseInsensitive]) {
                        let range = NSRange(location: 0, length: label.name.utf16.count)
                        return regex.firstMatch(in: label.name, options: [], range: range) != nil || label.name == Placeholders.nearbyArea
                    }
                    return label.name == Placeholders.nearbyArea
                }
            } catch {
                print("❌ Failed to purge synthetic cache entries: \(error)")
            }
            
            var processedBatches = 0
            
            while processedBatches < maxBatchesPerLaunch {
                do {
                    let unresolved = try await store.fetchUnresolvedReports(
                        limit: batchSize,
                        rulesVersion: DefaultGeocodingService.LOCATION_RULES_VERSION
                    )
                    
                    guard !unresolved.isEmpty else {
                        logger.log(.noWork)
                        break
                    }
                    
                    logger.log(.batchStart(count: unresolved.count))
                    
                    // Process each report through the resolver
                    for report in unresolved {
                        await resolver.resolveLocationForReport(report)
                    }
                    
                    // Save the batch (reports are already updated in-place by resolver)
                    try await store.save(unresolved)
                    logger.log(.batchSuccess(count: unresolved.count))
                    
                } catch {
                    logger.log(.batchError(error))
                    // Backoff to avoid hammering services
                    try? await Task.sleep(nanoseconds: 400_000_000) // 400ms
                }
                
                processedBatches += 1
            }
        }
    }
}