# Experiment 015 Sender Throughput Result: 256k blocks

## Machine

- Host name: Peters-MacBook-Pro.local
- Hardware model: MacBookPro18,2
- CPU brand: Apple M1 Max

## Sender Settings

- Destination: 127.0.0.1:49330
- Case index: 2
- Block size: 262144 bytes
- Requested duration: 1.000 seconds
- Transport: single TCP stream
- Network preflight: passed before timed payload window
- Network preflight round trip: 0.021 ms

## Sender Result

- Success: yes
- Bytes sent: 4776001536
- Write operations: 18219
- Sender wall time: 1.000062 seconds
- Sender throughput: 38205.64 Mbps
- Sender throughput: 4554.47 MiB/s
- Receiver-confirmed bytes: 4776001536
- Receiver read operations: 69500
- Receiver wall time: 1.000244 seconds
- Receiver-confirmed throughput: 38198.69 Mbps

## Interpretation

This is raw single-stream TCP payload throughput after the network preflight handshake. It excludes Little Snitch or macOS permission time from the measured payload window.
