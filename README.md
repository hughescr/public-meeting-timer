# Public Meeting Timer

A large, across-the-room countdown timer for public meetings — a speaker / agenda
clock that shows how much time a presenter has left at a glance. The remaining
time is drawn as big monospaced digits inside a circular "liquid tube" progress
ring that drains as the clock counts down, so the room can read it from a distance.

Set a duration (e.g. 3 minutes per speaker), start it, and the ring drains from
full to empty; it turns red when time is up. While the timer runs the device is
kept awake (idle/display sleep is suppressed).

## Supported platforms

A single SwiftUI codebase ships to four platforms:

- **iOS / iPadOS** — `Public Meeting Timer iOS` scheme.
- **macOS** — `Public Meeting Timer` scheme; launches full-screen with a hidden
  title bar, and supports keyboard shortcuts (Space/Return to start-or-stop,
  Esc/Delete to reset).
- **tvOS** — for running the clock on a big screen via Apple TV.
- **visionOS** — runs in the Vision Pro shared space.

## Building

Open `Public Meeting Timer.xcodeproj` in Xcode and pick the target platform, or
build from the command line, e.g.:

```sh
# macOS
xcodebuild -scheme "Public Meeting Timer" -destination 'platform=macOS' build

# iOS / tvOS / visionOS (pick a simulator)
xcodebuild -scheme "Public Meeting Timer iOS" \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build
```

## Design notes

- **Liquid Glass, availability-gated.** On OS 26 (iOS/macOS/tvOS 26) the control
  card and buttons use the real Liquid Glass APIs (`GlassEffectContainer`,
  `glassEffect`, `.glass` / `.glassProminent`). Older OSes fall back to a
  `.regularMaterial` frosted surface, so the layout is identical and only the
  surface treatment differs. visionOS is deliberately excluded from the glass
  APIs (it has its own system glass — see `CLAUDE.md`) and also takes the
  material fallback.
- **The progress ring is faked glass, not a frost.** The drained tube is a faint
  translucent channel and the "glass" is thin specular rim highlights on the tube
  walls, never a blurred material over thin strokes (which reads poorly). The
  vivid colored "liquid" is always drawn on top, un-frosted, for legibility.
- **Per-platform duration input.** Entering a duration forks by platform: macOS
  uses a free-text field with validation (real keyboard); iOS/visionOS use a
  `.wheel` minutes:seconds picker; tvOS uses a custom focusable +/- selector
  (no usable inline spinner exists there). All paths enforce the same duration
  range, `0:00 < t ≤ 99:59`.
- **Stable digit sizing.** The countdown digits are sized from the widest
  canonical readout (`00:00`) rather than the live string, so they don't jump in
  size as the minutes digit count changes while counting down.
