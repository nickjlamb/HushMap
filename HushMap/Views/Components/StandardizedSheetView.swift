import SwiftUI

// MARK: - Standardized Sheet Design System

/// Design system for consistent sheet styling across the app
struct StandardizedSheetDesign {
    // Typography
    static let titleFont: Font = .hushTitle2
    static let subtitleFont: Font = .hushSubheadline  
    static let bodyFont: Font = .hushBody
    static let captionFont: Font = .hushCaption
    
    // Colors
    static let primaryTextColor: Color = .hushPrimaryText
    static let secondaryTextColor: Color = .hushSecondaryText
    static let backgroundColor: Color = .hushCream
    static let cardBackground: Color = .hushSoftWhite
    static let accentColor: Color = .hushBackground
    
    // Spacing
    static let sectionSpacing: CGFloat = 24
    static let itemSpacing: CGFloat = 16
    static let cardPadding: CGFloat = 16
    static let contentPadding: EdgeInsets = .init(top: 0, leading: 20, bottom: 20, trailing: 20)
    
    // Corner radius
    static let cornerRadius: CGFloat = 12
    
    // Accessibility
    static func adaptiveSpacing(dynamicTypeSize: DynamicTypeSize) -> CGFloat {
        return dynamicTypeSize > .large ? sectionSpacing + 4 : sectionSpacing
    }
}

/// Base view modifier for standardized sheet styling
struct StandardizedSheetStyle: ViewModifier {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @AppStorage("highContrastMode") private var highContrastMode = false
    
    var backgroundColor: Color {
        highContrastMode ? .hushOffWhite : StandardizedSheetDesign.backgroundColor
    }
    
    func body(content: Content) -> some View {
        content
            .background(backgroundColor.ignoresSafeArea())
            .navigationBarTitleDisplayMode(.large)
    }
}

extension View {
    func standardizedSheet() -> some View {
        self.modifier(StandardizedSheetStyle())
    }
}

// MARK: - Standardized Components

/// Standardized section header for sheets
struct SheetSectionHeader: View {
    let title: String
    let subtitle: String?
    @AppStorage("highContrastMode") private var highContrastMode = false
    
    init(_ title: String, subtitle: String? = nil) {
        self.title = title
        self.subtitle = subtitle
    }
    
    var textColor: Color {
        highContrastMode ? .hushPrimaryText : StandardizedSheetDesign.primaryTextColor
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(StandardizedSheetDesign.titleFont)
                .foregroundColor(textColor)
                .accessibilityAddTraits(.isHeader)
            
            if let subtitle = subtitle {
                Text(subtitle)
                    .font(StandardizedSheetDesign.subtitleFont)
                    .foregroundColor(textColor.opacity(0.8))
            }
        }
    }
}

/// Standardized card view for sheet content
struct SheetCard<Content: View>: View {
    let content: Content
    @AppStorage("highContrastMode") private var highContrastMode = false
    
    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }
    
    var backgroundColor: Color {
        highContrastMode ? .hushOffWhite : StandardizedSheetDesign.cardBackground
    }
    
    var body: some View {
        content
            .padding(StandardizedSheetDesign.cardPadding)
            .background(backgroundColor)
            .cornerRadius(StandardizedSheetDesign.cornerRadius)
            .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
    }
}