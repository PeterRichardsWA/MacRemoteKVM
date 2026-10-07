# Experiment 017 Receiver Result: Case 1

## Machine

- Host name: peters-macbook-pro.local
- macOS: Version 26.6.2 (Build 25G83)
- Hardware model: MacBookPro18,2
- CPU brand: Apple M1 Max

## Stream Config

- Codec FourCC: `hvc1`
- Format dimensions: 3200 x 1800
- Nominal FPS: 60.00
- NAL unit header length: 4
- Serialized parameter sets: 3
- Serialized parameter-set bytes: 87

## Decoder Setup

- Required hardware decoder: yes
- Hardware-required session create status: 0 (noErr)
- Session note: created with required hardware decoder

## Network Preflight

- Preflight handshake: passed before stream config and receiver timing
- Preflight handling time: 0.041 ms

## Render Target

- Renderer: Metal CAMetalLayer with Core Image CVPixelBuffer render
- Window backing scale: 2.00
- Drawable size: 2560 x 1440

## Receiver Result

- Frames received: 587
- Bytes received: 19135958
- Measured receiver bitrate: 15.47 Mbps
- Submitted frames: 587
- Decode call errors: 0
- Decode output callbacks: 587
- Decode output errors: 0
- VideoToolbox dropped-frame flags: 0
- Rendered frames: 587
- Render failures: 0
- First decoded frame: 3200 x 1800 `420v`
- Receiver wall time: 9.895 seconds
- Throughput: 59.32 rendered FPS
- Realtime multiple vs 60.00 FPS input: 0.99x
- Average synchronous render time: 1.618 ms
- First output callback wall time: 0.009 seconds
- Last output callback wall time: 9.856 seconds

## Receiver Latency Proxy

Sender and receiver clocks are not synchronized in the two-Mac case, so this report does not claim one-way sender-to-render latency. It reports receiver-side payload-complete to rendered-frame latency and frame interarrival timing.

- Average receive-complete-to-render latency: 3.992 ms
- Min receive-complete-to-render latency: 2.320 ms
- Max receive-complete-to-render latency: 59.817 ms
- Average frame interarrival: 16.815 ms
- Min frame interarrival: 2.788 ms
- Max frame interarrival: 61.860 ms

## Interpretation

The network receiver path stayed inside the current pass band for this stream.
