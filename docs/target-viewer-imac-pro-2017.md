# Target Viewer Machine

Date recorded: 2026-10-04

This is the intended older Mac receiver/viewer for decode and render testing.

## Hardware

- Model: iMac Pro 2017
- CPU: 2.3 GHz 18-core Intel Xeon W
- GPU: Radeon Pro Vega 64, 16 GB
- Memory: 128 GB 2666 MHz DDR4
- OS: macOS Sequoia 15.8

## Product Implication

This machine is expected to be the Viewer/Receiver, not the Host/Sender. The
Host can be a faster modern Mac; this iMac Pro's decode and render capability is
therefore a central product constraint.

Receiver tests should prioritize:

1. Hardware decode support for H.264, HEVC/H.265, ProRes, JPEG, and AV1.
2. Actual 5K decode/render throughput.
3. End-to-end latency once frames are received.
4. Sustained thermals and CPU/GPU/media-engine load.

## Experiment 005 Observed Capability

The receiver codec capability probe was run on this machine.

Hardware decode support reported by VideoToolbox:

- H.264 / AVC: yes.
- HEVC / H.265: yes.
- HEVC with Alpha: yes.
- Apple ProRes 422 Proxy/LT/422/HQ: no.
- JPEG: no.
- AV1: no.

The next receiver test should measure actual 5K decode/render throughput for
H.264 and HEVC/H.265. ProRes, JPEG/MJPEG, AV1, and custom codecs remain fallback
paths, not the first path.

## Experiment 006 H.264 Result

The H.264 receiver decode/render probe was run on this machine with a
5120x2880/60 fps H.264 High Profile test stream.

VideoToolbox could not create a required-hardware H.264 decoder session:

```text
Hardware-required session create status: -12913 (kVTVideoDecoderNotAvailableNowErr)
Fallback session create status without hardware requirement: 0 (noErr)
```

This rules out 5K H.264 as the first hardware-decode transport path. The next
receiver test should use HEVC/H.265.

## Experiment 007 HEVC Result

The HEVC receiver decode/render probe was run on this machine with a
5120x2880/60 fps HEVC Main Profile test stream.

VideoToolbox could not create a required-hardware HEVC decoder session:

```text
Hardware-required session create status: -12907 (kVTCouldNotCreateInstanceErr)
Fallback session create status without hardware requirement: 0 (noErr)
```

This rules out 5K60 HEVC as the first hardware-decode transport path. The next
receiver test should map the lower-resolution and lower-frame-rate hardware
decode envelope.

## Experiment 008 Decode Envelope Result

The receiver decode envelope ladder was run on this machine.

Summary:

- H.264 2560x1440 at 60 fps: hardware session yes, 59.68 rendered FPS.
- H.264 3840x2160 at 60 fps: hardware session yes, 59.38 rendered FPS.
- HEVC 2560x1440 at 60 fps: hardware session yes, 59.72 rendered FPS.
- HEVC 3200x1800 at 60 fps: hardware session yes, 58.71 rendered FPS.
- HEVC 3840x2160 at 60 fps: hardware session yes, 42.67 rendered FPS.
- HEVC 4096x2304 at 60 fps: hardware session yes, 37.54 rendered FPS.
- HEVC 5120x2880 at 30 fps: hardware session no,
  `kVTCouldNotCreateInstanceErr`.

The first viable receiver prototype path should use H.264 3840x2160 at 60 fps
scaled to the 5K display, or HEVC 3200x1800 at 60 fps if lower bandwidth matters
more than spatial detail.

## Experiment 009 Receiver Stress Result

The receiver candidate stress test was run on this machine in fullscreen mode
with a 5120x2880 drawable for 120 seconds per candidate.

Summary:

- H.264 3840x2160 at 60 fps: hardware session yes, 7196 rendered frames,
  59.95 rendered FPS, zero decode errors, zero render failures.
- HEVC 3200x1800 at 60 fps: hardware session yes, 7196 rendered frames,
  59.94 rendered FPS, zero decode errors, zero render failures.
- VideoToolbox dropped-frame flags: zero for both candidates.
- Thermal state: nominal to nominal for both candidates.
- Process CPU realtime multiple: 0.08x for both candidates.
- Average synchronous render cost: about 16.32 ms for both candidates.

Both first receiver candidates are viable for the first transport prototype.
H.264 3840x2160 at 60 fps is the detail-first path. HEVC 3200x1800 at 60 fps is
the lower-bandwidth comparison path.

## Experiment 010 Loopback Transport Result

The loopback transport prototype was run on this machine in fullscreen mode with
a 5120x2880 drawable for 30 seconds per candidate.

Summary:

- H.264 3840x2160 at 60 fps: hardware session yes, 1801 frames sent,
  1801 frames rendered, 59.93 rendered FPS, zero decode errors, zero render
  failures.
- HEVC 3200x1800 at 60 fps: hardware session yes, 1801 frames sent,
  1801 frames rendered, 59.89 rendered FPS, zero decode errors, zero render
  failures.
- Average sender-to-receiver payload latency: 2.353 ms for H.264, 2.510 ms for
  HEVC.
- Average sender-to-rendered-frame latency: 49.309 ms for H.264, 51.182 ms for
  HEVC.
- Measured transport bitrate: 20.74 Mbps for H.264, 14.13 Mbps for HEVC.

Both first receiver candidates survived the same-machine TCP loopback transport
path. The next receiver-relevant gate is a real two-Mac transport run with
serialized decoder configuration and network behavior.

## Experiment 011 Wi-Fi 6E Two-Mac Transport Result

The two-Mac transport probe was run with an M1 Max MacBook Pro sender and this
iMac Pro as the receiver over Wi-Fi 6E.

Summary:

- H.264 3840x2160 at 60 fps: hardware session yes, 1190 frames received,
  1190 frames rendered, 59.92 rendered FPS while frames were arriving, zero
  decode errors, zero render failures. Sender-side pacing was only 39.65 FPS
  over the 30-second run.
- HEVC 3200x1800 at 60 fps: hardware session yes, 1801 frames sent,
  1801 frames received, 1801 frames rendered, 59.99 rendered FPS, zero decode
  errors, zero render failures.
- Average receive-complete-to-render latency: 49.971 ms for H.264, 34.757 ms
  for HEVC.
- Measured receiver bitrate: 20.66 Mbps for H.264, 14.12 Mbps for HEVC.

HEVC 3200x1800@60 passed across the Wi-Fi 6E two-Mac path. H.264
3840x2160@60 did not pass as an end-to-end Wi-Fi 6E sender path because the
sender only delivered 1190 frames in 30 seconds, but the iMac Pro receiver
decoded and rendered every frame it received. This result motivated wired
transport comparison before changing codec candidates.

## Experiment 011 Wired Ethernet Two-Mac Transport Result

The same two-Mac transport probe was run over wired Ethernet with this iMac Pro
as the receiver.

Summary:

- H.264 3840x2160 at 60 fps: hardware session yes, 1801 frames sent,
  1801 frames received, 1801 frames rendered, 59.89 rendered FPS, zero decode
  errors, zero render failures.
- HEVC 3200x1800 at 60 fps: hardware session yes, 1801 frames sent,
  1801 frames received, 1801 frames rendered, 60.00 rendered FPS, zero decode
  errors, zero render failures.
- Average receive-complete-to-render latency: 49.985 ms for H.264, 33.745 ms
  for HEVC.
- Measured receiver bitrate: 20.69 Mbps for H.264, 14.13 Mbps for HEVC.

Both first transport candidates passed across wired Ethernet. This confirms the
Wi-Fi 6E H.264 shortfall was transport-related rather than a receiver
decode/render limit. The next comparison is Thunderbolt networking.

## Experiment 012 Wired Ethernet Live Capture Result

The live capture/encode transport probe was run over wired Ethernet with this
iMac Pro as the receiver.

Summary:

- H.264 3840x2160 at 60 fps live capture: hardware session yes, 1409 frames
  sent, 1409 frames received, 1409 frames rendered, 47.08 rendered FPS, zero
  decode errors, zero render failures. Sender-side live capture/encode pacing
  was 46.81 FPS.
- HEVC 3200x1800 at 60 fps live capture: hardware session yes, 1721 frames sent,
  1721 frames received, 1721 frames rendered, 57.42 rendered FPS, zero decode
  errors, zero render failures.
- Average receive-complete-to-render latency: 12.405 ms for H.264, 19.194 ms
  for HEVC.
- Measured receiver bitrate: 20.80 Mbps for H.264, 14.75 Mbps for HEVC.
- Render drawable observed during the run: 5760x3240.

HEVC 3200x1800@60 is the first live sender-to-receiver candidate to pass the
current threshold. H.264 3840x2160@60 remains a sender live capture/encode
pacing problem, not an iMac Pro decode/render failure.
