# Experiment 009 Result: HEVC 3200x1800 at 60 fps Stress

## Machine

- Host name: dadimacpro.local
- macOS: Version 15.8 (Build 24H23)
- Hardware model: iMacPro1,1
- CPU brand: Intel(R) Xeon(R) W-2191B CPU @ 2.30GHz
- Processor count: 36
- Physical memory: 128.00 GB

## Stress Settings

- Requested duration: 120.0 seconds
- Max submitted frames: unlimited
- Completed source loops: 40
- In-flight decode limit: 3
- Required hardware decoder: yes

## Input Stream

- Path: `/Users/peterrichards/+++ macrkvm/009-receiver-candidate-stress/media/hevc-3200x1800-60-main-3s.mp4`
- File size: 5.04 MB
- Codec FourCC: `hvc1`
- Format dimensions: 3200 x 1800
- Duration: 3.000 seconds
- Nominal FPS: 60.00
- Estimated bitrate: 14.09 Mbps
- Compressed sample buffers read: 184
- Compressed frame samples read per source loop: 180

## Decoder Setup

- Hardware-required session create status: 0 (noErr)
- Session note: created with required hardware decoder

## Render Target

- Renderer: Metal CAMetalLayer with Core Image CVPixelBuffer render
- Window backing scale: 2.00
- Drawable size: 5120 x 2880

## Stress Result

- Submitted frames: 7196
- Represented source-video duration: 119.933 seconds
- Decode call errors: 0
- Decode output callbacks: 7196
- Decode output errors: 0
- VideoToolbox dropped-frame flags: 0
- Rendered frames: 7196
- Render failures: 0
- First decoded frame: 3200 x 1800 `420v`
- Decode/render wall time: 120.050 seconds
- Throughput: 59.94 rendered FPS
- Realtime multiple vs 60.00 FPS input: 1.00x
- Average synchronous render time: 16.322 ms
- First output callback wall time: 0.024 seconds
- Last output callback wall time: 120.033 seconds

## Runtime Health

- Thermal state start: nominal
- Thermal state end: nominal
- Process user CPU time: 4.200 seconds
- Process system CPU time: 5.258 seconds
- Process CPU realtime multiple: 0.08x
- Resident memory start: 14.93 MB
- Resident memory end: 24.12 MB

## Latency Proxy

This experiment does not include network transport, sender capture, or cursor input, so it cannot measure end-to-end KVM latency yet. It records decoder startup and synchronous render cost as the current local receiver latency proxy.

- Decoder startup to first output callback: 0.024 seconds
- Average synchronous render cost: 16.322 ms

## Observer Notes

- Add any visible stutter, tearing, color, or scaling observations after the run.

## Interpretation

This candidate stayed inside the current pass band for the local HEVC/H.265 decode/render stress run. It remains viable for the first receiver prototype.
