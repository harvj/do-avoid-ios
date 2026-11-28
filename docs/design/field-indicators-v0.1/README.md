# Native Field indicators v0.1

Tested implementation commit `7487c2f2b935d96e89c208d93d666e2c6fda3c07`. Captured from the built SwiftUI app with Xcode 26.2 and iOS Simulator 26.2.

## Screenshots

| Screenshot | What it shows |
| --- | --- |
| [Field on iPhone 17 Pro](field.png) | Both layers on by default. New Do, a Do one completion from its next cycle after a seven-day gap, recovering Avoid, Avoid with seven consecutive violations, and Avoid with no further milestone. |
| [Field on iPhone 16e](field-iphone-16e.png) | The same histories at a narrower width, including a title that wraps. |
| [Field display settings](field-display-settings.png) | Independent switches with both on and an explanation of the estimates. |
| [Minimal Field](field-minimal.png) | Both supplementary layers off, after marking the Do cycle boundary. |
| [Dev Lab Momentum recovery](lab-momentum-recovery.png) | A simulated Avoid history recovering from recorded violations. |
| [Dev Lab Recent archive](lab-recent-archived.png) | A simulated archived Do during a gap in completions. |

The native Field keeps its existing palette and daily status cues. The clocks estimate existing milestones under daily completion for Do or continued absence of recorded violations for Avoid. A dash means no next milestone. Recent, Momentum, and Lab maturity remain experimental. The app has no six-level mapping yet and the Lab has no candidate-specific clocks. The landscape Timeline remains read-only. [Lifecycle audit](../../progression/lifecycle-review-v0.1.md)

## Verification

| Check | Result |
| --- | --- |
| Production `Debug` XCTest | 22 passed on iPhone 17 Pro simulator |
| Dev `DevDebug` XCTest | 26 passed on iPhone 16e simulator, including four Lab-only tests |
| Production `Release` and Dev `DevRelease` | Both unsigned simulator builds passed |
| Dev `DevDebug` for generic iOS device | Unsigned compile passed with the installer’s Dev bundle identifier |
| Build separation | Production and Dev bundle IDs match the existing identities. The Lab launch argument and candidate symbols occur only in the Dev binary. Production launched the real Field even with the Lab launch argument. |
| Simulator Field | Inspected both widths and the simulator accessibility tree. Both settings started on. Turning off labels kept clocks. Turning off both restored the minimal display. Marking the 40th completion updated the forecast from one day to 40. |
| In-place simulator update | Installed the baseline Dev build at `6e87564`, seeded a version-1 history, and installed the candidate over it without uninstalling. The same Dev bundle loaded with byte-identical history. Existing migration, backup recovery, and store tests passed. |

The candidate is ready for physical-device testing. From the repository root at this revision, connect and unlock the paired iPhone and run `./scripts/install-dev-iphone.sh` with the same Personal Team as the existing app. The installer updates `com.jimharvey.DoAvoid.dev` in place. The physical iPhone was untouched during this verification. [Personal Team installer notes](../../DOAVOID_DEV.md)

## Reproduce in a disposable simulator

Build the `DoAvoid` scheme in `Release` for the iOS Simulator and install it on a fresh simulator. Set `device` to that simulator’s UDID. The fixture uses today’s civil date, so the simulator and Mac should agree on the date. From the repository root, seed the synthetic history before launching.

```sh
bundle=com.jimharvey.DoAvoid
container=$(xcrun simctl get_app_container "$device" "$bundle" data)
history="$container/Library/Application Support/$bundle"
mkdir -p "$history"
python3 docs/design/field-indicators-v0.1/make-fixture.py > "$history/doavoid.json"
xcrun simctl launch "$device" "$bundle"
```

Use the sliders button beside **Add New** for settings. Tap **Read ten pages** to complete its 40th day. For Lab evidence, install and launch the Dev app with `--progression-lab --lab-recovery --lab-momentum` or `--progression-lab --lab-archive`. Capture with `xcrun simctl io "$device" screenshot FILE.png` after each screen settles.
