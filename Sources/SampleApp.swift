import EventKit
import Observation
import SwiftUI

@main
struct SampleApp: App {
    @State private var model = SyncModel()
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            ContentView(model: model)
                .task { await model.start() }
                .onChange(of: scenePhase) { _, phase in
                    if phase == .active { Task { await model.sync() } }
                }
                // Re-sync whenever the calendar changes (new event, moved event, ...).
                .onReceive(NotificationCenter.default.publisher(for: .EKEventStoreChanged)) { _ in
                    Task { await model.sync() }
                }
        }
    }
}

@MainActor @Observable
final class SyncModel {
    var rules: [KeywordRule] { didSet { saveRules() } }
    private(set) var upcoming: [PlannedAlarm] = []
    private(set) var status = "Not synced yet"

    private let calendar = CalendarReader()
    private let scheduler = AlarmScheduler()
    private static let rulesKey = "rules"

    init() {
        let saved = UserDefaults.standard.data(forKey: Self.rulesKey)
            .flatMap { try? JSONDecoder().decode([KeywordRule].self, from: $0) }
        rules = saved ?? [KeywordRule(keyword: "Meeting", minutesBefore: 10)]
    }

    func start() async {
        do {
            guard try await calendar.requestAccess() else { status = "Calendar access denied"; return }
            guard try await scheduler.requestAuthorization() else { status = "Alarm access denied"; return }
            await sync()
        } catch {
            status = "Permission error: \(error.localizedDescription)"
        }
    }

    /// Plan from the calendar, then make AlarmKit match the plan.
    func sync() async {
        let events = await calendar.upcomingEvents(days: 7)
        let desired = AlarmPlanner.plan(events: events, rules: rules, now: .now)
        do {
            let diff = AlarmPlanner.diff(desired: desired, scheduled: try scheduler.scheduledIDs())
            diff.toCancel.forEach(scheduler.cancel)
            for alarm in diff.toSchedule { try await scheduler.schedule(alarm) }
            upcoming = desired
            status = "Synced: +\(diff.toSchedule.count) / -\(diff.toCancel.count)"
        } catch {
            status = "Sync failed: \(error.localizedDescription)"
        }
    }

    private func saveRules() {
        UserDefaults.standard.set(try? JSONEncoder().encode(rules), forKey: Self.rulesKey)
    }
}

struct ContentView: View {
    @Bindable var model: SyncModel

    var body: some View {
        NavigationStack {
            List {
                Section("Rules") {
                    ForEach($model.rules) { $rule in
                        HStack {
                            TextField("Keyword", text: $rule.keyword)
                            Stepper("\(rule.minutesBefore) min", value: $rule.minutesBefore, in: 0...720, step: 5)
                                .fixedSize()
                        }
                    }
                    .onDelete { model.rules.remove(atOffsets: $0) }
                    Button("Add rule") { model.rules.append(KeywordRule(keyword: "", minutesBefore: 5)) }
                }
                Section("Next 7 days") {
                    if model.upcoming.isEmpty { Text("No matching events").foregroundStyle(.secondary) }
                    ForEach(model.upcoming) { alarm in
                        LabeledContent(alarm.title, value: alarm.fireDate.formatted(date: .abbreviated, time: .shortened))
                    }
                }
            }
            .navigationTitle("Keyword Alarms")
            .toolbar { Button("Sync") { Task { await model.sync() } } }
            .safeAreaInset(edge: .bottom) {
                Text(model.status).font(.footnote).foregroundStyle(.secondary).padding(8)
            }
        }
    }
}
