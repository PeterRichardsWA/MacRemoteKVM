# Experiment 015 Receiver Throughput Result: 64k blocks

## Machine

- Host name: Peters-MacBook-Pro.local
- Hardware model: MacBookPro18,2
- CPU brand: Apple M1 Max

## Receiver Settings

- Listen port: 49330
- Case index: 1
- Block size: 65536 bytes
- Requested sender duration: 1.000 seconds
- Transport: single TCP stream
- Network preflight: passed before timed payload window
- Network preflight handling time: 0.039 ms

## Receiver Result

- Success: yes
- Bytes received: 4005429248
- Read operations: 103122
- Receiver wall time: 1.000197 seconds
- Receiver throughput: 32037.14 Mbps
- Receiver throughput: 3819.12 MiB/s

## Interpretation

This is raw single-stream TCP payload throughput measured from the first payload read through EOF. It excludes the network preflight handshake from the measured payload window.
