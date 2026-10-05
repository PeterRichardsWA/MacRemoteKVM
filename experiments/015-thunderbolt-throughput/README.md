# Experiment 015: Thunderbolt Throughput

Question: What raw TCP throughput do we get over the Thunderbolt network path?

This experiment is software-only and self-contained. It does not require `iperf`
or any external package. It measures single-stream sender-to-receiver TCP payload
throughput, which is the relevant transport shape for the current video stream.

## Run

On the receiver Mac:

```sh
cd /Users/peterrichards/dev/MacRemoteKVM/experiments/015-thunderbolt-throughput
./test.sh receiver thunderbolt-throughput
```

On the sender Mac:

```sh
cd /Users/peterrichards/dev/MacRemoteKVM/experiments/015-thunderbolt-throughput
./test.sh sender <receiver-thunderbolt-ip> thunderbolt-throughput
```

Results are written under:

```text
experiments/015-thunderbolt-throughput/results/thunderbolt-throughput/
```

## Cases

The default run uses three block sizes for 10 seconds each:

- 64 KiB blocks.
- 256 KiB blocks.
- 1 MiB blocks.

To run longer:

```sh
MACRKVM_THROUGHPUT_SECONDS=30 ./test.sh receiver thunderbolt-throughput-30s
MACRKVM_THROUGHPUT_SECONDS=30 ./test.sh sender <receiver-thunderbolt-ip> thunderbolt-throughput-30s
```

## Timing Boundary

Each case performs a TCP preflight write/ack before the measured payload window.
If Little Snitch or macOS asks for network permission, approve it during that
preflight. The throughput wall time begins only after the preflight and ready
acknowledgement complete.

## Interpretation

This test measures raw single-stream TCP capacity. If Thunderbolt has much higher
throughput than wired Ethernet, it may improve transport headroom, but it will
not by itself fix the current ScreenCaptureKit capture pacing ceiling found in
Experiment 014.
