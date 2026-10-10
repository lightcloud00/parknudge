# ParkNudge earned-unlock candidate

from: Claude; time_utc: 2026-10-10; requested_by: Gus, "pay after first result" (portfolio conversion contract 1.1, `earned_unlock`); supersedes the 2026-10-03 pay-before-use draft by Codex; before_state: new customers needed Lifetime Pro before saving any spot; after_state: local source candidate only; next: native and StoreKit acceptance; stop_gate: no release acceptance without exact candidate proof.

Candidate: **1.1 (5)**. Build 5 adds the sandbox Restore fix below and the UserDefaults required-reason declaration (CA92.1) in `PrivacyInfo.xcprivacy`.

- **The first parking session is free for new customers:** save the spot, see the return route and reminder plan, and finish.
- Starting or replacing a second session needs verified Lifetime Pro. Directions and Finish for a saved spot always stay usable.
- Once the free session is used, `hasUsedFreeParkingSession` is recorded so that deleting history cannot reopen it.
- Home and the paywall say "Your first park is free" before it is used and "You've used your free park" after.
- Verified production app ownership from original builds 1–2 keeps the original Free parking. It doesn't grant Pro extras.
- A verified sandbox or Xcode app transaction (App Review, TestFlight, local StoreKit) is never an original customer, so it is treated as a new customer. Restore with nothing to restore then says "No previous parking access or active Lifetime Pro purchase was found." Only an unverified or failed lookup stays unknown and reports that the App Store could not verify access.
- Keep the approved product `com.gusdigitalsolutions.parknudge.pro.lifetime`. Prices come from StoreKit. No subscription or Superwall SDK is introduced.
- DEBUG UI fixtures stay legacy by default. Use `--new-customer-paywall` for the new-customer journey.

## Release acceptance

- [ ] Run the full native suite at the final source revision, including:
  - `testNewCustomerParksOnceFreeThenNeedsVerifiedPurchase`
  - `testFreeParkStaysUsedWhenHistoryIsGone`
  - `testParkingStartPolicyGivesOneFreeSessionAndNeverGatesPaidAccess`
- [ ] Verify in StoreKit/Sandbox:
  - new install → first park with no paywall
  - second park offers Pro
  - close, cancel and pending
  - verified purchase resumes the editor
  - restore, revocation, relaunch and offline ownership
- [ ] Verify that old App Store ownership keeps original Free parking without granting Pro extras.
- [ ] Exercise entitlement loss while the editor is already open. A denied replacement must keep the original spot and its reminders.
- [ ] Verify that directions and Finish stay available after purchase revocation.
- [ ] Update the website, screenshots and localized listing to "first park free, then one-time unlock" in the same release.

## Draft customer-facing copy

“Save your parking spot, set meter reminders and find your way back. Your first park is free, then one Lifetime Pro purchase keeps ParkNudge going. No subscription. Existing customers keep their original parking features.”

Draft review note: “New customers can complete one full parking session for free. Starting another session uses the existing non-consumable Lifetime Pro product. Verified prior production app ownership keeps the original Free functionality. Closing or cancelling the offer never removes a saved spot, its directions or Finish.”
