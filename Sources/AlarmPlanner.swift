import CryptoKit
import Foundation

/// A calendar event, reduced to what the planner needs. No EventKit here,
/// so the planning logic stays pure and unit-testable.
struct CalendarEvent: Equatable, Sendable {
    let id: String
    let title: String
    let start: Date
}

/// "If an event title contains `keyword`, ring `minutesBefore` minutes before it starts."
struct KeywordRule: Codable, Equatable, Identifiable, Sendable {
    var id = UUID()
    var keyword: String
    var minutesBefore: Int
}

/// One alarm that should exist in AlarmKit.
struct PlannedAlarm: Equatable, Identifiable, Sendable {
    let id: UUID
    let title: String
    let fireDate: Date
}

enum AlarmPlanner {
    /// Every alarm that should be scheduled for `events`, sorted by fire date.
    /// Alarms in the past are dropped; two rules hitting the same minute collapse into one.
    static func plan(events: [CalendarEvent], rules: [KeywordRule], now: Date) -> [PlannedAlarm] {
        var byID: [UUID: PlannedAlarm] = [:]
        for event in events {
            let title = fold(event.title)
            for rule in rules {
                let keyword = fold(rule.keyword.trimmingCharacters(in: .whitespacesAndNewlines))
                guard !keyword.isEmpty, title.contains(keyword) else { continue }
                let fireDate = event.start.addingTimeInterval(-Double(rule.minutesBefore) * 60)
                guard fireDate > now else { continue }
                let id = alarmID(eventID: event.id, fireDate: fireDate)
                byID[id] = PlannedAlarm(id: id, title: event.title, fireDate: fireDate)
            }
        }
        return byID.values.sorted { $0.fireDate < $1.fireDate }
    }

    /// Case-, width- and diacritic-insensitive form used on both sides of the match.
    /// A fixed locale keeps matching independent of the device language.
    static func fold(_ text: String) -> String {
        let locale = Locale(identifier: "en_US_POSIX")
        return text
            .folding(options: .widthInsensitive, locale: locale)
            .folding(options: [.caseInsensitive, .diacriticInsensitive], locale: locale)
            .precomposedStringWithCanonicalMapping
    }

    /// The alarm ID depends only on (event, fire minute).
    ///
    /// This is the key design point: re-planning the same calendar produces the same IDs,
    /// so a re-sync never cancels and re-creates an alarm that is already correct.
    /// (A cancel/re-create gap that straddles the fire time would lose the alarm.)
    static func alarmID(eventID: String, fireDate: Date) -> UUID {
        let fireMinute = Int(fireDate.timeIntervalSince1970.rounded(.down)) / 60
        let digest = SHA256.hash(data: Data("\(eventID)|\(fireMinute)".utf8))
        var bytes = Array(digest.prefix(16))
        bytes[6] = (bytes[6] & 0x0F) | 0x50   // version 5
        bytes[8] = (bytes[8] & 0x3F) | 0x80   // RFC 4122 variant
        return bytes.withUnsafeBytes { UUID(uuid: $0.loadUnaligned(as: uuid_t.self)) }
    }

    /// What to add and what to remove so that AlarmKit holds exactly `desired`.
    /// Running it twice in a row yields an empty second diff (idempotent).
    static func diff(desired: [PlannedAlarm], scheduled: Set<UUID>)
        -> (toSchedule: [PlannedAlarm], toCancel: [UUID]) {
        let desiredIDs = Set(desired.map(\.id))
        return (
            desired.filter { !scheduled.contains($0.id) },
            scheduled.subtracting(desiredIDs).sorted { $0.uuidString < $1.uuidString }
        )
    }
}
