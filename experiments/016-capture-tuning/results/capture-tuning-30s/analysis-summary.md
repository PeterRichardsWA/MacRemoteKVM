# Experiment 016 Capture Tuning 30s Summary

Result label: `capture-tuning-30s`

## Result

| Case | Complete frames | FPS by window | FPS first/last | Notes |
| --- | ---: | ---: | ---: | --- |
| Best/BGRA/q8/1-60 baseline | 1,723 | 57.42 | 57.43 | Baseline from the current live sender shape. |
| Automatic/BGRA/q8/1-60 | 1,675 | 55.83 | 55.82 | Worse than baseline. |
| Nominal/BGRA/q8/1-60 | 1,724 | 57.44 | 57.46 | Similar to baseline. |
| Best/BGRA/q3/1-60 | 1,727 | 57.56 | 57.60 | Slightly better than baseline. |
| Best/BGRA/q1/1-60 | 0 | 0.00 | 0.00 | Bad setting; no complete frames. |
| Best/BGRA/q8/native interval | 1,761 | 58.69 | 58.68 | Best result in this run. |
| Best/420f/q8/1-60 | 1,717 | 57.22 | 57.24 | Output pixel format was 420f. |
| Best/420v/q8/1-60 | 1,710 | 56.98 | 57.00 | Output pixel format was 420v. |

## Interpretation

The native-frame-interval case is the best ScreenCaptureKit configuration tested
so far. It improved the 3200x1800 capture-only path from 57.42 FPS to 58.69 FPS
over 30 seconds.

That is a meaningful improvement, but not a full strict-60 unlock. The current
best capture-only path is still below 60 FPS before encode or transport work is
added.

Queue depth 1 should be avoided: it produced no complete frames. Pixel formats
420f and 420v worked, but neither improved capture pacing versus BGRA. Automatic
capture resolution was worse than Best/Nominal in this run.

## Next Step

The next live candidate should combine the best capture setting with the already
proven fast paths:

- ScreenCaptureKit minimum frame interval: native display refresh
  (`kCMTimeZero`).
- Capture size: 3200x1800.
- Codec: HEVC 3200x1800 or H.264 3200x1800.
- Transport: Thunderbolt.

This will show whether the 58.69 FPS capture-only improvement survives the full
live capture -> encode -> Thunderbolt -> decode/render path.
