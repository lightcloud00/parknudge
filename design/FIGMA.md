# ParkNudge · Figma file

**File:** [ParkNudge · App](https://www.figma.com/design/SKTbMZZ47D5cyjXPgjntK5) (file key `SKTbMZZ47D5cyjXPgjntK5`)
**Recorded from:** `main` @ `a87a6b2` (2026-10-13). File built 2026-10-14.
**Font:** SF Pro, which was available in the file, so nothing was substituted. SF Symbols are real glyphs.

This is the third design source for ParkNudge. The other two are the Claude Design canvases in
`design/canvas/` and `design/canvas-project/`. Both are still kept, and the Figma file uses them as
layout references only. The Swift on `main` is the source of truth for every string and state.

## Status legend

| Tag | Meaning |
|---|---|
| **Shipped** | On `main` a87a6b2. Copy, states and tokens are copied verbatim from the Swift. This is not proof of what is in App Store review. |
| **Proposed** | Not approved. Waits for Gus. |
| **Open** | A decision only Gus can make. Nothing is ticked. |

## Pages

| Page | Node ID | Contents |
|---|---|---|
| Cover | `0:1` | Title, source ref, status legend, page index, release-status note, component → Swift code map, font note |
| 01 · Foundations | `2:2` | Specimen board `16:414`: 35 live colour tokens (Light and Dark), 10 metrics, text styles, effect style |
| 02 · Components | `2:3` | Section `8:335` with 19 components and sets (below) |
| Shipped · Screens (record from main a87a6b2) | `2:4` | Section `9:353` with 14 screen components, 393 wide |
| Shipped · Dark appearance (record) | `2:5` | Section `12:4` with 4 screen instances, the Dark mode set on each wrapper |
| Proposed · App Store 6.9″ frames (2026-10-14) | `2:6` | Section `13:7` with 4 frames at 1320×2868, plus a listing-metadata panel |
| Proposed · Mascot · Claude (2026-10-20) | `25:2` | Section `25:7`: two mascot concepts, 5 states each in Light and Dark (below) |
| Proposed · Onboarding · Claude (2026-10-20) | `27:2` | Section `27:7`: 6 onboarding screens at 393×852, the Mascot Slot component, flow rules |
| Proposed · Paywall v2 (freemium) · Claude (2026-10-20) | `29:2` | Section `29:7`: 3 paywall frames (2 triggers, plus Dark) and a Free vs Pro spec |
| Decisions · open (2026-10-14) | `2:7` | Board `14:2` with 6 decision cards (D6 partly decided) and 9 source defects |

## Tokens

- **`ParkNudge / Color`** has two modes, Light and Dark, taken from `UI/Shared/ParkNudgeTheme.swift` and
  `Resources/Assets.xcassets`. Each variable's iOS code syntax is its Swift name, for example `Theme.brandInk`.
  Alpha tints are separate variables (`tint/brand-ink-15`, `meter/*-secondary`). The `decor/*`, `bg/bar` and
  `bg/tag` variables exist only in Figma, as stand-ins for MapKit and system materials.
- **`ParkNudge / Metrics`**: `radius/card` 20, `radius/tile` 14, `radius/inline` 8, `radius/chip` 5,
  `radius/grouped` 10, `radius/button` 12, `size/hit-target` 44, `size/primary-control` 50,
  `space/screen` 16, `space/stack` 12.
- **Text styles** follow iOS default sizes in SF Pro: `iOS/*`, `ParkNudge/Meter Digits` (52 Semibold),
  `ParkNudge/Meter Digits Urgent` (52 Bold), `ParkNudge/Paywall Price` (44 Bold), `Symbol/*`, `Store/*` and `Doc/*`.
- **Effect style:** `Elevation/Floating`.
- An earlier partial run left duplicates behind: board `3:3` on 02 · Components, nine variables and four text
  styles. They are renamed `Superseded…`, hidden from pickers, and nothing current references them. They are
  safe to delete by hand.

## Components (page `2:3`)

| Component | Node ID | Swift |
|---|---|---|
| Button (Style × State, 6) | `8:50` | `ParkView.swift` actions, `PaywallView.swift` |
| Meter Hero (Running / Expiring soon / Expired) | `8:86` | `ParkView.swift` MeterHero, `Domain/Policies/MeterState.swift` |
| Chip (Duration / Cost / Meter ran out) | `8:58` | `HistoryView.swift` Chip, HistoryChips |
| History Row | `8:211` | `HistoryView.swift` HistoryRow |
| Details Card | `8:312` | `ParkView.swift` detailsCard |
| Map Card (Active / Editor / History detail) | `8:311` | `ParkView.swift` ParkedMap, `ParkingEditorView.swift`, `HistoryView.swift` HistoryDetailView |
| List Cell (11 kinds) | `8:195` | Form / insetGrouped List rows |
| List Section | `8:196` | Form / List Section pattern |
| Nav Bar (Large title / Inline / Sheet / Sheet close) | `8:143` | NavigationStack toolbars |
| Tab Bar (Selected = Park / History / Settings) | `8:117` | `RootTabView.swift` |
| Empty State Beat | `8:227` | `ParkView.swift` EmptyStateBeat |
| Content Unavailable | `8:330` | `HistoryView.swift` |
| Paywall Benefit Row | `8:230` | `PaywallView.swift` |
| Paywall Feature Banner | `8:233` | `PaywallView.swift` |
| Comparison Row (4 kinds) | `8:260` | `PaywallView.swift` ComparisonRow, `CommerceModels.swift` ProFeature |
| Paywall Glyph | `8:261` | `PaywallView.swift` hero image |
| Switch (On / Off) | `8:31` | SwiftUI Toggle |
| Status Bar · Home Indicator | `8:19` · `8:25` | iOS system chrome |

## Shipped screens (page `2:4`)

| # | Screen | Node ID | Swift |
|---|---|---|---|
| 01 | Park · Empty · first park free | `9:354` | `UI/Park/ParkView.swift` emptyContent |
| 02 | Park · Empty · free park used | `9:403` | `UI/Park/ParkView.swift` emptyContent |
| 03 | Park · Active · meter running | `9:442` | `UI/Park/ParkView.swift` activeContent |
| 04 | Park · Active · meter expiring soon | `9:527` | `ParkView.swift` MeterHero, `MeterState.swift` |
| 05 | Park · Active · meter expired | `9:604` | `ParkView.swift` MeterHero, `MeterState.swift` |
| 06 | Editor sheet · Save Parking Spot | `9:681` | `UI/Park/ParkingEditorView.swift` |
| 07 | History · Free with locked older sessions | `9:801` | `UI/History/HistoryView.swift` |
| 08 | History · Empty | `10:749` | `UI/History/HistoryView.swift` |
| 09 | History · Session detail | `10:783` | `UI/History/HistoryView.swift` HistoryDetailView |
| 10 | Settings · Free | `10:904` | `UI/Settings/SettingsView.swift` |
| 11 | Paywall · First park free | `10:996` | `UI/Paywall/PaywallView.swift` |
| 12 | Paywall · Free park used | `10:1049` | `UI/Paywall/PaywallView.swift` |
| 13 | Paywall · Original customer | `10:1102` | `UI/Paywall/PaywallView.swift` comparison |
| 14 | Paywall · Feature request banner | `10:1185` | `UI/Paywall/PaywallView.swift` |

No screens from the brief were cut. Frames taller than 852 are extended to their full scroll height.
`$9.99` appears only as the example U.S. StoreKit `displayPrice`, because the app never hardcodes a price.

**Dark appearance (page `2:5`):** wrappers `12:5` (03), `12:159` (06), `12:347` (07) and `12:502` (12).

## Proposed · App Store 6.9″ (page `2:6`). Not approved.

| Frame | Node ID | Caption | Device |
|---|---|---|---|
| 1 | `13:8` | Find my car · Remember where you parked | Screen 03, with the Pro-only cost row hidden |
| 2 | `13:167` | Meter timer · Get nudged before the meter runs out | Screen 04, plus the shipped notification copy |
| 3 | `13:334` | Stays on your iPhone · No account. No background tracking. | Screen 07 |
| 4 | `13:494` | Lifetime Pro · Your first park is free. | Screen 11 |

Frame 4 is rewritten for the 1.1 earned-unlock model, using the draft copy in `HARD-PAYWALL-RELEASE.md`.
The retired canvas caption, "$9.99 once … The whole parking loop is free forever.", is not reused.
The listing-metadata panel is `13:572`.

## Proposed · Mascot, Onboarding, Paywall v2 (2026-10-20). Gate change approved; the rest is proposed.

Every shape is bound to `ParkNudge / Color` and `ParkNudge / Metrics`, and the mascots are editable vectors with
no people in them.

Gus approved the freemium gate change on 2026-10-20 ("go ahead"). PR #66 merged it to `main` as `d3bb9b2`:
- **Free:** parking with unlimited saves, directions, notes, photos and the 15/5/0-minute reminders.
- **Lifetime Pro ($9.99 once):** full history (Free shows the last 3), custom reminder times, cost records and CSV export.

**It is not shipped.** App Store version 1.1 is still `PENDING_DEVELOPER_RELEASE`, with the old "first park free" gate.
Shipped screens 01, 02, 11, 12 and 13 and store frame 4 record `a87a6b2`, so they are the pre-freemium baseline.
The paywall frames use the copy that is now on `main`: the "Free / Pro" header and "Parking stays free. …".

Still proposed and waiting on D6 or later approval:
- the mascot pick
- the onboarding
- more than one saved spot
- the Live Activity
- the automatic 4th-session paywall

**Mascot (page `25:2`):** two concepts, side by side.

| Concept | Card | Component set | Variants (State) |
|---|---|---|---|
| A · Pip the Pin, a teardrop map pin with stubby arms | `25:8` | `Mascot / Pip the Pin` `25:101` | Idle `25:26`, Nudge `25:47`, Sleepy `25:62`, Alarm `25:81`, Happy `25:98` |
| B · Tock, a parking-meter owl with a clock-face belly | `25:102` | `Mascot / Tock` `25:245` | Idle `25:131`, Nudge `25:159`, Sleepy `25:185`, Alarm `25:215`, Happy `25:242` |

Each card has a Light row and a Dark row (the Dark mode is set on the row), plus a "when each state shows" list
and the trade-offs. The placement panel is `26:547`.

**Onboarding (page `27:2`):** 6 screens at 393×852. `main` has no onboarding.

| # | Screen | Node ID | Mascot Slot hint |
|---|---|---|---|
| 1 | Promise: "Find your car. Beat the meter." | `27:17` | Idle |
| 2 | Street meter, garage or lot | `27:58` | Idle |
| 3 | Location pre-prime (While Using only, shipped purpose string) | `27:109` | Nudge |
| 4 | First real save | `28:41` | Sleepy |
| 5 | Notification pre-prime: 15 and 5 min before (shipped copy and free offsets) | `28:106` | Alarm |
| 6 | Dismissible Pro teaser | `28:155` | Happy |

`Mascot Slot` `27:10` is a local component with a `Hint` text property. Swap each instance for the picked mascot
set. The flow rules are in `28:1900`.

**Paywall v2 (page `29:2`):** built from a detached copy of shipped screen 13. Lifetime Pro stays $9.99, one-time,
with no subscription.

| Frame | Node ID | Trigger |
|---|---|---|
| A | `29:130` | A Pro-feature tap; the banner names the feature (custom reminder times) |
| B | `29:270` | The 4th finished session, once, when History reaches the free cap of 3 |
| A · Dark | `29:324` | Frame A with the Dark mode |

The spec column `30:170` has the Free vs Pro table, the trigger rules, the price research (US App Store,
2026-10-20) and how it matches PR #66. Multiple saved spots, the Live Activity and the automatic 4th-session
trigger are not built.

## Open decisions (page `2:7`). Only D6's gate change is decided.

- **D1 `14:6`:** what frame 4 claims under the earned-unlock model.
- **D2 `14:27`:** whether the store art shows a price, given that StoreKit `displayPrice` varies by storefront.
- **D3 `14:48`:** app icon direction. The two canvases propose different sets (issue #31).
- **D4 `14:69`:** frame 3 privacy wording. Should "Nothing is uploaded anywhere." stay, given that MapKit search and directions send data to Apple?
- **D5 `14:90`:** which listing localizations get the 1.1 frames.
- **D6 `30:230`** (added 2026-10-20, partly decided):
  - **Gate: approved.** Option D replaces the "first park free, then pay" gate with freemium. Gus approved it on
    2026-10-20, and it is on `main` through PR #66.
  - **Mascot: open.** Gus still needs to pick Pip the Pin, Tock or no mascot.

## Defects noticed while recording (fix candidates)

1. While the editor sheet is open, "Add a parking cost with Pro" does nothing. The paywall sheet is attached behind the editor (`ParkingEditorView.swift:304`, `RootTabView.swift:22`). PR #62 fixes it.
2. Every other StoreKit error is reported as "The App Store could not be reached." (`PurchaseService.swift:164,169`).
3. After a closed CSV-export offer, Restore in Settings skips its "restored" alert (`AppModel.swift:306,313–314,396`).
4. The History detail map marker is still `.tint(.orange)` (`HistoryView.swift:241`), not `Theme.brand`.
5. History detail always labels the meter row "Expired" (`HistoryView.swift:274`), even when the session ended before expiry.
6. The empty-state beat says "bay" (`ParkView.swift:101`), but the editor and the details card say "Section".
7. The repo canvases still carry retired copy: "free forever" and "The parking loop stays free". They also give a 1290×2796 size against 1320×2868, use "Level 3 · Bay 14", and show notification text that differs from the shipped copy.
8. Issue #8 records that the App Store listing still shows 1.0-era screenshot copy.
9. `Docs/RELEASE-GATES.md` ("Beta: Not uploaded", "Release: Not authorized") looks stale.

## Known gaps

- The app icon is a vector stand-in redrawn from `AppIcon-1024.png`. The agent's network proxy returned 403
  for every Figma upload host, so `upload_assets` could not run. Place the real PNG by hand.
- Maps and the parking photo are drawn as labelled stand-ins (MapKit is decorative).
- There is no Code Connect.
