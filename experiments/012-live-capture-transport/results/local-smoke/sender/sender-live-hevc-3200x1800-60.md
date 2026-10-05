# Experiment 012 Live Sender Result: HEVC 3200x1800 at 60 fps live capture

## Machine

- Host name: peters-macbook-pro.local
- macOS: Version 26.6.2 (Build 25G83)
- Hardware model: MacBookPro18,2
- CPU brand: Apple M1 Max

## Sender Settings

- Destination: 127.0.0.1:49320
- Requested duration: 2.0 seconds
- Source: software 5K virtual display captured through ScreenCaptureKit
- Virtual display id: 17
- Virtual display backing size: 5120 x 2880
- Capture/encode dimensions: 3200 x 1800
- Capture FPS target: 60
- Codec FourCC: `hvc1`
- Codec name: HEVC/H.265
- Target bitrate: 20 Mbps
- Encoder setup: low-latency create status: 0; prepare status: 0
- Transport: TCP over configured network path
- Header encoding: big-endian network headers
- Decoder config: serialized H.264/HEVC parameter sets from live encoder output

## Capture Result

- Stream callbacks: 113
- Complete input frames: 113
- Submitted to encoder: 113
- First input frame: 3200 x 1800
- Last input frame: 3200 x 1800
- Observed complete-input FPS: 56.27
- Saw IOSurface-backed input buffers: yes
- All input dimensions matched expected: yes
- Stream error: none

## Encode/Send Result

- Success: yes
- Encode call errors: 0
- Encode call dropped flags: 0
- Encoder output callbacks: 113
- Encoded frames sent: 113
- Output errors: 0
- Output dropped frames: 0
- Key frames: 2
- Frames sent: 113
- Bytes sent: 3579944
- Sender wall time: 2.022 seconds
- Sender frame rate: 55.88 FPS
- Observed encoded FPS: 57.63
- Realtime multiple vs 60 FPS target: 0.93x
- Measured sender bitrate: 14.16 Mbps

## Interpretation

The live sender path completed but did not hold the target frame rate. Inspect capture and encoder pacing before productizing this stream shape.
