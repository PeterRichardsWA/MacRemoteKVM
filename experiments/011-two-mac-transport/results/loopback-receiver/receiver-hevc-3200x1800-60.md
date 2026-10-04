# Experiment 011 Receiver Result: Case 2

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
- Serialized parameter sets: 4
- Serialized parameter-set bytes: 2393

## Decoder Setup

- Required hardware decoder: yes
- Hardware-required session create status: 0 (noErr)
- Session note: created with required hardware decoder

## Render Target

- Renderer: Metal CAMetalLayer with Core Image CVPixelBuffer render
- Window backing scale: 2.00
- Drawable size: 2560 x 1440

## Receiver Result

- Frames received: 121
- Bytes received: 3558051
- Measured receiver bitrate: 14.21 Mbps
- Submitted frames: 121
- Decode call errors: 0
- Decode output callbacks: 121
- Decode output errors: 0
- VideoToolbox dropped-frame flags: 0
- Rendered frames: 121
- Render failures: 0
- First decoded frame: 3200 x 1800 `420v`
- Receiver wall time: 2.003 seconds
- Throughput: 60.42 rendered FPS
- Realtime multiple vs 60.00 FPS input: 1.01x
- Average synchronous render time: 1.899 ms
- First output callback wall time: 0.004 seconds
- Last output callback wall time: 2.002 seconds

## Receiver Latency Proxy

Sender and receiver clocks are not synchronized in the two-Mac case, so this report does not claim one-way sender-to-render latency. It reports receiver-side payload-complete to rendered-frame latency and frame interarrival timing.

- Average receive-complete-to-render latency: 3.786 ms
- Min receive-complete-to-render latency: 2.424 ms
- Max receive-complete-to-render latency: 10.095 ms
- Average frame interarrival: 16.662 ms
- Min frame interarrival: 7.178 ms
- Max frame interarrival: 25.173 ms

## Interpretation

The network receiver path stayed inside the current pass band for this stream.
