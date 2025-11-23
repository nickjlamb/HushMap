import SwiftUI
import GoogleMaps

/// Native iOS bottom sheet using .presentationDetents (iOS 16+)
struct NativeBottomSheetContent: View {
    @Binding var showAddReport: Bool
    @Binding var showNearby: Bool
    @Binding var showProfile: Bool
    @Binding var showLegend: Bool
    @Binding var showAbout: Bool
    @Binding var currentMapStyle: GMSMapViewType
    @Binding var detent: PresentationDetent
    let onMapStyleSelected: (GMSMapViewType) -> Void

    @Environment(\.colorScheme) private var colorScheme
    @AppStorage("highContrastMode") private var highContrastMode = false

    private var backgroundColor: Color {
        highContrastMode ? .hushOffWhite : (colorScheme == .dark ? Color(UIColor.systemBackground) : .hushCream)
    }

    private var isCollapsed: Bool {
        detent == .height(150)
    }

    var body: some View {
        VStack(spacing: 20) {
            // Drag indicator
            RoundedRectangle(cornerRadius: 3)
                .fill(Color.gray.opacity(0.6))
                .frame(width: 40, height: 5)
                .padding(.top, 12)
                .padding(.bottom, 8)

            // Primary action
            Button(action: {
                let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
                impactFeedback.impactOccurred()
                showAddReport = true
            }) {
                HStack(spacing: 10) {
                    Image(systemName: "plus.circle.fill")
                        .font(.title2)
                        .foregroundColor(.white)

                    Text("Log My Visit")
                        .hushButton()
                        .foregroundColor(.white)

                    Spacer()

                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.8))
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
                .background(highContrastMode ? Color.black : Color.hushBackground)
                .cornerRadius(12)
                .shadow(color: .black.opacity(0.1), radius: 3, x: 0, y: 2)
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 20)

            // Quick access buttons - only show when expanded
            if !isCollapsed {
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                quickButton(
                    title: "Profile",
                    icon: "person.circle.fill",
                    color: .hushBackground
                ) {
                    showProfile = true
                }

                quickButton(
                    title: "Find Nearby",
                    icon: "location.circle.fill",
                    color: .hushWaterRoad
                ) {
                    showNearby = true
                }

                quickButton(
                    title: "Legend",
                    icon: "list.bullet.rectangle.fill",
                    color: .gray
                ) {
                    showLegend = true
                }

                    quickButton(
                        title: "Map Style",
                        icon: "map",
                        color: .hushHighRisk
                    ) {
                        onMapStyleSelected(currentMapStyle)
                    }
                }
                .padding(.horizontal, 20)
            }

            Spacer()
        }
        .frame(maxWidth: .infinity)
        .background(backgroundColor)
    }

    private func quickButton(
        title: String,
        icon: String,
        color: Color,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: {
            let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
            impactFeedback.impactOccurred()
            action()
        }) {
            VStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundColor(color)

                Text(title)
                    .hushCaption()
                    .foregroundColor(.hushPrimaryText)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(Color.hushSoftWhite)
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(color.opacity(0.3), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}
