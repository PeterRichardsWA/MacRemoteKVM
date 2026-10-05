#!/bin/zsh
set -euo pipefail

SCRIPT_DIR="${0:A:h}"
BINARY_PATH="${SCRIPT_DIR}/NetworkThroughputProbe"
SOURCE_PATH="${SCRIPT_DIR}/NetworkThroughputProbe.c"
RESULT_ROOT="${SCRIPT_DIR}/results"

MODE="${1:-usage}"
HOST="${2:-}"
LABEL_ARG="${3:-}"
PORT="${MACRKVM_PORT:-49330}"
DURATION="${MACRKVM_THROUGHPUT_SECONDS:-10}"
CASES="${MACRKVM_THROUGHPUT_CASES:-3}"
PROGRESS_SECONDS="${MACRKVM_PROGRESS_SECONDS:-10}"

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
      sender|send)
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
  if ! command -v clang >/dev/null 2>&1; then
    echo "No executable probe found and clang is unavailable." >&2
    echo "Install Xcode Command Line Tools on this Mac." >&2
    exit 1
  fi

  echo "Building NetworkThroughputProbe..."
  if ! clang -Wall -Wextra -O2 -arch x86_64 -arch arm64 "${SOURCE_PATH}" -o "${BINARY_PATH}"; then
    echo "Universal build failed; trying a native build for this Mac..."
    clang -Wall -Wextra -O2 "${SOURCE_PATH}" -o "${BINARY_PATH}"
  fi
  chmod +x "${BINARY_PATH}"
  codesign -s - -f "${BINARY_PATH}" >/dev/null 2>&1 || true
}

if [[ ! -x "${BINARY_PATH}" || "${SOURCE_PATH}" -nt "${BINARY_PATH}" ]]; then
  build_probe
fi

usage() {
  cat <<EOF
Experiment 015 Thunderbolt/raw TCP throughput test

Run this on the receiver Mac first:
  ./test.sh receiver thunderbolt-throughput

Then run this on the sender Mac:
  ./test.sh sender <receiver-thunderbolt-ip> thunderbolt-throughput

This test measures single-stream sender-to-receiver TCP throughput using three
payload block sizes: 64 KiB, 256 KiB, and 1 MiB. It performs a network preflight
handshake before each timed payload window, so Little Snitch or macOS network
permission prompts are not included in throughput numbers.

Environment:
  MACRKVM_PORT=${PORT}
  MACRKVM_THROUGHPUT_SECONDS=${DURATION}
  MACRKVM_THROUGHPUT_CASES=${CASES}
  MACRKVM_PROGRESS_SECONDS=${PROGRESS_SECONDS}
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
  echo "Listening on port ${PORT} for ${CASES} throughput case(s)."
  echo "Results: ${RESULT_DIR}/receiver"
  "${BINARY_PATH}" receiver \
    --port="${PORT}" \
    --cases="${CASES}" \
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
  echo "Duration per case: ${DURATION}s"
  echo "Cases: ${CASES}"
  echo "Results: ${RESULT_DIR}/sender"
  run_with_progress "raw TCP sender" \
    "${BINARY_PATH}" sender "${host}" \
      --port="${PORT}" \
      --cases="${CASES}" \
      --duration="${DURATION}" \
      --output-dir="${RESULT_DIR}/sender"
}

case "${MODE}" in
  receiver|receive)
    run_receiver
    ;;
  sender|send)
    run_sender "${HOST}"
    ;;
  usage|help|-h|--help)
    usage
    ;;
  *)
    echo "Unknown mode: ${MODE}" >&2
    usage >&2
    exit 1
    ;;
esac
