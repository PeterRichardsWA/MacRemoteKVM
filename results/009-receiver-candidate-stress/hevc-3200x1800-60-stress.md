# Experiment 009 Result: HEVC 3200x1800 at 60 fps Stress

## Machine

- Host name: peters-macbook-pro.local
- macOS: Version 26.6.2 (Build 25G83)
- Hardware model: MacBookPro18,2
- CPU brand: Apple M1 Max
- Processor count: 10
- Physical memory: 64.00 GB

## Stress Settings

- Requested duration: 3.0 seconds
- Max submitted frames: unlimited
- Completed source loops: 3
- In-flight decode limit: 3
- Required hardware decoder: yes

## Input Stream

- Path: `/Users/peterrichards/dev/MacRemoteKVM/experiments/009-receiver-candidate-stress/media/hevc-3200x1800-60-main-3s.mp4`
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
- Drawable size: 2560 x 1440

## Stress Result

- Submitted frames: 363
- Represented source-video duration: 6.050 seconds
- Decode call errors: 0
- Decode output callbacks: 363
- Decode output errors: 0
- VideoToolbox dropped-frame flags: 0
- Rendered frames: 363
- Render failures: 0
- First decoded frame: 3200 x 1800 `420v`
- Decode/render wall time: 3.018 seconds
- Throughput: 120.29 rendered FPS
- Realtime multiple vs 60.00 FPS input: 2.00x
- Average synchronous render time: 7.893 ms
- First output callback wall time: 0.004 seconds
- Last output callback wall time: 3.009 seconds

## Runtime Health

- Thermal state start: nominal
- Thermal state end: nominal
- Process user CPU time: 0.242 seconds
- Process system CPU time: 0.342 seconds
- Process CPU realtime multiple: 0.19x
- Resident memory start: 46.59 MB
- Resident memory end: 53.64 MB

## Latency Proxy

This experiment does not include network transport, sender capture, or cursor input, so it cannot measure end-to-end KVM latency yet. It records decoder startup and synchronous render cost as the current local receiver latency proxy.

- Decoder startup to first output callback: 0.004 seconds
- Average synchronous render cost: 7.893 ms

## Observer Notes

- Add any visible stutter, tearing, color, or scaling observations after the run.

## Interpretation

This candidate stayed inside the current pass band for the local HEVC/H.265 decode/render stress run. It remains viable for the first receiver prototype.
