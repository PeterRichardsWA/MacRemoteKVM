# Experiment 013 Wired Ethernet Summary

Result label: `wired-ethernet-h264-3200`

## Result

H.264 3200x1800 at 60 fps over wired Ethernet completed cleanly but missed the
strict 60 Hz sender pacing target.

- Sender: 1700 frames sent, 56.62 FPS, 20.91 Mbps.
- Capture: 1700 complete input frames, 56.64 observed complete-input FPS.
- Receiver: 1700 frames received, 1700 frames rendered, 56.98 rendered FPS,
  21.05 Mbps.
- Decode errors: 0.
- Render failures: 0.
- Average synchronous render time: 2.480 ms.
- Average receive-complete-to-render latency: 12.049 ms.

## Interpretation

The iMac Pro receiver created the required hardware H.264 decoder and rendered
every frame it received to a 5760x3240 drawable. This result is therefore not a
receiver decode/render failure. The limiting path is sender-side live
ScreenCaptureKit capture and/or VideoToolbox encode pacing.

## Timing Note

The original Experiment 013 sender wall-time starts after TCP `connect()`
returns, so a Little Snitch prompt on connection setup is outside the measured
sender FPS window. The harness has since been updated to add an explicit TCP
preflight write/ack before live capture starts, so future runs also exclude a
first-write network permission prompt from the timed sender window.
