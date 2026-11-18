import AlarmKit
import Foundation
import SwiftUI

/// Metadata attached to each alarm. This sample needs none.
struct SampleAlarmMetadata: AlarmMetadata {}

/// The AlarmKit side: alarms scheduled here ring like Clock app alarms,
/// through Silent mode and Focus, until the user stops them.
struct AlarmScheduler {
    private var manager: AlarmManager { .shared }

    func requestAuthorization() async throws -> Bool {
        try await manager.requestAuthorization() == .authorized
    }

    /// IDs of the alarms this app has scheduled (AlarmKit only returns our own).
    func scheduledIDs() throws -> Set<UUID> {
        Set(try manager.alarms.map(\.id))
    }

    func schedule(_ alarm: PlannedAlarm) async throws {
        let alert = AlarmPresentation.Alert(
            title: LocalizedStringResource(stringLiteral: alarm.title),
            stopButton: AlarmButton(text: "Stop", textColor: .white, systemImageName: "stop.circle")
        )
        let attributes = AlarmAttributes<SampleAlarmMetadata>(
            presentation: AlarmPresentation(alert: alert),
            tintColor: .orange
        )
        let configuration = AlarmManager.AlarmConfiguration<SampleAlarmMetadata>(
            schedule: .fixed(alarm.fireDate),
            attributes: attributes
        )
        _ = try await manager.schedule(id: alarm.id, configuration: configuration)
    }

    func cancel(_ id: UUID) {
        // The alarm may already have rung or been removed; that is fine.
        try? manager.cancel(id: id)
    }
}
