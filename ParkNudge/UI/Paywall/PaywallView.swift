import SwiftUI

struct PaywallView: View {
    @EnvironmentObject private var model: AppModel
    @Environment(\.dismiss) private var dismiss
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
                            if let price = model.lifetimeProduct?.displayPrice {
                                Text("Unlock Lifetime Pro for \(price)")
                            } else {
                                Text("Lifetime Pro Unavailable")
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

                    Button("Restore Purchases") { Task { await model.restorePurchases() } }
                        .disabled(model.isBusy)
                        .accessibilityIdentifier("restore-purchases")

                    HStack(spacing: 24) {
                        Button("Privacy") { legalDocument = .privacy }
                        Button("Terms") { legalDocument = .terms }
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
}
