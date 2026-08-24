import MapKit
import PhotosUI
import SwiftUI
import UIKit

enum ParkingEditorMode {
    case new
    case edit
}

struct ParkingEditorContext: Identifiable {
    let id = UUID()
    let mode: ParkingEditorMode
    let draft: ParkingDraft
    let replacingActive: Bool
    let existingPhotoData: Data?
}

struct ParkingEditorView: View {
    @EnvironmentObject private var model: AppModel
    @Environment(\.dismiss) private var dismiss
    @StateObject private var searchModel = PlaceSearchModel()
    @State private var draft: ParkingDraft
    @State private var searchText = ""
    @State private var meterEnabled: Bool
    @State private var costText: String
    @State private var validationMessage: String?
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var isCameraPresented = false
    @State private var cameraPhotoData: Data?
    @State private var cameraUnavailable = false
    @State private var mapPosition: MapCameraPosition

    private let context: ParkingEditorContext
    /// `ReminderPlanner.plans` needs a session id to build notification
    /// identifiers. The preview only reads the fire dates, so any stable id
    /// does.
    private let draftReminderPreviewID = UUID()

    init(context: ParkingEditorContext) {
        self.context = context
        _draft = State(initialValue: context.draft)
        _meterEnabled = State(initialValue: context.draft.meterExpiresAt != nil)
        _costText = State(initialValue: ParkNudgeFormatting.decimalMoneyText(
            minorUnits: context.draft.paidAmountMinor,
            currencyCode: context.draft.currencyCode
        ))
        let center = CLLocationCoordinate2D(
            latitude: context.draft.coordinate.latitude,
            longitude: context.draft.coordinate.longitude
        )
        _mapPosition = State(initialValue: .region(MKCoordinateRegion(
            center: center,
            span: MKCoordinateSpan(latitudeDelta: 0.012, longitudeDelta: 0.012)
        )))
    }

    var body: some View {
        NavigationStack {
            Form {
                mapSection
                searchSection
                detailsSection
                meterSection
                photoSection
                costSection
            }
            .navigationTitle(context.mode == .new ? "Save Parking Spot" : "Edit Parking Spot")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .fontWeight(.semibold)
                        .disabled(model.isBusy)
                        .accessibilityIdentifier("confirm-save-parking")
                }
            }
            .interactiveDismissDisabled(model.isBusy)
            .sheet(isPresented: $isCameraPresented) {
                CameraPicker(imageData: $cameraPhotoData)
                    .ignoresSafeArea()
            }
            .onChange(of: cameraPhotoData) { _, data in
                if let data {
                    draft.photoData = data
                    draft.removePhoto = false
                }
            }
            .onChange(of: selectedPhoto) { _, item in
                guard let item else { return }
                Task {
                    if let data = try? await item.loadTransferable(type: Data.self) {
                        draft.photoData = data
                        draft.removePhoto = false
                    }
                }
            }
            .alert("Check Parking Details", isPresented: Binding(
                get: { validationMessage != nil },
                set: { if !$0 { validationMessage = nil } }
            )) {
                Button("OK") { validationMessage = nil }
            } message: {
                Text(validationMessage ?? "")
            }
            .alert("Camera Unavailable", isPresented: $cameraUnavailable) {
                Button("OK", role: .cancel) {}
            } message: {
                Text("You can choose a photo from the photo picker instead.")
            }
            .alert("Place Search", isPresented: Binding(
                get: { searchModel.errorMessage != nil },
                set: { if !$0 { searchModel.errorMessage = nil } }
            )) {
                Button("OK") { searchModel.errorMessage = nil }
            } message: {
                Text(searchModel.errorMessage ?? "")
            }
        }
    }

    private var mapSection: some View {
        Section {
            MapReader { proxy in
                Map(position: $mapPosition) {
                    Annotation("Park here", coordinate: mapCoordinate) {
                        Image(systemName: "car.circle.fill")
                            .font(.system(size: 38))
                            .symbolRenderingMode(.palette)
                            .foregroundStyle(.white, Theme.brand)
                            .shadow(radius: 4)
                    }
                }
                .mapStyle(.standard(elevation: .realistic))
                .mapControls { MapCompass(); MapScaleView() }
                .frame(height: 260)
                .clipShape(RoundedRectangle(cornerRadius: Theme.radiusTile))
                .onTapGesture { point in
                    guard let coordinate = proxy.convert(point, from: .local) else { return }
                    setCoordinate(coordinate, source: .manualPin)
                }
                .accessibilityIdentifier("parking-pin-map")
            }

            Label("Tap the map to correct the pin.", systemImage: "hand.tap")
                .font(.footnote)
                .foregroundStyle(.secondary)

            if draft.horizontalAccuracy >= 0 {
                LabeledContent("Captured accuracy", value: "±\(Int(draft.horizontalAccuracy.rounded())) m")
            } else {
                LabeledContent("Location source", value: "Manual pin")
                    .accessibilityIdentifier("manual-pin-source")
            }
        } header: {
            Text("Location")
        }
    }

    private var searchSection: some View {
        Section("Find a place") {
            HStack {
                TextField("Garage, address, or landmark", text: $searchText)
                    .textInputAutocapitalization(.words)
                    .submitLabel(.search)
                    .onSubmit { runSearch() }
                    .accessibilityIdentifier("place-search-field")
                Button { runSearch() } label: {
                    if searchModel.isSearching {
                        ProgressView()
                    } else {
                        Image(systemName: "magnifyingglass")
                    }
                }
                .disabled(searchModel.isSearching || searchText.trimmingCharacters(in: .whitespaces).isEmpty)
                .accessibilityLabel("Search places")
            }

            ForEach(searchModel.results) { result in
                Button {
                    draft.locationLabel = result.name
                    setCoordinate(
                        CLLocationCoordinate2D(
                            latitude: result.coordinate.latitude,
                            longitude: result.coordinate.longitude
                        ),
                        source: .searchedPlace
                    )
                    searchModel.clearResults()
                } label: {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(result.name).foregroundStyle(.primary)
                        if !result.detail.isEmpty {
                            Text(result.detail)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(2)
                        }
                    }
                }
            }
        }
    }

    private var detailsSection: some View {
        Section("Helpful details") {
            TextField("Place label (optional)", text: $draft.locationLabel)
            TextField("Floor (optional)", text: $draft.floor)
            TextField("Section (optional)", text: $draft.section)
            TextField("Note (optional)", text: $draft.note, axis: .vertical)
                .lineLimit(2...5)
        }
    }

    private var meterSection: some View {
        Section {
            Toggle("Meter timer", isOn: $meterEnabled)
                .onChange(of: meterEnabled) { _, enabled in
                    draft.meterExpiresAt = enabled
                        ? max(draft.meterExpiresAt ?? Date().addingTimeInterval(3_600), Date().addingTimeInterval(60))
                        : nil
                }
                .accessibilityIdentifier("meter-toggle")
            if meterEnabled {
                DatePicker(
                    "Expires",
                    selection: Binding(
                        get: { draft.meterExpiresAt ?? Date().addingTimeInterval(3_600) },
                        set: { draft.meterExpiresAt = $0 }
                    ),
                    in: Date().addingTimeInterval(60)...,
                    displayedComponents: [.date, .hourAndMinute]
                )
                reminderPreview
            }
        } header: {
            Text("Meter")
        }
    }

    @ViewBuilder
    private var photoSection: some View {
        let hasPhoto = selectedUIImage != nil
        Section("One parking photo") {
            if let image = selectedUIImage {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .frame(maxHeight: 220)
                    .clipShape(RoundedRectangle(cornerRadius: Theme.radiusTile))
                    .accessibilityLabel("Selected parking photo")
            }

            PhotosPicker(selection: $selectedPhoto, matching: .images) {
                Label(hasPhoto ? "Replace Photo" : "Choose Photo", systemImage: "photo")
            }

            Button {
                if UIImagePickerController.isSourceTypeAvailable(.camera) {
                    isCameraPresented = true
                } else {
                    cameraUnavailable = true
                }
            } label: {
                Label("Take Photo", systemImage: "camera")
            }

            if selectedUIImage != nil {
                Button("Remove Photo", role: .destructive) {
                    draft.photoData = nil
                    draft.removePhoto = true
                    selectedPhoto = nil
                    cameraPhotoData = nil
                }
            }
        }
    }

    @ViewBuilder
    private var costSection: some View {
        Section {
            if model.hasAccess(to: .parkingCosts) {
                HStack {
                    TextField("0.00", text: $costText)
                        .keyboardType(.decimalPad)
                        .accessibilityLabel("Parking cost")
                    Picker("Currency", selection: $draft.currencyCode) {
                        ForEach(["USD", "CAD", "EUR", "GBP", "AUD"], id: \.self) { code in
                            Text(code).tag(code)
                        }
                    }
                    .labelsHidden()
                }
            } else {
                Button { model.requestAccess(to: .parkingCosts) } label: {
                    Label("Add a parking cost with Pro", systemImage: "lock.fill")
                }
            }
        } header: {
            Text("Parking cost")
        } footer: {
            Text("Cost records stay on this iPhone and are included in Pro CSV exports.")
        }
    }

    /// The reminders this meter would really schedule, at real clock times.
    ///
    /// The previous copy described the free offsets in prose, which was
    /// silently wrong whenever a warning time had already passed —
    /// `ReminderPlanner.plans` drops those, so a meter set for eight minutes
    /// from now schedules one reminder, not three. Showing the planner's own
    /// output cannot drift from what gets scheduled.
    @ViewBuilder
    private var reminderPreview: some View {
        let plans = ReminderPlanner.plans(
            sessionID: draftReminderPreviewID,
            expiry: draft.meterExpiresAt ?? Date(),
            offsets: model.reminderOffsets,
            now: Date()
        )

        if draft.meterExpiresAt == nil {
            EmptyView()
        } else if plans.isEmpty {
            Label(
                "No reminders — every warning time is already in the past.",
                systemImage: "bell.slash"
            )
            .font(.footnote)
            .foregroundStyle(Theme.brandInk)
        } else {
            Label {
                Text("You'll be nudged at \(Self.clockList(plans.map(\.fireDate))).")
            } icon: {
                Image(systemName: "bell.badge")
            }
            .font(.footnote)
            .foregroundStyle(.secondary)
        }
    }

    private static func clockList(_ dates: [Date]) -> String {
        let times = dates.map { $0.formatted(date: .omitted, time: .shortened) }
        guard times.count > 1 else { return times.first ?? "" }
        return times.dropLast().joined(separator: ", ") + " and " + (times.last ?? "")
    }

    private var mapCoordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(
            latitude: draft.coordinate.latitude,
            longitude: draft.coordinate.longitude
        )
    }

    private var selectedUIImage: UIImage? {
        if let data = draft.photoData { return UIImage(data: data) }
        if !draft.removePhoto, let data = context.existingPhotoData { return UIImage(data: data) }
        return nil
    }

    private func runSearch() {
        Task { await searchModel.search(query: searchText, near: draft.coordinate) }
    }

    private func setCoordinate(_ coordinate: CLLocationCoordinate2D, source: ParkingSource) {
        draft.coordinate = GeoCoordinate(latitude: coordinate.latitude, longitude: coordinate.longitude)
        draft.horizontalAccuracy = -1
        draft.source = source
        mapPosition = .region(MKCoordinateRegion(
            center: coordinate,
            span: MKCoordinateSpan(latitudeDelta: 0.012, longitudeDelta: 0.012)
        ))
    }

    private func save() {
        let trimmedCost = costText.trimmingCharacters(in: .whitespacesAndNewlines)
        if model.hasAccess(to: .parkingCosts), !trimmedCost.isEmpty {
            guard let amount = MoneyParser.minorUnits(
                from: trimmedCost,
                currencyCode: draft.currencyCode
            ) else {
                validationMessage = "Enter a valid non-negative parking cost using your locale's decimal separator."
                return
            }
            draft.paidAmountMinor = amount
        } else if model.hasAccess(to: .parkingCosts) {
            draft.paidAmountMinor = nil
        }

        if meterEnabled, let expiry = draft.meterExpiresAt, expiry <= Date() {
            validationMessage = "Choose a meter expiration time in the future."
            return
        }

        Task {
            let saved: Bool
            switch context.mode {
            case .new:
                saved = await model.saveNew(draft: draft, replacingActive: context.replacingActive)
            case .edit:
                saved = await model.updateActive(draft: draft)
            }
            if saved { dismiss() }
        }
    }
}

private struct CameraPicker: UIViewControllerRepresentable {
    @Environment(\.dismiss) private var dismiss
    @Binding var imageData: Data?

    func makeCoordinator() -> Coordinator { Coordinator(parent: self) }

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    final class Coordinator: NSObject, UINavigationControllerDelegate, UIImagePickerControllerDelegate {
        private let parent: CameraPicker
        init(parent: CameraPicker) { self.parent = parent }

        func imagePickerController(
            _ picker: UIImagePickerController,
            didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]
        ) {
            if let image = info[.originalImage] as? UIImage {
                parent.imageData = image.jpegData(compressionQuality: 0.9)
            }
            parent.dismiss()
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.dismiss()
        }
    }
}
