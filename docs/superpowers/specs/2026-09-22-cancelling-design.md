# Cancelling one occurrence, and a calendar action that can undo

Orrery version 37 lets a cancellation reach the calendar. Today a reply saying "practice tonight is cancelled" becomes a fact and stops there: the reader has nowhere to put "this one occurrence is off", so it writes `status: cancelled` on the whole activity, and nothing removes the event, because a `calendar` action can only add. Both gaps are closed here. Decided with the owner on 2026-09-22, after the case above happened on the live ship.

## Where a cancelled occurrence goes

An activity gains a multi-valued attribute, `skipped`: the start of one occurrence that is off, ISO 8601 UTC, one observation per occurrence. The activity's own `status` keeps its old meaning, the series as a whole: `active` or `cancelled`. The schema's note for each says so, and the client guide's rule says a reader that reads "tonight is cancelled" writes `skipped` and never touches `status`, while "the team folded" writes `status`.

Reconcile keeps the list short: a `skipped` whose time has passed by more than a day is retracted on the twice-daily pass, with the note `the occurrence has passed`, so an activity carries only what is still ahead. `next` is unchanged by a skip; a reader and the brief read `next` against `skipped` and say the next one that is not skipped, which is what the client guide tells them to do.

A one-off situation that is cancelled already has a home: `status: cancelled` on the situation, which the retire pass leaves alone and the brief skips.

## A calendar action that cancels

The `calendar` action's payload gains `mode`, one of `add` (the default, what exists today) and `cancel`. A cancel names the event: `event` is the calendar's own id for it (the `id` the store gives, which a reader learns from the source id of the fact it read, or from the event the client saw), and, when the event repeats, `starts` is the occurrence to drop. The rest of the payload is unchanged.

The executor serves a cancel by reading the store it already keeps for the mirror: an event whose id matches and which does not repeat is removed with `del-event`; one that repeats and carries a `starts` is skipped for that occurrence; an event the store does not have, or a repeat with no `starts`, is `failed` with the reason. The note on a done cancel says `off the calendar` or `that occurrence skipped`.

Nothing else about the executor changes: a cancel is claimed `by ship` like any calendar action, and an action for a calendar that is not installed waits, as before.

## The calendar's part

The calendar's `skip-event` takes an occurrence index, which only its own expansion of the recurrence knows. The ship has the store, not the expansion, so the calendar desk gains one poke: `skip-at {id, start_ms}`, which finds the occurrence starting at that moment and skips it exactly as `skip-event` does, and does nothing when no occurrence starts there. That is the whole calendar change, and it ships as a calendar release before orrery 37 reaches the live ship.

## What a reader proposes

A message that cancels an occurrence gives the reader two things to write: the fact (`skipped` on the activity, or `status: cancelled` on the situation) and, when the client knows the calendar event it came from, a `calendar` action with `mode: cancel` for the owner to approve. The action is not automatic: taking something off the calendar is the kind of move the owner taps, and `calendar` is not in the auto list.

## Out of scope

Editing an event's time or title from an action (a later version; `mode` leaves room for it). Cancelling a whole series from an action. Deleting a todo the ship did not place. Teaching the ship to expand a recurrence.
