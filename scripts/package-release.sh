#!/usr/bin/env bash
set -euo pipefail

VERSION="${1:-}"
if [[ -z "${VERSION}" ]]; then
  echo "usage: $0 <version>" >&2
  echo "example: $0 0.1.0" >&2
  exit 64
fi

PROJECT="JoyconMapper.xcodeproj"
SCHEME="JoyconMapper"
CONFIGURATION="${CONFIGURATION:-Release}"
DERIVED_DATA_PATH="${DERIVED_DATA_PATH:-.build/xcode-release}"
OUTPUT_DIR="${OUTPUT_DIR:-.build/dist}"
APP_NAME="JoyconMapper"
APP_PATH="${DERIVED_DATA_PATH}/Build/Products/${CONFIGURATION}/${APP_NAME}.app"
ZIP_PATH="${OUTPUT_DIR}/${APP_NAME}-v${VERSION}.zip"
SHA_PATH="${ZIP_PATH}.sha256"

mkdir -p "${OUTPUT_DIR}"

xcodebuild \
  -project "${PROJECT}" \
  -scheme "${SCHEME}" \
  -configuration "${CONFIGURATION}" \
  -derivedDataPath "${DERIVED_DATA_PATH}" \
  clean build

if [[ ! -d "${APP_PATH}" ]]; then
  echo "app not found at ${APP_PATH}" >&2
  exit 1
fi

if [[ -n "${CODESIGN_IDENTITY:-}" ]]; then
  codesign \
    --force \
    --deep \
    --options runtime \
    --timestamp \
    --sign "${CODESIGN_IDENTITY}" \
    "${APP_PATH}"
fi

if [[ -n "${NOTARY_PROFILE:-}" ]]; then
  NOTARY_UPLOAD="${OUTPUT_DIR}/${APP_NAME}-v${VERSION}-notary-upload.zip"
  rm -f "${NOTARY_UPLOAD}"
  ditto -c -k --keepParent "${APP_PATH}" "${NOTARY_UPLOAD}"
  xcrun notarytool submit "${NOTARY_UPLOAD}" --keychain-profile "${NOTARY_PROFILE}" --wait
  xcrun stapler staple "${APP_PATH}"
fi

rm -f "${ZIP_PATH}" "${SHA_PATH}"
ditto -c -k --keepParent "${APP_PATH}" "${ZIP_PATH}"
shasum -a 256 "${ZIP_PATH}" | tee "${SHA_PATH}"

echo
echo "created ${ZIP_PATH}"
echo "sha256 written to ${SHA_PATH}"
