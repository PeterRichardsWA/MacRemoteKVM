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
- We need to test on the actual target iMac before choosing a codec strategy.

## Likely Codec Direction

Initial receiver-side tests should focus on:

1. H.264 hardware decode support and 5K decode throughput.
2. HEVC/H.265 hardware decode support and 5K decode throughput.
3. ProRes Proxy/LT hardware decode support and bandwidth cost.
4. JPEG/MJPEG-style decode throughput and bandwidth cost.
5. A custom desktop-oriented codec if standard video codecs miss latency or FPS.

## Public Hardware Context

Intel documents HEVC/H.265 hardware acceleration beginning with 6th-generation
Intel Core processors, but Apple/macOS support and profile support vary by Mac.
Apple's WWDC 2017 HEVC materials distinguish 8-bit and 10-bit HEVC hardware
decode support by Intel generation. VideoToolbox exposes
`VTIsHardwareDecodeSupported` so we can directly query the actual receiver Mac.

## Next Test

Run the packaged receiver-side capability probe on the old iMac:

```sh
cd experiments/005-receiver-codec-capability
./run_receiver_codec_capability.sh
```

The probe records:

- Mac model, CPU, GPU, macOS version.
- Hardware decode support for H.264, HEVC/H.265, ProRes, JPEG, and AV1.
- Available VideoToolbox encoders for comparison.
- Whether the target machine can plausibly decode the candidate stream in
  hardware.

After that, generate codec-specific sample streams and run decode/render
throughput tests on the receiver.

## Sources

- Apple VideoToolbox documentation: https://developer.apple.com/documentation/videotoolbox
- Apple `VTIsHardwareDecodeSupported`: https://developer.apple.com/documentation/videotoolbox/vtishardwaredecodesupported%28_%3A%29
- Intel HEVC support note: https://www.intel.com/content/www/us/en/support/articles/000037112/graphics.html
- Apple WWDC 2017 HEVC material: https://devstreaming-cdn.apple.com/videos/wwdc/2017/511tj33587vdhds/511/511_working_with_heif_and_hevc.pdf
