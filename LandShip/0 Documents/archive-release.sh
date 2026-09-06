#!/bin/sh
set -euo pipefail

# Bumps the build number, cleans, and archives VehicleTrax so the result
# shows up in Xcode's Organizer (Window > Organizer > Archives) for
# distribution, exactly as if you'd used Product > Archive.

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
PROJECT="$PROJECT_ROOT/LandShip.xcodeproj"
SCHEME="VehicleTrax"
CONFIGURATION="Release"

cd "$PROJECT_ROOT"

echo "Bumping build number..."
agvtool next-version -all

MARKETING_VERSION="$(agvtool what-marketing-version -terse1)"
BUILD_NUMBER="$(agvtool what-version -terse)"
echo "Now building $MARKETING_VERSION ($BUILD_NUMBER)"

echo "Cleaning build folder..."
xcodebuild -project "$PROJECT" -scheme "$SCHEME" -configuration "$CONFIGURATION" clean

ARCHIVE_DIR="$HOME/Library/Developer/Xcode/Archives/$(date +%Y-%m-%d)"
mkdir -p "$ARCHIVE_DIR"
ARCHIVE_PATH="$ARCHIVE_DIR/$SCHEME $MARKETING_VERSION ($BUILD_NUMBER), $(date +'%I.%M %p').xcarchive"

echo "Archiving to $ARCHIVE_PATH ..."
xcodebuild -project "$PROJECT" -scheme "$SCHEME" -configuration "$CONFIGURATION" \
  -archivePath "$ARCHIVE_PATH" archive

echo "Done. Archive is visible in Xcode's Organizer (Window > Organizer > Archives)."
