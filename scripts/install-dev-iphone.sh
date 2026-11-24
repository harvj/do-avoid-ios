#!/bin/bash
set -euo pipefail

fail() { printf 'Do/Avoid Dev: %s\n' "$*" >&2; exit 1; }

cd "$(dirname "$0")/.."
bundle=com.jimharvey.DoAvoid.dev
team=${DOAVOID_PERSONAL_TEAM:-522376PKLR}
device_selector=""
actions=(build)

while (( $# )); do
    case "$1" in
        --device)
            (( $# >= 2 )) && [[ -n "$2" ]] || fail "--device requires an iPhone name or ID."
            device_selector="$2"; shift ;;
        --renew) actions=(clean build) ;;
        --help|-h)
            cat <<'HELP'
Usage: ./scripts/install-dev-iphone.sh [--device NAME_OR_ID] [--renew]
Use --device when more than one iPhone is reachable.
Use --renew to rebuild in the local installer's DerivedData and reevaluate signing.
Set DOAVOID_PERSONAL_TEAM if your Personal Team differs from the configured default.
HELP
            exit 0 ;;
        *) fail "Unknown option $1. Use --help." ;;
    esac
    shift
done

[[ "$team" =~ ^[A-Z0-9]{10}$ ]] || fail "Set DOAVOID_PERSONAL_TEAM to the 10-character Xcode team ID."
command -v python3 >/dev/null || fail "Python 3 is needed to read device and signing metadata."
xcodebuild -version >/dev/null 2>&1 || fail "Select a full Xcode installation and complete its first-launch setup."
xcrun --find devicectl >/dev/null 2>&1 || fail "Select Xcode with CoreDevice (devicectl) installed."

scratch="$(mktemp -d "${TMPDIR:-/tmp}/doavoid-iphone.XXXXXX")"
trap 'rm -rf "$scratch"' EXIT
if ! xcrun devicectl list devices --quiet --timeout 15 --json-output "$scratch/devices.json"; then
    fail "Device discovery failed. Unlock and connect the iPhone by USB, then try again."
fi

selection="$(python3 - "$scratch/devices.json" "$device_selector" <<'PY'
import json
import sys

filename, selector = sys.argv[1:]
with open(filename) as source:
    devices = json.load(source)["result"]["devices"]

matches = []
for device in devices:
    hardware = device.get("hardwareProperties", {})
    connection = device.get("connectionProperties", {})
    properties = device.get("deviceProperties", {})
    if hardware.get("platform") != "iOS" or hardware.get("deviceType") != "iPhone":
        continue
    core_id, udid, name = device.get("identifier"), hardware.get("udid"), properties.get("name")
    if selector and selector not in (core_id, udid, name):
        continue
    if (core_id and udid and connection.get("pairingState") == "paired"
            and connection.get("tunnelState") not in (None, "unavailable")):
        matches.append((core_id, udid, connection.get("transportType") or "CoreDevice"))

if not matches:
    sys.exit("No matching paired iPhone is reachable. Unlock it, connect by USB, accept Trust if prompted, and retry.")
if len(matches) > 1:
    sys.exit("More than one iPhone matches. Run 'xcrun devicectl list devices' and pass --device with its ID.")
print(*matches[0], sep="\t")
PY
)" || exit 1
IFS=$'\t' read -r core_id udid transport <<< "$selection"

if ! xcrun devicectl device info details --device "$core_id" --quiet --timeout 20 --json-output "$scratch/details.json"; then
    fail "The iPhone stopped responding. Unlock it and try USB if using Wi-Fi."
fi
python3 - "$scratch/details.json" <<'PY' || exit 1
import json
import sys

with open(sys.argv[1]) as source:
    device = json.load(source)["result"]
status = device.get("deviceProperties", {}).get("developerModeStatus")
if status == "disabled":
    sys.exit("Enable Developer Mode on the iPhone in Settings > Privacy & Security, restart, then confirm on the phone.")
PY

output="$PWD/DerivedData/LocaliPhoneDev"
version="$(python3 - <<'PY'
from datetime import datetime, timezone
now = datetime.now(timezone.utc)
print(f"{(now.date() - datetime(2020, 1, 1).date()).days}.{now.hour}.{now.minute}")
PY
)"
mkdir -p "$output"
echo "Building Do/Avoid Dev $version for the iPhone ($transport), team $team."
if ! xcodebuild -project DoAvoid.xcodeproj -scheme 'DoAvoid Dev' -configuration DevDebug \
    -destination "platform=iOS,id=$udid" -destination-timeout 30 -derivedDataPath "$output" \
    -allowProvisioningUpdates -allowProvisioningDeviceRegistration \
    "DEVELOPMENT_TEAM=$team" CODE_SIGN_STYLE=Automatic "CODE_SIGN_IDENTITY=Apple Development" \
    "CURRENT_PROJECT_VERSION=$version" "${actions[@]}" > "$output/build.log" 2>&1; then
    tail -45 "$output/build.log" >&2
    fail "Build or provisioning failed. Confirm Xcode > Settings > Accounts shows your signed-in Personal Team, the team ID is correct, and the unlocked iPhone is trusted. See $output/build.log."
fi

app="$output/Build/Products/DevDebug-iphoneos/DoAvoid.app"
plist="$app/Info.plist"
[[ "$(/usr/libexec/PlistBuddy -c 'Print CFBundleIdentifier' "$plist")" == "$bundle" &&
   "$(/usr/libexec/PlistBuddy -c 'Print CFBundleVersion' "$plist")" == "$version" ]] \
    || fail "Refusing to install an unexpected app or stale build."
codesign --verify --strict "$app" || fail "The Dev app's signature failed verification."
security cms -D -i "$app/embedded.mobileprovision" > "$scratch/profile.plist" \
    || fail "No readable development provisioning profile was embedded."
codesign -d --entitlements :- "$app" > "$scratch/entitlements.plist" 2>"$scratch/signature.log" \
    || fail "Could not read the signed application entitlements."

python3 - "$scratch/profile.plist" "$scratch/entitlements.plist" "$team" "$bundle" "$udid" <<'PY' || exit 1
from datetime import datetime, timezone
import plistlib
import sys

profile_path, signature_path, team, bundle, udid = sys.argv[1:]
with open(profile_path, "rb") as source:
    profile = plistlib.load(source)
with open(signature_path, "rb") as source:
    signature = plistlib.load(source)

expires = profile["ExpirationDate"].replace(tzinfo=timezone.utc)
if expires <= datetime.now(timezone.utc):
    sys.exit("The embedded profile has expired. Reconnect the phone, check Xcode account sign-in, and rerun with --renew.")
signed_app = signature.get("application-identifier")
permitted_app = profile.get("Entitlements", {}).get("application-identifier", "")
prefix, separator, pattern = permitted_app.partition(".")
profile_matches = bool(separator and signed_app and (
    permitted_app == signed_app or
    (pattern.endswith("*") and "*" not in pattern[:-1] and signed_app.startswith(f"{prefix}.{pattern[:-1]}"))
))
if (team not in profile.get("TeamIdentifier", [])
        or signature.get("com.apple.developer.team-identifier") != team
        or not signed_app or signed_app.partition(".")[2] != bundle
        or not profile_matches
        or profile.get("Entitlements", {}).get("get-task-allow") is not True
        or signature.get("get-task-allow") is not True
        or udid.lower() not in {device.lower() for device in profile.get("ProvisionedDevices", [])}):
    sys.exit("The signature or profile does not permit local development of this Dev app on the selected phone. Check your Personal Team and rerun with --renew.")
print(f"Verified development profile, expires {expires:%Y-%m-%d %H:%M UTC}.")
PY

if ! xcrun devicectl device install app --device "$core_id" --timeout 120 "$app"; then
    fail "Install failed. Keep the phone unlocked and try USB. If iOS reports a signing-team conflict, use the existing app's team to preserve its data."
fi
if ! xcrun devicectl device process launch --device "$core_id" --timeout 30 --terminate-existing "$bundle"; then
    fail "Install completed, but launch failed. Unlock the phone and check Developer Mode. If iOS shows an Untrusted Developer prompt, follow the on-device trust instructions for your own signing account."
fi
echo "Installed and launched Do/Avoid Dev $version."
