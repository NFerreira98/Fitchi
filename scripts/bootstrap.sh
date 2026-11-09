#!/usr/bin/env bash
# Regenerates the Xcode project and VS Code language-server config.
# Run after cloning, after pulling changes to project.yml, or after adding/removing files.
set -euo pipefail
cd "$(dirname "$0")/.."

for tool in xcodegen xcode-build-server; do
  command -v "$tool" >/dev/null || { echo "Missing $tool — run: brew install xcodegen xcode-build-server swiftlint swift-format"; exit 1; }
done

xcodegen generate --quiet
xcode-build-server config -project Fitchi.xcodeproj -scheme FitchiPhone >/dev/null
echo "✓ Fitchi.xcodeproj generated and buildServer.json configured"
