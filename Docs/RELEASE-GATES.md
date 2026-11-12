# Release gates

| Gate | Current evidence | Required promotion evidence |
|---|---|---|
| Source | Local repository and generated Xcode project | Clean committed SHA and passing local verification |
| Simulator | Build and automated test commands | Exact simulator/runtime receipt and test results |
| Physical device | Unproven | Completed `DEVICE-ACCEPTANCE.md` with build SHA |
| Product identity | On sale as "ParkNudge: Parking Reminder" (public US lookup, 2026-11-11) | App Store name availability and trademark review |
| Commerce | Lifetime Pro is on sale: the App Store product page lists In-App Purchases (2026-11-11). Sandbox outcomes are still open on #7 | App Store Connect product plus Apple Sandbox outcomes |
| Website | Local static files and checker | Publisher-domain pages (`gusdigitalsolutions.com/parknudge/`) with public HTTPS readback |
| Legal/privacy | Draft copy and privacy manifest | Final contact, legal review, App Store privacy answers |
| Beta | 1.2.1 (8) was archived on 2026-11-08 and uploaded for the 2026-11-10 submission | Signed archive and TestFlight processing/installation proof |
| Release | 1.2 (7) is live, since 2026-10-30. 1.2.1 (8) is approved by App Review and waiting for a manual release (2026-11-11 readback, claudecode-workspace#3660). Releasing it needs Gus's own words naming the version and build | Explicit release decision and App Review acceptance |

Local, simulator, or GitHub evidence never substitutes for device, commerce, deployment, TestFlight, App Review, or public-release proof.
