import SwiftUI

@MainActor
let timer = Timer
    .publish(every: 1, on: .main, in: .common)
    .autoconnect()

extension Int {
    func asMinutesAndSeconds() -> String {
        let seconds = self % 60
        let minutes = Int(self / 60)

        return "\(minutes):\(seconds < 10 ? "0" : "")\(seconds)"
    }
}

extension String {
    func fromMinutesAndSeconds() -> Int {
        let trimmed = self.trimmingCharacters(in: .whitespaces)

        // Support both ":" and "." as delimiters for better tvOS experience
        let delimiter: Character
        if trimmed.contains(":") {
            delimiter = ":"
        } else if trimmed.contains(".") {
            delimiter = "."
        } else {
            // No delimiter, treat as seconds only
            guard let seconds = Int(trimmed) else {
                return 0 // Return 0 for invalid input
            }
            return seconds
        }

        let split = trimmed.split(separator: delimiter, omittingEmptySubsequences: false)

        var sum = 0
        if split.count == 2 {
            // Format: MM:SS or MM.SS
            guard let minutes = Int(split[0]), let seconds = Int(split[1]) else {
                return 0 // Return 0 for invalid input
            }
            sum = minutes * 60 + seconds
        } else {
            // Invalid format (e.g., multiple delimiters)
            return 0
        }

        return sum
    }
}

struct ClockTimeText: View {
    private let clockTimeTextFontRatio = CGFloat(4)

    let state: CountdownTimerState

    var body: some View {
        GeometryReader { geometry in
            Text(state.remainingTime().asMinutesAndSeconds())
                .foregroundStyle(.black)
                .font(.system(size: min(geometry.size.width, geometry.size.height)/clockTimeTextFontRatio, weight: .heavy))
                .monospacedDigit()
                .frame(width: geometry.size.width,
                       height: geometry.size.height,
                       alignment: .center)
        }
    }
}

// Glass is tuned for chunky surfaces, not thin strokes, so the tube is thickened
// (smaller ratio = thicker ring) relative to the original 10/14 so it reads as a
// real glass tube on OS 26. The track/tube band (outerCircleRatio) is wider than
// the liquid arc (innerCircleRatio): the narrower liquid is CENTERED on the same
// mid-radius as the tube, so a thin translucent wall margin shows on BOTH edges
// of the liquid all the way around (like the original flat design). The empty
// channel is revealed where the liquid has drained. The glass is faked with thin
// specular RIM highlights on the tube walls (see GlassTubeRim) — never a frost.
private let outerCircleRatio = CGFloat(7)     // tube/track band width = dimension/7
private let innerCircleRatio = CGFloat(8.2)   // liquid arc width = dimension/8.2 (narrower, centered); per-side wall margin ≈ dimension/95. (~quarter margin: 7.6)

/// Whether the running OS VENDS the real Liquid Glass SwiftUI APIs. This reports
/// API availability — true on visionOS 26 too — which is intentionally DISTINCT
/// from "this platform APPLIES glass styling": visionOS opts out of the glass look
/// via `#if !os(visionOS)` (it has its own system glass and Apple marks the
/// container/effect/style symbols unavailable there). So a true result here and the
/// visionOS carve-outs elsewhere are not contradictory: one is about API presence,
/// the other about styling choice. Used for cosmetic tweaks (e.g. icon tint, round
/// vs. butt line caps) that key off the glass appearance rather than a hard #if.
@inline(__always)
func liquidGlassAvailable() -> Bool {
    if #available(iOS 26, macOS 26, tvOS 26, visionOS 26, *) {
        return true
    }
    return false
}

extension CountdownTimerState {
    func trackColor() -> Color {
        if started { return Color.black }
        if complete() { return Color.red }
        return Color.gray
    }

    /// How the empty (drained/elapsed) part of the tube renders. On OS 26 it is a
    /// FAINT LIGHT translucent glassy channel — slightly lighter than the dark
    /// background so the drained tube stays subtly visible all the way around
    /// (across-the-room legibility) instead of melting into the dark bg on the
    /// unlit side. Kept low so it doesn't reintroduce the "too white" look. The
    /// complete()=red case stays a solid, fully-visible alarm color (semantic
    /// intent preserved). Pre-26 keeps the original flat opaque trackColor().
    ///
    /// Tune range: ~0.08 (subtle) … 0.12 (current) … ~0.16 (more visible).
    func emptyTubeColor() -> Color {
        guard liquidGlassAvailable() else { return trackColor() }
        if complete() { return Color.red }
        // Faint light, low-opacity channel: a hair lighter than the dark bg.
        return Color.white.opacity(0.12)
    }

    /// A dark, low-saturation accent that shifts with progress so the gradient
    /// background gives glass surfaces something to refract without hurting
    /// legibility. Green-ish when fresh, warm in the middle, red near the end.
    func backgroundAccent() -> Color {
        guard started || counter > 0 else {
            // Idle: a neutral cool slate.
            return Color(hue: 0.58, saturation: 0.35, brightness: 0.16)
        }
        switch progress() {
            case 0..<(3/4): return Color(hue: 0.36, saturation: 0.40, brightness: 0.15)
            case (3/4)..<(7/8): return Color(hue: 0.09, saturation: 0.50, brightness: 0.17)
            default: return Color(hue: 0.0, saturation: 0.55, brightness: 0.18)
        }
    }
}

/// Dark, state-driven gradient backdrop. Uses plain Linear/RadialGradient which
/// are available on every deployment target, so no availability gate is needed.
struct TimerBackground: View {
    let state: CountdownTimerState

    var body: some View {
        let accent = state.backgroundAccent()
        ZStack {
            Color.black
            RadialGradient(
                gradient: Gradient(colors: [accent, Color.black]),
                center: .center,
                startRadius: 0,
                endRadius: 900
            )
            LinearGradient(
                gradient: Gradient(colors: [accent.opacity(0.45), Color.black.opacity(0.0)]),
                startPoint: .top,
                endPoint: .bottom
            )
        }
        .ignoresSafeArea()
        .animation(.easeInOut(duration: 0.8), value: accent)
    }
}

struct FullCircleTrack: View {
    let state: CountdownTimerState

    var body: some View {
        GeometryReader { geometry in
            let dimension = min(geometry.size.width, geometry.size.height)
            let lineWidth = dimension / outerCircleRatio
            let tube = Circle()
                .inset(by: lineWidth / 2)

            // The empty (drained) tube channel. On OS 26 this is a dark
            // translucent glassy band that lets the background show through, so
            // it reads as a hollow tube rather than a solid gray frame; the
            // colored liquid (ProgressBar) is trimmed over the SAME band on top.
            // Pre-26: the original flat opaque ring (full band, opaque color).
            tube
                .stroke(state.emptyTubeColor(), lineWidth: lineWidth)
                .animation(
                    state.complete() ? .easeInOut(duration: 2.0)
                        : .easeInOut(duration: 0.5),
                    value: state.emptyTubeColor()
                )
        }
    }
}

extension CountdownTimerState {
    func progressColor() -> Color {
        switch self.progress() {
            case 0..<(3/4): return Color.green
            case (3/4)..<(7/8): return Color.orange
            default: return Color.red
        }
    }
}

struct ProgressBar: View {
    let state: CountdownTimerState

    var body: some View {
        GeometryReader { geometry in
            let dimension = min(geometry.size.width, geometry.size.height)
            // On glass, a round line cap reads like a liquid meniscus; on the
            // flat fallback we keep the original butt cap.
            let cap: CGLineCap = liquidGlassAvailable() ? .round : .butt
            // Inset by the TUBE's half-width (outerCircleRatio), NOT the liquid's
            // own, so the narrower liquid (dimension/innerCircleRatio) stays
            // CENTERED on the tube's mid-radius with equal translucent wall margin
            // showing on the outer and inner edges.
            Circle()
                .inset(by: dimension/outerCircleRatio/2)
                .rotation(.degrees(-90))
                .trim(from: CGFloat(state.progress()), to: 1)
                .stroke(
                        style: StrokeStyle(
                            lineWidth: dimension/innerCircleRatio,
                            lineCap: cap
                        )
                )
                .foregroundStyle(state.progressColor())
                .animation(
                    .easeInOut(duration: 0.2),
                    value: state.progress()
                )
        }
    }
}

/// Rounded-glass-TUBE sheen rendered purely with DIRECTIONAL specular highlights
/// over the vivid liquid (OS 26 only). No system glass material is used here —
/// the real `.glassEffect(.regular)` frosts/greys the liquid even as a thin ring,
/// so the tube is faked with light: a single coherent light source in the UPPER-
/// LEFT (~10:30 o'clock) puts a bright glint on the upper-left walls fading to
/// near-transparent elsewhere, a subtle secondary reflection on the lower-right,
/// and a dark inner-shadow rim concentrated OPPOSITE the light (lower-right) for
/// roundness. The angular gradients keep the sheen from reading as a uniform
/// white painted ring. Light direction is FIXED (does not rotate with progress).
/// No-op on older OSes (the flat ring carries the look there).
///
/// AngularGradient: 0° is at 3 o'clock and increases clockwise, so the upper-left
/// light sits at ~225° (10:30) and the lower-right shadow/secondary at ~45°.
struct GlassTubeRim: View {
    let state: CountdownTimerState

    // One coherent light source, fixed.
    private let lightAngle: Double = 225   // upper-left (~10:30 o'clock)
    private let shadowAngle: Double = 45   // lower-right (~4:30 o'clock), opposite

    /// A directional specular gradient: bright `peak` glint over a ~80° arc near
    /// the light, a dim `secondary` reflection opposite, ~transparent elsewhere.
    private func sheenGradient(peak: Double, secondary: Double) -> AngularGradient {
        let lit = Color.white
        let dark = Color.white.opacity(0.0)
        return AngularGradient(
            gradient: Gradient(stops: [
                .init(color: dark,                       location: 0.00),
                .init(color: lit.opacity(secondary),     location: 0.125),  // 45°  lower-right glint
                .init(color: dark,                       location: 0.25),
                .init(color: dark,                       location: 0.52),
                .init(color: lit.opacity(peak),          location: 0.625),  // 225° upper-left main glint
                .init(color: dark,                       location: 0.73),
                .init(color: dark,                       location: 1.00),
            ]),
            center: .center,
            angle: .degrees(0)
        )
    }

    /// Directional shadow: darkest at the lower-right (opposite the light),
    /// fading to nothing toward the lit side.
    private func shadowGradient(peak: Double) -> AngularGradient {
        let shade = Color.black
        let clear = Color.black.opacity(0.0)
        return AngularGradient(
            gradient: Gradient(stops: [
                .init(color: clear,                  location: 0.00),
                .init(color: shade.opacity(peak),    location: 0.125),  // 45° lower-right
                .init(color: clear,                  location: 0.27),
                .init(color: clear,                  location: 1.00),
            ]),
            center: .center,
            angle: .degrees(0)
        )
    }

    var body: some View {
        GeometryReader { geometry in
            let dimension = min(geometry.size.width, geometry.size.height)
            let lineWidth = dimension / outerCircleRatio
            // Radii of the tube's outer and inner walls (the rim edges).
            let outerInset = lineWidth / 2 * 0.30   // just inside the outer edge
            let innerInset = lineWidth - lineWidth / 2 * 0.30
            // Thin rim strokes — a fraction of the tube width so the color shows.
            let rimWidth = max(1, lineWidth * 0.16)

            if #available(iOS 26, macOS 26, tvOS 26, visionOS 26, *) {
                ZStack {
                    // Dark inner-shadow rim, concentrated on the lower-right
                    // (opposite the light) for a directional 3D edge.
                    Circle()
                        .inset(by: outerInset + rimWidth)
                        .stroke(shadowGradient(peak: 0.22), lineWidth: rimWidth)
                        .blur(radius: rimWidth * 0.6)

                    // Main light catch on the OUTER wall — bright in the upper-left,
                    // fading to transparent around the rest of the ring.
                    Circle()
                        .inset(by: outerInset)
                        .stroke(sheenGradient(peak: 0.55, secondary: 0.12),
                                lineWidth: rimWidth)
                        .blur(radius: rimWidth * 0.45)

                    // Softer directional highlight on the INNER wall.
                    Circle()
                        .inset(by: innerInset)
                        .stroke(sheenGradient(peak: 0.28, secondary: 0.06),
                                lineWidth: rimWidth)
                        .blur(radius: rimWidth * 0.45)
                }
            }
        }
        .allowsHitTesting(false)
    }
}

/// Fully-opaque white face disc behind the digits, so the dark gradient
/// background cannot bloom through around the numbers. Sized to sit just inside
/// the inner tube wall.
struct ClockFace: View {
    var body: some View {
        GeometryReader { geometry in
            let dimension = min(geometry.size.width, geometry.size.height)
            let lineWidth = dimension / outerCircleRatio
            Circle()
                .inset(by: lineWidth)            // inside the inner tube wall
                .fill(Color.white)               // solid, opaque — no translucency
                .frame(minWidth: 0, maxWidth: .infinity,
                       minHeight: 0, maxHeight: .infinity,
                       alignment: .center)
        }
        .allowsHitTesting(false)
    }
}

struct ClockStack: View {
    let state: CountdownTimerState

    var body: some View {
        ZStack {
            FullCircleTrack(state: state)   // empty-tube channel band (dark translucent on OS 26)
            ProgressBar(state: state)        // VIVID colored liquid — drawn ON TOP, never frosted
            GlassTubeRim(state: state)       // specular wall highlights (light-only, no glass material), over the liquid (OS 26)
            ClockFace()                      // opaque face disc: kills background bleed behind digits
            ClockTimeText(state: state)      // black digits on white, readable
        }
    }
}

#Preview("ClockStack") {
    ClockStack(state: CountdownTimerState(started: false, counter: 120, countTo: 180))
        .frame(width: 120.0, height: 120.0)
}

extension View {
    /// Applies the Liquid Glass button style on OS 26, falling back to the
    /// original `.borderless` style on older OSes. `prominent` selects the
    /// `.glassProminent` style for the primary action; `tint` colors the
    /// prominent glass fill so it agrees with the button's semantic icon (e.g.
    /// green Start). The tint is ignored on the non-prominent `.glass` style and
    /// on the borderless fallback.
    ///
    /// visionOS is carved out with `#if !os(visionOS)`: Apple does not vend the
    /// `.glass`/`.glassProminent` button styles there even on the visionOS 26 SDK
    /// (they are marked unavailable — visionOS has its own system glass), so the
    /// `visionOS 26` availability clause alone would not compile. visionOS always
    /// takes the `.borderless` fallback.
    @ViewBuilder
    func timerButtonStyle(prominent: Bool = false, tint: Color? = nil) -> some View {
#if !os(visionOS)
        if #available(iOS 26, macOS 26, tvOS 26, *) {
            if prominent {
                self.buttonStyle(.glassProminent)
                    .tint(tint)
            } else {
                self.buttonStyle(.glass)
            }
        } else {
            self.buttonStyle(.borderless)
        }
#else
        self.buttonStyle(.borderless)
#endif
    }

    /// Liquid Glass card surface on OS 26, frosted material otherwise. visionOS is
    /// carved out with `#if !os(visionOS)` because `GlassEffectContainer` and
    /// `glassEffect(_:in:)` are unavailable there even on the visionOS 26 SDK
    /// (visionOS has its own system glass). Callers add their own padding BEFORE
    /// calling this; the helper only wraps the surface. The GlassEffectContainer
    /// also merges any glass children (e.g. the buttons on the card) on OS 26.
    @ViewBuilder
    func glassCardSurface(in shape: some Shape) -> some View {
#if !os(visionOS)
        if #available(iOS 26, macOS 26, tvOS 26, *) {
            GlassEffectContainer { self.glassEffect(.regular, in: shape) }
        } else {
            self.background(.regularMaterial, in: shape)
        }
#else
        self.background(.regularMaterial, in: shape)
#endif
    }
}

struct SettingsButton: View {
    var height: CGFloat
    let state: CountdownTimerState
    var onWake: () -> Void = {}
    @State private var showSheet = false

    var body: some View {
        VStack(alignment: .leading, spacing: height/32) {
            Button(action: {
                onWake()
                showSheet = true
            }, label: {
                Label("Duration", systemImage: "timer")
                    .font(.system(size: height/16, weight: .medium))
                    .foregroundStyle(Color.primary)
                    .labelStyle(.titleAndIcon(iconColor: Color.secondary))
            })
            .timerButtonStyle()
#if os(visionOS)
            .hoverEffect()
#endif
        }
        .sheet(isPresented: $showSheet) {
            SettingsSheetView(isVisible: $showSheet, state: state)
        }
    }
}

struct ResetButton: View {
    var height: CGFloat
    let state: CountdownTimerState
    var onWake: () -> Void = {}

    var body: some View {
        Button(action: {
            onWake()
            state.reset()
        }, label: {
            Label("Reset", systemImage: "arrow.counterclockwise")
                .font(.system(size: height/16, weight: .medium))
                .foregroundStyle(Color.primary)
                .labelStyle(.titleAndIcon(iconColor: .red))
        })
        .timerButtonStyle()
#if os(visionOS)
        .hoverEffect()
#endif
    }
}

struct StartOrStopButton: View {
    var height: CGFloat
    let state: CountdownTimerState
    var onWake: () -> Void = {}

    private var label: String {
        state.started ? "Pause" : (state.counter < state.countTo ? "Start" : "Restart")
    }

    private var systemImage: String {
        state.started ? "pause.fill" : (state.counter < state.countTo ? "play.fill" : "arrow.clockwise")
    }

    var body: some View {
        // On OS 26 the prominent button fills green, so the play/pause icon is
        // tinted Color.primary (white) to stay legible on the green glass;
        // semantic green moves to the fill. On the borderless fallback the icon
        // keeps its green semantic tint as before.
        let iconColor: Color = liquidGlassAvailable() ? Color.primary : .green
        return Button(action: {
            onWake()
            state.startOrStop()
        }, label: {
            ZStack(alignment: .leading) {
                Label("Restart", systemImage: "arrow.clockwise")
                    .font(.system(size: height/16, weight: .medium))
                    .labelStyle(.titleAndIcon(iconColor: iconColor))
                    .hidden()

                Label(label, systemImage: systemImage)
                    .font(.system(size: height/16, weight: .medium))
                    .foregroundStyle(Color.primary)
                    .labelStyle(.titleAndIcon(iconColor: iconColor))
                    .contentTransition(.symbolEffect(.replace))
            }
        })
        .timerButtonStyle(prominent: true, tint: .green)
#if os(visionOS)
        .hoverEffect()
#endif
    }
}

private struct TitleAndIconLabelStyle: LabelStyle {
    let iconColor: Color

    func makeBody(configuration: Configuration) -> some View {
        HStack(spacing: 4) {
            configuration.icon
                .foregroundStyle(iconColor)
            configuration.title
                .foregroundStyle(Color.primary)
        }
    }
}

extension LabelStyle where Self == TitleAndIconLabelStyle {
    static func titleAndIcon(iconColor: Color) -> TitleAndIconLabelStyle {
        TitleAndIconLabelStyle(iconColor: iconColor)
    }
}

struct CountdownView: View {
    let state: CountdownTimerState
    @State var editing = true
    @State private var lastInteraction: Date = .now
    @State private var isDimmed: Bool = false

    private func wakeUp() {
        lastInteraction = .now
        if isDimmed {
            withAnimation(.easeOut(duration: 0.3)) {
                isDimmed = false
            }
        }
    }

    @ViewBuilder
    private func controlButtons(height: CGFloat) -> some View {
        SettingsButton(height: height, state: state, onWake: wakeUp)
        ResetButton(height: height, state: state, onWake: wakeUp)
        StartOrStopButton(height: height, state: state, onWake: wakeUp)
    }

    @ViewBuilder
    private func controlCard(height: CGFloat, width: CGFloat, cornerRadius: CGFloat) -> some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius)
        // Card chrome via the shared `glassCardSurface` helper: real Liquid Glass
        // inside a GlassEffectContainer on OS 26 (which also merges the glass
        // buttons inside), frosted material as the pre-26 / visionOS fallback.
        VStack(alignment: .leading, spacing: height/32) {
            controlButtons(height: height)
        }
        .padding(.all, width/64)
        .glassCardSurface(in: shape)
    }

    var body: some View {
        GeometryReader { geometry in
            let cornerRadius = geometry.size.width / 64
            let content = HStack {
                ClockStack(state: state)
                    .onReceive(timer) { date in
                        Task { @MainActor in
                            state.tickIfStarted(date)
                            if state.started && Date.now.timeIntervalSince(lastInteraction) > 5 {
                                if !isDimmed {
                                    withAnimation(.easeIn(duration: 0.5)) {
                                        isDimmed = true
                                    }
                                }
                            } else if !state.started {
                                isDimmed = false
                            }
                        }
                    }
                    .padding(.vertical)

                controlCard(height: geometry.size.height,
                            width: geometry.size.width,
                            cornerRadius: cornerRadius)
                    .opacity(isDimmed ? 0.25 : 1.0)

                Spacer(minLength: geometry.size.width/64)
            }
            .background(TimerBackground(state: state))
#if os(macOS)
            content
                .onContinuousHover { phase in
                    if case .active = phase {
                        wakeUp()
                    }
                }
#elseif os(tvOS)
            content
                .onMoveCommand { _ in wakeUp() }
                .onPlayPauseCommand { wakeUp() }
#else
            content
                .simultaneousGesture(TapGesture().onEnded { wakeUp() })
#endif
        }
    }
}

#Preview("CountdownView") {
    CountdownView(state: CountdownTimerState(started: true, countTo: 10))
        .frame(width: 480, height: 320)
}
