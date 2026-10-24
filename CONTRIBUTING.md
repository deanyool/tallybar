# Contributing

Thanks for wanting to help. Bug reports with exact steps are as useful as code.

## Setup

You need macOS 14 or later and Xcode 16 or later. There are no third-party
dependencies, so a fresh clone builds with nothing else installed.

```sh
git clone https://github.com/deanyool/tallybar
cd tallybar
swift build
swift test
```

The tests use Swift Testing, which ships with Xcode rather than the Command Line
Tools. If `swift test` says it cannot find the `Testing` module, point the toolchain
at Xcode:

```sh
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test
```

To run the app with its own throwaway data:

```sh
scripts/build-app.sh
TALLYBAR_DATA_DIR=/tmp/tally-dev dist/TallyBar.app/Contents/MacOS/TallyBar
```

## Where things go

- Anything that can be decided without a window goes in `TallyCore`, with a test.
  Time math, money, invoices, CSV, storage and the idle rules all live there.
- `TallyUI` holds the SwiftUI views and `AppModel`, plus the code that talks to macOS
  in `Sources/TallyUI/Platform`.
- `TallyBar` is only the app entry point.

See [docs/architecture.md](docs/architecture.md) for how the pieces fit.

## Rules of the road

- Money is `Decimal`. Never `Double`.
- Times are absolute `Date` values stored in whole seconds. Never add 86,400 to get
  to the next day; ask the `Calendar`.
- If it touches time, add a test that runs across a daylight saving change.
- New settings must decode from older files. Add them to the custom `Codable` in
  `TallySettings` with a default.
- Nothing goes on the network. That is the point of the app.

## Before opening a pull request

```sh
swift test
swiftlint lint
scripts/build-app.sh && scripts/smoke-test.sh dist/TallyBar.app
```

If you changed a view, run `scripts/render-docs.sh` and include the new screenshots.
Add a line to `CHANGELOG.md` under the next version.
