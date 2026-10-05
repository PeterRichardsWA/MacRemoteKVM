# Experiment 014 Sender Pacing 30s Summary

Result label: `sender-pacing-30s`

## Capture-Only

- 3200x1800@60: 1670 complete frames, 55.66 FPS by window, 55.66 FPS
  first/last, 36 incomplete/non-frame callbacks.
- 3840x2160@60: 1717 complete frames, 57.23 FPS by window, 57.23 FPS
  first/last, 5 incomplete/non-frame callbacks.
- 5120x2880@60: 1727 complete frames, 57.56 FPS by window, 57.57 FPS
  first/last, 1 incomplete/non-frame callback.

## Encode-Only

- H.264 3200x1800@60: 1800 submitted, 1800 callbacks, 59.99 output FPS,
  zero encode/output drops.
- H.264 3840x2160@60: 1465 submitted, 1465 callbacks, 48.67 output FPS,
  zero encode/output drops.
- HEVC 3200x1800@60: 1800 submitted, 1800 callbacks, 59.99 output FPS,
  zero encode/output drops.

## Interpretation

For the current viable 3200x1800 stream shape, VideoToolbox encode is not the
sender bottleneck. Both H.264 3200x1800 and HEVC 3200x1800 encode-only held a
paced 60 Hz synthetic source for 30 seconds.

The ScreenCaptureKit capture-only path did not hold strict 60 Hz. The
3200x1800 capture-only result, 55.66 FPS, is close to the live Experiment 013
sender capture result, 56.64 FPS. That makes capture pacing the primary suspect
for the live 3200x1800 sender ceiling.

H.264 3840x2160 encode-only also failed the 60 Hz target at 48.67 FPS, matching
the earlier live H.264 3840x2160 miss. Avoid H.264 3840x2160@60 as a first
product candidate unless encoder settings or stream shape change substantially.
