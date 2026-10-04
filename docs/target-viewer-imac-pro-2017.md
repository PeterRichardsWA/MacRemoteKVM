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
