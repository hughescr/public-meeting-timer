//
//  TimerSettings.swift
//  Public Meeting Timer
//
//  Created by Craig Hughes on 2/8/21.
//

import SwiftUI
import Combine
import Introspect

struct SettingsSheetView: View {
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
                        state.reset()
                    }
                    .introspectTextField() { textField in
                        // UI stuff but running whenever this introspect thing is called on startup, so defer stuff to main thread
                        DispatchQueue.main.async {
#if os(iOS)
                            if((textField.window) != nil) {
                                textField.becomeFirstResponder()
                                textField.selectAll(nil)
                            }
#else
                            // NSResponder.becomeFirstResponder docs say:
                            // Use the NSWindow makeFirstResponder(_:) method, not this method, to make an object the first responder. Never invoke this method directly.
                            textField.window?.makeFirstResponder(textField)
#endif
                        }
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
                state.reset()
            }
        }
        .padding()
        .onAppear() {
            durationString = state.countTo.asMinutesAndSeconds()
            if state.started { state.startOrStop() }
        }
    }
}

struct SheetView_Previews: PreviewProvider {
    static var previews: some View {
        SettingsSheetView(isVisible: .constant(true), state: CountdownTimerState())
            .frame(width: 200, height: 100)
    }
}
