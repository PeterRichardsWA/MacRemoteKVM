#!/bin/zsh
set -euo pipefail

SCRIPT_DIR="${0:A:h}"
REPO_ROOT="${SCRIPT_DIR:h:h}"
BENCHMARK_DIR="${REPO_ROOT}/experiments/006-receiver-decode-render"
RESULT_DIR="${REPO_ROOT}/results/007-receiver-hevc-decode-render"
RESULT_PATH="${RESULT_DIR}/hevc-decode-render-result.md"
BINARY_PATH="${BENCHMARK_DIR}/ReceiverDecodeRenderProbe"
SOURCE_PATH="${BENCHMARK_DIR}/ReceiverDecodeRenderProbe.m"
MEDIA_PATH="${SCRIPT_DIR}/media/hevc-5k60-main-3s.mp4"

mkdir -p "${RESULT_DIR}"

if [[ ! -x "${BINARY_PATH}" ]]; then
  if command -v clang >/dev/null 2>&1; then
    clang -fobjc-arc \
      -framework AppKit \
      -framework AVFoundation \
      -framework CoreImage \
      -framework CoreMedia \
      -framework CoreVideo \
      -framework Foundation \
      -framework Metal \
      -framework QuartzCore \
      -framework VideoToolbox \
      "${SOURCE_PATH}" -o "${BINARY_PATH}"
  else
    echo "No executable benchmark found and clang is unavailable." >&2
    echo "Use the checked-in ReceiverDecodeRenderProbe binary or install Xcode Command Line Tools." >&2
    exit 1
  fi
fi

"${BINARY_PATH}" \
  --input="${MEDIA_PATH}" \
  --output="${RESULT_PATH}" \
  --report-title="Experiment 007 Result: HEVC Receiver Decode/Render Baseline" \
  --codec-name="HEVC/H.265" \
  --window-title="MacRemoteKVM Experiment 007" \
  "$@"

echo "Result written to ${RESULT_PATH}"
