# App Store keyword refresh, 2026-11-07

This repo keeps no checked-in App Store text file, so this note holds the proposed fields. Source: search keyword plan `2026-11-07-search-keyword-plan`. The fields ship with the next app version. Nothing was sent to App Store Connect.

## en-US

- Name (unchanged): `ParkNudge: Parking Reminder`
- Subtitle (unchanged, 29 characters): `Save Your Spot, Find Your Car`
- Keywords (96 UTF-8 bytes of 100; all ASCII): `park,locator,where,did,meter,timer,garage,lot,walk,alert,history,cost,csv,navigate,street,expire`

Live 1.2 field for comparison: `parked,locator,finder,where,timer,garage,notes,cost,history,csv,return,alert,lot,navigate`.

Why: "where did i park" gets about 440 searches a month and is easy to rank for (difficulty 14). The new field drops words already in the name and subtitle ("parking", "reminder", "save", "spot", "find", "car") and adds the words of that question.

Checks before this ships:
- Checked against source on 2026-11-08 (L7 and L7b reviews), so every word matches the build. `street`: the "Street meter" parking style (`Domain/Models/ParkingStyle.swift`). `expire`: the "Parking meter expired" notification (`Platform/NotificationService.swift`). `garage` and `lot`: parking styles. `walk` and `navigate`: walking directions to the saved spot. `meter`, `timer` and `alert`: meter reminders.
- `history`, `cost` and `csv` are Lifetime Pro features (unlimited parking history, parking cost records, CSV export; `Domain/Models/CommerceModels.swift`), and free keeps a short history. The description must keep saying which features need Pro (guideline 2.3.2).
- The name and subtitle above come from the 11-07 App Store Connect pull, and no file in this repo records them. `Docs/NAMING-ASO-AEO-SEO.md` still drafts a different name and subtitle. Confirm the live subtitle in App Store Connect before pasting. If it contains "meter" or "timer", drop that word here, because it would repeat the subtitle.
- Keywords are search terms, not claims. The listing text still has to describe only what the build does.

No es-MX field: the data shows no Mexican demand for ParkNudge.
