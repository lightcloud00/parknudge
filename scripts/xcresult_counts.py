#!/usr/bin/env python3
"""Fail verification unless a test run really ran and really passed.

`xcodebuild test-without-building` exiting 0 does not prove that tests ran: a
scheme or test-plan change can leave a target with nothing selected and the
run still "succeeds". This reads the summary that
`xcrun xcresulttool get test-results summary --path <bundle>` prints (JSON on
stdin or in a file) and requires a passing result, no failures, and at least
`--min-tests` tests.

Usage:
  xcrun xcresulttool get test-results summary --path X.xcresult \
    | python3 scripts/xcresult_counts.py --min-tests 1
"""

from __future__ import annotations

import argparse
import json
import sys
from typing import Any

REQUIRED = ("totalTestCount", "passedTests", "failedTests", "skippedTests")


def problems(summary: Any, min_tests: int) -> list[str]:
    if not isinstance(summary, dict):
        return ["the xcresult summary is not a JSON object"]
    missing = [key for key in REQUIRED if not isinstance(summary.get(key), int)]
    if missing:
        found = ", ".join(sorted(summary)) or "none"
        return [f"the xcresult summary has no integer {', '.join(missing)} (keys found: {found})"]

    found: list[str] = []
    total = summary["totalTestCount"]
    passed = summary["passedTests"]
    failed = summary["failedTests"]
    if total < min_tests:
        found.append(f"{total} tests ran; at least {min_tests} required")
    if passed == 0:
        found.append("no test passed")
    if failed:
        found.append(f"{failed} tests failed")
    result = summary.get("result")
    if result is not None and result != "Passed":
        found.append(f"result is {result!r}, not 'Passed'")
    return found


def describe(summary: dict) -> str:
    return (
        f"{summary['totalTestCount']} tests: {summary['passedTests']} passed, "
        f"{summary['failedTests']} failed, {summary['skippedTests']} skipped"
    )


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("summary", nargs="?", help="summary JSON file (default: stdin)")
    parser.add_argument("--min-tests", type=int, default=1)
    args = parser.parse_args(argv)

    raw = open(args.summary, encoding="utf-8").read() if args.summary else sys.stdin.read()
    try:
        summary = json.loads(raw)
    except json.JSONDecodeError as error:
        print(f"xcresult summary is not JSON: {error}", file=sys.stderr)
        return 1

    found = problems(summary, args.min_tests)
    if found:
        print("Test result check failed:", file=sys.stderr)
        for line in found:
            print(f"  - {line}", file=sys.stderr)
        return 1
    print(f"Test result check passed: {describe(summary)}.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
