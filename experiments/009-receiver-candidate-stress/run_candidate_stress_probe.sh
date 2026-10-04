#!/bin/zsh
set -euo pipefail

SCRIPT_DIR="${0:A:h}"
REPO_ROOT="${SCRIPT_DIR:h:h}"
RESULT_DIR="${REPO_ROOT}/results/009-receiver-candidate-stress"
BINARY_PATH="${SCRIPT_DIR}/ReceiverCandidateStressProbe"
SOURCE_PATH="${SCRIPT_DIR}/ReceiverCandidateStressProbe.m"
MEDIA_DIR="${REPO_ROOT}/experiments/008-receiver-decode-envelope/media"
SUMMARY_PATH="${RESULT_DIR}/candidate-stress-summary.md"

STRESS_SECONDS="${MACRKVM_STRESS_SECONDS:-120}"
INFLIGHT="${MACRKVM_INFLIGHT:-3}"
FULLSCREEN="${MACRKVM_FULLSCREEN:-yes}"

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
    echo "Use the checked-in ReceiverCandidateStressProbe binary or install Xcode Command Line Tools." >&2
    exit 1
  fi

  echo "Building ReceiverCandidateStressProbe..."
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

run_case() {
  local slug="$1"
  local codec="$2"
  local title="$3"
  local media="$4"
  local result="${RESULT_DIR}/${slug}-stress.md"

  "${BINARY_PATH}" \
    --input="${MEDIA_DIR}/${media}" \
    --output="${result}" \
    --report-title="Experiment 009 Result: ${title} Stress" \
    --codec-name="${codec}" \
    --window-title="MacRemoteKVM Experiment 009 - ${slug}" \
    --duration="${STRESS_SECONDS}" \
    --inflight="${INFLIGHT}" \
    --fullscreen="${FULLSCREEN}" \
    --require-hardware=yes
}

run_case "h264-3840x2160-60" "H.264" "H.264 3840x2160 at 60 fps" "h264-3840x2160-60-high-3s.mp4"
run_case "hevc-3200x1800-60" "HEVC/H.265" "HEVC 3200x1800 at 60 fps" "hevc-3200x1800-60-main-3s.mp4"

extract_value() {
  local file="$1"
  local label="$2"
  local line
  line="$(grep -F -m 1 -- "- ${label}:" "${file}" || true)"
  line="${line#- ${label}: }"
  if [[ -z "${line}" ]]; then
    echo "unavailable"
  else
    echo "${line}"
  fi
}

{
  echo "# Experiment 009 Result: Receiver Candidate Stress Summary"
  echo
  echo "- Requested duration per candidate: ${STRESS_SECONDS} seconds"
  echo "- In-flight decode limit: ${INFLIGHT}"
  echo "- Fullscreen: ${FULLSCREEN}"
  echo
  echo "| Candidate | Hardware session | Rendered frames | Throughput | Realtime multiple | Avg render | Thermal | CPU multiple | Result file |"
  echo "| --- | --- | ---: | ---: | ---: | ---: | --- | ---: | --- |"
  for slug in h264-3840x2160-60 hevc-3200x1800-60; do
    result="${RESULT_DIR}/${slug}-stress.md"
    session_status="$(extract_value "${result}" "Hardware-required session create status")"
    rendered="$(extract_value "${result}" "Rendered frames")"
    fps="$(extract_value "${result}" "Throughput")"
    multiple="$(grep -F -m 1 -- "- Realtime multiple" "${result}" | sed 's/^- Realtime multiple vs [^:]*: //' || true)"
    avg_render="$(extract_value "${result}" "Average synchronous render time")"
    thermal_start="$(extract_value "${result}" "Thermal state start")"
    thermal_end="$(extract_value "${result}" "Thermal state end")"
    cpu_multiple="$(extract_value "${result}" "Process CPU realtime multiple")"
    echo "| ${slug} | ${session_status:-unavailable} | ${rendered:-0} | ${fps:-unavailable} | ${multiple:-unavailable} | ${avg_render:-unavailable} | ${thermal_start:-?} -> ${thermal_end:-?} | ${cpu_multiple:-unavailable} | \`${result:t}\` |"
  done
} > "${SUMMARY_PATH}"

echo "Summary written to ${SUMMARY_PATH}"
