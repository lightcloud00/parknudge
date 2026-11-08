"""Tests for scripts/xcresult_counts.py, the verify.sh test-count check."""

from __future__ import annotations

import io
import json
import sys
import unittest
from contextlib import redirect_stderr, redirect_stdout
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))

import xcresult_counts  # noqa: E402

# Shape printed by `xcrun xcresulttool get test-results summary` (Xcode 16+);
# the counts are L1b's 2026-11-08 run of verify.sh on ParkNudge 1.2.1 (8).
PASSING = {
    "title": "Test - ParkNudge",
    "result": "Passed",
    "totalTestCount": 157,
    "passedTests": 157,
    "failedTests": 0,
    "skippedTests": 0,
    "expectedFailures": 0,
    "devicesAndConfigurations": [],
    "testFailures": [],
    "topInsights": [],
    "statistics": [],
}


def run(summary, *args: str) -> tuple[int, str, str]:
    stdin, out, err = sys.stdin, io.StringIO(), io.StringIO()
    sys.stdin = io.StringIO(summary if isinstance(summary, str) else json.dumps(summary))
    try:
        with redirect_stdout(out), redirect_stderr(err):
            code = xcresult_counts.main(list(args))
    finally:
        sys.stdin = stdin
    return code, out.getvalue(), err.getvalue()


class XCResultCountsTests(unittest.TestCase):
    def test_a_passing_run_passes_and_prints_the_counts(self):
        code, out, _ = run(PASSING, "--min-tests", "150")
        self.assertEqual(code, 0)
        self.assertIn("157 tests: 157 passed, 0 failed, 0 skipped", out)

    def test_an_empty_run_fails(self):
        code, _, err = run(dict(PASSING, totalTestCount=0, passedTests=0))
        self.assertEqual(code, 1)
        self.assertIn("0 tests ran", err)
        self.assertIn("no test passed", err)

    def test_fewer_tests_than_the_floor_fail(self):
        code, _, err = run(PASSING, "--min-tests", "200")
        self.assertEqual(code, 1)
        self.assertIn("at least 200 required", err)

    def test_a_failure_fails_even_if_the_exit_code_was_zero(self):
        code, _, err = run(dict(PASSING, passedTests=156, failedTests=1, result="Failed"))
        self.assertEqual(code, 1)
        self.assertIn("1 tests failed", err)
        self.assertIn("'Failed'", err)

    def test_a_changed_schema_fails_loudly_instead_of_passing(self):
        code, _, err = run({"result": "Passed", "tests": 157})
        self.assertEqual(code, 1)
        self.assertIn("no integer totalTestCount", err)

    def test_non_json_fails(self):
        code, _, err = run("** TEST SUCCEEDED **")
        self.assertEqual(code, 1)
        self.assertIn("not JSON", err)


if __name__ == "__main__":
    unittest.main()
