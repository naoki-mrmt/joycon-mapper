#!/usr/bin/env bash
set -euo pipefail

PROJECT="${PROJECT:-JoyconMapper.xcodeproj}"
SCHEME="${SCHEME:-JoyconMapper}"
TEST_DERIVED_DATA_PATH="${TEST_DERIVED_DATA_PATH:-.build/xcode-ci-test}"
RELEASE_DERIVED_DATA_PATH="${RELEASE_DERIVED_DATA_PATH:-.build/xcode-ci-release}"

echo "==> Xcode"
xcodebuild -version
echo

echo "==> Unit tests"
xcodebuild \
  -project "${PROJECT}" \
  -scheme "${SCHEME}" \
  -configuration Debug \
  -derivedDataPath "${TEST_DERIVED_DATA_PATH}" \
  CODE_SIGNING_ALLOWED=NO \
  -only-testing:JoyconMapperTests \
  test

echo
echo "==> Release build"
xcodebuild \
  -project "${PROJECT}" \
  -scheme "${SCHEME}" \
  -configuration Release \
  -derivedDataPath "${RELEASE_DERIVED_DATA_PATH}" \
  CODE_SIGNING_ALLOWED=NO \
  clean build

echo
echo "CI checks passed."
