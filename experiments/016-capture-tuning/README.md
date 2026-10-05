# Experiment 016: ScreenCaptureKit Capture Tuning

Question: Which ScreenCaptureKit configuration gets the current 3200x1800 live
capture path closest to strict 60 Hz?

This is a sender-only test. It does not use the receiver and it does not open a
network connection. It keeps the same software 5K virtual display and animated
AppKit source used by the live sender path, then varies capture configuration.

## Run

On the sender Mac:

```sh
cd /Users/peterrichards/dev/MacRemoteKVM/experiments/016-capture-tuning
./test.sh
```

The default run uses 10 seconds per case. For a stronger run:

```sh
MACRKVM_DURATION=30 ./test.sh all capture-tuning-30s
```

Results are written under:

```text
experiments/016-capture-tuning/results/<label>/
```

## Cases

All cases capture at 3200x1800 from a 5120x2880 software virtual display.

- Baseline: `SCCaptureResolutionBest`, queue depth 8, BGRA, 1/60 frame interval.
- `SCCaptureResolutionAutomatic`, queue depth 8, BGRA, 1/60 frame interval.
- `SCCaptureResolutionNominal`, queue depth 8, BGRA, 1/60 frame interval.
- `SCCaptureResolutionBest`, queue depth 3, BGRA, 1/60 frame interval.
- `SCCaptureResolutionBest`, queue depth 1, BGRA, 1/60 frame interval.
- `SCCaptureResolutionBest`, queue depth 8, BGRA, native frame interval.
- `SCCaptureResolutionBest`, queue depth 8, 420f, 1/60 frame interval.
- `SCCaptureResolutionBest`, queue depth 8, 420v, 1/60 frame interval.

Some variants may be bad settings. The harness still writes their reports and
continues, then exits successfully as long as at least one case produced usable
capture data.

## Interpretation

Experiment 014 showed that encode-only can hold 60 Hz for the 3200x1800 H.264
and HEVC candidates, while capture-only did not. This experiment isolates the
ScreenCaptureKit knobs most likely to affect capture pacing before we reconnect
the live encoder and Thunderbolt transport.
