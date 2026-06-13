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

private let outerCircleRatio = CGFloat(10)
private let innerCircleRatio = CGFloat(14)

extension CountdownTimerState {
    func trackColor() -> Color {
        if started { return Color.black }
        if complete() { return Color.red }
        return Color.gray
    }
}

struct FullCircleTrack: View {
    let state: CountdownTimerState

    var body: some View {
        GeometryReader { geometry in
            Circle()
                .fill(Color.white)
                .frame(minWidth: 0, maxWidth: .infinity,
                       minHeight: 0, maxHeight: .infinity,
                       alignment: .center)
                .overlay(
                    Circle()
                        .inset(by: min(geometry.size.width, geometry.size.height)/outerCircleRatio/2)
                        .stroke(state.trackColor(),
                                lineWidth: min(geometry.size.width, geometry.size.height)/outerCircleRatio)
                        .animation(
                            state.complete() ? .easeInOut(duration: 2.0)
                                : .easeInOut(duration: 0.5),
                            value: state.trackColor()
                        )
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
            Circle()
                .inset(by: min(geometry.size.width, geometry.size.height)/outerCircleRatio/2)
                .rotation(.degrees(-90))
                .trim(from: CGFloat(state.progress()), to: 1)
                .stroke(
                        style: StrokeStyle(
                            lineWidth: min(geometry.size.width, geometry.size.height)/innerCircleRatio,
                            lineCap: .butt
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

struct ClockStack: View {
    let state: CountdownTimerState

    var body: some View {
        ZStack {
            FullCircleTrack(state: state)
            ProgressBar(state: state)
            ClockTimeText(state: state)
        }
    }
}

#Preview("ClockStack") {
    ClockStack(state: CountdownTimerState(started: false, counter: 120, countTo: 180))
        .frame(width: 120.0, height: 120.0)
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
            .buttonStyle(.borderless)
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
        .buttonStyle(.borderless)
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
        Button(action: {
            onWake()
            state.startOrStop()
        }, label: {
            ZStack(alignment: .leading) {
                Label("Restart", systemImage: "arrow.clockwise")
                    .font(.system(size: height/16, weight: .medium))
                    .labelStyle(.titleAndIcon(iconColor: .green))
                    .hidden()

                Label(label, systemImage: systemImage)
                    .font(.system(size: height/16, weight: .medium))
                    .foregroundStyle(Color.primary)
                    .labelStyle(.titleAndIcon(iconColor: .green))
                    .contentTransition(.symbolEffect(.replace))
            }
        })
        .buttonStyle(.borderless)
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

                VStack(alignment: .leading, spacing: geometry.size.height/32) {
                    SettingsButton(height: geometry.size.height, state: state, onWake: wakeUp)

                    ResetButton(height: geometry.size.height, state: state, onWake: wakeUp)

                    StartOrStopButton(height: geometry.size.height, state: state, onWake: wakeUp)
                }
                .padding(.all, geometry.size.width/64)
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: cornerRadius))
                .opacity(isDimmed ? 0.25 : 1.0)

                Spacer(minLength: geometry.size.width/64)
            }
            .background(Color.black)
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
