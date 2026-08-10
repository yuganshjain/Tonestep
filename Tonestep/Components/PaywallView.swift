import SwiftUI
import StoreKit

struct PaywallView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var storeManager: StoreManager
    @State private var selectedProductID: String = TonestepProduct.annual.rawValue
    @State private var isPurchasing = false
    @State private var errorMessage: String?

    private let proFeatures = [
        ("The Full 112-Stage Journey", "map.fill"),
        ("All 15 Training Modules", "checkmark.circle.fill"),
        ("Smart Spaced Repetition", "arrow.triangle.2.circlepath"),
        ("Full Progress Analytics", "chart.bar.fill"),
        ("All 5 Instrument Sounds", "music.note"),
        ("Streak Freeze Protection", "flame.fill"),
    ]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 28) {
                    headerSection
                    featuresSection
                    if !storeManager.products.isEmpty {
                        pricingSection
                        purchaseButton
                    } else if storeManager.isLoading {
                        ProgressView()
                    } else {
                        // Without this the view spins forever when products fail
                        // to load — no network, or the IDs are not yet live in
                        // App Store Connect — leaving the user with no
                        // explanation and no way to retry.
                        unavailableSection
                    }
                    restoreButton
                    legalText
                }
                .padding()
            }
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Close") { dismiss() }
                }
            }
        }
        .alert("Purchase Error", isPresented: .constant(errorMessage != nil)) {
            Button("OK") { errorMessage = nil }
        } message: {
            Text(errorMessage ?? "")
        }
    }

    private var headerSection: some View {
        VStack(spacing: 10) {
            Image(systemName: "ear.fill")
                .font(.system(size: 56))
                .foregroundStyle(.purple)
            Text("Tonestep Pro")
                .font(.largeTitle)
                .fontWeight(.bold)
            Text("Train like a professional musician")
                .foregroundStyle(.secondary)
        }
        .padding(.top)
    }

    private var featuresSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            ForEach(proFeatures, id: \.0) { feature, icon in
                HStack(spacing: 12) {
                    Image(systemName: icon)
                        .foregroundStyle(.purple)
                        .frame(width: 24)
                    Text(feature)
                        .font(.subheadline)
                }
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 16))
    }

    private var pricingSection: some View {
        VStack(spacing: 12) {
            ForEach(storeManager.products, id: \.id) { product in
                Button {
                    selectedProductID = product.id
                } label: {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            HStack(spacing: 6) {
                                Text(product.displayName)
                                    .fontWeight(.semibold)
                                if let badge = TonestepProduct(rawValue: product.id)?.badge {
                                    Text(badge)
                                        .font(.caption2)
                                        .fontWeight(.bold)
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 2)
                                        .background(Color.purple)
                                        .foregroundStyle(.white)
                                        .clipShape(Capsule())
                                }
                            }
                            Text(product.description)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        VStack(alignment: .trailing) {
                            Text(product.displayPrice)
                                .fontWeight(.bold)
                        }
                        if selectedProductID == product.id {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(.purple)
                        }
                    }
                    .padding()
                    .background(
                        selectedProductID == product.id
                            ? Color.purple.opacity(0.1)
                            : Color(.secondarySystemBackground),
                        in: RoundedRectangle(cornerRadius: 12)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .strokeBorder(selectedProductID == product.id ? Color.purple : Color.clear, lineWidth: 1.5)
                    )
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var purchaseButton: some View {
        Button {
            Task { await purchase() }
        } label: {
            Group {
                if isPurchasing {
                    ProgressView()
                        .tint(.white)
                } else {
                    Text("Continue")
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(Color.purple)
            .foregroundStyle(.white)
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .fontWeight(.semibold)
        }
        .disabled(isPurchasing)
    }

    private var unavailableSection: some View {
        VStack(spacing: 10) {
            Image(systemName: "wifi.exclamationmark")
                .font(.title2)
                .foregroundStyle(.secondary)
            Text("Plans couldn't be loaded")
                .font(.subheadline).fontWeight(.semibold)
            Text("Check your connection and try again.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Button("Try Again") {
                Task { await storeManager.loadProducts() }
            }
            .fontWeight(.semibold)
            .foregroundStyle(Color.appPurple)
        }
        .padding(.vertical, 8)
    }

    private var restoreButton: some View {
        Button("Restore Purchases") {
            Task { await storeManager.restorePurchases() }
        }
        .font(.subheadline)
        .foregroundStyle(.secondary)
    }

    private var legalText: some View {
        Text("Payment will be charged to your Apple ID. Subscriptions automatically renew unless cancelled at least 24 hours before the end of the current period.")
            .font(.caption2)
            .foregroundStyle(.tertiary)
            .multilineTextAlignment(.center)
    }

    private func purchase() async {
        guard let product = storeManager.products.first(where: { $0.id == selectedProductID }) else { return }
        isPurchasing = true
        do {
            try await storeManager.purchase(product)
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
        isPurchasing = false
    }
}

// MARK: - Pro Teaser

struct ProTeaser: View {
    let title: String
    let description: String
    let icon: String
    @State private var showPaywall = false

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: icon)
                .font(.system(size: 44))
                .foregroundStyle(.purple.opacity(0.4))
            Text(title)
                .font(.headline)
            Text(description)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Button("Unlock with Pro") { showPaywall = true }
                .buttonStyle(.borderedProminent)
                .tint(.purple)
        }
        .padding(24)
        .background(.background, in: RoundedRectangle(cornerRadius: 16))
        .sheet(isPresented: $showPaywall) { PaywallView() }
    }
}
