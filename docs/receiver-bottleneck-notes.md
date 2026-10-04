# Receiver Bottleneck Notes

Date: 2026-10-04

## Corrected Performance Assumption

The Host/Sender machine is expected to be the faster Mac. It can spend GPU,
media-engine, and CPU resources creating the virtual display, capturing frames,
encoding data, and pushing bytes over the link.

The Viewer/Receiver is expected to be the older 5K iMac or iMac Pro. Its decode
and render path is therefore the more important bottleneck.

## Implications

- Sender encode speed is still relevant, but it is not the primary risk.
- Receiver hardware decode support determines whether H.264, HEVC/H.265,
  ProRes, JPEG, or a custom codec is realistic.
- Older Intel iMac hardware varies materially by year and CPU/GPU generation.
- HEVC/H.265 is especially model-sensitive on Intel Macs.
- We tested the actual target iMac Pro before choosing a codec strategy.

## Likely Codec Direction

The 5K60 hardware-decode path failed for both H.264 and HEVC/H.265 on the target
iMac Pro, but the receiver envelope test found viable lower points:

1. H.264 3840x2160 at 60 fps created a hardware session and rendered at about
   59.4 FPS.
2. HEVC/H.265 3200x1800 at 60 fps created a hardware session and rendered at
   about 58.7 FPS.
3. HEVC/H.265 3840x2160 and 4096x2304 created hardware sessions but did not
   sustain 60 FPS.
4. HEVC/H.265 5120x2880 at 30 fps still failed to create a required-hardware
   decoder session.

The first prototype receiver path should use H.264 4K60 scaled to the 5K
display as the detail-first candidate, with HEVC 3200x1800@60 as the
lower-bandwidth alternative. If full 5K fidelity remains required, the next
design path is tiling, adaptive resolution, or a custom desktop-oriented codec
rather than a single 5K60 VideoToolbox stream.

## Public Hardware Context

Intel documents HEVC/H.265 hardware acceleration beginning with 6th-generation
Intel Core processors, but Apple/macOS support and profile support vary by Mac.
Apple's WWDC 2017 HEVC materials distinguish 8-bit and 10-bit HEVC hardware
decode support by Intel generation. VideoToolbox exposes
`VTIsHardwareDecodeSupported` so we can directly query the actual receiver Mac.

## Actual iMac Pro Result

Experiment 005 was run on the target Viewer:

```text
Hardware model: iMacPro1,1
CPU: Intel(R) Xeon(R) W-2191B CPU @ 2.30GHz
GPU: Radeon Pro Vega 64, 16 GB VRAM
macOS: Version 15.8 (Build 24H23)
Built-in display: Retina 5K (5120 x 2880)
```

Hardware decode support reported by VideoToolbox:

- H.264 / AVC: yes.
- HEVC / H.265: yes.
- HEVC with Alpha: yes.
- Apple ProRes 422 Proxy/LT/422/HQ: no.
- JPEG: no.
- AV1: no.

## Next Test

Experiment 006 tested the first H.264 baseline:

```sh
cd experiments/006-receiver-decode-render
./run_h264_decode_render_probe.sh
```

It uses a checked-in 5120x2880/60 fps H.264 High Profile stream and requires a
hardware VideoToolbox decoder before attempting Metal/Core Image rendering.

The target iMac Pro could not create the required-hardware decoder session for
that 5K H.264 stream:

```text
Hardware-required session create status: -12913 (kVTVideoDecoderNotAvailableNowErr)
Fallback session create status without hardware requirement: 0 (noErr)
```

That means 5K H.264 should not be the first transport path. The next receiver
throughput test should move directly to HEVC/H.265.

Experiment 007 packages that HEVC/H.265 test:

```sh
cd experiments/007-receiver-hevc-decode-render
./run_hevc_decode_render_probe.sh
```

The local M1 Max smoke run created a required-hardware HEVC decoder session and
rendered all 180 frames at roughly 119 FPS. The target iMac Pro run could not
create a required-hardware decoder session for the same 5K60 stream:

```text
Hardware-required session create status: -12907 (kVTCouldNotCreateInstanceErr)
Fallback session create status without hardware requirement: 0 (noErr)
```

That means neither 5K60 H.264 nor 5K60 HEVC is viable as the first receiver
transport path on this iMac Pro. The next receiver test should map the practical
hardware decode envelope by lowering resolution and/or frame rate.

Experiment 008 packages that envelope test:

```sh
cd experiments/008-receiver-decode-envelope
./run_decode_envelope_probe.sh
```

It tests HEVC/H.265 at 5K30, 4096x2304@60, 3840x2160@60, 3200x1800@60, and
2560x1440@60, plus H.264 fallback points at 3840x2160@60 and 2560x1440@60.

The target iMac Pro result identified H.264 3840x2160@60 as the strongest
passing candidate so far, with HEVC 3200x1800@60 as a plausible lower-bandwidth
candidate.

Experiment 009 packages the longer receiver stress test:

```sh
cd experiments/009-receiver-candidate-stress
./test.sh
```

It compares those two candidates over a default 120-second fullscreen run and
records hardware decoder status, rendered FPS, render cost, process CPU, memory,
thermal state, and local receiver latency proxies.

The target iMac Pro result passed for both first candidates:

```text
H.264 3840x2160 @ 60: hardware session yes, 7196 frames, 59.95 rendered FPS
HEVC 3200x1800 @ 60: hardware session yes, 7196 frames, 59.94 rendered FPS
Decode errors: 0
Render failures: 0
Thermal state: nominal -> nominal for both candidates
```

This moves the bottleneck from local receiver decode/render to transport,
frame pacing, end-to-end latency, and real desktop visual quality.

## Sources

- Apple VideoToolbox documentation: https://developer.apple.com/documentation/videotoolbox
- Apple `VTIsHardwareDecodeSupported`: https://developer.apple.com/documentation/videotoolbox/vtishardwaredecodesupported%28_%3A%29
- Intel HEVC support note: https://www.intel.com/content/www/us/en/support/articles/000037112/graphics.html
- Apple WWDC 2017 HEVC material: https://devstreaming-cdn.apple.com/videos/wwdc/2017/511tj33587vdhds/511/511_working_with_heif_and_hevc.pdf
