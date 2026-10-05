# Experiment 016 Capture Tuning Result: Best BGRA queue 8 native interval

## Machine

- Host name: peters-macbook-pro.local
- macOS: Version 26.6.2 (Build 25G83)
- Hardware model: MacBookPro18,2
- CPU brand: Apple M1 Max

## Capture Settings

- Requested duration: 1.0 seconds
- Source: software 5K virtual display with animated AppKit content
- Virtual display id: 45
- Virtual display backing size: 5120 x 2880
- Capture dimensions: 3200 x 1800
- Capture FPS target: 60
- Minimum frame interval: native display refresh (kCMTimeZero)
- Capture resolution: Best
- Queue depth: 8
- Requested pixel format: `BGRA`
- Encode/network work: none

## Capture Result

- Success: yes
- Stream error: none
- Warmup callbacks ignored before measured window: 0
- Stream callbacks: 61
- Complete frames: 61
- Incomplete/non-frame callbacks: 0
- First frame: 3200 x 1800
- Last frame: 3200 x 1800
- First frame pixel format: `BGRA`
- Last frame pixel format: `BGRA`
- Saw IOSurface-backed buffers: yes
- All frame dimensions matched expected: yes
- Capture wall time: 1.009 seconds
- Complete FPS by capture window: 60.44
- Complete FPS by first/last frame: 60.12
- Average complete-frame interarrival: 16.632 ms
- Min complete-frame interarrival: 7.968 ms
- Max complete-frame interarrival: 25.557 ms

## Interpretation

ScreenCaptureKit capture stayed inside the current 95% pass band for this shape without encode or network work.
