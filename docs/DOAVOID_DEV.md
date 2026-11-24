# Do/Avoid Dev

Do/Avoid Dev uses the same SwiftUI app target as production, with its own icon, display name and bundle identifier, `com.jimharvey.DoAvoid.dev`. iOS gives it a separate app container. The Progression Lab owns in-memory fixture history and has no reference to an app store or persistence writer. The public `DoAvoid` scheme compiles without the lab and rejects a build with both production and lab flags. The distribution script targets only the Dev identity and uses Apple's **TestFlight Internal Only** export option.

Local verification used Xcode 26.2 with iOS 26.2. The Dev suite passed 21 tests and the production suite passed 17. Both unsigned device builds compiled, and side-by-side simulator installation verified separate containers and production exclusion. The signing probe found no matching Dev provisioning profile. App Store Connect processing and physical iPhone installation and updates are pending Apple setup.

## One-time TestFlight setup

1. The Account Holder confirms an active Apple Developer Program membership for the team configured in Xcode (`522376PKLR)) and accepts any pending agreements. In Certificates, Identifiers & Profiles, register the explicit iOS App ID `com.jimharvey.DoAvoid.dev`. If the active paid team differs, reconcile the Dev team in project and script before distribution. [Register an App ID](https://developer.apple.com/help/account/identifiers/register-an-app-id/)
2. In App Store Connect → Apps → **+ → New App**, create an iOS record for that ID with the name **Do/Avoid Dev** if available, primary language English and SKU `doavoid-dev`. In its TestFlight tab, create an internal group with automatic distribution and add the developer's App Store Connect user. Complete any export compliance prompt for the actual binary. [Create an app record](https://developer.apple.com/help/app-store-connect/create-an-app-record/add-a-new-app) · [Internal TestFlight groups](https://developer.apple.com/help/app-store-connect/test-a-beta-version/add-internal-testers/)
3. Authorize this Mac for provisioning and upload. Use an approved App Store Connect team API key with signing/provisioning and upload access, stored outside the repository. Configure `ASC_KEY_PATH`, `ASC_KEY_ID`, and `ASC_ISSUER_ID` in the build environment. Alternatively, if Xcode already has an authorized account on this Mac, set `DOAVOID_USE_XCODE_ACCOUNT=1`. Xcode automatic signing will attempt to obtain a suitable profile and signing identity. If the team restricts signing, an authorized team member must make the required profile and identity available. Use local credential storage and leave credentials out of chat and source control. [App Store Connect API access](https://developer.apple.com/help/app-store-connect/get-started/app-store-connect-api) · [Apple signing and distribution](https://developer.apple.com/documentation/Xcode/distributing-your-app-for-beta-testing-and-releases)

## Repeatable delivery

On the authorized Mac, from the desired Git checkout:

```sh
scripts/testflight-dev.sh --check
scripts/testflight-dev.sh --upload
```

`--check` inspects effective build settings. `--archive` builds and verifies a signed archive locally. `--upload` performs the same signed archive step and then uses Xcode's App Store Connect exporter to validate and upload as internal only. It prints the Git revision and build number. The default build number is derived from UTC (days since 2020, hour, minute). Use a higher `DOAVOID_BUILD_NUMBER` for two uploads in one minute or when App Store Connect already has a newer number. Build intermediates are cached in ignored `DerivedData/TestFlightDev` and archives/logs get their own run directory. No GitHub Actions runner is needed. If a future automation launches these commands, use a single uploader for the Dev app.

After the first upload processes and is marked **Internal**, accept the TestFlight invitation on the iPhone and tap **Install**. Enable Automatic Updates for Do/Avoid Dev if desired. For the first over-the-air verification, create a uniquely named item in the **Dev app outside the lab**, mark it, and note the build number shown at the top. Upload a second, higher build. Update in TestFlight, check the new build number, and verify the item and mark survived. Any production copy should still have its own separate history. TestFlight installation and updates use the iPhone app directly.

## Run and review locally

Build **DoAvoid Dev** in Xcode or run the simulator build from the terminal:

```sh
xcodebuild -project DoAvoid.xcodeproj -scheme 'DoAvoid Dev' -configuration DevRelease \
  -destination 'generic/platform=iOS Simulator' -derivedDataPath DerivedData/DevSim \
  CODE_SIGNING_ALLOWED=NO build
xcrun simctl install booted DerivedData/DevSim/Build/Products/DevRelease-iphonesimulator/DoAvoid.app
xcrun simctl launch booted com.jimharvey.DoAvoid.dev
```

Tap **Progression Lab** at the top. Choose an individual scenario or **All items**, then select **Field** or **Timeline**. Scrub the date from two years before the fixed reference day through six months after, or use the arrows for one-day steps. Tap a Field bar to toggle that day's simulated mark. The Timeline uses the same history and projects each cell at its column's day. Swipe horizontally to see more days. **Tune** changes activity window, momentum horizon, maturation thresholds, palette and intensity. It also restores the fixtures and jumps directly to the lifecycle example's archived and reactivated periods. Closing the lab discards the session.

For reproducible simulator captures, relaunch the app with these arguments. Use `xcrun simctl io booted screenshot FILE.png` after the app opens.

| Example | Launch arguments after bundle ID |
| --- | --- |
| Overview of nine histories | `--progression-lab --lab-all` |
| Recovering Avoid, Timeline, teal/plum | `--progression-lab --lab-recovery --lab-momentum --lab-timeline` |
| Mature item during an archive period | `--progression-lab --lab-archive` |

Review captures from the simulator show the [Field overview](lab-previews/field.png), [recovering Avoid timeline](lab-previews/timeline.png), and [archived item](lab-previews/archived.png).

## Candidate behavior and open questions

- **Recent activity** uses a rolling window. More Do completions raise strength. More Avoid violations lower it. Old activity falls out of the window.
- **Momentum** weights recent marks more heavily. Do strength decays as completions age. Avoid violations reduce strength and their effects fade over the selected recovery horizon. Overlapping violations can compound.
- **Maturation** currently depends on configurable age and strength. The lifecycle fixture adds a temporary archive interval for review. The skin maps strength to opacity and uses symbols and accessibility labels for daily status, with a separate maturation cue.

Compare rolling-window steps with gradual momentum. Decide whether implicit Avoid success alone can mature an item, whether maturation should survive inactivity, whether archive time should pause decay, how reactivation should resume a cycle, and how strongly color should signal these distinctions. Review light and dark appearance, accessibility, and small-phone Timeline navigation before choosing a default.

P0.2 stores the latest archive flag and full daily history. Reconstructing archive/reactivation periods or explicit cycle starts would require dated lifecycle events. If review calls for them, propose an additive schema version with ordered events and stable IDs. Preserve old records and treat dates of pre-existing archive flags as unknown. Keep derived progression and skin values out of stored history until a reviewed requirement calls for persistent state.

## Next assignment

**P0.3b — On-device progression review and interaction refinement.** Deliver two internal builds and verify install and update on the iPhone. Use the nine scenarios to review candidate rules and one default skin, then decide whether lifecycle needs a schema change. Finish the core inspection, editing and navigation workflows after that review.
