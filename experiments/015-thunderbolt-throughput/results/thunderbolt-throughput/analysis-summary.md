# Experiment 015 Thunderbolt Throughput Summary

Result label: `thunderbolt-throughput`

Raw sender results:

```text
experiments/015-thunderbolt-throughput/results/thunderbolt-throughput/sender/
```

Raw receiver results:

```text
experiments/015-thunderbolt-throughput/results/receiver/
```

The receiver was run without the label, so its files landed in the default
receiver output directory. The byte counts and case indexes match the labelled
sender results exactly.

## Result

| Case | Block size | Bytes | Receiver-confirmed throughput | Receiver MiB/s |
| --- | ---: | ---: | ---: | ---: |
| 64 KiB | 65,536 | 25,199,968,256 | 20,157.25 Mbps | 2,402.93 |
| 256 KiB | 262,144 | 25,197,281,280 | 20,154.73 Mbps | 2,402.63 |
| 1 MiB | 1,048,576 | 25,210,912,768 | 20,165.37 Mbps | 2,403.90 |

## Interpretation

Thunderbolt networking delivered about 20.16 Gbps single-stream TCP payload
throughput in this test, roughly 2.4 GiB/s receiver-side. The result was stable
across all three block sizes, which means transport bandwidth is not close to the
current video stream's bottleneck.

The first sender preflight took 4,500.489 ms, consistent with a Little Snitch or
macOS network approval pause. That time was outside the measured payload window;
the sender and receiver reports both show the preflight completed before timed
payload transmission.

Conclusion: Thunderbolt gives very large transport headroom. The current
3200x1800 live-stream ceiling remains ScreenCaptureKit capture pacing from
Experiment 014, not network throughput.
