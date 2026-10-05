# Experiment 016 Capture Tuning Result: Nominal BGRA queue 8 at 1/60

## Machine

- Host name: peters-macbook-pro.local
- macOS: Version 26.6.2 (Build 25G83)
- Hardware model: MacBookPro18,2
- CPU brand: Apple M1 Max

## Capture Settings

- Requested duration: 1.0 seconds
- Source: software 5K virtual display with animated AppKit content
- Virtual display id: 42
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
- Warmup callbacks ignored before measured window: 1
- Stream callbacks: 57
- Complete frames: 57
- Incomplete/non-frame callbacks: 0
- First frame: 3200 x 1800
- Last frame: 3200 x 1800
- First frame pixel format: `BGRA`
- Last frame pixel format: `BGRA`
- Saw IOSurface-backed buffers: yes
- All frame dimensions matched expected: yes
- Capture wall time: 1.007 seconds
- Complete FPS by capture window: 56.63
- Complete FPS by first/last frame: 56.40
- Average complete-frame interarrival: 17.731 ms
- Min complete-frame interarrival: 12.225 ms
- Max complete-frame interarrival: 30.144 ms

## Interpretation

Capture completed cleanly but did not hold the current 95% pass band before encode or network work was added.
