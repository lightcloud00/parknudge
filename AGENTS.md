# ParkNudge repository instructions

## Product

ParkNudge is a native iPhone utility for saving a parked-car location, remembering a meter deadline, and navigating back. The app is local-only: no account, backend, ads, analytics, background location, or remote push.

## Engineering

- Deploy to iOS 17+ and build with the current installed Xcode SDK.
- Use Swift 6, SwiftUI, SwiftData, Core Location, MapKit, UserNotifications, PhotosUI, and StoreKit 2.
- `project.yml` is canonical. Regenerate `ParkNudge.xcodeproj` after project-shape changes and verify a second generation produces no diff.
- Keep Apple framework adapters behind small protocols where this improves deterministic testing.
- Store absolute dates for meter deadlines. Never persist a decrementing countdown.
- Request When-In-Use location only after the user asks to save a spot. Never add background or Always location to the MVP.
- Do not add a third-party dependency without an explicit product decision and privacy review.
- Never treat cached preferences as purchase authority; only verified StoreKit transactions unlock Pro.

## UI

- Prefer native `NavigationStack`, `TabView`, `Form`, `List`, `Map`, sheets, alerts, and SF Symbols.
- Support VoiceOver, Dynamic Type, Reduce Motion, light appearance, and dark appearance.
- Avoid decorative gradients, glass cards, emoji icons, fake metrics, fabricated testimonials, and forced first-launch paywalls.

## Completion

Run `./scripts/verify.sh` before claiming local completion. Physical-device, App Store Connect, TestFlight, domain, deployment, and release status remain separate evidence gates.
