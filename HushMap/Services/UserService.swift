import Foundation
import SwiftData

class UserService {
    private let modelContext: ModelContext
    
    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }
    
    // Get the current user or create one if it doesn't exist
    func getCurrentUser() -> User {
        let descriptor = FetchDescriptor<User>()
        
        do {
            let users = try modelContext.fetch(descriptor)
            if let existingUser = users.first {
                return existingUser
            } else {
                // Create a new user
                let newUser = User(name: "HushMap User")
                modelContext.insert(newUser)
                try? modelContext.save()
                return newUser
            }
        } catch {
            print("Error fetching user: \(error)")
            
            // Create a new user as a fallback
            let newUser = User(name: "HushMap User")
            modelContext.insert(newUser)
            try? modelContext.save()
            return newUser
        }
    }
}