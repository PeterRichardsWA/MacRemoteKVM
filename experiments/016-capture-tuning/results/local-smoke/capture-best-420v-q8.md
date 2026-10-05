# Experiment 016 Capture Tuning Result: Best 420v queue 8 at 1/60

## Machine

- Host name: peters-macbook-pro.local
- macOS: Version 26.6.2 (Build 25G83)
- Hardware model: MacBookPro18,2
- CPU brand: Apple M1 Max

## Capture Settings

- Requested duration: 1.0 seconds
- Source: software 5K virtual display with animated AppKit content
- Virtual display id: 47
- Virtual display backing size: 5120 x 2880
- Capture dimensions: 3200 x 1800
- Capture FPS target: 60
- Minimum frame interval: 1/60 second
- Capture resolution: Best
- Queue depth: 8
- Requested pixel format: `420v`
- Encode/network work: none

## Capture Result

- Success: yes
- Stream error: none
- Warmup callbacks ignored before measured window: 0
- Stream callbacks: 58
- Complete frames: 58
- Incomplete/non-frame callbacks: 0
- First frame: 3200 x 1800
- Last frame: 3200 x 1800
- First frame pixel format: `420v`
- Last frame pixel format: `420v`
- Saw IOSurface-backed buffers: yes
- All frame dimensions matched expected: yes
- Capture wall time: 1.003 seconds
- Complete FPS by capture window: 57.85
- Complete FPS by first/last frame: 57.62
- Average complete-frame interarrival: 17.355 ms
- Min complete-frame interarrival: 3.500 ms
- Max complete-frame interarrival: 33.276 ms

## Interpretation

ScreenCaptureKit capture stayed inside the current 95% pass band for this shape without encode or network work.
