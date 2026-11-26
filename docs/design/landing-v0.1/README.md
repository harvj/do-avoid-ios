# Do/Avoid landing mockup v0.1

[Landing composition](landing-mockup.png) · [Transparent iPhone asset](iphone-transparent.png) · [Original simulator screen](field-simulator.png)

The screen was captured from the repository's SwiftUI Field and Bar components on an iPhone 17 Pro simulator. The capture build uses a temporary review patch to show five example items in the minimal presentation. The shell, shadow, background, and landing copy are composed around the capture.

| Example item | Type | Visible level | Fill | Days to next level |
| --- | --- | ---: | --- | ---: |
| Read ten pages | Do | 4 | `#66A879` | 3 |
| Take a walk | Do | 3 | `#90BB91` | |
| Late caffeine | Avoid | 5 | `#8CAE8A` | 6 |
| Scroll in bed | Avoid | 2 | `#C47861` | |
| Stretch | Do | 1 | `#D5D6D3` | |

The artwork uses opaque sRGB palette steps. The 34-point rings use tabular numerals, and the accessible label identifies the number as estimated days to the next level. The ring values and arc lengths are illustrative fixtures. Historical activity, visible level, accumulated progression, and projected transition dates can evolve independently. This review leaves the mapping between them open.

Review whether the ring's unit is clear at landing-page size, whether two rings feel quiet enough, and whether the green Avoid level needs another cue when shown beside Do. The landing copy is provisional.

## Reproduce

Use baseline `0f3ad056e068157561bfcdc862309da29bfdb142`, Xcode 26.2, and an iPhone 17 Pro simulator running iOS 26.2. Apply [swiftui-review.patch](swiftui-review.patch) in a disposable checkout, build the **DoAvoid Dev** scheme for iOS Simulator with `DevDebug`, install the app in a test simulator, and launch `com.jimharvey.DoAvoid.dev --landing-review` with `simctl`. Capture the display as `field-simulator.png`. Then run from this directory:

```sh
swift render-mockup.swift field-simulator.png .
```

The review patch is stored alongside the artwork. The repository's application target and behavior stay at the baseline.
