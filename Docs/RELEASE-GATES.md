# Release gates

| Gate | Current evidence | Required promotion evidence |
|---|---|---|
| Source | Local repository and generated Xcode project | Clean committed SHA and passing local verification |
| Simulator | Build and automated test commands | Exact simulator/runtime receipt and test results |
| Physical device | Unproven | Completed `DEVICE-ACCEPTANCE.md` with build SHA |
| Product identity | Working name only | App Store name availability and trademark review |
| Commerce | Debug StoreKit configuration only | App Store Connect product plus Apple Sandbox outcomes |
| Website | Local static files and checker | Owned domain, deployment receipt, public HTTPS readback |
| Legal/privacy | Draft copy and privacy manifest | Final contact, legal review, App Store privacy answers |
| Beta | Not uploaded | Signed archive and TestFlight processing/installation proof |
| Release | Not authorized | Explicit release decision and App Review acceptance |

Local, simulator, or GitHub evidence never substitutes for device, commerce, deployment, TestFlight, App Review, or public-release proof.
