#!/bin/zsh
set -euo pipefail

SCRIPT_DIR="${0:A:h}"
REPO_ROOT="${SCRIPT_DIR:h:h}"
RESULT_DIR="${REPO_ROOT}/results/008-receiver-decode-envelope"
BINARY_PATH="${SCRIPT_DIR}/ReceiverDecodeEnvelopeProbe"
SOURCE_PATH="${SCRIPT_DIR}/ReceiverDecodeEnvelopeProbe.m"
SUMMARY_PATH="${RESULT_DIR}/decode-envelope-summary.md"

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
    echo "No executable probe found and clang is unavailable." >&2
    echo "Use the checked-in ReceiverDecodeEnvelopeProbe binary or install Xcode Command Line Tools." >&2
    exit 1
  fi
fi

run_case() {
  local slug="$1"
  local codec="$2"
  local title="$3"
  local media="$4"
  local result="${RESULT_DIR}/${slug}.md"
  shift 4

  "${BINARY_PATH}" \
    --input="${SCRIPT_DIR}/media/${media}" \
    --output="${result}" \
    --report-title="Experiment 008 Result: ${title}" \
    --codec-name="${codec}" \
    --window-title="MacRemoteKVM Experiment 008 - ${slug}" \
    "$@"
}

run_case "hevc-5120x2880-30" "HEVC/H.265" "HEVC 5120x2880 at 30 fps" "hevc-5120x2880-30-main-3s.mp4" "$@"
run_case "hevc-4096x2304-60" "HEVC/H.265" "HEVC 4096x2304 at 60 fps" "hevc-4096x2304-60-main-3s.mp4" "$@"
run_case "hevc-3840x2160-60" "HEVC/H.265" "HEVC 3840x2160 at 60 fps" "hevc-3840x2160-60-main-3s.mp4" "$@"
run_case "hevc-3200x1800-60" "HEVC/H.265" "HEVC 3200x1800 at 60 fps" "hevc-3200x1800-60-main-3s.mp4" "$@"
run_case "hevc-2560x1440-60" "HEVC/H.265" "HEVC 2560x1440 at 60 fps" "hevc-2560x1440-60-main-3s.mp4" "$@"
run_case "h264-3840x2160-60" "H.264" "H.264 3840x2160 at 60 fps" "h264-3840x2160-60-high-3s.mp4" "$@"
run_case "h264-2560x1440-60" "H.264" "H.264 2560x1440 at 60 fps" "h264-2560x1440-60-high-3s.mp4" "$@"

{
  echo "# Experiment 008 Result: Receiver Decode Envelope Summary"
  echo
  echo "| Case | Hardware session | Rendered frames | Throughput | Realtime multiple | Result file |"
  echo "| --- | --- | ---: | ---: | ---: | --- |"
  for result in "${RESULT_DIR}"/*.md; do
    [[ "${result:t}" == "decode-envelope-summary.md" ]] && continue
    case_name="${result:t:r}"
    session_status="$(grep -m 1 "Hardware-required session create status:" "${result}" | sed 's/^- Hardware-required session create status: //')"
    rendered="$(grep -m 1 "Rendered frames:" "${result}" | sed 's/^- Rendered frames: //')"
    fps="$(grep -m 1 "Throughput:" "${result}" | sed 's/^- Throughput: //')"
    multiple="$(grep -m 1 "Realtime multiple" "${result}" | sed 's/^- Realtime multiple vs [^:]*: //')"
    echo "| ${case_name} | ${session_status:-unavailable} | ${rendered:-0} | ${fps:-unavailable} | ${multiple:-unavailable} | \`${result:t}\` |"
  done
} > "${SUMMARY_PATH}"

echo "Summary written to ${SUMMARY_PATH}"
