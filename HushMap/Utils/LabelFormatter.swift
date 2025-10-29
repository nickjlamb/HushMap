import Foundation

// MARK: - Label Formatter

struct LabelFormatter {
    
    // MARK: - Two-Line Formatting
    
    /// Formats labels for two-line display with UTF-safe truncation
    /// - Parameters:
    ///   - primary: Primary label text
    ///   - secondary: Optional secondary text
    ///   - maxPrimary: Maximum characters for primary line (default 40)
    ///   - maxSecondary: Maximum characters for secondary line (default 40)
    /// - Returns: Tuple of formatted strings
    static func shortTwoLine(
        primary: String,
        secondary: String?,
        maxPrimary: Int = 40,
        maxSecondary: Int = 40
    ) -> (String, String?) {
        let formattedPrimary = truncateWordBoundary(primary, maxLength: maxPrimary)
        let formattedSecondary = secondary.map { 
            truncateWordBoundary($0, maxLength: maxSecondary) 
        }
        
        return (formattedPrimary, formattedSecondary)
    }
    
    // MARK: - Compact Formatting
    
    /// Creates compact version of a label by removing separators but preserving meaning
    /// - Parameters:
    ///   - label: Input label to compact
    ///   - max: Maximum length (default 18)
    /// - Returns: Compacted label
    static func compact(_ label: String, max: Int = 18) -> String {
        var compacted = label
        
        // Remove common separators while preserving meaning
        compacted = compacted.replacingOccurrences(of: " – ", with: " ")
        compacted = compacted.replacingOccurrences(of: " - ", with: " ")
        compacted = compacted.replacingOccurrences(of: ", ", with: " ")
        
        // Remove "area" suffix for compact display
        if compacted.hasSuffix(" area") {
            compacted = String(compacted.dropLast(5))
        }
        
        // Truncate if still too long
        return truncateWordBoundary(compacted, maxLength: max)
    }
    
    // MARK: - Private Helpers
    
    /// Truncates string at word boundaries with UTF-safe grapheme cluster handling
    /// Preserves important suffixes like " area"
    private static func truncateWordBoundary(_ text: String, maxLength: Int) -> String {
        guard text.count > maxLength else { return text }
        
        // Check if we need to preserve " area" suffix
        let hasAreaSuffix = text.hasSuffix(" area")
        let areaSuffixLength = hasAreaSuffix ? 5 : 0
        let availableLength = maxLength - (hasAreaSuffix ? areaSuffixLength : 0) - 1 // -1 for ellipsis
        
        guard availableLength > 0 else {
            // If no room for content, just return ellipsis + suffix
            return hasAreaSuffix ? "… area" : "…"
        }
        
        // Find word boundary within available length
        let truncatePoint = findWordBoundary(in: text, maxLength: availableLength)
        let truncated = String(text.prefix(truncatePoint))
        
        // Add ellipsis and suffix
        if hasAreaSuffix {
            return truncated + "… area"
        } else {
            return truncated + "…"
        }
    }
    
    /// Finds safe word boundary for truncation using grapheme clusters
    /// Handles RTL text and emoji correctly
    private static func findWordBoundary(in text: String, maxLength: Int) -> Int {
        var currentLength = 0
        var lastWordBoundary = 0
        
        // Iterate through grapheme clusters (handles emoji, combining characters, etc.)
        var graphemeIndex = text.startIndex
        
        while graphemeIndex < text.endIndex && currentLength < maxLength {
            let nextIndex = text.index(after: graphemeIndex)
            let grapheme = String(text[graphemeIndex..<nextIndex])
            
            // Check if this grapheme would exceed our limit
            if currentLength + 1 > maxLength {
                break
            }
            
            // Update word boundary at whitespace or punctuation  
            if let scalar = grapheme.unicodeScalars.first {
                if scalar.properties.isWhitespace || 
                   CharacterSet.punctuationCharacters.contains(scalar) {
                    lastWordBoundary = text.distance(from: text.startIndex, to: nextIndex)
                }
            }
            
            graphemeIndex = nextIndex
            currentLength += 1
        }
        
        // Use word boundary if we found one, otherwise use character boundary
        return lastWordBoundary > 0 ? lastWordBoundary : currentLength
    }
}

// MARK: - Extensions

extension String {
    /// Returns the number of grapheme clusters in the string (emoji-safe)
    var graphemeCount: Int {
        return self.unicodeScalars.count
    }
    
    /// Safe substring that respects grapheme cluster boundaries
    func safePrefix(_ maxLength: Int) -> String {
        if self.count <= maxLength {
            return self
        }
        
        var result = ""
        var count = 0
        
        for graphemeCluster in self {
            if count >= maxLength {
                break
            }
            result.append(graphemeCluster)
            count += 1
        }
        
        return result
    }
}