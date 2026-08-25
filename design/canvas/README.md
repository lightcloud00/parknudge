# ParkNudge — design canvas

**Canvas:** https://claude.ai/code/artifact/fb729515-1f77-4920-b2ad-0ea03705bdb9

Nine artboards over two pages. It is titled "App Store Kit" but is broader than one:

**Screens** — Park (meter running), Park (empty), History, the save/edit sheet,
Settings & paywall, the meter hero in four states, and the design-token board.

**Icon & Store** — app-icon concepts (with the shipped icon alongside for
comparison) and the 6.9" App Store frames.

## Why these files exist

Recovered on 2026-08-25 by extracting the published artifact. The canvas had been
built and published in an earlier session, but **its `.dc.html` sources were never
committed to any branch** — so the only copy lived inside the published page, and
any later change would have had to be made by hand in the browser editor.

## A real defect this found

The published canvas was clipping. `canvas.json` declared frames smaller than the
artboards' real rendered size on five boards, and an artboard frame does not scale
or crop — content past it is simply cut off. The worst was the **design-token
board, declared 900×1080 against a real 900×1297: 217px of tokens were not
visible** to anyone opening the link. `SettingsPaywall`, `MeterStates`, `AppIcon`
and `StoreFrames` were off by 16–236px each.

Every frame now matches its measured root, and the canvas has been republished
to the same URL. Nothing about the artboards themselves changed.

## Changing it

Edit the `.dc.html` files here, re-seed, republish to the **same** URL. Extract the
live page first if anyone may have edited it in the browser.

```bash
node ~/.claude/skills/design-canvas-verify/scripts/check-structure.mjs
node ~/.claude/skills/design-canvas-verify/scripts/measure.mjs --port 8961
```

`check-structure` reports one false positive here: it reads `AppIcon.dc.html`'s
root as 60×60, picking up an inner element. The root is `width: 940px` with auto
height, and `measure.mjs` — a real layout engine — reports 940×894. Trust the
measurement.

## Palette

The app's palette is the asset catalog at `ParkNudge/Resources/Assets.xcassets`
(nine colorsets: BrandCream, BrandInk, BrandNavy, BrandOrange, the Meter alert and
warn pairs, and AccentColor). The token board proposes a `ParkNudgeTheme.swift`
that does **not exist yet** — it would replace the four ad-hoc corner radii and the
hardcoded `.orange` currently spread across five view files. Until that lands, this
board is a proposal, not a mirror.
