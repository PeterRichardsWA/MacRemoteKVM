# Experiment 013: Live H.264 Shape Tuning

Question: Did Experiment 012's live H.264 miss come from H.264 itself, or from
trying to live capture/encode the larger 3840x2160 stream shape?

This experiment keeps the Experiment 012 live sender/receiver path but tests a
single lower H.264 shape:

- H.264 3200x1800 at 60 fps.
- Default target bitrate: 24 Mbps.

## Run

On the iMac Pro receiver:

```sh
cd /Users/peterrichards/dev/MacRemoteKVM/experiments/013-live-h264-shape-tuning
./test.sh receiver wired-ethernet-h264-3200
```

On the sender Mac:

```sh
cd /Users/peterrichards/dev/MacRemoteKVM/experiments/013-live-h264-shape-tuning
./test.sh sender <receiver-wired-ip> wired-ethernet-h264-3200
```

Results are written under:

```text
experiments/013-live-h264-shape-tuning/results/wired-ethernet-h264-3200/
```

The sender and receiver perform a small TCP preflight handshake before the live
capture clock starts. If Little Snitch or macOS asks for network permission,
grant it during that preflight; the timed sender window begins only after the
receiver has acknowledged the preflight packet.

## Local Smoke

A 2-second local loopback smoke run passed functionally:

- Sender: 113 frames sent, 56.06 FPS, zero encode errors.
- Receiver: 113 frames received, 113 frames rendered, 60.76 rendered FPS, zero
  decode errors, zero render failures.

The local smoke run only validated integration; the two-Mac wired Ethernet
result below is the decisive result for this stream shape.

## Wired Ethernet Result

The first two-Mac wired Ethernet run completed cleanly but did not clear the
strict 60 Hz sender pacing bar:

- Sender: 1700 frames sent, 56.62 FPS, zero encode/write errors.
- Receiver: 1700 frames received, 1700 frames rendered, 56.98 rendered FPS,
  zero decode errors, zero render failures.
- Receiver render cost was low: 2.480 ms average synchronous render time.

Interpretation: this is a sender-side live capture/encode pacing miss, not an
iMac Pro receiver decode/render failure. The receiver rendered every frame it
received.
