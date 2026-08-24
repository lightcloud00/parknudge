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
                                    HistoryRow(session: session, thumbnail: model.thumbnail(for: session))
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
                                    HStack(spacing: 12) {
                                        Image(systemName: "lock.fill")
                                            .foregroundStyle(Theme.brandInk)
                                        VStack(alignment: .leading, spacing: 1) {
                                            Text("Reveal \(model.hiddenHistoryCount) older \(model.hiddenHistoryCount == 1 ? "session" : "sessions")")
                                            Text("Included in Lifetime Pro")
                                                .font(.caption)
                                                .foregroundStyle(.secondary)
                                        }
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
    let thumbnail: UIImage?

    var body: some View {
        HStack(spacing: 12) {
            leading
                .frame(width: 52, height: 52)
                .clipShape(RoundedRectangle(cornerRadius: Theme.radiusInline))

            VStack(alignment: .leading, spacing: 4) {
                Text(session.locationLabel ?? "Parking session")
                    .font(.headline)
                Text(session.endedAt ?? session.updatedAt, format: .dateTime.month(.abbreviated).day().year().hour().minute())
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                // Duration, cost and "the meter ran out" used to be spread
                // between a caption line and a trailing column that collided
                // with the title at accessibility sizes. As wrapping chips they
                // reflow instead.
                HistoryChips(session: session)
            }
        }
        .padding(.vertical, 3)
    }

    @ViewBuilder
    private var leading: some View {
        if let thumbnail {
            Image(uiImage: thumbnail)
                .resizable()
                .scaledToFill()
                .accessibilityHidden(true)
        } else {
            ZStack {
                Theme.surfaceRaised
                Image(systemName: "car.fill")
                    .font(.title3)
                    .foregroundStyle(.tertiary)
            }
            .accessibilityHidden(true)
        }
    }
}

private struct HistoryChips: View {
    let session: ParkingSession

    /// A meter that was still ticking when the session ended did its job; one
    /// the driver came back to late is worth flagging on the row.
    private var overranMeter: Bool {
        guard let expiry = session.meterExpiresAt, let ended = session.endedAt else { return false }
        return ended > expiry
    }

    var body: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 6) { chips }
            VStack(alignment: .leading, spacing: 4) { chips }
        }
    }

    @ViewBuilder
    private var chips: some View {
        Chip(
            text: ParkNudgeFormatting.duration(session.duration),
            foreground: .secondary,
            background: Theme.surfaceRaised
        )
        .accessibilityLabel("Parked for \(ParkNudgeFormatting.duration(session.duration))")

        if let amount = session.paidAmountMinor, let currency = session.currencyCode {
            Chip(
                text: ParkNudgeFormatting.money(minorUnits: amount, currencyCode: currency),
                foreground: Theme.brandInk,
                background: Color("MeterWarnSurface", bundle: .main)
            )
        }

        if overranMeter {
            Chip(
                text: "meter ran out",
                symbol: "exclamationmark.triangle.fill",
                foreground: Color("MeterAlertInk", bundle: .main),
                background: Color("MeterAlertSurface", bundle: .main)
            )
        }
    }
}

private struct Chip: View {
    let text: String
    var symbol: String?
    let foreground: Color
    let background: Color

    var body: some View {
        Label {
            Text(text)
        } icon: {
            if let symbol { Image(systemName: symbol) }
        }
        .font(.caption.weight(.semibold).monospacedDigit())
        .foregroundStyle(foreground)
        .padding(.horizontal, 6)
        .padding(.vertical, 2)
        .background(background, in: RoundedRectangle(cornerRadius: 5))
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
                .clipShape(RoundedRectangle(cornerRadius: Theme.radiusCard))
                .allowsHitTesting(false)
                .accessibilityElement()
                .accessibilityLabel(
                    session.locationLabel.map { "Map showing this parking spot at \($0)" }
                        ?? "Map showing this parking spot"
                )
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
                        .clipShape(RoundedRectangle(cornerRadius: Theme.radiusTile))
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
