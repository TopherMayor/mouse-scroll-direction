# Mouse Scroll Direction

A minimal macOS menu-bar utility that reverses scrolling for a mouse while leaving the built-in trackpad's natural scrolling unchanged.

It is intentionally narrower than Mos and Scroll Reverser:

- one Quartz scroll event tap
- no smoothing or synthetic events
- no per-app profiles
- no button remapping
- no third-party runtime dependencies
- ambiguous continuous events are left untouched

The default policy is mouse reversed, trackpad unchanged.

## Requirements

- macOS 13 or later
- Swift 6 toolchain / Xcode Command Line Tools
- Accessibility permission for the executable

## Build and run

```bash
swift build -c release --product MouseScrollDirection
.build/arm64-apple-macosx/release/MouseScrollDirection
```

On first launch, grant Accessibility permission in **System Settings → Privacy & Security → Accessibility**. The current executable is a development build and should be launched from a terminal; packaging and Login Items support are intentionally separate follow-up work.

## Validate the policy

The host currently has Command Line Tools but not full Xcode, so the project uses a dependency-free validation executable instead of XCTest:

```bash
swift run ScrollPolicyValidation
```

## Design

Ordinary wheel mice normally emit non-continuous scroll events. Trackpads emit continuous events and usually carry phase, momentum, or scroll-count metadata. The pure policy layer classifies those events and reverses both scroll axes only for mouse events.

The event tap rewrites the fixed-point and integer scroll delta fields in-place and passes the same event onward. It does not create replacement events.

## Status

This is an MVP for real-device validation. Before calling it production-ready, test sleep/wake, Accessibility permission revocation, trackpad momentum, horizontal scrolling, Logitech G402 input, and event-tap timeout recovery.
