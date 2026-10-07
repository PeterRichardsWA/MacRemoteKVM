# Experiment 017: Live HEVC With Native Capture Interval

Question: Does Experiment 016's improved capture pacing survive the full live
capture, encode, Thunderbolt transport, decode, and render path?

This test creates a software 5120x2880 virtual display on the sender and captures
an animated source at 3200x1800. It uses ScreenCaptureKit's native frame interval
(`kCMTimeZero`), Best capture resolution, BGRA buffers, and queue depth 8. The
virtual display runs at 60 Hz. VideoToolbox encodes HEVC/H.265 Main at a target
24 Mbps. The receiver requires a hardware decoder and scales the frames to its
fullscreen Metal drawable.

The source, universal Intel/Apple Silicon executable, and script are all in this
directory. There are no fixtures, downloads, or dependencies on other experiment
directories. Both Macs require macOS 15 or later. Xcode Command Line Tools are
needed only to rebuild after editing the source.

## Run

Pull the latest repository on both Macs. On the iMac Pro receiver first:

```sh
cd /Users/peterrichards/dev/MacRemoteKVM/experiments/017-live-native-interval-transport
./test.sh receiver
```

Then on the sender, using the receiver's Thunderbolt network IP:

```sh
cd /Users/peterrichards/dev/MacRemoteKVM/experiments/017-live-native-interval-transport
./test.sh sender <receiver-thunderbolt-ip>
```

The receiver address in Experiment 015 was `169.254.159.17`; use its current
Thunderbolt address if it has changed. The label does not select the network
interface; the destination address and macOS route determine the path.

The default run measures one 30-second stream. Allow about 40-45 seconds for the
sender after permissions are granted. The receiver waits until the sender
connects and exits after that stream ends. Sender progress prints every 5 seconds.
Approve Little Snitch and macOS network prompts during preflight. The measured
sender window starts after the receiver acknowledges preflight. Screen Recording
permission is also required on the sender; grant it and rerun if macOS requests it.

Both modes default to the same result label, even when no label is supplied:

```text
results/thunderbolt-native-hevc-3200/sender/
results/thunderbolt-native-hevc-3200/receiver/
```

For another run, specify the same label on both Macs:

```sh
./test.sh receiver thunderbolt-native-hevc-repeat
./test.sh sender <receiver-thunderbolt-ip> thunderbolt-native-hevc-repeat
```

Reusing a label replaces that label's reports. Defaults can be overridden with
`MACRKVM_TRANSPORT_SECONDS`, `MACRKVM_HEVC_BITRATE_MBPS`, `MACRKVM_PORT`,
`MACRKVM_INFLIGHT`, and `MACRKVM_FULLSCREEN`. Port defaults to `49324`.
Rebuild explicitly with `./test.sh build`.

## Evaluate

Compare complete capture frames, sent frames, received frames, and rendered
frames, then compare their measured rates. Require zero encode, decode, and
render errors and no lost frames. Experiment 016's capture-only comparison was
58.69 FPS over 30 seconds; Experiment 012's live HEVC Ethernet result was about
57.4 FPS. Neither comparison proves this test's performance over Thunderbolt.

The inherited 95% pass band starts at 57 FPS. A report within that band does not
prove sustained 60 FPS. Sender timing begins before `startCapture` and ends after
encoder drain, so every counted frame belongs to that wall-time interval. This
corrects Experiment 013's boundary, which could exclude initial capture time.
The first-to-last complete-input rate is also reported for capture comparisons.
Receiver startup can release a queued burst of frames, so short receiver FPS
measurements should be read alongside sender timing and matching frame counts.
Receiver latency is measured from complete packet arrival
to render completion; the two Macs' clocks are not synchronized, so it is not a
one-way end-to-end latency measurement. Render counts record completed GPU work,
not independently measured physical display refreshes.

## Local Verification

A 10-second loopback run on the sender Mac passed with 587 frames captured,
sent, received, and rendered, with zero encode/decode/render errors. Observed
capture rate was 58.38 FPS, sender rate 57.83 FPS including startup/drain, and
receiver throughput 59.32 FPS. This verifies the harness; the two-Mac Thunderbolt
run and Intel receiver performance are pending. Earlier startup and timing-review
smoke reports are preserved under separate labels in `results/`.

## Provenance

The live pipeline and protocol come from our Experiment 013; the renderer comes
from our Experiment 006; the capture setting comes from our Experiment 016.
Their required code is contained in `LiveNativeIntervalProbe.m`. The code uses
Apple platform APIs and locally available SDK declarations, including the
previously documented private CoreGraphics virtual-display classes. No
proprietary product code, binaries, or protocols were inspected.
