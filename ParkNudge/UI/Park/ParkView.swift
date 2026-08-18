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
                if model.activeSession == nil {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button {
                            beginNewParking(replacing: false)
                        } label: {
                            Image(systemName: "plus")
                        }
                        .accessibilityLabel("Save Parking Spot")
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
            Text("Save one active parking spot, add meter time and details, then get walking directions back.")
        } actions: {
            Button {
                beginNewParking(replacing: false)
            } label: {
                Label("Save Parking Spot", systemImage: "location.fill")
                    .font(.headline)
                    .padding(.horizontal, 8)
            }
            .buttonStyle(.borderedProminent)
            .tint(.orange)
            .disabled(model.isBusy)
            .accessibilityIdentifier("save-parking-spot")

            Text("Location is requested only after you tap this button.")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
    }

    private func activeContent(_ session: ParkingSession) -> some View {
        ScrollView {
            VStack(spacing: 18) {
                ParkedMap(session: session)
                    .frame(height: 260)
                    .clipShape(RoundedRectangle(cornerRadius: 22))
                    .accessibilityIdentifier("active-parking-map")

                VStack(alignment: .leading, spacing: 14) {
                    HStack(alignment: .firstTextBaseline) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(session.locationLabel ?? "Saved parking spot")
                                .font(.title2.bold())
                            TimelineView(.periodic(from: .now, by: 1)) { context in
                                Text("Parked for \(ParkNudgeFormatting.duration(context.date.timeIntervalSince(session.startedAt)))")
                                    .font(.subheadline.monospacedDigit())
                                    .foregroundStyle(.secondary)
                            }
                        }
                        Spacer()
                        Image(systemName: "car.fill")
                            .font(.title)
                            .foregroundStyle(.orange)
                    }

                    if let expiry = session.meterExpiresAt {
                        MeterCountdown(expiry: expiry)
                    }

                    if let detail = detailLine(for: session) {
                        Label(detail, systemImage: "building.2")
                    }
                    if let note = session.note {
                        Label(note, systemImage: "note.text")
                    }
                    if let amount = session.paidAmountMinor, let currency = session.currencyCode {
                        Label(ParkNudgeFormatting.money(minorUnits: amount, currencyCode: currency), systemImage: "dollarsign.circle")
                    }
                    if session.horizontalAccuracy >= 0 {
                        Label("GPS accuracy ±\(Int(session.horizontalAccuracy.rounded())) m", systemImage: "location.circle")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding()
                .background(Color(uiColor: .secondarySystemBackground), in: RoundedRectangle(cornerRadius: 22))

                if let data = model.photoData(for: session), let image = UIImage(data: data) {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                        .frame(maxWidth: .infinity, minHeight: 180, maxHeight: 240)
                        .clipShape(RoundedRectangle(cornerRadius: 22))
                        .clipped()
                        .accessibilityLabel("Saved parking photo")
                }

                VStack(spacing: 12) {
                    Button { model.openDirections() } label: {
                        Label("Walking Directions", systemImage: "figure.walk")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.orange)
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
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)

                    Button { confirmsReplacement = true } label: {
                        Label("Park Somewhere Else", systemImage: "arrow.triangle.2.circlepath")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)

                    Button(role: .destructive) { confirmsFinish = true } label: {
                        Label("Finish", systemImage: "checkmark.circle")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .accessibilityIdentifier("finish-parking")
                }
            }
            .padding()
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
                .tint(.orange)
        }
        .allowsHitTesting(false)
    }
}

private struct MeterCountdown: View {
    let expiry: Date

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            let remaining = expiry.timeIntervalSince(context.date)
            HStack {
                Image(systemName: remaining > 0 ? "timer" : "exclamationmark.triangle.fill")
                VStack(alignment: .leading, spacing: 2) {
                    Text(remaining > 0 ? "Meter time remaining" : "Meter expired")
                        .font(.caption)
                    Text(remaining > 0 ? ParkNudgeFormatting.duration(remaining) : "0:00")
                        .font(.title2.bold().monospacedDigit())
                }
                Spacer()
                Text(expiry, style: .time)
                    .font(.subheadline)
            }
            .foregroundStyle(remaining > 0 ? Color.primary : Color.red)
            .padding()
            .background((remaining > 0 ? Color.orange : Color.red).opacity(0.12), in: RoundedRectangle(cornerRadius: 16))
        }
    }
}

private extension String {
    var nilIfEmpty: String? { isEmpty ? nil : self }
}
