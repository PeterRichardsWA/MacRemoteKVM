# Experiment 012 Live Sender Result: HEVC 3200x1800 at 60 fps live capture

## Machine

- Host name: peters-macbook-pro.local
- macOS: Version 26.6.2 (Build 25G83)
- Hardware model: MacBookPro18,2
- CPU brand: Apple M1 Max

## Sender Settings

- Destination: 192.168.0.91:49320
- Requested duration: 30.0 seconds
- Source: software 5K virtual display captured through ScreenCaptureKit
- Virtual display id: 24
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

- Stream callbacks: 1723
- Complete input frames: 1721
- Submitted to encoder: 1721
- First input frame: 3200 x 1800
- Last input frame: 3200 x 1800
- Observed complete-input FPS: 57.32
- Saw IOSurface-backed input buffers: yes
- All input dimensions matched expected: yes
- Stream error: none

## Encode/Send Result

- Success: yes
- Encode call errors: 0
- Encode call dropped flags: 0
- Encoder output callbacks: 1721
- Encoded frames sent: 1721
- Output errors: 0
- Output dropped frames: 0
- Key frames: 29
- Frames sent: 1721
- Bytes sent: 55256946
- Sender wall time: 30.015 seconds
- Sender frame rate: 57.34 FPS
- Observed encoded FPS: 57.38
- Realtime multiple vs 60 FPS target: 0.96x
- Measured sender bitrate: 14.73 Mbps

## Interpretation

The live ScreenCaptureKit -> VideoToolbox -> TCP sender path stayed inside the current pass band for this stream.
