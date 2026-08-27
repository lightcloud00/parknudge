# ParkNudge — Claude Design project canvas

**Canvas:** https://claude.ai/design/p/a555acd5-3448-41f7-a4ce-a82e13fbda07

Eight boards: a system sheet, the four screens, the paywall, store frames and icons.

## This is not the canvas in `design/canvas/`

The repo already tracks a different one, with a different naming scheme. They are separate
pieces of work and live in separate directories rather than being merged:

| Directory | What it is | Where it came from |
|---|---|---|
| `design/canvas/` | `Main`, `ParkEmpty`, `Editor`, `History`, `MeterStates`, `SettingsPaywall`, `StoreFrames`, `AppIcon`, `Tokens` | recovered from a published Artifact, 2026-08-25 |
| `design/canvas-project/` | this one — `00-system` … `07-icons` | Claude Design project, backed up 2026-08-27 |

Neither supersedes the other. Check both before assuming a screen is undrawn.

## Fidelity

Every board was exported through the project's own preview endpoint and **verified
byte-exact against the size `list_files` reports**. The preview injects a runtime harness
ahead of the file's own `<meta charset=…>`; stripping it and restoring the authored head
opening reproduces the original exactly, and a wrong guess at the head form fails loudly
rather than writing a near-copy.

The Design project stays canonical for these eight: edit there, then re-export here.
`support.js` is untracked — a 66 KB editor runtime and a build input, not source.
