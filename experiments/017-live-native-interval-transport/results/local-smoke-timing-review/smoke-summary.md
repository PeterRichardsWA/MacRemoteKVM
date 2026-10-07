# Experiment 017 Smoke Before Timing Correction

Date: 2026-10-07

After the drawing fix, the 5-second loopback run captured, sent, received, and
rendered all 303 frames with zero encode/decode/render errors. Preflight passed
with a 0.126 ms round trip. The source used the native ScreenCaptureKit interval.

The sender reported 60.29 FPS, but its clock started after capture startup while
the count could already include capture callbacks. The observed first-to-last
capture rate was 59.70 FPS. These reports are preserved to document the timing
issue; they are not evidence of sustained 60 FPS.

The final source starts the monotonic sender clock before `startCapture`, after
network preflight, and stops it after encoder drain. The final 10-second smoke
reports are under `../local-smoke/`.
