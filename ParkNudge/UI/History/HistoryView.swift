import MapKit
import SwiftUI

struct HistoryView: View {
    @EnvironmentObject private var model: AppModel
    @State private var showExportWarning = false
    @State private var exportItem: ExportItem?

    var body: some View {
        NavigationStack {
            Group {
                if model.completedSessions.isEmpty {
                    ContentUnavailableView(
                        "No Parking History",
                        systemImage: "clock.arrow.circlepath",
                        description: Text("Finished parking sessions will appear here.")
                    )
                } else {
                    List {
                        Section {
                            ForEach(model.visibleHistory) { session in
                                NavigationLink(value: session) {
                                    HistoryRow(session: session)
                                }
                                .swipeActions {
                                    Button("Delete", role: .destructive) {
                                        Task { await model.delete(session) }
                                    }
                                }
                            }
                        } footer: {
                            if !model.entitlement.isPro {
                                Text("Free includes the three newest completed sessions. All older sessions remain stored locally.")
                            }
                        }

                        if model.hiddenHistoryCount > 0 {
                            Section {
                                Button { model.requestAccess(to: .fullHistory) } label: {
                                    HStack {
                                        Label(
                                            "Reveal \(model.hiddenHistoryCount) older \(model.hiddenHistoryCount == 1 ? "session" : "sessions")",
                                            systemImage: "lock.fill"
                                        )
                                        Spacer()
                                        Image(systemName: "chevron.right")
                                            .foregroundStyle(.tertiary)
                                    }
                                }
                                .accessibilityIdentifier("locked-history")
                            }
                        }
                    }
                    .listStyle(.insetGrouped)
                }
            }
            .navigationTitle("History")
            .navigationDestination(for: ParkingSession.self) { session in
                HistoryDetailView(session: session)
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        if model.hasAccess(to: .csvExport) {
                            showExportWarning = true
                        } else {
                            model.requestAccess(to: .csvExport)
                        }
                    } label: {
                        Image(systemName: model.hasAccess(to: .csvExport)
                              ? "square.and.arrow.up"
                              : "lock.fill")
                    }
                    .accessibilityLabel("Export parking history")
                    .disabled(model.completedSessions.isEmpty)
                }
            }
        }
        .confirmationDialog(
            "Export sensitive location history?",
            isPresented: $showExportWarning,
            titleVisibility: .visible
        ) {
            Button("Create CSV Export") {
                if let url = model.makeCSVExport() { exportItem = ExportItem(url: url) }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("The file includes dates, coordinates, labels, notes, meter times, and costs. It does not include photos or internal photo paths.")
        }
        .sheet(item: $exportItem, onDismiss: model.cleanupTemporaryExports) { item in
            ShareSheet(url: item.url, onComplete: {
                exportItem = nil
                model.cleanupTemporaryExports()
            })
        }
    }
}

private struct HistoryRow: View {
    let session: ParkingSession

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "car.circle.fill")
                .font(.title2)
                .foregroundStyle(.orange)
            VStack(alignment: .leading, spacing: 4) {
                Text(session.locationLabel ?? "Parking session")
                    .font(.headline)
                Text(session.endedAt ?? session.updatedAt, format: .dateTime.month(.abbreviated).day().year().hour().minute())
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Text(ParkNudgeFormatting.duration(session.duration))
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
            Spacer()
            if let amount = session.paidAmountMinor, let currency = session.currencyCode {
                Text(ParkNudgeFormatting.money(minorUnits: amount, currencyCode: currency))
                    .font(.subheadline)
            }
        }
        .padding(.vertical, 3)
    }
}

private struct HistoryDetailView: View {
    @EnvironmentObject private var model: AppModel
    @Environment(\.dismiss) private var dismiss
    @State private var confirmDelete = false
    let session: ParkingSession

    var body: some View {
        List {
            Section {
                let coordinate = CLLocationCoordinate2D(
                    latitude: session.coordinate.latitude,
                    longitude: session.coordinate.longitude
                )
                Map(initialPosition: .region(MKCoordinateRegion(
                    center: coordinate,
                    span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
                ))) {
                    Marker(session.locationLabel ?? "Parked car", coordinate: coordinate)
                        .tint(.orange)
                }
                .frame(height: 230)
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .allowsHitTesting(false)
            }

            Section("Session") {
                LabeledContent("Started") { Text(session.startedAt, format: .dateTime) }
                if let ended = session.endedAt {
                    LabeledContent("Finished") { Text(ended, format: .dateTime) }
                }
                LabeledContent("Duration", value: ParkNudgeFormatting.duration(session.duration))
                if session.horizontalAccuracy >= 0 {
                    LabeledContent("GPS accuracy", value: "±\(Int(session.horizontalAccuracy.rounded())) m")
                }
            }

            if session.locationLabel != nil || session.floor != nil || session.section != nil || session.note != nil {
                Section("Details") {
                    if let value = session.locationLabel { LabeledContent("Place", value: value) }
                    if let value = session.floor { LabeledContent("Floor", value: value) }
                    if let value = session.section { LabeledContent("Section", value: value) }
                    if let value = session.note { Text(value) }
                }
            }

            if let expiry = session.meterExpiresAt {
                Section("Meter") { LabeledContent("Expired") { Text(expiry, format: .dateTime) } }
            }

            if let amount = session.paidAmountMinor, let currency = session.currencyCode {
                Section("Cost") {
                    LabeledContent("Paid", value: ParkNudgeFormatting.money(minorUnits: amount, currencyCode: currency))
                }
            }

            if let data = model.photoData(for: session), let image = UIImage(data: data) {
                Section("Photo") {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFit()
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                }
            }

            Section {
                Button("Delete Session", role: .destructive) { confirmDelete = true }
            }
        }
        .navigationTitle(session.locationLabel ?? "Parking Session")
        .navigationBarTitleDisplayMode(.inline)
        .confirmationDialog("Delete this session?", isPresented: $confirmDelete) {
            Button("Delete Session", role: .destructive) {
                Task {
                    await model.delete(session)
                    dismiss()
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Its saved photo and notification requests will also be removed.")
        }
    }
}

private struct ExportItem: Identifiable {
    let id = UUID()
    let url: URL
}
