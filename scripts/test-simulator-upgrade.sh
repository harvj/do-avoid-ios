#!/bin/bash
set -euo pipefail

if [[ $# != 3 ]]; then
    echo "Usage: $0 BASELINE_APP UPGRADE_APP ARTIFACT_DIRECTORY" >&2
    exit 2
fi

baseline="$1"
upgrade="$2"
artifacts="$3"
repository="$(cd "$(dirname "$0")/.." && pwd)"
fixture="$repository/DoAvoidTests/legacy-history.json"
bundle="com.jimharvey.DoAvoid"
runtime="${DOAVOID_SIM_RUNTIME:-com.apple.CoreSimulator.SimRuntime.iOS-26-2}"
device_type="${DOAVOID_SIM_DEVICE_TYPE:-com.apple.CoreSimulator.SimDeviceType.iPhone-17-Pro}"
mkdir -p "$artifacts"

for app in "$baseline" "$upgrade"; do
    [[ "$(/usr/libexec/PlistBuddy -c 'Print CFBundleIdentifier' "$app/Info.plist")" == "$bundle" ]]
done
baseline_build="$(/usr/libexec/PlistBuddy -c 'Print CFBundleVersion' "$baseline/Info.plist")"
upgrade_build="$(/usr/libexec/PlistBuddy -c 'Print CFBundleVersion' "$upgrade/Info.plist")"
[[ "$baseline_build" == 1 && "$upgrade_build" == 2 ]]

device="$(xcrun simctl create DoAvoid-Upgrade-Test "$device_type" "$runtime")"
cleanup() {
    xcrun simctl shutdown "$device" >/dev/null 2>&1 || true
    xcrun simctl delete "$device" >/dev/null 2>&1 || true
}
trap cleanup EXIT
xcrun simctl boot "$device"
xcrun simctl bootstatus "$device" -b > "$artifacts/boot.log"

launch() {
    SIMCTL_CHILD_TZ=America/Los_Angeles xcrun simctl launch "$device" "$bundle"
}

history_directory() {
    local container
    container="$(xcrun simctl get_app_container "$device" "$bundle" data)"
    printf '%s\n' "$container/Library/Application Support/$bundle"
}

await_primary_match() {
    local expected="$1"
    for ((attempt = 0; attempt < 150; attempt++)); do
        if cmp -s "$expected" "$primary"; then return; fi
        sleep 0.1
    done
    echo "Primary did not match $expected" >&2
    return 1
}

xcrun simctl install "$device" "$baseline"
history="$(history_directory)"
mkdir -p "$history"
cp "$fixture" "$history/doavoid.json"
launch
sleep 1
cmp "$fixture" "$history/doavoid.json"
xcrun simctl io "$device" screenshot "$artifacts/baseline.png"
xcrun simctl terminate "$device" "$bundle"

xcrun simctl install "$device" "$upgrade"
history="$(history_directory)"
primary="$history/doavoid.json"
backup="$history/doavoid.backup.json"
cmp "$fixture" "$primary"
launch
python3 - "$fixture" "$primary" "$artifacts/migrated.json" <<'PY'
import json
import sys
import time
from datetime import datetime, timedelta, timezone
from pathlib import Path
from zoneinfo import ZoneInfo

fixture, primary, artifact = map(Path, sys.argv[1:])
for _ in range(150):
    data = primary.read_bytes()
    migrated = json.loads(data)
    if isinstance(migrated, dict):
        break
    time.sleep(0.1)
else:
    raise SystemExit("The app did not migrate its installed legacy data")

reference = datetime(2001, 1, 1, tzinfo=timezone.utc)

def day(instant):
    local = (reference + timedelta(seconds=instant)).astimezone(ZoneInfo("America/Los_Angeles"))
    return local.year * 10000 + local.month * 100 + local.day

expected = json.loads(fixture.read_bytes())
for item in expected:
    item["createdDay"] = day(item["createdAt"])
    entries = item["entries"][1::2]
    for entry in entries:
        entry["day"] = day(entry.pop("date"))
    item["entries"] = sorted(entries, key=lambda entry: entry["day"])

assert migrated == {"version": 1, "items": expected}, migrated
artifact.write_bytes(data)
PY
cmp "$fixture" "$history"/doavoid-legacy-*.json
cmp "$artifacts/migrated.json" "$backup"
xcrun simctl io "$device" screenshot "$artifacts/upgraded.png"
xcrun simctl terminate "$device" "$bundle"

launch
sleep 1
cmp "$artifacts/migrated.json" "$primary"
xcrun simctl terminate "$device" "$bundle"

printf 'deliberately corrupt primary\n' > "$artifacts/corrupt-primary.json"
cp "$artifacts/corrupt-primary.json" "$primary"
launch
await_primary_match "$artifacts/migrated.json"
cmp "$artifacts/migrated.json" "$backup"
cmp "$artifacts/corrupt-primary.json" "$history"/doavoid-corrupt-*.json
sleep 1
xcrun simctl io "$device" screenshot "$artifacts/recovered.png"
xcrun simctl terminate "$device" "$bundle"

printf 'deliberately corrupt backup\n' > "$artifacts/corrupt-backup.json"
cp "$artifacts/corrupt-primary.json" "$primary"
cp "$artifacts/corrupt-backup.json" "$backup"
launch
sleep 1
cmp "$artifacts/corrupt-primary.json" "$primary"
cmp "$artifacts/corrupt-backup.json" "$backup"
xcrun simctl io "$device" screenshot "$artifacts/unavailable.png"

echo "Passed baseline build $baseline_build to build $upgrade_build migration, relaunch, backup recovery, and fail-closed storage checks."
