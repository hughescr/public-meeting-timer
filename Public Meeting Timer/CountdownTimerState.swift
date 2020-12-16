//
//  CountdownTimerState.swift
//  Public Meeting Timer
//
//  Created by Craig Hughes on 12/16/20.
//

import Foundation

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
