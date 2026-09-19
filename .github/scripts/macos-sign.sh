#!/usr/bin/env bash
set -euo pipefail

DYLIB="${1:?Missing dylib path argument}"

if [ -n "${MACOS_SIGN_P12:-}" ]; then
  echo "Developer ID certificate found. Setting up keychain..."
  KEYCHAIN_PATH="$RUNNER_TEMP/app-signing.keychain-db"
  KEYCHAIN_PASSWORD=$(openssl rand -base64 12)

  # Ensure keychain and certificate files are cleaned up on exit
  trap 'security delete-keychain "$KEYCHAIN_PATH" 2>/dev/null; rm -f "$RUNNER_TEMP/certificate.p12" 2>/dev/null' EXIT

  security create-keychain -p "$KEYCHAIN_PASSWORD" "$KEYCHAIN_PATH"
  security set-keychain-settings -lut 21600 "$KEYCHAIN_PATH"
  security default-keychain -s "$KEYCHAIN_PATH"
  security list-keychains -d user -s "$KEYCHAIN_PATH" login.keychain-db
  security unlock-keychain -p "$KEYCHAIN_PASSWORD" "$KEYCHAIN_PATH"

  echo "$MACOS_SIGN_P12" | base64 -D > "$RUNNER_TEMP/certificate.p12"
  security import "$RUNNER_TEMP/certificate.p12" \
    -k "$KEYCHAIN_PATH" \
    -P "$MACOS_SIGN_PASSWORD" \
    -T /usr/bin/codesign \
    -T /usr/bin/security

  security set-key-partition-list -S apple-tool:,apple: -s -k "$KEYCHAIN_PASSWORD" "$KEYCHAIN_PATH"

  echo "Codesigning $DYLIB..."
  codesign --force --options runtime --timestamp \
    -s "Developer ID Application" \
    "$DYLIB"
else
  echo "Developer ID certificate NOT found. Falling back to local ad-hoc signing..."
  codesign --force -s - "$DYLIB"
fi
