# Experiment 017 Receiver Result: Case 1

## Machine

- Host name: peters-macbook-pro.local
- macOS: Version 26.6.2 (Build 25G83)
- Hardware model: MacBookPro18,2
- CPU brand: Apple M1 Max

## Stream Config

- Codec FourCC: `unavailable`
- Format dimensions: 0 x 0
- Nominal FPS: 60.00
- NAL unit header length: 0
- Serialized parameter sets: 0
- Serialized parameter-set bytes: 0

## Decoder Setup

- Required hardware decoder: yes
- Hardware-required session create status: -2147483648 (unknown)
- Session note: unavailable
- Failure: could not read stream header

## Network Preflight

- Preflight handshake: passed before stream config and receiver timing
- Preflight handling time: 0.017 ms

## Render Target

- Renderer: Metal CAMetalLayer with Core Image CVPixelBuffer render
- Window backing scale: 2.00
- Drawable size: 2560 x 1440

## Receiver Result

- Frames received: 0
- Bytes received: 0
- Measured receiver bitrate: 0.00 Mbps
- Submitted frames: 0
- Decode call errors: 0
- Decode output callbacks: 0
- Decode output errors: 0
- VideoToolbox dropped-frame flags: 0
- Rendered frames: 0
- Render failures: 0
- First decoded frame: 0 x 0 `unavailable`
- Receiver wall time: 0.000 seconds
- Throughput: 0.00 rendered FPS
- Realtime multiple vs 60.00 FPS input: 0.00x
- Average synchronous render time: 0.000 ms
- First output callback wall time: 0.000 seconds
- Last output callback wall time: 0.000 seconds

## Receiver Latency Proxy

Sender and receiver clocks are not synchronized in the two-Mac case, so this report does not claim one-way sender-to-render latency. It reports receiver-side payload-complete to rendered-frame latency and frame interarrival timing.

- Average receive-complete-to-render latency: 0.000 ms
- Min receive-complete-to-render latency: 0.000 ms
- Max receive-complete-to-render latency: 0.000 ms
- Average frame interarrival: 0.000 ms
- Min frame interarrival: 0.000 ms
- Max frame interarrival: 0.000 ms

## Interpretation

The network receiver path did not complete cleanly for this stream.
