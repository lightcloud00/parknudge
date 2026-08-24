import SwiftUI

struct PaywallView: View {
    @EnvironmentObject private var model: AppModel
    @Environment(\.dismiss) private var dismiss
    @ScaledMetric(relativeTo: .largeTitle) private var priceFontSize: CGFloat = 44
    @State private var legalDocument: LegalDocument?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    Image(systemName: "parkingsign.circle.fill")
                        .font(.system(size: 72))
                        .symbolRenderingMode(.palette)
                        .foregroundStyle(.white, .orange)
                        .accessibilityHidden(true)

                    VStack(spacing: 8) {
                        Text("ParkNudge Lifetime Pro")
                            .font(.largeTitle.bold())
                            .multilineTextAlignment(.center)
                        Text("One-time purchase, no subscription")
                            .font(.headline)
                            .foregroundStyle(.secondary)
                    }

                    priceBlock

                    if let feature = model.requestedProFeature {
                        Label("Unlock \(feature.title.lowercased())", systemImage: feature.symbol)
                            .font(.headline)
                            .padding()
                            .frame(maxWidth: .infinity)
                            .background(Color.orange.opacity(0.12), in: RoundedRectangle(cornerRadius: 16))
                    }

                    VStack(alignment: .leading, spacing: 16) {
                        ForEach(ProFeature.allCases) { feature in
                            Label(feature.title, systemImage: feature.symbol)
                                .font(.headline)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
                    .background(Color(uiColor: .secondarySystemBackground), in: RoundedRectangle(cornerRadius: 20))

                    Text("Free always includes one active spot, GPS and manual pin correction, Apple Maps directions, details and one photo, a meter timer, fixed 15/5/0-minute reminders, and the three newest completed sessions.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)

                    Button {
                        Task { await model.purchaseLifetime() }
                    } label: {
                        Group {
                            if model.isBusy {
                                ProgressView().tint(.white)
                            } else {
                                Text("Unlock Lifetime Pro")
                            }
                        }
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 4)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.orange)
                    .disabled(model.lifetimeProduct == nil || model.isBusy)
                    .accessibilityIdentifier("purchase-lifetime-pro")
                    .accessibilityLabel(purchaseAccessibilityLabel)

                    Button("Restore Purchases") { Task { await model.restorePurchases() } }
                        .frame(maxWidth: .infinity, minHeight: 44)
                        .contentShape(Rectangle())
                        .disabled(model.isBusy)
                        .accessibilityIdentifier("restore-purchases")
                        .accessibilityHint("Restores a previous Lifetime Pro purchase made with this Apple ID.")

                    if model.lifetimeProduct == nil, !model.isBusy {
                        Button("Retry App Store price") {
                            Task { await model.refreshLifetimeProduct() }
                        }
                        .frame(maxWidth: .infinity, minHeight: 44)
                        .contentShape(Rectangle())
                        .accessibilityIdentifier("retry-app-store-price")
                    }

                    Text("One non-consumable purchase charged to your Apple ID at confirmation. It does not renew, and there is no subscription, trial, or account. The price above is the localized App Store price for your storefront.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityIdentifier("paywall-purchase-terms")

                    HStack(spacing: 16) {
                        Button("Privacy") { legalDocument = .privacy }
                            .frame(maxWidth: .infinity, minHeight: 44)
                            .contentShape(Rectangle())
                            .accessibilityIdentifier("paywall-privacy")
                        Button("Terms") { legalDocument = .terms }
                            .frame(maxWidth: .infinity, minHeight: 44)
                            .contentShape(Rectangle())
                            .accessibilityIdentifier("paywall-terms")
                    }
                    .font(.footnote)
                }
                .padding()
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button { dismiss() } label: { Image(systemName: "xmark") }
                        .accessibilityLabel("Close")
                        .accessibilityIdentifier("close-paywall")
                }
            }
            .sheet(item: $legalDocument) { document in
                NavigationStack {
                    LegalView(document: document)
                        .toolbar {
                            ToolbarItem(placement: .confirmationAction) {
                                Button("Done") { legalDocument = nil }
                            }
                        }
                }
            }
        }
    }

    /// `PurchaseProduct.displayPrice` is a non-optional String, so writing
    /// `lifetimeProduct?.displayPrice.map { … }` applies `Sequence.map` to the
    /// unwrapped String and yields `[String]?`, not `String?`. Spelled out as a
    /// guard instead, which is both clearer and immune to that trap.
    private var purchaseAccessibilityLabel: String {
        guard let price = model.lifetimeProduct?.displayPrice else {
            return "Unlock Lifetime Pro. The price has not loaded from the App Store yet."
        }
        return "Unlock Lifetime Pro for \(price). One-time purchase."
    }

    /// The billed amount, standing on its own. It previously existed only
    /// inside the CTA label, where VoiceOver cannot reach it as its own
    /// element. There is no fallback figure: an unresolved product renders an
    /// em-dash, which reads as "not loaded" rather than as the price itself.
    private var priceBlock: some View {
        VStack(spacing: 4) {
            Group {
                if let price = model.lifetimeProduct?.displayPrice {
                    Text(price)
                        .accessibilityLabel("\(price), one-time purchase")
                } else {
                    Text(verbatim: "——")
                        .foregroundStyle(.secondary)
                        .accessibilityLabel("Price is still loading from the App Store")
                }
            }
            .font(.system(size: priceFontSize, weight: .semibold, design: .serif))
            .monospacedDigit()
            .lineLimit(1)
            .minimumScaleFactor(0.5)
            .accessibilityIdentifier("paywall-price")
        }
        .frame(maxWidth: .infinity)
    }
}
