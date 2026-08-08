import SwiftUI
import SwiftData

@main
struct EarIQApp: App {
    @StateObject private var storeManager = StoreManager()
    @StateObject private var userProfile = UserProfileStore()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(storeManager)
                .environmentObject(userProfile)
                .modelContainer(for: [DrillResult.self, DailySessionRecord.self, SRItem.self])
        }
    }
}
