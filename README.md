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

Experiment 009 passed on the target iMac Pro. Both first receiver candidates
sustained a 120-second fullscreen decode/render stress run into the 5120x2880
drawable with hardware decoder sessions, zero decode errors, zero render
failures, and nominal thermal state:

1. H.264 3840x2160 at 60 fps rendered at about 59.95 FPS.
2. HEVC/H.265 3200x1800 at 60 fps rendered at about 59.94 FPS.

Experiment 010 passed on the target iMac Pro. It sent the two validated
compressed stream shapes through local TCP loopback before hardware
decode/render, measuring frame pacing and sender-to-render latency:

1. H.264 3840x2160 at 60 fps sent 1801 frames and rendered 1801 frames at about
   59.93 FPS.
2. HEVC/H.265 3200x1800 at 60 fps sent 1801 frames and rendered 1801 frames at
   about 59.89 FPS.
3. Both candidates had zero decode errors and zero render failures.

Experiment 011 now packages the first real two-Mac transport test. It has
separate receiver and sender modes, uses big-endian network headers, serializes
H.264/HEVC decoder parameter sets, and writes results under the experiment
directory. The local loopback smoke run passed.

The first two-Mac run was over Wi-Fi 6E from the M1 Max MacBook Pro sender to
the iMac Pro receiver:

1. HEVC/H.265 3200x1800 at 60 fps passed for the full 30-second run: 1801
   frames sent, 1801 received, 1801 rendered, zero decode errors, zero render
   failures.
2. H.264 3840x2160 at 60 fps decoded and rendered every received frame, but the
   sender only delivered 1190 frames in 30 seconds, about 39.65 fps. This is a
   transport/sender pacing result for the Wi-Fi 6E path, not a receiver decode
   failure.

The wired Ethernet run passed both candidates:

1. H.264 3840x2160 at 60 fps sent 1801 frames, received 1801 frames, rendered
   1801 frames, and held about 59.89 rendered FPS with zero decode/render
   errors.
2. HEVC/H.265 3200x1800 at 60 fps sent 1801 frames, received 1801 frames,
   rendered 1801 frames, and held 60.00 rendered FPS with zero decode/render
   errors.

Thunderbolt should still be tested when the right cable arrives, but wired
Ethernet has cleared the transport gate enough to start Experiment 012: live
ScreenCaptureKit capture from a software 5K virtual display, live VideoToolbox
encode, and network transport into the same receiver path.

Experiment 012 passed the live HEVC path over wired Ethernet. HEVC/H.265
3200x1800 at 60 fps live capture sent 1721 frames, rendered 1721 frames, and
held about 57.4 rendered FPS, clearing the current 95% pass band with zero
decode/render errors. H.264 3840x2160 live capture completed cleanly but only
sent about 46.8 FPS, so that path is a sender capture/encode pacing problem, not
an iMac Pro receiver decode problem.

Experiment 013 tested that H.264 live path at 3200x1800 at 60 fps using the
same live virtual-display capture, VideoToolbox encode, TCP transport, and
receiver render path. The wired Ethernet run sent and rendered every frame with
zero decode/render errors, but only produced about 56.6 sender FPS. That points
back to sender-side live capture/encode pacing, not iMac Pro receiver decode.

Network timing note: from the Experiment 013 harness update onward, the sender
and receiver perform a small TCP preflight handshake before the timed live
capture window. This keeps Little Snitch or macOS network-permission prompts out
of the measured sender FPS window.

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
  010-loopback-transport-prototype/
    LoopbackTransportProbe
    LoopbackTransportProbe.m
    test.sh
    media/
      h264-3840x2160-60-high-3s.mp4
      hevc-3200x1800-60-main-3s.mp4
    results/
      loopback-transport-summary.md
  011-two-mac-transport/
    TwoMacTransportProbe
    TwoMacTransportProbe.m
    test.sh
    media/
      h264-3840x2160-60-high-3s.mp4
      hevc-3200x1800-60-main-3s.mp4
    results/
      loopback-receiver/
      loopback-sender/
  012-live-capture-transport/
    LiveCaptureTransportProbe
    LiveCaptureTransportProbe.m
    test.sh
    results/
  013-live-h264-shape-tuning/
    LiveH264ShapeProbe
    LiveH264ShapeProbe.m
    test.sh
    results/

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

Loopback transport prototype:

```sh
cd experiments/010-loopback-transport-prototype
./test.sh
```

By default Experiment 010 runs each candidate fullscreen for 30 seconds through
local TCP loopback and writes results under
`experiments/010-loopback-transport-prototype/results/`. For a quick smoke pass:

```sh
MACRKVM_TRANSPORT_SECONDS=5 MACRKVM_FULLSCREEN=no ./test.sh
```

Two-Mac transport:

On the iMac Pro receiver:

```sh
cd experiments/011-two-mac-transport
./test.sh receiver wired-ethernet
```

On the sender Mac:

```sh
cd experiments/011-two-mac-transport
./test.sh sender <receiver-wired-ip> wired-ethernet
```

For Thunderbolt networking, use the same commands with `thunderbolt` as the
label and the receiver IP address from the Thunderbolt network interface.
Results are written under `experiments/011-two-mac-transport/results/<label>/`.

Live capture/encode transport:

On the iMac Pro receiver:

```sh
cd experiments/012-live-capture-transport
./test.sh receiver wired-ethernet-live
```

On the sender Mac:

```sh
cd experiments/012-live-capture-transport
./test.sh sender <receiver-wired-ip> wired-ethernet-live
```

Results are written under
`experiments/012-live-capture-transport/results/<label>/`.

Live H.264 shape tuning:

On the iMac Pro receiver:

```sh
cd experiments/013-live-h264-shape-tuning
./test.sh receiver wired-ethernet-h264-3200
```

On the sender Mac:

```sh
cd experiments/013-live-h264-shape-tuning
./test.sh sender <receiver-wired-ip> wired-ethernet-h264-3200
```

Results are written under
`experiments/013-live-h264-shape-tuning/results/<label>/`.

Sender pacing split:

On the sender Mac:

```sh
cd experiments/014-sender-pacing-split
./test.sh
```

Experiment 014 separates the sender path into capture-only and encode-only
ladders. It does not use the receiver and it does not open a network
connection. Results are written under
`experiments/014-sender-pacing-split/results/<label>/`.

## Distribution Assumption

These probes use private CoreGraphics virtual-display APIs. The working
assumption is direct Developer ID distribution, not Mac App Store distribution.
