#!/bin/zsh
set -euo pipefail

SCRIPT_DIR="${0:A:h}"
BINARY_PATH="${SCRIPT_DIR}/TwoMacTransportProbe"
SOURCE_PATH="${SCRIPT_DIR}/TwoMacTransportProbe.m"
MEDIA_DIR="${SCRIPT_DIR}/media"
RESULT_DIR="${SCRIPT_DIR}/results"

MODE="${1:-usage}"
HOST="${2:-}"
PORT="${MACRKVM_PORT:-49320}"
TRANSPORT_SECONDS="${MACRKVM_TRANSPORT_SECONDS:-30}"
INFLIGHT="${MACRKVM_INFLIGHT:-3}"
FULLSCREEN="${MACRKVM_FULLSCREEN:-yes}"
PROGRESS_SECONDS="${MACRKVM_PROGRESS_SECONDS:-10}"

mkdir -p "${RESULT_DIR}"

build_probe() {
  local common_args=(
    -fobjc-arc
    -framework AppKit
    -framework AVFoundation
    -framework CoreImage
    -framework CoreMedia
    -framework CoreVideo
    -framework Foundation
    -framework Metal
    -framework QuartzCore
    -framework VideoToolbox
    "${SOURCE_PATH}"
    -o "${BINARY_PATH}"
  )

  if ! command -v clang >/dev/null 2>&1; then
    echo "No executable probe found and clang is unavailable." >&2
    echo "Use the checked-in TwoMacTransportProbe binary or install Xcode Command Line Tools." >&2
    exit 1
  fi

  echo "Building TwoMacTransportProbe..."
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
Experiment 011 two-Mac transport test

Run this on the iMac Pro receiver first:
  ./test.sh receiver

Then run this on the sender Mac:
  ./test.sh sender <receiver-host-or-ip>

Local smoke test on one Mac:
  MACRKVM_TRANSPORT_SECONDS=5 MACRKVM_FULLSCREEN=no ./test.sh loopback

Environment:
  MACRKVM_PORT=${PORT}
  MACRKVM_TRANSPORT_SECONDS=${TRANSPORT_SECONDS}
  MACRKVM_FULLSCREEN=${FULLSCREEN}
  MACRKVM_INFLIGHT=${INFLIGHT}

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
  echo "Listening on port ${PORT} for 2 streams."
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
  echo "Sender mode"
  echo "Destination: ${host}:${PORT}"
  echo "Duration per stream: ${TRANSPORT_SECONDS}s"
  echo "Results: ${RESULT_DIR}/sender"
  "${BINARY_PATH}" sender "${host}" \
    --port="${PORT}" \
    --duration="${TRANSPORT_SECONDS}" \
    --realtime-pacing=yes \
    --media-dir="${MEDIA_DIR}" \
    --output-dir="${RESULT_DIR}/sender"
}

run_loopback() {
  local loopback_port="${MACRKVM_PORT:-49321}"
  mkdir -p "${RESULT_DIR}/loopback-receiver" "${RESULT_DIR}/loopback-sender"
  echo "Loopback smoke mode"
  echo "Port: ${loopback_port}"
  echo "Duration per stream: ${TRANSPORT_SECONDS}s"

  "${BINARY_PATH}" receiver \
    --port="${loopback_port}" \
    --cases=2 \
    --inflight="${INFLIGHT}" \
    --fullscreen="${FULLSCREEN}" \
    --require-hardware=yes \
    --output-dir="${RESULT_DIR}/loopback-receiver" &
  local receiver_pid="$!"

  sleep 1

  set +e
  run_with_progress "loopback sender" \
    "${BINARY_PATH}" sender "127.0.0.1" \
      --port="${loopback_port}" \
      --duration="${TRANSPORT_SECONDS}" \
      --realtime-pacing=yes \
      --media-dir="${MEDIA_DIR}" \
      --output-dir="${RESULT_DIR}/loopback-sender"
  local sender_status="$?"

  wait "${receiver_pid}"
  local receiver_status="$?"
  set -e

  if [[ "${sender_status}" -ne 0 || "${receiver_status}" -ne 0 ]]; then
    echo "Loopback smoke failed: sender=${sender_status}, receiver=${receiver_status}" >&2
    exit 1
  fi
  echo "Loopback smoke completed."
}

case "${MODE}" in
  receiver|receive)
    run_receiver
    ;;
  sender|send)
    run_sender "${HOST}"
    ;;
  loopback|smoke)
    run_loopback
    ;;
  *)
    usage
    ;;
esac
