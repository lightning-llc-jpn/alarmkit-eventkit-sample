import EventKit
import Foundation

/// Reads upcoming events from the iOS Calendar database (iCloud, Google, Exchange, ...).
/// Read-only: it never creates or edits events.
final class CalendarReader: @unchecked Sendable {
    let store = EKEventStore()

    func requestAccess() async throws -> Bool {
        try await store.requestFullAccessToEvents()
    }

    /// Timed (non all-day) events starting within `days` days from `now`.
    func upcomingEvents(days: Int, from now: Date = .now) async -> [CalendarEvent] {
        let store = self.store
        // EKEventStore is synchronous; keep it off the main thread.
        return await Task.detached(priority: .utility) {
            let end = now.addingTimeInterval(Double(days) * 86_400)
            let predicate = store.predicateForEvents(withStart: now, end: end, calendars: nil)
            return store.events(matching: predicate).compactMap { event -> CalendarEvent? in
                // Recurring events share one identifier; the start date in the alarm ID
                // keeps each occurrence distinct.
                guard !event.isAllDay, let id = event.eventIdentifier, let start = event.startDate
                else { return nil }
                return CalendarEvent(id: id, title: event.title ?? "", start: start)
            }
        }.value
    }
}
