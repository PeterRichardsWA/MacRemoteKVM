# Experiment 016 Local Smoke Summary

Run mode: local MacBookPro18,2, 1 second per case.

## Results

- Baseline Best/BGRA/q8/1-60: 58 complete frames, 57.76 FPS by window.
- Automatic/BGRA/q8/1-60: 57 complete frames, 56.98 FPS by window.
- Nominal/BGRA/q8/1-60: 57 complete frames, 56.63 FPS by window.
- Best/BGRA/q3/1-60: 58 complete frames, 57.73 FPS by window.
- Best/BGRA/q1/1-60: 0 complete frames.
- Best/BGRA/q8/native interval: 61 complete frames, 60.44 FPS by window.
- Best/420f/q8/1-60: 57 complete frames, 56.58 FPS by window.
- Best/420v/q8/1-60: 58 complete frames, 57.85 FPS by window.

## Interpretation

The harness works and records bad variants instead of hiding them. Queue depth 1
produced no complete frames in this smoke run and should not be used as a live
candidate. The native-frame-interval case is the interesting one: it reached
about 60 FPS in the short smoke and deserves a full 30-second run.
