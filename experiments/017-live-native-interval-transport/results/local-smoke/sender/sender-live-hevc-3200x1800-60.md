# Experiment 017 Live Sender Result: HEVC 3200x1800 native-interval live capture (60 Hz display)

## Machine

- Host name: peters-macbook-pro.local
- macOS: Version 26.6.2 (Build 25G83)
- Hardware model: MacBookPro18,2
- CPU brand: Apple M1 Max

## Sender Settings

- Destination: 127.0.0.1:49325
- Requested duration: 10.0 seconds
- Source: software 5K virtual display captured through ScreenCaptureKit
- Virtual display id: 58
- Virtual display backing size: 5120 x 2880
- Capture/encode dimensions: 3200 x 1800
- Virtual display refresh: 60 Hz
- Minimum frame interval: native display refresh (kCMTimeZero)
- Capture resolution: Best
- Capture pixel format: BGRA
- Queue depth: 8
- Codec FourCC: `hvc1`
- Codec name: HEVC/H.265
- Target bitrate: 24 Mbps
- Encoder setup: low-latency create status: 0; prepare status: 0
- Network preflight: passed before capture/timed sender window
- Network preflight round trip: 0.175 ms
- Transport: TCP over configured network path
- Header encoding: big-endian network headers
- Decoder config: serialized H.264/HEVC parameter sets from live encoder output

## Capture Result

- Stream callbacks: 595
- Complete input frames: 587
- Submitted to encoder: 587
- First input frame: 3200 x 1800
- Last input frame: 3200 x 1800
- Observed complete-input FPS: 58.38
- Saw IOSurface-backed input buffers: yes
- All input dimensions matched expected: yes
- Stream error: none

## Encode/Send Result

- Success: yes
- Encode call errors: 0
- Encode call dropped flags: 0
- Encoder output callbacks: 587
- Encoded frames sent: 587
- Output errors: 0
- Output dropped frames: 0
- Key frames: 10
- Frames sent: 587
- Bytes sent: 19135958
- Sender wall time: 10.151 seconds
- Sender timing boundary: after network preflight, before startCapture, through encoder drain
- Sender frame rate: 57.83 FPS
- Observed encoded FPS: 58.99
- Realtime multiple vs 60 FPS target: 0.96x
- Measured sender bitrate: 15.08 Mbps

## Interpretation

The existing pass band is 95% of 60 Hz (57 FPS); it does not demonstrate sustained 60 FPS. Compare measured capture, send, and render rates and frame counts.

The live ScreenCaptureKit -> VideoToolbox -> TCP sender path stayed inside the current pass band for this stream.
