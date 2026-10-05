# Experiment 015 Sender Throughput Result: 1m blocks

## Machine

- Host name: Peters-MacBook-Pro.local
- Hardware model: MacBookPro18,2
- CPU brand: Apple M1 Max

## Sender Settings

- Destination: 169.254.159.17:49330
- Case index: 3
- Block size: 1048576 bytes
- Requested duration: 10.000 seconds
- Transport: single TCP stream
- Network preflight: passed before timed payload window
- Network preflight round trip: 0.098 ms

## Sender Result

- Success: yes
- Bytes sent: 25210912768
- Write operations: 24043
- Sender wall time: 10.000144 seconds
- Sender throughput: 20168.44 Mbps
- Sender throughput: 2404.27 MiB/s
- Receiver-confirmed bytes: 25210912768
- Receiver read operations: 475475
- Receiver wall time: 10.001668 seconds
- Receiver-confirmed throughput: 20165.37 Mbps

## Interpretation

This is raw single-stream TCP payload throughput after the network preflight handshake. It excludes Little Snitch or macOS permission time from the measured payload window.
