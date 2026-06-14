//
//  Public_Meeting_TimerApp.swift
//  Public Meeting Timer
//
//  Created by Craig Hughes on 12/14/20.
//

import SwiftUI

let savedDurationKey = "Countdown duration"

@main
struct PublicMeetingTimerApp: App {
    @AppStorage(savedDurationKey) private var savedDuration = 180
    @State private var state: CountdownTimerState

    /// Has the cold-launch splash already played THIS process? App-lifetime
    /// `@State`, so it persists for the life of the process across scene
    /// recreation (e.g. macOS closing and reopening the window, or future
    /// multi-window) — the splash plays once per cold (process) launch and does
    /// NOT replay on scene reopen. NOT `@AppStorage`/UserDefaults: that would
    /// make it play only once EVER across launches, which is the wrong behavior.
    @State private var hasShownSplash = false

    init() {
        let duration = UserDefaults.standard.integer(forKey: savedDurationKey)
        _state = State(initialValue: CountdownTimerState(countTo: duration != 0 ? duration : 180))
    }

    var body: some Scene {
#if os(macOS)
        Window("Public Meeting Timer", id: "main") {
            content
        }
        .windowStyle(.hiddenTitleBar)
#else
        WindowGroup {
            content
        }
#endif
    }

    private var content: some View {
        RootView(state: state, hasShownSplash: $hasShownSplash)
            .onChange(of: state.countTo) { _, newValue in
                savedDuration = newValue
            }
#if os(macOS)
            .background {
                Group {
                    Button("") { state.reset() }
                        .keyboardShortcut(.escape, modifiers: [])
                    Button("") { state.reset() }
                        .keyboardShortcut(.delete, modifiers: [])
                    Button("") { state.startOrStop() }
                        .keyboardShortcut(.space, modifiers: [])
                    Button("") { state.startOrStop() }
                        .keyboardShortcut(.return, modifiers: [])
                }
                .opacity(0)
            }
            .onAppear {
                Task { @MainActor in
                    if let window = NSApp.windows.first,
                       !window.styleMask.contains(.fullScreen) {
                        window.toggleFullScreen(nil)
                    }
                }
            }
#endif
    }
}

/// Root of the scene: hosts the live `CountdownView` and, on COLD launch only,
/// overlays the animated `SplashView` brand moment on top of it.
///
/// Cold-launch-only: the "has the splash shown this process" flag lives on the
/// `@main App` struct as app-lifetime `@State` and is passed down here as a
/// `Binding`. Because it persists for the life of the PROCESS (not the scene),
/// the splash plays once per cold launch and is NOT re-triggered when a scene is
/// reconstructed — e.g. macOS closing and reopening the window, future
/// multi-window, or a background→foreground resume (we intentionally do not key
/// it off `scenePhase`).
struct RootView: View {
    let state: CountdownTimerState
    @Binding var hasShownSplash: Bool

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var showSplash = false

    var body: some View {
        ZStack {
            CountdownView(state: state)
                .background(Color.black.ignoresSafeArea())

            if showSplash {
                SplashView(state: state) {
                    // Hand-off to the timer. Under Reduce Motion, drop the scale
                    // and the 0.45s ease — a plain near-instant cross-fade — since
                    // the scale-up is exactly the motion Reduce Motion removes.
                    if reduceMotion {
                        withAnimation(.linear(duration: 0.05)) {
                            showSplash = false
                        }
                    } else {
                        withAnimation(.easeInOut(duration: 0.45)) {
                            showSplash = false
                        }
                    }
                }
                // Fade + slight scale-up as the splash hands off to the timer;
                // Reduce Motion collapses this to a plain opacity transition.
                .transition(reduceMotion
                    ? AnyTransition.opacity
                    : .opacity.combined(with: .scale(scale: 1.06)))
                .zIndex(1)
            }
        }
        .onAppear {
            // Show the splash exactly once per process launch.
            if !hasShownSplash {
                showSplash = true
                hasShownSplash = true
            }
        }
    }
}

/// Animated brand splash, in the Liquid Glass vocabulary. Reuses
/// `TimerBackground` as the dark backdrop and draws the green timer arc in
/// (echoing `ProgressBar`/`outerCircleRatio` proportions) while the app title
/// resolves in with a fade + slight scale and a subtle specular shimmer sweeps
/// the arc. Plays for ~1.2s then calls `onFinish`; it is skippable per platform:
/// a tap/click on iOS/macOS, or play-pause / menu on tvOS (the Siri remote does
/// not deliver taps to a non-focusable overlay, so tvOS uses remote commands).
/// Honors Reduce Motion by showing a static brand frame and dismissing
/// near-instantly. The auto-dismiss timeout is cancelled on teardown so an early
/// skip leaves no retained work.
struct SplashView: View {
    let state: CountdownTimerState
    let onFinish: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    // Brand emblem locks to the SAME proportions as the live clock — these are
    // the module-visible `outerCircleRatio`/`innerCircleRatio` from Timer.swift,
    // referenced (not re-declared) so the mark tracks the clock geometry.

    @State private var arcProgress: CGFloat = 0   // 0…1 trim of the sweeping arc
    @State private var titleOpacity: Double = 0
    @State private var titleScale: CGFloat = 0.92
    @State private var shimmer: CGFloat = -1       // specular highlight position
    @State private var didFinish = false
    @State private var timeoutTask: Task<Void, Never>?

    private func finishOnce() {
        guard !didFinish else { return }
        didFinish = true
        onFinish()
    }

    var body: some View {
        GeometryReader { geometry in
            let dimension = min(geometry.size.width, geometry.size.height)
            // A brand emblem a bit smaller than the live clock so it feels like a
            // self-contained mark; the arc width tracks outerCircleRatio.
            let emblem = dimension * 0.42
            let lineWidth = emblem / outerCircleRatio
            let liquidWidth = emblem / innerCircleRatio
            let cap: CGLineCap = liquidGlassAvailable() ? .round : .butt

            ZStack {
                TimerBackground(state: state)

                ZStack {
                    // Faint full track, so the arc has a glassy channel to fill.
                    Circle()
                        .inset(by: lineWidth / 2)
                        .stroke(Color.white.opacity(0.10), lineWidth: lineWidth)

                    // The green liquid arc sweeping/drawing in. Intentionally the
                    // fixed Color.green "fresh/full" brand color, NOT the
                    // state-driven progressColor() — this is a brand moment, not a
                    // live readout, so it always reads as a full, healthy clock.
                    Circle()
                        .inset(by: lineWidth / 2)
                        .rotation(.degrees(-90))
                        .trim(from: 0, to: arcProgress)
                        .stroke(
                            Color.green,
                            style: StrokeStyle(lineWidth: liquidWidth, lineCap: cap)
                        )

                    // Subtle specular glint travelling ALONG the emblem's arc: a
                    // narrow .screen-blended LinearGradient band swept horizontally
                    // and CLIPPED to the stationary drawn arc — so the highlight
                    // glides along the arc rather than the whole ring sliding
                    // off-center. The .offset moves the band (the masked content);
                    // the arc mask stays put. In the SPIRIT of GlassTubeRim's
                    // light-only sheen, but not the same technique (GlassTubeRim
                    // uses an AngularGradient specular rim). Skipped under Reduce
                    // Motion.
                    if !reduceMotion {
                        Rectangle()
                            .fill(
                                LinearGradient(
                                    colors: [
                                        Color.white.opacity(0.0),
                                        Color.white.opacity(0.55),
                                        Color.white.opacity(0.0)
                                    ],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .frame(width: emblem * 0.5)            // a narrow band, not the whole width
                            .offset(x: shimmer * emblem * 0.9)     // sweep left → right under the mask
                            .frame(width: emblem, height: emblem)  // re-center the band within the emblem box
                            .mask(
                                Circle()
                                    .inset(by: lineWidth / 2)
                                    .trim(from: 0, to: arcProgress)
                                    .rotation(.degrees(-90))
                                    .stroke(style: StrokeStyle(lineWidth: liquidWidth, lineCap: cap))
                            )
                            .blendMode(.screen)
                            .blur(radius: liquidWidth * 0.4)
                            .allowsHitTesting(false)
                    }
                }
                .frame(width: emblem, height: emblem)

                // App title resolving in (fade + slight scale), heavy monospaced
                // type consistent with ClockTimeText.
                Text("Public Meeting Timer")
                    .font(.system(size: dimension * 0.055, weight: .heavy, design: .rounded))
                    .monospaced()
                    .foregroundStyle(.white)
                    .opacity(titleOpacity)
                    .scaleEffect(titleScale)
                    .offset(y: emblem * 0.5 + dimension * 0.06)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }
            .frame(width: geometry.size.width, height: geometry.size.height)
        }
        .ignoresSafeArea()
        .contentShape(Rectangle())
        // Skip the intro. On iOS/macOS a tap/click anywhere works (the overlay
        // receives touches/clicks). tvOS is different: the Siri remote doesn't
        // deliver taps to a non-focusable overlay, so it's driven by remote
        // commands instead — play-pause or menu — mirroring how the timer is
        // driven on tvOS (see Timer.swift's .onPlayPauseCommand/.onMoveCommand).
        .onTapGesture { finishOnce() }
#if os(tvOS)
        .onPlayPauseCommand { finishOnce() }
        .onExitCommand { finishOnce() }
#endif
        .accessibilityAddTraits(.isButton)
        .accessibilityLabel("Skip intro")
        .onAppear { runAnimation() }
        // Cancel the auto-dismiss timeout if we're torn down early (e.g. skipped),
        // so no retained sleep keeps running after the splash is gone.
        .onDisappear { timeoutTask?.cancel() }
    }

    private func runAnimation() {
        if reduceMotion {
            // Static brand frame, dismissed near-instantly.
            arcProgress = 1
            titleOpacity = 1
            titleScale = 1
            timeoutTask = Task { @MainActor in
                try? await Task.sleep(nanoseconds: 350_000_000)
                guard !Task.isCancelled else { return }
                finishOnce()
            }
            return
        }

        withAnimation(.easeInOut(duration: 0.85)) {
            arcProgress = 1
        }
        withAnimation(.easeOut(duration: 0.6).delay(0.35)) {
            titleOpacity = 1
            titleScale = 1.0
        }
        withAnimation(.easeInOut(duration: 0.9).delay(0.25)) {
            shimmer = 1
        }

        // Auto-dismiss timeout so the splash can never get stuck (~1.2s).
        // Stored so .onDisappear can cancel it on an early skip; we also bail if
        // it was cancelled before the sleep returned.
        timeoutTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 1_200_000_000)
            guard !Task.isCancelled else { return }
            finishOnce()
        }
    }
}
