# Experiment 010 Result: HEVC 3200x1800 at 60 fps Loopback Transport

## Machine

- Host name: peters-macbook-pro.local
- macOS: Version 26.6.2 (Build 25G83)
- Hardware model: MacBookPro18,2
- CPU brand: Apple M1 Max
- Processor count: 10
- Physical memory: 64.00 GB

## Transport Settings

- Transport: local TCP loopback, one sender thread, one receiver thread
- Payload format: compressed sample payload per frame
- Decoder config: shared in process from local asset format description
- Header encoding: native-endian prototype frame header
- Requested duration: 2.0 seconds
- Realtime pacing: yes
- In-flight decode limit: 3
- Loopback listener port: 51536

## Input Stream

- Path: `/Users/peterrichards/dev/MacRemoteKVM/experiments/010-loopback-transport-prototype/media/hevc-3200x1800-60-main-3s.mp4`
- File size: 5.04 MB
- Codec FourCC: `hvc1`
- Format dimensions: 3200 x 1800
- Duration: 3.000 seconds
- Nominal FPS: 60.00
- Estimated source bitrate: 14.09 Mbps
- Compressed sample buffers read: 184
- Empty sample buffers skipped: 4
- Transportable frame payloads: 180

## Decoder Setup

- Required hardware decoder: yes
- Hardware-required session create status: 0 (noErr)
- Session note: created with required hardware decoder

## Render Target

- Renderer: Metal CAMetalLayer with Core Image CVPixelBuffer render
- Window backing scale: 2.00
- Drawable size: 2560 x 1440

## Transport Result

- Sender frames sent: 121
- Sender bytes sent: 3558051
- Source loops completed: 0
- Sender wall time: 2.004 seconds
- Measured transport bitrate: 14.21 Mbps
- Receiver frames received: 121
- Receiver bytes received: 3558051

## Decode/Render Result

- Submitted frames: 121
- Decode call errors: 0
- Decode output callbacks: 121
- Decode output errors: 0
- VideoToolbox dropped-frame flags: 0
- Rendered frames: 121
- Render failures: 0
- First decoded frame: 3200 x 1800 `420v`
- Receiver wall time: 2.007 seconds
- Throughput: 60.28 rendered FPS
- Realtime multiple vs 60.00 FPS input: 1.00x
- Average synchronous render time: 1.261 ms
- First output callback wall time: 0.004 seconds
- Last output callback wall time: 2.006 seconds

## Latency Proxy

This is a local loopback transport result. It measures sender write time to receiver payload completion and sender write time to rendered frame on the same Mac. It does not yet include real network jitter, sender capture, live encode, cross-machine clock sync, or input/cursor round trip.

- Average sender-to-receiver payload latency: 0.194 ms
- Min sender-to-receiver payload latency: 0.099 ms
- Max sender-to-receiver payload latency: 2.032 ms
- Average sender-to-rendered-frame latency: 3.493 ms
- Min sender-to-rendered-frame latency: 2.459 ms
- Max sender-to-rendered-frame latency: 20.174 ms

## Interpretation

The local loopback transport path stayed inside the current pass band for HEVC/H.265. This candidate is ready for a two-Mac transport test.
