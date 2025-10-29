import SwiftUI
import SwiftData

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    
    var body: some View {
        SingleScreenMapView()
            .ignoresSafeArea(.all)
            .onAppear {
                // Initialize smart notification service singleton
                let service = SmartNotificationService.shared(modelContext: modelContext)
                service.enableSmartNotifications()
            }
    }
}

#Preview {
    ContentView()
        .modelContainer(for: [Item.self, Report.self, User.self, Badge.self], inMemory: true)
}
