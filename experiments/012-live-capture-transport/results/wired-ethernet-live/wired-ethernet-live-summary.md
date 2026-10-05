# Experiment 012 Wired Ethernet Live Summary

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
- Render drawable observed during run: 5760x3240

## H.264 3840x2160 at 60 fps live capture

- Sender stream callbacks: 1409
- Complete input frames: 1409
- Observed complete-input FPS: 46.93
- Encoded frames sent: 1409
- Sender frame rate: 46.81 FPS
- Sender bitrate: 20.69 Mbps
- Receiver frames received: 1409
- Receiver frames rendered: 1409
- Receiver throughput: 47.08 rendered FPS
- Receiver bitrate: 20.80 Mbps
- Decode errors: 0
- Render failures: 0
- Average receive-complete-to-render latency: 12.405 ms
- Average frame interarrival: 21.236 ms

Interpretation: H.264 3840x2160@60 completed cleanly but did not pass the live
60 fps target. The sender only captured/encoded/sent about 47 FPS. The receiver
rendered every frame it received with zero decode or render errors.

## HEVC 3200x1800 at 60 fps live capture

- Sender stream callbacks: 1723
- Complete input frames: 1721
- Observed complete-input FPS: 57.32
- Encoded frames sent: 1721
- Sender frame rate: 57.34 FPS
- Sender bitrate: 14.73 Mbps
- Receiver frames received: 1721
- Receiver frames rendered: 1721
- Receiver throughput: 57.42 rendered FPS
- Receiver bitrate: 14.75 Mbps
- Decode errors: 0
- Render failures: 0
- Average receive-complete-to-render latency: 19.194 ms
- Average frame interarrival: 17.412 ms

Interpretation: HEVC 3200x1800@60 passed the current live sender-to-receiver
pass band at about 0.96x realtime, with 1:1 sent/received/rendered frame counts
and zero decode or render errors.

## Conclusion

Experiment 012 proves the live software virtual display -> ScreenCaptureKit ->
VideoToolbox -> TCP -> hardware decode/render path works across two Macs over
wired Ethernet. HEVC 3200x1800@60 is the first live transport candidate that
passes the current threshold. H.264 3840x2160@60 remains a sender-side
capture/encode pacing problem, not a receiver decode/render problem.
