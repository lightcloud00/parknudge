# ParkNudge MVP product definition

## Promise

ParkNudge helps an iPhone user remember where they parked and when a parking meter expires without an account or background tracking.

The primary loop is:

1. Tap **Save Parking Spot**.
2. Capture one location fix, inspect accuracy, search, or correct the pin manually.
3. Add optional floor, section, note, one photo, meter expiration, and—when Pro—cost.
4. Confirm one active session.
5. View elapsed time and meter status, open Apple Maps walking directions, edit or extend, replace, or finish.
6. Review completed sessions newest-first.

## Product principles

- No onboarding carousel and no first-launch paywall.
- Location permission is contextual and When-In-Use only.
- The free parking workflow stays intact when StoreKit or notifications fail.
- All data stays local unless the user explicitly shares a CSV.
- A display limit is not a retention limit: free users see three completed sessions, but all remain stored.
- Countdowns derive from an absolute expiration date.
- Purchase state comes only from verified StoreKit transactions.

## MVP non-goals

Live Activities, automatic parking detection, motion or Bluetooth monitoring, widgets, Apple Watch, CarPlay, iPad, CloudKit, accounts, municipal payments, ads, and analytics are deferred.

## Identity

- Product: **ParkNudge**
- Draft App Store name: **ParkNudge: Find My Car**
- Draft subtitle: **Parking Spot & Meter Timer**
- Bundle identifier: `com.gusdigitalsolutions.parknudge`
- Scheme: `ParkNudge`
- Deployment target: iOS 17
