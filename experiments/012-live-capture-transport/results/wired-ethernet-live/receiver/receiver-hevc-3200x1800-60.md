# Experiment 012 Receiver Result: Case 2

## Machine

- Host name: dadimacpro.local
- macOS: Version 15.8 (Build 24H23)
- Hardware model: iMacPro1,1
- CPU brand: Intel(R) Xeon(R) W-2191B CPU @ 2.30GHz

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
- Drawable size: 5760 x 3240

## Receiver Result

- Frames received: 1721
- Bytes received: 55256946
- Measured receiver bitrate: 14.75 Mbps
- Submitted frames: 1721
- Decode call errors: 0
- Decode output callbacks: 1721
- Decode output errors: 0
- VideoToolbox dropped-frame flags: 0
- Rendered frames: 1721
- Render failures: 0
- First decoded frame: 3200 x 1800 `420v`
- Receiver wall time: 29.973 seconds
- Throughput: 57.42 rendered FPS
- Realtime multiple vs 60.00 FPS input: 0.96x
- Average synchronous render time: 1.154 ms
- First output callback wall time: 0.025 seconds
- Last output callback wall time: 29.967 seconds

## Receiver Latency Proxy

Sender and receiver clocks are not synchronized in the two-Mac case, so this report does not claim one-way sender-to-render latency. It reports receiver-side payload-complete to rendered-frame latency and frame interarrival timing.

- Average receive-complete-to-render latency: 19.194 ms
- Min receive-complete-to-render latency: 17.753 ms
- Max receive-complete-to-render latency: 51.369 ms
- Average frame interarrival: 17.412 ms
- Min frame interarrival: 5.449 ms
- Max frame interarrival: 40.921 ms

## Interpretation

The network receiver path stayed inside the current pass band for this stream.
