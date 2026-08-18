# Free and paid boundary

## Launch model

Lifetime Pro is a non-consumable in-app purchase: bought once and non-expiring while Apple reports a verified current entitlement. The planned U.S. reference price is $9.99; the app always renders StoreKit's localized `displayPrice`.

Product identifier: `com.gusdigitalsolutions.parknudge.pro.lifetime`

| Capability | Free | Lifetime Pro |
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

- Automatically present only once, after the first successfully completed session, and only for a free user.
- Always dismissible; free access continues uninterrupted.
- Also available from a locked Pro feature and Settings.
- State “one-time purchase, no subscription.”
- List the four exact Pro features.
- Provide Restore Purchases, Privacy, Terms, and Close controls.
- No trial countdown, fake discount, repeated automatic presentation, or first-launch interruption.

## Store outcomes

- Successful verified purchase: finish the transaction and unlock Pro.
- Cancelled: close no workflow and show no error.
- Pending: keep free access and explain that approval is pending.
- Unverified: do not unlock Pro.
- Store or product unavailable: keep free access.
- Restore: call `AppStore.sync()` and recompute current verified entitlement.
- Revoked or refunded: recompute to free without deleting data.

## Why not a subscription

The MVP is an on-device utility whose launch value does not depend on continuously delivered content or a hosted service. A one-time purchase is the clearer fit. See Apple’s [in-app purchase type reference](https://developer.apple.com/help/app-store-connect/reference/in-app-purchases-and-subscriptions/in-app-purchase-types) and [App Review Guidelines](https://developer.apple.com/app-store/review/guidelines/).
