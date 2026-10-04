#!/bin/zsh
set -euo pipefail

SCRIPT_DIR="${0:A:h}"
REPO_ROOT="${SCRIPT_DIR:h:h}"
RESULT_DIR="${REPO_ROOT}/results/005-receiver-codec-capability"
RESULT_PATH="${RESULT_DIR}/receiver-codec-capability.md"
BINARY_PATH="${SCRIPT_DIR}/ReceiverCodecCapabilityProbe"
SOURCE_PATH="${SCRIPT_DIR}/ReceiverCodecCapabilityProbe.m"

mkdir -p "${RESULT_DIR}"

if [[ ! -x "${BINARY_PATH}" ]]; then
  if command -v clang >/dev/null 2>&1; then
    clang -fobjc-arc -framework Foundation -framework CoreMedia \
      -framework VideoToolbox \
      "${SOURCE_PATH}" -o "${BINARY_PATH}"
  else
    echo "No executable probe found and clang is unavailable." >&2
    echo "Use the checked-in ReceiverCodecCapabilityProbe binary or install Xcode Command Line Tools." >&2
    exit 1
  fi
fi

"${BINARY_PATH}" --output="${RESULT_PATH}"
echo "Result written to ${RESULT_PATH}"
