import SwiftUI

extension Color {
    // Brand colors - Soft, muted earth tones
    static let hushBackground = Color(hex: "8FA68E") // Sage green
    static let hushMapShape = Color(hex: "FAF6F0") // Warm cream/off-white
    static let hushMapLines = Color(hex: "E8DFD3") // Soft warm tan
    static let hushWaterRoad = Color(hex: "A8C4D4") // Gentle blue
    static let hushPinFace = Color(hex: "FFF9E6") // Soft warm yellow
    static let hushPinOuter = Color(hex: "D4B896") // Muted golden tan
    
    // Warm off-whites (instead of harsh white)
    static let hushOffWhite = Color(hex: "FAF8F5") // Warm off-white
    static let hushCream = Color(hex: "F5F0E8") // Creamy white
    static let hushSoftWhite = Color(hex: "FDFBF8") // Very soft white
    
    // High contrast text colors for excellent readability (WCAG AAA compliance)
    static let hushPrimaryText = Color(hex: "1A1A1A") // Almost black for primary text
    static let hushSecondaryText = Color(hex: "404040") // Dark gray for secondary text
    static let hushTertiaryText = Color(hex: "6B6B6B") // Medium gray for tertiary text
    
    // On dark backgrounds
    static let hushOnDarkText = Color(hex: "FEFEFE") // Very light text on dark backgrounds
    static let hushOnDarkSecondary = Color(hex: "E0E0E0") // Secondary text on dark
    
    // Risk level colors - calming versions
    static let hushLowRisk = Color(hex: "A8C4D4") // Gentle blue
    static let hushMediumRisk = Color(hex: "E8DFD3") // Soft warm tan
    static let hushHighRisk = Color(hex: "D4B896") // Muted golden tan
    
    // Helper initializer for hex colors
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (1, 1, 1, 0)
        }

        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue:  Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}