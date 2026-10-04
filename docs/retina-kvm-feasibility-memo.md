# Retina KVM Display Feasibility Memo

Date: 2026-10-04

## Executive verdict

The full product only exists if the Host/Sender Mac can expose a 5K-capable desktop/framebuffer that macOS apps actually render into, and then stream that framebuffer to the 5K iMac/iMac Pro Viewer. Capturing a lower-resolution built-in display and upscaling it to 5120x2880 is not enough.

Current conclusion: a public, App Store-safe, software-only way to create a new 5K external/virtual display on macOS has not been found. Public APIs can capture, stream, configure, and inject input around existing displays, but they do not appear to create a new display. Therefore:

1. Software-only true extended display with Mac App Store distribution is a no-go until Apple confirms a public API or grants a suitable entitlement.
2. Developer ID / notarized direct distribution with private CGVirtualDisplay-style APIs is technically plausible, but review-ineligible, brittle, and should be treated as a deliberate non-App-Store product strategy.
3. A public-API App Store-ish path may exist only if the sender has a real 5K-capable display target supplied by hardware, such as a physical monitor or a 5K EDID/dummy/display adapter. That makes the product no longer software-only and consumes the Mac's display support budget.
4. If none of the above is acceptable, the remaining product is a fallback remote-control/mirroring tool, not the promised "old iMac as a native 5K external display" product.

## Non-negotiable feasibility gate

The Host/Sender may be a MacBook Air, MacBook Pro, Mac mini, or other Mac with no physical 5K display attached, or with a lower-resolution built-in display. The Viewer may be a 27-inch 5K iMac or iMac Pro.

For the product promise to be true:

- macOS on the Host must see a display-like render target at 5120x2880, ideally Retina/HiDPI-aware.
- Apps on the Host must be able to place windows on that target, render text/vector content at native scale, enter fullscreen, and use normal display arrangement behavior.
- The stream must capture that target at real 5120x2880, not at 2560x1440 or 4K upscaled on the Viewer.
- The target must work when the Host does not already have a 5K monitor.

This is the key risk. Encoding, transport, Viewer rendering, pairing, and input forwarding are important, but they are downstream of this display-creation requirement.

## API and distribution findings

### Public capture is feasible

ScreenCaptureKit is the right public capture layer. Apple describes it as a framework for high-performance screen/audio capture that delivers CMSampleBuffer frames, and says it replaces ReplayKit for screen streaming and mirroring. It supports SCStream, SCStreamConfiguration, SCContentFilter, SCStreamOutput, and Apple's system content-sharing picker.

What this solves:

- Capture an existing display, window, or app.
- Configure output dimensions and frame cadence.
- Capture at 60 fps when the source and machine can sustain it.
- Capture audio if needed.

What it does not solve:

- It does not create a new display.
- It does not cause macOS to allocate a 5K desktop for apps to render into.

### Public display configuration is not display creation

Quartz Display Services can list online/active displays, change modes, move displays in the global desktop coordinate space, mirror displays, and capture/stream existing display contents. Apple's own docs frame it around configuring and controlling display hardware.

That is useful for discovering and validating displays, but it is not a virtual display API. The public Core Graphics functions list configuration functions like CGConfigureDisplayWithDisplayMode and CGConfigureDisplayOrigin; there is no public CGCreateDisplay-style API exposed there.

### Private CGVirtualDisplay appears to be the known software-only route

Open-source virtual-display projects and implementation notes consistently point to private CoreGraphics classes such as CGVirtualDisplay, CGVirtualDisplayDescriptor, CGVirtualDisplayMode, and CGVirtualDisplaySettings. Some libraries explicitly warn that the API is private and unsuitable for App Store submission.

Technical attractiveness:

- Can create a software display that macOS treats like a display.
- Can expose arbitrary-ish modes such as 5120x2880.
- Can then be captured with ScreenCaptureKit and streamed.
- May avoid some physical display-engine limits because it is not a normal hardware output path, though this must be tested per OS and Mac model.

Business/distribution problem:

- Apple's App Review guideline 2.5.1 says apps may only use public APIs.
- A private API product should be assumed Mac App Store-ineligible.
- Apple can change or remove the private API in any macOS release.

### DriverKit/system extension path is not currently a clear solution

DriverKit can ship user-space drivers inside an app and is Apple's modern replacement for many kernel extension use cases. Apple documents family frameworks for devices and interfaces such as USB, HID, PCI, serial, networking, and audio. Apple's system extensions page also says DriverKit deployment requires Apple-granted entitlements.

What remains unresolved:

- I found no obvious public DriverKit display/framebuffer family for third-party virtual displays.
- A display-like system extension would need Apple entitlement approval before it is a product path.
- Even if technically possible, Mac App Store review would still need to accept the entitlement, installation flow, sandbox story, and app purpose.

Do not build against this path until Apple Developer Technical Support or entitlement review gives a concrete answer.

### Input forwarding is feasible but review-sensitive

Core Graphics exposes CGEvent creation/posting and newer permission preflight/request functions for posting and listening to events. A Host can probably receive forwarded input and synthesize keyboard/mouse events after user consent.

Risk:

- Broad event injection looks like remote control/automation.
- Apple's sandbox guidance lists several activities that are incompatible or sensitive in a sandbox, including accessibility APIs in assistive apps and simulating input in certain contexts.
- This is more plausible for Developer ID distribution than for a consumer Mac App Store app.

### Networking/discovery is feasible

Network.framework plus Bonjour is a good fit. Sandboxed apps need network client/server entitlements as appropriate. Modern macOS local network privacy requires NSLocalNetworkUsageDescription, and Bonjour browsing should declare service types in NSBonjourServices.

## Architecture options

### Option A: Public API, software-only, true 5K extended display

Status: blocked.

No public API has been identified that lets a third-party app create a 5120x2880 macOS desktop/framebuffer with normal display semantics. If Apple confirms there is no public entitlement or API, this option is dead.

Distribution: would be App Store-compatible only if Apple provides/approves a public path. Today, do not assume this exists.

### Option B: Public API plus hardware display target

Status: plausible, but product shape changes.

The Host uses a real display target: an actual 5K monitor, a 5K/6K-capable EDID emulator, a USB-C/DisplayPort/Thunderbolt dummy, a Luna-like hardware dongle, or possibly a DisplayLink-style adapter.

How it works:

1. Hardware convinces macOS that a 5K-capable display exists.
2. macOS renders a real desktop into that display target.
3. The Host captures that display with ScreenCaptureKit.
4. The Viewer displays the captured 5K stream fullscreen on the iMac.
5. Input is relayed back to the Host.

Pros:

- Avoids private virtual-display APIs.
- Gives macOS apps a real display target.
- Could be positioned honestly as "works with supported display emulator hardware."

Cons:

- Not software-only.
- Consumes one of the Host Mac's supported external display slots.
- Commodity dummy plugs often top out at 4K; true 5K60 EDID/display emulation must be validated.
- DisplayLink-like routes require separate drivers, Screen Recording permission, and introduce third-party dependency, latency, quality, and trust issues.
- App Store review may still scrutinize screen capture and input control, but the hardest private-display issue is reduced.

This is the only credible public-API path for full 5K without Apple granting a new display API/entitlement.

### Option C: Private CGVirtualDisplay plus Developer ID

Status: technically promising, business-risky.

The Host creates a private virtual display at 5120x2880, captures it with ScreenCaptureKit, streams it to the Viewer, and injects input back into that virtual desktop.

Pros:

- Software-only.
- Best fit for the target user experience.
- Can potentially support Macs with limited physical display outputs.
- Competitor/open-source activity suggests the approach works in practice.

Cons:

- Not Mac App Store-safe.
- Private API can break without notice.
- Needs a strong updater, compatibility matrix, and honest customer messaging.
- Requires Developer ID signing and notarization, plus careful permission onboarding.

This is the likely path if the product goal is "best user experience" rather than "Mac App Store first."

### Option D: DriverKit/system extension virtual display

Status: unknown, low-confidence until Apple answers.

This would be the cleanest "official-ish" software route if Apple offered a display/framebuffer DriverKit family or granted a special entitlement. Current public docs do not make that path obvious.

Pros:

- Potentially public/entitled rather than private.
- Better long-term story than CGVirtualDisplay if Apple supports it.

Cons:

- No clear public third-party display driver family found.
- Entitlement approval is uncertain.
- More engineering and support burden than the app-only approaches.
- Could still be incompatible with Mac App Store goals.

### Option E: Fallback mirroring/remote-control mode

Status: feasible, but not the main product.

Capture the Host's existing display, scale as needed, show it fullscreen on the Viewer, and relay input.

Pros:

- Public API path is straightforward.
- Useful as a remote-control or presentation mode.
- Good fallback for unsupported Macs.

Cons:

- Does not create a real 5K desktop if the Host lacks one.
- Text clarity and workspace behavior fail the core promise.
- Should not be marketed as "turn your iMac into a native 5K external display."

## Apple Silicon display-limit implications

This matters differently by path:

- Hardware target path: display limits matter directly. A 5K dummy/adapter is an external display as far as macOS is concerned. Base M1/M2 MacBooks are especially constrained if the user already has an external monitor. Newer base M4/M5 MacBook Air models support more external display configurations, but limits still depend on resolution and refresh rate.
- Private CGVirtualDisplay path: may bypass hardware display-engine limits, but this must be verified per model and OS. Do not rely on it without a matrix.
- DriverKit path: unknown until there is a concrete implementation or Apple guidance.
- Mirroring path: limited by whichever real display is being captured.

Important official examples:

- Apple says display counts depend on Mac model, resolution, and refresh rate, and hubs/daisy chains do not increase the maximum supported displays.
- M3 MacBook Air / base M3 MacBook Pro can run two external displays only with the lid closed, with the first up to 6K60 and the second up to 5K60.
- M4/M5 MacBook Air models can support two external displays in addition to the built-in display, with one-display support up to 5K120 or 8K60 and two-display support up to 6K60.
- Mac mini display support varies by chip. M2 Mac mini supports up to two displays, including one up to 6K60 and a second up to 5K60 over Thunderbolt. M4 Mac mini supports up to three displays, including configurations with a 5K60 third display.

Product implication: a hardware-dummy version must publish a compatibility matrix by Host model. A private virtual display version still needs a matrix, but for different reasons: OS/private API compatibility, ScreenCaptureKit behavior, encoder load, and whether virtual displays count against any system limit.

## Performance realities

5K60 is not casually streamable raw:

- 5120 x 2880 x 60 = 884,736,000 pixels/second.
- 24-bit RGB raw is about 21.2 Gbps before overhead.
- 32-bit BGRA raw is about 28.3 Gbps before overhead.

Compression is mandatory. The first implementation should benchmark:

- VideoToolbox H.264 and HEVC with real-time / low-latency settings.
- Zero-copy or near-zero-copy paths from ScreenCaptureKit CMSampleBuffer/CVPixelBuffer to VideoToolbox or Metal.
- GPU texture/tile/delta compression only after the baseline proves insufficient.

Transport priority:

1. Thunderbolt Bridge: flagship path.
2. Direct Ethernet: dependable fallback, especially iMac Pro 10GbE.
3. Wi-Fi: beta/convenience only, not part of the 5K60 promise.

The iMac Pro is unusually good Viewer hardware: Apple lists a 27-inch 5120x2880 Retina 5K P3 display, Nbase-T Ethernet up to 10Gb, and four Thunderbolt 3 ports up to 40Gb/s. It is compatible with macOS Sequoia, but Apple's macOS Tahoe compatibility list does not include iMac Pro 2017, so the Viewer OS ceiling is now a lifecycle risk.

## Distribution strategy recommendation

Recommended near-term strategy:

1. Treat Developer ID / notarized distribution as the primary path if pursuing the software-only full product.
2. Treat the Mac App Store as a possible fallback only for:
   - mirror/remote-control mode, or
   - a hardware-assisted version where a physical/dummy 5K display target already exists.
3. Do not spend production engineering time on App Store polish until the 5K render-target gate is settled.

App Store blocker summary:

- Full software-only virtual display likely needs private API or unavailable entitlement.
- Mac App Store apps must be sandboxed and use public APIs.
- Screen capture and input control both require sensitive permissions and clear user-facing purpose.
- Apps cannot rely on downloading/installing extra executables, drivers, or hidden components after review.

## Required spikes before production code

These should be throwaway feasibility spikes with explicit pass/fail criteria.

### Spike 1: Public-only 5K display target audit

Goal: prove whether public APIs alone can create a 5120x2880 render target.

Steps:

- Search Apple docs and headers for public virtual display/display-provider APIs.
- Ask Apple Developer Technical Support: "Is there a public or entitlement-approved way for a Mac app to create a virtual display that appears in Displays settings and can be captured/rendered at 5120x2880?"
- Document any entitlement application path Apple points to.

Pass:

- Apple identifies a public API or entitlement path compatible with external distribution goals.

Fail:

- No public API/entitlement path exists. App Store full product is dead.

### Spike 2: Hardware target proof

Goal: test whether a physical/dummy display route can deliver real 5K frames.

Steps:

- Buy/borrow 5K-capable EDID/dummy/display emulator candidates, not just 4K HDMI dummies.
- Test on base M1/M2/M3/M4/M5 laptops, Mac mini M2/M4, and Pro/Max machines if available.
- Verify actual display mode with public APIs and System Settings.
- Capture with ScreenCaptureKit and assert sample-buffer dimensions are 5120x2880.
- Stream locally to Viewer render loop and inspect text sharpness.

Pass:

- Host exposes real 5120x2880 or correct Retina/HiDPI target, apps render into it, and capture output is real 5K.

Fail:

- Hardware only exposes 4K/lower modes, mirrored/upscaled modes, or unstable display behavior.

### Spike 3: Private CGVirtualDisplay lab

Goal: decide whether a Developer ID software-only product is technically viable.

Steps:

- Create a minimal private-API proof that exposes a 5120x2880 virtual display.
- Verify Displays settings, CGDisplay lists, ScreenCaptureKit capture, Retina scaling, fullscreen Spaces, sleep/wake, reconnect, and teardown.
- Test across macOS Sequoia/Tahoe and representative Apple Silicon hosts.
- Keep it out of production and out of App Store plans until business strategy explicitly accepts the private API risk.

Pass:

- Stable virtual display creation/capture at 5K with known limitations.

Fail:

- Crashes, one-display-per-process lifecycle traps, bad scaling, ScreenCaptureKit incompatibilities, or model/OS fragility too high for a paid product.

### Spike 4: Input relay permission and behavior

Goal: prove KVM behavior without breaking trust.

Steps:

- Viewer captures keyboard/mouse only while focused/fullscreen.
- Host injects CGEvents after explicit user consent.
- Test modifier keys, shortcuts, Mission Control/Spaces, drag/scroll, keyboard layouts, stuck-key recovery, disconnect behavior, and secure input fields.
- Separate App Store-sandboxed and Developer ID builds.

Pass:

- Reliable input with transparent permission prompts and emergency local escape.

Fail:

- Unreliable shortcuts, stuck input, inaccessible permission flow, or App Store-incompatible sandbox behavior.

### Spike 5: End-to-end transport/latency

Goal: quantify whether the product feels like a display.

Steps:

- Capture a true 5K target.
- Encode with VideoToolbox H.264/HEVC using low-latency settings.
- Transport over Thunderbolt Bridge, 10GbE, 1GbE, and Wi-Fi.
- Decode/render fullscreen with Metal on iMac/iMac Pro Viewer.
- Measure fps, frame drops, glass-to-glass latency, CPU/GPU load, thermals, and reconnection.

Pass:

- 5K60 desktop motion over Thunderbolt Bridge with acceptable latency and sustainable thermals.

Fail:

- Encoder/decoder queues or transport cannot meet user-visible quality.

## Decision tree

1. If Apple confirms a public virtual display API/entitlement that supports 5K and review-compatible distribution, pursue App Store-capable full product.
2. If no public software route exists but private CGVirtualDisplay is stable enough, choose Developer ID/notarized distribution and be explicit that Mac App Store is not the route.
3. If private API risk is unacceptable, evaluate hardware-assisted public route with a 5K-capable dummy/display adapter. This may be a different product bundle.
4. If hardware route is too awkward or cannot guarantee 5K, downgrade scope to remote-control/mirror mode and stop using "native 5K external display" language.

## Product scope if proceeding

### Full product

- Host creates or uses a true 5K display target.
- Viewer renders fullscreen, pixel-perfect, on the 5K iMac panel.
- Input relay, hotkey switching, permission onboarding, reconnect handling, display/audio settings, and transport diagnostics are first-class.

### Fallback product

- Mirror/control existing Host display.
- Works at source display resolution.
- May be useful for quick switching, remote presentation, and KVM-like control.
- Should be marketed honestly as mirroring/control, not as resurrecting a 5K iMac as a real display.

## Sources checked

- Apple, ScreenCaptureKit: https://developer.apple.com/documentation/screencapturekit
- Apple, Capturing screen content in macOS: https://developer.apple.com/documentation/screencapturekit/capturing-screen-content-in-macos
- Apple, Quartz Display Services: https://developer.apple.com/documentation/coregraphics/quartz-display-services
- Apple, Core Graphics functions: https://developer.apple.com/documentation/coregraphics/core-graphics-functions
- Apple, CGEvent: https://developer.apple.com/documentation/coregraphics/cgevent
- Apple, CGRequestPostEventAccess: https://developer.apple.com/documentation/coregraphics/cgrequestposteventaccess%28%29
- Apple, App Review Guidelines: https://developer.apple.com/app-store/review/guidelines/
- Apple, App Sandbox: https://developer.apple.com/documentation/security/app-sandbox
- Apple, Protecting user data with App Sandbox: https://developer.apple.com/documentation/security/protecting-user-data-with-app-sandbox
- Apple, DriverKit: https://developer.apple.com/documentation/DriverKit
- Apple, System Extensions: https://developer.apple.com/system-extensions/
- Apple, Requesting DriverKit entitlements: https://developer.apple.com/documentation/DriverKit/requesting-entitlements-for-driverkit-development
- Apple, NSLocalNetworkUsageDescription: https://developer.apple.com/documentation/BundleResources/Information-Property-List/NSLocalNetworkUsageDescription
- Apple, TN3179 local network privacy: https://developer.apple.com/documentation/technotes/tn3179-understanding-local-network-privacy
- Apple, VideoToolbox real-time compression: https://developer.apple.com/documentation/videotoolbox/kvtcompressionpropertykey_realtime
- Apple, iMac Pro 2017 technical specifications: https://support.apple.com/en-gb/111995
- Apple, macOS Sequoia compatibility: https://support.apple.com/en-gb/120282
- Apple, macOS Tahoe compatibility: https://support.apple.com/en-ca/122867
- Apple, Connect displays to your Mac: https://support.apple.com/en-us/102555
- Apple, MacBook Air display limits: https://support.apple.com/en-us/122212
- Apple, M3 dual monitor support: https://support.apple.com/en-us/117373
- Apple, Mac mini M2 display limits: https://support.apple.com/en-us/148273
- Apple, Mac mini M4 display limits: https://support.apple.com/en-us/148271
- RetinaRelay: https://retinarelay.com/
- RetinaRelay changelog: https://retinarelay.com/changelog
- TargetBridge: https://github.com/swellweb/targetBridge
- TargetBridge features: https://github.com/swellweb/targetBridge/blob/main/docs/Features.md
- Luna Display 4K/5K support: https://support.astropad.com/en/articles/11835385-does-luna-display-support-4k-and-5k-retina-resolutions
- DisplayLink screen-recording permission: https://support.displaylink.com/knowledgebase/articles/2008685-macos-sonoma-14-screen-recording-permission
- VirtualDisplayKit private API warning: https://github.com/xocialize/VirtualDisplayKit
- BetterDummy: https://github.com/Brezel31/BetterDummy
