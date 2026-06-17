#!/usr/bin/env bash
# Logs bundle IDs, installed profiles, and keychain certs before xcode-project use-profiles.
set -uo pipefail

echo "========== Expected (workflow env) =========="
echo "BUNDLE_ID=${BUNDLE_ID:-unset}"
echo "XCODE_PROJECT=${XCODE_PROJECT:-ios/App/App.xcodeproj}"

PBX="${XCODE_PROJECT:-ios/App/App.xcodeproj}/project.pbxproj"

echo ""
echo "========== Xcode PRODUCT_BUNDLE_IDENTIFIER =========="
if [[ -f "$PBX" ]]; then
  grep 'PRODUCT_BUNDLE_IDENTIFIER' "$PBX" | head -4 || true
else
  echo "missing $PBX"
fi

echo ""
echo "========== Capacitor ios/App/App/capacitor.config.json =========="
CAP_JSON="ios/App/App/capacitor.config.json"
if [[ -f "$CAP_JSON" ]]; then
  cat "$CAP_JSON"
else
  echo "missing $CAP_JSON"
fi

echo ""
echo "========== Code signing identities (keychain) =========="
security find-identity -v -p codesigning 2>/dev/null || echo "(none or keychain unavailable)"

profile_dirs=(
  "$HOME/Library/MobileDevice/Provisioning Profiles"
  "$HOME/Library/Developer/Xcode/UserData/Provisioning Profiles"
)

echo ""
echo "========== Installed .mobileprovision files =========="
found_profile=0
for dir in "${profile_dirs[@]}"; do
  [[ -d "$dir" ]] || continue
  for p in "$dir"/*.mobileprovision; do
    [[ -f "$p" ]] || continue
    found_profile=1
    echo "--- $(basename "$p") ---"
    decoded=$(security cms -D -i "$p" 2>/dev/null) || {
      echo "  (failed to decode)"
      continue
    }
    echo "$decoded" | plutil -p - 2>/dev/null | grep -E '"(Name|application-identifier|TeamIdentifier|ExpirationDate|UUID|ProvisionedDevices|ProvisionsAllDevices|get-task-allow)"' || true
  done
done
if [[ "$found_profile" -eq 0 ]]; then
  echo "No .mobileprovision files found under MobileDevice or Xcode UserData."
fi

echo ""
echo "========== Profile certificate fingerprint (each profile) =========="
for dir in "${profile_dirs[@]}"; do
  [[ -d "$dir" ]] || continue
  for p in "$dir"/*.mobileprovision; do
    [[ -f "$p" ]] || continue
    echo "--- $(basename "$p") ---"
    if security cms -D -i "$p" 2>/dev/null | plutil -extract DeveloperCertificates.0 raw -o /tmp/cm_profile_cert.der - 2>/dev/null; then
      openssl x509 -inform DER -in /tmp/cm_profile_cert.der -noout -subject -fingerprint -sha256 2>/dev/null || echo "  (openssl read failed)"
      rm -f /tmp/cm_profile_cert.der
    else
      echo "  (no DeveloperCertificates in profile)"
    fi
  done
done

echo ""
echo "========== App.entitlements =========="
if [[ -f ios/App/App/App.entitlements ]]; then
  cat ios/App/App/App.entitlements
else
  echo "missing App.entitlements"
fi

echo ""
echo "========== Bundle ID alignment check =========="
if [[ -f "$PBX" ]] && [[ -f "$CAP_JSON" ]]; then
  pbx_id=$(grep -m1 'PRODUCT_BUNDLE_IDENTIFIER' "$PBX" | sed 's/.*= //;s/;//' | tr -d ' ')
  cap_id=$(grep -o '"appId"[[:space:]]*:[[:space:]]*"[^"]*"' "$CAP_JSON" | sed 's/.*"\([^"]*\)"$/\1/')
  echo "pbxproj:  ${pbx_id:-unknown}"
  echo "capacitor: ${cap_id:-unknown}"
  echo "workflow:  ${BUNDLE_ID:-unknown}"
  if [[ -n "${BUNDLE_ID:-}" && -n "$pbx_id" && "$pbx_id" != "$BUNDLE_ID" ]]; then
    echo "MISMATCH: PRODUCT_BUNDLE_IDENTIFIER != BUNDLE_ID (use-profiles may not match)"
  fi
  if [[ -n "${BUNDLE_ID:-}" && -n "$cap_id" && "$cap_id" != "$BUNDLE_ID" ]]; then
    echo "MISMATCH: capacitor appId != BUNDLE_ID"
  fi
fi

echo ""
echo "========== diagnose-ios-signing done =========="
