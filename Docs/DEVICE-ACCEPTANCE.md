# Physical-device acceptance checklist

These checks cannot be proven by the simulator. Record device model, iOS version, build SHA, date, result, and evidence path for every run.

## Location

- [ ] When-In-Use prompt appears only after **Save Parking Spot** is tapped.
- [ ] Authorized capture returns one current fix, shows realistic accuracy, and stops location activity.
- [ ] Reduced accuracy is identified and the pin remains editable.
- [ ] Denied and restricted flows open manual selection and place search. Saving stays blocked until the user retries successfully or explicitly confirms a pin (map, search, or the on-screen confirm control). A confirmed pin is saved even when its coordinates match the unconfirmed placeholder. Broad device location acceptance remains #2; this check is the #95 regression.
- [ ] Airplane mode or another location failure keeps notes and meter choices, and does not persist the placeholder coordinate until the user confirms it.

## Camera and photo files

- [ ] Camera prompt appears only after **Take Photo**.
- [ ] Capture, rotation, compression, relaunch display, replacement, and removal work.
- [ ] Individual deletion and Delete All remove associated photo files.
- [ ] Orphan cleanup removes only unreferenced ParkNudge photos.

## Notifications

- [ ] Permission denial saves the parking session and presents only a warning.
- [ ] 15/5/0 alerts arrive for a long-enough meter while the app is foregrounded, backgrounded, and terminated.
- [ ] A short meter skips alerts already in the past.
- [ ] Edit/extend cancels old identifiers and delivers only the replacement schedule.
- [ ] Finish, replace, delete, and Delete All cancel pending requests.
- [ ] Time-sensitive behavior is evaluated with Focus enabled; do not promise Focus bypass.

## Maps and system handoff

- [ ] Walking Directions opens Apple Maps with the saved coordinate and walking mode.
- [ ] Failure leaves the active session untouched and gives an actionable message.

## Accessibility and layouts

- [ ] VoiceOver labels, order, map alternatives, buttons, dialogs, and paywall controls.
- [ ] Accessibility Extra Large without clipped controls or inaccessible actions.
- [ ] Light and dark appearance.
- [ ] Reduce Motion.
- [ ] Small supported iPhone and largest current iPhone layouts.

## StoreKit Sandbox

- [ ] Local StoreKit configuration covers success, cancellation, pending, and unavailable product.
- [ ] Apple Sandbox purchase grants Pro only after verification.
- [ ] Restore uses `AppStore.sync()` and succeeds after reinstall.
- [ ] Refund/revocation removes access without deleting sessions or cost data.
- [ ] Localized price text matches StoreKit `displayPrice` in at least two storefront locales.
