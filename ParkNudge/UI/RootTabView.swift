import SwiftUI

struct RootTabView: View {
    @EnvironmentObject private var model: AppModel
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var selectedTab = 0

    var body: some View {
        Group {
            if model.isOnboardingPresented {
                OnboardingView()
                    .transition(.opacity)
            } else {
                tabs
                    .transition(.opacity)
            }
        }
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.25), value: model.isOnboardingPresented)
        // Siri / Shortcuts: a cold launch finds the route already queued; a warm one is notified.
        .task { drainShortcut() }
        .onReceive(NotificationCenter.default.publisher(for: ParkingShortcutInbox.didEnqueue)) { _ in
            drainShortcut()
        }
        .sheet(isPresented: model.paywallPresentation(on: .root), onDismiss: model.paywallDidDismiss) {
            PaywallView()
                .environmentObject(model)
        }
        .alert(
            "ParkNudge",
            isPresented: Binding(
                get: { model.alertMessage != nil },
                set: { if !$0 { model.alertMessage = nil } }
            )
        ) {
            Button("OK") { model.alertMessage = nil }
        } message: {
            Text(model.alertMessage ?? "")
        }
    }

    private func drainShortcut() {
        guard let route = ParkingShortcutInbox.shared.take() else { return }
        selectedTab = 0
        model.pendingShortcut = route
    }

    private var tabs: some View {
        TabView(selection: $selectedTab) {
            ParkView()
                .tabItem { Label("Park", systemImage: "parkingsign.circle.fill") }
                .tag(0)

            HistoryView()
                .tabItem { Label("History", systemImage: "clock.arrow.circlepath") }
                .tag(1)

            SettingsView()
                .tabItem { Label("Settings", systemImage: "gearshape") }
                .tag(2)
        }
        .tint(Theme.brandInk)
    }
}
