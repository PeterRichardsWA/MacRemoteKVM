#!/bin/zsh
set -euo pipefail

SCRIPT_DIR="${0:A:h}"
BINARY_PATH="${SCRIPT_DIR}/LiveNativeIntervalProbe"
SOURCE_PATH="${SCRIPT_DIR}/LiveNativeIntervalProbe.m"
MODE="${1:-usage}"
HOST="${2:-}"
PORT="${MACRKVM_PORT:-49324}"
TRANSPORT_SECONDS="${MACRKVM_TRANSPORT_SECONDS:-30}"
INFLIGHT="${MACRKVM_INFLIGHT:-3}"
FULLSCREEN="${MACRKVM_FULLSCREEN:-yes}"
PROGRESS_SECONDS="${MACRKVM_PROGRESS_SECONDS:-5}"
HEVC_BITRATE_MBPS="${MACRKVM_HEVC_BITRATE_MBPS:-24}"

case "${MODE}" in
  receiver|receive) LABEL_ARG="${2:-}" ;;
  sender|send) LABEL_ARG="${3:-}" ;;
  *) LABEL_ARG="" ;;
esac
RAW_LABEL="${MACRKVM_RESULT_LABEL:-${LABEL_ARG:-thunderbolt-native-hevc-3200}}"
RESULT_LABEL="$(printf '%s' "${RAW_LABEL}" | tr '[:upper:]' '[:lower:]' | sed -E 's/[^a-z0-9._-]+/-/g; s/^-+//; s/-+$//')"
if [[ -z "${RESULT_LABEL}" || "${RESULT_LABEL}" == "." || "${RESULT_LABEL}" == ".." ]]; then
  echo "Choose a result label containing letters or numbers." >&2
  exit 1
fi
RESULT_DIR="${SCRIPT_DIR}/results/${RESULT_LABEL}"

usage() {
  cat <<EOF
Experiment 017: live HEVC 3200x1800, native capture interval

On the iMac Pro receiver first:
  ./test.sh receiver

On the sender Mac:
  ./test.sh sender <receiver-thunderbolt-ip>

Default run: one ${TRANSPORT_SECONDS}-second live stream, about 40-45 seconds
including setup and shutdown after permissions are granted.
Approve Little Snitch network prompts during preflight. The measurement starts
only after the receiver acknowledges preflight.

Both modes default to the same results folder:
  ${RESULT_DIR}/sender/
  ${RESULT_DIR}/receiver/

Optional labels:
  ./test.sh receiver <label>
  ./test.sh sender <receiver-thunderbolt-ip> <same-label>

Settings:
  MACRKVM_PORT=${PORT}
  MACRKVM_TRANSPORT_SECONDS=${TRANSPORT_SECONDS}
  MACRKVM_HEVC_BITRATE_MBPS=${HEVC_BITRATE_MBPS}
  MACRKVM_FULLSCREEN=${FULLSCREEN}
  MACRKVM_INFLIGHT=${INFLIGHT}

Force a source rebuild: ./test.sh build
EOF
}

build_probe() {
  local common_args=(
    -fobjc-arc
    -mmacosx-version-min=15.0
    -framework AppKit
    -framework AVFoundation
    -framework CoreGraphics
    -framework CoreImage
    -framework CoreMedia
    -framework CoreVideo
    -framework Foundation
    -framework IOSurface
    -framework Metal
    -framework QuartzCore
    -framework ScreenCaptureKit
    -framework VideoToolbox
    "${SOURCE_PATH}" -o "${BINARY_PATH}"
  )
  if ! command -v clang >/dev/null 2>&1; then
    echo "The included executable is missing or its source changed, and clang is unavailable." >&2
    echo "Install Xcode Command Line Tools to rebuild." >&2
    exit 1
  fi
  echo "Building LiveNativeIntervalProbe for Intel and Apple Silicon..."
  if ! clang -arch x86_64 -arch arm64 "${common_args[@]}"; then
    echo "Universal build failed; trying a native build..."
    clang "${common_args[@]}"
  fi
  chmod +x "${BINARY_PATH}"
  codesign -s - -f "${BINARY_PATH}"
  shasum -a 256 "${SOURCE_PATH}" | awk '{print $1}' > "${SCRIPT_DIR}/LiveNativeIntervalProbe.source.sha256"
}

run_with_progress() {
  local started="$(date +%s)"
  local pid
  local exit_code=0
  "$@" &
  pid="$!"
  trap 'kill "${pid}" 2>/dev/null || true' INT TERM EXIT
  while kill -0 "${pid}" 2>/dev/null; do
    sleep "${PROGRESS_SECONDS}"
    if kill -0 "${pid}" 2>/dev/null; then
      echo "  Sender: $(($(date +%s) - started))s elapsed including setup/preflight"
    fi
  done
  wait "${pid}" || exit_code="$?"
  trap - INT TERM EXIT
  echo "Sender finished with status ${exit_code}. Results: ${RESULT_DIR}/sender"
  return "${exit_code}"
}

case "${MODE}" in
  build) build_probe; exit 0 ;;
  receiver|receive|sender|send) ;;
  *) usage; exit 0 ;;
esac

if [[ "${MODE}" == sender || "${MODE}" == send ]]; then
  if [[ -z "${HOST}" || "${HOST}" == -* ]]; then
    echo "Sender mode needs the receiver's Thunderbolt IP address." >&2
    exit 1
  fi
fi
if [[ ! "${PORT}" =~ ^[0-9]+$ ]] || (( PORT < 1 || PORT > 65535 )); then
  echo "MACRKVM_PORT must be between 1 and 65535." >&2
  exit 1
fi
for numeric_value in "${TRANSPORT_SECONDS}" "${PROGRESS_SECONDS}"; do
  if [[ ! "${numeric_value}" =~ ^[0-9]+([.][0-9]+)?$ ]] || (( numeric_value <= 0 )); then
    echo "Duration and progress interval must be positive numbers." >&2
    exit 1
  fi
done
for numeric_value in "${INFLIGHT}" "${HEVC_BITRATE_MBPS}"; do
  if [[ ! "${numeric_value}" =~ ^[0-9]+$ ]] || (( numeric_value < 1 )); then
    echo "In-flight count and bitrate must be positive integers." >&2
    exit 1
  fi
done

# Git checkout timestamps can differ even when the bundled binary matches.
# Rebuild only when the source contents differ from the bundled source digest.
EXPECTED_SOURCE_SHA=""
if [[ -f "${SCRIPT_DIR}/LiveNativeIntervalProbe.source.sha256" ]]; then
  EXPECTED_SOURCE_SHA="$(<"${SCRIPT_DIR}/LiveNativeIntervalProbe.source.sha256")"
fi
ACTUAL_SOURCE_SHA="$(shasum -a 256 "${SOURCE_PATH}" | awk '{print $1}')"
if [[ ! -x "${BINARY_PATH}" || "${ACTUAL_SOURCE_SHA}" != "${EXPECTED_SOURCE_SHA}" ]]; then
  build_probe
fi

case "${MODE}" in
  receiver|receive)
    mkdir -p "${RESULT_DIR}/receiver"
    echo "Waiting for one HEVC live stream on port ${PORT}."
    echo "Results: ${RESULT_DIR}/receiver"
    "${BINARY_PATH}" receiver --port="${PORT}" --cases=1 \
      --inflight="${INFLIGHT}" --fullscreen="${FULLSCREEN}" \
      --require-hardware=yes --output-dir="${RESULT_DIR}/receiver"
    ;;
  sender|send)
    mkdir -p "${RESULT_DIR}/sender"
    echo "Destination: ${HOST}:${PORT}"
    echo "HEVC 3200x1800, native capture interval, ${HEVC_BITRATE_MBPS} Mbps"
    echo "Expected runtime: about 40-45s for the default 30s stream, after permissions."
    run_with_progress "${BINARY_PATH}" sender "${HOST}" \
      --port="${PORT}" --duration="${TRANSPORT_SECONDS}" \
      --hevc-bitrate-mbps="${HEVC_BITRATE_MBPS}" \
      --output-dir="${RESULT_DIR}/sender"
    ;;
esac
