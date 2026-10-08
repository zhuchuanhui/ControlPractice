#!/bin/zsh
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
VERSION="${APP_VERSION:-}"
if [[ -z "$VERSION" ]]; then
	if [[ -n "${GITHUB_REF_NAME:-}" && "${GITHUB_REF_TYPE:-}" == tag ]]; then
		VERSION="${GITHUB_REF_NAME#v}"
	elif git -C "$ROOT" describe --tags --exact-match >/dev/null 2>&1; then
		VERSION="$(git -C "$ROOT" describe --tags --exact-match | sed 's/^v//')"
	else
		echo "Set APP_VERSION or build from a vX.Y.Z tag." >&2
		exit 1
	fi
fi
VERSION="${VERSION#v}"
if [[ ! "$VERSION" =~ '^[0-9]+\.[0-9]+\.[0-9]+$' ]]; then
	echo "APP_VERSION must be a semantic version (for example 1.2.3): $VERSION" >&2
	exit 1
fi

APP_PATH="$ROOT/dist/ControlPractice.app"
DMG_PATH="$ROOT/dist/ControlPractice-$VERSION.dmg"
APP_VERSION="$VERSION" "$ROOT/scripts/build_app.sh"
STAGING="$ROOT/dist/dmg-staging"
rm -rf "$STAGING" "$DMG_PATH"
mkdir -p "$STAGING"
cp -R "$APP_PATH" "$STAGING/ControlPractice.app"
ln -s /Applications "$STAGING/Applications"
hdiutil create -volname "Control Practice $VERSION" -srcfolder "$STAGING" -ov -format UDZO "$DMG_PATH"
rm -rf "$STAGING"
echo "$DMG_PATH"
