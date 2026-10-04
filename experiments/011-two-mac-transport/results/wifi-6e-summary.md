# Experiment 011 Wi-Fi 6E Summary

Network condition: Wi-Fi 6E

Sender:

- Host: `peters-macbook-pro.local`
- Model: `MacBookPro18,2`
- CPU: Apple M1 Max
- macOS: 26.6.2 build 25G83

Receiver:

- Host: `dadimacpro.local`
- Model: `iMacPro1,1`
- CPU: Intel Xeon W-2191B
- macOS: 15.8 build 24H23
- Display target: 5120x2880 Metal drawable

## H.264 3840x2160 at 60 fps

- Sender frames: 1190
- Sender wall time: 30.010 seconds
- Sender frame rate: 39.65 FPS
- Sender bitrate: 13.67 Mbps
- Receiver frames received: 1190
- Receiver frames rendered: 1190
- Receiver throughput while frames were arriving: 59.92 rendered FPS
- Receiver bitrate: 20.66 Mbps
- Decode errors: 0
- Render failures: 0
- Average receive-complete-to-render latency: 49.971 ms

Interpretation: H.264 did not pass the Wi-Fi 6E sender/network path in this
run because the sender only delivered 1190 frames in 30 seconds. The receiver
decoded and rendered every frame it received, so this is not a receiver decode
failure.

## HEVC 3200x1800 at 60 fps

- Sender frames: 1801
- Sender wall time: 30.001 seconds
- Sender frame rate: 60.03 FPS
- Sender bitrate: 14.13 Mbps
- Receiver frames received: 1801
- Receiver frames rendered: 1801
- Receiver throughput: 59.99 rendered FPS
- Receiver bitrate: 14.12 Mbps
- Decode errors: 0
- Render failures: 0
- Average receive-complete-to-render latency: 34.757 ms

Interpretation: HEVC 3200x1800@60 passed the Wi-Fi 6E two-Mac transport run.

## Next Comparison

Rerun the same Experiment 011 package over wired Ethernet and Thunderbolt
networking before changing codec candidates or stream dimensions.
