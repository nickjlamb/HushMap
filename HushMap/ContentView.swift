import SwiftUI
import SwiftData

struct ContentView: View {
    @State private var selectedTab = 0
    
    var body: some View {
        VStack(spacing: 0) {
            // Main content - takes all available space above tab bar
            TabView(selection: $selectedTab) {
                HomeMapView()
                    .tag(0)

                NearbyView()
                    .tag(1)

                AddReportView()
                    .tag(2)

                ReportHistoryView()
                    .tag(3)
                    
                ProfileView()
                    .tag(4)
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            
            // Custom Tab Bar at bottom
            CustomTabBar(selectedTab: $selectedTab)
        }
        .ignoresSafeArea(.all, edges: .all)
        .background(Color.black)
        .onAppear {
            // Listen for tab switching notifications
            NotificationCenter.default.addObserver(
                forName: Notification.Name("SwitchToTab"),
                object: nil,
                queue: .main
            ) { notification in
                if let tabIndex = notification.userInfo?["tabIndex"] as? Int {
                    selectedTab = tabIndex
                }
            }
        }
    }
}

struct CustomTabBar: View {
    @Binding var selectedTab: Int
    
    private let tabs = [
        TabItem(icon: "map", title: "Map", tag: 0),
        TabItem(icon: "location.magnifyingglass", title: "Nearby", tag: 1),
        TabItem(icon: "plus.circle.fill", title: "Add", tag: 2),
        TabItem(icon: "clock", title: "History", tag: 3),
        TabItem(icon: "person.circle", title: "Profile", tag: 4)
    ]
    
    var body: some View {
        HStack(spacing: 0) {
            ForEach(tabs, id: \.tag) { tab in
                Button(action: {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        selectedTab = tab.tag
                    }
                }) {
                    VStack(spacing: 4) {
                        Image(systemName: tab.icon)
                            .font(.title2)
                            .foregroundColor(selectedTab == tab.tag ? .white : .hushBackground)
                        
                        Text(tab.title)
                            .font(.caption2)
                            .fontWeight(.medium)
                            .foregroundColor(selectedTab == tab.tag ? .white : .hushBackground)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .padding(.horizontal, 8)
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(selectedTab == tab.tag ? Color.hushBackground : Color.clear)
                            .animation(.easeInOut(duration: 0.2), value: selectedTab)
                    )
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            Rectangle()
                .fill(Color.hushMapShape.opacity(0.95))
                .shadow(color: .black.opacity(0.15), radius: 8, x: 0, y: -4)
        )
        .ignoresSafeArea(.container, edges: .bottom)
    }
}

struct TabItem {
    let icon: String
    let title: String
    let tag: Int
}

#Preview {
    ContentView()
        .modelContainer(for: [Item.self, Report.self, User.self, Badge.self], inMemory: true)
}
