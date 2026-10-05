# Experiment 016 Capture Tuning Result: Best 420f queue 8 at 1/60

## Machine

- Host name: peters-macbook-pro.local
- macOS: Version 26.6.2 (Build 25G83)
- Hardware model: MacBookPro18,2
- CPU brand: Apple M1 Max

## Capture Settings

- Requested duration: 30.0 seconds
- Source: software 5K virtual display with animated AppKit content
- Virtual display id: 54
- Virtual display backing size: 5120 x 2880
- Capture dimensions: 3200 x 1800
- Capture FPS target: 60
- Minimum frame interval: 1/60 second
- Capture resolution: Best
- Queue depth: 8
- Requested pixel format: `420f`
- Encode/network work: none

## Capture Result

- Success: yes
- Stream error: none
- Warmup callbacks ignored before measured window: 1
- Stream callbacks: 1720
- Complete frames: 1717
- Incomplete/non-frame callbacks: 3
- First frame: 3200 x 1800
- Last frame: 3200 x 1800
- First frame pixel format: `420f`
- Last frame pixel format: `420f`
- Saw IOSurface-backed buffers: yes
- All frame dimensions matched expected: yes
- Capture wall time: 30.006 seconds
- Complete FPS by capture window: 57.22
- Complete FPS by first/last frame: 57.24
- Average complete-frame interarrival: 17.470 ms
- Min complete-frame interarrival: 1.721 ms
- Max complete-frame interarrival: 46.583 ms

## Interpretation

ScreenCaptureKit capture stayed inside the current 95% pass band for this shape without encode or network work.
