# Data format

Everything TallyBar stores is in one file:

```text
~/Library/Application Support/TallyBar/ledger.json
```

Set `TALLYBAR_DATA_DIR` to use a different folder.

## Safety

- **Atomic writes.** The file is written to a temporary location and swapped into
  place, so a crash during a save cannot leave half a ledger.
- **Backup.** Before each save, the current file is copied to `ledger.backup.json`,
  as long as it can be read. A damaged file never replaces a good backup.
- **Damaged files are kept.** If `ledger.json` cannot be read, it is moved to
  `ledger.corrupt-<timestamp>.json`, TallyBar restores the backup, and it tells you.
- **Files from the future are left alone.** If the version is newer than this copy of
  the app understands, TallyBar shows a message and does not write to the file.

## Shape

```json
{
  "version": 2,
  "clients": [
    {
      "id": "A1B2C3D4-0000-0000-0000-000000000001",
      "name": "Lumen Coffee Roasters",
      "hourlyRate": { "amount": "120", "currency": "USD" },
      "colorIndex": 0,
      "billingAddress": "48 Roastery Road",
      "isArchived": false
    }
  ],
  "entries": [
    {
      "id": "A1B2C3D4-0000-0000-0000-000000000002",
      "clientID": "A1B2C3D4-0000-0000-0000-000000000001",
      "start": "2025-10-06T13:05:00Z",
      "end": "2025-10-06T15:40:00Z",
      "note": "Packaging concepts",
      "invoiceNumber": "INV-0042"
    }
  ],
  "running": null,
  "settings": {},
  "lastClientID": "A1B2C3D4-0000-0000-0000-000000000001",
  "lastHeartbeat": null,
  "nextInvoiceNumber": 43
}
```

## Conventions

- Timestamps are UTC instants in whole seconds. They become local time only for
  display, so changing time zones never changes a duration.
- Money amounts are strings, because a JSON number passes through a binary float in
  many parsers and can lose cents. Files from before 0.4 hold numbers and still load.
- Every field added after the first release is optional when reading, so older files
  always open.
