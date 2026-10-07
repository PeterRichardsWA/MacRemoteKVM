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
- Preflight handling time: 0.014 ms

## Render Target

- Renderer: Metal CAMetalLayer with Core Image CVPixelBuffer render
- Window backing scale: 2.00
- Drawable size: 2560 x 1440

## Receiver Result

- Frames received: 303
- Bytes received: 10331054
- Measured receiver bitrate: 17.24 Mbps
- Submitted frames: 303
- Decode call errors: 0
- Decode output callbacks: 303
- Decode output errors: 0
- VideoToolbox dropped-frame flags: 0
- Rendered frames: 303
- Render failures: 0
- First decoded frame: 3200 x 1800 `420v`
- Receiver wall time: 4.795 seconds
- Throughput: 63.19 rendered FPS
- Realtime multiple vs 60.00 FPS input: 1.05x
- Average synchronous render time: 1.851 ms
- First output callback wall time: 0.009 seconds
- Last output callback wall time: 4.774 seconds

## Receiver Latency Proxy

Sender and receiver clocks are not synchronized in the two-Mac case, so this report does not claim one-way sender-to-render latency. It reports receiver-side payload-complete to rendered-frame latency and frame interarrival timing.

- Average receive-complete-to-render latency: 4.390 ms
- Min receive-complete-to-render latency: 2.249 ms
- Max receive-complete-to-render latency: 44.100 ms
- Average frame interarrival: 15.801 ms
- Min frame interarrival: 1.362 ms
- Max frame interarrival: 22.691 ms

## Interpretation

The network receiver path stayed inside the current pass band for this stream.
