# MacRemoteKVM

Software-only macOS remote display/KVM feasibility project.

## Current Status

The first five technical gates have passed:

1. macOS accepted a software-only virtual 5K display with no physical monitor,
   dummy adapter, or custom hardware.
2. ScreenCaptureKit enumerated that virtual display and captured a true
   5120x2880 frame from it.
3. A live ScreenCaptureKit stream delivered IOSurface-backed 5120x2880 frames
   from an animated virtual display.
4. Live 5120x2880 frames were accepted by a local VideoToolbox HEVC encoder
   with zero encode errors or dropped frames in the short probe.
5. The target iMac Pro Viewer exposes hardware decode support for H.264,
   HEVC/H.265, and HEVC-with-alpha through VideoToolbox.

The receiver decode envelope now has usable points on the target iMac Pro:

1. H.264 3840x2160 at 60 fps created a hardware decoder session and rendered at
   about 59.4 FPS.
2. HEVC/H.265 3200x1800 at 60 fps created a hardware decoder session and
   rendered at about 58.7 FPS.
3. HEVC/H.265 3840x2160 at 60 fps created a hardware decoder session but only
   rendered at about 42.7 FPS.
4. HEVC/H.265 5120x2880 at 30 fps still failed to create a required-hardware
   decoder session.

Experiment 009 now packages the first receiver stress test for those viable
candidates. It runs H.264 4K60 scaled to the 5K display and HEVC 3200x1800@60,
then records hardware decoder status, rendered FPS, render cost, process CPU,
memory, thermal state, and local receiver latency proxies.

## Clean-Room Record

The project logbook is the source of truth for sources, experiments, results,
and clean-room boundaries:

```text
docs/clean-room-logbook.md
```

Workflow preferences are recorded here:

```text
docs/workflow-notes.md
```

Rules:

- Do not reverse engineer proprietary products.
- Do not inspect proprietary binaries, private protocols, strings, or traffic.
- Use public docs, Apple SDK headers, public patent records, our own tests, and
  consciously selected open-source references.
- Record every experiment, including failures.

## Layout

```text
docs/
  clean-room-logbook.md
  receiver-bottleneck-notes.md
  target-viewer-imac-pro-2017.md
  retina-kvm-feasibility-memo.md
  software-only-retinarelay-research-addendum.md
  virtual-display-proof-notes.md

experiments/
  README.md
  001-virtual-display/
    VirtualDisplayProbe.m
  002-screencapturekit-capture/
    VirtualDisplayCaptureProbe.m
  003-live-screencapturekit-stream/
    VirtualDisplayStreamProbe.m
  004-videotoolbox-hevc-encode/
    VirtualDisplayHEVCEncodeProbe.m
  005-receiver-codec-capability/
    ReceiverCodecCapabilityProbe
    ReceiverCodecCapabilityProbe.m
    run_receiver_codec_capability.sh
  006-receiver-decode-render/
    ReceiverDecodeRenderProbe
    ReceiverDecodeRenderProbe.m
    run_h264_decode_render_probe.sh
    media/
      h264-5k60-high-3s.mp4
  007-receiver-hevc-decode-render/
    ReceiverHEVCDecodeRenderProbe
    ReceiverHEVCDecodeRenderProbe.m
    run_hevc_decode_render_probe.sh
    media/
      hevc-5k60-main-3s.mp4
  008-receiver-decode-envelope/
    ReceiverDecodeEnvelopeProbe
    ReceiverDecodeEnvelopeProbe.m
    run_decode_envelope_probe.sh
    media/
      hevc-5120x2880-30-main-3s.mp4
      hevc-4096x2304-60-main-3s.mp4
      hevc-3840x2160-60-main-3s.mp4
      hevc-3200x1800-60-main-3s.mp4
      hevc-2560x1440-60-main-3s.mp4
      h264-3840x2160-60-high-3s.mp4
      h264-2560x1440-60-high-3s.mp4
  009-receiver-candidate-stress/
    ReceiverCandidateStressProbe
    ReceiverCandidateStressProbe.m
    test.sh
    media/
      h264-3840x2160-60-high-3s.mp4
      hevc-3200x1800-60-main-3s.mp4

results/
  002-screencapturekit-capture/
    virtual-display-capture-probe.png
  003-live-screencapturekit-stream/
    stream-probe-result.md
  004-videotoolbox-hevc-encode/
    hevc-encode-result.md
  005-receiver-codec-capability/
    receiver-codec-capability.md
  006-receiver-decode-render/
    h264-decode-render-result.md
  007-receiver-hevc-decode-render/
    hevc-decode-render-result.md
  008-receiver-decode-envelope/
    decode-envelope-summary.md
  009-receiver-candidate-stress/
    candidate-stress-summary.md
```

## Build Probes

Virtual display creation:

```sh
cd experiments/001-virtual-display
clang -fobjc-arc -framework Foundation -framework CoreGraphics \
  VirtualDisplayProbe.m -o VirtualDisplayProbe
./VirtualDisplayProbe --width=5120 --height=2880 --seconds=30
```

ScreenCaptureKit still capture:

```sh
cd experiments/002-screencapturekit-capture
clang -fobjc-arc -framework Foundation -framework CoreGraphics \
  -framework CoreVideo -framework ImageIO -framework ScreenCaptureKit \
  -framework UniformTypeIdentifiers \
  VirtualDisplayCaptureProbe.m -o VirtualDisplayCaptureProbe
./VirtualDisplayCaptureProbe \
  --output=/Users/peterrichards/dev/MacRemoteKVM/results/002-screencapturekit-capture/virtual-display-capture-probe.png
```

Live ScreenCaptureKit stream:

```sh
cd experiments/003-live-screencapturekit-stream
clang -fobjc-arc -framework AppKit -framework Foundation \
  -framework CoreGraphics -framework CoreMedia -framework CoreVideo \
  -framework IOSurface -framework ScreenCaptureKit \
  VirtualDisplayStreamProbe.m -o VirtualDisplayStreamProbe
./VirtualDisplayStreamProbe \
  --output=/Users/peterrichards/dev/MacRemoteKVM/results/003-live-screencapturekit-stream/stream-probe-result.md
```

Local HEVC encode:

```sh
cd experiments/004-videotoolbox-hevc-encode
clang -fobjc-arc -framework AppKit -framework Foundation \
  -framework CoreGraphics -framework CoreMedia -framework CoreVideo \
  -framework IOSurface -framework ScreenCaptureKit -framework VideoToolbox \
  VirtualDisplayHEVCEncodeProbe.m -o VirtualDisplayHEVCEncodeProbe
./VirtualDisplayHEVCEncodeProbe \
  --output=/Users/peterrichards/dev/MacRemoteKVM/results/004-videotoolbox-hevc-encode/hevc-encode-result.md
```

Receiver codec capability:

```sh
cd experiments/005-receiver-codec-capability
./run_receiver_codec_capability.sh
```

H.264 receiver decode/render baseline:

```sh
cd experiments/006-receiver-decode-render
./run_h264_decode_render_probe.sh
```

HEVC receiver decode/render baseline:

```sh
cd experiments/007-receiver-hevc-decode-render
./run_hevc_decode_render_probe.sh
```

Receiver decode envelope ladder:

```sh
cd experiments/008-receiver-decode-envelope
./run_decode_envelope_probe.sh
```

Receiver candidate stress test:

```sh
cd experiments/009-receiver-candidate-stress
./test.sh
```

By default Experiment 009 runs each candidate fullscreen for 120 seconds. To run
a shorter smoke pass, set `MACRKVM_STRESS_SECONDS`, for example:

```sh
MACRKVM_STRESS_SECONDS=15 MACRKVM_FULLSCREEN=no ./test.sh
```

## Distribution Assumption

These probes use private CoreGraphics virtual-display APIs. The working
assumption is direct Developer ID distribution, not Mac App Store distribution.
