#!/bin/bash
set -euo pipefail

cd "$(dirname "$0")/.."
case "${1:---check}" in
    --check|--archive|--upload) action="${1:---check}" ;;
    *) echo "Usage: $0 [--check | --archive | --upload]" >&2; exit 2 ;;
esac

identifier=com.jimharvey.DoAvoid.dev
team=522376PKLR
version="${DOAVOID_BUILD_NUMBER:-$(python3 - <<'PY'
from datetime import datetime, timezone
now = datetime.now(timezone.utc)
days = (now.date() - datetime(2020, 1, 1).date()).days
print(f"{days}.{now.hour}.{now.minute}")
PY
)}"
if [[ ! "$version" =~ ^[1-9][0-9]{0,3}\.([0-9]|[1-9][0-9])\.([0-9]|[1-9][0-9])$ ]]; then
    echo "Use a build number in the form 1234.12.34." >&2
    exit 2
fi
output=${DOAVOID_BUILD_DIR:-"$PWD/DerivedData/TestFlightDev"}
build=(xcodebuild -project DoAvoid.xcodeproj -scheme 'DoAvoid Dev' -configuration DevRelease
       -destination 'generic/platform=iOS' -derivedDataPath "$output/build" "CURRENT_PROJECT_VERSION=$version")
settings="$("${build[@]}" -showBuildSettings -json)"
python3 -c '
import json, sys
app, = [entry["buildSettings"] for entry in json.load(sys.stdin) if entry["target"] == "DoAvoid"]
if not (app["CONFIGURATION"] == "DevRelease" and app["PRODUCT_BUNDLE_IDENTIFIER"] == sys.argv[1]
        and app["DEVELOPMENT_TEAM"] == sys.argv[2]
        and "DOAVOID_LAB" in app["SWIFT_ACTIVE_COMPILATION_CONDITIONS"].split()):
    raise SystemExit("Refusing to distribute a build outside the configured Dev identity")
' "$identifier" "$team" <<< "$settings"
echo "Do/Avoid Dev $version at $(git rev-parse --short HEAD)"
if [[ "$action" == --check ]]; then exit 0; fi

authentication=(-allowProvisioningUpdates)
if [[ -n "${ASC_KEY_PATH:-}${ASC_KEY_ID:-}${ASC_ISSUER_ID:-}" ]]; then
    if [[ ! -f "${ASC_KEY_PATH:-}" || -z "${ASC_KEY_ID:-}" || -z "${ASC_ISSUER_ID:-}" ]]; then
        echo "Configure ASC_KEY_PATH, ASC_KEY_ID and ASC_ISSUER_ID locally." >&2
        exit 2
    fi
    authentication+=(-authenticationKeyPath "$ASC_KEY_PATH" -authenticationKeyID "$ASC_KEY_ID" -authenticationKeyIssuerID "$ASC_ISSUER_ID")
elif [[ "${DOAVOID_USE_XCODE_ACCOUNT:-}" != 1 ]]; then
    echo "Configure the local App Store Connect key or opt in to an existing Xcode account." >&2
    exit 2
fi

mkdir -p "$output"
run="$(mktemp -d "$output/run-$version.XXXXXX")"
archive="$run/DoAvoidDev.xcarchive"
"${build[@]}" "${authentication[@]}" -archivePath "$archive" archive
app="$archive/Products/Applications/DoAvoid.app"
plist="$app/Info.plist"
[[ "$(/usr/libexec/PlistBuddy -c 'Print CFBundleIdentifier' "$plist")" == "$identifier" ]]
[[ "$(/usr/libexec/PlistBuddy -c 'Print CFBundleVersion' "$plist")" == "$version" ]]
[[ "$(/usr/libexec/PlistBuddy -c 'Print CFBundleDisplayName' "$plist")" == "Do/Avoid Dev" ]]
codesign --verify --strict "$app"
echo "Verified signed Dev archive at $archive"
if [[ "$action" == --archive ]]; then exit 0; fi

options="$run/ExportOptions.plist"
cat > "$options" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>method</key><string>app-store-connect</string>
    <key>destination</key><string>upload</string>
    <key>distributionBundleIdentifier</key><string>$identifier</string>
    <key>teamID</key><string>$team</string>
    <key>signingStyle</key><string>automatic</string>
    <key>manageAppVersionAndBuildNumber</key><false/>
    <key>testFlightInternalTestingOnly</key><true/>
</dict>
</plist>
PLIST
xcodebuild -exportArchive -archivePath "$archive" -exportOptionsPlist "$options" \
    -exportPath "$run/delivery" "${authentication[@]}"
echo "Upload returned successfully. Check processing and Internal status in App Store Connect."
