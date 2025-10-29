import SwiftUI

struct ContentView: View {
    @StateObject private var sessionManager = WCSessionManager.shared
    @State private var selectedTab = 0

    var body: some View {
        TabView(selection: $selectedTab) {
            NavigationView {
                GlanceView()
            }
            .tag(0)

            NavigationView {
                LogView()
            }
            .tag(1)
        }
        .tabViewStyle(PageTabViewStyle())
        .onAppear {
            sessionManager.requestUpdate()
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
