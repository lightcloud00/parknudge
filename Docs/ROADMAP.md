# ParkNudge roadmap

This roadmap separates implemented source from evidence that requires a physical device, Apple systems, public infrastructure, or release authority. The [open GitHub issues](https://github.com/lightcloud00/parknudge/issues) are the execution queue; milestones group work by evidence gate.

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
- [x] Cloudflare-ready 404/redirect assets, crawler/LLM/IndexNow files, and provider-neutral search-engine handoff
- [x] Deterministic full simulator, Release, audit, and exact-head CI gate ([#1](https://github.com/lightcloud00/parknudge/issues/1))

## Device and accessibility acceptance

- [ ] Real GPS states and Apple Maps handoff/failure behavior ([#2](https://github.com/lightcloud00/parknudge/issues/2))
- [ ] Real camera capture, unavailable-camera behavior, and photo lifecycle ([#3](https://github.com/lightcloud00/parknudge/issues/3))
- [ ] Notifications while foregrounded/backgrounded/terminated plus Focus and time-sensitive behavior ([#4](https://github.com/lightcloud00/parknudge/issues/4))
- [ ] VoiceOver, Accessibility Extra Large, small/large iPhones, light/dark, and Reduce Motion ([#5](https://github.com/lightcloud00/parknudge/issues/5))

## Commerce and beta

- [ ] Reserve the product identity and complete trademark review ([#6](https://github.com/lightcloud00/parknudge/issues/6))
- [ ] Configure the Lifetime Pro product, localized pricing, and every Apple Sandbox outcome ([#7](https://github.com/lightcloud00/parknudge/issues/7))
- [ ] Finalize support/privacy/terms review, privacy answers, age rating, metadata, and screenshots ([#8](https://github.com/lightcloud00/parknudge/issues/8))
- [ ] Create a signed archive and complete TestFlight beta installation, feedback, and go/no-go review ([#9](https://github.com/lightcloud00/parknudge/issues/9))

## Website launch

- [ ] Acquire the selected domain, replace candidate canonicals, and establish the final support channel ([#10](https://github.com/lightcloud00/parknudge/issues/10))
- [ ] Deploy and verify HTTPS, redirects, canonical URLs, robots, sitemap, Google Search Console, Bing Webmaster Tools, and IndexNow from the public edge ([#11](https://github.com/lightcloud00/parknudge/issues/11))
- [ ] Complete the shared Google/Bing Engine lane and record merged, provider, query-baseline, Obsidian, and Hindsight evidence ([#25](https://github.com/lightcloud00/parknudge/issues/25))

## Revenue foundation

- [ ] Establish an aggregate App Store Connect and Search Console revenue scorecard without an app analytics SDK ([#14](https://github.com/lightcloud00/parknudge/issues/14))
- [ ] Add a respectful contextual rating request after repeated successful sessions ([#15](https://github.com/lightcloud00/parknudge/issues/15))
- [ ] Add and accept the promoted Lifetime Pro PurchaseIntent flow ([#18](https://github.com/lightcloud00/parknudge/issues/18))
- [ ] Review the $9.99 price from real proceeds, conversion, refund, and value evidence ([#20](https://github.com/lightcloud00/parknudge/issues/20))
- [ ] Establish a privacy-safe support and feature-demand feedback loop ([#24](https://github.com/lightcloud00/parknudge/issues/24))

## Organic and paid growth gates

- [ ] Run a controlled App Store product-page optimization test ([#16](https://github.com/lightcloud00/parknudge/issues/16))
- [ ] Create intent-specific Find My Car, Meter Reminder, and Garage custom product pages ([#17](https://github.com/lightcloud00/parknudge/issues/17))
- [ ] Localize one complete market at a time from territory and search evidence ([#19](https://github.com/lightcloud00/parknudge/issues/19))
- [ ] Refresh parking-app and iOS trend evidence quarterly ([#21](https://github.com/lightcloud00/parknudge/issues/21))
- [ ] Prepare a bounded Apple Ads experiment; activation requires separate spend approval ([#22](https://github.com/lightcloud00/parknudge/issues/22))
- [ ] Expand SEO/AEO pages only from verified Google and Bing query demand ([#23](https://github.com/lightcloud00/parknudge/issues/23))

## v1.1 candidates

- [ ] Evaluate Live Activity for active meter status as a candidate Pro feature ([#12](https://github.com/lightcloud00/parknudge/issues/12))
- [ ] Evaluate opt-in automatic parking suggestions, widgets, and Apple Watch only after demand, privacy, battery, and reliability validation ([#13](https://github.com/lightcloud00/parknudge/issues/13))

## Explicitly deferred

Motion/Bluetooth monitoring, CarPlay, iPad, CloudKit, accounts, municipal meter payments, subscriptions, ads, third-party analytics, and automatic release automation.

See the [issue execution plan](EXECUTION-PLAN.md) for dependency order and proof requirements, the [revenue roadmap](REVENUE-ROADMAP.md) for measurement and growth experiments, and the [search-engine handoff](SEARCH-ENGINE.md) for the shared Google/Bing Engine contract.
