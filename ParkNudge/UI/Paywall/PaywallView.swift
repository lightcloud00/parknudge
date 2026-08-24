import SwiftUI

struct PaywallView: View {
    @EnvironmentObject private var model: AppModel
    @Environment(\.dismiss) private var dismiss
    @ScaledMetric(relativeTo: .largeTitle) private var priceFontSize: CGFloat = 44
    @State private var legalDocument: LegalDocument?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 22) {
                    Image(systemName: "parkingsign.circle.fill")
                        .font(.system(size: 68))
                        .symbolRenderingMode(.palette)
                        .foregroundStyle(Theme.cream, Theme.navy)
                        .accessibilityHidden(true)

                    VStack(spacing: 6) {
                        Text("ParkNudge Lifetime Pro")
                            .font(.largeTitle.bold())
                            .multilineTextAlignment(.center)
                        priceBlock
                        Text("No subscription, no trial, no account.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }

                    if let feature = model.requestedProFeature {
                        Label("Unlock \(feature.title.lowercased())", systemImage: feature.symbol)
                            .font(.headline)
                            .foregroundStyle(Theme.brandInk)
                            .padding()
                            .frame(maxWidth: .infinity)
                            .background(
                                Color("MeterWarnSurface", bundle: .main),
                                in: RoundedRectangle(cornerRadius: Theme.radiusTile)
                            )
                    }

                    comparison

                    Text("Older sessions are never deleted — free simply shows the newest \(FeatureAccessPolicy.freeHistoryLimit). Everything stays on this iPhone.")
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
                    .tint(Theme.brand)
                    .disabled(model.lifetimeProduct == nil || model.isBusy)
                    .accessibilityIdentifier("purchase-lifetime-pro")
                    .accessibilityLabel(purchaseAccessibilityLabel)

                    Button("Restore Purchases") { Task { await model.restorePurchases() } }
                        .frame(maxWidth: .infinity, minHeight: Theme.minimumHitTarget)
                        .contentShape(Rectangle())
                        .disabled(model.isBusy)
                        .accessibilityIdentifier("restore-purchases")
                        .accessibilityHint("Restores a previous Lifetime Pro purchase made with this Apple ID.")

                    if model.lifetimeProduct == nil, !model.isBusy {
                        Button("Retry App Store price") {
                            Task { await model.refreshLifetimeProduct() }
                        }
                        .frame(maxWidth: .infinity, minHeight: Theme.minimumHitTarget)
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
                            .frame(maxWidth: .infinity, minHeight: Theme.minimumHitTarget)
                            .contentShape(Rectangle())
                            .accessibilityIdentifier("paywall-privacy")
                        Button("Terms") { legalDocument = .terms }
                            .frame(maxWidth: .infinity, minHeight: Theme.minimumHitTarget)
                            .contentShape(Rectangle())
                            .accessibilityIdentifier("paywall-terms")
                    }
                    .font(.footnote)
                }
                .padding()
            }
            .tint(Theme.brandInk)
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
        HStack(alignment: .firstTextBaseline, spacing: 8) {
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
            .font(.system(size: priceFontSize, weight: .bold))
            .monospacedDigit()
            .lineLimit(1)
            .minimumScaleFactor(0.5)
            .accessibilityIdentifier("paywall-price")

            Text("once")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    /// Free against Pro, side by side. A flat list of Pro features gave no
    /// sense of how much the free app already does, which for this app is most
    /// of it — the honest comparison is also the more persuasive one.
    private var comparison: some View {
        VStack(spacing: 0) {
            ComparisonRow(
                title: Text("What you get").font(.caption.weight(.semibold)).foregroundStyle(.secondary),
                free: Text("Free").font(.caption.weight(.semibold)).foregroundStyle(.secondary),
                pro: Text("Pro").font(.caption.bold()).foregroundStyle(Theme.brandInk)
            )
            .padding(.vertical, 8)
            .background(Theme.surfaceRaised)

            Divider()

            ComparisonRow(
                title: Text("Save a spot, pin, photo, directions"),
                free: included,
                pro: included
            )
            .padding(.vertical, 9)

            ForEach(ProFeature.allCases) { feature in
                Divider()
                ComparisonRow(
                    title: Text(feature.comparisonTitle),
                    free: allowance(feature.freeAllowance, emphasised: false),
                    pro: allowance(feature.proAllowance, emphasised: true)
                )
                .padding(.vertical, 9)
            }
        }
        .padding(.horizontal, 12)
        .background(
            RoundedRectangle(cornerRadius: Theme.radiusTile)
                .strokeBorder(Theme.separator)
        )
        .clipShape(RoundedRectangle(cornerRadius: Theme.radiusTile))
    }

    private var included: AnyView {
        AnyView(
            Image(systemName: "checkmark")
                .font(.footnote.bold())
                .foregroundStyle(.green)
                .accessibilityLabel("included")
        )
    }

    private var excluded: AnyView {
        AnyView(
            Image(systemName: "minus")
                .font(.footnote.bold())
                .foregroundStyle(.tertiary)
                .accessibilityLabel("not included")
        )
    }

    @ViewBuilder
    private func allowance(_ value: String?, emphasised: Bool) -> some View {
        if let value {
            Text(value)
                .font(.caption.weight(emphasised ? .bold : .regular).monospacedDigit())
                .foregroundStyle(emphasised ? Theme.brandInk : .secondary)
        } else if emphasised {
            included
        } else {
            excluded
        }
    }
}

private struct ComparisonRow<Title: View, Free: View, Pro: View>: View {
    let title: Title
    let free: Free
    let pro: Pro

    var body: some View {
        HStack(spacing: 8) {
            title
                .font(.subheadline)
                .frame(maxWidth: .infinity, alignment: .leading)
            free
                .frame(width: 54)
            pro
                .frame(width: 54)
        }
    }
}
