# Experiment 007 Result: HEVC Receiver Decode/Render Baseline

## Machine

- Host name: peters-macbook-pro.local
- macOS: Version 26.6.2 (Build 25G83)
- Hardware model: MacBookPro18,2
- CPU brand: Apple M1 Max
- Processor count: 10
- Physical memory: 64.00 GB

## Input Stream

- Path: `/Users/peterrichards/dev/MacRemoteKVM/experiments/007-receiver-hevc-decode-render/media/hevc-5k60-main-3s.mp4`
- File size: 11.43 MB
- Codec FourCC: `hvc1`
- Format dimensions: 5120 x 2880
- Duration: 3.000 seconds
- Nominal FPS: 60.00
- Estimated bitrate: 31.96 Mbps
- Compressed sample buffers read: 184
- Compressed frame samples read: 180
- Empty sample buffers skipped before decode: 4

## Decoder Setup

- Required hardware decoder: yes
- Hardware-required session create status: 0 (noErr)
- Session note: created with required hardware decoder

## Render Target

- Renderer: Metal CAMetalLayer with Core Image CVPixelBuffer render
- Window backing scale: 2.00
- Drawable size: 2560 x 1440

## Decode/Render Result

- Submitted frames: 180
- Decode call errors: 0
- Decode output callbacks: 180
- Decode output errors: 0
- VideoToolbox dropped-frame flags: 0
- Rendered frames: 180
- Render failures: 0
- First decoded frame: 5120 x 2880 `420v`
- Decode/render wall time: 1.507 seconds
- Throughput: 119.43 rendered FPS
- Realtime multiple vs 60.00 FPS input: 1.99x
- Average synchronous render time: 7.925 ms
- First output callback wall time: 0.006 seconds
- Last output callback wall time: 1.495 seconds

## Interpretation

This machine sustained at least 60 rendered FPS for the local 5K HEVC/H.265 decode/render path. HEVC/H.265 remains viable for the first receiver transport prototype.
