# ParkNudge GitHub issue execution plan

The [GitHub issue queue](https://github.com/lightcloud00/parknudge/issues) is the operational roadmap. This document defines sequencing, dependencies, and proof so an open checkbox cannot be mistaken for a completed release gate.

## Current handoff order

1. Finish [#1](https://github.com/lightcloud00/parknudge/issues/1): make the committed verification workflow pass on an exact SHA and record unit, UI, Release, and forbidden-content audit evidence.
2. Run the physical-device lanes [#2](https://github.com/lightcloud00/parknudge/issues/2)–[#5](https://github.com/lightcloud00/parknudge/issues/5). These can proceed independently after a build is installable.
3. Resolve identity [#6](https://github.com/lightcloud00/parknudge/issues/6), then configure and accept commerce [#7](https://github.com/lightcloud00/parknudge/issues/7).
4. Finalize metadata/legal/screenshots [#8](https://github.com/lightcloud00/parknudge/issues/8), then run the beta gate [#9](https://github.com/lightcloud00/parknudge/issues/9).
5. Acquire the final domain [#10](https://github.com/lightcloud00/parknudge/issues/10), deploy and verify the site [#11](https://github.com/lightcloud00/parknudge/issues/11).
6. Install the revenue foundation [#14](https://github.com/lightcloud00/parknudge/issues/14), [#15](https://github.com/lightcloud00/parknudge/issues/15), [#18](https://github.com/lightcloud00/parknudge/issues/18), and [#24](https://github.com/lightcloud00/parknudge/issues/24).
7. Run organic experiments [#16](https://github.com/lightcloud00/parknudge/issues/16), [#17](https://github.com/lightcloud00/parknudge/issues/17), [#19](https://github.com/lightcloud00/parknudge/issues/19), and [#23](https://github.com/lightcloud00/parknudge/issues/23) from the baseline, not simultaneously on overlapping variables.
8. Review price [#20](https://github.com/lightcloud00/parknudge/issues/20), refresh trends [#21](https://github.com/lightcloud00/parknudge/issues/21), and only then prepare the paid gate [#22](https://github.com/lightcloud00/parknudge/issues/22).
9. Promote validated post-MVP value from [#12](https://github.com/lightcloud00/parknudge/issues/12) and [#13](https://github.com/lightcloud00/parknudge/issues/13); neither is a launch blocker.

## Milestone map

| Milestone | Issues | Exit evidence |
|---|---|---|
| [Local Verification](https://github.com/lightcloud00/parknudge/milestone/1) | #1 | Exact SHA, deterministic generator, unit/UI pass, Release build, release-content audit |
| [Device & Accessibility Acceptance](https://github.com/lightcloud00/parknudge/milestone/2) | #2–#5 | Physical-device receipts for GPS, Maps, camera, notifications, Focus, accessibility, appearance, and layouts |
| [Commerce & Beta](https://github.com/lightcloud00/parknudge/milestone/3) | #6–#9 | Cleared identity, approved IAP metadata, Sandbox outcomes, legal/metadata, installed TestFlight beta |
| [Website Launch](https://github.com/lightcloud00/parknudge/milestone/4) | #10–#11 | Owned domain, public HTTPS/redirect/canonical/sitemap/Search Console readback |
| [v1.1](https://github.com/lightcloud00/parknudge/milestone/5) | #12–#13 | Demand, privacy, battery, design, implementation, and device evidence for any promoted candidate |
| [Revenue Foundation](https://github.com/lightcloud00/parknudge/milestone/6) | #14, #15, #18, #20, #24 | Aggregate scorecard, respectful rating flow, promoted purchase acceptance, price decision, protected feedback loop |
| [Organic Growth Experiments](https://github.com/lightcloud00/parknudge/milestone/7) | #16, #17, #19, #21, #23 | Controlled App Store/web experiments and timestamped market/localization decisions |
| [Paid Growth Gate](https://github.com/lightcloud00/parknudge/milestone/8) | #22 | Approved budget packet, caps and stop rules; activation is not implied |

## Standard issue lifecycle

### Ready

- Dependencies are closed or their exact usable evidence is linked.
- The issue describes one outcome, in-scope files/systems, non-goals, and acceptance checks.
- External authority is explicit: local implementation, device work, App Store Connect, deployment, or spend.

### Implement

- Preserve unrelated owner work and generate the project from canonical `project.yml`.
- Add focused tests before broad gates.
- Keep privacy, free/Pro boundaries, local data retention, and StoreKit verification centralized.
- Do not combine independent conversion experiments or claim provider-unavailable data as zero.

### Verify

- Record exact commit SHA/tree and commands.
- Attach focused and full applicable test results.
- For external state, read back the public/provider/device result; source code alone is not acceptance.
- Run secret/content audits before publication and preserve redacted evidence.

### Close and hand off

- Comment the issue with the exact evidence and remaining caveats.
- Close only when every acceptance item is proved; otherwise keep it open with the smallest next action.
- Update `README.md`, `Docs/ROADMAP.md`, the relevant product/revenue document, and the canonical Obsidian/Hindsight project state when durable truth changes.

## Protected gates

The roadmap does not authorize domain purchase, public deployment, Apple account mutation, signing/upload, TestFlight distribution, App Review submission, paid advertising, or release. Each requires the exact authority and readback named in its issue.
