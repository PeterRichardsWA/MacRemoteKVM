#!/bin/zsh
set -euo pipefail

SCRIPT_DIR="${0:A:h}"
BINARY_PATH="${SCRIPT_DIR}/CaptureTuningProbe"
SOURCE_PATH="${SCRIPT_DIR}/CaptureTuningProbe.m"
RESULT_ROOT="${SCRIPT_DIR}/results"

MODE="${1:-all}"
LABEL_ARG="${2:-default}"
DURATION="${MACRKVM_DURATION:-10}"
PROGRESS_SECONDS="${MACRKVM_PROGRESS_SECONDS:-10}"

sanitize_label() {
  local raw="$1"
  if [[ -z "${raw}" ]]; then
    echo "default"
    return
  fi
  printf "%s" "${raw}" \
    | tr "[:upper:]" "[:lower:]" \
    | sed -E "s/[^a-z0-9._-]+/-/g; s/^-+//; s/-+$//"
}

RESULT_LABEL="$(sanitize_label "${MACRKVM_RESULT_LABEL:-${LABEL_ARG}}")"
RESULT_DIR="${RESULT_ROOT}/${RESULT_LABEL}"
mkdir -p "${RESULT_DIR}"

build_probe() {
  local common_args=(
    -fobjc-arc
    -framework AppKit
    -framework CoreGraphics
    -framework CoreMedia
    -framework CoreVideo
    -framework Foundation
    -framework IOSurface
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

  echo "Building CaptureTuningProbe..."
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
Experiment 016 ScreenCaptureKit capture tuning

Run the full capture tuning test:
  ./test.sh

Optional labelled run:
  ./test.sh all capture-tuning-30s

This is a sender-only test. It does not use the receiver and it does not open a
network connection. It captures a software 5K virtual display at 3200x1800 and
varies ScreenCaptureKit captureResolution, queueDepth, pixelFormat, and frame
interval.

Environment:
  MACRKVM_DURATION=${DURATION}
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

case "${MODE}" in
  usage|help|-h|--help)
    usage
    ;;
  all)
    echo "Experiment 016 ScreenCaptureKit capture tuning"
    echo "Duration per case: ${DURATION}s"
    echo "Results: ${RESULT_DIR}"
    run_with_progress "capture tuning ladder" \
      "${BINARY_PATH}" all \
        --duration="${DURATION}" \
        --output-dir="${RESULT_DIR}"
    ;;
  capture)
    echo "Experiment 016 ScreenCaptureKit capture tuning"
    echo "Duration per case: ${DURATION}s"
    echo "Results: ${RESULT_DIR}"
    run_with_progress "capture tuning ladder" \
      "${BINARY_PATH}" capture \
        --duration="${DURATION}" \
        --output-dir="${RESULT_DIR}"
    ;;
  *)
    echo "Unknown mode: ${MODE}" >&2
    usage >&2
    exit 1
    ;;
esac
