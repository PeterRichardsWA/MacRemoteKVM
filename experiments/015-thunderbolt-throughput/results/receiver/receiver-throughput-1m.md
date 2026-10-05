# Experiment 015 Receiver Throughput Result: 1m blocks

## Machine

- Host name: DadiMacPro.local
- Hardware model: iMacPro1,1
- CPU brand: Intel(R) Xeon(R) W-2191B CPU @ 2.30GHz

## Receiver Settings

- Listen port: 49330
- Case index: 3
- Block size: 1048576 bytes
- Requested sender duration: 10.000 seconds
- Transport: single TCP stream
- Network preflight: passed before timed payload window
- Network preflight handling time: 0.653 ms

## Receiver Result

- Success: yes
- Bytes received: 25210912768
- Read operations: 475475
- Receiver wall time: 10.001668 seconds
- Receiver throughput: 20165.37 Mbps
- Receiver throughput: 2403.90 MiB/s

## Interpretation

This is raw single-stream TCP payload throughput measured from the first payload read through EOF. It excludes the network preflight handshake from the measured payload window.
