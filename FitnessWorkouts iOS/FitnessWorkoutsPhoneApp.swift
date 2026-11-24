//
//  FitnessWorkoutsPhoneApp.swift
//  FitnessWorkouts (iPhone)
//
//  Companion app: reads the complete running history from Health on the iPhone and keeps the
//  Apple Watch app and widget up to date.
//

import SwiftUI

@main
struct FitnessWorkoutsPhoneApp: App {
    @State private var model = PhoneModel()

    init() {
        PhoneSessionManager.shared.activate()
        // Re-register the observer on every launch, including background launches by HealthKit.
        HealthBackgroundSync.start()
    }

    var body: some Scene {
        WindowGroup {
            PhoneContentView()
                .environment(model)
        }
    }
}
