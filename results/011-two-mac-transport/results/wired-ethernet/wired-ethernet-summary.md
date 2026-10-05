# Experiment 011 Wired Ethernet Summary

Network condition: wired Ethernet

Sender:

- Host: `peters-macbook-pro.local`
- Model: `MacBookPro18,2`
- CPU: Apple M1 Max
- macOS: 26.6.2 build 25G83
- Destination: `192.168.0.91:49320`

Receiver:

- Host: `dadimacpro.local`
- Model: `iMacPro1,1`
- CPU: Intel Xeon W-2191B
- macOS: 15.8 build 24H23
- Display target: 5120x2880 Metal drawable

## H.264 3840x2160 at 60 fps

- Sender frames: 1801
- Sender wall time: 30.001 seconds
- Sender frame rate: 60.03 FPS
- Sender bitrate: 20.74 Mbps
- Receiver frames received: 1801
- Receiver frames rendered: 1801
- Receiver throughput: 59.89 rendered FPS
- Receiver bitrate: 20.69 Mbps
- Decode errors: 0
- Render failures: 0
- Average receive-complete-to-render latency: 49.985 ms
- Max receive-complete-to-render latency: 112.642 ms

Interpretation: H.264 3840x2160@60 passed the wired Ethernet two-Mac transport
run. This confirms the earlier Wi-Fi 6E H.264 shortfall was not an iMac Pro
hardware decode/render failure.

## HEVC 3200x1800 at 60 fps

- Sender frames: 1801
- Sender wall time: 30.004 seconds
- Sender frame rate: 60.02 FPS
- Sender bitrate: 14.13 Mbps
- Receiver frames received: 1801
- Receiver frames rendered: 1801
- Receiver throughput: 60.00 rendered FPS
- Receiver bitrate: 14.13 Mbps
- Decode errors: 0
- Render failures: 0
- Average receive-complete-to-render latency: 33.745 ms
- Max receive-complete-to-render latency: 54.494 ms

Interpretation: HEVC 3200x1800@60 passed the wired Ethernet two-Mac transport
run.

## Next Comparison

Run the same Experiment 011 package over Thunderbolt networking before changing
codec candidates or stream dimensions.
