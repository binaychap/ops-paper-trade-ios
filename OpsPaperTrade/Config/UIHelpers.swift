import Foundation
import SwiftUI

// MARK: - Trade / order status styling

enum StatusStyle {
    static func color(for status: String?) -> Color {
        switch (status ?? "").lowercased() {
        case "ordered", "submitted", "filled", "complete":
            return .green
        case "queued", "dry_run":
            return .blue
        case "failed", "submission_unknown", "rejected", "cancelled", "canceled":
            return .red
        case "skipped":
            return .gray
        case "unlinked":
            return .orange
        default:
            return .secondary
        }
    }
}

/// Small capsule pill rendering a trade/order/exit status.
struct StatusPill: View {
    let status: String?

    private var label: String {
        (status ?? "unknown").replacingOccurrences(of: "_", with: " ").capitalized
    }

    var body: some View {
        Text(label)
            .font(.caption2.weight(.semibold))
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(StatusStyle.color(for: status).opacity(0.15))
            .foregroundStyle(StatusStyle.color(for: status))
            .clipShape(Capsule())
    }
}

// MARK: - Formatting helpers

enum Formatters {
    static let newYorkTimeZone: TimeZone = TimeZone(identifier: "America/New_York") ?? .current

    private static let iso8601Fractional: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()

    private static let iso8601Plain: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter
    }()

    /// Parse an ISO-8601-ish timestamp, tolerating fractional seconds and a few
    /// common fallbacks. Returns nil when nothing parses.
    static func parseDate(_ value: String?) -> Date? {
        guard let value, !value.isEmpty else { return nil }
        if let date = iso8601Fractional.date(from: value) { return date }
        if let date = iso8601Plain.date(from: value) { return date }
        let fallbackPatterns = ["yyyy-MM-dd'T'HH:mm:ss", "yyyy-MM-dd HH:mm:ss", "yyyy-MM-dd"]
        for pattern in fallbackPatterns {
            let formatter = DateFormatter()
            formatter.locale = Locale(identifier: "en_US_POSIX")
            formatter.timeZone = TimeZone(secondsFromGMT: 0)
            formatter.dateFormat = pattern
            if let date = formatter.date(from: value) { return date }
        }
        return nil
    }

    private static let newYorkDateTime: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale.current
        formatter.timeZone = newYorkTimeZone
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter
    }()

    /// Display a server timestamp in America/New_York. Falls back to the raw
    /// string (or an em dash) when it cannot be parsed.
    static func newYorkDateTimeString(_ value: String?) -> String {
        guard let date = parseDate(value) else { return value ?? "\u{2014}" }
        return newYorkDateTime.string(from: date)
    }

    private static let currency: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "USD"
        formatter.maximumFractionDigits = 2
        return formatter
    }()

    static func moneyString(_ value: Double?) -> String {
        guard let value else { return "\u{2014}" }
        return currency.string(from: NSNumber(value: value)) ?? "\u{2014}"
    }

    static func signedMoneyString(_ value: Double?) -> String {
        guard let value else { return "\u{2014}" }
        let sign = value > 0 ? "+" : ""
        return sign + moneyString(value)
    }

    static func quantityString(_ value: Double?) -> String {
        guard let value else { return "\u{2014}" }
        if value.truncatingRemainder(dividingBy: 1) == 0 {
            return String(format: "%.0f", value)
        }
        return String(format: "%.4f", value)
    }

    static func pnlColor(_ value: Double?) -> Color {
        guard let value else { return .secondary }
        if value > 0 { return .green }
        if value < 0 { return .red }
        return .secondary
    }
}