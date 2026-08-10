import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var userProfile: UserProfileStore
    @State private var selectedTab: Tab = .today

    var body: some View {
        ZStack {
            Color.appPurple
            if userProfile.hasCompletedOnboarding {
                mainTabView
            } else {
                OnboardingView()
            }
        }
        .ignoresSafeArea()
        .preferredColorScheme(.light)
    }

    private var mainTabView: some View {
        TabView(selection: $selectedTab) {
            TodayView()
                .tabItem { Label("Today", systemImage: "flame.fill") }
                .tag(Tab.today)

            TrainView()
                .tabItem { Label("Train", systemImage: "music.note.list") }
                .tag(Tab.train)

            TheoryLessonsView()
                .tabItem { Label("Learn", systemImage: "books.vertical.fill") }
                .tag(Tab.learn)

            ProgressTabView()
                .tabItem { Label("Progress", systemImage: "chart.bar.fill") }
                .tag(Tab.progress)

            SettingsView()
                .tabItem { Label("Settings", systemImage: "gearshape.fill") }
                .tag(Tab.settings)
        }
        .tint(Color.appPurple)
        .toolbarBackground(Color.appPurple.opacity(0.95), for: .tabBar)
        .toolbarColorScheme(.dark, for: .tabBar)
    }
}

enum Tab {
    case today, train, learn, progress, settings
}
