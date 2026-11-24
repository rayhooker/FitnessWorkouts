//
//  Formatting.swift
//

import Foundation

nonisolated enum Fmt {
    static func miles(_ value: Double, digits: Int = 1) -> String {
        value.formatted(.number.precision(.fractionLength(digits)))
    }

    /// "42:10" or "1:05:32"
    static func duration(_ seconds: TimeInterval) -> String {
        let total = Int(seconds.rounded())
        let h = total / 3600, m = (total % 3600) / 60, s = total % 60
        return h > 0 ? String(format: "%d:%02d:%02d", h, m, s) : String(format: "%d:%02d", m, s)
    }

    /// "8:45 /mi"
    static func pace(_ secondsPerMile: TimeInterval?) -> String {
        guard let secondsPerMile, secondsPerMile.isFinite, secondsPerMile > 0 else { return "--" }
        let total = Int(secondsPerMile.rounded())
        return String(format: "%d:%02d", total / 60, total % 60)
    }

    static func weekRange(start: Date, end: Date) -> String {
        let last = end.addingTimeInterval(-1)
        return "\(start.formatted(.dateTime.month(.abbreviated).day()))–\(last.formatted(.dateTime.month(.abbreviated).day()))"
    }
}
