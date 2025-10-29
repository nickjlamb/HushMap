import SwiftUI

extension Font {
    // MARK: - Hush Map Typography Scale
    // Dynamic Type support - fonts scale with user's preferred text size
    // All fonts use rounded design for accessibility and friendliness

    // Display Sizes (for headers and titles)
    static let hushDisplay = Font.system(.largeTitle, design: .rounded).weight(.bold)
    static let hushLargeTitle = Font.system(.largeTitle, design: .rounded).weight(.bold)
    static let hushTitle = Font.system(.title, design: .rounded).weight(.semibold)
    static let hushTitle2 = Font.system(.title2, design: .rounded).weight(.semibold)
    static let hushTitle3 = Font.system(.title3, design: .rounded).weight(.medium)

    // Body Sizes - scale with Dynamic Type
    static let hushHeadline = Font.system(.headline, design: .rounded).weight(.semibold)
    static let hushSubheadline = Font.system(.subheadline, design: .rounded).weight(.medium)
    static let hushBody = Font.system(.body, design: .rounded).weight(.regular)
    static let hushBodyEmphasized = Font.system(.body, design: .rounded).weight(.medium)
    static let hushCallout = Font.system(.callout, design: .rounded).weight(.regular)

    // Smaller Sizes - still scale with Dynamic Type
    static let hushFootnote = Font.system(.footnote, design: .rounded).weight(.regular)
    static let hushCaption = Font.system(.caption, design: .rounded).weight(.regular)
    static let hushCaption2 = Font.system(.caption2, design: .rounded).weight(.regular)

    // Button Text
    static let hushButton = Font.system(.body, design: .rounded).weight(.semibold)
    static let hushButtonLarge = Font.system(.title3, design: .rounded).weight(.semibold)

    // Navigation and UI Elements
    static let hushNavTitle = Font.system(.headline, design: .rounded).weight(.semibold)
    static let hushTabLabel = Font.system(.footnote, design: .rounded).weight(.medium)
}

extension Text {
    // MARK: - Convenience Modifiers for Hush Map Typography
    
    func hushDisplay() -> some View {
        self.font(.hushDisplay)
    }
    
    func hushLargeTitle() -> some View {
        self.font(.hushLargeTitle)
    }
    
    func hushTitle() -> some View {
        self.font(.hushTitle)
    }
    
    func hushTitle2() -> some View {
        self.font(.hushTitle2)
    }
    
    func hushTitle3() -> some View {
        self.font(.hushTitle3)
    }
    
    func hushHeadline() -> some View {
        self.font(.hushHeadline)
    }
    
    func hushSubheadline() -> some View {
        self.font(.hushSubheadline)
    }
    
    func hushBody() -> some View {
        self.font(.hushBody)
    }
    
    func hushBodyEmphasized() -> some View {
        self.font(.hushBodyEmphasized)
    }
    
    func hushCallout() -> some View {
        self.font(.hushCallout)
    }
    
    func hushFootnote() -> some View {
        self.font(.hushFootnote)
    }
    
    func hushCaption() -> some View {
        self.font(.hushCaption)
    }
    
    func hushCaption2() -> some View {
        self.font(.hushCaption2)
    }
    
    func hushButton() -> some View {
        self.font(.hushButton)
    }
    
    func hushButtonLarge() -> some View {
        self.font(.hushButtonLarge)
    }
    
    func hushNavTitle() -> some View {
        self.font(.hushNavTitle)
    }
    
    func hushTabLabel() -> some View {
        self.font(.hushTabLabel)
    }
}

// MARK: - Typography Helpers for Excellent Contrast

extension Text {
    // Apply high contrast colors automatically
    func withHighContrast(on background: Color = .hushCream) -> some View {
        self.foregroundColor(.hushPrimaryText)
    }
    
    func withSecondaryContrast() -> some View {
        self.foregroundColor(.hushSecondaryText)
    }
    
    func withTertiaryContrast() -> some View {
        self.foregroundColor(.hushTertiaryText)
    }
}