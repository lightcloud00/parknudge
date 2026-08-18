# ParkNudge

ParkNudge is a privacy-first iPhone parking spot and meter reminder. It saves one active parking location, lets the driver correct the pin, records garage details and one photo, schedules local meter alerts, opens Apple Maps walking directions, and keeps completed history on-device.

The repository contains the native iOS app, tests, product documentation, and a static launch website. It is an MVP source repository—not evidence of physical-device acceptance, App Store availability, a configured in-app purchase, or a deployed domain.

## Product boundary

The complete parking loop is free: one active spot, GPS/manual pin, place search, directions, floor/section/note/photo, meter timer, fixed 15/5/0-minute alerts, and the three newest completed sessions.

Lifetime Pro is a planned one-time, non-subscription purchase with a $9.99 U.S. reference price. StoreKit's localized `displayPrice` is the only price rendered inside the app. Pro adds unlimited visible history, custom reminder presets, parking-cost records, and CSV export. Older history is never deleted when Pro is absent or revoked.

See [MONETIZATION.md](Docs/MONETIZATION.md) and [ROADMAP.md](Docs/ROADMAP.md) for the exact boundary and remaining gates.

## Stack

- Swift 6 with strict concurrency
- SwiftUI and MapKit
- SwiftData with a versioned schema
- Core Location one-shot capture
- UserNotifications local, time-sensitive reminders
- StoreKit 2 verified entitlements
- XcodeGen with iOS 17 deployment target
- No third-party packages, backend, account, ads, analytics, background location, or remote push

## Build and test

Requirements: the current Xcode toolchain, XcodeGen 2.45 or newer, and Python 3 for the dependency-free website checker.

```bash
./scripts/generate-project.sh
./scripts/verify.sh
```

`project.yml` is canonical and `ParkNudge.xcodeproj` is committed for reproducibility. The Debug scheme uses `ParkNudge.storekit`; the Release app excludes that file.

To preview the website locally:

```bash
python3 -m http.server 8080 --directory site
```

Then visit `http://localhost:8080`. The `parknudge.app` canonical URL is a candidate only until the domain is acquired and deployment is verified.

## Repository map

- `ParkNudge/` — application, domain, persistence, platform adapters, UI, privacy manifest, and assets
- `ParkNudgeTests/` — deterministic unit and in-memory SwiftData tests
- `ParkNudgeUITests/` — simulator UI smoke flows
- `site/` — static SEO/AEO-ready launch and support pages
- `Docs/` — product, architecture, naming, monetization, release, and device-acceptance records
- `scripts/` — project generation, verification, and release-content audits

## Release boundaries

The repository does not authorize or claim domain purchase, public deployment, App Store Connect mutation, TestFlight upload, physical-device acceptance, submission, or release. Those remain tracked work with explicit evidence requirements.

Copyright © 2026 Gus Digital Solutions. No license is granted by publication of this source repository.
