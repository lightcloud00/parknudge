"""Tests for scripts/audit-release.sh: each check must fail closed.

The audit runs against a fake Release product built in a temp directory.
PlistBuddy and plutil are replaced by small Python stand-ins so the logic is
tested the same way on macOS and Linux; the real tools still run in verify.sh.
"""

from __future__ import annotations

import os
import plistlib
import re
import shutil
import subprocess
import tempfile
import textwrap
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
AUDIT = ROOT / "scripts" / "audit-release.sh"
PRIVACY = ROOT / "ParkNudge" / "Resources" / "PrivacyInfo.xcprivacy"
PROJECT_YML = (ROOT / "project.yml").read_text(encoding="utf-8")


def project_setting(key: str) -> str:
    return re.search(rf'^\s*{key}:\s*"?([^"\s]+)"?\s*$', PROJECT_YML, re.M).group(1)


VERSION = project_setting("MARKETING_VERSION")
BUILD = project_setting("CURRENT_PROJECT_VERSION")

PLISTBUDDY = textwrap.dedent(
    """\
    #!/usr/bin/env python3
    import plistlib, sys
    command, path = sys.argv[2], sys.argv[3]
    key = command.split(":", 1)[1]
    with open(path, "rb") as handle:
        data = plistlib.load(handle)
    if key not in data:
        print(f'Print: Entry, ":{key}", Does Not Exist', file=sys.stderr)
        sys.exit(1)
    print(data[key])
    """
)
PLUTIL = textwrap.dedent(
    """\
    #!/usr/bin/env python3
    import plistlib, sys
    with open(sys.argv[-1], "rb") as handle:
        plistlib.load(handle)
    """
)


@unittest.skipUnless(shutil.which("rg") and shutil.which("bash"), "needs bash and rg")
class AuditReleaseTests(unittest.TestCase):
    def setUp(self):
        self.temp = Path(tempfile.mkdtemp())
        self.addCleanup(shutil.rmtree, self.temp)
        self.tools = self.temp / "tools"
        self.tools.mkdir()
        for name, body in (("PlistBuddy", PLISTBUDDY), ("plutil", PLUTIL)):
            tool = self.tools / name
            tool.write_text(body, encoding="utf-8")
            tool.chmod(0o755)
        self.derived = self.temp / "DerivedData"
        self.app = self.derived / "Build" / "Products" / "Release-iphonesimulator" / "ParkNudge.app"
        self.app.mkdir(parents=True)
        shutil.copy(PRIVACY, self.app / "PrivacyInfo.xcprivacy")
        self.write_info()

    def write_info(self, **changes):
        info = {"CFBundleShortVersionString": VERSION, "CFBundleVersion": BUILD, **changes}
        with open(self.app / "Info.plist", "wb") as handle:
            plistlib.dump({k: v for k, v in info.items() if v is not None}, handle)

    def audit(self):
        env = dict(os.environ)
        env["PATH"] = f"{self.tools}{os.pathsep}{env.get('PATH', '')}"
        env["PARKNUDGE_PLISTBUDDY"] = str(self.tools / "PlistBuddy")
        return subprocess.run(
            ["bash", str(AUDIT), str(self.derived)], env=env, capture_output=True, text=True
        )

    def assertFails(self, needle: str):
        result = self.audit()
        self.assertEqual(result.returncode, 1, result.stdout + result.stderr)
        self.assertIn(needle, result.stderr)

    def test_a_clean_release_product_passes_and_names_its_version(self):
        result = self.audit()
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn(f"ParkNudge {VERSION} ({BUILD})", result.stdout)

    def test_a_bundled_storekit_configuration_fails(self):
        (self.app / "Nested").mkdir()
        (self.app / "Nested" / "ParkNudge.storekit").write_text("{}", encoding="utf-8")
        self.assertFails("Debug StoreKit configuration")

    def test_a_version_other_than_project_yml_fails(self):
        self.write_info(CFBundleShortVersionString="1.2")
        self.assertFails("does not match project.yml MARKETING_VERSION")

    def test_a_build_other_than_project_yml_fails(self):
        self.write_info(CFBundleVersion="7")
        self.assertFails("does not match project.yml CURRENT_PROJECT_VERSION")

    def test_background_modes_fail(self):
        self.write_info(UIBackgroundModes=["location"])
        self.assertFails("UIBackgroundModes")

    def test_a_missing_info_plist_fails_instead_of_passing_the_plist_checks(self):
        (self.app / "Info.plist").unlink()
        self.assertFails("has no Info.plist")

    def test_an_sdk_scan_that_cannot_run_fails_instead_of_passing(self):
        broken_rg = self.tools / "rg"
        broken_rg.write_text("#!/bin/sh\nexit 2\n", encoding="utf-8")
        broken_rg.chmod(0o755)
        self.assertFails("could not run (rg exit 2)")


if __name__ == "__main__":
    unittest.main()
