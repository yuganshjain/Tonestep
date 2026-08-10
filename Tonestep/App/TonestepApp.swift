import SwiftUI
import SwiftData

@main
struct TonestepApp: App {
    @StateObject private var storeManager = StoreManager()
    @StateObject private var userProfile = UserProfileStore()

    init() {
        let purple = UIColor(red: 0.357, green: 0.310, blue: 0.812, alpha: 1)

        // Navigation bar — always purple
        let navAppearance = UINavigationBarAppearance()
        navAppearance.configureWithOpaqueBackground()
        navAppearance.backgroundColor = purple
        navAppearance.titleTextAttributes = [.foregroundColor: UIColor.white]
        navAppearance.largeTitleTextAttributes = [.foregroundColor: UIColor.white]
        UINavigationBar.appearance().standardAppearance = navAppearance
        UINavigationBar.appearance().scrollEdgeAppearance = navAppearance
        UINavigationBar.appearance().compactAppearance = navAppearance
        UINavigationBar.appearance().tintColor = .white

        // Tab bar — purple background
        let tabAppearance = UITabBarAppearance()
        tabAppearance.configureWithOpaqueBackground()
        tabAppearance.backgroundColor = purple
        tabAppearance.stackedLayoutAppearance.selected.iconColor = .white
        tabAppearance.stackedLayoutAppearance.selected.titleTextAttributes = [.foregroundColor: UIColor.white]
        tabAppearance.stackedLayoutAppearance.normal.iconColor = UIColor.white.withAlphaComponent(0.55)
        tabAppearance.stackedLayoutAppearance.normal.titleTextAttributes = [.foregroundColor: UIColor.white.withAlphaComponent(0.55)]
        UITabBar.appearance().standardAppearance = tabAppearance
        UITabBar.appearance().scrollEdgeAppearance = tabAppearance
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(storeManager)
                .environmentObject(userProfile)
                .modelContainer(for: [
                    DrillResult.self, DailySessionRecord.self, SRItem.self,
                    JourneyProgress.self, StageRecord.self
                ])
        }
    }
}
