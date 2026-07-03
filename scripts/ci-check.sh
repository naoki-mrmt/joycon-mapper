#!/usr/bin/env bash
set -euo pipefail

PROJECT="${PROJECT:-JoyconMapper.xcodeproj}"
SCHEME="${SCHEME:-JoyconMapper}"
TEST_DERIVED_DATA_PATH="${TEST_DERIVED_DATA_PATH:-.build/xcode-ci-test}"
UI_TEST_DERIVED_DATA_PATH="${UI_TEST_DERIVED_DATA_PATH:-.build/xcode-ci-ui-test}"
RELEASE_DERIVED_DATA_PATH="${RELEASE_DERIVED_DATA_PATH:-.build/xcode-ci-release}"
UI_TEST_TIMEOUT_SECONDS="${UI_TEST_TIMEOUT_SECONDS:-180}"

run_with_timeout() {
  local timeout_seconds="$1"
  shift

  "$@" &
  local command_pid=$!

  (
    sleep "${timeout_seconds}"
    if kill -0 "${command_pid}" 2>/dev/null; then
      echo "Timed out after ${timeout_seconds}s: $*" >&2
      kill "${command_pid}" 2>/dev/null || true
    fi
  ) &
  local watchdog_pid=$!

  local status=0
  wait "${command_pid}" || status=$?
  kill "${watchdog_pid}" 2>/dev/null || true
  wait "${watchdog_pid}" 2>/dev/null || true
  return "${status}"
}

echo "==> Xcode"
xcodebuild -version
echo

echo "==> Unit and snapshot tests"
JOYCON_MAPPER_TESTING=1 xcodebuild \
  -project "${PROJECT}" \
  -scheme "${SCHEME}" \
  -configuration Debug \
  -derivedDataPath "${TEST_DERIVED_DATA_PATH}" \
  CODE_SIGNING_ALLOWED=NO \
  -only-testing:JoyconMapperTests \
  test

echo
if [[ "${CI:-}" == "true" || "${RUN_UI_TESTS:-0}" == "1" ]]; then
  echo "==> UI smoke tests"
  run_with_timeout "${UI_TEST_TIMEOUT_SECONDS}" xcodebuild \
    -project "${PROJECT}" \
    -scheme "${SCHEME}" \
    -configuration Debug \
    -derivedDataPath "${UI_TEST_DERIVED_DATA_PATH}" \
    CODE_SIGNING_ALLOWED=NO \
    -only-testing:JoyconMapperUITests \
    -test-timeouts-enabled YES \
    -default-test-execution-time-allowance 60 \
    test
else
  echo "==> UI smoke tests"
  echo "Skipped locally. Set RUN_UI_TESTS=1 to run them."
fi

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
