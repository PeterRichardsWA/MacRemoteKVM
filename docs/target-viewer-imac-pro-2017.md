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
