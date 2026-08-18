import SwiftUI

enum LegalDocument: String, Identifiable {
    case privacy = "Privacy"
    case terms = "Terms"

    var id: String { rawValue }
}

struct LegalView: View {
    let document: LegalDocument

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                Text(document.rawValue)
                    .font(.largeTitle.bold())
                if document == .privacy {
                    privacyContent
                } else {
                    termsContent
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()
        }
        .navigationTitle(document.rawValue)
        .navigationBarTitleDisplayMode(.inline)
    }

    private var privacyContent: some View {
        Group {
            Text("ParkNudge keeps parking sessions, notes, costs, reminder metadata, and photos on this iPhone. There is no account, backend, advertising, analytics, or tracking SDK.")
            Text("Location is requested only when you choose to save a parking spot. Camera access is requested only when you choose to take a parking photo. Local notifications are used only for meter reminders you create.")
            Text("CSV exports contain sensitive location history. ParkNudge omits photo bytes and internal photo paths from exports. You decide where an exported file is shared.")
            Text("Deleting a session removes its associated local photo and reminder requests. Delete All removes all saved parking data from the app.")
        }
    }

    private var termsContent: some View {
        Group {
            Text("ParkNudge is a parking memory aid. It does not pay parking fees, verify parking rules, guarantee a legal space, or prevent tickets, towing, or other losses.")
            Text("Meter reminders depend on the date you enter, device settings, notification permission, Focus modes, and iOS delivery. Always follow posted signs and check the meter directly.")
            Text("Lifetime Pro is a one-time, non-consumable in-app purchase tied to the Apple ID used for purchase. Availability and transaction handling are provided by Apple.")
        }
    }
}
