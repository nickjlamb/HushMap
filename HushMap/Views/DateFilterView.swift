import SwiftUI

extension DateFilterView {
    struct BackgroundModifier: ViewModifier {
        func body(content: Content) -> some View {
            content
                .padding()
                .background(Color.hushMapLines.opacity(0.8))
                .cornerRadius(12)
        }
    }
}

extension View {
    func hushMapBackground() -> some View {
        self.modifier(DateFilterView.BackgroundModifier())
    }
}