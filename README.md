# MacRemoteKVM

Software-only macOS remote display/KVM feasibility project.

## Current Status

The first three technical gates have passed:

1. macOS accepted a software-only virtual 5K display with no physical monitor,
   dummy adapter, or custom hardware.
2. ScreenCaptureKit enumerated that virtual display and captured a true
   5120x2880 frame from it.
3. A live ScreenCaptureKit stream delivered IOSurface-backed 5120x2880 frames
   from an animated virtual display.

The next technical gate is encode/render:

1. Feed `SCStream` frames into a local low-latency encoder or renderer.
2. Measure CPU/GPU cost and end-to-end frame latency.
3. Try a local receiver path before adding network transport.

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

results/
  002-screencapturekit-capture/
    virtual-display-capture-probe.png
  003-live-screencapturekit-stream/
    stream-probe-result.md
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

## Distribution Assumption

These probes use private CoreGraphics virtual-display APIs. The working
assumption is direct Developer ID distribution, not Mac App Store distribution.
