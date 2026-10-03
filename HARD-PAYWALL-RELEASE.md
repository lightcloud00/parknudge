# ParkNudge hard-paywall candidate

from: Codex; time_utc: 2026-10-03T18:10:05Z; local_date: 2026-10-03 America/New_York; requested_by: Gus, paid core access for new customers; before_state: free parking with optional Pro; after_state: local source candidate only; proof_path: /Users/gus/Desktop/Claudecode/state/secondary-app-revenue-20261003/RECEIPT.md; next: native and StoreKit acceptance; stop_gate: no release acceptance without exact candidate proof.

Candidate: **1.1 (3)**. ASC currently has only public 1.0 build 2; a 1.1 draft has not been created by this task.

- New customers require verified Lifetime Pro before saving or replacing a parking session. Existing saved spots, directions and finishing an active session stay usable.
- Verified production app ownership from original builds 1–2 retains original Free parking. It does not grant Pro extras.
- Keep approved product `com.gusdigitalsolutions.parknudge.pro.lifetime`. Prices come from StoreKit. No subscription or Superwall SDK is introduced.
- DEBUG UI fixtures remain legacy by default; use `--new-customer-paywall` for the new-customer journey.

## Release acceptance

- [ ] Run the full native suite and the five new core-access tests at the final source revision.
- [ ] Verify new install, close/cancel, pending, verified purchase, restore, revocation, relaunch and offline ownership behavior in StoreKit/Sandbox.
- [ ] Verify old App Store ownership preserves original Free parking without granting Pro extras.
- [ ] Exercise the purchase-to-editor transition and entitlement loss while the editor is already open; denied replacement must preserve the original spot and reminders.
- [ ] Verify directions and Finish remain available after purchase revocation.
- [ ] Update the website, screenshots and localized listing to match paid core access before the same release. Existing live free-first copy remains appropriate only to build 2.

## Draft customer-facing copy

“Save your parking spot, set meter reminders and find your way back. New customers unlock ParkNudge with one Lifetime Pro purchase. No subscription. Existing customers keep their original parking features.”

Draft review note: “The existing non-consumable Lifetime Pro product unlocks core parking for new customers. Verified prior production app ownership retains original Free functionality. Closing or cancelling the offer cannot save or replace a spot. Existing saved parking and directions remain available.”
