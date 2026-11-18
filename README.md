# AlarmKit × EventKit sample

[日本語](README.ja.md)

A minimal iOS 26 app that reads your calendar with **EventKit** and schedules real
**AlarmKit** alarms before events whose title contains a keyword.

Example rule: *"Meeting" → ring 10 minutes before*. An event called "Team meeting" at
15:00 gets an alarm at 14:50 that rings like a Clock app alarm — through Silent mode
and Focus — until you stop it.

About 270 lines of Swift, no dependencies.

## Files

| File | What it does |
|---|---|
| `Sources/AlarmPlanner.swift` | Pure logic: keyword matching, alarm planning, stable alarm IDs, diff. No EventKit/AlarmKit imports, so it is unit-tested. |
| `Sources/CalendarReader.swift` | EventKit: full-access request and upcoming timed events (read-only). |
| `Sources/AlarmScheduler.swift` | AlarmKit: authorization, schedule, cancel, list. |
| `Sources/SampleApp.swift` | SwiftUI app: rules editor, sync on launch / foreground / `EKEventStoreChanged`. |
| `Tests/AlarmPlannerTests.swift` | XCTest for the planner. |

## Design notes

- **Deterministic alarm IDs.** The ID is a hash of *(event identifier, fire minute)*.
  Re-planning the same calendar yields the same IDs, so a re-sync never cancels and
  re-creates an alarm that is already correct. A cancel/re-create gap that happens to
  straddle the fire time would lose the alarm; stable IDs avoid that entirely.
- **Sync = diff.** Plan from the calendar, compare with `AlarmManager.shared.alarms`,
  schedule what is missing, cancel what is no longer wanted. Running it twice does nothing
  the second time.
- **Keep the OS at the edges.** Only two small types touch EventKit and AlarmKit. The
  matching and planning code is plain Swift and fully testable.
- **Resolve strings before handing them to AlarmKit.** The alarm UI is drawn by the system,
  so pass already-resolved text (as this sample does) rather than catalog keys.

## Run it

1. Xcode 26 or later, iOS 26 or later.
2. Open `AlarmKitEventKitSample.xcodeproj` (or run `xcodegen generate` first).
3. Set your team under *Signing & Capabilities* and change the bundle ID.
4. Run on a device, allow Calendar and Alarms, add an event whose title contains
   "Meeting" a little more than 10 minutes from now, and tap **Sync**.

Tests: `xcodebuild test -scheme AlarmKitEventKitSample -destination 'platform=iOS Simulator,name=iPhone 17 Pro'`

The required usage strings (`NSCalendarsFullAccessUsageDescription`,
`NSAlarmKitUsageDescription`) are set in `project.yml`.

## What a real app adds

This sample skips background refresh, all-day events, snooze, Live Activities/widgets,
alarm-count limits, multiple lead times per keyword, and localization.

A production app built on the same approach is
[KeyAlarm](https://apps.apple.com/app/id6801792687) — notes from building it:
[Shipping an AlarmKit app: what the docs don’t say](https://ltng.jp/keyalarm/blog/alarmkit-in-practice).

## License

MIT © Lightning LLC
