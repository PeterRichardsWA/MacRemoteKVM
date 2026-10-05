# Experiment 015 Local Smoke Summary

Run mode: local loopback on MacBookPro18,2, 1 second per case.

## Sender/Receiver Throughput

- 64 KiB blocks: 32,037 Mbps receiver-confirmed throughput.
- 256 KiB blocks: 38,199 Mbps receiver-confirmed throughput.
- 1 MiB blocks: 41,056 Mbps receiver-confirmed throughput.

## Timing

Each case used the TCP preflight handshake before the timed payload window. The
reports include the `Network preflight` lines needed to prove that Little Snitch
or macOS network permission time is excluded from payload throughput.

## Interpretation

This smoke run validates the harness locally. It does not represent Thunderbolt
performance; the real result must be collected over the Thunderbolt network
interface using the receiver Mac's Thunderbolt IP address.
