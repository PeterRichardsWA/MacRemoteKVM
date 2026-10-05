# Experiment 015 Sender Throughput Result: 64k blocks

## Machine

- Host name: Peters-MacBook-Pro.local
- Hardware model: MacBookPro18,2
- CPU brand: Apple M1 Max

## Sender Settings

- Destination: 127.0.0.1:49330
- Case index: 1
- Block size: 65536 bytes
- Requested duration: 1.000 seconds
- Transport: single TCP stream
- Network preflight: passed before timed payload window
- Network preflight round trip: 0.073 ms

## Sender Result

- Success: yes
- Bytes sent: 4005429248
- Write operations: 61118
- Sender wall time: 1.000006 seconds
- Sender throughput: 32043.24 Mbps
- Sender throughput: 3819.85 MiB/s
- Receiver-confirmed bytes: 4005429248
- Receiver read operations: 103122
- Receiver wall time: 1.000197 seconds
- Receiver-confirmed throughput: 32037.14 Mbps

## Interpretation

This is raw single-stream TCP payload throughput after the network preflight handshake. It excludes Little Snitch or macOS permission time from the measured payload window.
