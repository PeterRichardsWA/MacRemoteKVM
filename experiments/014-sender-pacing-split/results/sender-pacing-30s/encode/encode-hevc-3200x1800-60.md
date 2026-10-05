# Experiment 014 Encode-Only Result: HEVC 3200x1800 at 60 fps encode-only

## Machine

- Host name: peters-macbook-pro.local
- macOS: Version 26.6.2 (Build 25G83)
- Hardware model: MacBookPro18,2
- CPU brand: Apple M1 Max

## Encode Settings

- Requested duration: 30.0 seconds
- Source: preallocated IOSurface-backed BGRA synthetic pixel buffers
- Synthetic buffer ring size: 4
- Codec FourCC: `hvc1`
- Codec name: HEVC/H.265
- Encode dimensions: 3200 x 1800
- FPS target: 60
- Target bitrate: 24 Mbps
- Encoder setup: low-latency create status: 0; prepare status: 0
- Capture/network work: none
- Submission pacing: real-time 60 Hz sleepUntil schedule

## Encode Result

- Success: yes
- Submitted frames: 1800
- Encode call errors: 0
- Encode call dropped flags: 0
- Encoder output callbacks: 1800
- Output errors: 0
- Output dropped frames: 0
- Key frames: 30
- Encoded bytes: 10398847
- Submission wall time: 30.000 seconds
- Drain wall time: 0.003 seconds
- Total wall time: 30.003 seconds
- Submitted FPS: 60.00
- Output FPS by total wall: 59.99
- Output FPS by first/last callback: 60.07
- Measured encoded bitrate: 2.77 Mbps
- First output callback wall time: 0.053 seconds
- Last output callback wall time: 30.002 seconds

## Interpretation

VideoToolbox encode-only pacing stayed inside the current 95% pass band for this synthetic stream.
