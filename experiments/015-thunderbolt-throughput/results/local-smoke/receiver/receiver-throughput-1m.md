# Experiment 015 Receiver Throughput Result: 1m blocks

## Machine

- Host name: Peters-MacBook-Pro.local
- Hardware model: MacBookPro18,2
- CPU brand: Apple M1 Max

## Receiver Settings

- Listen port: 49330
- Case index: 3
- Block size: 1048576 bytes
- Requested sender duration: 1.000 seconds
- Transport: single TCP stream
- Network preflight: passed before timed payload window
- Network preflight handling time: 0.006 ms

## Receiver Result

- Success: yes
- Bytes received: 5133828096
- Read operations: 59688
- Receiver wall time: 1.000346 seconds
- Receiver throughput: 41056.44 Mbps
- Receiver throughput: 4894.31 MiB/s

## Interpretation

This is raw single-stream TCP payload throughput measured from the first payload read through EOF. It excludes the network preflight handshake from the measured payload window.
