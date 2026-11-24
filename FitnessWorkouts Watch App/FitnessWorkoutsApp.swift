//
//  FitnessWorkoutsApp.swift
//  FitnessWorkouts Watch App
//
//  Created by Ray Hooker on 11/21/26.
//

import SwiftUI

enum Route: Hashable {
    case weekDetail
    case trend
    case run(RunSummary)
    case goal
    case syncStatus
}

@main
struct FitnessWorkouts_Watch_AppApp: App {
    @State private var model = MileageViewModel()
    @State private var path: [Route] = []

    init() {
        WatchSessionManager.shared.activate()
    }

    var body: some Scene {
        WindowGroup {
            ContentView(path: $path)
                .environment(model)
                // Tapping the widget opens the app straight on the weekly chart.
                .onOpenURL { url in
                    switch url {
                    case DeepLink.weeklyDetail: path = [.weekDetail]
                    case DeepLink.trend: path = [.trend]
                    default: path = []
                    }
                }
        }
    }
}
