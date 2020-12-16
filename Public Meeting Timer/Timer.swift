import SwiftUI
import Combine
import Introspect

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
        let split = self.split(separator: ":")
        var sum = 0
        if split.count == 2 {
            let minutes = Int(split[0]) ?? 0
            let seconds = Int(split[1]) ?? 0
            sum = minutes * 60 + seconds
        } else {
            let seconds = Int(split[0]) ?? 0
            sum = seconds
        }

        return sum
    }
}

struct ClockTimeText: View {
    private let clockTimeTextFontRatio = CGFloat(4)

    var counter: Int
    var countTo: Int

    var body: some View {
        GeometryReader { geometry in
            Text((countTo - counter).asMinutesAndSeconds())
                .foregroundColor(.black)
                .font(.custom("Avenir", size: min(geometry.size.width, geometry.size.height)/clockTimeTextFontRatio))
                .fontWeight(.black)
            .frame(width: geometry.size.width,
                   height: geometry.size.height,
                   alignment: .center)
        }
    }
}

private let outerCircleRatio = CGFloat(10)
private let innerCircleRatio = CGFloat(12)

struct FullCircleTrack: View {
    var started: Bool

    var body: some View {
        GeometryReader { geometry in
            Circle()
                .fill(Color.white)
                .frame(minWidth: 0, maxWidth: .infinity,
                       minHeight: 0, maxHeight: .infinity,
                       alignment: .center)
                .overlay(
                    Circle()
                        .inset(by: min(geometry.size.width, geometry.size.height)/innerCircleRatio)
                        .stroke(started ? Color.black : Color.gray,
                                lineWidth: min(geometry.size.width, geometry.size.height)/outerCircleRatio)
                        .animation(
                            .easeInOut(duration: 0.2)
                        )
                )
            
        }
    }
}

struct ProgressBar: View {
    var counter: Int
    var countTo: Int

    var body: some View {
        GeometryReader { geometry in
            Circle()
                .inset(by: min(geometry.size.width, geometry.size.height)/innerCircleRatio)
                .rotation(.degrees(-90))
                .trim(from:progress(), to: 1)
                .stroke(
                    style: StrokeStyle(
                        lineWidth: min(geometry.size.width, geometry.size.height)/innerCircleRatio,
                        lineCap: .butt
                    )
            )
                .foregroundColor(
                    (progress() >= 7/8 ? Color.red :
                     progress() >= 3/4 ? Color.orange :
                        Color.green)
            ).animation(
                .easeInOut(duration: 0.2)
            )
        }
    }

    func completed() -> Bool {
        return progress() == 1
    }

    func progress() -> CGFloat {
        return (CGFloat(counter) / CGFloat(countTo))
    }
}

class CountdownTimerState: ObservableObject {
    @Published var started: Bool
    @Published var counter: Int
    @Published var countTo: Int

    init(started: Bool = false, counter: Int = 0, countTo: Int = 180) {
        self.started = started
        self.counter = counter
        self.countTo = countTo
    }

    func tickIfStarted(_ time: Date) {
        if(started && counter < countTo) {
            counter += 1
            if(counter >= countTo) {
                started = false
            }
        }
    }

    func setBaseTime(_ time: Int) {
        reset()
        countTo = time
    }

    func addMinute() {
        reset()
        countTo += 60
    }

    func removeMinute() {
        reset()
        if(countTo > 60) {
            countTo -= 60
        }
    }

    func startOrStop() {
        if(!started && counter >= countTo) {
            reset()
        }
        started = !started
    }

    func reset() {
        started = false
        counter = 0
    }
}

struct ClockStack: View {
    @ObservedObject var state: CountdownTimerState

    var body: some View {
        ZStack {
            FullCircleTrack(started: state.started)
            ProgressBar(counter: state.counter, countTo: state.countTo)
            ClockTimeText(counter: state.counter, countTo: state.countTo)
        }
    }
}

struct ClockStack_Previews: PreviewProvider {
    static var previews: some View {
        ClockStack(state: CountdownTimerState(started: false, counter: 120, countTo: 180))
            .frame(width: 120.0, height: 120.0)
    }
}

struct SetDurationSheetView: View {
    @Binding var isVisible: Bool
    @ObservedObject var state: CountdownTimerState
    @State private var durationString: String = ""

    var body: some View {
        VStack(alignment: .center) {
            HStack {
                Text("Reset timer to")
                    .font(.headline)

                TextField("Duration",
                          text: $durationString) { (_) in
                    } onCommit: {
                        isVisible = false
                        state.countTo = durationString.fromMinutesAndSeconds()
                    }
                    .introspectTextField() { textField in
                        textField.becomeFirstResponder()
                    }
                    .multilineTextAlignment(.trailing)
                    .frame(width: 50)
                    .onReceive(Just(durationString)) { newValue in
                        let filtered = newValue.filter { "0123456789:".contains($0) }
                        if filtered != newValue {
                            durationString = filtered
                        }
                    }
            }

            Button("OK") {
                isVisible = false
                state.countTo = durationString.fromMinutesAndSeconds()
            }
        }
        .padding()
        .onAppear() {
            durationString = state.countTo.asMinutesAndSeconds()
        }
    }
}

struct SheetView_Previews: PreviewProvider {
    static var previews: some View {
        SetDurationSheetView(isVisible: .constant(true), state: CountdownTimerState())
            .frame(width: 200, height: 100)
    }
}

struct TimerSettings: View {
    var height: CGFloat
    @ObservedObject var state: CountdownTimerState
    @State private var showSheet = false

    var body: some View {
        VStack(alignment: .leading, spacing: height/32) {
            Button(action: { showSheet = true }, label: {
                Text("⏲ Set")
                    .font(.custom("Avenir", size: height/16))
                    .fontWeight(.heavy)
            })
            .buttonStyle(PlainButtonStyle())
        }
        .sheet(isPresented: $showSheet) {
            SetDurationSheetView(isVisible: $showSheet, state: state)
        }
    }
}

struct ResetButton: View {
    var height: CGFloat
    @ObservedObject var state: CountdownTimerState

    var body: some View {
        Button(action: { state.reset() }, label: {
            Text("🛑 Reset")
                .font(.custom("Avenir", size: height/16))
                .fontWeight(.heavy)
        })
        .buttonStyle(PlainButtonStyle())
    }
}

struct StartOrStopButton: View {
    var height : CGFloat
    @ObservedObject var state: CountdownTimerState

    private func widthAsRendered(_ string : String) -> CGFloat {
#if os(macOS)
        let theFont = NSFont(name: "Avenir Heavy", size: height/16)!
#else
        let theFont = UIFont(name: "Avenir Heavy", size: height/16)!
#endif
        return (string as NSString)
            .size(withAttributes: [NSAttributedString.Key.font : theFont])
            .width
    }

    var body: some View {
        Button(action: { state.startOrStop() }, label: {
            Text(state.started ? "⏸ Pause" :
                    state.counter < state.countTo ? "▶️ Start" : "↪️ Restart")
                .frame(minWidth: widthAsRendered("↪️ Restart"),
                       alignment: .leading)
                .font(.custom("Avenir Heavy", size: height/16))
        })
        .buttonStyle(PlainButtonStyle())
    }
}

struct CountdownView: View {
    @State var state = CountdownTimerState()
    @State var editing = true

    var body: some View {
        GeometryReader { geometry in
            HStack {
                ClockStack(state: state)
                    .onReceive(timer, perform: state.tickIfStarted)

                VStack(alignment: .leading, spacing: geometry.size.height/8) {
                    TimerSettings(height: geometry.size.height, state: state)

                    ResetButton(height: geometry.size.height, state: state)

                    StartOrStopButton(height: geometry.size.height, state: state)
                }
                .padding(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: geometry.size.width/32))
            }
        }
    }
}

struct CountdownView_Previews: PreviewProvider {
    static var previews: some View {
        CountdownView(state: CountdownTimerState(started: true, countTo: 10))
            .frame(width: 192.0, height: 120.0)
    }
}
