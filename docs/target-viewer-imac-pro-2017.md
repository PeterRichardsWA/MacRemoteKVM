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
