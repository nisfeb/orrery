# Orrery overnight review, 2026-10-14

An autonomous bug hunt over the released code, run overnight on 2026-10-14 against main at `0988931` (version 104). It found no code bugs. The leads it was given turned out to be runtime or configuration problems on the owner's ship, or to live outside this repo. No code was changed; this report is what it left.

## Status

- Run from 01:07 to about 02:20 EDT.
- Baseline offline suites green: generator 108 of 108, nexus 81 of 81, orrery 62 of 62. With no code changed, the baseline stands as the verification.
- Nothing was written to a live ship, and nothing was pushed.

## Since then (2026-10-18)

- The watch feature it reviewed on its branch shipped: flights and pages watched in version 105, AeroDataBox keys from API.market and the right leg of a flight number in 108, more frequent looks near departure in 109.
- The other items below stand as written on 2026-10-14.

## Fix-first shortlist, ranked

1. Runtime, on the owner's ship: the mail reader had not run since 2026-09-26. Check `mail.json`'s `enabled` and the health of the `mail.sig` fiber, then turn it on or reload it. It is not a code bug: `mail-pass` advances `mail_last` on every path but the one where it is off.
2. Runtime, on the owner's ship: Telegram replies to one contact were failing. Check that contact's chat id in the Telegram `people` map and connections, and the send road. `telegram-last.json` holds the failure note.
3. Outside this repo: a recurring event's `next` comes out an hour off the calendar's around a daylight saving change. Its root is the next-occurrence and DST arithmetic in `reconcile.py` in orrery-utils. The ship's own reader of it is already tolerant, so pick-ups are no longer dropped.
4. Feature: finish the watch feature. Done since, in 105, 108 and 109.
5. Data: a bill-payment task was proposed twice in slightly different words. The generator has no same-intent dedupe in code (an action's id hashes its content), so near-duplicates slip through. Tighten the generator prompt if it recurs.
6. Not verifiable here: the order of pushes when a shared situation is edited needs two ships; the single-ship dev set cannot reproduce it. Carry it to a two-ship gate.

## Subsystem sweep

- Clean: the fold, winners and timeline (lib).
- Partly: reconcile and the DST `next` wobble. The root is outside this repo, and the ship's consumer is tolerant.
- Partly: the readers. The mail and Telegram leads are runtime, below. A full adversarial read of the calendar, chat and browsing readers is still open.
- Clean: the leave and trip fibers (leave times, next look, after the alert, leave quiet, late by, learned extra minutes, pinned until).
- Not swept: resolution and the executors. Carry to a follow-up.
- Partly: sharing, the inbox and sphere follows. The edit-order of shared pushes needs a two-ship test.
- Clean, with a caveat below: the audit of files declared on load.
- Model level, not code: generator dedupe.
- Clean: the schema upgrade ladder (attributes only added, nothing destroyed).
- Clean: request routing (`de-route`). Scopes are consistent, and no mutating route is over-permissive.
- Sound after its two compile fixes: the watch branch as it stood (`dacc036`). A notice fires on a change only, and `next` advances even when a fetch fails.

## Leads to confirm or kill, as given

- reconcile writes a series `next` an hour off the calendar's: why, and what else it misfires.
- Telegram replies to one contact failing; `mail_last` stuck since 2026-09-26; `POST /api/reconcile` waits on a pass in flight; the edit order of shared pushes; a re-adopted task's note.
- Duplicate task proposals.
- Gall timers across reloads: a reload keeps the run nonce, so clearing pending-request state on load drops work in flight. Audit `on-load` for it.

## Findings

### Leads swept clean

- The fold's internals (`is-live`, `later`, `find-value`): correct. `is-live` guards retracted, at and until; `later` orders by at, then seen; `find-value` is a plain search by value. No edge case found.
- `occurrences` only reads the calendar's stored order map; it does not project occurrence times. So the DST `next` wobble is not computed on the ship. Its root is `reconcile.py` in orrery-utils. The ship's consumer (the end lookup in `appointments-ahead`) was already made tolerant, so the wobble no longer drops pick-ups.
- The declared-file audit: every root `.json` written through `over:io (rf 0 / %'...')` is declared in the on-load `%fall` rows (36 written, all among 87 declared), so the lost-on-reload class holds. Caveat: this checked only that literal write pattern. Writes through `file-ops-on`, `observe-ops` or computed paths were not enumerated, and a later pass should confirm them.

### Runtime or configuration, not code

- `mail_last` stuck since 2026-09-26: `mail-pass` calls `reader-record` on every exit but the early return when the reader is off, and `reader-record` always stamps `at`. A frozen `mail_last.at` therefore means the reader was off, or its `mail.sig` fiber was not running (crashed and not revived, or no timer). For the owner: check `mail.json`'s `enabled` and the fiber on the live ship.
- Telegram replies to one contact failing: the reply goes through `send-telegram` with a `chat_id` from `telegram-connections.json` or the `people` map. A failure there is almost surely a missing or stale chat id, or a refused send road, not a logic bug in that path. For the owner: check the contact's entry and the road; `telegram-last.json` holds the failure.

### Confirmed bugs

None.

## Run log

- 01:07: oriented, recalled the leads, ran the baseline suites, made the branch and this report.
- 01:25: swept the fold and winners (clean), `occurrences` (a reader only; the DST root is off the ship), and the declared-file audit (clean).
- 01:42: traced the mail and Telegram leads to runtime and configuration.
- 01:59: swept the leave and trip arms (clean) and `de-route` scopes (clean), and reviewed the watch branch (sound after its fixes).
- 02:17: swept the schema ladder (clean), generator dedupe (model level) and sharing (the push order needs two ships). Finished: no code bugs, shortlist written. Resolution and the executors are left for a follow-up.
