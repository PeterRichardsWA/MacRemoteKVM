# Experiment 006 Result: H.264 Receiver Decode/Render Baseline

## Machine

- Host name: peters-macbook-pro.local
- macOS: Version 26.6.2 (Build 25G83)
- Hardware model: MacBookPro18,2
- CPU brand: Apple M1 Max
- Processor count: 10
- Physical memory: 64.00 GB

## Input Stream

- Path: `/Users/peterrichards/dev/MacRemoteKVM/experiments/006-receiver-decode-render/media/h264-5k60-high-3s.mp4`
- File size: 16.08 MB
- Codec FourCC: `avc1`
- Format dimensions: 5120 x 2880
- Duration: 3.000 seconds
- Nominal FPS: 60.00
- Estimated bitrate: 44.97 Mbps
- Compressed sample buffers read: 184
- Compressed frame samples read: 180

## Decoder Setup

- Required hardware decoder: yes
- Hardware-required session create status: -12911 (kVTVideoDecoderMalfunctionErr)
- Fallback session create status without hardware requirement: 0 (noErr)
- Session note: hardware-required VideoToolbox session could not be created

## Render Target

- Renderer: Metal CAMetalLayer with Core Image CVPixelBuffer render
- Window backing scale: 2.00
- Drawable size: 2560 x 1440

## Decode/Render Result

- Submitted frames: 0
- Decode call errors: 0
- Decode output callbacks: 0
- Decode output errors: 0
- VideoToolbox dropped-frame flags: 0
- Rendered frames: 0
- Render failures: 0
- First decoded frame: 0 x 0 `unavailable`
- Decode/render wall time: 0.000 seconds
- Throughput: 0.00 rendered FPS
- Realtime multiple vs 60.00 FPS input: 0.00x
- Average synchronous render time: 0.000 ms
- First output callback wall time: 0.000 seconds
- Last output callback wall time: 0.000 seconds

## Interpretation

The required hardware H.264 decoder session could not be created for this 5K stream. H.264 should not be treated as viable for the first 5K transport path until this is explained or a different H.264 stream shape is tested.
