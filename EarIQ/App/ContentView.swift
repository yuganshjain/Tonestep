import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var userProfile: UserProfileStore
    @State private var selectedTab: Tab = .today

    var body: some View {
        Group {
            if userProfile.hasCompletedOnboarding {
                mainTabView
            } else {
                OnboardingView()
            }
        }
    }

    private var mainTabView: some View {
        TabView(selection: $selectedTab) {
            TodayView()
                .tabItem { Label("Today", systemImage: "flame.fill") }
                .tag(Tab.today)

            TrainView()
                .tabItem { Label("Train", systemImage: "music.note.list") }
                .tag(Tab.train)

            ProgressView()
                .tabItem { Label("Progress", systemImage: "chart.bar.fill") }
                .tag(Tab.progress)

            ChallengesView()
                .tabItem { Label("Challenges", systemImage: "trophy.fill") }
                .tag(Tab.challenges)

            SettingsView()
                .tabItem { Label("Settings", systemImage: "gearshape.fill") }
                .tag(Tab.settings)
        }
        .tint(.purple)
    }
}

enum Tab {
    case today, train, progress, challenges, settings
}
