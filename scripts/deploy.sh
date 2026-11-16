#!/usr/bin/env bash
# Builds the latest code and installs it on your physical iPhone and/or Apple Watch.
#
# Usage:  ./scripts/deploy.sh               # iPhone; it forwards the watch app to the watch (most reliable)
#         ./scripts/deploy.sh watch         # straight to the watch (faster, needs the Mac-to-watch link)
#         ./scripts/deploy.sh all           # both of the above
#         add --no-launch to install without opening the app
#         ./scripts/deploy.sh --devices                         # list connected devices
#         ./scripts/deploy.sh phone --device "Sam's iPhone" --release   # a friend's phone
#         ./scripts/deploy.sh testflight    # archive a Release build and upload it to TestFlight
#
# --device picks a device by name or UDID (otherwise the first paired one is used).
# --release builds without the developer tools (test Pep, instant hatch): use it for friends.
#
# testflight needs the paid Developer Program, the app created in App Store Connect and Xcode
# signed in to your Apple ID (Settings > Accounts). Friends then install it from the TestFlight
# app; see docs/FRIENDS.md. No devices need to be connected.
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
    phone|watch|all|testflight) target="$1" ;;
    *) echo "Usage: $0 [phone|watch|all|testflight] [--device NAME|UDID] [--release] [--no-launch] | --devices"; exit 1 ;;
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

# Archives a Release build (no developer tools) of the iPhone app, which carries the watch app
# and widgets, and uploads it to App Store Connect. It shows up in TestFlight after Apple has
# processed it (5–30 minutes).
testflight() {
  local team archive="$derived/Fitchi.xcarchive" options=".build/ExportOptions.plist"
  team="$(sed -n 's/^DEVELOPMENT_TEAM *= *//p' Configs/Local.xcconfig | tr -d '[:space:]')"
  [ -n "$team" ] || { echo "✗ No DEVELOPMENT_TEAM in Configs/Local.xcconfig"; exit 1; }
  cat > "$options" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
  <key>method</key><string>app-store-connect</string>
  <key>destination</key><string>upload</string>
  <key>teamID</key><string>$team</string>
  <key>signingStyle</key><string>automatic</string>
  <key>manageAppVersionAndBuildNumber</key><false/>
  <key>uploadSymbols</key><true/>
</dict></plist>
PLIST
  echo "▶ Archiving FitchiPhone (Release, build $build_number)…"
  rm -rf "$archive"
  xcodebuild -project Fitchi.xcodeproj -scheme FitchiPhone -configuration Release \
    -destination "generic/platform=iOS" -archivePath "$archive" -derivedDataPath "$derived" \
    -allowProvisioningUpdates CURRENT_PROJECT_VERSION="$build_number" archive -quiet > .build/testflight-archive.log 2>&1 \
    || { echo "✗ Archive failed — see .build/testflight-archive.log"; grep -m5 "error" .build/testflight-archive.log; exit 1; }
  echo "▶ Uploading to App Store Connect…"
  xcodebuild -exportArchive -archivePath "$archive" -exportOptionsPlist "$options" \
    -exportPath ".build/testflight-export" -allowProvisioningUpdates > .build/testflight-upload.log 2>&1 \
    || { echo "✗ Upload failed — see .build/testflight-upload.log"; grep -m5 -i "error" .build/testflight-upload.log; exit 1; }
  echo "✓ Uploaded build $build_number. It appears in App Store Connect > TestFlight once processed."
}

case "$target" in
  phone) phone ;;
  watch) watch ;;
  all) phone; watch ;;
  testflight) testflight ;;
esac
