# AlarmKit × EventKit サンプル

[English](README.md)

**EventKit** でカレンダーを読み、予定のタイトルにキーワードが入っていたら、その前に
**AlarmKit** の本物のアラームを登録する、iOS 26 向けの最小のアプリです。

ルールの例：「会議」→ 10 分前に鳴らす。15:00 の「定例会議」には 14:50 のアラームが入り、
時計アプリのアラームと同じように、消音モードや集中モード中でも止めるまで鳴り続けます。

Swift で約 250 行、依存ライブラリはありません。

## ファイル

| ファイル | 役割 |
|---|---|
| `Sources/AlarmPlanner.swift` | 純粋なロジック：キーワードの照合・アラームの計画・変わらない ID・差分。EventKit も AlarmKit も import しないので単体テストできます。 |
| `Sources/CalendarReader.swift` | EventKit：フルアクセスの許可と、これからの時刻指定の予定の読み取り（読むだけ）。 |
| `Sources/AlarmScheduler.swift` | AlarmKit：許可・登録・取消・一覧。 |
| `Sources/SampleApp.swift` | SwiftUI の画面：ルールの編集と、起動時・前面に戻ったとき・`EKEventStoreChanged` での同期。 |
| `Tests/AlarmPlannerTests.swift` | プランナの XCTest。 |

## 設計のポイント

- **アラームの ID を決定的にする。** ID は「予定の ID ＋ 鳴る時刻（分）」のハッシュです。
  同じカレンダーから計画し直せば同じ ID になるので、正しく入っているアラームを同期のたびに
  取り消して作り直すことがありません。取消と再登録の隙間が鳴る時刻にかかると、そのアラームは
  消えてしまいます。ID が変わらなければこの穴は最初からありません。
- **同期は差分で。** カレンダーから計画を立て、`AlarmManager.shared.alarms` と比べて、
  足りないものを登録し、要らなくなったものを取り消します。2 回続けて流しても 2 回目は何もしません。
- **OS に触れる部分は端に寄せる。** EventKit と AlarmKit に触るのは小さな 2 つの型だけ。
  照合と計画は普通の Swift なので、全部テストできます。
- **AlarmKit には解決済みの文字列を渡す。** アラームの画面を描くのはシステム側なので、
  カタログのキーではなく、その場で文字列にしたもの（このサンプルのやり方）を渡します。

## 動かし方

1. Xcode 26 以降・iOS 26 以降。
2. `AlarmKitEventKitSample.xcodeproj` を開く（または先に `xcodegen generate`）。
3. *Signing & Capabilities* で自分のチームを選び、Bundle ID を変える。
4. 実機で起動してカレンダーとアラームを許可し、10 分少し先に「Meeting」を含む予定を入れて
   **Sync** を押す（キーワードは画面で「会議」などに変えられます）。

テスト：`xcodebuild test -scheme AlarmKitEventKitSample -destination 'platform=iOS Simulator,name=iPhone 17 Pro'`

必要な利用目的の文（`NSCalendarsFullAccessUsageDescription`・`NSAlarmKitUsageDescription`）は
`project.yml` に書いてあります。

## 実用のアプリで足すもの

このサンプルは、バックグラウンド更新・終日予定・スヌーズ・ライブアクティビティ／ウィジェット・
アラーム数の上限・1 つのキーワードに複数の「何分前」・多言語対応を省いています。

同じ作りで実際に公開しているアプリが
[KeyAlarm](https://apps.apple.com/jp/app/id6801792687) です。作ったときの記録：
[AlarmKit アプリを出荷して分かったこと（iOS 26）](https://ltng.jp/keyalarm/blog/alarmkit-in-practice-ja)。

## ライセンス

MIT © Lightning LLC
