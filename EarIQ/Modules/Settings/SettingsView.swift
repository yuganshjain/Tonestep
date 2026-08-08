import SwiftUI
import StoreKit

struct SettingsView: View {
    @EnvironmentObject private var userProfile: UserProfileStore
    @EnvironmentObject private var storeManager: StoreManager
    @State private var showPaywall = false

    var body: some View {
        NavigationStack {
            Form {
                practiceSection
                audioSection
                subscriptionSection
                dataSection
                aboutSection
            }
            .navigationTitle("Settings")
            .sheet(isPresented: $showPaywall) { PaywallView() }
        }
    }

    private var practiceSection: some View {
        Section("Practice") {
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

    private var audioSection: some View {
        Section("Audio") {
            Button("Test Piano Sound") {
                AudioEngine.shared.playNote(midiNote: 60, duration: 1.5)
            }
        }
    }

    private var subscriptionSection: some View {
        Section("EarIQ Pro") {
            if storeManager.isPro {
                HStack {
                    Image(systemName: "checkmark.seal.fill").foregroundStyle(.purple)
                    Text("You have EarIQ Pro")
                }
            } else {
                Button("Upgrade to Pro") { showPaywall = true }
                    .foregroundStyle(.purple)
            }
            Button("Restore Purchases") {
                Task { await storeManager.restorePurchases() }
            }
        }
    }

    private var dataSection: some View {
        Section("Data") {
            Button("Export Session Data (CSV)") {
                // TODO: generate CSV and share
            }
        }
    }

    private var aboutSection: some View {
        Section("About") {
            HStack {
                Text("Version")
                Spacer()
                Text(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0")
                    .foregroundStyle(.secondary)
            }
            Link("Privacy Policy", destination: URL(string: "https://yugansh.com/eariq/privacy")!)
            Button("Rate EarIQ on the App Store") {
                SKStoreReviewController.requestReviewInCurrentScene()
            }
        }
    }
}
