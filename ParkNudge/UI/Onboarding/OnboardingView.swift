import MapKit
import SwiftUI

/// The first-launch introduction (Figma page 27:2). It replaces the tab view
/// rather than covering it, so the root's alert and Lifetime Pro sheet still
/// present normally while it is on screen.
///
/// It never opens the paywall on its own. Skip, Close, and Maybe Later all
/// finish it for good; Settings can replay it.
struct OnboardingView: View {
    @EnvironmentObject private var model: AppModel
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var step: OnboardingStep = .promise
    @State private var firstDraft: ParkingDraft?

    var body: some View {
        NavigationStack {
            page
                .id(step)
                .transition(
                    reduceMotion
                        ? .opacity
                        : .asymmetric(insertion: .move(edge: .trailing), removal: .move(edge: .leading))
                )
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    if step.offersSkip {
                        ToolbarItem(placement: .topBarTrailing) {
                            Button("Skip") { model.completeOnboarding() }
                                .accessibilityHint("Ends the introduction. You can replay it from Settings.")
                                .accessibilityIdentifier("onboarding-skip")
                        }
                    }
                    if step == .pro {
                        ToolbarItem(placement: .topBarTrailing) {
                            Button { model.completeOnboarding() } label: { Image(systemName: "xmark") }
                                .accessibilityLabel("Close")
                                .accessibilityIdentifier("onboarding-close")
                        }
                    }
                }
        }
        .tint(Theme.brandInk)
        .onChange(of: step) { _, _ in
            UIAccessibility.post(notification: .screenChanged, argument: nil)
        }
    }

    @ViewBuilder
    private var page: some View {
        switch step {
        case .promise:
            PromisePage { advance() }
        case .parkingStyle:
            ParkingStylePage(settings: model.settings) { advance() }
        case .location:
            LocationPage(isBusy: model.isBusy) {
                Task {
                    // The same one-shot capture the Park tab uses. It raises
                    // the When-In-Use prompt only if that is still undecided.
                    firstDraft = await model.newParkingDraft()
                    advance()
                }
            }
        case .firstSave:
            if let firstDraft {
                FirstSavePage(draft: firstDraft, settings: model.settings) { saved in
                    advance(remindersAwaitPermission: saved == .savedAwaitingReminderPermission)
                }
            }
        case .reminders:
            RemindersPage(
                meterExpiry: model.activeSession?.meterExpiresAt,
                offsets: model.reminderOffsets,
                isBusy: model.isBusy
            ) {
                Task {
                    await model.enableMeterReminders()
                    advance()
                }
            }
        case .pro:
            ProTeaserPage()
        }
    }

    private func advance(remindersAwaitPermission: Bool = false) {
        guard let next = OnboardingFlow.step(
            after: step,
            hasActiveSession: model.activeSession != nil,
            remindersAwaitPermission: remindersAwaitPermission
        ) else {
            model.completeOnboarding()
            return
        }
        withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.3)) {
            step = next
        }
    }
}

// MARK: - Pages

private struct PromisePage: View {
    let onContinue: () -> Void

    var body: some View {
        OnboardingPage(step: .promise, title: "Find your car. Beat the meter.",
                       message: "Save where you parked, set the meter, and get a nudge before it runs out.") {
            VStack(alignment: .leading, spacing: 14) {
                Beat(symbol: "mappin.and.ellipse", text: "Drop a pin where you parked")
                Beat(symbol: "timer", text: "Get nudged before the meter runs out")
                Beat(symbol: "figure.walk", text: "Walk back with directions")
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        } actions: {
            PrimaryAction(title: "Get Started", action: onContinue)
            Text("No account. No background tracking.")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
    }
}

private struct ParkingStylePage: View {
    @ObservedObject var settings: AppSettings
    let onContinue: () -> Void

    var body: some View {
        OnboardingPage(step: .parkingStyle, title: "Where do you usually park?",
                       message: "ParkNudge puts those details first when you save. You can change this in Settings.") {
            VStack(spacing: 10) {
                ForEach(ParkingStyle.allCases) { style in
                    StyleOption(style: style, isSelected: settings.parkingStyle == style) {
                        settings.parkingStyle = settings.parkingStyle == style ? nil : style
                    }
                }
            }
        } actions: {
            PrimaryAction(title: "Continue", action: onContinue)
        }
    }
}

private struct LocationPage: View {
    let isBusy: Bool
    let onContinue: () -> Void

    /// The shipped purpose string, read back so the explanation can never
    /// promise something different from what iOS shows next.
    private var purposeString: String {
        Bundle.main.object(forInfoDictionaryKey: "NSLocationWhenInUseUsageDescription") as? String
            ?? "Your location is used only when you save where you parked."
    }

    var body: some View {
        OnboardingPage(step: .location, title: "Find your way back",
                       message: "ParkNudge uses your location only while the app is open, to drop the pin where you parked.") {
            VStack(alignment: .leading, spacing: 10) {
                Text("iOS asks next")
                    .font(.caption.weight(.semibold))
                    .textCase(.uppercase)
                    .foregroundStyle(.secondary)
                Text(purposeString)
                    .font(.subheadline)
                Divider()
                Label("ParkNudge asks only for While Using the App, never Always.", systemImage: "location")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                Label("If you decline, you can still save by tapping the map.", systemImage: "hand.tap")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Theme.surfaceRaised, in: RoundedRectangle(cornerRadius: Theme.radiusTile))
        } actions: {
            PrimaryAction(title: "Continue", isBusy: isBusy, action: onContinue)
        }
    }
}

private struct FirstSavePage: View {
    @EnvironmentObject private var model: AppModel
    @ObservedObject var settings: AppSettings
    @State private var draft: ParkingDraft
    @State private var meterMinutes = 0
    @State private var mapPosition: MapCameraPosition
    let onSaved: (FirstSpotSave) -> Void

    private static let meterChoices: [(minutes: Int, title: String)] = [
        (0, "None"), (30, "30 min"), (60, "1 hr"), (120, "2 hr")
    ]

    init(draft: ParkingDraft, settings: AppSettings, onSaved: @escaping (FirstSpotSave) -> Void) {
        _draft = State(initialValue: draft)
        _mapPosition = State(initialValue: .region(MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: draft.coordinate.latitude, longitude: draft.coordinate.longitude),
            span: MKCoordinateSpan(latitudeDelta: 0.008, longitudeDelta: 0.008)
        )))
        self.settings = settings
        self.onSaved = onSaved
    }

    var body: some View {
        OnboardingPage(step: .firstSave, showsPip: false, title: "Save your first spot",
                       message: "Stand by your car and tap Save. Tap the map to move the pin.") {
            VStack(alignment: .leading, spacing: 18) {
                map
                ForEach(ParkingDetailSection.order(for: settings.parkingStyle), id: \.self) { section in
                    switch section {
                    case .details: detailFields
                    case .meter: meterPicker
                    case .photo: EmptyView()
                    }
                }
            }
        } actions: {
            PrimaryAction(title: "Save Parking Spot", isBusy: model.isBusy, identifier: "onboarding-save-first-spot") {
                Task { await save() }
            }
            Text("This is a real save. It stays on this iPhone, and you can add a photo or note later.")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
    }

    private var map: some View {
        MapReader { proxy in
            Map(position: $mapPosition) {
                Annotation("Park here", coordinate: coordinate) {
                    Image(systemName: "car.circle.fill")
                        .font(.system(size: 34))
                        .symbolRenderingMode(.palette)
                        .foregroundStyle(.white, Theme.brand)
                        .shadow(radius: 3)
                }
            }
            .frame(height: 200)
            .clipShape(RoundedRectangle(cornerRadius: Theme.radiusCard))
            .overlay(alignment: .bottomTrailing) {
                // Pip naps on the spot it is about to guard.
                PipView(mood: OnboardingStep.firstSave.pipMood, size: 64)
                    .padding(6)
                    .allowsHitTesting(false)
            }
            .onTapGesture { point in
                guard let tapped = proxy.convert(point, from: .local) else { return }
                draft.coordinate = GeoCoordinate(latitude: tapped.latitude, longitude: tapped.longitude)
                draft.horizontalAccuracy = -1
                draft.source = .manualPin
            }
            .accessibilityElement()
            .accessibilityLabel("Map with the spot to save")
            .accessibilityIdentifier("onboarding-first-save-map")
        }
    }

    @ViewBuilder
    private var detailFields: some View {
        switch settings.parkingStyle {
        case .garage:
            VStack(alignment: .leading, spacing: 8) {
                Text("Garage").font(.headline)
                TextField("Floor (optional)", text: $draft.floor)
                    .textFieldStyle(.roundedBorder)
                TextField("Section (optional)", text: $draft.section)
                    .textFieldStyle(.roundedBorder)
            }
        case .lot:
            VStack(alignment: .leading, spacing: 8) {
                Text("Lot").font(.headline)
                TextField("Row or landmark (optional)", text: $draft.note)
                    .textFieldStyle(.roundedBorder)
            }
        case .streetMeter, nil:
            EmptyView()
        }
    }

    private var meterPicker: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Meter").font(.headline)
            Picker("Meter", selection: $meterMinutes) {
                ForEach(Self.meterChoices, id: \.minutes) { choice in
                    Text(choice.title).tag(choice.minutes)
                }
            }
            .pickerStyle(.segmented)
            .accessibilityIdentifier("onboarding-meter")
            if meterMinutes > 0 {
                Text("Reminders \(OnboardingFlow.reminderSummary(offsets: model.reminderOffsets)).")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: draft.coordinate.latitude, longitude: draft.coordinate.longitude)
    }

    private func save() async {
        var draft = draft
        // The deadline starts when the spot is saved, not when the screen opened.
        draft.meterExpiresAt = meterMinutes > 0 ? Date().addingTimeInterval(TimeInterval(meterMinutes * 60)) : nil
        let result = await model.saveFirstSpot(draft: draft)
        if result != .failed { onSaved(result) }
    }
}

private struct RemindersPage: View {
    let meterExpiry: Date?
    let offsets: [Int]
    let isBusy: Bool
    let onContinue: () -> Void

    var body: some View {
        OnboardingPage(step: .reminders, title: "Get nudged before the meter runs out",
                       message: "ParkNudge reminds you \(OnboardingFlow.reminderSummary(offsets: offsets)). iOS asks next.") {
            VStack(spacing: 10) {
                ForEach(ReminderPlanner.normalizedOffsets(offsets).filter { $0 > 0 }, id: \.self) { offset in
                    ExampleReminder(
                        offset: offset,
                        fireDate: meterExpiry?.addingTimeInterval(TimeInterval(-offset * 60))
                    )
                }
            }
        } actions: {
            PrimaryAction(title: "Turn On Reminders", isBusy: isBusy, identifier: "onboarding-enable-reminders",
                          action: onContinue)
        }
    }
}

private struct ProTeaserPage: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        OnboardingPage(step: .pro, title: "You’re all set",
                       message: "ParkNudge is free for everyday parking. Lifetime Pro is one purchase, not a subscription.") {
            if model.entitlement.isPro {
                Label("Lifetime Pro is unlocked", systemImage: "checkmark.seal.fill")
                    .font(.headline)
                    .foregroundStyle(.green)
            } else {
                VStack(alignment: .leading, spacing: 12) {
                    HStack(alignment: .firstTextBaseline) {
                        Text("Lifetime Pro adds")
                            .font(.caption.weight(.semibold))
                            .textCase(.uppercase)
                            .foregroundStyle(.secondary)
                        Spacer(minLength: 8)
                        // StoreKit's localized price only; nothing when it has not loaded.
                        if let price = model.lifetimeProduct?.displayPrice {
                            Text("\(price) once")
                                .font(.subheadline.weight(.semibold).monospacedDigit())
                                .foregroundStyle(Theme.brandInk)
                        }
                    }
                    ForEach(ProFeature.allCases) { feature in
                        Label {
                            Text(feature.title)
                        } icon: {
                            Image(systemName: feature.symbol)
                                .foregroundStyle(Theme.brandInk)
                        }
                        .font(.subheadline)
                    }
                }
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Theme.surfaceRaised, in: RoundedRectangle(cornerRadius: Theme.radiusTile))
                .accessibilityElement(children: .combine)
            }
        } actions: {
            if model.entitlement.isPro {
                PrimaryAction(title: "Start Parking", identifier: "onboarding-finish") {
                    model.completeOnboarding()
                }
            } else {
                PrimaryAction(title: "See Lifetime Pro", identifier: "onboarding-see-pro") {
                    model.requestedProFeature = nil
                    model.isPaywallPresented = true
                }
                Button("Maybe Later") { model.completeOnboarding() }
                    .frame(maxWidth: .infinity, minHeight: Theme.minimumHitTarget)
                    .contentShape(Rectangle())
                    .accessibilityIdentifier("onboarding-finish")
            }
        }
    }
}

// MARK: - Building blocks

/// One introduction screen: Pip, a headline, a sentence, the screen's own
/// content, and its actions pinned above the home indicator.
private struct OnboardingPage<Content: View, Actions: View>: View {
    let step: OnboardingStep
    var showsPip = true
    let title: String
    let message: String
    @ViewBuilder let content: Content
    @ViewBuilder let actions: Actions

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                if showsPip {
                    PipView(mood: step.pipMood, size: 132)
                }
                VStack(spacing: 10) {
                    Text(title)
                        .font(.title.bold())
                        .multilineTextAlignment(.center)
                        .accessibilityAddTraits(.isHeader)
                    Text(message)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .fixedSize(horizontal: false, vertical: true)
                content
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 16)
            .frame(maxWidth: .infinity)
        }
        .scrollBounceBehavior(.basedOnSize)
        .safeAreaInset(edge: .bottom) {
            VStack(spacing: 8) { actions }
                .padding(.horizontal, 24)
                .padding(.top, 12)
                .padding(.bottom, 8)
                .background(Theme.surface)
        }
        .background(Theme.surface)
        // `.contain` first: an identifier on a plain container would replace
        // every child's own identifier instead of naming the container.
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("onboarding-step-\(step.rawValue)")
    }
}

private struct PrimaryAction: View {
    let title: String
    var isBusy = false
    var identifier = "onboarding-continue"
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Group {
                if isBusy {
                    ProgressView().tint(.white)
                } else {
                    Text(title)
                }
            }
            .font(.headline)
            .frame(maxWidth: .infinity, minHeight: Theme.primaryControlHeight - 16)
        }
        .buttonStyle(.borderedProminent)
        .tint(Theme.brand)
        .disabled(isBusy)
        .accessibilityLabel(title)
        .accessibilityIdentifier(identifier)
    }
}

private struct Beat: View {
    let symbol: String
    let text: String

    var body: some View {
        Label {
            Text(text)
        } icon: {
            Image(systemName: symbol)
                .foregroundStyle(Theme.brandInk)
        }
        .font(.body)
    }
}

private struct StyleOption: View {
    let style: ParkingStyle
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 14) {
                Image(systemName: style.symbol)
                    .font(.title3)
                    .foregroundStyle(Theme.brandInk)
                    .frame(width: 32)
                VStack(alignment: .leading, spacing: 3) {
                    Text(style.title)
                        .font(.headline)
                        .foregroundStyle(.primary)
                    Text(style.detail)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundStyle(isSelected ? Theme.brandInk : Color.secondary)
            }
            .padding()
            .background(Theme.surfaceRaised, in: RoundedRectangle(cornerRadius: Theme.radiusTile))
            .overlay(
                RoundedRectangle(cornerRadius: Theme.radiusTile)
                    .strokeBorder(isSelected ? Theme.brandInk : .clear, lineWidth: 2)
            )
            .contentShape(RoundedRectangle(cornerRadius: Theme.radiusTile))
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
        .accessibilityIdentifier("onboarding-style-\(style.rawValue)")
    }
}

/// A picture of the reminder iOS will deliver, using the shipped copy and,
/// once the meter is saved, its real fire time.
private struct ExampleReminder: View {
    let offset: Int
    let fireDate: Date?

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "parkingsign")
                .font(.headline)
                .foregroundStyle(.white)
                .frame(width: 34, height: 34)
                .background(Theme.brand, in: RoundedRectangle(cornerRadius: Theme.radiusInline))
            VStack(alignment: .leading, spacing: 2) {
                HStack(alignment: .firstTextBaseline) {
                    Text(ParkingNotificationCopy.title(offsetMinutes: offset))
                        .font(.subheadline.weight(.semibold))
                    Spacer(minLength: 8)
                    if let fireDate {
                        Text(fireDate.formatted(date: .omitted, time: .shortened))
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(.secondary)
                    }
                }
                Text(ParkingNotificationCopy.body(offsetMinutes: offset))
                    .font(.subheadline)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.surfaceRaised, in: RoundedRectangle(cornerRadius: Theme.radiusTile))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Example reminder")
        .accessibilityValue(ParkingNotificationCopy.body(offsetMinutes: offset))
    }
}
