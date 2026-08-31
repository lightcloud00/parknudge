# App Store screenshot capture plan

Status: deterministic source and capture harness only. No screenshot is accepted or upload-ready until the governed native job passes and every exported original plus reduction is visually inspected.

## Five-frame iPhone story

1. **Save Where You Parked** — free empty state; location is requested only after the user taps Save Parking Spot.
2. **Add a Photo, Note or Cost** — photo, floor, section, and note are available in the editor; parking-cost records remain visibly gated behind planned Lifetime Pro.
3. **Set a Return Reminder** — an explicitly enabled absolute meter deadline previews only reminder times that have not already passed.
4. **Navigate Back to Your Car** — the active-session screen exposes Walking Directions, which hands the saved coordinate to Apple Maps.
5. **Keep Location Data Private** — Settings states that parking data remains on the iPhone unless the user explicitly shares a CSV export and provides a delete-all control.

## Truth boundaries

- The UI-test run uses a clean in-memory container and one deterministic Union Square Garage sample session. It is sample media, not automatic parking detection, background location, or a real saved car.
- ParkNudge requests When-In-Use location only after the user starts the save flow. It has no account, backend, ads, analytics, background location, or remote push.
- Local reminder delivery still depends on notification permission and system behavior such as Focus. The app does not promise ticket prevention.
- Walking Directions opens Apple Maps; the media must not claim a route, ETA, availability, or navigation outcome.
- Photo and note are free. Parking-cost records and CSV export are planned Lifetime Pro surfaces; fixture visibility is not App Store product configuration or purchase proof.
- The capture does not prove a signed build, physical device, App Store Connect attachment, TestFlight installation, submission, or release.

## Required acceptance

- Exactly five RGB/no-alpha iPhone 6.9-inch originals at 1320x2868.
- One passing UI test, zero failures, exact committed source SHA, and immutable per-file hashes.
- Original-resolution and reduced contact-sheet visual review for cropping, readability, sample-data disclosure, privacy, and claim accuracy.
- No media upload or publication without a separate exact-build and protected-action decision.
