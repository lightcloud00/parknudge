# ParkNudge search-engine handoff

This is the product-owned contract for the shared cross-portfolio search-growth system. **Google Engine**, **Bing Engine**, **Search Engine**, **SEO Engine**, **AEO Engine**, and **ASO Engine** are aliases for that one system. Google Search Console and Bing Webmaster Tools are provider inputs; neither is a separate product or evidence that a URL is indexed.

The machine-readable companion is [`SEARCH-ENGINE.json`](SEARCH-ENGINE.json). ParkNudge issue [#25](https://github.com/lightcloud00/parknudge/issues/25) owns the product lane. The private runtime is owned by [search-growth-engine#1](https://github.com/lightcloud00/search-growth-engine/issues/1), with the ParkNudge registry intake in [search-growth-engine#10](https://github.com/lightcloud00/search-growth-engine/issues/10). [gusdigitalsolutions#103](https://github.com/lightcloud00/gusdigitalsolutions/issues/103) remains the legacy cross-portfolio rollout umbrella.

## Canonical contract

| Field | Current value |
|---|---|
| Product | ParkNudge |
| Repository | `lightcloud00/parknudge` |
| Website source | `site/` |
| Hosting target | Cloudflare Pages |
| Cloudflare project candidate | `parknudge` |
| Canonical origin candidate | `https://parknudge.app` |
| Domain state | Candidate only; ownership and DNS are unproven |
| Sitemap | `https://parknudge.app/sitemap.xml` |
| Robots | `https://parknudge.app/robots.txt` |
| LLM facts | `https://parknudge.app/llms.txt` |
| IndexNow key | Public verification file named in `SEARCH-ENGINE.json` |
| Temporary support | Public GitHub Issues with a warning not to post sensitive location data |

The candidate origin is intentionally consistent across source. It must not be called owned or live until [#10](https://github.com/lightcloud00/parknudge/issues/10) records ownership and [#11](https://github.com/lightcloud00/parknudge/issues/11) records public-edge acceptance.

## Evidence ladder

1. **Source-ready:** static checks pass for metadata, structured data, canonical/sitemap parity, crawler files, Cloudflare assets, and the handoff manifest.
2. **Merged:** the accepted pull request is merged and remote `main` resolves to the recorded commit and tree.
3. **Deployed:** Cloudflare serves that exact source with working HTTPS, redirects, navigation, and a real 404 response.
4. **Provider-verified:** the final domain is read back as owned in Google Search Console and Bing Webmaster Tools.
5. **Submitted:** sitemap and IndexNow requests have timestamped provider receipts. Submission is not indexing proof.
6. **Observed:** provider reports show indexed pages, impressions, queries, clicks, and positions for explicit date ranges. Missing data is unknown, not zero.
7. **Business outcome:** App Store acquisition and verified StoreKit/App Store proceeds—not search configuration—prove installs or revenue.

## Launch procedure

1. Recheck the ParkNudge name and `parknudge.app`, obtain explicit purchase approval, record registrar/renewal/DNS control, and finalize a privacy-safe support channel in #10.
2. Replace this contract and every canonical only if the approved owned origin differs. Run `python3 site/scripts/check_site.py` before publication.
3. Create or connect the Cloudflare Pages project, attach the owned domain, configure apex as preferred host, redirect `www` and the Pages subdomain, and deploy the exact accepted commit under #11.
4. Read back HTTPS, status codes, redirects, canonical tags, `robots.txt`, `sitemap.xml`, `llms.txt`, JSON-LD, the IndexNow key, mobile/desktop layout, console, and navigation from the public edge.
5. Verify the domain in Google Search Console and Bing Webmaster Tools. Submit the sitemap to both. Submit only public HTTP 200 changed URLs through IndexNow.
6. Record provider, property/site identity, timestamp, request digest, response, screenshot/export path, deployed commit, and caveats without recording credentials.
7. Establish the aggregate baseline in #14, then use verified query clusters to drive one bounded content experiment at a time in #23.

## Stop gates

This source contract does not purchase a domain, mutate DNS or Cloudflare, deploy a site, verify a provider property, submit URLs, enable paid tools, buy traffic, or release the iOS app. Those actions require their issue-specific authority and public/provider readback.
