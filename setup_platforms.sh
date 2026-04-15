#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")"

if ! command -v flutter >/dev/null 2>&1; then
  echo "Install Flutter first: https://docs.flutter.dev/get-started/install"
  exit 1
fi

flutter create . \
  --project-name pinnacle \
  --org com.pinnacle.transfer \
  --platforms=android,ios

flutter pub get

echo ""
echo "Post-setup (required for local HTTP):"
echo "  • Android: in android/app/src/main/AndroidManifest.xml add to <application ...>:"
echo "      android:usesCleartextTraffic=\"true\""
echo "  • iOS: in ios/Runner/Info.plist add:"
echo "      NSLocalNetworkUsageDescription — explain Wi‑Fi device discovery"
echo "      NSCameraUsageDescription — for QR scanning"
echo "      NSPhotoLibraryUsageDescription — if the system prompts when picking photos"
echo ""
echo "Then: flutter run"
