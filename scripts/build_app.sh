#!/bin/zsh
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
DEVELOPER_DIR="${DEVELOPER_DIR:-/Applications/Xcode-27.0-Release-Candidate.app/Contents/Developer}"
export DEVELOPER_DIR

cd "$ROOT"

if [[ -n "${APP_VERSION:-}" ]]; then
	VERSION="$APP_VERSION"
elif [[ -n "${GITHUB_REF_NAME:-}" && "$GITHUB_REF_TYPE" == tag ]]; then
	VERSION="${GITHUB_REF_NAME#v}"
elif git describe --tags --exact-match >/dev/null 2>&1; then
	VERSION="$(git describe --tags --exact-match | sed 's/^v//')"
else
	VERSION="0.1.0"
fi
VERSION="${VERSION#v}"
if [[ ! "$VERSION" =~ '^[0-9]+\.[0-9]+\.[0-9]+$' ]]; then
	echo "APP_VERSION must be a semantic version (for example 1.2.3): $VERSION" >&2
	exit 1
fi
BUILD_NUMBER="${BUILD_NUMBER:-${GITHUB_RUN_NUMBER:-1}}"

swift build -c release

if [[ -f project.yml ]]; then
	xcodegen generate
fi
xcodebuild -project ControlPractice.xcodeproj -scheme ControlPractice -configuration Release -destination 'platform=macOS' -derivedDataPath build/DerivedData APP_VERSION="$VERSION" BUILD_NUMBER="$BUILD_NUMBER" CODE_SIGNING_ALLOWED=NO build

APP="$ROOT/dist/ControlPractice.app"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp build/DerivedData/Build/Products/Release/ControlPractice.app/Contents/MacOS/ControlPractice "$APP/Contents/MacOS/ControlPractice"
cp Assets/AppIcon.icns "$APP/Contents/Resources/AppIcon.icns"
cp build/DerivedData/Build/Products/Release/ControlPractice.app/Contents/Info.plist "$APP/Contents/Info.plist"
/usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString $VERSION" "$APP/Contents/Info.plist"
/usr/libexec/PlistBuddy -c "Set :CFBundleVersion $BUILD_NUMBER" "$APP/Contents/Info.plist"
chmod +x "$APP/Contents/MacOS/ControlPractice"
codesign --force --deep --sign - "$APP"

echo "$APP"
