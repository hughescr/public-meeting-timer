import SwiftUI

let fontRatio = CGFloat(4)
let outerCircleRatio = CGFloat(10)
let innerCircleRatio = CGFloat(12)

let timer = Timer
    .publish(every: 1, on: .main, in: .common)
    .autoconnect()

struct ClockText: View {
    var counter: Int
    var countTo: Int

    var body: some View {
        GeometryReader { geometry in
            Text(counterToMinutes())
                .foregroundColor(.black)
                .font(.custom("Avenir", size: min(geometry.size.width, geometry.size.height)/fontRatio))
                .fontWeight(.black)
            .frame(width: geometry.size.width,
                   height: geometry.size.height,
                   alignment: .center)
        }
    }

    func counterToMinutes() -> String {
        let currentTime = countTo - counter
        let seconds = currentTime % 60
        let minutes = Int(currentTime / 60)

        return "\(minutes):\(seconds < 10 ? "0" : "")\(seconds)"
    }
}

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
                .trim(from:0, to: progress())
                .stroke(
                    style: StrokeStyle(
                        lineWidth: min(geometry.size.width, geometry.size.height)/innerCircleRatio,
                        lineCap: .round,
                        lineJoin:.round
                    )
            )
                .foregroundColor(
                    (completed() ? Color.red :
                        progress() >= 7/8 ? Color.red :
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

class CountdownState: ObservableObject {
    @Published var started: Bool
    @Published var counter: Int
    @Published var countTo: Int

    init(started: Bool = false, counter: Int = 0, countTo: Int = 180) {
        self.started = started
        self.counter = counter
        self.countTo = countTo
    }
}

struct CountdownView: View {
    @ObservedObject var state = CountdownState()

    var body: some View {
        GeometryReader { geometry in
            HStack {
                ZStack {
                    FullCircleTrack(started: state.started)
                    ProgressBar(counter: state.counter, countTo: state.countTo)
                    ClockText(counter: state.counter, countTo: state.countTo)
                }
                .onReceive(timer, perform: tickIfStarted)

                VStack(alignment: .leading, spacing: geometry.size.height/8) {
                    VStack(alignment: .leading, spacing: geometry.size.height/32) {
                        Button(action: { setBaseTime(5 * 60) }, label: {
                            Text("⏲ 5 Min")
                                .font(.custom("Avenir", size: geometry.size.height/16))
                                .fontWeight(.heavy)
                        })
                        .buttonStyle(PlainButtonStyle())

                        Button(action: { setBaseTime(3 * 60) }, label: {
                            Text("⏲ 3 Min")
                                .font(.custom("Avenir", size: geometry.size.height/16))
                                .fontWeight(.heavy)
                        })
                        .buttonStyle(PlainButtonStyle())

                        Button(action: { setBaseTime(10) }, label: {
                            Text("⏲ 10 Sec")
                                .font(.custom("Avenir", size: geometry.size.height/16))
                                .fontWeight(.heavy)
                        })
                        .buttonStyle(PlainButtonStyle())
                    }

                    Button(action: reset, label: {
                        Text("🛑 Reset")
                            .font(.custom("Avenir", size: geometry.size.height/16))
                            .fontWeight(.heavy)
                    })
                    .buttonStyle(PlainButtonStyle())

                    Button(action: startOrStop, label: {
                        Text(state.started ? "⏸ Pause" : state.counter < state.countTo ? "▶️ Start" : "↪️ Restart")
                            .font(.custom("Avenir", size: geometry.size.height/16))
                            .fontWeight(.heavy)
                    })
                    .buttonStyle(PlainButtonStyle())
                }
                .padding(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: geometry.size.width/32))
            }
        }

    }

    func tickIfStarted(_ time: Date) {
        if(state.started && state.counter < state.countTo) {
            state.counter += 1
            if(state.counter >= state.countTo) {
                state.started = false
            }
        }
    }

    func setBaseTime(_ time: Int) {
        reset()
        state.countTo = time
    }

    func addMinute() {
        reset()
        state.countTo += 60
    }

    func removeMinute() {
        reset()
        if(state.countTo > 60) {
            state.countTo -= 60
        }
    }

    func startOrStop() {
        if(!state.started && state.counter >= state.countTo) {
            reset()
        }
        state.started = !state.started
    }

    func reset() {
        state.started = false
        state.counter = 0
    }
}

struct CountdownView_Previews: PreviewProvider {
    static var previews: some View {
        CountdownView(state: CountdownState(started: true, countTo: 10))
            .frame(width: 192.0, height: 120.0)
    }
}
