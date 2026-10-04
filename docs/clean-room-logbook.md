# Clean-Room Development Logbook

Project: Software-only Retina iMac display/KVM feasibility

Purpose: Maintain a dated record showing that technical decisions, tests, and
implementation work were derived from public documentation, platform behavior,
our own experiments, and permissively usable references, without reverse
engineering RetinaRelay or any other proprietary product.

## Clean-Room Rules

1. Do not decompile, disassemble, inspect strings, trace private protocols, or
   capture network traffic from RetinaRelay or similar proprietary products.
2. Use public documentation, Apple SDK headers, public patent records,
   academic/standards material, and appropriately licensed open-source projects.
3. Record sources before relying on them for design decisions.
4. Keep implementation probes small and independently written.
5. Treat GPL code as reference-only unless counsel approves reuse.
6. Treat MIT/permissive code as reusable only after a conscious license decision.
7. Preserve this log with each experiment, including failures.
8. Get IP counsel for patent freedom-to-operate review before commercialization.

## Source Register

| Date | Source | Use |
| --- | --- | --- |
| 2026-10-04 | RetinaRelay public FAQ/changelog/terms | Product-level architecture clues only; no reverse engineering. |
| 2026-10-04 | Apple SDK headers: CoreGraphics, ScreenCaptureKit | API surface and local compilation behavior. |
| 2026-10-04 | PrimeLab VirtualDisplay macOS notes | Public explanation of private `CGVirtualDisplay` class family. |
| 2026-10-04 | OpenDisplay/OpenAirDisplay public docs | Prior-art architecture reference; no code copied. |
| 2026-10-04 | TargetBridge public docs/repository | Prior-art architecture and license awareness; no code copied. |
| 2026-10-04 | Google Patents records for Microsoft, Qualcomm, Avatron families | Patent landscape notes only; not legal advice. |
| 2026-10-04 | Apple VideoToolbox docs and `VTIsHardwareDecodeSupported` | Receiver-side codec capability testing. |
| 2026-10-04 | Intel HEVC/H.265 hardware support note | Public hardware context for older Intel receiver Macs. |
| 2026-10-04 | FFmpeg/libx264 test pattern generation | Synthetic H.264 5K60 fixture generation only; no implementation code copied. |
| 2026-10-04 | FFmpeg/libx265 test pattern generation | Synthetic HEVC/H.265 5K60 fixture generation only; no implementation code copied. |
| 2026-10-04 | FFmpeg/libx264 and libx265 test pattern generation | Synthetic decode-envelope fixtures only; no implementation code copied. |

## Architecture Note: Receiver Bottleneck

Date: 2026-10-04

The Host/Sender is expected to be the faster Mac. It can spend more CPU, GPU,
and media-engine budget on virtual display creation, capture, and encoding.

The Viewer/Receiver is expected to be the older 5K iMac or iMac Pro. Therefore,
the critical codec decision should be driven by what the Viewer can decode and
render at low latency. Sender-side encode speed is useful, but it is not the
primary bottleneck.

Artifact:

- `docs/receiver-bottleneck-notes.md`
- `docs/target-viewer-imac-pro-2017.md`

## Experiment 001: Create Software-Only 5K Virtual Display

Date: 2026-10-03

Question: Can a Mac be made to see a larger software-only display than the
physical display it has connected?

Implementation:

- Wrote `experiments/001-virtual-display/VirtualDisplayProbe.m`.
- Used runtime-present private CoreGraphics classes:
  - `CGVirtualDisplayDescriptor`
  - `CGVirtualDisplay`
  - `CGVirtualDisplaySettings`
  - `CGVirtualDisplayMode`
- No proprietary binaries or protocols inspected.

Build command:

```sh
clang -fobjc-arc -framework Foundation -framework CoreGraphics \
  VirtualDisplayProbe.m -o VirtualDisplayProbe
```

Run command:

```sh
./VirtualDisplayProbe --width=5120 --height=2880 --seconds=30
```

Result:

```text
Codex Virtual 5K Probe:
  Resolution: 5120 x 2880 (5K/UHD+ - Ultra High Definition Plus)
  UI Looks like: 2560 x 1440 @ 60.00Hz
  Mirror: Off
  Online: Yes
  Rotation: Supported
```

Conclusion: Passed. macOS accepted a software-only 5K virtual display with no
physical monitor, dummy plug, or custom hardware.

Artifact:

- `docs/virtual-display-proof-notes.md`

## Experiment 002: Capture Virtual 5K Display With ScreenCaptureKit

Date: 2026-10-03

Question: Can ScreenCaptureKit enumerate and capture the software-only virtual
display at true 5120x2880 backing resolution?

Implementation:

- Wrote `experiments/002-screencapturekit-capture/VirtualDisplayCaptureProbe.m`.
- Created the virtual display independently.
- Used ScreenCaptureKit `SCShareableContent` to enumerate displays.
- Used `SCScreenshotManager` to capture one image from the virtual display.
- Saved the output as PNG.
- No proprietary binaries or protocols inspected.

Build command:

```sh
clang -fobjc-arc -framework Foundation -framework CoreGraphics \
  -framework CoreVideo -framework ImageIO -framework ScreenCaptureKit \
  -framework UniformTypeIdentifiers \
  VirtualDisplayCaptureProbe.m -o VirtualDisplayCaptureProbe
```

Run command:

```sh
./VirtualDisplayCaptureProbe
```

ScreenCaptureKit enumeration:

```text
ScreenCaptureKit displays:
  displayID=1 width=1728 height=1117 frame=1728x1117+0+0
  displayID=11 width=2560 height=1440 frame=2560x1440+1728+0  <-- target
```

Probe result:

```text
Captured image: 5120x2880 bitsPerPixel=32 bytesPerRow=20480
Wrote PNG: /Users/peterrichards/dev/MacRemoteKVM/results/002-screencapturekit-capture/virtual-display-capture-probe.png
```

Independent file verification:

```text
pixelWidth: 5120
pixelHeight: 2880
format: png
```

Conclusion: Passed. ScreenCaptureKit can capture the software-only virtual 5K
display at true 5120x2880 pixel resolution.

Artifacts:

- `results/002-screencapturekit-capture/virtual-display-capture-probe.png`
- `docs/virtual-display-proof-notes.md`
- `experiments/002-screencapturekit-capture/VirtualDisplayCaptureProbe.m`

## Experiment 003: Stream Live Virtual 5K Frames With ScreenCaptureKit

Date: 2026-10-03

Question: Can ScreenCaptureKit deliver continuous live `CMSampleBuffer` frames
from the software-only virtual 5K display, with buffers backed by `IOSurface`?

Implementation:

- Wrote `experiments/003-live-screencapturekit-stream/VirtualDisplayStreamProbe.m`.
- Created the virtual display independently.
- Opened a borderless animated AppKit window on the virtual display to force
  visible frame changes.
- Used `SCStream` to capture the display as live screen frames.
- Logged frame dimensions, frame status, IOSurface presence, timestamps, and
  dirty rect counts.
- No proprietary binaries or protocols inspected.

Build command:

```sh
clang -fobjc-arc -framework AppKit -framework Foundation \
  -framework CoreGraphics -framework CoreMedia -framework CoreVideo \
  -framework IOSurface -framework ScreenCaptureKit \
  VirtualDisplayStreamProbe.m -o VirtualDisplayStreamProbe
```

Run command:

```sh
./VirtualDisplayStreamProbe --seconds=5 --frames=180 \
  --output=/Users/peterrichards/dev/MacRemoteKVM/results/003-live-screencapturekit-stream/stream-probe-result.md
```

ScreenCaptureKit enumeration:

```text
ScreenCaptureKit displays:
  displayID=1 width=1728 height=1117 frame=1728x1117+0+0
  displayID=12 width=2560 height=1440 frame=2560x1440+1728+0  <-- target
```

Probe result:

```text
Expected frame size: 5120x2880
First frame size: 5120x2880
Last frame size: 5120x2880
Callbacks: 180
Complete frames: 180
Idle frames: 0
Blank frames: 0
Suspended frames: 0
Observed callback FPS: 57.34
Observed complete-frame FPS: 57.34
Saw IOSurface-backed buffers: yes
All image-buffer dimensions matched expected: yes
Stream error: none
```

Conclusion: Passed. ScreenCaptureKit delivered continuous live 5120x2880 frames
from the software-only virtual display, and the buffers were IOSurface-backed.

Artifacts:

- `experiments/003-live-screencapturekit-stream/VirtualDisplayStreamProbe.m`
- `results/003-live-screencapturekit-stream/stream-probe-result.md`

## Experiment 004: Encode Live Virtual 5K Frames With VideoToolbox HEVC

Date: 2026-10-03

Question: Can live 5120x2880 frames from the software-only virtual display be
accepted by a local VideoToolbox HEVC encoder without network transport?

Implementation:

- Wrote `experiments/004-videotoolbox-hevc-encode/VirtualDisplayHEVCEncodeProbe.m`.
- Created the virtual display independently.
- Opened a borderless animated AppKit window on the virtual display to force
  changing input frames.
- Used `SCStream` to capture 5120x2880 BGRA frames.
- Submitted complete IOSurface-backed frames into a VideoToolbox HEVC
  compression session configured for realtime, low-latency operation.
- Logged encode calls, output callbacks, encoded bytes, dropped-frame flags,
  keyframes, and rough encode cadence.
- No proprietary binaries or protocols inspected.

Build command:

```sh
clang -fobjc-arc -framework AppKit -framework Foundation \
  -framework CoreGraphics -framework CoreMedia -framework CoreVideo \
  -framework IOSurface -framework ScreenCaptureKit -framework VideoToolbox \
  VirtualDisplayHEVCEncodeProbe.m -o VirtualDisplayHEVCEncodeProbe
```

Run command:

```sh
./VirtualDisplayHEVCEncodeProbe --seconds=8 --frames=180 --bitrate-mbps=120 \
  --output=/Users/peterrichards/dev/MacRemoteKVM/results/004-videotoolbox-hevc-encode/hevc-encode-result.md
```

Probe result:

```text
Codec: HEVC
Expected frame size: 5120x2880
Target bitrate: 120 Mbps
Encoder setup: low-latency create status: 0; prepare status: 0
Complete input frames: 180
Submitted to encoder: 180
Encode call errors: 0
Encode call dropped flags: 0
Encoder output callbacks: 180
Encoded frames: 180
Output errors: 0
Output dropped frames: 0
Key frames: 3
Total encoded bytes: 9098993
Observed submit FPS: 28.07
Observed encoded FPS: 27.87
Observed encoded bitrate: 11.33 Mbps
Raw-to-encoded ratio: 1166.81:1
Saw IOSurface-backed input buffers: yes
All input dimensions matched expected: yes
Stream error: none
```

Conclusion: Passed functionally. VideoToolbox HEVC accepted and encoded all 180
live 5120x2880 frames with no encode errors and no dropped-frame flags.

Performance note: This probe encoded at roughly 28 FPS, not 60 FPS. HEVC is a
valid baseline path, but this result does not yet prove HEVC can meet the 5K60
target.

Artifacts:

- `experiments/004-videotoolbox-hevc-encode/VirtualDisplayHEVCEncodeProbe.m`
- `results/004-videotoolbox-hevc-encode/hevc-encode-result.md`

## Experiment 005: Receiver Codec Capability Probe

Date: 2026-10-04

Question: What hardware decode capabilities does the Viewer/Receiver Mac expose
through VideoToolbox?

Implementation:

- Wrote `experiments/005-receiver-codec-capability/ReceiverCodecCapabilityProbe.m`.
- Packaged a signed universal `x86_64`/`arm64` binary so the iMac Pro can run
  the test even if Xcode Command Line Tools are not installed.
- Added `run_receiver_codec_capability.sh` to run the binary and write results
  to the project `results/` directory.
- Uses public VideoToolbox APIs:
  - `VTIsHardwareDecodeSupported`
  - `VTCopyVideoEncoderList`
- Records macOS version, hardware model, CPU brand, memory, hardware decode
  support, and available VideoToolbox encoders.
- No proprietary binaries or protocols inspected.

Build command:

```sh
clang -fobjc-arc -arch x86_64 -arch arm64 -mmacosx-version-min=15.0 \
  -framework Foundation -framework CoreMedia \
  -framework VideoToolbox \
  experiments/005-receiver-codec-capability/ReceiverCodecCapabilityProbe.m \
  -o experiments/005-receiver-codec-capability/ReceiverCodecCapabilityProbe
codesign -s - experiments/005-receiver-codec-capability/ReceiverCodecCapabilityProbe
```

Run command:

```sh
./run_receiver_codec_capability.sh
```

Local sanity result:

```text
Hardware model: MacBookPro18,2
CPU brand: Apple M1 Max
H.264 hardware decode: yes
HEVC/H.265 hardware decode: yes
ProRes Proxy/LT/422/HQ hardware decode: yes
JPEG hardware decode: yes
AV1 hardware decode: no
```

Conclusion: Probe passed locally, but the local result is only a sanity check on
the development Mac. The target Viewer result below is the decisive codec
capability result.

Target Viewer result:

```text
Hardware model: iMacPro1,1
CPU brand: Intel(R) Xeon(R) W-2191B CPU @ 2.30GHz
GPU: Radeon Pro Vega 64, 16 GB VRAM
Built-in display: Retina 5K (5120 x 2880)
H.264 hardware decode: yes
HEVC/H.265 hardware decode: yes
HEVC with Alpha hardware decode: yes
ProRes Proxy/LT/422/HQ hardware decode: no
JPEG hardware decode: no
AV1 hardware decode: no
```

Conclusion: Passed. The target iMac Pro reports hardware decode support for
H.264 and HEVC/H.265, including HEVC with alpha. It does not report hardware
decode support for ProRes 422 variants, JPEG, or AV1 through
`VTIsHardwareDecodeSupported`. Experiment 006 should therefore measure actual
5K receiver decode/render throughput for H.264 and HEVC first.

Artifacts:

- `docs/receiver-bottleneck-notes.md`
- `docs/target-viewer-imac-pro-2017.md`
- `experiments/005-receiver-codec-capability/ReceiverCodecCapabilityProbe`
- `experiments/005-receiver-codec-capability/ReceiverCodecCapabilityProbe.m`
- `experiments/005-receiver-codec-capability/run_receiver_codec_capability.sh`
- `results/005-receiver-codec-capability/receiver-codec-capability.md`

## Experiment 006: H.264 Receiver Decode/Render Baseline

Date: 2026-10-04

Question: Can the Viewer/Receiver create a required-hardware VideoToolbox H.264
decoder for a 5120x2880 60 fps stream, and if so can it decode and render that
stream through the display path?

Implementation:

- Generated `experiments/006-receiver-decode-render/media/h264-5k60-high-3s.mp4`
  from a synthetic `testsrc2` pattern using local FFmpeg/libx264 tooling.
- The fixture is H.264/AVC High Profile, Level 6.2, 5120x2880, 60 fps, three
  seconds, roughly 45 Mbps, with 180 encoded frames.
- Wrote `experiments/006-receiver-decode-render/ReceiverDecodeRenderProbe.m`.
- Uses Apple APIs:
  - `AVAssetReader` to read compressed H.264 samples from the MP4 fixture.
  - `VTDecompressionSessionCreate` with
    `kVTVideoDecoderSpecification_RequireHardwareAcceleratedVideoDecoder`.
  - `CAMetalLayer` plus Core Image to render decoded `CVPixelBuffer` frames.
- Packaged a signed universal `x86_64`/`arm64` binary for the iMac Pro.
- No proprietary binaries or protocols inspected.
- No FFmpeg/x264 implementation code was copied into this project.

Run command:

```sh
./run_h264_decode_render_probe.sh
```

Local smoke result:

```text
Hardware model: MacBookPro18,2
Input: H.264 High Profile Level 6.2, 5120x2880, 60 fps, 180 frames
Required hardware decoder: yes
Hardware-required session create status: -12911 (kVTVideoDecoderMalfunctionErr)
Fallback session create status without hardware requirement: 0 (noErr)
```

Conclusion: The local smoke run successfully exercised the test harness, but the
M1 Max development Mac could not create a required-hardware H.264 decoder
session for the 5K H.264 fixture. The target iMac Pro result below is the
decisive H.264 receiver result.

Target Viewer result:

```text
Hardware model: iMacPro1,1
CPU brand: Intel(R) Xeon(R) W-2191B CPU @ 2.30GHz
Input: H.264 High Profile Level 6.2, 5120x2880, 60 fps, 180 frames
Required hardware decoder: yes
Hardware-required session create status: -12913 (kVTVideoDecoderNotAvailableNowErr)
Fallback session create status without hardware requirement: 0 (noErr)
Drawable size: 5120 x 2880
Rendered frames: 0
```

Conclusion: Failed as a 5K H.264 hardware receiver path. The target iMac Pro
could not create a required-hardware VideoToolbox decoder session for the
5120x2880/60 fps H.264 test stream. Since software fallback is available but
does not satisfy the low-latency hardware-decode requirement, H.264 should not
be the first transport codec for the 5K prototype. Experiment 007 should test
HEVC/H.265 receiver decode/render using the same benchmark structure.

Artifacts:

- `experiments/006-receiver-decode-render/ReceiverDecodeRenderProbe`
- `experiments/006-receiver-decode-render/ReceiverDecodeRenderProbe.m`
- `experiments/006-receiver-decode-render/run_h264_decode_render_probe.sh`
- `experiments/006-receiver-decode-render/media/h264-5k60-high-3s.mp4`
- `results/006-receiver-decode-render/h264-decode-render-result.md`

## Experiment 007: HEVC Receiver Decode/Render Baseline

Date: 2026-10-04

Question: Can the Viewer/Receiver create a required-hardware VideoToolbox HEVC
decoder for a 5120x2880 60 fps stream, and if so can it decode and render that
stream through the display path?

Implementation:

- Generated `experiments/007-receiver-hevc-decode-render/media/hevc-5k60-main-3s.mp4`
  from a synthetic `testsrc2` pattern using local FFmpeg/libx265 tooling.
- The fixture is HEVC/H.265 Main Profile, 5120x2880, 60 fps, three seconds,
  roughly 32 Mbps, with 180 encoded frames.
- Reused `experiments/006-receiver-decode-render/ReceiverDecodeRenderProbe.m`
  as a codec-label-aware benchmark harness.
- Added `experiments/007-receiver-hevc-decode-render/ReceiverHEVCDecodeRenderProbe.m`
  as the Experiment 007 wrapper source with HEVC defaults.
- Packaged a signed universal `x86_64`/`arm64` binary directly in the
  Experiment 007 directory.
- Uses Apple APIs:
  - `AVAssetReader` to read compressed HEVC samples from the MP4 fixture.
  - `VTDecompressionSessionCreate` with
    `kVTVideoDecoderSpecification_RequireHardwareAcceleratedVideoDecoder`.
  - `CAMetalLayer` plus Core Image to render decoded `CVPixelBuffer` frames.
- No proprietary binaries or protocols inspected.
- No FFmpeg/x265 implementation code was copied into this project.

Run command:

```sh
./run_hevc_decode_render_probe.sh
```

Local smoke result:

```text
Hardware model: MacBookPro18,2
Input: HEVC/H.265 Main Profile, 5120x2880, 60 fps, 180 frames
Required hardware decoder: yes
Hardware-required session create status: 0 (noErr)
Rendered frames: 180
Render failures: 0
Throughput: 119.19 rendered FPS
Realtime multiple vs 60.00 FPS input: 1.99x
```

Conclusion: The local smoke run passed on the development Mac. The decisive
result still needs to come from the target iMac Pro Viewer.

Target Viewer result:

```text
Hardware model: iMacPro1,1
CPU brand: Intel(R) Xeon(R) W-2191B CPU @ 2.30GHz
Input: HEVC/H.265 Main Profile, 5120x2880, 60 fps, 180 frames
Required hardware decoder: yes
Hardware-required session create status: -12907 (kVTCouldNotCreateInstanceErr)
Fallback session create status without hardware requirement: 0 (noErr)
Drawable size: 5120 x 2880
Rendered frames: 0
```

Conclusion: Failed as a 5K60 HEVC hardware receiver path. The target iMac Pro
could not create a required-hardware VideoToolbox decoder session for the
5120x2880/60 fps HEVC test stream. Since software fallback is available but
does not satisfy the low-latency hardware-decode requirement, the next test
should map the receiver's practical hardware decode envelope across lower
resolutions and frame rates.

Artifacts:

- `experiments/007-receiver-hevc-decode-render/ReceiverHEVCDecodeRenderProbe`
- `experiments/007-receiver-hevc-decode-render/ReceiverHEVCDecodeRenderProbe.m`
- `experiments/007-receiver-hevc-decode-render/run_hevc_decode_render_probe.sh`
- `experiments/007-receiver-hevc-decode-render/media/hevc-5k60-main-3s.mp4`
- `results/007-receiver-hevc-decode-render/hevc-decode-render-result.md`

## Experiment 008: Receiver Decode Envelope Ladder

Date: 2026-10-04

Question: Since 5120x2880 at 60 fps failed for both H.264 and HEVC on the target
iMac Pro, what lower resolution and frame-rate points can create a
required-hardware VideoToolbox decoder session and render successfully?

Implementation:

- Generated synthetic `testsrc2` MP4 fixtures:
  - HEVC/H.265 5120x2880 at 30 fps.
  - HEVC/H.265 4096x2304 at 60 fps.
  - HEVC/H.265 3840x2160 at 60 fps.
  - HEVC/H.265 3200x1800 at 60 fps.
  - HEVC/H.265 2560x1440 at 60 fps.
  - H.264 3840x2160 at 60 fps.
  - H.264 2560x1440 at 60 fps.
- Added `experiments/008-receiver-decode-envelope/ReceiverDecodeEnvelopeProbe.m`
  as a self-contained wrapper source with Experiment 008 defaults.
- Reused the native Apple API benchmark harness from Experiment 006.
- Added `run_decode_envelope_probe.sh` to run each fixture and create
  `results/008-receiver-decode-envelope/decode-envelope-summary.md`.
- No proprietary binaries or protocols inspected.
- No FFmpeg/x264/x265 implementation code was copied into this project.

Run command:

```sh
./run_decode_envelope_probe.sh
```

Local smoke result:

```text
All seven ladder points created required-hardware decoder sessions on the M1 Max
development Mac. Each rendered all frames with no decode output errors or render
failures.
```

Conclusion: The ladder package works locally. The target iMac Pro result below
is the decisive receiver-envelope result.

Target Viewer result:

```text
H.264 2560x1440 @ 60: hardware session yes, 180 frames, 59.68 rendered FPS
H.264 3840x2160 @ 60: hardware session yes, 180 frames, 59.38 rendered FPS
HEVC 2560x1440 @ 60: hardware session yes, 180 frames, 59.72 rendered FPS
HEVC 3200x1800 @ 60: hardware session yes, 180 frames, 58.71 rendered FPS
HEVC 3840x2160 @ 60: hardware session yes, 180 frames, 42.67 rendered FPS
HEVC 4096x2304 @ 60: hardware session yes, 180 frames, 37.54 rendered FPS
HEVC 5120x2880 @ 30: hardware session no, -12907 (kVTCouldNotCreateInstanceErr)
```

Conclusion: Passed. The iMac Pro can hardware-decode and render substantial
receiver streams. The strongest passing candidate so far is H.264 3840x2160 at
60 fps, rendered at about 59.4 FPS into the 5120x2880 drawable. HEVC 3200x1800
at 60 fps is also plausible at about 58.7 FPS and lower bitrate. HEVC at 3840x2160
and 4096x2304 creates hardware sessions but does not sustain 60 FPS in this
probe. HEVC 5120x2880 at 30 fps cannot create a required-hardware decoder
session on this machine.

Artifacts:

- `experiments/008-receiver-decode-envelope/ReceiverDecodeEnvelopeProbe`
- `experiments/008-receiver-decode-envelope/ReceiverDecodeEnvelopeProbe.m`
- `experiments/008-receiver-decode-envelope/run_decode_envelope_probe.sh`
- `experiments/008-receiver-decode-envelope/media/`
- `results/008-receiver-decode-envelope/`

## Experiment 009: Receiver Candidate Stress

Date: 2026-10-04

Question: Do the first viable receiver candidates remain stable over a longer
local decode/render run, and what local receiver health signals do they show?

Candidate paths:

- H.264 3840x2160 at 60 fps scaled to the 5K display.
- HEVC/H.265 3200x1800 at 60 fps scaled to the 5K display.

Implementation:

- Added `experiments/009-receiver-candidate-stress/ReceiverCandidateStressProbe.m`.
- Added a self-contained `experiments/009-receiver-candidate-stress/media/`
  directory containing the two required input streams.
- Reused the native Apple API benchmark harness from Experiment 006.
- Loops the selected compressed fixture for a configurable duration while
  requiring a hardware VideoToolbox decoder.
- Renders through `CAMetalLayer` plus Core Image.
- Records hardware session status, rendered FPS, render failures, VideoToolbox
  dropped-frame flags, process CPU time, resident memory, thermal state, decoder
  startup time, and average synchronous render cost.
- Writes one report per candidate plus
  `results/009-receiver-candidate-stress/candidate-stress-summary.md`.
- No proprietary binaries or protocols inspected.
- No FFmpeg/x264/x265 implementation code was copied into this project.

Run command:

```sh
./test.sh
```

Local smoke result:

```text
Machine: MacBookPro18,2, Apple M1 Max
Run mode: windowed, 3 seconds per candidate, self-contained media directory
H.264 3840x2160 @ 60: hardware session yes, 357 frames, 118.31 rendered FPS
HEVC 3200x1800 @ 60: hardware session yes, 363 frames, 120.29 rendered FPS
Decode errors: 0
Render failures: 0
Thermal state: nominal -> nominal for both candidates
```

Conclusion: The Experiment 009 package works locally. The local smoke test used
a smaller windowed drawable, so it is not the decisive receiver result.

Target Viewer result:

```text
Machine: iMacPro1,1, Intel Xeon W-2191B, Radeon Pro Vega 64, macOS 15.8
Run mode: fullscreen, 120 seconds per candidate, 5120x2880 drawable
H.264 3840x2160 @ 60: hardware session yes, 7196 frames, 59.95 rendered FPS
HEVC 3200x1800 @ 60: hardware session yes, 7196 frames, 59.94 rendered FPS
Decode errors: 0
Render failures: 0
VideoToolbox dropped-frame flags: 0
Thermal state: nominal -> nominal for both candidates
Process CPU realtime multiple: 0.08x for both candidates
Average synchronous render cost: about 16.32 ms for both candidates
```

Conclusion: Passed. Both first receiver candidates sustained the 120-second
fullscreen stress run on the target iMac Pro. H.264 3840x2160@60 should be the
detail-first prototype path. HEVC 3200x1800@60 should remain the lower-bandwidth
prototype path. This does not yet prove network transport, sender capture,
end-to-end latency, cursor/input loop behavior, or visual quality on real
desktop content.

Artifacts:

- `experiments/009-receiver-candidate-stress/ReceiverCandidateStressProbe`
- `experiments/009-receiver-candidate-stress/ReceiverCandidateStressProbe.m`
- `experiments/009-receiver-candidate-stress/test.sh`
- `experiments/009-receiver-candidate-stress/media/`
- `results/009-receiver-candidate-stress/`

## Experiment 010: Loopback Transport Prototype

Date: 2026-10-04

Question: Can the first validated compressed stream shapes survive a software
transport framing path before hardware decode/render, while maintaining 60 fps
frame pacing and useful local latency?

Candidate paths:

- H.264 3840x2160 at 60 fps.
- HEVC/H.265 3200x1800 at 60 fps.

Implementation:

- Added `experiments/010-loopback-transport-prototype/LoopbackTransportProbe.m`.
- Added a self-contained `experiments/010-loopback-transport-prototype/media/`
  directory containing the two required input streams.
- Added `experiments/010-loopback-transport-prototype/test.sh`.
- Results are written under
  `experiments/010-loopback-transport-prototype/results/`, matching the
  experiment-local result convention adopted after this test.
- Sends one compressed sample payload per frame over local TCP loopback from a
  sender thread to a receiver thread.
- Rebuilds `CMSampleBuffer` objects on the receiver side, requires a hardware
  VideoToolbox decoder, and renders through `CAMetalLayer` plus Core Image.
- Records frame counts, loopback bitrate, decode/render throughput,
  sender-to-receiver payload latency, and sender-to-rendered-frame latency.
- Prototype limitations are recorded in the reports: decoder config is shared
  in-process from the local asset format description, and the frame header is a
  native-endian prototype. The next two-Mac transport test should serialize the
  decoder config and use a network-stable header.
- No proprietary binaries or protocols inspected.
- No FFmpeg/x264/x265 implementation code was copied into this project.

Run command:

```sh
./test.sh
```

Local smoke result:

```text
Machine: MacBookPro18,2, Apple M1 Max
Run mode: windowed, 2 seconds per candidate, local TCP loopback
H.264 3840x2160 @ 60: hardware session yes, 121 sent, 121 rendered, 60.07 rendered FPS
HEVC 3200x1800 @ 60: hardware session yes, 121 sent, 121 rendered, 60.28 rendered FPS
Decode errors: 0
Render failures: 0
Average sender-to-rendered-frame latency: 3.985 ms for H.264, 3.493 ms for HEVC
```

Conclusion: The Experiment 010 package works locally. The local smoke test used
a smaller windowed drawable, so it is not the decisive receiver result.

Target Viewer result:

```text
Machine: iMacPro1,1, Intel Xeon W-2191B, Radeon Pro Vega 64, macOS 15.8
Run mode: fullscreen, 30 seconds per candidate, local TCP loopback
H.264 3840x2160 @ 60: hardware session yes, 1801 sent, 1801 rendered, 59.93 rendered FPS
HEVC 3200x1800 @ 60: hardware session yes, 1801 sent, 1801 rendered, 59.89 rendered FPS
Decode errors: 0
Render failures: 0
VideoToolbox dropped-frame flags: 0
Average sender-to-receiver payload latency: 2.353 ms for H.264, 2.510 ms for HEVC
Average sender-to-rendered-frame latency: 49.309 ms for H.264, 51.182 ms for HEVC
Measured transport bitrate: 20.74 Mbps for H.264, 14.13 Mbps for HEVC
```

Conclusion: Passed. Both validated stream shapes survived the local loopback
transport path on the target iMac Pro with 1:1 sent/rendered frame counts, no
decode errors, no render failures, and sustained 60 fps pacing. The sender-to-
render latency proxy is now roughly 50 ms on the target receiver in this
same-machine loopback setup. This still does not prove real network transport,
live sender capture/encode, cross-machine clock synchronization, or input/cursor
round trip.

Artifacts:

- `experiments/010-loopback-transport-prototype/LoopbackTransportProbe`
- `experiments/010-loopback-transport-prototype/LoopbackTransportProbe.m`
- `experiments/010-loopback-transport-prototype/test.sh`
- `experiments/010-loopback-transport-prototype/media/`
- `experiments/010-loopback-transport-prototype/results/`

## Experiment 011: Two-Mac Transport

Date: 2026-10-04

Question: Can the validated compressed stream shapes be sent from one Mac to
another over TCP with serialized decoder configuration, then hardware-decoded
and rendered on the receiver?

Candidate paths:

- H.264 3840x2160 at 60 fps.
- HEVC/H.265 3200x1800 at 60 fps.

Implementation:

- Added `experiments/011-two-mac-transport/TwoMacTransportProbe.m`.
- Added a self-contained `experiments/011-two-mac-transport/media/` directory
  containing the two required input streams.
- Added `experiments/011-two-mac-transport/test.sh`.
- Added separate `receiver`, `sender`, and `loopback` modes.
- Uses TCP with big-endian network headers.
- Serializes H.264/HEVC parameter sets and NAL unit header length before frame
  payloads. The receiver rebuilds the `CMFormatDescription` from those parameter
  sets.
- Sends one compressed sample payload per frame.
- The receiver requires a hardware VideoToolbox decoder and renders through
  `CAMetalLayer` plus Core Image.
- Receiver reports avoid claiming one-way sender-to-render latency because
  two-Mac clocks are not synchronized. They record receiver-side
  receive-complete-to-render latency and frame interarrival timing.
- No proprietary binaries or protocols inspected.
- No FFmpeg/x264/x265 implementation code was copied into this project.

Run command:

```sh
./test.sh receiver
./test.sh sender <receiver-host-or-ip>
```

Local smoke result:

```text
Machine: MacBookPro18,2, Apple M1 Max
Run mode: local loopback, windowed, 2 seconds per candidate
H.264 3840x2160 @ 60: 121 sent, 121 received, 121 rendered, 63.26 rendered FPS
HEVC 3200x1800 @ 60: 121 sent, 121 received, 121 rendered, 60.42 rendered FPS
Decode errors: 0
Render failures: 0
Serialized parameter sets: 2 for H.264, 4 for HEVC
```

Two-Mac Wi-Fi 6E result:

```text
Network condition: Wi-Fi 6E
Sender: MacBookPro18,2, Apple M1 Max, macOS 26.6.2, peters-macbook-pro.local
Receiver: iMacPro1,1, Intel Xeon W-2191B, macOS 15.8, dadimacpro.local
Destination: 192.168.0.62:49320

H.264 3840x2160 @ 60:
  Sender: 1190 frames sent in 30.010 seconds, 39.65 FPS, 13.67 Mbps
  Receiver: 1190 received, 1190 rendered, 59.92 rendered FPS, 20.66 Mbps
  Decode errors: 0
  Render failures: 0
  Average receive-complete-to-render latency: 49.971 ms
  Average frame interarrival: 16.660 ms

HEVC 3200x1800 @ 60:
  Sender: 1801 frames sent in 30.001 seconds, 60.03 FPS, 14.13 Mbps
  Receiver: 1801 received, 1801 rendered, 59.99 rendered FPS, 14.12 Mbps
  Decode errors: 0
  Render failures: 0
  Average receive-complete-to-render latency: 34.757 ms
  Average frame interarrival: 16.656 ms
```

Conclusion: The Experiment 011 package works locally and across two Macs. The
local smoke test proves the serialized decoder configuration path and TCP
framing path. The Wi-Fi 6E two-Mac result proves that HEVC 3200x1800@60 can
complete a full 30-second sender-to-receiver run into the iMac Pro display path
with 1:1 sent/received/rendered frame counts. H.264 3840x2160@60 did not pass
the Wi-Fi 6E sender/network path in this run because the sender only delivered
1190 frames in 30 seconds. The receiver decoded and rendered every H.264 frame it
received, so this result does not rule out H.264 on a better transport.

Artifacts:

- `experiments/011-two-mac-transport/TwoMacTransportProbe`
- `experiments/011-two-mac-transport/TwoMacTransportProbe.m`
- `experiments/011-two-mac-transport/test.sh`
- `experiments/011-two-mac-transport/media/`
- `experiments/011-two-mac-transport/results/`
- `results/011-two-mac-transport/results/`

## Next Experiment

Rerun the same Experiment 011 package across the two Macs over wired Ethernet
and Thunderbolt networking. Start `./test.sh receiver` on the iMac Pro first,
then run `./test.sh sender <receiver-host-or-ip>` on the sender Mac after
confirming the receiver IP belongs to the wired Ethernet or Thunderbolt network
interface. Compare H.264 3840x2160@60 and HEVC 3200x1800@60 against the Wi-Fi
6E run before changing codecs or stream shapes.

If wired Ethernet or Thunderbolt passes both candidates, the next gate is
replacing prerecorded compressed fixtures with live sender capture/encode.
