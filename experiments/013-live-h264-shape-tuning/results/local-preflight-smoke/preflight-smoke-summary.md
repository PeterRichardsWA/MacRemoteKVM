# Experiment 013 Local Preflight Smoke

Purpose: verify the TCP preflight handshake added after the first wired
Ethernet run.

Run mode: local loopback on MacBookPro18,2, 1 second.

- Sender network preflight: passed before capture/timed sender window.
- Sender preflight round trip: 0.112 ms.
- Receiver preflight: passed before stream config and receiver timing.
- Receiver preflight handling time: 0.007 ms.
- Sender: 57 frames sent, 56.08 FPS, zero encode/write errors.
- Receiver: 57 frames received, 57 frames rendered, zero decode/render errors.

Conclusion: the updated harness proves network permission prompts can be handled
before the timed live sender window starts.
