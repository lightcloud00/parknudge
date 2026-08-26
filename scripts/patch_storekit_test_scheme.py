#!/usr/bin/env python3
"""Bind ParkNudge's StoreKit fixture to the generated test action.

XcodeGen 2.45.4 emits the configured fixture for the run action but omits the
equivalent test-action reference. StoreKitTest purchase behavior must use the
checked-in fixture, so this post-generation hook adds the missing XML fragment
deterministically.
"""

from __future__ import annotations

from pathlib import Path


ROOT = Path(__file__).resolve().parent.parent
SCHEME = ROOT / "ParkNudge.xcodeproj" / "xcshareddata" / "xcschemes" / "ParkNudge.xcscheme"
STOREKIT_REFERENCE = "../../ParkNudge/Resources/ParkNudge.storekit"
FRAGMENT = (
    "      <StoreKitConfigurationFileReference\n"
    f'         identifier = "{STOREKIT_REFERENCE}">\n'
    "      </StoreKitConfigurationFileReference>\n"
)


def main() -> int:
    if not SCHEME.is_file():
        raise SystemExit(f"missing generated scheme: {SCHEME}")

    text = SCHEME.read_text(encoding="utf-8")
    if text.count("<TestAction") != 1 or text.count("</TestAction>") != 1:
        raise SystemExit(f"unexpected TestAction shape: {SCHEME}")

    start = text.index("<TestAction")
    end = text.index("</TestAction>", start)
    test_action = text[start:end]
    if STOREKIT_REFERENCE not in test_action:
        if test_action.count("</Testables>") != 1:
            raise SystemExit(f"unexpected Testables shape: {SCHEME}")
        insertion = text.index("</Testables>", start, end) + len("</Testables>")
        text = text[:insertion] + "\n" + FRAGMENT.rstrip("\n") + text[insertion:]
        SCHEME.write_text(text, encoding="utf-8")

    readback = SCHEME.read_text(encoding="utf-8")
    test_start = readback.index("<TestAction")
    test_end = readback.index("</TestAction>", test_start)
    if readback[test_start:test_end].count(STOREKIT_REFERENCE) != 1:
        raise SystemExit(f"StoreKit test reference was not applied exactly once: {SCHEME}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
