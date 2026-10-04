# Experiment 007 Result: HEVC Receiver Decode/Render Baseline

## Machine

- Host name: dadimacpro.local
- macOS: Version 15.8 (Build 24H23)
- Hardware model: iMacPro1,1
- CPU brand: Intel(R) Xeon(R) W-2191B CPU @ 2.30GHz
- Processor count: 36
- Physical memory: 128.00 GB

## Input Stream

- Path: `/Users/peterrichards/+++ macrkvm/007-receiver-hevc-decode-render/media/hevc-5k60-main-3s.mp4`
- File size: 11.43 MB
- Codec FourCC: `hvc1`
- Format dimensions: 5120 x 2880
- Duration: 3.000 seconds
- Nominal FPS: 60.00
- Estimated bitrate: 31.96 Mbps
- Compressed sample buffers read: 184
- Compressed frame samples read: 180
- Empty sample buffers skipped before decode: 0

## Decoder Setup

- Required hardware decoder: yes
- Hardware-required session create status: -12907 (unknown)
- Fallback session create status without hardware requirement: 0 (noErr)
- Session note: hardware-required VideoToolbox session could not be created

## Render Target

- Renderer: Metal CAMetalLayer with Core Image CVPixelBuffer render
- Window backing scale: 2.00
- Drawable size: 5120 x 2880

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

The required hardware HEVC/H.265 decoder session could not be created for this 5K stream. HEVC/H.265 should not be treated as viable for the first 5K transport path until this is explained or a different stream shape is tested.
