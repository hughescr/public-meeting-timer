//
//  TimerSettings.swift
//  Public Meeting Timer
//
//  Created by Craig Hughes on 2/8/21.
//

import SwiftUI
import Combine
import Swift
import SwiftUIIntrospect

struct SettingsSheetView: View {
    @Binding var isVisible: Bool
    @ObservedObject var state: CountdownTimerState
    @State private var durationString: String = ""
    @State private var validationError: String? = nil

    var body: some View {
        VStack(alignment: .center) {
            HStack {
                Text("Reset timer to")
                    .font(.headline)

                TextField("Duration",
                          text: $durationString) { (_) in
                    } onCommit: {
                        if validateAndApplyDuration() {
                            isVisible = false
                        }
                    }
#if os(macOS)
                    .introspect(.textField, on: .macOS(.v10_15, .v11, .v12, .v13, .v14, .v15, .v26)) { textField in
                        // UI stuff but running whenever this introspect thing is called on startup, so defer stuff to main thread
                        DispatchQueue.main.async {
                            // NSResponder.becomeFirstResponder docs say:
                            // Use the NSWindow makeFirstResponder(_:) method, not this method, to make an object the first responder. Never invoke this method directly.
                            guard let window = textField.window else { return }
                            
                            // On macOS, check if the current first responder is the text field or its field editor
                            let isAlreadyFirstResponder = window.firstResponder == textField || 
                                                          (window.firstResponder as? NSText)?.delegate as? NSTextField == textField
                            
                            if textField.acceptsFirstResponder && !isAlreadyFirstResponder {
                                if window.makeFirstResponder(textField) {
                                    textField.selectAll(nil)
                                }
                            }
                        }
                    }
#else
                    .introspect(.textField, on: .iOS(.v13, .v14, .v15, .v16, .v17, .v18, .v26),
                                .tvOS(.v14, .v15, .v16, .v18, .v26),
                                .visionOS(.v1, .v2, .v26)) { textField in
                        // UI stuff but running whenever this introspect thing is called on startup, so defer stuff to main thread
                        DispatchQueue.main.async {
                            if((textField.window) != nil && textField.isFirstResponder == false) {
                                textField.becomeFirstResponder()
                                textField.selectAll(nil)
                            }
                        }
                    }
#endif
                    .multilineTextAlignment(.trailing)
                    .frame(width: 50)
                    .onReceive(Just(durationString)) { newValue in
                        let filtered = newValue.filter { "0123456789:.".contains($0) }
                        if filtered != newValue {
                            durationString = filtered
                        }
                    }
            }
            
            // Help text showing format options
            Text("Format: MM:SS, MM.SS, or SSS")
                .font(.caption)
                .foregroundColor(.secondary)
                .padding(.top, 2)
            
            if let error = validationError {
                Text(error)
                    .foregroundColor(.red)
                    .font(.caption)
                    .padding(.top, 4)
            }

            Button("OK") {
                if validateAndApplyDuration() {
                    isVisible = false
                }
            }
        }
        .padding()
        .onAppear() {
            durationString = state.countTo.asMinutesAndSeconds()
            if state.started { state.startOrStop() }
        }
    }
    
    private func validateAndApplyDuration() -> Bool {
        let trimmed = durationString.trimmingCharacters(in: .whitespaces)
        
        // Empty string
        if trimmed.isEmpty {
            validationError = "Please enter a duration"
            return false
        }
        
        let colonCount = trimmed.filter { $0 == ":" }.count
        let dotCount = trimmed.filter { $0 == "." }.count
        
        // Multiple delimiters or mixed delimiters
        if colonCount > 1 || dotCount > 1 || (colonCount > 0 && dotCount > 0) {
            validationError = "Format: MM:SS, MM.SS, or SSS"
            return false
        }
        
        let hasDelimiter = colonCount == 1 || dotCount == 1
        
        if hasDelimiter {
            // Format should be MM:SS or MM.SS
            let delimiter: Character = colonCount == 1 ? ":" : "."
            let parts = trimmed.split(separator: delimiter, omittingEmptySubsequences: false)
            
            // Check for invalid patterns like ":", "3:", ":19"
            if parts.count != 2 {
                validationError = "Format: MM:SS, MM.SS, or SSS"
                return false
            }
            
            let minutesPart = String(parts[0])
            let secondsPart = String(parts[1])
            
            if minutesPart.isEmpty {
                validationError = "Minutes missing"
                return false
            }
            
            if secondsPart.isEmpty {
                validationError = "Seconds missing"
                return false
            }
            
            guard let _ = Int(minutesPart), let _ = Int(secondsPart) else {
                validationError = "Invalid numbers"
                return false
            }
        } else {
            // Format should be just seconds
            guard let _ = Int(trimmed) else {
                validationError = "Invalid number"
                return false
            }
        }
        
        // All validation passed
        validationError = nil
        state.countTo = trimmed.fromMinutesAndSeconds()
        state.reset()
        return true
    }
}

struct SheetView_Previews: PreviewProvider {
    static var previews: some View {
        SettingsSheetView(isVisible: .constant(true), state: CountdownTimerState())
            .frame(width: 200, height: 100)
    }
}
