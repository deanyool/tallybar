# Changelog

All notable changes to TallyBar are listed here. The format follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/) and versions follow
[Semantic Versioning](https://semver.org/).

## [0.4.0] - 2026-02-22

### Added

- PDF invoices with pagination, tax, payment terms and your business details.
- Three line styles: one per day, one per entry, or a single total.

### Fixed

- Money is stored as a string, because JSON numbers can lose cents on large amounts.
  Existing files still load.

## [0.3.0] - 2026-01-28

### Added

- Timesheet window with editing, manual entries and deletion.
- CSV export.
- Idle detection with keep, discard, and discard and stop.
- Recovery after a crash or power loss, using a heartbeat in the saved file.

## [0.2.0] - 2025-12-20

### Added

- Weekly total and goal ring.
- Settings window with goal, week start and client management.
- Clients can be archived.

### Fixed

- Sessions that cross midnight now count toward the right days.
- Days are measured with the calendar, so 23 and 25 hour days add up correctly.

## [0.1.0] - 2025-11-02

### Added

- Menu bar timer with one click start, stop and switch per client.
- Hourly rates and a daily total.
- Local JSON storage with atomic writes.
