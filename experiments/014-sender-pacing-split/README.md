# Experiment 014: Sender Pacing Split

Question: Is the live sender ceiling coming from ScreenCaptureKit capture pacing
or VideoToolbox encode pacing?

This is a sender-only experiment. It does not use the receiver and it does not
open a network connection.

## Run

On the sender Mac:

```sh
cd /Users/peterrichards/dev/MacRemoteKVM/experiments/014-sender-pacing-split
./test.sh
```

The default run uses 10 seconds per case. To run longer:

```sh
MACRKVM_DURATION=30 ./test.sh all sender-pacing-30s
```

Focused modes:

```sh
./test.sh capture sender-capture
./test.sh encode sender-encode
```

Results are written under:

```text
experiments/014-sender-pacing-split/results/<label>/
```

## Cases

Capture-only ladder:

- ScreenCaptureKit 3200x1800 at 60 fps from a software 5K virtual display.
- ScreenCaptureKit 3840x2160 at 60 fps from a software 5K virtual display.
- ScreenCaptureKit 5120x2880 at 60 fps from a software 5K virtual display.

Encode-only ladder:

- H.264 3200x1800 at 60 fps from preallocated IOSurface-backed BGRA buffers.
- H.264 3840x2160 at 60 fps from preallocated IOSurface-backed BGRA buffers.
- HEVC/H.265 3200x1800 at 60 fps from preallocated IOSurface-backed BGRA
  buffers.

## Interpretation

If capture-only is also near 56-57 fps, the sender ceiling is before
VideoToolbox. If capture-only holds 60 fps but encode-only misses, the encoder
path is the bottleneck. If both hold 60 fps separately, the next target is the
combined capture-to-encode handoff path.
