# ParkNudge revenue roadmap

Status: operating plan for a future public launch. It does not claim App Store availability, revenue, a configured purchase, a deployed website, or an approved advertising budget.

## Revenue thesis

ParkNudge earns by making a small, trustworthy parking utility worth owning. The complete park-and-return loop remains free. Lifetime Pro is a one-time, non-expiring non-consumable that adds durable power-user value: unlimited visible history, custom reminder offsets and presets, parking-cost records, and CSV export.

The U.S. reference price is **$9.99**. The app renders only StoreKit's localized `displayPrice`. Subscriptions, ads, selling data, background tracking, forced first-launch paywalls, fake discounts, and destructive downgrade behavior are outside this model.

## Revenue math, not a forecast

These scenarios multiply units by the $9.99 U.S. reference price. They are gross customer billings before Apple commission, taxes, refunds, exchange rates, and regional price differences. App Store Connect **Proceeds** is the operating truth after launch.

| Lifetime Pro sales | Reference gross |
|---:|---:|
| 10 | $99.90 |
| 50 | $499.50 |
| 100 | $999.00 |
| 500 | $4,995.00 |
| 1,000 | $9,990.00 |

Apple defines proceeds as customer price minus applicable taxes and Apple's commission. The scorecard must never substitute gross sales for proceeds. Source: [App Store Connect sales analytics](https://developer.apple.com/help/app-store-connect-analytics/monetization/sales/).

## Measurement without an app analytics SDK

| Funnel question | Canonical evidence |
|---|---|
| Are people seeing ParkNudge? | App Store impressions and Search Console impressions |
| Does the listing earn a visit or download? | Product-page views, downloads, App Store conversion rate, web clicks and CTR |
| Does the free product earn paid trust? | Lifetime Pro purchases, paying users, download-to-paid conversion |
| Does the business retain value? | Estimated proceeds, proceeds per download, refunds and refund rate |
| Which intent and territory work? | App Store acquisition/territory dimensions, custom-product-page results, Search Console queries |
| Is quality blocking growth? | Crashes, support categories, ratings/reviews, device-acceptance evidence |

App Store Connect provides acquisition, sales, proceeds, refund, and paying-user metrics; some usage data depends on users sharing analytics. Search Console exposes query, impression, click, and CTR evidence after public ownership is verified. Missing or privacy-thresholded data is **unknown**, never zero. Sources: [App Store Connect Analytics](https://developer.apple.com/help/app-store-connect-analytics/), [Google Search performance](https://support.google.com/webmasters/answer/9131543).

## Stage 0 — finish the sellable product

Exit gate: deterministic verification, device/accessibility acceptance, identity clearance, Lifetime Pro configuration and Sandbox outcomes, final legal/metadata, and TestFlight beta evidence.

- Verification and device gates: [#1](https://github.com/lightcloud00/parknudge/issues/1)–[#5](https://github.com/lightcloud00/parknudge/issues/5)
- Identity, commerce, metadata, and beta: [#6](https://github.com/lightcloud00/parknudge/issues/6)–[#9](https://github.com/lightcloud00/parknudge/issues/9)
- Domain and website launch: [#10](https://github.com/lightcloud00/parknudge/issues/10)–[#11](https://github.com/lightcloud00/parknudge/issues/11), with the shared Google/Bing Engine handoff in [#25](https://github.com/lightcloud00/parknudge/issues/25)

No revenue projection is promoted until these evidence gates are complete.

## Stage 1 — install the revenue foundation

- [#14](https://github.com/lightcloud00/parknudge/issues/14): establish the aggregate launch revenue scorecard.
- [#15](https://github.com/lightcloud00/parknudge/issues/15): request a rating only after repeated successful sessions.
- [#18](https://github.com/lightcloud00/parknudge/issues/18): support an App Store-promoted Lifetime Pro purchase intent.
- [#24](https://github.com/lightcloud00/parknudge/issues/24): organize voluntary support and feature-demand feedback without collecting parking histories.

Exit gate: the sources and definitions are documented, the purchase path is accepted in Sandbox, and feedback handling protects location data.

## Stage 2 — improve organic conversion

- [#16](https://github.com/lightcloud00/parknudge/issues/16): test one App Store product-page variable at a time.
- [#17](https://github.com/lightcloud00/parknudge/issues/17): align custom product pages to Find My Car, Meter Reminder, and Garage intent.
- [#23](https://github.com/lightcloud00/parknudge/issues/23): expand SEO/AEO pages only from verified Google Search Console and Bing Webmaster query demand.
- [#19](https://github.com/lightcloud00/parknudge/issues/19): localize one complete market at a time from territory evidence.

Apple's Product Page Optimization supports controlled creative treatments and labels better/worse results at 90% confidence. Custom product pages can vary screenshots, promotional text, previews, and keywords for distinct audiences. Sources: [Product Page Optimization](https://developer.apple.com/help/app-store-connect-analytics/acquisition/product-page-optimization/), [Custom Product Pages](https://developer.apple.com/app-store/custom-product-pages/).

Exit gate: each change has a control, evidence window, metric, stop rule, and committed decision record. Do not interpret low-volume noise as a win.

## Stage 3 — validate price and unit economics

[#20](https://github.com/lightcloud00/parknudge/issues/20) keeps $9.99 stable for the initial evidence window. Review after 30 live days and 25 purchases; if volume is lower, wait until day 90 and label the sample small. Change one variable at a time and never manufacture urgency.

Decision inputs:

- download-to-paid conversion;
- actual proceeds per download and per paying user;
- refunds and refund reasons where Apple exposes them;
- territory mix and localized price presentation;
- voluntary price/value feedback;
- support load created by Pro features.

## Stage 4 — consider paid acquisition

[#22](https://github.com/lightcloud00/parknudge/issues/22) prepares a bounded Apple Ads search experiment. Campaign activation is a protected spend action and requires separate approval for the exact countries, dates, daily budget, maximum exposure, and stop rules.

Do not buy traffic until organic product-page conversion and proceeds per download are known. A pilot must use a conservative acquisition-cost cap, intent-specific product pages, negative keywords, an end date, and a hard loss limit. Apple documents that a daily budget is an average and monthly spend can reach daily budget multiplied by 30.4, so the approval packet must show worst-case exposure. Source: [Apple Ads campaign and budget guidance](https://ads.apple.com/app-store/help/campaigns/0005-create-campaigns).

## Evidence-backed trend lane

On August 18, 2026, a reproducible U.S. iTunes Search API sample queried `find my car`, `parking reminder`, and `parking meter timer` with `entity=software` and `limit=25`, then deduplicated App Store IDs. The 66 unique results contained these description mentions:

| Directional signal | Results mentioning it |
|---|---:|
| Timer, meter, or parking-ticket reminder | 37 |
| Photo or note | 24 |
| History | 24 |
| Automatic, Bluetooth, or motion behavior | 18 |
| Sharing | 12 |
| Apple Watch or widget | 10 |
| Offline behavior | 7 |
| Augmented reality | 3 |

Forty-seven results had a 2026 update date; none had the exact title `ParkNudge`. This is a relevance-ranked snapshot of listing copy, **not** market share, revenue, quality, trademark clearance, or proof that a feature should be built.

The response is disciplined:

- keep meter, photo/note, history, directions, and manual correction excellent because they are core jobs;
- evaluate Live Activity through [#12](https://github.com/lightcloud00/parknudge/issues/12), because meter status is a bounded glanceable task;
- evaluate opt-in automatic suggestions, widgets, and Watch through [#13](https://github.com/lightcloud00/parknudge/issues/13), only after demand, privacy, battery, and reliability proof;
- refresh the market snapshot quarterly through [#21](https://github.com/lightcloud00/parknudge/issues/21);
- leave sharing, offline maps, and augmented reality as hypotheses until customer evidence justifies a scoped issue.

## Operating rules

1. Finish reliability and commerce acceptance before growth optimization.
2. Measure one material change at a time.
3. Use provider data with exact dates and filters; unavailable is not zero.
4. Keep the free parking loop useful and the paywall dismissible.
5. Never delete hidden history or costs when entitlement is absent or revoked.
6. No public/deployment/commerce/spend action without the evidence and authority named in its issue.
7. Close every experiment with a written continue, revise, or stop decision.
