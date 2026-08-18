# ParkNudge roadmap

This roadmap separates implemented source from evidence that requires a physical device, Apple systems, public infrastructure, or release authority. Open GitHub issues are the execution queue after repository publication.

## Local MVP implementation

- [x] Swift 6 / SwiftUI / SwiftData iOS 17 project with XcodeGen
- [x] Versioned parking, reminder, and photo-metadata schema
- [x] One-active-session repository invariant and confirmed archival replacement
- [x] One-shot contextual location capture and manual/search pin correction
- [x] Floor, section, note, photo, meter expiration, and active-session UI
- [x] Deterministic local meter reminders with past-warning filtering and replacement
- [x] Apple Maps walking directions, finish, newest-first history, deletion, and Delete All
- [x] StoreKit 2 product loading, purchase, restore, verified entitlement, update, and revocation handling
- [x] Free/Pro feature policy and one-time first-completion paywall
- [x] Locale-aware cost input with integer minor-unit persistence
- [x] Sensitive-location warning and RFC 4180 CSV export without photo data/paths
- [x] Privacy manifest, contextual permission copy, time-sensitive entitlement, no background modes
- [x] Unit and simulator UI test sources
- [x] Dependency-free static website, privacy, terms, support, roadmap, natural-search guides, JSON-LD, sitemap, and checker

## Device and accessibility acceptance

- [ ] Real GPS: authorized, denied, restricted, reduced accuracy, stale fix, and failure
- [ ] Real camera capture and unavailable-camera behavior
- [ ] Local notifications while foregrounded, backgrounded, and terminated
- [ ] Focus and time-sensitive delivery behavior
- [ ] VoiceOver reading/order/actions on every primary screen
- [ ] Accessibility Extra Large, smaller and larger iPhones, light/dark, Reduce Motion
- [ ] Apple Maps handoff and failure behavior on hardware

## Commerce and beta

- [ ] Reserve the product identity and complete trademark review
- [ ] Create `com.gusdigitalsolutions.parknudge.pro.lifetime` in App Store Connect
- [ ] Configure localized non-consumable pricing using $9.99 as the U.S. reference
- [ ] Apple Sandbox purchase, cancellation, pending, restore, refund, and revocation acceptance
- [ ] Final support/privacy/terms contact and legal review
- [ ] App Store privacy answers, age rating, metadata, and screenshot set
- [ ] Signed archive, TestFlight upload, external beta, crash feedback, and go/no-go review

## Website launch

- [ ] Acquire the selected domain; current `parknudge.app` references are candidates, not ownership proof
- [ ] Deploy static site and verify HTTPS, canonical URLs, redirects, robots, and sitemap from the public edge
- [ ] Connect Search Console after verified ownership and submit the sitemap
- [ ] Replace GitHub-only beta support with the final support channel

## v1.1 candidates

- [ ] Live Activity for active meter status as a candidate Pro feature
- [ ] Evaluate opt-in automatic parking suggestions for privacy, battery, and reliability
- [ ] Validate demand before considering widgets or Apple Watch

## Explicitly deferred

Motion/Bluetooth monitoring, CarPlay, iPad, CloudKit, accounts, municipal meter payments, subscriptions, ads, third-party analytics, and automatic release automation.
