# Paywall matrix — ParkNudge

Issues: lightcloud00/claudecode-workspace#2806 (paywall test kit), lightcloud00/claudecode-workspace#976 (Sandbox commerce scoreboard), parknudge#79 / PR #80 (slow lookup no longer shows a payer as free). No separate commerce issue for the app was found in the repo.
Source commit: 6c2d3a2 on main ("chore(release): ParkNudge 1.2.1 (8), the stalled-lookup fix (#79) (#84)", which follows #80). Date: 2026-11-08. Sitting target: ParkNudge 1.2.1 (8).
Row ids I-01..I-27 were reconstructed from #2806 because the original list (a Mac-local file, section 7 of the paywall-superwall research note) is not available in this container. Mac owner: please reconcile the numbering against the original before the sitting.

Physical-device checks that are not paywall-specific live in [DEVICE-ACCEPTANCE.md](../DEVICE-ACCEPTANCE.md) (see its "StoreKit Sandbox" section); this file does not duplicate them.


> **TestFlight account note (corrected 2026-11-08).** Apple's App Store Connect Help page "Testing subscriptions and in-app purchases in TestFlight" says TestFlight builds run in the sandbox environment, and for apps in your own developer account you can use a Sandbox Apple Account: sign out of the production Apple Account under Settings > Media & Purchases, then sign in to the Sandbox tester under Settings > Developer. Do that before every TF row. It keeps the exact TestFlight build, never uses a personal Apple ID (lightcloud00/claudecode-workspace#976), and gives sandbox renewal speed (default: 1 week renews every 3 minutes, 1 month every 5 minutes, 1 year every hour, up to 12 renewals). Without a Sandbox account, TestFlight renews subscriptions once a day, up to 6 times a week. A tester's purchase history can be cleared in App Store Connect (Users and Access > Sandbox > Clear Purchase History), or use a fresh tester per block. Confirm the purchase sheet shows [Environment: Sandbox] and the tester account. An earlier version of this note wrongly said the Sandbox account works only for Xcode builds.

## What this proves and what it does not

- SK rows (Xcode StoreKit configuration in the simulator) prove the app's own purchase, restore and entitlement logic against a local fake store. They do not prove Apple servers, App Store Connect product state, Sandbox behaviour, RevenueCat, Superwall or any server ledger.
- ParkNudge has no RevenueCat, no Superwall and no backend (AGENTS.md: local-only, StoreKit 2 only), so there is no provider or server ledger to check. Row I-25 is therefore n/a.
- The XCUITests that exist run with `-ui-testing`, which swaps in a stub purchase provider (`UITestPurchaseProvider` in `ParkNudge/Application/AppEnvironment.swift`). They never touch StoreKit, except `testAppReviewLifetimePaywallScreenshot`, which omits `-ui-testing`.
- The unit tests in `ParkNudgeTests/AppModelTests.swift` use a fake `PurchaseProviding` from `TestFixtures.swift`. No file in the repo uses `SKTestSession` or `StoreKitTest`. No row is automated against a real or simulated StoreKit session.
- Env codes: SK = StoreKit configuration file in the simulator. SB = Sandbox tester account on a device with a dev/Xcode build. TF = TestFlight build on Gus's iPhone, signed in to the Sandbox tester under Settings > Developer (see the TestFlight account note) (subscription renewal speed is moot here, no subscriptions). PR = a second physical device. Never a personal Apple ID or real money.

## Products

| Source | Product id | Type | Price | Period | Intro offer | Subscription group |
|---|---|---|---|---|---|---|
| `ParkNudge/Resources/ParkNudge.storekit` | com.gusdigitalsolutions.parknudge.pro.lifetime | NonConsumable | 9.99 (en_US, storefront USA) | none | none | none (`subscriptionGroups` is empty) |
| Code constant `StoreKitPurchaseService.productIdentifier` (`ParkNudge/Platform/PurchaseService.swift`) | com.gusdigitalsolutions.parknudge.pro.lifetime | non-consumable (Docs/MONETIZATION.md line 5; AGENTS.md does not state the type) | from StoreKit `displayPrice` at runtime | none | none | none |
| Live App Store Connect (from #976 10-26 refresh; unverifiable from this clone and not re-checked; confirm in ASC and the issues before the sitting) | Lifetime | non-consumable | $9.99, APPROVED | n/a | n/a | n/a. Live app version 1.1 (6). |

Drift check:
- Product id: .storekit and code constant match. The ASC product id was not given in the #976 note, so confirm it on the device by the product loading in Sandbox.
- Price: .storekit 9.99 and ASC $9.99 match. The app never hardcodes a price; the paywall shows the StoreKit `displayPrice`.
- Display name: .storekit "ParkNudge Lifetime Pro". The paywall title is the literal string "ParkNudge Lifetime Pro", not read from StoreKit. The ASC display name was not provided.
- Version: `project.yml` and `ParkNudge.xcodeproj/project.pbxproj` are at MARKETING_VERSION 1.2.1, CURRENT_PROJECT_VERSION 8 on main 6c2d3a2. The live App Store version is 1.2 (7), since 2026-10-30; 1.2.1 (8) is approved and waiting for a manual release (2026-11-11 readback, claudecode-workspace#3660). Record the real version and build on every receipt.
- The .storekit `appPolicies` EULA and policy URL are empty (local config only; the in-app Terms and Privacy come from `LegalView.swift`).
- The paywall states "No subscription, no trial, no account." and the .storekit has no subscriptions or offers, so no drift.

## How to run SK rows

1. Open `ParkNudge.xcodeproj`, scheme `ParkNudge`, an iOS 17+ simulator.
2. Edit Scheme > Run > Options > StoreKit Configuration = `ParkNudge/Resources/ParkNudge.storekit`. `project.yml` already sets this for the Run action, and the generated scheme also references it for the Test action (checked by `scripts/check_project_source_truth.sh`). Release builds exclude the file (`scripts/audit-release.sh`), so SK rows need a Debug build.
3. Run (not Test) the app without `-ui-testing`. With `-ui-testing` the stub provider replaces StoreKit.
4. Use the Xcode Debug > StoreKit menu (Manage Transactions window) to refund, revoke, approve or decline Ask to Buy, and delete transactions. The menu item names for failing and interrupting purchases (the failure setting is stored as `_failTransactionsEnabled` in the .storekit, currently false) are Xcode UI strings that cannot be verified from this clone: confirm the exact labels in Xcode's Debug > StoreKit menu before the sitting.
5. There is no `.xctestplan` in the repo.

Existing automated coverage (fake provider, not StoreKit unless noted):

| Row | Test | File |
|---|---|---|
| I-04 | `testVerifiedPurchaseUnlocksAndRevocationLocksOnlyProExtras`, `testCostOfferOpensOverTheEditorAndPurchaseReturnsToIt` (UI stub) | `ParkNudgeTests/AppModelTests.swift`, `ParkNudgeUITests/ParkNudgeUITests.swift` |
| I-05, I-06, I-10 | `testCancelledPendingAndUnverifiedPurchaseKeepProExtrasLocked` (the `.purchased` case there is not an unverified transaction; real verification is in `PurchaseService.swift` and unautomated) | `ParkNudgeTests/AppModelTests.swift` |
| I-06 | `testPendingApprovalDismissesTheOfferAfterVerifiedUpdate`, `testLaterApprovalDoesNotReopenAClosedOffer` | `ParkNudgeTests/AppModelTests.swift` |
| I-02 | `testUnavailableEntitlementHidesThePurchaseUntilTheStoreAnswers`, `testOpeningTheOfferWhileUnavailableAsksTheStoreAgain`, `testSavingWhileTheStoreIsUnreachableKeepsTheParkingCost`, deadline tests (`withStoreDeadline`, `resolveEntitlement`), `scripts/test_paywall_entitlement_gate.py` (source-pins the paywall's verifying branch) | `ParkNudgeTests/AppModelTests.swift`, `scripts/` |
| I-18 | `testVerifiedPurchaseUnlocksAndRevocationLocksOnlyProExtras` | `ParkNudgeTests/AppModelTests.swift` |
| I-21 | `testRestoreWithNothingToRestoreSaysSoAndKeepsTheOfferOpen` | `ParkNudgeTests/AppModelTests.swift` |
| I-13 (logic only) | `testRestoreFromTheOfferOverTheEditorLeavesTheEditorWithoutAnAlert`, `testRestoreFromSettingsConfirmsWithAnAlert`, `testFailedRestoreReportsTheStoreAndKeepsParking`, `testRestoreThatCannotReachTheStoreSaysSo` | `ParkNudgeTests/AppModelTests.swift` |
| I-03 (screenshot only) | `testAppReviewLifetimePaywallScreenshot` (real StoreKit-backed, captures screenshots, asserts the price and Buy button exist) | `ParkNudgeUITests/ParkNudgeUITests.swift` |
| I-01 | `testParkingStaysFreeAfterTheFirstPark`, `testParkingIsFreeAndUnlimitedWithoutPro` | `ParkNudgeUITests/ParkNudgeUITests.swift`, `ParkNudgeTests/AppModelTests.swift` |

These are logic tests with a stub, so every matrix Status below stays "not run". No receipt for any row exists in the repo (searched Docs/ and the root docs).

## Where the paywall is reached (real labels)

- Settings tab: tab bar "Settings" > section "ParkNudge Pro" > row "Lifetime Pro" with subtitle "One-time purchase" (id `settings-lifetime-pro`). Also "Restore Purchases" in the same section. Footer: "One-time purchase, no subscription. Parking, directions, notes, photos, and standard meter reminders stay free."
- Settings tab, reminders section: "Customize with Pro" (free reminders show "Free reminders" = "15 / 5 / 0 min").
- History tab: "Reveal N older session(s)" ("Included in Lifetime Pro"; id `locked-history`; needs more than 3 finished sessions) and the lock toolbar button "Export parking history" (needs at least one finished session).
- Park tab: tap the "+" toolbar button (label "Save Parking Spot", or the "Save Parking Spot" button in the empty state, id `save-parking-spot`), the editor "Save Parking Spot" opens; scroll to the "Parking cost" section and tap "Add a parking cost with Pro" (id `parking-cost-pro`).
- First-launch introduction last page "You’re all set": "See Lifetime Pro" (or "Maybe Later").
- Paywall contents: title "ParkNudge Lifetime Pro", price (id `paywall-price`) then "once", "No subscription, no trial, no account.", comparison table ("What you get", Free, Pro), "Parking stays free. Closing this screen keeps your saved spot, directions, and data.", button "Unlock Lifetime Pro" (id `purchase-lifetime-pro`), "Restore Purchases", "Retry App Store price" (only when the product failed to load), terms text (id `paywall-purchase-terms`) "One non-consumable purchase charged to your Apple ID at confirmation. It does not renew, and there is no subscription, trial, or account. The price above is the localized App Store price for your storefront.", "Privacy", "Terms", and the close button "Close" (xmark, id `close-paywall`). When a feature triggered it, a banner reads "Unlock <feature title lowercased>" (for example "Unlock parking cost records").
- Unlocked signals: Settings shows "Lifetime Pro unlocked" (with a seal icon) in place of the "Lifetime Pro" row; the parking editor shows the "Parking cost" text field (id `parking-cost-field`, placeholder "0.00") instead of "Add a parking cost with Pro"; History shows all sessions.
- Alerts use the title "ParkNudge" with an "OK" button.

## Matrix

Status is "not run" for every applicable row; no receipts are in the repo. Prerequisite for most rows: a Debug build, the tester signed in only where the Env says SB/TF/PR. For the history-locked row, finish at least 4 parking sessions first ("Save Parking Spot" > "Save" > "Finish" > "Finish Parking").

| Row | Scenario | Env | Exact steps | Expected result | Evidence to capture | Status |
|---|---|---|---|---|---|---|
| I-01 | Clean install, unentitled: free core works before any product lookup | SK, TF | Delete app, install. Skip the introduction ("Skip" top right, id `onboarding-skip`; not offered on every step, otherwise "Maybe Later" on the last page). Park tab: "+" ("Save Parking Spot") > "Save" > "Walking Directions" > "Finish" > "Finish Parking". Repeat once. | Saves, directions and finish work with no paywall and no purchase prompt. Second park also free. Standard reminders 15/5/0. | Screen recording or screenshots of both parks and no paywall. | not run |
| I-02 | Product lookup fails: free core works, recoverable error, no unlock | SK | Run with the StoreKit config removed from the scheme (or Airplane Mode on a device build). Settings > "Lifetime Pro". | Price shows "——"; "Unlock Lifetime Pro" is disabled; "Retry App Store price" appears. Tapping it while still failing shows an alert "The App Store price is still unavailable. Your saved spot and directions remain available." Free parking still works. If the entitlement lookup itself stalls or fails (15 s deadline) the paywall shows "The App Store could not confirm your purchase right now. If you already bought Lifetime Pro, it is not lost." with "Check Again" and no buy button (#79; 1.2.1 target). While checking: "Checking your Lifetime Pro purchase with the App Store." | Screenshot of paywall in each state; the alert text. | not run |
| I-03 | Paywall shows right product, price, terms, Restore, Terms/Privacy | SK, SB | Settings > "Lifetime Pro". | Title "ParkNudge Lifetime Pro", price $9.99 then "once", "No subscription, no trial, no account.", terms text above, buttons "Unlock Lifetime Pro", "Restore Purchases", "Privacy", "Terms" (each opens a sheet with "Done"). No trial or period text (non-consumable). | Full-height screenshots (top and scrolled). | not run (a screenshot UI test exists: `testAppReviewLifetimePaywallScreenshot`, no receipt) |
| I-04 | Successful purchase unlocks without relaunch | SK, SB, TF | Settings > "Lifetime Pro" > "Unlock Lifetime Pro" > confirm the system sheet (Sandbox sign-in if asked). If the paywall shows "Checking your Lifetime Pro purchase with the App Store." or "Check Again" instead of the buy button, the store has not answered: tap "Check Again" first. | Paywall closes; alert "Lifetime Pro is unlocked." > "OK"; Settings shows "Lifetime Pro unlocked". Opened from the cost offer or the CSV lock, no alert: the editor shows the cost field / the export continues. | Screenshots before and after; transaction id last 6. | not run |
| I-05 | User cancels the purchase sheet | SK, SB | Tap "Unlock Lifetime Pro", dismiss the system sheet. | Paywall stays open, button returns to idle (spinner gone), no alert, still locked. | Screenshot after cancel. | not run |
| I-06 | Pending / Ask to Buy | SK (Manage Transactions window; label unverified), SB | Purchase with an Ask to Buy tester. Later approve. | Alert "Your purchase is pending approval. Pro unlocks after verification. Your saved spot remains available." Stays locked. After approval (app running) the open paywall closes and Pro unlocks; if the paywall was already closed it does not reopen. | Alert screenshot; post-approval Settings screenshot. | not run |
| I-07 | Ask to Buy declined | SK (decline in the Xcode transaction manager), SB | Decline a pending request. | Stays locked. Source has no decline-specific message: label not found in source — verify on device. | Screenshot; note whether any message appears. | not run |
| I-08 | Purchase fails (StoreKit error) | SK (failure option in Debug > StoreKit on; label unverified) | Tap "Unlock Lifetime Pro". | Alert "The App Store could not be reached. Your saved parking details remain available." (any non-app error maps to this). Locked; button usable again for a retry. | Alert screenshot; retry succeeds after turning failures off. | not run |
| I-09 | Interrupted purchase resolves once, no double unlock | SK (interrupted-purchases option in Debug > StoreKit; label unverified), SB, TF (enable interrupted purchases for the tester in App Store Connect) | Start a purchase, interrupt, then complete it. | The app unlocks once via the transaction update; the paywall closes if open; a single product entitlement, no second charge. | Screenshots; Xcode transaction manager showing one transaction. | not run |
| I-10 | Unverified transaction stays locked | SK (unverifiable not directly simulable; verify on device by inspection or n/a) | Not reproducible with the local config. Source: unverified or revoked or wrong-product result throws. | Alert "The purchase could not be verified. Try Restore Purchases or contact support." Locked. | Mark BLOCKED if it cannot be forced. | not run |
| I-11 | Relaunch after purchase: entitlement persists | SK, SB, TF | After I-04 force-quit and reopen. | Settings shows "Lifetime Pro unlocked" with no purchase prompt. | Screenshot after relaunch. | not run |
| I-12 | Offline relaunch after purchase | SB, TF | After I-04 enable Airplane Mode, force-quit, reopen. | Expected: StoreKit answers from its on-device transaction data and Settings shows "Lifetime Pro unlocked"; the app keeps no entitlement cache of its own, so this is unproven. If StoreKit cannot answer within 15 s the entitlement is unavailable: Settings then still shows the "Lifetime Pro" row (not unlocked), and the paywall must not show the buy button to a payer (#79) but the verifying text with "Check Again". Record exactly which appears. | Screenshots of Settings and, if opened, the paywall. | not run |
| I-13 | Delete, reinstall, Restore Purchases | SB, TF | Delete the app, reinstall, skip the introduction ("Skip" top right, or "Maybe Later" on the last page; Restore is not offered inside it), then Settings > "Restore Purchases" (also on the paywall). | Alert "Lifetime Pro was restored." (or none when restored from the cost offer or CSV lock); Settings shows "Lifetime Pro unlocked". A system sign-in sheet may appear (120 s deadline). | Before and after screenshots. | not run |
| I-14 | Restore on a second device, same Sandbox account | PR | On the second device, install the build, Settings > "Restore Purchases". | Same as I-13. | Screenshots; device model and OS. | not run |
| I-15 | Subscription with free trial | all | n/a — no subscription or trial exists (paywall says "No subscription, no trial, no account."). | n/a | n/a | n/a |
| I-16 | Subscription renews | all | n/a — non-consumable, no renewal. | n/a | n/a | n/a |
| I-17 | Auto-renew off then expiry locks | all | n/a — no subscription. | n/a | n/a | n/a |
| I-18 | Refund / revoke locks, data kept | SK (transaction manager > Refund), SB | With Pro unlocked and saved sessions, refund or revoke, return to the app, then Settings > "Restore Purchases" if needed. | Pro locks (Settings shows the "Lifetime Pro" row again); "Parking cost" shows "Add a parking cost with Pro"; History shows 3; saved spot, "Walking Directions" and "Finish" still work; no data deleted. | Before and after screenshots; count of sessions. | not run |
| I-19 | Cross-grade within a group | all | n/a — single non-consumable, no group. | n/a | n/a | n/a |
| I-20 | Billing retry / grace period | all | n/a — no subscription. | n/a | n/a | n/a |
| I-21 | Restore with nothing to restore | SK (no transaction), SB or TF with a fresh tester (or after Clear Purchase History) | Settings > "Restore Purchases" with no purchase. | Alert "No Lifetime Pro purchase was found for this Apple ID." Stays locked; if the paywall was open it stays open. If the store cannot be reached instead: "The App Store could not confirm Lifetime Pro right now. Try Restore Purchases again when the store is available. Your saved spot remains available." or "The App Store could not restore Lifetime Pro. Try Restore Purchases again when the store is available. Your saved spot remains available." | Alert screenshot. | not run |
| I-22 | Double tap on Buy: single charge | SK, SB | Double-tap "Unlock Lifetime Pro" quickly. | Button shows a spinner and is disabled while busy (`isBusy`), so one purchase sheet and one transaction. | Screen recording; one transaction in the Xcode transaction manager or the Sandbox receipt. | not run |
| I-23 | Manage subscription link | all | n/a — no subscription and no manage-subscriptions control in source. | n/a | n/a | n/a |
| I-24 | Consumable credit once | all | n/a — Lifetime Pro is non-consumable; no consumable products. | n/a | n/a | n/a |
| I-25 | Provider / server ledger records the transaction | all | n/a — no RevenueCat, Superwall or server (local-only app). The only record is the App Store/Sandbox transaction (capture the last 6 of the id). | n/a | n/a | n/a |
| I-26 | TestFlight renewal-limit behaviour | TF | n/a — no renewing products. | n/a | n/a | n/a |
| I-27 | Production purchase | none | not authorized (no real money). Do not tap "Unlock Lifetime Pro" on an App Store build signed in with a real Apple ID. | n/a | n/a | not authorized |

## Device rows for Gus

For the 2026-11-09 sitting on the physical iPhone (scoreboard #976), using only the Sandbox tester account:

- SB / TF: I-03, I-04, I-05, I-06, I-07, I-08, I-11, I-12, I-13, I-18, I-21, I-22, and I-01 on a fresh install. I-09 and I-10 only if the tooling can force them (SK only otherwise).
- PR (second device): I-14.
- Everything n/a above needs no device time. Standing physical checks are in [DEVICE-ACCEPTANCE.md](../DEVICE-ACCEPTANCE.md) under "StoreKit Sandbox".
- Run the 1.2.1 build (TestFlight or Xcode) and check I-02 and I-12 first; they are the #79 behaviour the 1.2.1 build exists to prove.

## Receipt template

```
Row id:
App: ParkNudge
Version (build):
Install source: (Xcode Debug | TestFlight | App Store)
Device / OS:
Sandbox alias: (sanitized, for example "the Sandbox tester account")
Product id: com.gusdigitalsolutions.parknudge.pro.lifetime
Timestamp UTC:
Before state:
Action:
After state:
Transaction id (last 6 only):
Screenshot filenames:
Result: PASS | FAIL | BLOCKED
Notes:
```

Never record Sandbox emails or passwords, offer codes or provider keys in a receipt.

## Sources

- `ParkNudge/Resources/ParkNudge.storekit`
- `ParkNudge/Platform/PurchaseService.swift`
- `ParkNudge/Application/AppModel.swift`
- `ParkNudge/Application/AppEnvironment.swift`
- `ParkNudge/Domain/Models/CommerceModels.swift`
- `ParkNudge/UI/Paywall/PaywallView.swift`
- `ParkNudge/UI/Settings/SettingsView.swift`
- `ParkNudge/UI/History/HistoryView.swift`
- `ParkNudge/UI/Park/ParkView.swift`
- `ParkNudge/UI/Park/ParkingEditorView.swift`
- `ParkNudge/UI/RootTabView.swift`
- `ParkNudge/UI/Onboarding/OnboardingView.swift`
- `ParkNudgeTests/AppModelTests.swift`, `ParkNudgeTests/TestFixtures.swift`
- `ParkNudgeUITests/ParkNudgeUITests.swift`
- `scripts/test_paywall_entitlement_gate.py`, `scripts/check_project_source_truth.sh`, `scripts/audit-release.sh`
- `project.yml`, `AGENTS.md`, `Docs/MONETIZATION.md`, `Docs/DEVICE-ACCEPTANCE.md`
