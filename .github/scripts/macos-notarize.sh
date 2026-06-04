#!/usr/bin/env bash
set -euo pipefail

DYLIB="${1:?Missing dylib path argument}"

if [ -n "${MACOS_SIGN_P12:-}" ]; then
  echo "Apple Developer ID signature applied. Submitting to Apple Notary Service..."

  # Ensure cleanup on exit
  trap 'rm -f "$RUNNER_TEMP/AuthKey.p8" "$RUNNER_TEMP/libds4_notarize.zip" "$RUNNER_TEMP/notary_submit.log" 2>/dev/null' EXIT

  # Package in a zip archive for notarization
  ZIP="$RUNNER_TEMP/libds4_notarize.zip"
  ditto -c -k --keepParent "$DYLIB" "$ZIP"

  # Write private key PEM
  if [[ "${MACOS_NOTARY_KEY:-}" == *"BEGIN PRIVATE KEY"* ]]; then
    echo "$MACOS_NOTARY_KEY" > "$RUNNER_TEMP/AuthKey.p8"
  else
    echo "$MACOS_NOTARY_KEY" | base64 -D > "$RUNNER_TEMP/AuthKey.p8"
  fi

  # Submit to notarytool and output to a log file via tee
  xcrun notarytool submit "$ZIP" \
    --key "$RUNNER_TEMP/AuthKey.p8" \
    --key-id "$MACOS_NOTARY_KEY_ID" \
    --issuer "$MACOS_NOTARY_ISSUER_ID" \
    --wait 2>&1 | tee "$RUNNER_TEMP/notary_submit.log"

  # Parse submission ID and status
  SUBMISSION_ID=$(grep -E -o '[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}' "$RUNNER_TEMP/notary_submit.log" | head -n 1 || true)
  STATUS=$(grep -E -i '^[[:space:]]*status:' "$RUNNER_TEMP/notary_submit.log" | tail -n 1 | awk '{print $2}' || true)

  if [ "$STATUS" != "Accepted" ]; then
    echo "Notarization failed with status: $STATUS"
    if [ -n "$SUBMISSION_ID" ]; then
      echo "Retrieving failure log for Submission ID: $SUBMISSION_ID..."
      xcrun notarytool log "$SUBMISSION_ID" \
        --key "$RUNNER_TEMP/AuthKey.p8" \
        --key-id "$MACOS_NOTARY_KEY_ID" \
        --issuer "$MACOS_NOTARY_ISSUER_ID"
    fi
    exit 1
  else
    echo "Notarization succeeded!"
  fi
else
  echo "Skipping notarization (no official Developer ID signature)."
fi
