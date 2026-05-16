#!/usr/bin/env bash
set -euo pipefail

VERSION="${1:-}"
if [[ -z "${VERSION}" ]]; then
  echo "usage: $0 <version>" >&2
  echo "example: $0 0.9.0" >&2
  exit 64
fi

APP_NAME="${APP_NAME:-JoyconMapper}"
OUTPUT_DIR="${OUTPUT_DIR:-.build/dist}"
ZIP_PATH="${OUTPUT_DIR}/${APP_NAME}-v${VERSION}.zip"
SHA_PATH="${ZIP_PATH}.sha256"

if [[ ! -f "${ZIP_PATH}" ]]; then
  echo "zip not found: ${ZIP_PATH}" >&2
  exit 66
fi

if [[ ! -f "${SHA_PATH}" ]]; then
  echo "sha256 file not found: ${SHA_PATH}" >&2
  exit 66
fi

echo "==> SHA-256"
shasum -a 256 -c "${SHA_PATH}"

CHECK_DIR="$(mktemp -d "${TMPDIR:-/tmp}/joycon-mapper-release-check.XXXXXX")"
cleanup() {
  rm -rf "${CHECK_DIR}"
}
trap cleanup EXIT

echo
echo "==> Extract"
ditto -x -k "${ZIP_PATH}" "${CHECK_DIR}"

APP_PATH="${CHECK_DIR}/${APP_NAME}.app"
if [[ ! -d "${APP_PATH}" ]]; then
  echo "app not found after unzip: ${APP_PATH}" >&2
  exit 66
fi

echo
echo "==> codesign"
codesign --verify --deep --strict --verbose=4 "${APP_PATH}"

echo
echo "==> stapler"
xcrun stapler validate "${APP_PATH}"

echo
echo "==> Gatekeeper"
spctl --assess --type execute --verbose=4 "${APP_PATH}"

echo
echo "Release verification passed: ${ZIP_PATH}"
