# ParkNudge 1.2.1 (8)

Prepared 2026-11-08 from main `6c2d3a2`. Submitted for App Review on 2026-11-10, and approved by Apple. A read-only App Store Connect readback on 2026-11-11 (claudecode-workspace#3660) shows PENDING_DEVELOPER_RELEASE with a MANUAL release. 1.2 (7) is still the live version (public US lookup, 2026-11-11). Releasing 1.2.1 (8) needs Gus's own words naming ParkNudge 1.2.1 (8).

Not in build 8: everything merged after `6c2d3a2`, including the Rate ParkNudge row (#87) and the open entitlement-ordering follow-up (#89). They ship in the next version.

## Changes since 1.2 (7)

- **A paying customer is no longer shown as free when the App Store is slow (#79, PR #80, `9cdba94`).** Before this fix, the launch entitlement lookup gave up after 15 seconds and returned free, so a Lifetime Pro owner on a slow or offline connection saw Pro locks and the buy button. Now:
  - a lookup that misses its deadline, or fails, reads as unavailable, not free;
  - while the answer is pending or unavailable, the paywall shows a verifying message and Check Again, not the purchase button, and Restore Purchases stays;
  - opening a Pro feature while the answer is unavailable asks the store again;
  - an unavailable answer never takes Pro away from a verified owner, and a parking cost being saved is kept.
- Repository only, no app change: `CLAUDE.md` imports `AGENTS.md` (#77).

Release mechanics: `MARKETING_VERSION` 1.2 to 1.2.1 and `CURRENT_PROJECT_VERSION` 7 to 8, in `project.yml` and the generated `ParkNudge.xcodeproj/project.pbxproj` (app target, Debug and Release). The product id, price, and paywall copy did not change.

## What's New (App Store, en-US)

```
Fixes an issue where a slow or offline connection could make ParkNudge show Lifetime Pro as locked. If the App Store can't confirm your purchase yet, ParkNudge now says so and lets you check again, and Restore Purchases is still there.
```

## App Review notes addition

```
1.2.1 fixes how Lifetime Pro status is checked. If the App Store does not answer within 15 seconds, the app no longer treats the user as free. The paywall shows "The App Store could not confirm your purchase right now. If you already bought Lifetime Pro, it is not lost." with a Check Again button instead of the purchase button. Restore Purchases stays available. Parking, directions, notes, photos, and the standard meter reminders stay free and work whatever the purchase state.
```

## Before submission (the Mac)

1. Read back App Store Connect: confirm build 8 is unused. 1.2 (7) has been live since 2026-10-30 (public App Store lookup, read 2026-11-08), so 1.2.1 is a normal new version; nothing has to be rejected first.
2. Run `./scripts/verify.sh` on the exact head. It regenerates the project (`git status` must stay clean afterwards), runs the unit and UI tests, builds Release, and runs `scripts/audit-release.sh`, which fails if the Release app contains `ParkNudge.storekit`.
3. Archive the same head and confirm the archived `ParkNudge.app` has version 1.2.1 (8) and no `.storekit` file.
4. Sandbox, on TestFlight 1.2.1 (8), for #7: buy, cancel, restore on a clean install, and, with the network off at launch, an owner sees the verifying state, not the buy button.
