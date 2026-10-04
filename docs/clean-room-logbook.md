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

## Next Experiment

Experiment 003 should test live frame delivery:

1. Create the virtual 5K display.
2. Start an `SCStream` against it.
3. Receive continuous `CMSampleBuffer` frames backed by `IOSurface`.
4. Log frame dimensions, timestamps, status, and approximate frame cadence.
5. Do not encode or stream yet; prove live capture stability first.
