import SwiftUI
import GoogleMaps

struct MapStylePickerView: View {
    @Binding var currentMapStyle: GMSMapViewType
    let onMapStyleSelected: (GMSMapViewType) -> Void
    @Binding var isPresented: Bool
    
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    
    let mapStyles: [(GMSMapViewType, String, String, String)] = [
        (.normal, "map", "Standard", "Default map view with roads and landmarks"),
        (.satellite, "globe.americas", "Satellite", "Aerial imagery view from above"),
        (.hybrid, "map.circle", "Hybrid", "Satellite view with road overlays"),
        (.terrain, "mountain.2", "Terrain", "Topographical features and elevation")
    ]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header section with proper spacing
            VStack(alignment: .leading, spacing: 8) {
                Text("Choose Map Style")
                    .font(StandardizedSheetDesign.titleFont)
                    .foregroundColor(StandardizedSheetDesign.primaryTextColor)
                
                Text("Select the map view that works best for you")
                    .font(StandardizedSheetDesign.subtitleFont)
                    .foregroundColor(StandardizedSheetDesign.secondaryTextColor)
            }
            .padding(.horizontal, StandardizedSheetDesign.contentPadding.leading)
            .padding(.top, StandardizedSheetDesign.contentPadding.top + 16)
            .padding(.bottom, 24)
                
            // Map style options with generous spacing
            ScrollView {
                VStack(spacing: 16) {
                    ForEach(mapStyles, id: \.0.rawValue) { style in
                        SheetCard {
                            MapStyleOptionView(
                                mapType: style.0,
                                icon: style.1,
                                title: style.2,
                                description: style.3,
                                isSelected: currentMapStyle == style.0,
                                backgroundColor: .clear,
                                textColor: StandardizedSheetDesign.primaryTextColor
                            ) {
                                selectMapStyle(style.0)
                            }
                        }
                        .padding(.horizontal, StandardizedSheetDesign.contentPadding.leading)
                    }
                }
                .padding(.bottom, StandardizedSheetDesign.contentPadding.bottom)
            }
        }
        .navigationTitle("Map Style")
        .standardizedSheet()
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }
    
    private func selectMapStyle(_ style: GMSMapViewType) {
        currentMapStyle = style
        onMapStyleSelected(style)
        
        // Provide haptic feedback
        let impactFeedback = UIImpactFeedbackGenerator(style: .light)
        impactFeedback.impactOccurred()
        
        // Dismiss after selection
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            isPresented = false
        }
    }
}

struct MapStyleOptionView: View {
    let mapType: GMSMapViewType
    let icon: String
    let title: String
    let description: String
    let isSelected: Bool
    let backgroundColor: Color
    let textColor: Color
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 16) {
                // Icon
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundColor(isSelected ? .hushOffWhite : .hushBackground)
                    .frame(width: 32, height: 32)
                    .background(
                        Circle()
                            .fill(isSelected ? Color.hushBackground : Color.clear)
                    )
                
                // Text content
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .hushHeadline()
                        .foregroundColor(textColor)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    
                    Text(description)
                        .hushFootnote()
                        .foregroundColor(textColor.opacity(0.7))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .fixedSize(horizontal: false, vertical: true)
                }
                
                // Selection indicator
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.title2)
                        .foregroundColor(.hushBackground)
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
            .frame(minHeight: 44)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(isSelected ? Color.hushSoftWhite : backgroundColor)
                    .stroke(isSelected ? Color.hushBackground : Color.clear, lineWidth: 2)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(title), \(description)")
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
    }
}

#Preview {
    MapStylePickerView(
        currentMapStyle: .constant(.normal),
        onMapStyleSelected: { _ in },
        isPresented: .constant(true)
    )
}