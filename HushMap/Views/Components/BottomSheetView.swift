import SwiftUI
import GoogleMaps

/// Bottom sheet component with three disclosure states for HushMap
struct BottomSheetView: View {
    // MARK: - Sheet States
    enum SheetState: CaseIterable {
        case peek    // 60pt height - handle + hint
        case half    // 50% screen - quick filters + recent
        case full    // 90% screen - all features

        func height(for screenHeight: CGFloat) -> CGFloat {
            switch self {
            case .peek: return 200
            case .half: return screenHeight * 0.5
            case .full: return screenHeight * 0.9
            }
        }

        var cornerRadius: CGFloat {
            switch self {
            case .peek: return 16
            case .half: return 20
            case .full: return 24
            }
        }
    }

    // MARK: - Modal Sheet Types
    enum ModalSheet: Identifiable {
        case profile
        case legend
        case about

        var id: Int {
            switch self {
            case .profile: return 1
            case .legend: return 2
            case .about: return 3
            }
        }
    }
    
    // MARK: - Properties
    @Binding var currentState: SheetState
    @State private var dragOffset: CGFloat = 0
    @State private var lastDragValue: CGFloat = 0
    @State private var activeModalSheet: ModalSheet?
    @State private var internalState: SheetState = .peek

    // Screen dimensions
    @Environment(\.safeAreaInsets) private var safeAreaInsets
    private let screenHeight = UIScreen.main.bounds.height

    // Accessibility & Theme
    @Environment(\.colorScheme) private var colorScheme
    @AppStorage("highContrastMode") private var highContrastMode = false

    // Existing app state (passed from parent)
    @Binding var showLegend: Bool
    @Binding var showAbout: Bool
    @Binding var showAddReport: Bool
    @Binding var showNearby: Bool
    @Binding var showProfile: Bool
    @Binding var shouldFocusSearch: Bool
    @Binding var currentMapStyle: GMSMapViewType
    let onMapStyleSelected: (GMSMapViewType) -> Void
    
    // Filter state
    @Binding var useClustering: Bool
    @Binding var sortByRecent: Bool
    @Binding var startDate: Date
    @Binding var endDate: Date
    @Binding var maxNoiseThreshold: Double
    @Binding var maxCrowdThreshold: Double
    @Binding var maxLightingThreshold: Double
    
    
    // Quick filter states (legacy - can be removed later)
    @State private var showOpenOnly = false
    @State private var showNearbyOnly = false
    
    // MARK: - Computed Properties
    private var backgroundColor: Color {
        highContrastMode ? .hushOffWhite : (colorScheme == .dark ? Color(UIColor.systemBackground) : .hushCream)
    }
    
    private var handleColor: Color {
        highContrastMode ? .hushSecondaryText : .hushTertiaryText
    }
    
    private var currentHeight: CGFloat {
        let height = internalState.height(for: screenHeight) + dragOffset
        print("📐 [BottomSheet] Computing height: \(height)pt for state: \(internalState)")
        return height
    }
    
    // MARK: - Body
    var body: some View {
        GeometryReader { geometry in
            VStack(spacing: 0) {
                // Drag handle
                dragHandle
                    .padding(.top, 8)
                
                // Content based on current state
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(spacing: 0) {
                        switch currentState {
                        case .peek:
                            peekContent
                                .onAppear {
                                    print("🟡 [BottomSheet] Peek content appeared. Current state: \(currentState)")
                                }
                        case .half:
                            halfContent
                        case .full:
                            fullContent
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, safeAreaInsets.bottom + 20)
                }
                .scrollDisabled(currentState == .peek)
            }
            .frame(height: currentHeight)
            .frame(maxWidth: .infinity)
            .background(backgroundColor)
            .cornerRadius(currentState.cornerRadius, corners: [.topLeft, .topRight])
            .shadow(color: .black.opacity(0.15), radius: 10, x: 0, y: -5)
            .offset(y: max(0, geometry.size.height - currentHeight))
            .onTapGesture {
                // Consume taps on the sheet to prevent them from bubbling to parent
                print("💚 [BottomSheet] Sheet tapped - consuming to prevent parent reset")
            }
            .animation(.spring(response: 0.6, dampingFraction: 0.8), value: internalState)
            .animation(.spring(response: 0.3, dampingFraction: 0.9), value: dragOffset)
            .sheet(item: $activeModalSheet) { sheet in
                switch sheet {
                case .profile:
                    NavigationView {
                        ProfileView()
                            .toolbar {
                                ToolbarItem(placement: .navigationBarTrailing) {
                                    Button("Done") {
                                        activeModalSheet = nil
                                    }
                                    .fontWeight(.medium)
                                }
                            }
                    }
                    .presentationDetents([.large])
                    .presentationDragIndicator(.visible)
                    .interactiveDismissDisabled(false)

                case .legend:
                    NavigationView {
                        MapLegendSheetView()
                            .navigationTitle("Map Legend")
                            .navigationBarTitleDisplayMode(.inline)
                            .toolbar {
                                ToolbarItem(placement: .navigationBarTrailing) {
                                    Button("Done") {
                                        activeModalSheet = nil
                                    }
                                }
                            }
                    }
                    .presentationDetents([.medium])

                case .about:
                    AboutView()
                }
            }
            .onChange(of: showProfile) { _, newValue in
                if newValue { activeModalSheet = .profile }
                else if activeModalSheet == .profile { activeModalSheet = nil }
            }
            .onChange(of: showLegend) { _, newValue in
                if newValue { activeModalSheet = .legend }
                else if activeModalSheet == .legend { activeModalSheet = nil }
            }
            .onChange(of: showAbout) { _, newValue in
                if newValue { activeModalSheet = .about }
                else if activeModalSheet == .about { activeModalSheet = nil }
            }
            .onChange(of: activeModalSheet) { _, newValue in
                showProfile = (newValue == .profile)
                showLegend = (newValue == .legend)
                showAbout = (newValue == .about)
            }
            .onChange(of: currentState) { oldValue, newValue in
                print("🔄 [BottomSheet] Binding state changed: \(oldValue) → \(newValue)")
                internalState = newValue
                print("   Old height: \(oldValue.height(for: screenHeight))pt")
                print("   New height: \(newValue.height(for: screenHeight))pt")
                print("   Screen height: \(screenHeight)pt")
            }
            .onAppear {
                internalState = currentState
                print("🟡 [BottomSheet] Initialized internal state to: \(internalState)")
            }
        }
    }
    
    // MARK: - Drag Handle
    private var dragHandle: some View {
        RoundedRectangle(cornerRadius: 3)
            .fill(handleColor)
            .frame(width: 40, height: 6)
            .padding(.vertical, 12)
            .contentShape(Rectangle())
            .gesture(dragGesture)
            .accessibilityLabel("Drag to expand or collapse")
            .accessibilityHint("Swipe up or down to change sheet size")
    }
    
    // MARK: - Content Views
    private var peekContent: some View {
        VStack(spacing: 16) {
            // Primary action - clean and focused
            Button(action: {
                print("🟣 [BottomSheet] Log My Visit button tapped!")
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
                .background(
                    highContrastMode ? Color.black : Color.hushBackground
                )
                .cornerRadius(12)
                .shadow(color: .black.opacity(0.1), radius: 3, x: 0, y: 2)
            }
            .buttonStyle(.plain)

            // Subtle hint to expand - clean design
            Button(action: {
                print("🔵 [BottomSheet] More options button tapped!")
                print("🔵 [BottomSheet] Changing state from \(currentState) to .half")
                currentState = .half
                internalState = .half
                print("🔵 [BottomSheet] State after change: \(currentState)")
                print("🔵 [BottomSheet] Internal state: \(internalState)")
            }) {
                HStack {
                    Text("More options")
                        .hushCaption()
                        .foregroundColor(
                            highContrastMode ? .black.opacity(0.8) : .hushTertiaryText
                        )

                    Spacer()

                    Image(systemName: "chevron.up")
                        .font(.caption2)
                        .foregroundColor(
                            highContrastMode ? .black.opacity(0.8) : .hushTertiaryText
                        )
                }
                .padding(.vertical, 8)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
    }
    
    private var halfContent: some View {
        VStack(spacing: 20) {
            // Semi-important functions - no duplication
            VStack(spacing: 16) {
                // Profile and Nearby row
                HStack(spacing: 12) {
                    // Profile access
                    Button(action: {
                        let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
                        impactFeedback.impactOccurred()
                        showProfile = true
                    }) {
                        VStack(spacing: 8) {
                            Image(systemName: "person.circle.fill")
                                .font(.title2)
                                .foregroundColor(.hushBackground)
                            
                            Text("Profile")
                                .hushCaption()
                                .foregroundColor(.hushPrimaryText)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(Color.hushSoftWhite)
                        .cornerRadius(12)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color.hushBackground.opacity(0.3), lineWidth: 1)
                        )
                    }
                    .buttonStyle(.plain)
                    
                    // Find Nearby places
                    Button(action: {
                        let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
                        impactFeedback.impactOccurred()
                        showNearby = true
                    }) {
                        VStack(spacing: 8) {
                            Image(systemName: "location.circle.fill")
                                .font(.title2)
                                .foregroundColor(.hushWaterRoad)
                            
                            Text("Find Nearby")
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
                                .stroke(Color.hushWaterRoad.opacity(0.3), lineWidth: 1)
                        )
                    }
                    .buttonStyle(.plain)
                }
                
                // Legend and Map Style row
                HStack(spacing: 12) {
                    // Legend/Guide
                    Button(action: {
                        let impactFeedback = UIImpactFeedbackGenerator(style: .light)
                        impactFeedback.impactOccurred()
                        showLegend = true
                    }) {
                        VStack(spacing: 8) {
                            Image(systemName: "list.bullet.rectangle.fill")
                                .font(.title2)
                                .foregroundColor(.gray)
                            
                            Text("Legend")
                                .hushCaption()
                                .foregroundColor(.hushPrimaryText)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(Color.hushSoftWhite)
                        .cornerRadius(12)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                        )
                    }
                    .buttonStyle(.plain)
                    
                    // Map Style picker
                    Button(action: {
                        let impactFeedback = UIImpactFeedbackGenerator(style: .light)
                        impactFeedback.impactOccurred()
                        onMapStyleSelected(currentMapStyle)
                    }) {
                        VStack(spacing: 8) {
                            Image(systemName: "map")
                                .font(.title2)
                                .foregroundColor(.hushHighRisk)
                            
                            Text("Map Style")
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
                                .stroke(Color.hushHighRisk.opacity(0.3), lineWidth: 1)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
            
            // Expand hint for full options
            Button(action: { 
                withAnimation(.easeInOut(duration: 0.3)) { 
                    currentState = .full 
                }
            }) {
                HStack {
                    Text("All options & filters")
                        .hushBody()
                    Spacer()
                    Image(systemName: "chevron.up")
                }
                .foregroundColor(.hushBackground)
                .padding(.vertical, 8)
            }
            .buttonStyle(.plain)
        }
        .padding(.vertical, 8)
    }
    
    private var fullContent: some View {
        VStack(spacing: 24) {
            // Quick access buttons
            quickAccessSection
            
            Divider().background(handleColor)
            
            // Complete filter system
            filterSection
            
            Divider().background(handleColor)
            
            // Map controls
            mapControlsSection
            
            Divider().background(handleColor)
            
            // Profile and settings
            profileSection
        }
    }
    
    // MARK: - Full Content Sections
    private var quickAccessSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Quick Access")
                .hushHeadline()
                .foregroundColor(.hushPrimaryText)
            
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: currentState == .full ? 1 : 2), spacing: 12) {
                actionButton(title: "Settings", icon: "gearshape.fill", color: .hushMapShape) {
                    let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
                    impactFeedback.impactOccurred()
                    showAbout = true
                }
                
                // Only show Filter Reports button when not in full state (filters are visible when expanded)
                if currentState != .full {
                    actionButton(title: "Filter Reports", icon: "line.3.horizontal.decrease.circle.fill", color: .hushWaterRoad) {
                        let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
                        impactFeedback.impactOccurred()
                        withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                            currentState = .full
                        }
                    }
                }
            }
        }
    }
    
    private var filterSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Filters")
                .hushHeadline()
                .foregroundColor(.hushPrimaryText)
            
            VStack(spacing: 16) {
                // Clustering and sorting
                VStack(spacing: 12) {
                    Toggle("Group pins by location", isOn: $useClustering)
                        .font(.hushBody)
                        .tint(.hushMapShape)
                    
                    Toggle("Sort by most recent", isOn: $sortByRecent)
                        .font(.hushBody)
                        .tint(.hushMapShape)
                }
                
                // Sensory level filters
                VStack(spacing: 16) {
                    Text("Maximum Comfort Levels")
                        .hushSubheadline()
                        .foregroundColor(.hushSecondaryText)
                    
                    VStack(spacing: 12) {
                        filterSlider(
                            title: "Noise Level",
                            value: $maxNoiseThreshold,
                            icon: "speaker.wave.2.fill"
                        )
                        
                        filterSlider(
                            title: "Crowd Level",
                            value: $maxCrowdThreshold,
                            icon: "person.2.fill"
                        )
                        
                        filterSlider(
                            title: "Lighting Level",
                            value: $maxLightingThreshold,
                            icon: "lightbulb.fill"
                        )
                    }
                }
                
                // Date filters
                VStack(alignment: .leading, spacing: 12) {
                    Text("Date Range")
                        .hushSubheadline()
                        .foregroundColor(.hushSecondaryText)
                    
                    HStack {
                        DatePicker("Start", selection: $startDate, displayedComponents: .date)
                            .font(.hushFootnote)
                        
                        Text("to")
                            .font(.hushFootnote)
                            .foregroundColor(.hushSecondaryText)
                        
                        DatePicker("End", selection: $endDate, displayedComponents: .date)
                            .font(.hushFootnote)
                    }
                }
                
                // Reset button
                Button("Reset All Filters") {
                    resetFilters()
                }
                .font(.hushButton)
                .foregroundColor(.hushMapShape)
                .frame(maxWidth: .infinity, alignment: .center)
            }
            .padding()
            .background(Color.hushSoftWhite)
            .cornerRadius(16)
        }
    }
    
    private var mapControlsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Map Controls")
                .hushHeadline()
                .foregroundColor(.hushPrimaryText)
            
            VStack(spacing: 12) {
                // Map style
                Button(action: { 
                    onMapStyleSelected(currentMapStyle)
                }) {
                    HStack {
                        Image(systemName: "map")
                            .foregroundColor(.hushBackground)
                            .frame(width: 24)
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Map Style")
                                .hushBody()
                                .foregroundColor(.hushPrimaryText)
                            
                            Text("Standard")
                                .font(.hushFootnote)
                                .foregroundColor(.hushSecondaryText)
                        }
                        
                        Spacer()
                        
                        Image(systemName: "chevron.right")
                            .foregroundColor(.hushTertiaryText)
                    }
                    .padding()
                    .background(Color.hushSoftWhite)
                    .cornerRadius(12)
                }
                .buttonStyle(.plain)
                
                // Legend
                Button(action: { showLegend = true }) {
                    HStack {
                        Image(systemName: "list.bullet.rectangle.fill")
                            .foregroundColor(.hushBackground)
                            .frame(width: 24)
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Map Legend")
                                .hushBody()
                                .foregroundColor(.hushPrimaryText)
                            
                            Text("View symbol meanings")
                                .font(.hushFootnote)
                                .foregroundColor(.hushSecondaryText)
                        }
                        
                        Spacer()
                        
                        Image(systemName: "chevron.right")
                            .foregroundColor(.hushTertiaryText)
                    }
                    .padding()
                    .background(Color.hushSoftWhite)
                    .cornerRadius(12)
                }
                .buttonStyle(.plain)
            }
        }
    }
    
    private var profileSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Additional Options")
                .hushHeadline()
                .foregroundColor(.hushPrimaryText)
            
            VStack(spacing: 12) {
                // About/Help
                Button(action: { showAbout = true }) {
                    profileRow(
                        title: "About & Help",
                        subtitle: "App info, accessibility, and support",
                        icon: "info.circle.fill"
                    )
                }
                .buttonStyle(.plain)
            }
        }
    }
    
    // MARK: - Helper Views
    
    private func actionButton(title: String, icon: String, color: Color, action: @escaping () -> Void) -> some View {
        Button(action: {
            let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
            impactFeedback.impactOccurred()
            action()
        }) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundColor(color)
                
                Text(title)
                    .hushBody()
                    .foregroundColor(.hushPrimaryText)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(height: 50)
            .padding(.horizontal, 16)
            .background(Color.hushSoftWhite)
            .cornerRadius(12)
        }
        .buttonStyle(.plain)
    }
    
    private func filterSlider(title: String, value: Binding<Double>, icon: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(.hushBackground)
                    .frame(width: 20)
                
                Text(title)
                    .hushBody()
                    .foregroundColor(.hushPrimaryText)
                
                Spacer()
                
                Text("\(Int(value.wrappedValue * 100))%")
                    .font(.hushFootnote)
                    .foregroundColor(.hushSecondaryText)
            }
            
            Slider(value: value, in: 0...1)
                .tint(.hushBackground)
        }
    }
    
    
    private func profileRow(title: String, subtitle: String, icon: String) -> some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(.hushBackground)
                .frame(width: 24)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .hushBody()
                    .foregroundColor(.hushPrimaryText)
                
                Text(subtitle)
                    .font(.hushFootnote)
                    .foregroundColor(.hushSecondaryText)
            }
            
            Spacer()
            
            Image(systemName: "chevron.right")
                .foregroundColor(.hushTertiaryText)
        }
        .padding()
        .background(Color.hushSoftWhite)
        .cornerRadius(12)
    }
    
    // MARK: - Drag Gesture
    private var dragGesture: some Gesture {
        DragGesture()
            .onChanged { value in
                print("🔴 [BottomSheet] Drag gesture detected: \(value.translation.height)")
                // Calculate drag offset (negative = dragging up, positive = dragging down)
                let translation = value.translation.height
                dragOffset = translation
                
                // Provide haptic feedback at state boundaries
                
                // Check for state transitions with haptic feedback
                if abs(translation - lastDragValue) > 50 {
                    let impactFeedback = UIImpactFeedbackGenerator(style: .light)
                    impactFeedback.impactOccurred()
                    lastDragValue = translation
                }
            }
            .onEnded { value in
                let translation = value.translation.height
                let velocity = value.velocity.height
                
                // Determine next state based on drag distance and velocity
                let dragThreshold: CGFloat = 100
                let velocityThreshold: CGFloat = 500
                
                withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                    if translation < -dragThreshold || velocity < -velocityThreshold {
                        // Dragged up or fast upward velocity
                        switch currentState {
                        case .peek: currentState = .half
                        case .half: currentState = .full
                        case .full: break // Already at top
                        }
                    } else if translation > dragThreshold || velocity > velocityThreshold {
                        // Dragged down or fast downward velocity  
                        switch currentState {
                        case .peek: break // Already at bottom
                        case .half: currentState = .peek
                        case .full: currentState = .half
                        }
                    }
                    
                    // Reset drag offset
                    dragOffset = 0
                    lastDragValue = 0
                }
                
                // Provide completion haptic feedback
                let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
                impactFeedback.impactOccurred()
            }
    }
    
    // MARK: - Helper Methods
    private func expandBottomSheet() {
        withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
            switch currentState {
            case .peek:
                currentState = .half
            case .half:
                currentState = .full
            case .full:
                // Already at full, cycle back to peek
                currentState = .peek
            }
        }
        
        // Provide haptic feedback
        let impactFeedback = UIImpactFeedbackGenerator(style: .light)
        impactFeedback.impactOccurred()
    }
    
    private func resetFilters() {
        maxNoiseThreshold = 1.0
        maxCrowdThreshold = 1.0
        maxLightingThreshold = 1.0
        startDate = DateComponents(calendar: Calendar.current, year: 2025, month: 1, day: 1).date ?? Date()
        endDate = Date()
        useClustering = true
        sortByRecent = false
        
        // Reset quick filters
        showOpenOnly = false
        showNearbyOnly = false
    }
}

// MARK: - Corner Radius Extension
extension View {
    func cornerRadius(_ radius: CGFloat, corners: UIRectCorner) -> some View {
        clipShape(RoundedCorner(radius: radius, corners: corners))
    }
}

struct RoundedCorner: Shape {
    var radius: CGFloat = .infinity
    var corners: UIRectCorner = .allCorners

    func path(in rect: CGRect) -> Path {
        let path = UIBezierPath(
            roundedRect: rect,
            byRoundingCorners: corners,
            cornerRadii: CGSize(width: radius, height: radius)
        )
        return Path(path.cgPath)
    }
}

// MARK: - Safe Area Extension
extension EnvironmentValues {
    var safeAreaInsets: EdgeInsets {
        EdgeInsets(UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first?.windows.first?.safeAreaInsets ?? .zero)
    }
}

extension EdgeInsets {
    init(_ uiInsets: UIEdgeInsets) {
        self.init(
            top: uiInsets.top,
            leading: uiInsets.left,
            bottom: uiInsets.bottom,
            trailing: uiInsets.right
        )
    }
}

// MARK: - Map Legend Sheet View
struct MapLegendSheetView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: StandardizedSheetDesign.sectionSpacing) {
                // Header
                Text("Map markers show comfort quality based on sensory reports from the community.")
                    .font(StandardizedSheetDesign.subtitleFont)
                    .foregroundColor(StandardizedSheetDesign.secondaryTextColor)
                    .fixedSize(horizontal: false, vertical: true)
                    
                // Quality levels
                VStack(spacing: StandardizedSheetDesign.itemSpacing) {
                    SheetCard {
                        LegendRowView(
                            color: Color(red: 0.2, green: 0.8, blue: 0.3),
                            title: "Excellent Quality",
                            description: "Very quiet, calm, and comfortable",
                            textColor: StandardizedSheetDesign.primaryTextColor,
                            cardBackgroundColor: .clear
                        )
                    }
                        
                    SheetCard {
                        LegendRowView(
                            color: Color(red: 0.4, green: 0.7, blue: 0.9),
                            title: "Good Quality",
                            description: "Generally quiet with minor distractions",
                            textColor: StandardizedSheetDesign.primaryTextColor,
                            cardBackgroundColor: .clear
                        )
                    }
                    
                    SheetCard {
                        LegendRowView(
                            color: Color(red: 1.0, green: 0.8, blue: 0.0),
                            title: "Moderate Quality",
                            description: "Some noise and activity present",
                            textColor: StandardizedSheetDesign.primaryTextColor,
                            cardBackgroundColor: .clear
                        )
                    }
                        
                    SheetCard {
                        LegendRowView(
                            color: Color(red: 1.0, green: 0.5, blue: 0.0),
                            title: "Poor Quality",
                            description: "Noisy, crowded, or overstimulating",
                            textColor: StandardizedSheetDesign.primaryTextColor,
                            cardBackgroundColor: .clear
                        )
                    }
                    
                    SheetCard {
                        LegendRowView(
                            color: Color(red: 0.9, green: 0.2, blue: 0.2),
                            title: "Very Poor Quality",
                            description: "Avoid if sensitive to sensory input",
                            textColor: StandardizedSheetDesign.primaryTextColor,
                            cardBackgroundColor: .clear
                        )
                    }
                    
                    SheetCard {
                        LegendRowView(
                            color: Color(UIColor.systemPurple),
                            title: "AI Prediction",
                            description: "Estimated comfort based on AI analysis",
                            textColor: StandardizedSheetDesign.primaryTextColor,
                            cardBackgroundColor: .clear
                        )
                    }
                }
                    
                // Additional info
                SheetSectionHeader("How It Works")
                
                SheetCard {
                    VStack(alignment: .leading, spacing: StandardizedSheetDesign.itemSpacing) {
                        HStack(alignment: .top) {
                            Image(systemName: "person.3.fill")
                                .foregroundColor(StandardizedSheetDesign.accentColor)
                                .frame(width: 20)
                            Text("Colors reflect the average sensory comfort from community reports")
                                .font(StandardizedSheetDesign.bodyFont)
                                .foregroundColor(StandardizedSheetDesign.primaryTextColor)
                        }
                        
                        HStack(alignment: .top) {
                            Image(systemName: "brain")
                                .foregroundColor(StandardizedSheetDesign.accentColor)
                                .frame(width: 20)
                            Text("Purple markers show AI predictions for places without reports")
                                .font(StandardizedSheetDesign.bodyFont)
                                .foregroundColor(StandardizedSheetDesign.primaryTextColor)
                        }
                        
                        HStack(alignment: .top) {
                            Image(systemName: "plus.circle")
                                .foregroundColor(StandardizedSheetDesign.accentColor)
                                .frame(width: 20)
                            Text("Contribute your own reports to help others find comfortable spaces")
                                .font(StandardizedSheetDesign.bodyFont)
                                .foregroundColor(StandardizedSheetDesign.primaryTextColor)
                        }
                    }
                }
            }
            .padding(StandardizedSheetDesign.contentPadding)
        }
        .standardizedSheet()
    }
}

// MARK: - Legend Row View
struct LegendRowView: View {
    let color: Color
    let title: String
    let description: String
    let textColor: Color
    let cardBackgroundColor: Color
    
    var body: some View {
        HStack(spacing: 12) {
            // Colored circle indicator
            Circle()
                .fill(color)
                .frame(width: 16, height: 16)
                .overlay(
                    Circle()
                        .stroke(Color.black.opacity(0.1), lineWidth: 0.5)
                )
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline.weight(.medium))
                    .foregroundColor(textColor)
                
                Text(description)
                    .font(.caption)
                    .foregroundColor(textColor.opacity(0.7))
                    .fixedSize(horizontal: false, vertical: true)
            }
            
            Spacer()
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(cardBackgroundColor)
        )
    }
}

#Preview {
    @Previewable @State var currentState: BottomSheetView.SheetState = .half
    @Previewable @State var showLegend = false
    @Previewable @State var showAbout = false
    @Previewable @State var currentMapStyle: GMSMapViewType = .normal
    
    return ZStack {
        Color.hushMapShape.ignoresSafeArea()
        
        BottomSheetView(
            currentState: $currentState,
            showLegend: $showLegend,
            showAbout: $showAbout,
            showAddReport: .constant(false),
            showNearby: .constant(false),
            showProfile: .constant(false),
            shouldFocusSearch: .constant(false),
            currentMapStyle: $currentMapStyle,
            onMapStyleSelected: { _ in },
            useClustering: .constant(true),
            sortByRecent: .constant(false),
            startDate: .constant(Date()),
            endDate: .constant(Date()),
            maxNoiseThreshold: .constant(0.5),
            maxCrowdThreshold: .constant(0.5),
            maxLightingThreshold: .constant(0.5)
        )
    }
}