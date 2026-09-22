# Cancelling one occurrence: Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Orrery version 37: a cancelled occurrence has a place to live (`skipped` on the activity), and a `calendar` action can take an event off the calendar or skip one occurrence, which the executor carries out against the calendar desk.

**Architecture:** Three small pieces. The schema gains `skipped` on activities, multi-valued, and its note; reconcile retracts a `skipped` a day past. The `calendar` action's payload gains `mode` (`add` by default, `cancel`), and `plan-exec` answers a cancel with a new plan target whose body names the event and, when it repeats, the occurrence; the executor reads the store it already keeps, picks `del-event` or the calendar's new `skip-at`, and reports. The calendar desk gains `skip-at {id, start_ms}`, since only its own expansion knows an occurrence's index.

**Tech Stack:** Hoon (the orrery desk and the calendar desk), the api gate, the page tests.

**Spec:** `docs/superpowers/specs/2026-09-22-cancelling-design.md`.

## Global Constraints

- No em dashes (U+2014) anywhere in either repo. No hard-wrapped markdown. Commit messages one plain sentence, no attribution lines. Comments are complete sentences that say why.
- Never touch the live ship. The dev ship is `http://localhost:8080` with the cookie jar `/tmp/wex.cookies`; the second ship for the unit suites is at the mount `/home/sneagan/software/feb/grubbery` with its dojo in tmux window `0:6`. Never boot or kill piers. No ship codes, tokens or cookies in the repo or a report.
- Fast compile: `/tmp/claude-1001/-home-sneagan-software-personal-orrery/2a3e16c2-f1c6-43d8-a630-854483ecbe32/scratchpad/build.sh <path under code/>` prints `build: vase` (`mime` for the page) or the compile error. The calendar desk has no such helper; write its file through the ball explorer the same way (`POST /grubbery/ball/apps/shell.shell/desks/calendar.desk/desk/code/nex/calendar/app.hoon` with `action=write-text`) and read `?info=1` for the bang.
- Unit suites: `\cp -f` the lib and `tests/lib/*.hoon` into the mount, then in tmux `0:6`: `C-u`, `|commit %grubbery`, wait 12 s, then `/tmp/claude-1001/-home-sneagan-software-personal-orrery/2a3e16c2-f1c6-43d8-a630-854483ecbe32/scratchpad/febtest.sh generator` (52 now) and `... orrery` (59 now). If the runner times out, read the pane with `tmux capture-pane -t 0:6 -p -S -800` and filter `silo-drop` and `old %blit`.
- Gates: `python3 scripts/code-closure.py code`, `node scripts/page-test.js` (69), `python3 scripts/api-matrix.py http://localhost:8080 /tmp/wex.cookies` (230, 20 to 40 minutes; run it with nohup to a scratchpad log and poll), `python3 scripts/prompt-drift.py ../orrery-utils/common`.
- The calendar desk lives at `/home/sneagan/software/personal/calendar` (its own git repo, branch main). Its release is its own version bump and push; this plan's Task 1 makes the change and leaves the release to the controller.

---

### Task 1: The calendar's skip by time

**Files:**
- Modify: `/home/sneagan/software/personal/calendar/code/nex/calendar/app.hoon` (the action dispatch, beside `skip-event` at about line 162)
- Modify: `/home/sneagan/software/personal/calendar/code/version.json` (bump by one)

**Interfaces:**
- Produces: the poke `{"action": "skip-at", "id": "<event id>", "start_ms": <number>}`: the occurrence of that event which starts at that moment is skipped, exactly as `skip-event` skips one by index; anything else is a no-op, as every unknown action there is.

- [ ] **Step 1: Read `skip-event`** (app.hoon 162 to 176) and the expansion it relies on. The index it puts into `except.bound` counts occurrences of the event's recurrence; find the arm that expands a recurrence into occurrence starts (grep for `except`, `bound`, and the arm the month view uses to list an event's occurrences, likely in `code/lib/calendar.hoon` or `code/lib/rrule.hoon`). Name it in the report.
- [ ] **Step 2: Write `skip-at`** beside `skip-event`:

```hoon
        ::  skip-at: skip the occurrence that starts at start_ms. The page
        ::  skips by index, which only the expansion knows; a client that
        ::  holds a time and not an index (orrery's executor) needs this.
        ?:  =('skip-at' act)
          =/  id=@ta  (crip (trip (gs jon 'id')))
          =/  ms=(unit @ud)  (gn jon 'start_ms')
          ?:  |(=('' id) ?=(~ ms))  $
          =/  ev=(unit event:cal)  (~(get by (events-all:cal c)) id)
          ?~  ev  $
          =/  when=@da  (ms-to-da u.ms)
          =/  idx=(unit @ud)  (occurrence-index u.ev when)
          ?~  idx  $
          =/  new=(unit event:cal)
            ?-  -.u.ev
              ?(%date %todo)  ~
              %timed   `u.ev(except.bound (~(put in except.bound.u.ev) u.idx))
              %allday  `u.ev(except.bound (~(put in except.bound.u.ev) u.idx))
            ==
          ?~  new  $
          ;<  ~  bind:m  (replace:io (put-ev c id u.new))
          $
```

Write `occurrence-index |=([ev=event:cal when=@da] (unit @ud))` beside it (or in the lib if that is where the expansion lives): walk the event's occurrence starts, answer the index whose start equals `when`, `~` when none does. Reuse the expansion the page's list uses; do not write a second one. `ms-to-da` exists in that file.

- [ ] **Step 3: Build on the dev ship** (write the file through the explorer, read `?info=1`, bang null) and probe by hand: pick a repeating event from `GET /apps/calendar/events.json`, poke `skip-at` with the start of one of its occurrences, read the events back and see that occurrence gone and the others still there; poke `skip-at` with a time no occurrence starts at and see nothing change. Record the calls.
- [ ] **Step 4: Bump `code/version.json`, commit** in the calendar repo: `An occurrence can be skipped by its start, not only by its index`.

---

### Task 2: The schema, the reader's rule, and reconcile

**Files:**
- Modify: `code/lib/orrery.hoon` (`starter-schema`'s activity block at about 1009; the `multi` list at about 994; `plan-times` at about 2600)
- Test: `tests/lib/generator.hoon`

**Interfaces:**
- Produces: the schema's activity attrs gain `skipped` with the note `the start of one occurrence that is off, ISO 8601 UTC, one row per occurrence; the activity itself stays active`, and the `status` note becomes `active, or cancelled when the whole series has ended; one occurrence that is off goes under skipped`; `skipped` joins the `multi` list. `plan-times` retracts a `skipped` row whose value is more than a day in the past, with the note `reconcile: the occurrence has passed`.

- [ ] **Step 1: The failing test.** In the generator suite beside `test-plan-times`, add a case: an activity with three `skipped` rows (one two days past, one an hour past, one tomorrow) yields exactly one retract, naming the two-days-past row, with that note; and a `skipped` on a body that is not an activity is left alone.
- [ ] **Step 2: Run it on the second ship, see the failure.**
- [ ] **Step 3: The schema.** Add `skipped` to the activity's attr list and its note; rewrite the `status` note; add `skipped` to `multi`. Read how `plan-times` already retracts a stale `next` (the `this occurrence has passed` branch) and add the `skipped` branch in the same shape, keyed on `=(%activity kind.body.l)`.
- [ ] **Step 4: Tests green** (53 on the generator suite), `build.sh lib/orrery.hoon` vase. **Commit** `An activity says which occurrences are off, and reconcile drops the ones gone by`.

---

### Task 3: The cancel plan

**Files:**
- Modify: `code/lib/orrery.hoon` (the payload shapes in `starter-schema` at about 1020; `plan-exec` and `exec-plan` in the executors section at about 4300 to 4400)
- Test: `tests/lib/generator.hoon`

**Interfaces:**
- Consumes: `exec-plan [id kind target to body note]` where `target` is `?(%telegram %mail %calendar %todo)`.
- Produces: `target` gains `%uncalendar`; a `calendar` action whose payload's `mode` is `cancel` answers a plan with `target %uncalendar`, `to` the event id from the payload's `event`, and `body` the JSON `{"start_ms": <ms of starts>}` when the payload carries `starts`, else `{}`; a `mode` that is neither `add` nor `cancel`, or a cancel with no `event`, answers a plan with `note` set (`mode must be add or cancel`, `cancel needs the event`) so the executor leaves it approved and notes it, the way a message with no address is left. The schema's `calendar` payload shape gains `['mode' 'optional: add (the default) or cancel']` and `['event' 'optional: the calendar id of the event to cancel']`; `starts` keeps its note and, under a cancel, means the occurrence.

- [ ] **Step 1: The failing test** in `test-plan-exec`'s neighbourhood: four actions, a plain add (unchanged, `%calendar`), a cancel with an event and a start (`%uncalendar`, `to` the id, `body.start_ms` the epoch ms), a cancel with an event and no start (`body` empty), a cancel with no event (a note, no poke). Assert the plan list and each field.
- [ ] **Step 2: Run it, see the failure.**
- [ ] **Step 3: The planner.** Add the target to the type, the branch to `plan-exec`, and the two shape lines to the schema. `ms-of` is in the same section for the epoch ms. Do not touch `event-json`: a cancel writes no event.
- [ ] **Step 4: Tests green (54), lib vase. Commit** `A calendar action can say cancel, and the planner answers with the event to take off`.

---

### Task 4: The executor carries a cancel out

**Files:**
- Modify: `code/nex/orrery/app.hoon` (`exec-one` and the calendar poke in the executor section, about 3490 to 3560)

**Interfaces:**
- Consumes: Task 3's `%uncalendar` plans; the store the fiber already reads for the mirror (`read-calendar`, which answers the store as JSON).
- Produces: a `%uncalendar` plan is claimed `by ship` like any calendar action, then: the store is searched for an event whose `id` equals the plan's `to`; no such event is `failed` with `the calendar does not have that event`; an event that does not repeat (no `kind` beyond `once`, or no recurrence in its row; read the store's rows to see which key says so and name it in the report) is removed with `{"action": "del-event", "id": <id>}` and reported `done` with `off the calendar`; one that repeats with a `start_ms` in the body is skipped with `{"action": "skip-at", "id": <id>, "start_ms": <ms>}` and reported `done` with `that occurrence skipped`; one that repeats with no `start_ms` is `failed` with `that event repeats, so the occurrence is needed`. A refused poke is `failed` with its text, as the add branch already does.

- [ ] **Step 1: Read `exec-one`'s `%calendar` branch** and `poke-calendar`; the store read is `read-calendar`'s JSON, whose `events` rows carry `id`, `cat`, `meta`, and the recurrence keys. Write down which key tells a repeat from a one-off before you branch on it.
- [ ] **Step 2: Add the branch**, reusing `poke-calendar` for both pokes. The plan's `note` path (a bad mode, a missing event) must leave the action approved and noted, not claimed: that check belongs beside the existing "a plan with a note is left approved" branch in `exec-pass`.
- [ ] **Step 3: Build app vase, and probe on the dev ship:** make a repeating event and a one-off through the calendar, file and approve a cancel action for each, and watch `GET /apps/orrery/api/exec/last` and the calendar. Record the calls and what each action's history shows.
- [ ] **Step 4: Commit** `The executor takes an event off the calendar, or skips the one occurrence`.

---

### Task 5: The gate, the docs, the release

**Files:**
- Modify: `scripts/api-matrix.py` (the executor section), `README.md`, `docs/releasing.md`, `code/version.json` (37), and in orrery-utils `docs/writing-a-client.md` (rules 3 and 14) and `common/analyst-prompt.md` with its lib cord
- Test: the gate

- [ ] **Step 1: The gate.** In the executor section, after the calendar action checks: create a repeating event and a one-off through the calendar's poke route (the section already pokes the calendar; reuse its helper), file a `calendar` action with `mode: cancel` and the one-off's id, approve it, poll the record, and check the event is gone and the action reads `done` with `off the calendar`; the same for the repeat with a `starts`, checking the other occurrences survive; a cancel naming an event that does not exist is `failed`; a cancel with no event leaves the action approved with a note in the record. Teardown removes anything left.
- [ ] **Step 2: The client guide** (orrery-utils, rule 3 "the schedule is not the fact" and rule 14's reader half): a cancellation of one occurrence writes `skipped` on the activity with that occurrence's start, and never `status`, which means the series; a one-off that is cancelled writes `status: cancelled` on the situation; when the client knows the calendar event, it may also propose a `calendar` action with `mode: cancel`, `event` the calendar's id and `starts` the occurrence, which the owner approves. Add the same two sentences to `common/analyst-prompt.md` and mirror the cord in the lib; `python3 scripts/prompt-drift.py ../orrery-utils/common` must pass.
- [ ] **Step 3: The README** gains the cancel in the executor paragraph and the two schema notes in the vocabulary section; `docs/releasing.md` gains version 37's owner steps: the calendar desk must be at its new version first (Task 1's release), then the schema merge of the three changed notes (`activity.status`, `activity.skipped`, the `calendar` payload's `mode` and `event`) through `PUT /api/schema` with the bare document.
- [ ] **Step 4: Every gate** (closure, drift, page-test, api, key, mcp, smoke, share, both unit suites). **Commit** orrery `Version 37: a cancelled occurrence has a place, and the ship can take an event off the calendar`; orrery-utils `Rule 3 and rule 14: a cancelled occurrence is skipped, not a cancelled series`.

## Self-review

- Spec coverage: `skipped` and its notes (Task 2); reconcile's retraction (Task 2); the action's `mode` and the planner (Task 3); the executor's two pokes and its failures (Task 4); the calendar's `skip-at` (Task 1); the reader's rule and the proposal (Task 5); out of scope respected (no edit mode, no series cancel, no todo deletion, no expansion in orrery).
- Placeholders: Task 1 Step 1 and Task 4 Step 1 ask the implementer to name the expansion arm and the recurrence key rather than guessing them here; both are one grep and both are reported.
- Types: `%uncalendar` used the same in Tasks 3 and 4; `body.start_ms` is the epoch ms in both; the note path matches the existing "left approved with a note" branch from version 36.
