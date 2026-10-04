# Virtual Display Probe

This is a throwaway macOS capability spike. It uses the private CoreGraphics
`CGVirtualDisplay` Objective-C classes to answer one question:

Can this Mac create a software-only display larger than the physically connected
displays?

Build:

```sh
clang -fobjc-arc -framework Foundation -framework CoreGraphics \
  VirtualDisplayProbe.m -o VirtualDisplayProbe
```

Run a short test:

```sh
./VirtualDisplayProbe --width=5120 --height=2880 --seconds=30
```

By default `--width` and `--height` are the backing pixel limit. With HiDPI
enabled, the first advertised mode is half that size in logical points, so the
default test creates a 5120x2880 backing display that looks like 2560x1440 to
macOS.

While it is running, open System Settings > Displays. A display named
`Codex Virtual 5K Probe` should appear. The display should disappear when the
process exits.

Build the capture probe:

```sh
clang -fobjc-arc -framework Foundation -framework CoreGraphics \
  -framework CoreVideo -framework ImageIO -framework ScreenCaptureKit \
  -framework UniformTypeIdentifiers \
  VirtualDisplayCaptureProbe.m -o VirtualDisplayCaptureProbe
```

Run the capture test:

```sh
./VirtualDisplayCaptureProbe
```

Expected result: ScreenCaptureKit enumerates the virtual display and writes a
PNG to `results/002-screencapturekit-capture/virtual-display-capture-probe.png`
when run with the project README's `--output` argument. If macOS prompts for
Screen Recording permission, grant it to the launching app and rerun.

Notes:

- This is not App Store-safe; it intentionally exercises private API.
- It should be used only as a local proof spike.
- If a previous probe is still running, new display creation can fail.
- Do not build product architecture around this file; replace it with a cleaner
  app-owned implementation after the capability is proven.
