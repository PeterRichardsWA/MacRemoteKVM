#!/bin/zsh
set -euo pipefail

SCRIPT_DIR="${0:A:h}"
BINARY_PATH="${SCRIPT_DIR}/LiveCaptureTransportProbe"
SOURCE_PATH="${SCRIPT_DIR}/LiveCaptureTransportProbe.m"
RESULT_ROOT="${SCRIPT_DIR}/results"

MODE="${1:-usage}"
HOST="${2:-}"
LABEL_ARG="${3:-}"
PORT="${MACRKVM_PORT:-49320}"
TRANSPORT_SECONDS="${MACRKVM_TRANSPORT_SECONDS:-30}"
INFLIGHT="${MACRKVM_INFLIGHT:-3}"
FULLSCREEN="${MACRKVM_FULLSCREEN:-yes}"
PROGRESS_SECONDS="${MACRKVM_PROGRESS_SECONDS:-10}"
H264_BITRATE_MBPS="${MACRKVM_H264_BITRATE_MBPS:-35}"
HEVC_BITRATE_MBPS="${MACRKVM_HEVC_BITRATE_MBPS:-20}"

sanitize_label() {
  local raw="$1"
  if [[ -z "${raw}" ]]; then
    echo ""
    return
  fi
  printf "%s" "${raw}" \
    | tr "[:upper:]" "[:lower:]" \
    | sed -E "s/[^a-z0-9._-]+/-/g; s/^-+//; s/-+$//"
}

result_label_for_mode() {
  local label="${MACRKVM_RESULT_LABEL:-}"
  if [[ -z "${label}" ]]; then
    case "${MODE}" in
      receiver|receive)
        label="${HOST}"
        ;;
      sender|send|fixture-sender)
        label="${LABEL_ARG}"
        ;;
    esac
  fi
  sanitize_label "${label}"
}

RESULT_LABEL="$(result_label_for_mode)"
if [[ -n "${RESULT_LABEL}" ]]; then
  RESULT_DIR="${RESULT_ROOT}/${RESULT_LABEL}"
else
  RESULT_DIR="${RESULT_ROOT}"
fi

mkdir -p "${RESULT_DIR}"

build_probe() {
  local common_args=(
    -fobjc-arc
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
    "${SOURCE_PATH}"
    -o "${BINARY_PATH}"
  )

  if ! command -v clang >/dev/null 2>&1; then
    echo "No executable probe found and clang is unavailable." >&2
    echo "Install Xcode Command Line Tools on this Mac." >&2
    exit 1
  fi

  echo "Building LiveCaptureTransportProbe..."
  if ! clang -arch x86_64 -arch arm64 "${common_args[@]}"; then
    echo "Universal build failed; trying a native build for this Mac..."
    clang "${common_args[@]}"
  fi
  chmod +x "${BINARY_PATH}"
  codesign -s - -f "${BINARY_PATH}" >/dev/null 2>&1 || true
}

if [[ ! -x "${BINARY_PATH}" || "${SOURCE_PATH}" -nt "${BINARY_PATH}" ]]; then
  build_probe
fi

usage() {
  cat <<EOF
Experiment 012 live capture/encode transport test

Run this on the iMac Pro receiver first:
  ./test.sh receiver wired-ethernet-live

Then run this on the sender Mac:
  ./test.sh sender <receiver-host-or-ip> wired-ethernet-live

This sender creates a software 5K virtual display, captures it with
ScreenCaptureKit, encodes live with VideoToolbox, and streams the encoded frames
to the receiver.

Environment:
  MACRKVM_PORT=${PORT}
  MACRKVM_TRANSPORT_SECONDS=${TRANSPORT_SECONDS}
  MACRKVM_FULLSCREEN=${FULLSCREEN}
  MACRKVM_INFLIGHT=${INFLIGHT}
  MACRKVM_H264_BITRATE_MBPS=${H264_BITRATE_MBPS}
  MACRKVM_HEVC_BITRATE_MBPS=${HEVC_BITRATE_MBPS}
  MACRKVM_RESULT_LABEL=${RESULT_LABEL}

Results are written under:
  ${RESULT_DIR}
EOF
}

run_with_progress() {
  local label="$1"
  shift
  local started
  local elapsed
  local pid
  local exit_code

  echo
  echo "Starting ${label}"
  started="$(date +%s)"
  "$@" &
  pid="$!"

  while kill -0 "${pid}" >/dev/null 2>&1; do
    sleep "${PROGRESS_SECONDS}"
    if kill -0 "${pid}" >/dev/null 2>&1; then
      elapsed="$(($(date +%s) - started))"
      echo "  ${label}: ${elapsed}s elapsed"
    fi
  done

  exit_code=0
  wait "${pid}" || exit_code="$?"
  elapsed="$(($(date +%s) - started))"
  if [[ "${exit_code}" -eq 0 ]]; then
    echo "Finished ${label} in ${elapsed}s"
  else
    echo "Failed ${label} after ${elapsed}s with status ${exit_code}" >&2
  fi
  return "${exit_code}"
}

run_receiver() {
  mkdir -p "${RESULT_DIR}/receiver"
  echo "Receiver mode"
  echo "Listening on port ${PORT} for 2 live streams."
  echo "Results: ${RESULT_DIR}/receiver"
  "${BINARY_PATH}" receiver \
    --port="${PORT}" \
    --cases=2 \
    --inflight="${INFLIGHT}" \
    --fullscreen="${FULLSCREEN}" \
    --require-hardware=yes \
    --output-dir="${RESULT_DIR}/receiver"
}

run_sender() {
  local host="$1"
  if [[ -z "${host}" ]]; then
    echo "Sender mode needs a receiver host/IP." >&2
    usage >&2
    exit 1
  fi
  mkdir -p "${RESULT_DIR}/sender"
  echo "Live sender mode"
  echo "Destination: ${host}:${PORT}"
  echo "Duration per stream: ${TRANSPORT_SECONDS}s"
  echo "H.264 target bitrate: ${H264_BITRATE_MBPS} Mbps"
  echo "HEVC target bitrate: ${HEVC_BITRATE_MBPS} Mbps"
  echo "Results: ${RESULT_DIR}/sender"
  run_with_progress "live sender" \
    "${BINARY_PATH}" sender "${host}" \
      --port="${PORT}" \
      --duration="${TRANSPORT_SECONDS}" \
      --h264-bitrate-mbps="${H264_BITRATE_MBPS}" \
      --hevc-bitrate-mbps="${HEVC_BITRATE_MBPS}" \
      --output-dir="${RESULT_DIR}/sender"
}

case "${MODE}" in
  receiver|receive)
    run_receiver
    ;;
  sender|send)
    run_sender "${HOST}"
    ;;
  *)
    usage
    ;;
esac
