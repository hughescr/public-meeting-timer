//
//  TimerSettings.swift
//  Public Meeting Timer
//
//  Created by Craig Hughes on 2/8/21.
//

import SwiftUI
import Swift

struct SettingsSheetView: View {
    @Binding var isVisible: Bool
    let state: CountdownTimerState
    @State private var durationString: String = ""
    @State private var validationError: String? = nil
    @FocusState private var durationIsFocused: Bool

    var body: some View {
        VStack(alignment: .center) {
            HStack {
                Text("Reset timer to")
                    .font(.headline)

                TextField("Duration", text: $durationString)
                    .onSubmit {
                        if validateAndApplyDuration() {
                            isVisible = false
                        }
                    }
                    .focused($durationIsFocused)
                    .multilineTextAlignment(.trailing)
                    .frame(width: 50)
                    .onChange(of: durationString) { _, newValue in
                        let filtered = newValue.filter { "0123456789:.".contains($0) }
                        if filtered != newValue {
                            durationString = filtered
                        }
                    }
            }

            // Help text showing format options
            Text("Format: MM:SS, MM.SS, or SSS")
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(.top, 2)

            if let error = validationError {
                Text(error)
                    .foregroundStyle(.red)
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
        .defaultFocus($durationIsFocused, true)
#if canImport(UIKit)
        .onReceive(NotificationCenter.default.publisher(for: UITextField.textDidBeginEditingNotification)) { notification in
            let textField = notification.object as? UITextField
            DispatchQueue.main.async { textField?.selectAll(nil) }
        }
#endif
        .onAppear() {
            durationString = state.countTo.asMinutesAndSeconds()
            if state.started { state.startOrStop() }
            durationIsFocused = true
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

#Preview {
    SettingsSheetView(isVisible: .constant(true), state: CountdownTimerState())
        .frame(width: 200, height: 100)
}
