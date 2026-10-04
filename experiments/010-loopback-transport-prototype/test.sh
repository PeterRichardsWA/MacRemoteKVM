#!/bin/zsh
set -euo pipefail

SCRIPT_DIR="${0:A:h}"
REPO_ROOT="${SCRIPT_DIR:h:h}"
RESULT_DIR="${REPO_ROOT}/results/010-loopback-transport-prototype"
BINARY_PATH="${SCRIPT_DIR}/LoopbackTransportProbe"
SOURCE_PATH="${SCRIPT_DIR}/LoopbackTransportProbe.m"
MEDIA_DIR="${SCRIPT_DIR}/media"
SUMMARY_PATH="${RESULT_DIR}/loopback-transport-summary.md"

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
    echo "Use the checked-in LoopbackTransportProbe binary or install Xcode Command Line Tools." >&2
    exit 1
  fi

  echo "Building LoopbackTransportProbe..."
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

run_with_progress() {
  local label="$1"
  shift
  local started
  local elapsed
  local pid
  local exit_code

  echo
  echo "Starting ${label}"
  echo "Target duration: ${TRANSPORT_SECONDS}s, fullscreen: ${FULLSCREEN}, in-flight decode limit: ${INFLIGHT}"

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

run_case() {
  local slug="$1"
  local codec="$2"
  local title="$3"
  local media="$4"
  local result="${RESULT_DIR}/${slug}-loopback.md"

  run_with_progress "${slug}" \
    "${BINARY_PATH}" \
    --input="${MEDIA_DIR}/${media}" \
    --output="${result}" \
    --report-title="Experiment 010 Result: ${title} Loopback Transport" \
    --codec-name="${codec}" \
    --window-title="MacRemoteKVM Experiment 010 - ${slug}" \
    --duration="${TRANSPORT_SECONDS}" \
    --inflight="${INFLIGHT}" \
    --fullscreen="${FULLSCREEN}" \
    --realtime-pacing=yes \
    --require-hardware=yes
}

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

echo "Experiment 010 loopback transport prototype"
echo "This sends compressed frame payloads over local TCP before hardware decode/render."
echo "Expected runtime is roughly two ${TRANSPORT_SECONDS}s passes plus build/startup."
echo "Results directory: ${RESULT_DIR}"

run_case "h264-3840x2160-60" "H.264" "H.264 3840x2160 at 60 fps" "h264-3840x2160-60-high-3s.mp4"
run_case "hevc-3200x1800-60" "HEVC/H.265" "HEVC 3200x1800 at 60 fps" "hevc-3200x1800-60-main-3s.mp4"

{
  echo "# Experiment 010 Result: Loopback Transport Summary"
  echo
  echo "- Requested duration per candidate: ${TRANSPORT_SECONDS} seconds"
  echo "- In-flight decode limit: ${INFLIGHT}"
  echo "- Fullscreen: ${FULLSCREEN}"
  echo "- Transport: local TCP loopback"
  echo
  echo "| Candidate | Hardware session | Sent | Rendered | Throughput | Transport bitrate | Avg sender->receiver | Avg sender->render | Result file |"
  echo "| --- | --- | ---: | ---: | ---: | ---: | ---: | ---: | --- |"
  for slug in h264-3840x2160-60 hevc-3200x1800-60; do
    result="${RESULT_DIR}/${slug}-loopback.md"
    session_status="$(extract_value "${result}" "Hardware-required session create status")"
    sent="$(extract_value "${result}" "Sender frames sent")"
    rendered="$(extract_value "${result}" "Rendered frames")"
    fps="$(extract_value "${result}" "Throughput")"
    bitrate="$(extract_value "${result}" "Measured transport bitrate")"
    rx_latency="$(extract_value "${result}" "Average sender-to-receiver payload latency")"
    render_latency="$(extract_value "${result}" "Average sender-to-rendered-frame latency")"
    echo "| ${slug} | ${session_status:-unavailable} | ${sent:-0} | ${rendered:-0} | ${fps:-unavailable} | ${bitrate:-unavailable} | ${rx_latency:-unavailable} | ${render_latency:-unavailable} | \`${result:t}\` |"
  done
} > "${SUMMARY_PATH}"

echo "Summary written to ${SUMMARY_PATH}"
