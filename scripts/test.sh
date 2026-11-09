#!/usr/bin/env bash
# Runs every package's unit tests (fast, no simulator), then builds both apps.
# Usage: ./scripts/test.sh            # packages + app builds
#        ./scripts/test.sh --packages # packages only
set -euo pipefail
cd "$(dirname "$0")/.."

for pkg in Packages/*/; do
  if [ -d "$pkg/Tests" ]; then
    echo "▶ swift test — $(basename "$pkg")"
    swift test --package-path "$pkg" --quiet
  else
    echo "▶ swift build — $(basename "$pkg")"
    swift build --package-path "$pkg" --quiet
  fi
done

[ "${1:-}" = "--packages" ] && exit 0

./scripts/bootstrap.sh
echo "▶ xcodebuild — FitchiWatch"
xcodebuild -project Fitchi.xcodeproj -scheme FitchiWatch -destination 'generic/platform=watchOS Simulator' \
  -derivedDataPath .build/DerivedData build -quiet
echo "▶ xcodebuild — FitchiPhone (embeds watch app)"
xcodebuild -project Fitchi.xcodeproj -scheme FitchiPhone -destination 'generic/platform=iOS Simulator' \
  -derivedDataPath .build/DerivedData build -quiet
echo "✓ All good"
