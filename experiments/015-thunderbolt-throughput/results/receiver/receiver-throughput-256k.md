# Experiment 015 Receiver Throughput Result: 256k blocks

## Machine

- Host name: DadiMacPro.local
- Hardware model: iMacPro1,1
- CPU brand: Intel(R) Xeon(R) W-2191B CPU @ 2.30GHz

## Receiver Settings

- Listen port: 49330
- Case index: 2
- Block size: 262144 bytes
- Requested sender duration: 10.000 seconds
- Transport: single TCP stream
- Network preflight: passed before timed payload window
- Network preflight handling time: 0.032 ms

## Receiver Result

- Success: yes
- Bytes received: 25197281280
- Read operations: 501972
- Receiver wall time: 10.001536 seconds
- Receiver throughput: 20154.73 Mbps
- Receiver throughput: 2402.63 MiB/s

## Interpretation

This is raw single-stream TCP payload throughput measured from the first payload read through EOF. It excludes the network preflight handshake from the measured payload window.
