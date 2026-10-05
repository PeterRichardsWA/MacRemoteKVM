# Experiment 012: Live Capture/Encode Transport

Question: Can the sender create a software 5K virtual display, capture it live
with ScreenCaptureKit, encode frames with VideoToolbox, and stream those live
compressed frames to the existing hardware-decoding iMac Pro receiver path?

This experiment keeps the Experiment 011 receiver protocol and swaps the sender
from prerecorded MP4 fixtures to live generated frames.

## Run

On the iMac Pro receiver:

```sh
cd /Users/peterrichards/dev/MacRemoteKVM/experiments/012-live-capture-transport
./test.sh receiver wired-ethernet-live
```

On the sender Mac:

```sh
cd /Users/peterrichards/dev/MacRemoteKVM/experiments/012-live-capture-transport
./test.sh sender <receiver-wired-ip> wired-ethernet-live
```

Results are written under:

```text
experiments/012-live-capture-transport/results/wired-ethernet-live/
```

## Streams

- H.264 3840x2160 at 60 fps, default target bitrate 35 Mbps.
- HEVC/H.265 3200x1800 at 60 fps, default target bitrate 20 Mbps.

The sender creates a 5120x2880 software virtual display for each stream, draws a
moving test scene, captures through ScreenCaptureKit, and encodes the capture
output at the stream dimensions.

## Notes

- The sender Mac may need Screen Recording permission for the terminal/Codex app
  running the test. If macOS prompts for permission, grant it and rerun.
- This is still a probe. It does not yet carry real user input, cursor state, or
  audio.
- Thunderbolt can use the same commands with a different label, for example
  `thunderbolt-live`.

## Wired Ethernet Result

The 30-second wired Ethernet run passed the HEVC live path:

- HEVC 3200x1800@60 live capture: 1721 frames sent, received, and rendered,
  57.42 rendered FPS, zero decode errors, zero render failures.
- H.264 3840x2160@60 live capture: 1409 frames sent, received, and rendered,
  47.08 rendered FPS, zero decode errors, zero render failures.

The H.264 miss is sender-side capture/encode pacing. The receiver rendered every
frame it received.
