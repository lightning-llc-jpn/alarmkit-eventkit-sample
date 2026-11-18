import XCTest
@testable import AlarmKitEventKitSample

final class AlarmPlannerTests: XCTestCase {
    private let now = Date(timeIntervalSince1970: 1_800_000_000)
    private func event(_ id: String, _ title: String, inMinutes minutes: Double) -> CalendarEvent {
        CalendarEvent(id: id, title: title, start: now.addingTimeInterval(minutes * 60))
    }

    func testMatchesKeywordIgnoringCaseAndWidth() {
        let rules = [KeywordRule(keyword: "meeting", minutesBefore: 10)]
        let events = [event("a", "Team MEETING", inMinutes: 60), event("b", "Ｍｅｅｔｉｎｇ prep", inMinutes: 90),
                      event("c", "Lunch", inMinutes: 120)]
        let plan = AlarmPlanner.plan(events: events, rules: rules, now: now)
        XCTAssertEqual(plan.map(\.title), ["Team MEETING", "Ｍｅｅｔｉｎｇ prep"])
        XCTAssertEqual(plan.first?.fireDate, now.addingTimeInterval(50 * 60))
    }

    func testSkipsPastAlarmsAndBlankKeywords() {
        let rules = [KeywordRule(keyword: "Call", minutesBefore: 30), KeywordRule(keyword: "  ", minutesBefore: 5)]
        let plan = AlarmPlanner.plan(events: [event("a", "Call", inMinutes: 10)], rules: rules, now: now)
        XCTAssertTrue(plan.isEmpty)
    }

    func testOneAlarmPerEventAndMinute() {
        let rules = [KeywordRule(keyword: "Team", minutesBefore: 5), KeywordRule(keyword: "Sync", minutesBefore: 5),
                     KeywordRule(keyword: "Sync", minutesBefore: 30)]
        let plan = AlarmPlanner.plan(events: [event("a", "Team Sync", inMinutes: 60)], rules: rules, now: now)
        XCTAssertEqual(plan.count, 2)
    }

    func testIDIsStableAcrossReplans() {
        let rules = [KeywordRule(keyword: "Call", minutesBefore: 5)]
        let events = [event("a", "Call", inMinutes: 60)]
        let first = AlarmPlanner.plan(events: events, rules: rules, now: now)
        let second = AlarmPlanner.plan(events: events, rules: rules, now: now.addingTimeInterval(120))
        XCTAssertEqual(first.map(\.id), second.map(\.id))
        XCTAssertNotEqual(AlarmPlanner.alarmID(eventID: "a", fireDate: now),
                          AlarmPlanner.alarmID(eventID: "a", fireDate: now.addingTimeInterval(60)))
    }

    func testDiffIsIdempotent() {
        let desired = AlarmPlanner.plan(events: [event("a", "Call", inMinutes: 60)],
                                        rules: [KeywordRule(keyword: "Call", minutesBefore: 5)], now: now)
        let stale = UUID()
        let first = AlarmPlanner.diff(desired: desired, scheduled: [stale])
        XCTAssertEqual(first.toSchedule, desired)
        XCTAssertEqual(first.toCancel, [stale])

        let second = AlarmPlanner.diff(desired: desired, scheduled: Set(desired.map(\.id)))
        XCTAssertTrue(second.toSchedule.isEmpty && second.toCancel.isEmpty)
    }
}
