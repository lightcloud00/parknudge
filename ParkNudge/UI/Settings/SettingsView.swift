import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var model: AppModel
    @State private var legalDocument: LegalDocument?
    @State private var confirmDeleteAll = false

    var body: some View {
        NavigationStack {
            Form {
                proSection
                remindersSection
                dataSection
                aboutSection
            }
            .navigationTitle("Settings")
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
        .confirmationDialog(
            "Delete all parking data?",
            isPresented: $confirmDeleteAll,
            titleVisibility: .visible
        ) {
            Button("Delete All", role: .destructive) {
                Task { _ = await model.deleteEverything() }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This permanently removes active and completed sessions, photos, and reminder requests from this iPhone. Your App Store purchase is not affected.")
        }
    }

    private var proSection: some View {
        Section {
            if model.entitlement.isPro {
                Label("Lifetime Pro unlocked", systemImage: "checkmark.seal.fill")
                    .foregroundStyle(.green)
            } else {
                Button {
                    model.requestedProFeature = nil
                    model.isPaywallPresented = true
                } label: {
                    HStack {
                        Label {
                            VStack(alignment: .leading, spacing: 1) {
                                Text("Lifetime Pro")
                                Text("One-time purchase")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        } icon: {
                            Image(systemName: "sparkles")
                                .foregroundStyle(Theme.brand)
                        }
                        Spacer()
                        if let price = model.lifetimeProduct?.displayPrice {
                            Text(price)
                                .monospacedDigit()
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }

            Button("Restore Purchases") { Task { await model.restorePurchases() } }
                .disabled(model.isBusy)
        } header: {
            Text("ParkNudge Pro")
        } footer: {
            Text("One-time purchase, no subscription. The full free parking workflow always remains available.")
        }
    }

    @ViewBuilder
    private var remindersSection: some View {
        Section {
            if model.hasAccess(to: .customReminders) {
                ReminderPresetEditor(settings: model.settings)
            } else {
                LabeledContent(
                    "Free reminders",
                    value: ReminderPlanner.freeOffsets.map(String.init).joined(separator: " / ") + " min"
                )
                Button { model.requestAccess(to: .customReminders) } label: {
                    Label {
                        Text("Customize with Pro")
                    } icon: {
                        Image(systemName: "lock.fill")
                            .foregroundStyle(Theme.brandInk)
                    }
                }
            }
        } header: {
            Text("Meter reminders")
        } footer: {
            Text("Warnings already in the past are skipped when a meter is saved or extended.")
        }
    }

    private var dataSection: some View {
        Section("Local data") {
            LabeledContent("Completed sessions", value: "\(model.completedSessions.count)")
            Text("All data stays on this iPhone unless you explicitly share a CSV export.")
                .font(.footnote)
                .foregroundStyle(.secondary)
            Button("Delete All Parking Data", role: .destructive) { confirmDeleteAll = true }
        }
    }

    private var aboutSection: some View {
        Section("About") {
            Button("Privacy") { legalDocument = .privacy }
            Button("Terms") { legalDocument = .terms }
            LabeledContent("Version", value: appVersion)
        }
    }

    private var appVersion: String {
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0.1.0"
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "1"
        return "\(version) (\(build))"
    }
}

private struct ReminderPresetEditor: View {
    @ObservedObject var settings: AppSettings
    @State private var newOffset = 20

    var body: some View {
        ForEach(settings.customReminderOffsets, id: \.self) { offset in
            HStack {
                Text(offset == 0 ? "At expiry" : "\(offset) minutes before")
                Spacer()
                Button(role: .destructive) {
                    settings.customReminderOffsets.removeAll { $0 == offset }
                } label: {
                    Image(systemName: "minus.circle")
                }
                .accessibilityLabel("Remove \(offset) minute reminder")
            }
        }

        if settings.customReminderOffsets.count < ReminderPlanner.maximumCustomOffsets {
            Stepper(value: $newOffset, in: 0...1_440, step: 5) {
                Text(newOffset == 0 ? "At expiry" : "New: \(newOffset) min before")
            }
            Button("Add Reminder") {
                settings.customReminderOffsets = ReminderPlanner.normalizedOffsets(
                    settings.customReminderOffsets + [newOffset]
                )
            }
            .disabled(settings.customReminderOffsets.contains(newOffset))
        }
    }
}
