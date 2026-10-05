# Experiment 013 Local Smoke Summary

Run mode: local loopback on the M1 Max development Mac

Duration: 2 seconds

## H.264 3200x1800 at 60 fps live capture

- Sender frames sent: 113
- Sender frame rate: 56.06 FPS
- Complete input frames: 113
- Observed complete-input FPS: 56.70
- Encode call errors: 0
- Output errors: 0
- Output dropped frames: 0
- Receiver frames received: 113
- Receiver frames rendered: 113
- Receiver throughput: 60.76 rendered FPS
- Decode errors: 0
- Render failures: 0
- Average receive-complete-to-render latency: 10.652 ms

## Interpretation

The local smoke run passed as an integration check for the lower H.264 stream
shape. The sender was close to, but still below, the 60 fps target in this short
run. The receiver rendered every frame it received and stayed inside the current
pass band.
