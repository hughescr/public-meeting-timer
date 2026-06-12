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
        CountdownView(state: state)
            .background(Color.black.ignoresSafeArea())
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
                DispatchQueue.main.async {
                    if let window = NSApp.windows.first,
                       !window.styleMask.contains(.fullScreen) {
                        window.toggleFullScreen(nil)
                    }
                }
            }
#endif
    }
}
