#!/bin/zsh
# Archives Semou and uploads it to App Store Connect for TestFlight.
# Requires the app record to exist in App Store Connect and your Apple ID signed in to Xcode.
set -euo pipefail
cd "${0:A:h}"

ARCHIVE=build/Semou.xcarchive
rm -rf "$ARCHIVE"
xcodegen generate
xcodebuild -project Semou.xcodeproj -scheme Semou -configuration Release \
  -destination 'generic/platform=macOS' -archivePath "$ARCHIVE" -allowProvisioningUpdates archive
xcodebuild -exportArchive -archivePath "$ARCHIVE" -exportOptionsPlist ExportOptions.plist \
  -exportPath build/export -allowProvisioningUpdates

echo "Uploaded. The build appears in App Store Connect → TestFlight after processing."
