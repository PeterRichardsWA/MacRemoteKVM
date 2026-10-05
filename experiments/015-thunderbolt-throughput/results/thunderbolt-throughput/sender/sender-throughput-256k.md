# Experiment 015 Sender Throughput Result: 256k blocks

## Machine

- Host name: Peters-MacBook-Pro.local
- Hardware model: MacBookPro18,2
- CPU brand: Apple M1 Max

## Sender Settings

- Destination: 169.254.159.17:49330
- Case index: 2
- Block size: 262144 bytes
- Requested duration: 10.000 seconds
- Transport: single TCP stream
- Network preflight: passed before timed payload window
- Network preflight round trip: 0.146 ms

## Sender Result

- Success: yes
- Bytes sent: 25197281280
- Write operations: 96120
- Sender wall time: 10.000018 seconds
- Sender throughput: 20157.79 Mbps
- Sender throughput: 2403.00 MiB/s
- Receiver-confirmed bytes: 25197281280
- Receiver read operations: 501972
- Receiver wall time: 10.001536 seconds
- Receiver-confirmed throughput: 20154.73 Mbps

## Interpretation

This is raw single-stream TCP payload throughput after the network preflight handshake. It excludes Little Snitch or macOS permission time from the measured payload window.
