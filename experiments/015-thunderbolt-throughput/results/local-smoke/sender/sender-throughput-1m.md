# Experiment 015 Sender Throughput Result: 1m blocks

## Machine

- Host name: Peters-MacBook-Pro.local
- Hardware model: MacBookPro18,2
- CPU brand: Apple M1 Max

## Sender Settings

- Destination: 127.0.0.1:49330
- Case index: 3
- Block size: 1048576 bytes
- Requested duration: 1.000 seconds
- Transport: single TCP stream
- Network preflight: passed before timed payload window
- Network preflight round trip: 0.024 ms

## Sender Result

- Success: yes
- Bytes sent: 5133828096
- Write operations: 4896
- Sender wall time: 1.000193 seconds
- Sender throughput: 41062.69 Mbps
- Sender throughput: 4895.05 MiB/s
- Receiver-confirmed bytes: 5133828096
- Receiver read operations: 59688
- Receiver wall time: 1.000346 seconds
- Receiver-confirmed throughput: 41056.44 Mbps

## Interpretation

This is raw single-stream TCP payload throughput after the network preflight handshake. It excludes Little Snitch or macOS permission time from the measured payload window.
