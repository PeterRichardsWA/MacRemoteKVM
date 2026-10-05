# Experiment 012 Local Smoke Summary

Run mode: local loopback on the M1 Max development Mac

Duration: 2 seconds per stream

## H.264 3840x2160 at 60 fps live capture

- Sender frames sent: 101
- Sender frame rate: 47.98 FPS
- Complete input frames: 101
- Observed complete-input FPS: 50.21
- Encode call errors: 0
- Output errors: 0
- Output dropped frames: 0
- Receiver frames received: 101
- Receiver frames rendered: 101
- Receiver throughput: 52.49 rendered FPS
- Decode errors: 0
- Render failures: 0
- Average receive-complete-to-render latency: 9.553 ms

## HEVC 3200x1800 at 60 fps live capture

- Sender frames sent: 113
- Sender frame rate: 55.88 FPS
- Complete input frames: 113
- Observed complete-input FPS: 56.27
- Encode call errors: 0
- Output errors: 0
- Output dropped frames: 0
- Receiver frames received: 113
- Receiver frames rendered: 113
- Receiver throughput: 57.64 rendered FPS
- Decode errors: 0
- Render failures: 0
- Average receive-complete-to-render latency: 4.099 ms

## Interpretation

The local smoke run passed as an integration check: software virtual display,
ScreenCaptureKit capture, VideoToolbox live encode, TCP framing, hardware
decode, and Metal render all worked end to end for both candidate streams. It
did not prove full 60 fps performance; the short local run delivered about
48 FPS for H.264 and 56 FPS for HEVC from the live sender.
