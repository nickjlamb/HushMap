import Foundation
import SwiftData

// MARK: - ReportStore Protocol

@MainActor
protocol ReportStore {
    /// Return reports missing display fields or with outdated locationResolutionVersion
    func fetchUnresolvedReports(limit: Int, rulesVersion: Int) async throws -> [Report]
    /// Persist updated reports (write-through to persistence layer)
    func save(_ reports: [Report]) async throws
}

// MARK: - SwiftData Implementation

@MainActor
class SwiftDataReportStore: ReportStore {
    
    private let modelContext: ModelContext
    
    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }
    
    func fetchUnresolvedReports(limit: Int, rulesVersion: Int) async throws -> [Report] {
        // Create predicate for unresolved reports:
        // 1. displayName is nil
        // 2. displayTier is nil  
        // 3. locationResolutionVersion is nil or < rulesVersion
        let predicate = #Predicate<Report> { report in
            report.displayName == nil ||
            report.displayTierRaw == nil ||
            (report.locationResolutionVersion ?? 0) < rulesVersion
        }
        
        var descriptor = FetchDescriptor<Report>(
            predicate: predicate,
            sortBy: [SortDescriptor(\.timestamp, order: .reverse)]
        )
        descriptor.fetchLimit = limit
        
        do {
            let reports = try modelContext.fetch(descriptor)
            print("📍 Found \(reports.count) unresolved reports (rulesVersion: \(rulesVersion))")
            return reports
        } catch {
            print("❌ Failed to fetch unresolved reports: \(error)")
            throw error
        }
    }
    
    func save(_ reports: [Report]) async throws {
        // Reports are already managed objects in SwiftData context,
        // so we just need to save the context
        do {
            try modelContext.save()
            print("💾 Saved \(reports.count) resolved reports to SwiftData")
        } catch {
            print("❌ Failed to save reports: \(error)")
            throw error
        }
    }
}