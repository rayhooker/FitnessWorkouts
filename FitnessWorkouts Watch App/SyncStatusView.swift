//
//  SyncStatusView.swift
//  FitnessWorkouts Watch App
//
//  Shows the state of the connection to the iPhone app, for troubleshooting history sync.
//

import Combine
import SwiftUI

struct SyncStatusView: View {
    @Environment(MileageViewModel.self) private var model
    @State private var lines: [SyncStatusLine] = []
    @State private var isRequesting = false

    var body: some View {
        List {
            Section {
                ForEach(lines) { line in
                    VStack(alignment: .leading, spacing: 1) {
                        Text(line.label)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                        Text(line.value)
                            .font(.footnote)
                    }
                }
            }

            Section {
                Button {
                    Task {
                        isRequesting = true
                        if await WatchSessionManager.shared.requestRunsFromPhone() {
                            model.phoneDataDidChange()
                        }
                        lines = WatchSessionManager.shared.statusLines
                        isRequesting = false
                    }
                } label: {
                    HStack {
                        Label("Request from iPhone", systemImage: "iphone.radiowaves.left.and.right")
                        if isRequesting {
                            Spacer()
                            ProgressView()
                        }
                    }
                }
                .disabled(isRequesting)
            }
        }
        .navigationTitle("Sync Status")
        .onAppear { lines = WatchSessionManager.shared.statusLines }
        .onReceive(NotificationCenter.default.publisher(for: WatchSessionManager.didReceiveRuns)) { _ in
            lines = WatchSessionManager.shared.statusLines
        }
    }
}
