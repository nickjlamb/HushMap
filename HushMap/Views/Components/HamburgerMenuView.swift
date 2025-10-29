import SwiftUI
import GoogleMaps

struct HamburgerMenuView: View {
    @Binding var isPresented: Bool
    @Binding var showLegend: Bool
    @Binding var showAbout: Bool
    @Binding var currentMapStyle: GMSMapViewType
    let onMapStyleSelected: (GMSMapViewType) -> Void
    let mapStyleIcon: String
    let mapStyleLabel: String
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.colorScheme) private var colorScheme
    
    // Control for high contrast mode
    @AppStorage("highContrastMode") private var highContrastMode = false
    
    // State for showing map style picker
    @State private var showMapStylePicker = false
    
    var backgroundColor: Color {
        if highContrastMode {
            return .hushOffWhite
        } else {
            return colorScheme == .dark ? Color(UIColor.systemBackground) : Color.hushCream
        }
    }
    
    var textColor: Color {
        if highContrastMode {
            return .black
        } else {
            return colorScheme == .dark ? Color.hushOffWhite : Color.black
        }
    }
    
    var cardBackgroundColor: Color {
        if highContrastMode {
            return .hushOffWhite
        } else {
            return colorScheme == .dark ? Color(UIColor.secondarySystemBackground) : Color.hushSoftWhite
        }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack {
                Text("Menu")
                    .hushTitle2()
                    .foregroundColor(textColor)
                    .accessibilityAddTraits(.isHeader)
                
                Spacer()
                
                Button(action: {
                    isPresented = false
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title2)
                        .symbolRenderingMode(.hierarchical)
                        .foregroundColor(.hushBackground)
                }
                .accessibilityLabel("Close menu")
            }
            .padding()
            .background(backgroundColor)
            
            Divider()
            
            // Menu items
            VStack(spacing: 0) {
                menuItem(
                    icon: "map.circle",
                    title: "Map Legend",
                    description: "View symbol meanings"
                ) {
                    showLegend = true
                    isPresented = false
                }
                
                Divider()
                    .padding(.leading, 60)
                
                menuItem(
                    icon: mapStyleIcon,
                    title: "Map Style",
                    description: mapStyleLabel
                ) {
                    showMapStylePicker = true
                }
                
                Divider()
                    .padding(.leading, 60)
                
                menuItem(
                    icon: "info.circle",
                    title: "About HushMap",
                    description: "App info & settings"
                ) {
                    showAbout = true
                    isPresented = false
                }
            }
            .background(backgroundColor)
            
            Spacer()
        }
        .background(backgroundColor)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.15), radius: 10, x: 0, y: 4)
        .environment(\.colorScheme, highContrastMode ? .light : colorScheme)
        .sheet(isPresented: $showMapStylePicker) {
            MapStylePickerView(
                currentMapStyle: $currentMapStyle,
                onMapStyleSelected: onMapStyleSelected,
                isPresented: $showMapStylePicker
            )
        }
    }
    
    @ViewBuilder
    private func menuItem(
        icon: String,
        title: String,
        description: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 16) {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundColor(.hushBackground)
                    .frame(width: 28, height: 28)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .hushHeadline()
                        .foregroundColor(textColor)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    
                    Text(description)
                        .hushFootnote()
                        .foregroundColor(textColor.opacity(0.7))
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding()
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(title), \(description)")
    }
}

#Preview {
    ZStack {
        Color.black.ignoresSafeArea()
        
        HamburgerMenuView(
            isPresented: .constant(true),
            showLegend: .constant(false),
            showAbout: .constant(false),
            currentMapStyle: .constant(.normal),
            onMapStyleSelected: { _ in },
            mapStyleIcon: "map",
            mapStyleLabel: "Standard"
        )
        .frame(width: 280, height: 240)
    }
}