# Experiment 015 Sender Throughput Result: 64k blocks

## Machine

- Host name: Peters-MacBook-Pro.local
- Hardware model: MacBookPro18,2
- CPU brand: Apple M1 Max

## Sender Settings

- Destination: 169.254.159.17:49330
- Case index: 1
- Block size: 65536 bytes
- Requested duration: 10.000 seconds
- Transport: single TCP stream
- Network preflight: passed before timed payload window
- Network preflight round trip: 4500.489 ms

## Sender Result

- Success: yes
- Bytes sent: 25199968256
- Write operations: 384521
- Sender wall time: 10.000036 seconds
- Sender throughput: 20159.90 Mbps
- Sender throughput: 2403.25 MiB/s
- Receiver-confirmed bytes: 25199968256
- Receiver read operations: 450446
- Receiver wall time: 10.001354 seconds
- Receiver-confirmed throughput: 20157.25 Mbps

## Interpretation

This is raw single-stream TCP payload throughput after the network preflight handshake. It excludes Little Snitch or macOS permission time from the measured payload window.
