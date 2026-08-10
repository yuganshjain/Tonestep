import SwiftUI
import StoreKit
import SwiftData

struct SettingsView: View {
    @EnvironmentObject private var userProfile: UserProfileStore
    @EnvironmentObject private var storeManager: StoreManager
    @Environment(\.requestReview) private var requestReview
    @Environment(\.modelContext) private var modelContext
    @Query private var allResults: [DrillResult]
    @Query private var allSessions: [DailySessionRecord]
    @State private var showPaywall = false
    @State private var showResetConfirm = false
    @State private var showResetDone = false
    @State private var csvURL: URL?
    @State private var showCSVShare = false
    @State private var notificationsEnabled = false
    @State private var reminderTime = Calendar.current.date(from: DateComponents(hour: 20, minute: 0)) ?? Date()

    var body: some View {
        NavigationStack {
            Form {
                practiceSection
                notificationSection
                audioSection
                subscriptionSection
                dataSection
                aboutSection
            }
            .scrollContentBackground(.hidden)
            .background(Color.appPurple)
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Color.appPurple, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .sheet(isPresented: $showPaywall) { PaywallView() }
            .sheet(isPresented: $showCSVShare) {
                if let url = csvURL {
                    ShareSheet(url: url)
                }
            }
            .alert("Reset All Data?", isPresented: $showResetConfirm) {
                Button("Reset", role: .destructive) { performReset() }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This permanently deletes all drill history, XP, streaks, and achievements. This cannot be undone.")
            }
            .alert("Data Reset", isPresented: $showResetDone) {
                Button("OK") {}
            } message: {
                Text("All your data has been reset.")
            }
        }
    }

    private var practiceSection: some View {
        Section(header: Text("Practice").foregroundStyle(.white.opacity(0.85))) {
            Picker("Instrument", selection: $userProfile.instrument) {
                ForEach(Instrument.allCases, id: \.self) { Text($0.rawValue).tag($0) }
            }
            Picker("Input Method", selection: $userProfile.inputMethod) {
                ForEach(InputMethod.allCases, id: \.self) { Text($0.rawValue).tag($0) }
            }
            Picker("Solfège Style", selection: $userProfile.solfegeStyle) {
                ForEach(SolfegeStyle.allCases, id: \.self) { Text($0.rawValue).tag($0) }
            }
            Picker("Session Length", selection: $userProfile.sessionLength) {
                ForEach(SessionLength.allCases, id: \.self) { Text($0.label).tag($0) }
            }
        }
    }

    private var notificationSection: some View {
        Section(header: Text("Daily Reminder").foregroundStyle(.white.opacity(0.85))) {
            Toggle("Practice Reminder", isOn: $notificationsEnabled)
                .onChange(of: notificationsEnabled) { _, enabled in
                    if enabled {
                        NotificationManager.shared.requestPermission { granted in
                            if granted {
                                scheduleNotification()
                            } else {
                                notificationsEnabled = false
                            }
                        }
                    } else {
                        NotificationManager.shared.cancel()
                    }
                }
            if notificationsEnabled {
                DatePicker("Remind me at", selection: $reminderTime, displayedComponents: .hourAndMinute)
                    .onChange(of: reminderTime) { _, _ in scheduleNotification() }
            }
        }
        .onAppear {
            notificationsEnabled = UserDefaults.standard.bool(forKey: "notificationsEnabled")
            if let saved = UserDefaults.standard.object(forKey: "reminderTime") as? Date {
                reminderTime = saved
            }
        }
    }

    private func scheduleNotification() {
        let cal = Calendar.current
        let comps = cal.dateComponents([.hour, .minute], from: reminderTime)
        NotificationManager.shared.schedule(at: comps)
        UserDefaults.standard.set(notificationsEnabled, forKey: "notificationsEnabled")
        UserDefaults.standard.set(reminderTime, forKey: "reminderTime")
    }

    private var audioSection: some View {
        Section(header: Text("Audio").foregroundStyle(.white.opacity(0.85))) {
            Button("Test \(userProfile.instrument.rawValue) Sound") {
                AudioEngine.shared.playNote(midiNote: 60, duration: 1.5)
            }
        }
    }

    private var subscriptionSection: some View {
        Section(header: Text("Tonestep Pro").foregroundStyle(.white.opacity(0.85))) {
            if storeManager.isPro {
                HStack {
                    Image(systemName: "checkmark.seal.fill").foregroundStyle(Color.purple)
                    Text("You have Tonestep Pro")
                }
            } else {
                Button("Upgrade to Pro") { showPaywall = true }
                    .foregroundStyle(Color.purple)
            }
            Button("Restore Purchases") {
                Task { await storeManager.restorePurchases() }
            }
        }
    }

    private var dataSection: some View {
        Section(header: Text("Data").foregroundStyle(.white.opacity(0.85))) {
            Button("Export Practice History (CSV)") {
                exportCSV()
            }
            .disabled(allResults.isEmpty)

            Button("Reset All Data") {
                showResetConfirm = true
            }
            .foregroundStyle(.red)
        }
    }

    private var aboutSection: some View {
        Section(header: Text("About").foregroundStyle(.white.opacity(0.85))) {
            HStack {
                Text("Version")
                Spacer()
                Text(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0")
                    .foregroundStyle(.secondary)
            }
            // Served by GitHub Pages from docs/. Verified live.
            // NOTE: the path carries the old repo name. Renaming the GitHub repo
            // to match the app would break this link and fail App Store review,
            // which requires the privacy URL to load.
            Link("Privacy Policy", destination: AppLinks.privacyPolicy)
            Button("Rate Tonestep on the App Store") {
                requestReview()
            }
        }
    }

    // MARK: - Actions

    private func exportCSV() {
        var lines = ["date,module,drill_type,correct,response_time_ms"]
        let fmt = ISO8601DateFormatter()
        for r in allResults.sorted(by: { $0.timestamp < $1.timestamp }) {
            let row = [
                fmt.string(from: r.timestamp),
                r.moduleRaw,
                r.drillType,
                r.wasCorrect ? "1" : "0",
                String(Int(r.responseTime * 1000))
            ].joined(separator: ",")
            lines.append(row)
        }
        let csv = lines.joined(separator: "\n")
        let tmp = FileManager.default.temporaryDirectory
            .appendingPathComponent("tonestep_history_\(Int(Date().timeIntervalSince1970)).csv")
        try? csv.write(to: tmp, atomically: true, encoding: .utf8)
        csvURL = tmp
        showCSVShare = true
    }

    private func performReset() {
        for r in allResults { modelContext.delete(r) }
        for s in allSessions { modelContext.delete(s) }
        try? modelContext.save()

        // Reset user profile stored values
        let keys = ["eariq_xp","eariq_currentStreak","eariq_longestStreak",
                    "eariq_lastSessionDate","dailyChallengeDate","dailyChallengeScore",
                    "dailyChallengeBest","eariq_achievements"]
        for key in keys { UserDefaults.standard.removeObject(forKey: key) }

        showResetDone = true
    }
}

// MARK: - URL Share Sheet

struct ShareSheet: UIViewControllerRepresentable {
    let url: URL
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: [url], applicationActivities: nil)
    }
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
