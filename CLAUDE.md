# CLAUDE.md

Durable design decisions for this repo (a multi-platform SwiftUI countdown timer
for public meetings). These are captured here so the rationale lives somewhere
more findable than inline comments. Keep changes consistent with them.

## OS-26 Liquid Glass availability-gating

The control card (`controlCard()` in `Timer.swift`), the settings sheet card
(`cardStack` in `Settings.swift`), and the control buttons opt into Apple's
Liquid Glass on OS 26 and fall back to `.regularMaterial` on older OSes:

- Card surfaces go through one shared helper, `View.glassCardSurface(in:)` in
  `Timer.swift`. On OS 26 it wraps the content in a `GlassEffectContainer` and
  applies `.glassEffect(.regular, in: shape)`; otherwise `.background(.regularMaterial,
  in: shape)`. Both call sites add their own padding BEFORE calling it.
- Buttons go through `View.timerButtonStyle(prominent:tint:)` in `Timer.swift`:
  `.glass` / `.glassProminent` on OS 26, `.borderless` otherwise.
- `liquidGlassAvailable()` reports whether the OS *vends* the glass APIs and is
  used only for cosmetic tweaks (icon tint, line-cap style) that key off the
  glass *appearance*. It is intentionally distinct from whether a platform
  *applies* glass styling (see visionOS below).

Keep the gating availability clauses and the `#if` carve-out in sync if either is
touched — the `if #available(...)` and the `#if !os(visionOS)` are doing two
different jobs.

## visionOS is DELIBERATELY excluded from the glass APIs

The glass symbols — `GlassEffectContainer`, `glassEffect(_:in:)`, and the
`.glass` / `.glassProminent` button styles — are marked *unavailable* on the
visionOS SDK, even behind a `visionOS 26` availability clause. visionOS has its
own system glass and Apple does not expose these. So a `#available(..., visionOS
26, *)` clause alone does NOT make them compile on visionOS.

Therefore every glass code path is fenced with `#if !os(visionOS)` and visionOS
always takes the `.regularMaterial` fallback branch. This is why
`liquidGlassAvailable()` can return `true` on visionOS 26 (the APIs *exist* in the
sense the function checks) while the styling code still excludes visionOS — the
two are not contradictory.

## Per-platform reset-duration input fork

The "reset timer to" sheet (`SettingsSheetView` in `Settings.swift`) forks its
input by platform, and each path owns only the `@State` it writes (fenced by
`#if`):

- **macOS** — a free-text `TextField` with `validateAndApplyDuration()`. There's a
  real keyboard, so typing the time beats spinning a wheel. Accepts `MM:SS`,
  `MM.SS`, or `SSS`; selects-all on focus so typing replaces the seeded value.
- **iOS / visionOS** — a `.wheel` minutes:seconds `Picker`. A text field would
  summon the on-screen / pop-over keyboard; the wheel keeps the value well-formed
  with no validation needed.
- **tvOS** — a custom focusable minutes:seconds selector built from `Button`s.
  tvOS has no usable inline number spinner (`.wheel` and `Stepper` don't exist,
  the default `Picker` is a cramped carousel). Minutes clamp at the bounds;
  seconds wrap, as is conventional for a seconds dial.

## tvOS app icon is a separate `AppIcon.brandassets`

iOS/tvOS/visionOS share one target with a single `ASSETCATALOG_COMPILER_APPICON_NAME
= AppIcon`. Two independent art sources both intentionally carry the name
"AppIcon" and the asset catalog resolves the right one per idiom:

- `AppIcon.icon` (Icon Composer, at the project root) serves iOS/macOS/visionOS.
- `AppIcon.brandassets` (in `Assets.xcassets`) provides the tvOS layered icon
  (front/back imagestack layers) plus the Top Shelf images.

These are INDEPENDENT art sources — there is no shared master they're derived
from at build time — so they **must be kept visually in sync by hand**. If you
change the app icon, regenerate `AppIcon.brandassets` to match.

## Cold-launch splash

An in-app animated `SplashView` (in `Public_Meeting_TimerApp.swift`) plays over
the live timer on cold (process) launch ONLY. It is gated by an app-lifetime
`@State` flag on the `@main App` struct (passed down to `RootView` as a
`Binding`), deliberately NOT keyed to `scenePhase`, so it survives
background→foreground and does NOT replay when a scene is reconstructed (macOS
window reopen, future multi-window). It is skippable — tap/click on iOS/macOS,
play-pause / menu on tvOS (the Siri remote can't tap a non-focusable overlay) —
and honors Reduce Motion (static brand frame, plain cross-fade hand-off, no
scale, near-instant dismiss). An auto-dismiss timeout guarantees it can never
hang, and is cancelled on teardown so an early skip retains no work.

## Launch-screen strategy

The iOS static launch screen (`UILaunchScreen` in `iOS Info.plist`) is a flat
dark `LaunchBackground` color with NO launch image. The previous launch image
was removed because it mis-sized on iPad and caused a white-mode flash; the dark
static frame now hands off seamlessly into the animated `SplashView`. (This is
why `LaunchScreenText.imageset` was deleted.)

## Duration range invariant: `0:00 < t ≤ 99:59`

The reset duration must be strictly positive and at most 99 minutes 59 seconds.
A zero/negative target would divide-by-zero in `CountdownTimerState.progress()`
(guarded to return 0) and leave nothing to count down. The invariant is enforced
on BOTH input paths so values round-trip identically:

- Pickers cap at `0...99` minutes and `0...59` seconds, and the **Set** button is
  disabled at `0:00`.
- The macOS validator rejects a zero total, seconds `> 59`, minutes `> 99`, and a
  seconds-only value exceeding `99:59`.
- `onAppear` seeds the pickers with `min(99, countTo / 60)` so an out-of-range
  persisted value can't seed an invalid picker.
