# Virtual Display Probe

This is a throwaway macOS capability spike. It uses the private CoreGraphics
`CGVirtualDisplay` Objective-C classes to answer one question:

Can this Mac create a software-only display larger than the physically connected
displays?

Build:

```sh
clang -fobjc-arc -framework Foundation -framework CoreGraphics \
  VirtualDisplayProbe.m -o VirtualDisplayProbe
```

Run a short test:

```sh
./VirtualDisplayProbe --width=5120 --height=2880 --seconds=30
```

By default `--width` and `--height` are the backing pixel limit. With HiDPI
enabled, the first advertised mode is half that size in logical points, so the
default test creates a 5120x2880 backing display that looks like 2560x1440 to
macOS.

While it is running, open System Settings > Displays. A display named
`Codex Virtual 5K Probe` should appear. The display should disappear when the
process exits.

Build the capture probe:

```sh
clang -fobjc-arc -framework Foundation -framework CoreGraphics \
  -framework CoreVideo -framework ImageIO -framework ScreenCaptureKit \
  -framework UniformTypeIdentifiers \
  VirtualDisplayCaptureProbe.m -o VirtualDisplayCaptureProbe
```

Run the capture test:

```sh
./VirtualDisplayCaptureProbe
```

Expected result: ScreenCaptureKit enumerates the virtual display and writes a
PNG to `results/002-screencapturekit-capture/virtual-display-capture-probe.png`
when run with the project README's `--output` argument. If macOS prompts for
Screen Recording permission, grant it to the launching app and rerun.

Build the live stream probe:

```sh
cd 003-live-screencapturekit-stream
clang -fobjc-arc -framework AppKit -framework Foundation \
  -framework CoreGraphics -framework CoreMedia -framework CoreVideo \
  -framework IOSurface -framework ScreenCaptureKit \
  VirtualDisplayStreamProbe.m -o VirtualDisplayStreamProbe
```

Run the live stream test:

```sh
./VirtualDisplayStreamProbe
```

Expected result: the probe creates a virtual 5K display, opens an animated
window on it, starts an `SCStream`, receives live IOSurface-backed 5120x2880
frames, and writes a Markdown/CSV report to
`results/003-live-screencapturekit-stream/stream-probe-result.md`.

Build the local HEVC encode probe:

```sh
cd 004-videotoolbox-hevc-encode
clang -fobjc-arc -framework AppKit -framework Foundation \
  -framework CoreGraphics -framework CoreMedia -framework CoreVideo \
  -framework IOSurface -framework ScreenCaptureKit -framework VideoToolbox \
  VirtualDisplayHEVCEncodeProbe.m -o VirtualDisplayHEVCEncodeProbe
```

Run the local HEVC encode test:

```sh
./VirtualDisplayHEVCEncodeProbe
```

Expected result: the probe creates a virtual 5K display, streams live frames,
submits 5120x2880 IOSurface-backed buffers into VideoToolbox HEVC, and writes a
Markdown/CSV report to
`results/004-videotoolbox-hevc-encode/hevc-encode-result.md`.

Run the receiver codec capability test:

```sh
cd 005-receiver-codec-capability
./run_receiver_codec_capability.sh
```

Expected result: the probe writes VideoToolbox hardware decode capability and
encoder availability to
`results/005-receiver-codec-capability/receiver-codec-capability.md`.

Run the H.264 receiver decode/render baseline:

```sh
cd 006-receiver-decode-render
./run_h264_decode_render_probe.sh
```

Expected result: the probe opens a render window, requires a hardware
VideoToolbox H.264 decoder for the checked-in 5120x2880/60 fps test stream,
renders decoded frames through Metal/Core Image, and writes a report to
`results/006-receiver-decode-render/h264-decode-render-result.md`.

Run the HEVC receiver decode/render baseline:

```sh
cd 007-receiver-hevc-decode-render
./run_hevc_decode_render_probe.sh
```

Expected result: the probe opens a render window, requires a hardware
VideoToolbox HEVC/H.265 decoder for the checked-in 5120x2880/60 fps test stream,
renders decoded frames through Metal/Core Image, and writes a report to
`results/007-receiver-hevc-decode-render/hevc-decode-render-result.md`.

Run the receiver decode envelope ladder:

```sh
cd 008-receiver-decode-envelope
./run_decode_envelope_probe.sh
```

Expected result: the probe runs several HEVC/H.265 and H.264 fixtures at lower
resolutions and/or frame rates, requires a hardware VideoToolbox decoder for
each, renders decoded frames through Metal/Core Image, and writes reports plus a
summary to `results/008-receiver-decode-envelope/`.

Run the receiver candidate stress test:

```sh
cd 009-receiver-candidate-stress
./run_candidate_stress_probe.sh
```

Expected result: the probe runs the two first viable receiver candidates for a
longer duration: H.264 3840x2160 at 60 fps and HEVC/H.265 3200x1800 at 60 fps.
It requires a hardware VideoToolbox decoder, renders through Metal/Core Image,
and writes reports plus a summary to `results/009-receiver-candidate-stress/`.
By default each candidate runs fullscreen for 120 seconds. For a quick smoke
run, set `MACRKVM_STRESS_SECONDS=15 MACRKVM_FULLSCREEN=no`.

Notes:

- This is not App Store-safe; it intentionally exercises private API.
- It should be used only as a local proof spike.
- If a previous probe is still running, new display creation can fail.
- Do not build product architecture around this file; replace it with a cleaner
  app-owned implementation after the capability is proven.
