# Virtual Display Proof Notes

Date: 2026-10-03

## Result

The local Mac successfully created a software-only virtual display larger than
its connected physical display.

The proof program created a private CoreGraphics virtual display named
`Codex Virtual 5K Probe`.

System Profiler reported:

```text
Codex Virtual 5K Probe:
  Resolution: 5120 x 2880 (5K/UHD+ - Ultra High Definition Plus)
  UI Looks like: 2560 x 1440 @ 60.00Hz
  Mirror: Off
  Online: Yes
  Rotation: Supported
```

This is the exact shape we want for a 27-inch Retina iMac target: macOS sees a
normal Retina workspace that looks like 2560x1440, backed by a 5120x2880 pixel
surface.

## ScreenCaptureKit Capture Result

The next probe also passed.

The capture program created the same kind of virtual 5K display, asked
ScreenCaptureKit to enumerate shareable displays, selected the virtual display,
and captured one image from it.

ScreenCaptureKit reported:

```text
ScreenCaptureKit displays:
  displayID=1 width=1728 height=1117 frame=1728x1117+0+0
  displayID=11 width=2560 height=1440 frame=2560x1440+1728+0  <-- target
```

The captured image reported by the probe:

```text
Captured image: 5120x2880 bitsPerPixel=32 bytesPerRow=20480
```

Filesystem verification with `sips`:

```text
pixelWidth: 5120
pixelHeight: 2880
format: png
```

Output image:

```text
results/002-screencapturekit-capture/virtual-display-capture-probe.png
```

Visual inspection confirmed the PNG contains the virtual desktop wallpaper, not
a blank or malformed buffer.

## Local Probe

Probe location:

```text
experiments/001-virtual-display/VirtualDisplayProbe.m
```

Build command:

```sh
clang -fobjc-arc -framework Foundation -framework CoreGraphics \
  VirtualDisplayProbe.m -o VirtualDisplayProbe
```

Run command:

```sh
./VirtualDisplayProbe --width=5120 --height=2880 --seconds=30
```

The probe uses runtime-present private CoreGraphics classes:

- `CGVirtualDisplayDescriptor`
- `CGVirtualDisplay`
- `CGVirtualDisplaySettings`
- `CGVirtualDisplayMode`

It is intentionally a capability spike, not product architecture.

## Interpretation

The virtual-display blocker is no longer theoretical. On this machine, macOS
can be made to see a software-only 5K display with no physical monitor or dummy
adapter attached.

The next blocker is no longer capture. The next blocker is live frame delivery:

1. Start an `SCStream` against the virtual display.
2. Receive live `CMSampleBuffer` frames backed by `IOSurface`.
3. Verify continuous 5120x2880 frame delivery at useful frame rates.
4. Measure idle desktop, moving cursor, window drag, and video playback cases.

After that, the project can move to stream/render experiments.

## Distribution Implication

This proof relies on private API. It is suitable for direct distribution and
local experimentation assumptions, not Mac App Store assumptions.
