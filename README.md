# TallyBar

A menu bar time tracker for freelancers. Local only, no account.

- One click start, stop and switch per client
- Daily and weekly totals, weekly goal ring
- Timesheet with editing
- CSV export
- Idle detection: keep or discard the time you were away

Everything is stored in one JSON file at
`~/Library/Application Support/TallyBar/ledger.json`.

## Build

    swift build
    swift run TallyBar

Needs macOS 14 and Swift 5.10 or later.

## Tests

    swift test

The tests use Swift Testing, so they need the Xcode toolchain.
