# Experiment 017 Initial Startup Failure

Date: 2026-10-07

The first 5-second local smoke failed before sending a stream header. Network
preflight succeeded (sender round trip 0.445 ms), then the sender exited with
status 133 (SIGTRAP). The receiver reported `could not read stream header` and
received zero frames. The receiver report and summary are preserved here; the
sender crashed before writing its report.

The OS crash report for our own `LiveNativeIntervalProbe` showed an Objective-C
exception while constructing an `NSDictionary` in `LiveAnimatedProbeView
drawRect:`. The font attribute dictionaries used unguarded font lookup results.
The fix added system-font fallback and inserts a font only when it exists.
The subsequent run rendered all 303 frames successfully.

No codec or transport performance conclusion can be drawn from this startup
failure. Only our own source and its OS crash report were inspected.
