#!/usr/bin/env bash
# Builds the latest code and installs it on your physical iPhone and/or Apple Watch.
#
# Usage:  ./scripts/deploy.sh               # iPhone; it forwards the watch app to the watch (most reliable)
#         ./scripts/deploy.sh watch         # straight to the watch (faster, needs the Mac-to-watch link)
#         ./scripts/deploy.sh all           # both of the above
#         add --no-launch to install without opening the app
#         ./scripts/deploy.sh --devices                         # list connected devices
#         ./scripts/deploy.sh phone --device "Sam's iPhone" --release   # a friend's phone
#
# --device picks a device by name or UDID (otherwise the first paired one is used).
# --release builds without the developer tools (test Pep, instant hatch): use it for friends.
#
# With a free Apple ID (Personal Team), installed apps stop opening after 7 days: reinstall over
# the top to renew (the pet is kept; deleting the app loses it). See docs/FRIENDS.md.
#
# The iPhone app carries the watch app inside it, so a phone install also updates the watch
# (usually within a minute or two). The iPhone only forwards a watch app whose build number
# changed, so every deploy gets a fresh one (yyMMddHHmm).
#
# Never toggle "Show App on Apple Watch" to force an update: that deletes the watch app and
# its data. (BackupLink restores it from the phone, but don't rely on that.)
#
# Requirements: Configs/Local.xcconfig with your DEVELOPMENT_TEAM, devices paired with this Mac,
# Developer Mode on, iPhone unlocked, watch unlocked and awake.
set -euo pipefail
cd "$(dirname "$0")/.."

target="phone"
launch=1
device=""
config="Debug"
list=0
while [ $# -gt 0 ]; do
  case "$1" in
    --no-launch) launch=0 ;;
    --release) config="Release" ;;
    --device) shift; device="${1:-}" ;;
    --devices) list=1 ;;
    phone|watch|all) target="$1" ;;
    *) echo "Usage: $0 [phone|watch|all] [--device NAME|UDID] [--release] [--no-launch] | --devices"; exit 1 ;;
  esac
  shift
done
derived=".build/DerivedData"
# Increases with every deploy; applies to the phone, watch and widget targets alike.
build_number="$(date +%y%m%d%H%M)"

[ -f Configs/Local.xcconfig ] || { echo "✗ Configs/Local.xcconfig missing (see Configs/Local.xcconfig.example)"; exit 1; }

# Finds a paired physical device of a type ("iPhone" or "appleWatch"): the one named (or with the
# UDID) given by --device, otherwise the first one.
find_device() {
  xcrun devicectl list devices --json-output - 2>/dev/null | python3 -c '
import json, sys
kind, wanted = sys.argv[1], sys.argv[2].lower()
for d in json.load(sys.stdin)["result"]["devices"]:
    hw, conn, props = d.get("hardwareProperties", {}), d.get("connectionProperties", {}), d.get("deviceProperties", {})
    if hw.get("reality") != "physical" or hw.get("deviceType") != kind or conn.get("pairingState") != "paired":
        continue
    name = props.get("name", "").lower().replace(chr(8217), chr(39))
    if wanted and wanted.replace(chr(8217), chr(39)) not in name and wanted != hw.get("udid", "").lower():
        continue
    print(hw.get("udid", "")); break
' "$1" "$device"
}

# Every connected device with its pairing state, to find a friend's phone by name.
list_devices() {
  xcrun devicectl list devices --json-output - 2>/dev/null | python3 -c '
import json, sys
for d in json.load(sys.stdin)["result"]["devices"]:
    hw, conn, props = d.get("hardwareProperties", {}), d.get("connectionProperties", {}), d.get("deviceProperties", {})
    if hw.get("reality") == "physical":
        name, kind = props.get("name", "?"), hw.get("deviceType", "")
        print("%-28s %-11s %-10s %s" % (name, kind, conn.get("pairingState", ""), hw.get("udid", "")))
'
}

deploy() {
  local scheme="$1" kind="$2" bundle_id="$3" product="$4" label="$5"
  local udid
  udid="$(find_device "$kind")"
  [ -n "$udid" ] || { echo "✗ No paired $label${device:+ called \"$device\"} found. Is it unlocked and connected? (--devices lists them)"; return 1; }

  echo "▶ Building ${scheme} ($config) for ${label}…"
  xcodebuild -project Fitchi.xcodeproj -scheme "$scheme" -configuration "$config" -destination "id=$udid" \
    -derivedDataPath "$derived" -allowProvisioningUpdates -allowProvisioningDeviceRegistration \
    CURRENT_PROJECT_VERSION="$build_number" build -quiet > ".build/deploy-$scheme.log" 2>&1 \
    || { echo "✗ Build failed — see .build/deploy-$scheme.log"; grep -m5 "error" ".build/deploy-$scheme.log"; return 1; }

  echo "▶ Installing on ${label}…"
  xcrun devicectl device install app --device "$udid" "$derived/Build/Products/$config-$product/Fitchi.app" --timeout 600 >/dev/null
  if [ "$launch" = 1 ]; then
    xcrun devicectl device process launch --device "$udid" "$bundle_id" >/dev/null 2>&1 || true
  fi
  echo "✓ $label updated (build $build_number)"
}

if [ "$list" = 1 ]; then list_devices; exit 0; fi

mkdir -p .build
./scripts/bootstrap.sh

phone() {
  deploy FitchiPhone iPhone com.nicholasferreira.fitchi iphoneos "iPhone"
  echo "  The watch app rides along; your iPhone installs it on the watch shortly."
}
watch() { deploy FitchiWatch appleWatch com.nicholasferreira.fitchi.watchkitapp watchos "Apple Watch"; }

case "$target" in
  phone) phone ;;
  watch) watch ;;
  all) phone; watch ;;
esac
