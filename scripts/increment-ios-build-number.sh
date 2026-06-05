#!/usr/bin/env bash
set -euo pipefail

# Codemagic: requires app_store_connect integration and APP_ID in workflow vars.
: "${APP_ID:?APP_ID must be set (App Store Connect Apple ID)}"
: "${XCODE_PROJECT:=ios/App/App.xcodeproj}"

PBXPROJ="${XCODE_PROJECT}/project.pbxproj"
if [[ ! -f "$PBXPROJ" ]]; then
  echo "project.pbxproj not found at $PBXPROJ" >&2
  exit 1
fi

LATEST_BUILD_NUMBER="$(app-store-connect get-latest-app-store-build-number "$APP_ID")"
NEXT_BUILD_NUMBER=$((LATEST_BUILD_NUMBER + 1))

echo "App Store Connect app $APP_ID: latest build $LATEST_BUILD_NUMBER -> $NEXT_BUILD_NUMBER"

sed -i.bak "s/CURRENT_PROJECT_VERSION = [0-9]*/CURRENT_PROJECT_VERSION = ${NEXT_BUILD_NUMBER}/g" "$PBXPROJ"
rm -f "${PBXPROJ}.bak"

grep CURRENT_PROJECT_VERSION "$PBXPROJ" | head -2
