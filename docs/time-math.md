# Time math

Most time tracking bugs come from treating a day as 86,400 seconds. These are the rules
TallyBar follows, and each has tests in `Tests/TallyCoreTests/DaySlicesTests.swift`.

## Durations come from instants

An entry stores two absolute instants. Its length is the distance between them, which
is correct whatever the wall clock did. In Toronto on November 2, 2025, the clock reads
1:30 twice. A session from 12:30 EDT to 1:30 EST looks like one hour and is two.
TallyBar records two. In March the reverse happens, and 1:30 to 3:30 is one real hour.

## Days come from the calendar

To split a session across days, TallyBar asks `Calendar` for the real bounds of each
local day rather than adding 24 hours. That gives the right answer for:

| Case | Example | Length of the day |
| --- | --- | --- |
| Fall back | Toronto, Nov 2, 2025 | 25 hours |
| Spring forward | Toronto, Mar 8, 2026 | 23 hours |
| Half hour shift | Lord Howe Island, Oct 5, 2025 | 23.5 hours |
| No midnight at all | Havana, Mar 8, 2026 | Starts at 01:00 |

The slices of a session always add up to exactly the session.

## A session belongs to every day it touches

A session from 11:00 PM to 1:30 AM is one hour on the first day and an hour and a half
on the second. Daily and weekly totals, the timesheet, invoices and the CSV export all
use this split, so they agree with each other. A session crossing Sunday night counts
toward both weeks.

## Money comes from exact seconds

An amount is `rate × seconds ÷ 3600`, rounded half-up to the currency's minor unit. The
two decimal hours printed on an invoice are for reading. 20 minutes at $100 an hour is
$33.33, not 0.33 × 100. Each line is rounded once, and the subtotal is the sum of the
rounded lines, so the printed column always adds up.

Billing rounding, when turned on, applies to each piece of work on each day before
pricing. Two 5 minute calls rounded up to 15 minute increments bill 30 minutes.
