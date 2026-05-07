#!/usr/bin/env bash
set -euo pipefail

NOTARY_PROFILE="${NOTARY_PROFILE:-joycon-mapper-notary}"

echo "Code signing identities:"
security find-identity -v -p codesigning

echo
if security find-identity -v -p codesigning | grep -q "Developer ID Application:"; then
  echo "OK: Developer ID Application certificate found."
else
  echo "MISSING: Developer ID Application certificate not found."
  echo "Create/download it from Apple Developer or Xcode before notarized distribution."
fi

echo
echo "Notary profile: ${NOTARY_PROFILE}"
if xcrun notarytool history --keychain-profile "${NOTARY_PROFILE}" >/dev/null 2>&1; then
  echo "OK: notarytool profile works."
else
  echo "MISSING: notarytool profile is not available or invalid."
  echo "Create it with:"
  echo "  xcrun notarytool store-credentials ${NOTARY_PROFILE}"
fi
