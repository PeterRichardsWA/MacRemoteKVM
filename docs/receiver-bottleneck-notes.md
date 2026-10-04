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

Initial receiver-side throughput tests should focus on:

1. H.264 5K decode/render throughput.
2. HEVC/H.265 5K decode/render throughput.
3. HEVC-with-alpha only if a later rendering design needs alpha composition.
4. ProRes, JPEG/MJPEG, AV1, or a custom desktop-oriented codec only if H.264
   and HEVC miss latency or FPS targets.

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

Experiment 006 should generate 5K H.264 and HEVC/H.265 sample streams and run
decode/render throughput tests on the iMac Pro Viewer. The test should measure
FPS, frame drops, decode latency, display latency, CPU load, GPU load, and
whether either hardware path can sustain an interactive remote-display workload.

## Sources

- Apple VideoToolbox documentation: https://developer.apple.com/documentation/videotoolbox
- Apple `VTIsHardwareDecodeSupported`: https://developer.apple.com/documentation/videotoolbox/vtishardwaredecodesupported%28_%3A%29
- Intel HEVC support note: https://www.intel.com/content/www/us/en/support/articles/000037112/graphics.html
- Apple WWDC 2017 HEVC material: https://devstreaming-cdn.apple.com/videos/wwdc/2017/511tj33587vdhds/511/511_working_with_heif_and_hevc.pdf
