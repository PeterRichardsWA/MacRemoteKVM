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
./test.sh
```

Expected result: the probe runs the two first viable receiver candidates for a
longer duration: H.264 3840x2160 at 60 fps and HEVC/H.265 3200x1800 at 60 fps.
It requires a hardware VideoToolbox decoder, renders through Metal/Core Image,
and writes reports plus a summary to `results/009-receiver-candidate-stress/`.
By default each candidate runs fullscreen for 120 seconds. For a quick smoke
run, set `MACRKVM_STRESS_SECONDS=15 MACRKVM_FULLSCREEN=no`.

Run the loopback transport prototype:

```sh
cd 010-loopback-transport-prototype
./test.sh
```

Expected result: the probe sends the H.264 3840x2160@60 and HEVC/H.265
3200x1800@60 compressed frame payloads through a local TCP loopback transport,
then rebuilds compressed sample buffers, requires a hardware VideoToolbox
decoder, renders through Metal/Core Image, and writes reports plus a summary to
`010-loopback-transport-prototype/results/`. By default each candidate runs
fullscreen for 30 seconds. For a quick smoke run, set
`MACRKVM_TRANSPORT_SECONDS=5 MACRKVM_FULLSCREEN=no`.

Run the two-Mac transport test:

```sh
cd 011-two-mac-transport
./test.sh receiver
```

Then, on the sender Mac:

```sh
cd 011-two-mac-transport
./test.sh sender <receiver-host-or-ip>
```

Expected result: the sender sends the H.264 3840x2160@60 and HEVC/H.265
3200x1800@60 compressed frame payloads over TCP to the receiver. The protocol
uses big-endian network headers and serialized H.264/HEVC parameter sets, so the
receiver rebuilds the decoder configuration instead of sharing it in-process.
Results are written under `011-two-mac-transport/results/`.

The first real two-Mac run was over Wi-Fi 6E. HEVC 3200x1800@60 passed for the
full 30-second run. H.264 3840x2160@60 decoded and rendered all received frames,
but the sender only delivered 1190 frames in 30 seconds. The wired Ethernet run
passed both candidates for the full 30-second run. Rerun this same test over
Thunderbolt networking before changing the codec candidates. Use the receiver IP
address for the active Thunderbolt interface when starting the sender.

Use a result label to keep each transport run separate:

```sh
./test.sh receiver wired-ethernet
./test.sh sender <receiver-wired-ip> wired-ethernet

./test.sh receiver thunderbolt
./test.sh sender <receiver-thunderbolt-ip> thunderbolt
```

Labeled runs write results under `011-two-mac-transport/results/<label>/`.

Run the live capture/encode transport test:

```sh
cd 012-live-capture-transport
./test.sh receiver wired-ethernet-live
```

Then, on the sender Mac:

```sh
cd 012-live-capture-transport
./test.sh sender <receiver-host-or-ip> wired-ethernet-live
```

Expected result: the sender creates a 5120x2880 software virtual display,
captures it live with ScreenCaptureKit, encodes H.264 3840x2160@60 and
HEVC/H.265 3200x1800@60 with VideoToolbox, and streams those live compressed
frames to the existing receiver path. Results are written under
`012-live-capture-transport/results/<label>/`.

The first 30-second wired Ethernet live run passed the HEVC path: HEVC
3200x1800@60 sent, received, and rendered 1721 frames at about 57.4 rendered
FPS with zero decode/render errors. H.264 3840x2160@60 completed cleanly but
only delivered about 47 FPS from the sender; the receiver rendered every frame it
received.

Run the H.264 live shape tuning test:

```sh
cd 013-live-h264-shape-tuning
./test.sh receiver wired-ethernet-h264-3200
```

Then, on the sender Mac:

```sh
cd 013-live-h264-shape-tuning
./test.sh sender <receiver-host-or-ip> wired-ethernet-h264-3200
```

Expected result: the sender creates a 5120x2880 software virtual display,
captures it live at 3200x1800, encodes H.264 3200x1800@60 with VideoToolbox, and
streams that lower H.264 shape to the existing receiver path. Results are
written under `013-live-h264-shape-tuning/results/<label>/`.

The Experiment 013 harness now runs a TCP preflight handshake before live capture
and before the timed sender window. If Little Snitch prompts for network
permission, approve it during that preflight; the reported sender FPS starts only
after the receiver has acknowledged the preflight packet.

The first wired Ethernet run sent and rendered all 1700 frames with zero
decode/render errors, but held only about 56.6 sender FPS / 57.0 receiver FPS.
This confirms the iMac Pro can decode/render the received H.264 3200x1800 stream
cleanly, while the sender-side live capture/encode pacing still misses a strict
60 Hz target.

Run the sender pacing split:

```sh
cd 014-sender-pacing-split
./test.sh
```

Expected result: the probe runs a sender-only ladder with no receiver and no
network connection. The capture-only ladder measures ScreenCaptureKit pacing from
a software 5K virtual display at 3200x1800, 3840x2160, and 5120x2880. The
encode-only ladder measures VideoToolbox H.264/HEVC pacing from preallocated
IOSurface-backed synthetic buffers. Results are written under
`014-sender-pacing-split/results/<label>/`.

The 30-second `sender-pacing-30s` run found:

- Capture-only 3200x1800@60: 55.66 FPS.
- Capture-only 3840x2160@60: 57.23 FPS.
- Capture-only 5120x2880@60: 57.56 FPS.
- Encode-only H.264 3200x1800@60: 59.99 FPS.
- Encode-only H.264 3840x2160@60: 48.67 FPS.
- Encode-only HEVC 3200x1800@60: 59.99 FPS.

Interpretation: the current live 3200x1800 sender ceiling is capture pacing, not
VideoToolbox encode. H.264 3840x2160@60 is also encode-limited and should not be
the first live stream candidate.

Run the Thunderbolt/raw TCP throughput test:

```sh
cd 015-thunderbolt-throughput
./test.sh receiver thunderbolt-throughput
```

Then, on the sender Mac:

```sh
cd 015-thunderbolt-throughput
./test.sh sender <receiver-thunderbolt-ip> thunderbolt-throughput
```

Expected result: the probe measures single-stream TCP throughput over the active
network path with 64 KiB, 256 KiB, and 1 MiB payload blocks. Each case performs a
network preflight write/ack before the timed payload window so Little Snitch or
macOS network permission prompts are excluded from throughput numbers. Results
are written under `015-thunderbolt-throughput/results/<label>/`.

Notes:

- This is not App Store-safe; it intentionally exercises private API.
- It should be used only as a local proof spike.
- If a previous probe is still running, new display creation can fail.
- Do not build product architecture around this file; replace it with a cleaner
  app-owned implementation after the capability is proven.
