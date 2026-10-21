# Pip the Pin · source art

ParkNudge's approved mascot (Gus, 2026-10-21, decision D6). These five SVGs are the Light exports of
`Mascot / Pip the Pin` (`25:101`) on page `25:2` of the Figma file `SKTbMZZ47D5cyjXPgjntK5`, exported as
SVG from the plugin API on 2026-10-21.

| File | State | Figma variant | Used for |
|---|---|---|---|
| `idle.svg` | Idle | `25:26` | Onboarding screens 1 and 2 |
| `nudge.svg` | Nudge | `25:47` | Onboarding 3; Park tab with 15 to 5 minutes left |
| `sleepy.svg` | Sleepy | `25:62` | Onboarding 4; Park tab with no meter or more than 15 minutes left |
| `alarm.svg` | Alarm | `25:81` | Onboarding 5; Park tab from 5 minutes left and after expiry |
| `happy.svg` | Happy | `25:98` | Onboarding 6; paywall hero |

Don't edit the image sets in `ParkNudge/Resources/Assets.xcassets/Mascot` by hand. Change the SVG here, or
re-export it from Figma, then run:

```bash
python3 scripts/generate_pip_assets.py
```

The script writes the Light SVG and a Dark SVG into each image set. It makes the Dark one by swapping the four
`ParkNudge / Color` values that differ between the file's Light and Dark modes. `./scripts/verify.sh` runs it with
`--check` and fails if the catalog drifts.
