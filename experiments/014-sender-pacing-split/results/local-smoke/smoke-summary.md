# Experiment 014 Local Smoke Summary

Run mode: local MacBookPro18,2, 1 second per case.

## Capture-Only

- 3200x1800: 58 complete frames, 57.99 FPS by window, 57.42 FPS first/last.
- 3840x2160: 57 complete frames, 56.81 FPS by window, 56.37 FPS first/last.
- 5120x2880: 57 complete frames, 56.93 FPS by window, 57.79 FPS first/last.

## Encode-Only

- H.264 3200x1800: 60 submitted, 60 callbacks, 59.89 output FPS total.
- H.264 3840x2160: 55 submitted, 55 callbacks, 50.32 output FPS total.
- HEVC 3200x1800: 60 submitted, 60 callbacks, 59.86 output FPS total.

## Interpretation

This smoke run validates the harness. The short-run numbers suggest H.264
3200x1800 and HEVC 3200x1800 encode-only can keep up with a paced 60 Hz
synthetic source, while H.264 3840x2160 encode-only cannot. Use the default
10-second run or a labelled 30-second run for the decisive measurement.
