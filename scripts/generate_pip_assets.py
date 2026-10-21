#!/usr/bin/env python3
"""Builds the Pip the Pin image sets from the Figma SVG exports.

`design/mascot/pip/*.svg` are the Light-mode exports of the approved
`Mascot / Pip the Pin` set (Figma file SKTbMZZ47D5cyjXPgjntK5, page 25:2).
The Dark appearance is derived here by swapping the `ParkNudge / Color`
values that differ between the file's Light and Dark modes, so the catalog
can never hold a dark Pip that disagrees with the light one.

Run with no arguments to write the image sets. `--check` exits non-zero when
the committed catalog no longer matches what this script would write.
"""

from __future__ import annotations

import json
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
SOURCE = ROOT / "design" / "mascot" / "pip"
CATALOG = ROOT / "ParkNudge" / "Resources" / "Assets.xcassets" / "Mascot"
STATES = ("idle", "nudge", "sleepy", "alarm", "happy")

# Light value -> Dark value, read from the Dark row of page 25:2 (2026-10-21).
DARK_SWAPS = (
    ('fill-opacity="0.12"', 'fill-opacity="0.24"'),  # fill/tertiary (ground shadow)
    ("#031738", "#0A1F45"),  # Theme.navy (eyes, mouth, brows)
    ("#3C3C43", "#EBEBF5"),  # label/secondary (z's, nudge ticks)
    ("#B3261E", "#FF6B60"),  # Theme.alertInk (alarm marks)
)

FOLDER_CONTENTS = {"info": {"author": "xcode", "version": 1}}


def image_set_contents(state: str) -> dict:
    return {
        "images": [
            {"filename": f"pip-{state}.svg", "idiom": "universal"},
            {
                "appearances": [{"appearance": "luminosity", "value": "dark"}],
                "filename": f"pip-{state}-dark.svg",
                "idiom": "universal",
            },
        ],
        "info": {"author": "xcode", "version": 1},
        "properties": {"preserves-vector-representation": True},
    }


def dark_variant(svg: str) -> str:
    for light, dark in DARK_SWAPS:
        svg = svg.replace(light, dark)
    return svg


def expected_files() -> dict[Path, str]:
    files: dict[Path, str] = {
        CATALOG / "Contents.json": json.dumps(FOLDER_CONTENTS, indent=2) + "\n",
    }
    for state in STATES:
        light = (SOURCE / f"{state}.svg").read_text()
        image_set = CATALOG / f"Pip{state.capitalize()}.imageset"
        files[image_set / f"pip-{state}.svg"] = light
        files[image_set / f"pip-{state}-dark.svg"] = dark_variant(light)
        files[image_set / "Contents.json"] = json.dumps(image_set_contents(state), indent=2) + "\n"
    return files


def main() -> int:
    files = expected_files()
    if "--check" in sys.argv[1:]:
        drifted = [path for path, text in files.items() if not path.is_file() or path.read_text() != text]
        known = set(files)
        extra = [path for path in CATALOG.rglob("*") if path.is_file() and path not in known]
        for path in drifted + extra:
            print(f"Pip asset drift: {path.relative_to(ROOT)}", file=sys.stderr)
        if drifted or extra:
            print("Run python3 scripts/generate_pip_assets.py and commit the result.", file=sys.stderr)
            return 1
        print(f"Pip assets match design/mascot/pip ({len(STATES)} states, Light and Dark).")
        return 0

    for path, text in files.items():
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(text)
    print(f"Wrote {len(files)} Pip asset files under {CATALOG.relative_to(ROOT)}.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
