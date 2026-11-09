#!/usr/bin/env bash
# Builds the latest code and installs it on your physical iPhone and/or Apple Watch.
#
# Usage:  ./scripts/deploy.sh          # phone + watch
#         ./scripts/deploy.sh phone    # iPhone only (fast)
#         ./scripts/deploy.sh watch    # Apple Watch only
#
# Requirements: Configs/Local.xcconfig with your DEVELOPMENT_TEAM, devices paired with this Mac,
# Developer Mode on, iPhone unlocked, watch unlocked and awake.
set -euo pipefail
cd "$(dirname "$0")/.."

target="${1:-all}"
derived=".build/DerivedData"

[ -f Configs/Local.xcconfig ] || { echo "✗ Configs/Local.xcconfig missing (see Configs/Local.xcconfig.example)"; exit 1; }

# Finds the first paired physical device of a type: "iPhone" or "appleWatch".
find_device() {
  xcrun devicectl list devices --json-output - 2>/dev/null | python3 -c '
import json, sys
kind = sys.argv[1]
for d in json.load(sys.stdin)["result"]["devices"]:
    hw, conn = d.get("hardwareProperties", {}), d.get("connectionProperties", {})
    if hw.get("reality") == "physical" and hw.get("deviceType") == kind and conn.get("pairingState") == "paired":
        print(hw.get("udid", "")); break
' "$1"
}

deploy() {
  local scheme="$1" kind="$2" bundle_id="$3" product="$4" label="$5"
  local udid
  udid="$(find_device "$kind")"
  [ -n "$udid" ] || { echo "✗ No paired $label found. Is it unlocked and nearby?"; return 1; }

  echo "▶ Building ${scheme} for ${label}…"
  xcodebuild -project Fitchi.xcodeproj -scheme "$scheme" -destination "id=$udid" \
    -derivedDataPath "$derived" -allowProvisioningUpdates -allowProvisioningDeviceRegistration \
    build -quiet > ".build/deploy-$scheme.log" 2>&1 \
    || { echo "✗ Build failed — see .build/deploy-$scheme.log"; grep -m5 "error" ".build/deploy-$scheme.log"; return 1; }

  echo "▶ Installing on ${label}…"
  xcrun devicectl device install app --device "$udid" "$derived/Build/Products/$product/Fitchi.app" --timeout 600 >/dev/null
  xcrun devicectl device process launch --device "$udid" "$bundle_id" >/dev/null 2>&1 || true
  echo "✓ $label updated"
}

mkdir -p .build
./scripts/bootstrap.sh

case "$target" in
  phone) deploy FitchiPhone iPhone com.nicholasferreira.fitchi Debug-iphoneos "iPhone" ;;
  watch) deploy FitchiWatch appleWatch com.nicholasferreira.fitchi.watchkitapp Debug-watchos "Apple Watch" ;;
  all)
    deploy FitchiPhone iPhone com.nicholasferreira.fitchi Debug-iphoneos "iPhone"
    deploy FitchiWatch appleWatch com.nicholasferreira.fitchi.watchkitapp Debug-watchos "Apple Watch"
    ;;
  *) echo "Usage: $0 [phone|watch|all]"; exit 1 ;;
esac
