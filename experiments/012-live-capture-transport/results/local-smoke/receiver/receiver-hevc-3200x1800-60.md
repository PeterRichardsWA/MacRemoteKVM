# Experiment 012 Receiver Result: Case 2

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

## Render Target

- Renderer: Metal CAMetalLayer with Core Image CVPixelBuffer render
- Window backing scale: 2.00
- Drawable size: 2560 x 1440

## Receiver Result

- Frames received: 113
- Bytes received: 3579944
- Measured receiver bitrate: 14.61 Mbps
- Submitted frames: 113
- Decode call errors: 0
- Decode output callbacks: 113
- Decode output errors: 0
- VideoToolbox dropped-frame flags: 0
- Rendered frames: 113
- Render failures: 0
- First decoded frame: 3200 x 1800 `420v`
- Receiver wall time: 1.960 seconds
- Throughput: 57.64 rendered FPS
- Realtime multiple vs 60.00 FPS input: 0.96x
- Average synchronous render time: 2.270 ms
- First output callback wall time: 0.005 seconds
- Last output callback wall time: 1.941 seconds

## Receiver Latency Proxy

Sender and receiver clocks are not synchronized in the two-Mac case, so this report does not claim one-way sender-to-render latency. It reports receiver-side payload-complete to rendered-frame latency and frame interarrival timing.

- Average receive-complete-to-render latency: 4.099 ms
- Min receive-complete-to-render latency: 2.655 ms
- Max receive-complete-to-render latency: 9.469 ms
- Average frame interarrival: 17.312 ms
- Min frame interarrival: 11.746 ms
- Max frame interarrival: 26.479 ms

## Interpretation

The network receiver path stayed inside the current pass band for this stream.
