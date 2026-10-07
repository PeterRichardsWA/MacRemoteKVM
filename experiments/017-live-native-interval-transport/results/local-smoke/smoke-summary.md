# Experiment 017 Local Smoke

Date: 2026-10-07

Both processes ran on MacBookPro18,2 (Apple M1 Max), macOS 26.6.2, over TCP
loopback. Requested duration was 10 seconds; receiver was windowed, with a
2560x1440 drawable. This does not measure the Thunderbolt link or iMac Pro.

| Stage | Frames | Measured rate |
| --- | ---: | ---: |
| Complete capture input | 587 | 58.38 FPS, first-to-last input |
| Encode/send | 587 | 57.83 FPS over 10.151 seconds |
| Receive/render | 587 | 59.32 FPS over 9.895 seconds |

All frame counts and byte counts match. There were no encode/decode errors,
dropped-frame flags, or render failures. The receiver created a hardware HEVC
decoder. Preflight round trip was 0.175 ms and was outside sender timing.

Sender timing starts before `startCapture` and includes encoder drain. Receiver
timing starts after stream configuration and decoder creation, so its shorter
window can include a queued startup burst; the rates have different boundaries.
This result validates the live pipeline and reporting, not sustained 60 FPS.

The bundled binary contains x86_64 and arm64 slices, targets macOS 15.0 on both,
and passes ad-hoc signature verification. The script's usage, missing-host
validation, positive-duration validation, and shell syntax checks passed.
