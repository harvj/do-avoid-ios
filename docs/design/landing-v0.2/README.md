# Do/Avoid landing mockup v0.2

[Landing composition](landing-mockup.png) · [Transparent iPhone asset](iphone-transparent.png) · [SwiftUI simulator capture](field-simulator.png)

Small **DO** and **AVOID** labels sit in the upper-left corner of each Field bar, across from the countdown when present. The labels distinguish the green Late caffeine bar from green Do bars. The review patch includes a Field-level switch for the labels. VoiceOver includes the type in the bar’s label when the switch is enabled.

The landing artwork places **Coming soon to** above static App Store and Google Play badges. The badges are drawn into the PNG and carry no links or download calls to action. The landing uses the v0.1 gradient, typography, and iPhone placement.

| Example item | Type | Visible level | Fill | Days to next level |
| --- | --- | ---: | --- | ---: |
| Read ten pages | Do | 4 | `#66A879` | 3 |
| Take a walk | Do | 3 | `#90BB91` | |
| Late caffeine | Avoid | 5 | `#8CAE8A` | 6 |
| Scroll in bed | Avoid | 2 | `#C47861` | |
| Stretch | Do | 1 | `#D5D6D3` | |

Both six-level palettes and the 34-point countdown rings use the v0.1 fixtures. The ring values and arc lengths are illustrative.

## Reproduce

Use Xcode 26.2 and an iPhone 17 Pro simulator running iOS 26.2. Set `design` to the absolute path to this directory and `device` to the simulator UDID. Run the commands in a disposable checkout of `872a0064225c1c2350ee098467c0d8318b44ed0f`.

```sh
git apply "$design/swiftui-review.patch"
xcodebuild -project DoAvoid.xcodeproj -scheme 'DoAvoid Dev' \
  -configuration DevDebug -destination 'generic/platform=iOS Simulator' \
  -derivedDataPath build CODE_SIGNING_ALLOWED=NO build

xcrun simctl bootstatus "$device" -b
xcrun simctl status_bar "$device" override --time '9:41' \
  --dataNetwork wifi --wifiMode active --wifiBars 3 \
  --cellularMode active --cellularBars 4 \
  --batteryState unplugged --batteryLevel 100
xcrun simctl install "$device" build/Build/Products/DevDebug-iphonesimulator/DoAvoid.app
xcrun simctl launch "$device" com.jimharvey.DoAvoid.dev --landing-review
```

Once the Field is visible and the status bar has settled, capture the display and render both assets.

```sh
xcrun simctl io "$device" screenshot "$design/field-simulator.png"
swift "$design/render-mockup.swift" "$design/field-simulator.png" "$design"
```

To review the optional layer, terminate the app and relaunch with `--landing-review --hide-landing-types`. The patch is provided as a review artifact and is applied only in the disposable checkout.
