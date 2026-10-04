# Experiment 010 Result: HEVC 3200x1800 at 60 fps Loopback Transport

## Machine

- Host name: dadimacpro.local
- macOS: Version 15.8 (Build 24H23)
- Hardware model: iMacPro1,1
- CPU brand: Intel(R) Xeon(R) W-2191B CPU @ 2.30GHz
- Processor count: 36
- Physical memory: 128.00 GB

## Transport Settings

- Transport: local TCP loopback, one sender thread, one receiver thread
- Payload format: compressed sample payload per frame
- Decoder config: shared in process from local asset format description
- Header encoding: native-endian prototype frame header
- Requested duration: 30.0 seconds
- Realtime pacing: yes
- In-flight decode limit: 3
- Loopback listener port: 54534

## Input Stream

- Path: `/Users/peterrichards/+++ macrkvm/010-loopback-transport-prototype/media/hevc-3200x1800-60-main-3s.mp4`
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
- Drawable size: 5120 x 2880

## Transport Result

- Sender frames sent: 1801
- Sender bytes sent: 53007400
- Source loops completed: 10
- Sender wall time: 30.004 seconds
- Measured transport bitrate: 14.13 Mbps
- Receiver frames received: 1801
- Receiver bytes received: 53007400

## Decode/Render Result

- Submitted frames: 1801
- Decode call errors: 0
- Decode output callbacks: 1801
- Decode output errors: 0
- VideoToolbox dropped-frame flags: 0
- Rendered frames: 1801
- Render failures: 0
- First decoded frame: 3200 x 1800 `420v`
- Receiver wall time: 30.073 seconds
- Throughput: 59.89 rendered FPS
- Realtime multiple vs 60.00 FPS input: 1.00x
- Average synchronous render time: 16.298 ms
- First output callback wall time: 0.023 seconds
- Last output callback wall time: 30.041 seconds

## Latency Proxy

This is a local loopback transport result. It measures sender write time to receiver payload completion and sender write time to rendered frame on the same Mac. It does not yet include real network jitter, sender capture, live encode, cross-machine clock sync, or input/cursor round trip.

- Average sender-to-receiver payload latency: 2.510 ms
- Min sender-to-receiver payload latency: 0.041 ms
- Max sender-to-receiver payload latency: 22.562 ms
- Average sender-to-rendered-frame latency: 51.182 ms
- Min sender-to-rendered-frame latency: 20.149 ms
- Max sender-to-rendered-frame latency: 72.134 ms

## Interpretation

The local loopback transport path stayed inside the current pass band for HEVC/H.265. This candidate is ready for a two-Mac transport test.
