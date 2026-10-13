# Version 1.1 parking-access boundary

## Current candidate model

New customers need verified Lifetime Pro before saving or replacing a parking session. A verified production AppTransaction with original build 1 or 2 retains the original parking workflow without granting Pro extras. Sandbox, missing or unverified ownership is not evidence of legacy access.

The rules below describe the version 1.1 candidate, not proof of public release or successful device transactions.

Lifetime Pro is a non-consumable in-app purchase: bought once and non-expiring while Apple reports a verified current entitlement. The app renders StoreKit's current localized `displayPrice`; this document does not establish current storefront pricing.

Product identifier: `com.gusdigitalsolutions.parknudge.pro.lifetime`

| Capability | Verified original customers | Lifetime Pro |
|---|---|---|
| One active parking spot | Included | Included |
| GPS capture and manual pin correction | Included | Included |
| MapKit place search | Included | Included |
| Apple Maps walking directions | Included | Included |
| Floor, section, note, and one photo | Included | Included |
| Meter timer | Included | Included |
| Meter reminders | Fixed 15/5/0-minute alerts | Custom offsets and saved presets |
| Completed history | Three newest visible | Unlimited visible history |
| Parking-cost records | Locked | Included |
| CSV export | Locked | Included |
| Live Activity | Deferred | Candidate v1.1 feature |

## Data preservation

All completed sessions remain stored locally. Upgrade reveals older sessions. A missing, revoked, or refunded entitlement hides locked surfaces but never deletes sessions, costs, photos, or reminder metadata.

## Paywall rules

- Present after a new customer asks to save or replace a spot, after a locked-feature action, or from the Settings card. No first-launch interruption.
- Always dismissible. Dismissal does not unlock new parking. Existing saved parking, directions and finishing an active session remain available.
- State “one-time purchase, no subscription.”
- Explain the paid parking requirement for new customers. Show the original-access comparison only to verified original customers; list the four Pro extras accurately.
- Provide Restore Purchases, Privacy, Terms, and Close controls.
- No trial countdown, fake discount, repeated automatic presentation, or first-launch interruption.

## Store outcomes

- Successful verified purchase: finish the transaction and unlock Pro.
- Cancelled: keep the intended action locked without showing an error or changing saved data.
- Pending: do not unlock new parking or Pro extras; explain that approval is pending and preserve saved data.
- Unverified: do not unlock Pro.
- Store or product unavailable: do not infer new access; preserve existing saved parking, directions and active-session completion.
- Restore: call `AppStore.sync()` and recompute current verified entitlement and original parking ownership. Original parking access does not grant Pro extras.
- Revoked or refunded: recompute access from verified purchase and original ownership without deleting data. A new customer cannot save or replace another spot without verified access.

## Why not a subscription

The MVP is an on-device utility whose launch value does not depend on continuously delivered content or a hosted service. A one-time purchase is the clearer fit. See Apple’s [in-app purchase type reference](https://developer.apple.com/help/app-store-connect/reference/in-app-purchases-and-subscriptions/in-app-purchase-types) and [App Review Guidelines](https://developer.apple.com/app-store/review/guidelines/).
