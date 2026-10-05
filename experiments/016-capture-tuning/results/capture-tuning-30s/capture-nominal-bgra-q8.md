# Experiment 016 Capture Tuning Result: Nominal BGRA queue 8 at 1/60

## Machine

- Host name: peters-macbook-pro.local
- macOS: Version 26.6.2 (Build 25G83)
- Hardware model: MacBookPro18,2
- CPU brand: Apple M1 Max

## Capture Settings

- Requested duration: 30.0 seconds
- Source: software 5K virtual display with animated AppKit content
- Virtual display id: 50
- Virtual display backing size: 5120 x 2880
- Capture dimensions: 3200 x 1800
- Capture FPS target: 60
- Minimum frame interval: 1/60 second
- Capture resolution: Nominal
- Queue depth: 8
- Requested pixel format: `BGRA`
- Encode/network work: none

## Capture Result

- Success: yes
- Stream error: none
- Warmup callbacks ignored before measured window: 0
- Stream callbacks: 1725
- Complete frames: 1724
- Incomplete/non-frame callbacks: 1
- First frame: 3200 x 1800
- Last frame: 3200 x 1800
- First frame pixel format: `BGRA`
- Last frame pixel format: `BGRA`
- Saw IOSurface-backed buffers: yes
- All frame dimensions matched expected: yes
- Capture wall time: 30.011 seconds
- Complete FPS by capture window: 57.44
- Complete FPS by first/last frame: 57.46
- Average complete-frame interarrival: 17.403 ms
- Min complete-frame interarrival: 7.027 ms
- Max complete-frame interarrival: 53.129 ms

## Interpretation

ScreenCaptureKit capture stayed inside the current 95% pass band for this shape without encode or network work.
