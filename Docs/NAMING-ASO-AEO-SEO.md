# Naming and discoverability decision

Status: working launch identity, subject to trademark and App Store Connect availability review.

## Decision

- Brand and app display name: **ParkNudge**
- Draft App Store name: **ParkNudge: Find My Car**
- Draft subtitle: **Parking Spot & Meter Timer**
- Repository: `lightcloud00/parknudge`
- Candidate domain: `parknudge.app`

The brand is short, pronounceable, and connects the parking job (“Park”) with the reminder behavior (“Nudge”). The App Store name and subtitle carry the direct category language instead of forcing every search phrase into the brand.

## Evidence gathered August 18, 2026

- Apple’s U.S. iTunes Search API returned no exact `ParkNudge` title in the queries tested.
- Registry/RDAP requests returned HTTP 404 availability signals for `parknudge.com` and `parknudge.app` at the time checked.
- `ParkPin` was rejected because an existing App Store product uses that name.

These are point-in-time collision signals, not reservation, ownership, trademark clearance, or final App Store name acceptance. Recheck immediately before acquiring a domain or creating the App Store record.

Research package verification fingerprint: `168d79b9442a1999b6122eed2710492d8d9bdebb21abca470b2ad5a0c36e9f4b`.

## ASO draft

- Name: `ParkNudge: Find My Car`
- Subtitle: `Parking Spot & Meter Timer`
- Promotional direction: “Save your pin, garage details, and meter deadline without background tracking.”
- Keyword candidates for final metadata testing: `garage,location,saved pin,vehicle,street,reminder,where did i park`

Do not claim “best,” “#1,” ticket prevention, or automatic detection. Avoid duplicating name/subtitle terms in the keyword field when finalizing App Store Connect metadata.

Apple says the product page name, subtitle, keywords, category, and description help customers discover an app, and metadata must accurately reflect the experience. Sources: [App Store search](https://developer.apple.com/app-store/search/), [Product page](https://developer.apple.com/app-store/product-page/), and [App Review Guidelines](https://developer.apple.com/app-store/review/guidelines/).

## Natural SEO and AEO structure

The static site targets three human questions with dedicated visible pages:

- “How do I find my parked car?” → `/find-my-parked-car/`
- “How do I set a parking meter reminder?” → `/parking-meter-reminder/`
- “How do I remember where I parked in a garage?” → `/parking-garage-tips/`

The homepage uses descriptive title and heading copy, visible concise answers, internal links, `SoftwareApplication` and `FAQPage` JSON-LD, a sitemap, and robots file. Google recommends descriptive, concise title text and requires structured data to match visible page content: [title link guidance](https://developers.google.com/search/docs/appearance/title-link) and [software app structured data](https://developers.google.com/search/docs/appearance/structured-data/software-app).

## Before public use

1. Complete trademark review in relevant markets.
2. Recheck App Store, search-engine, social-handle, GitHub, and domain collisions.
3. Acquire the selected domain.
4. Replace or confirm candidate canonical URLs, then deploy and verify HTTPS, redirects, sitemap, and Search Console.
