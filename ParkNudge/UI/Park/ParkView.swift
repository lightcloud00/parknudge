import MapKit
import SwiftUI

struct ParkView: View {
    @EnvironmentObject private var model: AppModel
    @State private var editorContext: ParkingEditorContext?
    @State private var confirmsReplacement = false
    @State private var confirmsFinish = false

    var body: some View {
        NavigationStack {
            Group {
                if let session = model.activeSession {
                    activeContent(session)
                } else {
                    emptyContent
                }
            }
            .navigationTitle("ParkNudge")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    if model.activeSession == nil {
                        Button {
                            beginNewParking(replacing: false)
                        } label: {
                            Image(systemName: "plus")
                        }
                        .accessibilityLabel("Save Parking Spot")
                    } else {
                        // "Park somewhere else" is a rare action. Keeping it as a
                        // fourth full-width button made every action look equally
                        // likely; here it stays one tap away without competing
                        // with Directions.
                        Menu {
                            Button {
                                confirmsReplacement = true
                            } label: {
                                Label("Park Somewhere Else", systemImage: "arrow.triangle.2.circlepath")
                            }
                        } label: {
                            Image(systemName: "ellipsis.circle")
                        }
                        .accessibilityLabel("More parking actions")
                        .accessibilityIdentifier("parking-actions-menu")
                    }
                }
            }
        }
        .sheet(item: $editorContext) { context in
            ParkingEditorView(context: context)
                .environmentObject(model)
        }
        .confirmationDialog(
            "Park somewhere else?",
            isPresented: $confirmsReplacement,
            titleVisibility: .visible
        ) {
            Button("Archive Current Spot and Continue") {
                beginNewParking(replacing: true)
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Your current spot will move to History. Its photo and details will be kept.")
        }
        .confirmationDialog(
            "Finish this parking session?",
            isPresented: $confirmsFinish,
            titleVisibility: .visible
        ) {
            Button("Finish Parking") { Task { await model.finishActive() } }
            Button("Cancel", role: .cancel) {}
        }
    }

    private var emptyContent: some View {
        ContentUnavailableView {
            Label("Remember Where You Parked", systemImage: "mappin.and.ellipse")
        } description: {
            VStack(spacing: 20) {
                Text("Save one spot, set the meter deadline, and get walking directions back to your car.")

                VStack(alignment: .leading, spacing: 12) {
                    EmptyStateBeat(
                        symbol: "mappin.and.ellipse",
                        text: "Drop a pin, or correct it by tapping the map"
                    )
                    EmptyStateBeat(
                        symbol: "timer",
                        text: "Get nudged before the meter runs out"
                    )
                    EmptyStateBeat(
                        symbol: "camera",
                        text: "Add a photo, floor, bay, or a note"
                    )
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.horizontal, 8)
        } actions: {
            Button {
                beginNewParking(replacing: false)
            } label: {
                Label("Save Parking Spot", systemImage: "location.fill")
                    .font(.headline)
                    .padding(.horizontal, 8)
            }
            .buttonStyle(.borderedProminent)
            .tint(Theme.brand)
            .disabled(model.isBusy)
            .accessibilityIdentifier("save-parking-spot")

            Text("Location is requested only after you tap this button.")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
    }

    private func activeContent(_ session: ParkingSession) -> some View {
        ScrollView {
            VStack(spacing: 14) {
                // The meter is the one thing a returning driver is anxious
                // about, so it leads. Without a meter there is nothing urgent
                // to hoist and the map keeps the top slot.
                if let expiry = session.meterExpiresAt {
                    MeterHero(startedAt: session.startedAt, expiry: expiry)
                }

                ParkedMap(session: session)
                    .frame(height: 176)
                    .clipShape(RoundedRectangle(cornerRadius: Theme.radiusCard))
                    .accessibilityElement()
                    .accessibilityLabel(mapAccessibilityLabel(for: session))
                    .accessibilityIdentifier("active-parking-map")

                detailsCard(session)

                if let data = model.photoData(for: session), let image = UIImage(data: data) {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                        .frame(maxWidth: .infinity, minHeight: 180, maxHeight: 240)
                        .clipShape(RoundedRectangle(cornerRadius: Theme.radiusCard))
                        .clipped()
                        .accessibilityLabel("Saved parking photo")
                }

                actions(session)
            }
            .padding()
        }
    }

    private func detailsCard(_ session: ParkingSession) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text(session.locationLabel ?? "Saved parking spot")
                    .font(.title2.bold())
                TimelineView(.periodic(from: .now, by: 1)) { context in
                    Text("Parked for \(ParkNudgeFormatting.duration(context.date.timeIntervalSince(session.startedAt)))")
                        .font(.subheadline.monospacedDigit())
                        .foregroundStyle(.secondary)
                }
            }

            if hasAnyDetail(session) {
                Divider()

                VStack(alignment: .leading, spacing: 9) {
                    if let detail = detailLine(for: session) {
                        Label(detail, systemImage: "building.2")
                    }
                    if let note = session.note {
                        Label(note, systemImage: "note.text")
                    }
                    if let amount = session.paidAmountMinor, let currency = session.currencyCode {
                        Label(
                            ParkNudgeFormatting.money(minorUnits: amount, currencyCode: currency),
                            systemImage: "dollarsign.circle"
                        )
                        .monospacedDigit()
                    }
                    if session.horizontalAccuracy >= 0 {
                        Label("GPS accuracy ±\(Int(session.horizontalAccuracy.rounded())) m", systemImage: "location.circle")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Theme.surfaceRaised, in: RoundedRectangle(cornerRadius: Theme.radiusCard))
    }

    @ViewBuilder
    private func actions(_ session: ParkingSession) -> some View {
        VStack(spacing: 10) {
            Button { model.openDirections() } label: {
                Label("Walking Directions", systemImage: "figure.walk")
                    .font(.headline)
                    .frame(maxWidth: .infinity, minHeight: Theme.primaryControlHeight - 16)
            }
            .buttonStyle(.borderedProminent)
            .tint(Theme.brand)
            .accessibilityIdentifier("walking-directions")

            Button {
                editorContext = ParkingEditorContext(
                    mode: .edit,
                    draft: .editing(session),
                    replacingActive: false,
                    existingPhotoData: model.photoData(for: session)
                )
            } label: {
                Label("Edit or Extend", systemImage: "pencil")
                    .frame(maxWidth: .infinity, minHeight: Theme.minimumHitTarget - 16)
            }
            .buttonStyle(.bordered)
            .tint(Theme.brand)

            Button(role: .destructive) { confirmsFinish = true } label: {
                Label("Finish", systemImage: "checkmark.circle")
                    .frame(maxWidth: .infinity, minHeight: Theme.minimumHitTarget - 16)
            }
            .buttonStyle(.bordered)
            .accessibilityIdentifier("finish-parking")
        }
    }

    private func beginNewParking(replacing: Bool) {
        Task {
            let draft = await model.newParkingDraft()
            editorContext = ParkingEditorContext(
                mode: .new,
                draft: draft,
                replacingActive: replacing,
                existingPhotoData: nil
            )
        }
    }

    private func detailLine(for session: ParkingSession) -> String? {
        [session.floor.map { "Floor \($0)" }, session.section.map { "Section \($0)" }]
            .compactMap { $0 }
            .joined(separator: " · ")
            .nilIfEmpty
    }

    private func hasAnyDetail(_ session: ParkingSession) -> Bool {
        detailLine(for: session) != nil
            || session.note != nil
            || session.paidAmountMinor != nil
            || session.horizontalAccuracy >= 0
    }

    /// The map is decorative and untappable. Left unlabelled it reaches
    /// VoiceOver as an unnamed element, so it names the spot it is showing.
    private func mapAccessibilityLabel(for session: ParkingSession) -> String {
        if let label = session.locationLabel {
            return "Map showing your parked car at \(label)"
        }
        return "Map showing your parked car"
    }
}

private struct EmptyStateBeat: View {
    let symbol: String
    let text: String

    var body: some View {
        Label {
            Text(text)
        } icon: {
            Image(systemName: symbol)
                .foregroundStyle(Theme.brandInk)
        }
        .font(.subheadline)
    }
}

private struct ParkedMap: View {
    let session: ParkingSession

    var body: some View {
        let coordinate = CLLocationCoordinate2D(
            latitude: session.coordinate.latitude,
            longitude: session.coordinate.longitude
        )
        Map(initialPosition: .region(MKCoordinateRegion(
            center: coordinate,
            span: MKCoordinateSpan(latitudeDelta: 0.008, longitudeDelta: 0.008)
        ))) {
            Marker(session.locationLabel ?? "Parked car", systemImage: "car.fill", coordinate: coordinate)
                .tint(Theme.brand)
        }
        .allowsHitTesting(false)
    }
}

/// The countdown, promoted out of the details card and given the three states
/// a meter actually has.
private struct MeterHero: View {
    /// The countdown has to scale with Dynamic Type like everything else, but
    /// left uncapped it swallows the screen at the accessibility sizes — the
    /// map and the actions stop being reachable without a long scroll.
    @ScaledMetric(relativeTo: .title) private var scaledDigitSize: CGFloat = 52
    let startedAt: Date
    let expiry: Date

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            let state = MeterState.at(context.date, expiry: expiry)
            let progress = MeterState.progress(start: startedAt, expiry: expiry, now: context.date)

            VStack(alignment: .leading, spacing: 10) {
                // A fixed HStack with a Spacer collides at accessibility sizes,
                // so the clock time drops below the label when it stops fitting.
                ViewThatFits(in: .horizontal) {
                    HStack(spacing: 8) {
                        headline(state)
                        Spacer(minLength: 8)
                        clock(state)
                    }
                    VStack(alignment: .leading, spacing: 6) {
                        headline(state)
                        clock(state)
                    }
                }

                Text(state.digits)
                    .font(.system(size: digitSize, weight: state.digitWeight, design: .default))
                    .monospacedDigit()
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
                    .foregroundStyle(state.accent)

                ProgressView(value: progress)
                    .progressViewStyle(.linear)
                    .tint(state.accent)
                    .accessibilityHidden(true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(16)
            .background(state.surface, in: RoundedRectangle(cornerRadius: Theme.radiusCard))
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(state.accessibilityDescription(expiry: expiry))
            .accessibilityIdentifier("meter-hero")
        }
    }

    private func headline(_ state: MeterState) -> some View {
        Label {
            Text(state.title)
                .font(.subheadline.weight(.semibold))
        } icon: {
            Image(systemName: state.symbol)
        }
        .foregroundStyle(state.secondaryAccent)
    }

    private func clock(_ state: MeterState) -> some View {
        Text(state.isExpired ? "at \(expiry.formatted(date: .omitted, time: .shortened))"
                             : "until \(expiry.formatted(date: .omitted, time: .shortened))")
            .font(.subheadline.monospacedDigit())
            .foregroundStyle(state.secondaryAccent)
    }

    private var digitSize: CGFloat { min(scaledDigitSize, 76) }
}

private extension String {
    var nilIfEmpty: String? { isEmpty ? nil : self }
}
