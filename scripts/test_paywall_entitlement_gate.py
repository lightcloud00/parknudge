"""Source contract for the paywall's unresolved-entitlement branch (#79).

While the App Store has not said whether this Apple ID owns Lifetime Pro,
PaywallView must show the verifying state with Check Again, never the buy
button. The XCUITests cannot reach that state (the UI-test purchase provider
answers only free or pro), so this pins the view's branch from its source.
"""

from __future__ import annotations

import re
import unittest
from pathlib import Path

PAYWALL = Path(__file__).resolve().parent.parent / "ParkNudge" / "UI" / "Paywall" / "PaywallView.swift"
GATE = "if model.isEntitlementUnresolved {"
BUY_ID = '"purchase-lifetime-pro"'


def block_after(source: str, open_index: int) -> tuple[str, int]:
    """Text inside the braces opening at `open_index`, and the index after its close."""
    depth = 0
    in_string = False
    i = open_index
    while i < len(source):
        ch = source[i]
        if in_string:
            if ch == "\\":
                i += 2
                continue
            if ch == '"':
                in_string = False
        elif ch == '"':
            in_string = True
        elif ch == "{":
            depth += 1
        elif ch == "}":
            depth -= 1
            if depth == 0:
                return source[open_index + 1:i], i + 1
        i += 1
    raise AssertionError("unbalanced braces")


def gate_branches(source: str) -> tuple[str, str]:
    """The `if model.isEntitlementUnresolved` branch and its `else` branch."""
    start = source.find(GATE)
    if start < 0:
        raise AssertionError(f"PaywallView no longer branches on `{GATE}`")
    if_body, after = block_after(source, start + len(GATE) - 1)
    rest = source[after:]
    match = re.match(r"\s*else\s*\{", rest)
    if not match:
        raise AssertionError("the unresolved-entitlement branch has no else")
    else_body, _ = block_after(rest, match.end() - 1)
    return if_body, else_body


def property_body(source: str, name: str) -> str:
    match = re.search(rf"var {name}\b[^{{]*\{{", source)
    if not match:
        raise AssertionError(f"PaywallView has no `{name}`")
    body, _ = block_after(source, match.end() - 1)
    return body


class PaywallEntitlementGateTests(unittest.TestCase):
    def setUp(self) -> None:
        self.source = PAYWALL.read_text(encoding="utf-8")

    def test_buy_button_exists_only_when_the_store_has_answered(self) -> None:
        if_body, else_body = gate_branches(self.source)
        self.assertIn("entitlementVerification", if_body)
        self.assertNotIn(BUY_ID, if_body)
        self.assertIn(BUY_ID, else_body)
        self.assertEqual(self.source.count(BUY_ID), 1, "a second buy button would bypass the gate")

    def test_check_again_asks_the_store_again(self) -> None:
        body = property_body(self.source, "entitlementVerification")
        self.assertIn("model.retryEntitlementLookup()", body)
        self.assertIn('"retry-entitlement-lookup"', body)
        self.assertIn('"paywall-verifying-entitlement"', body)


if __name__ == "__main__":
    unittest.main()
