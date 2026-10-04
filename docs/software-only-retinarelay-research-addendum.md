# Software-Only RetinaRelay Research Addendum

Date: 2026-10-04

## Bottom line

If hardware is off the table, the viable software-only path is almost certainly:

1. Create a sender-side virtual display on the Host Mac.
2. Make macOS treat that display as a real extended desktop at/near 5120x2880.
3. Capture that virtual display with ScreenCaptureKit.
4. Compress and stream frames over Thunderbolt Bridge, USB networking, or Ethernet.
5. Render fullscreen with Metal on the iMac Viewer.

The hard truth remains: the virtual-display creation step appears to depend on private CoreGraphics `CGVirtualDisplay` APIs, not a public App Store-safe API. RetinaRelay appears to have accepted that tradeoff and ships outside the Mac App Store.

## What RetinaRelay publicly says

RetinaRelay discloses quite a lot at the product/architecture level:

- Host captures with ScreenCaptureKit; Viewer draws with Metal.
- It supports Extended and Mirror modes.
- The Viewer reaches native 5120x2880 at 60 fps.
- Version 2 stopped using normal video codecs over cable; each frame is compressed into a GPU texture format, then a lossless second pass typically shrinks desktop frames by 14-19x.
- The Host needs Screen Recording permission only; version 2 no longer asks for Accessibility.
- The stream is direct TCP between the two Macs.
- DRM-protected content may appear black because it is still screen capture.

Inference from those facts:

- Extended mode needs a Host-side display target. Since no public macOS API is known for software-only virtual display creation, RetinaRelay very likely creates a private virtual display, then captures it.
- The absence of Accessibility permission suggests RetinaRelay is probably not doing full Host-side input injection. Its “cursor does not lag” claim is likely a Viewer-side cursor rendering/movement strategy, not KVM-style control of the Host from the Viewer’s keyboard and mouse.
- RetinaRelay’s big differentiator appears to be the transport/codec layer, not the existence of the virtual-display primitive itself.

This is an inference from public statements, not a reverse-engineered finding.

## The prior-art stack is visible

Multiple current software-only projects use the same conceptual pipeline:

- `CGVirtualDisplay` creates the display.
- ScreenCaptureKit captures the virtual display.
- VideoToolbox or a custom encoder compresses the frames.
- Network.framework/TCP/RTP/UDP sends the stream.
- The receiver decodes/renders fullscreen.

OpenDisplay’s public docs explicitly diagram: `CGVirtualDisplay -> ScreenCaptureKit -> VideoToolbox -> TCP -> receiver`, and state that `CGVirtualDisplay` is private CoreGraphics, which is why it cannot ship on the App Store.

TargetBridge publicly says Extended Desktop creates a virtual display on the sender and streams it to the receiver. Its docs describe a ScreenCaptureKit + VideoToolbox + Thunderbolt Bridge pipeline, and its source is MIT-licensed.

PrimeLab’s VirtualDisplay notes are the clearest technical writeup I found. They state:

- There is no public macOS API for creating a display.
- The private `CGVirtualDisplay` family is the mechanism every third-party virtual-display app appears to use.
- The classes involved are `CGVirtualDisplayDescriptor`, `CGVirtualDisplay`, `CGVirtualDisplaySettings`, and `CGVirtualDisplayMode`.
- A virtual display is composited into an off-screen surface, so it does not consume a physical display engine.
- This is why virtual displays can bypass base Apple Silicon external-display limits in ways real monitors cannot.

## Consequence for our product

Software-only is feasible as a Developer ID/notarized product, but probably not as a Mac App Store product.

That means the distribution decision becomes:

- Accept private API risk and sell direct.
- Build a software-only product that is honest about macOS compatibility risk.
- Re-test every major macOS release.
- Avoid claiming Mac App Store viability.

It also means there are really two independent challenges:

1. Display creation: private `CGVirtualDisplay`, well-trodden but unsupported.
2. RetinaRelay-class performance: custom frame compression and adaptive transport, much harder but implementable independently.

## Clean-room approach

Do not reverse-engineer RetinaRelay binaries. Their terms prohibit reverse engineering, and using their implementation details would be the wrong foundation for a commercial product.

Recommended clean-room boundaries:

1. Use only public statements, public docs, patents, academic material, and permissively licensed open-source projects.
2. Keep a research log of every source consulted.
3. Do not decompile, disassemble, inspect strings, trace protocols, or capture RetinaRelay traffic.
4. If using open-source code, only use code with an acceptable license and preserve notices.
5. If we want a closed-source/commercial app, avoid GPL implementation code. Use GPL projects only for high-level public behavior unless counsel says otherwise.
6. TargetBridge is MIT-licensed, so its code is legally easier to use than GPL code, but we should still decide consciously whether to reuse it or independently reimplement.
7. Have one person write high-level design/specs from public docs; have implementation done from Apple docs, our own tests, and permissively licensed references.
8. For patent safety, hire IP counsel for a freedom-to-operate search before selling.

## Patent/IP snapshot

I did not find a RetinaRelay-specific patent by name in public search results. That does not prove none exists; applications can be unpublished for a period, assigned under another legal name, or hard to find by product name.

Relevant patent landscape found:

- Microsoft has an active patent family around cloning/extending a desktop to a wireless display surface using a virtual display driver and remote presentation protocol. Google Patents lists US8839112B2 as active, adjusted expiration 2031-08-04.
- Microsoft also has remote-display compression patents around block-based difference detection/classification in remote display systems. One European family I found is listed active to 2029-10-30.
- Qualcomm had an application around remote multimedia sink devices using texture/geometry compression, but Google Patents lists the US application as abandoned.
- Avatron had a Windows WDDM virtual display driver patent, but Google Patents lists it as expired for fee nonpayment. It is Windows-driver-specific, not macOS `CGVirtualDisplay`.

Practical reading:

- The broad idea “remote extended display” has lots of old prior art.
- The broad idea “compress screen blocks/deltas” has lots of old prior art.
- RetinaRelay’s specific performance trick, GPU block-texture compression plus a second lossless pass for 5K60 over wired links, should be treated as an area needing professional FTO review before commercialization.
- We can reduce risk by designing our own pipeline from first principles and documenting independent development.

## Technical path to our own implementation

### Phase 1: Private virtual display proof

Goal: confirm we can create a 5120x2880 virtual display and capture it.

Scope:

- Developer ID app, not sandboxed for the first spike.
- Runtime lookup for `CGVirtualDisplay*` classes so failures are explicit.
- Advertise exactly the iMac panel modes we care about.
- Verify the display appears in System Settings, accepts windows, supports fullscreen, and emits real 5120x2880 frames through ScreenCaptureKit.

Pass condition:

- Host creates a true 5K desktop with no hardware dongle and ScreenCaptureKit captures real 5K frames.

### Phase 2: Conservative stream

Goal: make it usable before making it special.

Scope:

- ScreenCaptureKit -> VideoToolbox HEVC/H.264 low-latency -> TCP over Thunderbolt Bridge/Ethernet -> Metal/AVSampleBufferDisplayLayer render.
- This should intentionally resemble public open-source patterns at the architecture level, not RetinaRelay’s texture-codec internals.

Pass condition:

- Real 5K extended display works, even if initially 30-48 fps.

### Phase 3: Original high-performance codec

Goal: compete on latency and 5K60.

Possible original directions:

- Tile-based dirty-region detection.
- GPU compute conversion into Apple-supported block-compressed texture formats.
- Adaptive tile quality based on motion and link budget.
- Lossless entropy pass over tile payloads.
- Viewer-side Metal render path that uploads compressed texture blocks directly.
- Separate local cursor plane on the Viewer for perceived pointer smoothness.

Clean-room rule:

- We can study public graphics documentation for texture compression and our own measurements. We should not inspect RetinaRelay’s binary, wire format, or private logs.

### Phase 4: KVM/input layer

RetinaRelay appears not to solve the full KVM input problem. Our product ambition does.

Scope:

- Viewer captures local keyboard/mouse while focused/fullscreen.
- Host posts CGEvents after Accessibility permission.
- Add emergency escape and stuck-key recovery.
- Expect this to increase review/privacy friction; Developer ID remains the realistic path.

## Updated recommendation

Proceed only if we are comfortable with a direct-distribution macOS product using private `CGVirtualDisplay`.

Do not spend more time searching for a public software-only API unless Apple Developer Technical Support gives a new answer. The ecosystem evidence is now strong: the way software-only products do this is private virtual display plus capture/stream/render.

The next useful work is not more abstract planning. It is a tightly scoped proof:

- create 5K virtual display,
- capture real 5K frames,
- stream them over Thunderbolt Bridge,
- render fullscreen on the iMac,
- measure latency and CPU/GPU.

That proof should be implemented from our own code and documented as independent work.

## Sources

- RetinaRelay FAQ: https://retinarelay.com/faq
- RetinaRelay downloads: https://retinarelay.com/downloads
- RetinaRelay changelog: https://retinarelay.com/changelog
- RetinaRelay terms: https://retinarelay.com/terms
- OpenDisplay public docs: https://opendisplay.app/
- OpenAirDisplay/OpenDisplay README excerpt: https://github.com/nmt3325/openairdisplay
- TargetBridge README/license: https://github.com/swellweb/targetBridge
- TargetBridge feature guide: https://github.com/swellweb/targetBridge/blob/main/docs/Features.md
- TargetBridge “How it works”: https://marcocaciotti.it/targetbridge/how-it-works/
- PrimeLab VirtualDisplay API notes: https://github.com/PrimeLab-Foundation/VirtualDisplay/blob/main/docs/platform/macos-virtual-display-apis.md
- Microsoft wireless display patent family: https://patents.google.com/patent/US20120042252A1/en
- Qualcomm remote multimedia sink application: https://patents.google.com/patent/US20150178032A1
- Avatron WDDM virtual display patent: https://patents.google.com/patent/US9058759B2/en
- Microsoft remote display compression family: https://patents.google.com/patent/EP2344957A2/en
