#!/bin/sh
set -euo pipefail

# Cleans and archives the given scheme so the result shows up in Xcode's
# Organizer (Window > Organizer > Archives) for distribution, exactly as if
# you'd used Product > Archive.
#
# Usage: archive-release.sh [SchemeName] [--bump]
#   SchemeName  VehicleTrax (default), AeroTrax, or NauticalTrax
#   --bump      Bump the build number first. The build number is shared
#               across all three vertical targets, so pass --bump on the
#               FIRST scheme of a release round only — bumping again for
#               each subsequent scheme in the same round would waste build
#               numbers, not corrupt anything, but there's no reason to.
#
# Example for a release covering all three apps:
#   ./archive-release.sh VehicleTrax --bump
#   ./archive-release.sh AeroTrax
#   ./archive-release.sh NauticalTrax

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
PROJECT="$PROJECT_ROOT/LandShip.xcodeproj"
SCHEME="${1:-VehicleTrax}"
CONFIGURATION="Release"
BUMP_FLAG="${2:-}"

cd "$PROJECT_ROOT"

# Dropbox sync can reattach com.apple.quarantine to files (e.g. logo-A.png)
# copied in from elsewhere. App Store Connect rejects packages containing it
# (error 91109), so strip it from the whole project before every archive.
xattr -dr com.apple.quarantine . 2>/dev/null || true

if [ "$BUMP_FLAG" = "--bump" ]; then
  echo "Bumping build number..."
  agvtool next-version -all
fi

MARKETING_VERSION="$(agvtool what-marketing-version -terse1)"
BUILD_NUMBER="$(agvtool what-version -terse)"
echo "Now building $SCHEME $MARKETING_VERSION ($BUILD_NUMBER)"

echo "Cleaning build folder..."
xcodebuild -project "$PROJECT" -scheme "$SCHEME" -configuration "$CONFIGURATION" clean

ARCHIVE_DIR="$HOME/Library/Developer/Xcode/Archives/$(date +%Y-%m-%d)"
mkdir -p "$ARCHIVE_DIR"
ARCHIVE_PATH="$ARCHIVE_DIR/$SCHEME $MARKETING_VERSION ($BUILD_NUMBER), $(date +'%I.%M %p').xcarchive"

echo "Archiving to $ARCHIVE_PATH ..."
xcodebuild -project "$PROJECT" -scheme "$SCHEME" -configuration "$CONFIGURATION" \
  -archivePath "$ARCHIVE_PATH" archive

echo "Done. Archive is visible in Xcode's Organizer (Window > Organizer > Archives)."
