//
//  TimerSettings.swift
//  Public Meeting Timer
//
//  Created by Craig Hughes on 2/8/21.
//

import SwiftUI
import Swift
#if os(macOS)
import AppKit
#endif

struct SettingsSheetView: View {
    @Binding var isVisible: Bool
    let state: CountdownTimerState

    // Input mechanism is platform-specific (see `durationInput`):
    //   • iOS / visionOS / tvOS — a MINUTES : SECONDS picker, so the value is
    //     always well-formed: no free-text, no format hint, no validation. These
    //     bind `minutes`/`seconds` and commit `minutes*60 + seconds` on Set. Using
    //     a picker here avoids summoning the on-screen / pop-over keyboard.
    //   • macOS — the original free-text field, because there is a real keyboard
    //     and typing the time is faster than spinning a wheel. It binds
    //     `durationString` and routes through `validateAndApplyDuration()`.
    // Each input path owns only the @State it actually writes, fenced to its
    // platform: the picker platforms drive `minutes`/`seconds`, macOS drives the
    // free-text `durationString` plus its validation/focus state. Declaring them
    // unconditionally would leave write-only properties dangling on the other
    // platforms.
#if !os(macOS)
    @State private var minutes: Int = 0
    @State private var seconds: Int = 0
#else
    @State private var durationString: String = ""
    @State private var validationError: String? = nil
    @FocusState private var durationIsFocused: Bool
#endif

    var body: some View {
        // The whole sheet sits on the app's dark, state-driven gradient so the
        // white system sheet background is gone and the glass card reads against
        // black like the rest of the UI. The card is ALWAYS dark, so we pin the
        // sheet to the dark color scheme: that makes `Color.primary` resolve light
        // (it is black in light mode, near-invisible on the dark card) and lets the
        // materials and glass settle to their dark appearance regardless of device.
        cardStack
            .padding()
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(TimerBackground(state: state))
            .presentationBackground(.clear)
            .presentationDetents([.medium])
            .colorScheme(.dark)
            .onAppear() {
                // Seed whichever input the platform shows from the current target,
                // clamping minutes into the picker's 0...99 range so an out-of-range
                // persisted value can't seed an invalid picker. The validated macOS
                // text path agrees on the same range, so the value round-trips.
                // Editing the duration also implies the timer should stop.
#if !os(macOS)
                minutes = min(99, state.countTo / 60)
                seconds = state.countTo % 60
#else
                durationString = state.countTo.asMinutesAndSeconds()
#endif
                if state.started { state.startOrStop() }
#if os(macOS)
                durationIsFocused = true
#endif
            }
    }

    /// The glass surface that holds the title, the input, and the actions. Uses the
    /// shared `glassCardSurface` helper (Timer.swift) so it stays in lockstep with
    /// the control card's chrome: real Liquid Glass inside a GlassEffectContainer on
    /// OS 26, frosted material as the pre-26 / visionOS fallback.
    @ViewBuilder
    private var cardStack: some View {
        let shape = RoundedRectangle(cornerRadius: 28)
        cardContent
            .padding(24)
            .glassCardSurface(in: shape)
    }

    /// Title + platform-appropriate input + Cancel/Set actions, on a light
    /// foreground so everything reads against the dark gradient.
    @ViewBuilder
    private var cardContent: some View {
        VStack(spacing: 20) {
            Text("Reset timer to")
                .font(.headline)
                .foregroundStyle(Color.primary)

            durationInput

            HStack(spacing: 16) {
                Button(action: { isVisible = false }) {
                    Label("Cancel", systemImage: "xmark")
                        .foregroundStyle(Color.primary)
                }
                .timerButtonStyle()

                Button(action: { applyAndDismiss() }) {
                    Label("Set", systemImage: "checkmark")
                        .foregroundStyle(Color.primary)
                }
                .timerButtonStyle(prominent: true, tint: .green)
                // The duration invariant is 0:00 < t ≤ 99:59. On the picker
                // platforms enforce the lower bound up front by disabling Set at
                // 0:00; on macOS the free-text value isn't known here, so Set stays
                // enabled and `validateAndApplyDuration()` rejects a zero total.
#if !os(macOS)
                .disabled(minutes == 0 && seconds == 0)
#endif
            }
        }
    }

    // The input mechanism forks on `#if os(macOS)`: keyboard text entry on the Mac
    // (there's a real keyboard, so typing the time beats clicking a spinner), a
    // MINUTES : SECONDS picker everywhere else (where a text field would summon the
    // on-screen / pop-over keyboard). Both paths feed `applyAndDismiss()`.
#if os(macOS)
    /// macOS: the original free-text field, given an aesthetic pass for the dark
    /// glass card — monospaced value, the format hint as subtle secondary text, the
    /// inline validation error in red. Keyboard-driven; `.wheel`-style pickers are
    /// unavailable on macOS anyway.
    @ViewBuilder
    private var durationInput: some View {
        VStack(spacing: 8) {
            TextField("Duration", text: $durationString)
                .textFieldStyle(.plain)
                .multilineTextAlignment(.center)
                .monospacedDigit()
                .font(.title2)
                .foregroundStyle(Color.primary)
                .focused($durationIsFocused)
                .frame(width: 120)
                .padding(.vertical, 8)
                .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 10))
                .onSubmit { applyAndDismiss() }
                .onChange(of: durationString) { _, newValue in
                    let filtered = newValue.filter { "0123456789:.".contains($0) }
                    if filtered != newValue {
                        durationString = filtered
                    }
                }
                // Select the whole value when the field gains focus, so typing
                // REPLACES the seeded duration instead of appending to it (the old
                // sheet did this; the rewrite had dropped it). We reach the active
                // field editor through the key window's first responder rather than
                // wrapping an NSTextField, which keeps the SwiftUI field intact.
                .onChange(of: durationIsFocused) { _, focused in
                    if focused {
                        DispatchQueue.main.async {
                            if let editor = NSApp.keyWindow?.firstResponder as? NSText {
                                editor.selectAll(nil)
                            }
                        }
                    }
                }

            // Help text showing format options.
            Text("Format: MM:SS, MM.SS, or SSS")
                .font(.caption)
                .foregroundStyle(.secondary)

            if let error = validationError {
                Text(error)
                    .foregroundStyle(.red)
                    .font(.caption)
            }
        }
        .defaultFocus($durationIsFocused, true)
    }
#elseif os(tvOS)
    /// tvOS: a CUSTOM focusable MINUTES : SECONDS selector. tvOS has no good
    /// built-in inline number spinner — `.wheel` does not exist there, the default
    /// `Picker` renders as an unreadable cramped carousel, and `Stepper` is
    /// unavailable too — so each unit is a big monospaced number flanked by a pair
    /// of plain `Button`s (which are focusable on tvOS by default). The remote's
    /// directional swipes move focus between the −/+ controls; clicking adjusts the
    /// value. Sized for couch-distance legibility.
    @ViewBuilder
    private var durationInput: some View {
        HStack(alignment: .center, spacing: 24) {
            // Minutes CLAMP at 0...99 (no wrap): holding "up" past 99 silently
            // jumping back to 0 would be a footgun when dialing a long duration.
            stepperColumn(label: "min",
                          value: $minutes,
                          range: 0...99,
                          format: "%d",
                          wraps: false)

            Text(":")
                .font(.system(size: 80, weight: .semibold))
                .monospacedDigit()
                .foregroundStyle(.secondary)

            // Seconds WRAP (0↔59) as conventional for a seconds dial.
            stepperColumn(label: "sec",
                          value: $seconds,
                          range: 0...59,
                          format: "%02d",
                          wraps: true)
        }
    }

    /// One unit column: a +button on top, the large value, a −button below, with a
    /// "min"/"sec" caption. When `wraps` is true the value cycles within `range`
    /// (e.g. 59→0) so holding a direction never dead-ends; when false it clamps at
    /// the bounds (used for minutes, where wrapping past 99 would be surprising).
    @ViewBuilder
    private func stepperColumn(label: String,
                               value: Binding<Int>,
                               range: ClosedRange<Int>,
                               format: String,
                               wraps: Bool) -> some View {
        VStack(spacing: 12) {
            stepButton(systemImage: "chevron.up") {
                if value.wrappedValue >= range.upperBound {
                    value.wrappedValue = wraps ? range.lowerBound : range.upperBound
                } else {
                    value.wrappedValue += 1
                }
            }

            Text(String(format: format, value.wrappedValue))
                .font(.system(size: 80, weight: .semibold))
                .monospacedDigit()
                .foregroundStyle(Color.primary)
                .frame(minWidth: 140)

            stepButton(systemImage: "chevron.down") {
                if value.wrappedValue <= range.lowerBound {
                    value.wrappedValue = wraps ? range.upperBound : range.lowerBound
                } else {
                    value.wrappedValue -= 1
                }
            }

            Text(label)
                .font(.title3)
                .foregroundStyle(.secondary)
        }
    }

    /// A subtle, focusable chevron button. `timerButtonStyle()` gives it the same
    /// glass/borderless chrome as the rest of the card and supplies the tvOS focus
    /// halo for free, so a light foreground keeps it legible on the dark glass.
    @ViewBuilder
    private func stepButton(systemImage: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: 36, weight: .bold))
                .foregroundStyle(Color.primary)
                .padding(8)
        }
        .timerButtonStyle()
    }
#else
    /// iOS / visionOS: a MINUTES : SECONDS Clock-app `.wheel` spinner. Selection
    /// writes straight to `state.countTo` on Set, so there is nothing to validate.
    @ViewBuilder
    private var durationInput: some View {
        HStack(spacing: 0) {
            minutesPicker
                .pickerStyle(.wheel)
                .frame(maxWidth: .infinity)

            Text("min")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            secondsPicker
                .pickerStyle(.wheel)
                .frame(maxWidth: .infinity)

            Text("sec")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: 320)
    }

    /// Minutes picker source (0...99).
    private var minutesPicker: some View {
        Picker("min", selection: $minutes) {
            ForEach(0...99, id: \.self) { value in
                Text("\(value)")
                    .monospacedDigit()
                    .tag(value)
            }
        }
    }

    /// Seconds picker source (0...59), zero-padded for the MM:SS look.
    private var secondsPicker: some View {
        Picker("sec", selection: $seconds) {
            ForEach(0...59, id: \.self) { value in
                Text(String(format: "%02d", value))
                    .monospacedDigit()
                    .tag(value)
            }
        }
    }
#endif

    /// Commits the edited duration and dismisses. On the picker platforms the
    /// minutes/seconds always form a valid value, so it just updates `countTo`,
    /// calls `reset()` so the timer arc redraws (exactly like the old OK path), and
    /// closes. On macOS it routes through the validator and only dismisses when the
    /// typed value parses.
    private func applyAndDismiss() {
#if os(macOS)
        if validateAndApplyDuration() {
            isVisible = false
        }
#else
        state.countTo = minutes * 60 + seconds
        state.reset()
        isVisible = false
#endif
    }

#if os(macOS)
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

            guard let mins = Int(minutesPart), let secs = Int(secondsPart) else {
                validationError = "Invalid numbers"
                return false
            }

            // Keep the typed value inside the same 0...99 min / 0...59 sec range
            // the pickers enforce, so both input paths round-trip identically.
            if secs > 59 {
                validationError = "Seconds must be 0–59"
                return false
            }

            if mins > 99 {
                validationError = "Minutes must be 0–99"
                return false
            }
        } else {
            // Format should be just seconds.
            guard let totalSeconds = Int(trimmed) else {
                validationError = "Invalid number"
                return false
            }

            // The seconds-only (SSS) form still has to fit the 99:59 ceiling.
            if totalSeconds > 99 * 60 + 59 {
                validationError = "Maximum duration is 99:59"
                return false
            }
        }

        // A zero/negative duration would divide-by-zero in progress() and leave
        // nothing to count down — reject it (the invariant is 0:00 < t ≤ 99:59).
        let total = trimmed.fromMinutesAndSeconds()
        if total <= 0 {
            validationError = "Enter a non-zero duration"
            return false
        }

        // All validation passed.
        validationError = nil
        state.countTo = total
        state.reset()
        return true
    }
#endif
}

#Preview {
    SettingsSheetView(isVisible: .constant(true), state: CountdownTimerState())
}
