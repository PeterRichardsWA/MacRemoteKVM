# MacRemoteKVM

Software-only macOS remote display/KVM feasibility project.

## Current Status

The first two technical gates have passed:

1. macOS accepted a software-only virtual 5K display with no physical monitor,
   dummy adapter, or custom hardware.
2. ScreenCaptureKit enumerated that virtual display and captured a true
   5120x2880 frame from it.

The next technical gate is live capture:

1. Start an `SCStream` against the virtual display.
2. Receive continuous `CMSampleBuffer` frames backed by `IOSurface`.
3. Log frame dimensions, frame status, timestamps, and cadence.
4. Measure idle desktop, cursor movement, window drag, and video playback cases.

## Clean-Room Record

The project logbook is the source of truth for sources, experiments, results,
and clean-room boundaries:

```text
docs/clean-room-logbook.md
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

results/
  002-screencapturekit-capture/
    virtual-display-capture-probe.png
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

## Distribution Assumption

These probes use private CoreGraphics virtual-display APIs. The working
assumption is direct Developer ID distribution, not Mac App Store distribution.
