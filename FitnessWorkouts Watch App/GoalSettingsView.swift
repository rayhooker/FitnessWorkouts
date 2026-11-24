//
//  GoalSettingsView.swift
//  FitnessWorkouts Watch App
//

import SwiftUI

struct GoalSettingsView: View {
    @Environment(MileageViewModel.self) private var model

    var body: some View {
        @Bindable var model = model

        Form {
            Section {
                Stepper(value: $model.weeklyGoalMiles, in: 1...150, step: 1) {
                    VStack {
                        Text(Fmt.miles(model.weeklyGoalMiles, digits: 0))
                            .font(.system(.title, design: .rounded).weight(.semibold))
                            .foregroundStyle(.tint)
                        Text("miles / week")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                }
            } footer: {
                Text("The widget's ring fills as you approach this goal.")
            }

            #if DEBUG
            Section("Debug") {
                Toggle("Use Sample Data", isOn: $model.useSampleData)
            }
            #endif
        }
        .navigationTitle("Weekly Goal")
    }
}

#Preview {
    NavigationStack {
        GoalSettingsView()
    }
    .environment(MileageViewModel(previewRuns: SampleData.runs()))
}
