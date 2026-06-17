#!/usr/bin/env bash
# Sets PRODUCT_BUNDLE_IDENTIFIER in project.pbxproj to match workflow BUNDLE_ID (after cap sync).
set -euo pipefail

: "${BUNDLE_ID:?BUNDLE_ID must be set}"

PBX="${XCODE_PROJECT:-ios/App/App.xcodeproj}/project.pbxproj"
if [[ ! -f "$PBX" ]]; then
  echo "project.pbxproj not found: $PBX" >&2
  exit 1
fi

before=$(grep -m1 'PRODUCT_BUNDLE_IDENTIFIER' "$PBX" | sed 's/.*= //;s/;//' | tr -d ' ' || true)
sed -i.bak "s/PRODUCT_BUNDLE_IDENTIFIER = [^;]*/PRODUCT_BUNDLE_IDENTIFIER = ${BUNDLE_ID}/g" "$PBX"
rm -f "${PBX}.bak"
after=$(grep -m1 'PRODUCT_BUNDLE_IDENTIFIER' "$PBX" | sed 's/.*= //;s/;//' | tr -d ' ')

echo "PRODUCT_BUNDLE_IDENTIFIER: ${before:-?} -> ${after}"
