# Experiment 011 Receiver Result: Case 2

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
- Serialized parameter sets: 4
- Serialized parameter-set bytes: 2393

## Decoder Setup

- Required hardware decoder: yes
- Hardware-required session create status: 0 (noErr)
- Session note: created with required hardware decoder

## Render Target

- Renderer: Metal CAMetalLayer with Core Image CVPixelBuffer render
- Window backing scale: 2.00
- Drawable size: 5120 x 2880

## Receiver Result

- Frames received: 1801
- Bytes received: 53007400
- Measured receiver bitrate: 14.12 Mbps
- Submitted frames: 1801
- Decode call errors: 0
- Decode output callbacks: 1801
- Decode output errors: 0
- VideoToolbox dropped-frame flags: 0
- Rendered frames: 1801
- Render failures: 0
- First decoded frame: 3200 x 1800 `420v`
- Receiver wall time: 30.022 seconds
- Throughput: 59.99 rendered FPS
- Realtime multiple vs 60.00 FPS input: 1.00x
- Average synchronous render time: 12.525 ms
- First output callback wall time: 0.023 seconds
- Last output callback wall time: 30.006 seconds

## Receiver Latency Proxy

Sender and receiver clocks are not synchronized in the two-Mac case, so this report does not claim one-way sender-to-render latency. It reports receiver-side payload-complete to rendered-frame latency and frame interarrival timing.

- Average receive-complete-to-render latency: 34.757 ms
- Min receive-complete-to-render latency: 17.889 ms
- Max receive-complete-to-render latency: 59.992 ms
- Average frame interarrival: 16.656 ms
- Min frame interarrival: 0.302 ms
- Max frame interarrival: 55.868 ms

## Interpretation

The network receiver path stayed inside the current pass band for this stream.
