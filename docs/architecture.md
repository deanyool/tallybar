# Architecture

TallyBar is three layers, and the dependency only points one way.

```text
TallyBar (app entry point)
   |
TallyUI  (SwiftUI views, AppModel, Platform/ for macOS services)
   |
TallyCore (pure logic: time, money, invoices, CSV, storage)
```

`tally-render` is a fourth target beside the app. It draws the real views from a
fictional ledger to produce the screenshots in this repository.

## TallyCore

The center of the app is `Ledger`, a plain value holding everything TallyBar knows:
clients, entries, the running session and settings. Every rule is a method on it:
`start`, `stop`, `resolve(away:)`, `buildInvoice`, `csv`. Because a ledger is a value,
a test can create one, call a method with an explicit `now`, and compare the result.
Nothing in the core reads the system clock.

`IdleMonitor` follows the same idea. It receives samples of "seconds since last input"
and reports an away period when the person returns. Sleep, wake and timer hiccups are
all just numbers in a test.

`InvoicePDF` draws with Core Graphics and Core Text, so it needs no window or main
thread. All the money is calculated by `buildInvoice` before drawing starts, so the
renderer contains no arithmetic beyond layout.

## TallyUI

`AppModel` owns the ledger and is the only thing that changes it. Every change goes
through `update(_:)`, which applies the change and saves:

```swift
model.update { $0.addClient(name: "Lumen", hourlyRate: 120) }
```

Views read from the model and hold no durable state of their own.

`Platform/` is the thin layer over macOS:

| File | System API |
| --- | --- |
| `GlobalHotKey` | Carbon `RegisterEventHotKey`, which needs no Accessibility permission |
| `SystemIdle` | `CGEventSource.secondsSinceLastEventType` |
| `LaunchAtLogin` | `SMAppService.mainApp` |
| `WindowManager` | `NSWindow` hosting SwiftUI, opened on demand |
| `AppController` | Timer, wake notifications, and the wiring between all of the above |
| `SelfCheck` | The `--self-check` report used by the smoke test |

## The tick

`AppController` runs a 15 second timer. Each tick reads the idle clock and calls
`AppModel.tick(now:idleSeconds:)`, which:

1. updates `now`, which moves the menu bar label,
2. feeds the idle monitor, and sets `pendingAway` if the person just came back,
3. saves a heartbeat once a minute while a session runs.

The heartbeat is how a crash is recovered. A session is stored as soon as it starts, so
after a crash or power loss the next launch finds it still running, sees the last
heartbeat was a while ago, and asks about the gap exactly as if the person had walked
away.

See [data-format.md](data-format.md).
