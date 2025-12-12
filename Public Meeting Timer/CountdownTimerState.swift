//
//  CountdownTimerState.swift
//  Public Meeting Timer
//
//  Created by Craig Hughes on 12/16/20.
//

import Foundation
#if os(iOS)
import UIKit
#elseif os(macOS)
import IOKit.pwr_mgt
#endif

class CountdownTimerState: ObservableObject {
    @Published var started: Bool {
        didSet {
            updateIdleTimerState()
        }
    }
    @Published var counter: Int
    @Published var countTo: Int
    
    #if os(macOS)
    private var powerAssertionID: IOPMAssertionID = 0
    private var hasPowerAssertion = false
    #endif

    init(started: Bool = false, counter: Int = 0, countTo: Int = 180) {
        self.started = started
        self.counter = counter
        self.countTo = countTo
        
        if started {
            updateIdleTimerState()
        }
    }
    
    deinit {
        #if os(macOS)
        releasePowerAssertion()
        #endif
    }
    
    private func updateIdleTimerState() {
        #if os(iOS)
        DispatchQueue.main.async {
            UIApplication.shared.isIdleTimerDisabled = self.started
            #if DEBUG
            print("🔒 Idle timer disabled: \(self.started)")
            #endif
        }
        #elseif os(macOS)
        if started {
            createPowerAssertion()
        } else {
            releasePowerAssertion()
        }
        #endif
    }
    
    #if os(macOS)
    private func createPowerAssertion() {
        guard !hasPowerAssertion else { return }
        
        let reason = "Timer is running" as CFString
        let assertionType = kIOPMAssertionTypePreventUserIdleDisplaySleep as CFString
        
        let success = IOPMAssertionCreateWithName(
            assertionType,
            IOPMAssertionLevel(kIOPMAssertionLevelOn),
            reason,
            &powerAssertionID
        )
        
        if success == kIOReturnSuccess {
            hasPowerAssertion = true
            #if DEBUG
            print("🔒 Power assertion created (ID: \(powerAssertionID))")
            #endif
        } else {
            #if DEBUG
            print("❌ Failed to create power assertion (error: \(success))")
            #endif
        }
    }
    
    private func releasePowerAssertion() {
        guard hasPowerAssertion else { return }
        
        IOPMAssertionRelease(powerAssertionID)
        hasPowerAssertion = false
        #if DEBUG
        print("🔓 Power assertion released (ID: \(powerAssertionID))")
        #endif
        powerAssertionID = 0
    }
    #endif

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

    func progress() -> Float {
        return Float(counter) / Float(countTo)
    }

    func complete() -> Bool {
        return counter == countTo
    }

    func remainingTime() -> Int {
        return countTo - counter
    }
}
