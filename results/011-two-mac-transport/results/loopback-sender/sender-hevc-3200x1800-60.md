# Experiment 011 Sender Result: HEVC 3200x1800 at 60 fps

## Machine

- Host name: peters-macbook-pro.local
- macOS: Version 26.6.2 (Build 25G83)
- Hardware model: MacBookPro18,2
- CPU brand: Apple M1 Max

## Sender Settings

- Destination: 127.0.0.1:49321
- Requested duration: 2.0 seconds
- Realtime pacing: yes
- Transport: TCP over configured network path
- Header encoding: big-endian network headers
- Decoder config: serialized H.264/HEVC parameter sets

## Input Stream

- Path: `/Users/peterrichards/dev/MacRemoteKVM/experiments/011-two-mac-transport/media/hevc-3200x1800-60-main-3s.mp4`
- Codec FourCC: `hvc1`
- Format dimensions: 3200 x 1800
- Nominal FPS: 60.00
- Estimated source bitrate: 14.09 Mbps

## Sender Result

- Success: yes
- Frames sent: 121
- Bytes sent: 3558051
- Source loops completed: 0
- Sender wall time: 2.006 seconds
- Sender frame rate: 60.33 FPS
- Realtime multiple vs 60.00 FPS input: 1.01x
- Measured sender bitrate: 14.19 Mbps
