import Foundation

// MARK: - Report Display Helpers

extension Report {
    
    /// Returns a compact display string suitable for small surfaces like watch complications
    /// Uses LabelFormatter.compact to create concise labels while preserving meaning
    /// 
    /// Examples:
    /// - "Tesco Express – Camden" → "Tesco Camden" 
    /// - "Oxford Street, London" → "Oxford St London"
    /// - "Camden area" → "Camden"
    var compactDisplay: String {
        guard let displayName = displayName else {
            return "Unknown"
        }
        
        return LabelFormatter.compact(displayName, max: 18)
    }
}

// MARK: - Global Helper Function

/// Returns compact display string for a report, useful for watch complications and tiny callouts
/// - Parameter report: The report to generate a compact display for
/// - Returns: A compact, meaningful string suitable for small UI surfaces
func compactDisplay(for report: Report) -> String {
    return report.compactDisplay
}