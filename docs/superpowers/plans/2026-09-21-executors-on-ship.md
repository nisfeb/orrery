# Executors on the Ship (version 34) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Orrery version 34 carries out its own approved actions (Telegram and mail messages, calendar events, todos) and keeps the calendar's todo list and its task actions in step, so the phone client can drop those four jobs.

**Architecture:** One `exec.sig` fiber keeps two things: orrery's own beacon and the calendar desk's store. On orrery's beacon it runs the executor: claim each open action it can serve, do the one poke or HTTP call, report done or failed. On the calendar's store it runs the mirror: read the todos, reconcile them with the actions in both directions. Every decision is a pure planner in `code/lib/orrery.hoon` over the actions and the todo list, answering writer ops and calendar pokes; the fiber files them. The two desks are found through `/sys/link/` the way `self-base` finds orrery itself. The reader loses its command grammar.

**Tech Stack:** Hoon on the grubbery nexus (fibers, `keep`/`poke` roads across instances, iris), the orrery page (plain JS), Python gates.

**Spec:** `docs/superpowers/specs/2026-09-21-executors-on-ship-design.md`

## Global Constraints

- Builds run on the dev ship through the ball fast loop, verified by read-back: `<scratchpad>/build.sh <file under code/>` prints `build: vase` (Hoon compiled), `build: mime` (a data file), or `build: tang` with the error and the offending lines; only `build.status` counts. Build the lib before the app. A new fiber may need `POST $SHIP/apps/grubbery/permits/reload` with JSON `{"app": "orrery"}` and the jar `$JAR` to rise.
- Clay unit tests run on the second ship's grubbery desk: copy `code/lib/orrery.hoon` to `<the second ship's mount>/lib/orrery.hoon` and `tests/lib/generator.hoon` to `<the second ship's mount>/tests/lib/generator.hoon`, then in its dojo (read the pane first; another session may be using it; wait for a bare `~sampel-palnet:dojo>` prompt) send `|commit %grubbery`, wait for the prompt, send `-test /=grubbery=/tests/lib/generator ~`, wait for a bare prompt after new `OK`/`FAILED`/`CRASHED` lines, then read the dojo pane and `grep -aE "^(OK|FAILED|CRASHED) .*generator|expected|actual|nest-fail|find\.|mint|syntax error" | sort -u`. The pane drops lines under load; 40 OK lines at the start of this plan.
- Cross-instance addressing: a road to another instance is `[%& %& base name]` where `base` is the path from `/sys/link/<name>/dest.lanes` (see `self-base` in app.hoon near line 1776, which does it for `orrery`). The calendar claims the link name `calendar`; auspex claims `auspex`. The calendar's store and poke target are one grub, `[%& %& base %'calendar.calendar']`: it takes `[[/ %json] jon]` pokes with an `action` key (`add-event`, `edit-event`, `done-event`, `del-event`) and holds the events; keep it for news. Auspex's writer is `[%& %& base %'main.sig']`; it takes a raw noun poke with blot `[/auspex %auspex-action]` ... check the exact blot in `~/software/personal/auspex/code/nex/auspex/app.hoon` `apply` (`=([/ %auspex-action] p.sage)`) and use that; the noun is `[%send to=(set @p) subject=@t body=@t body-mime=@t prev=~ files=~ bcc=~]` with `body-mime` `''` meaning text/plain; the writer clams it with `;;(action:uc ...)` and refuses a poke from another ship (a local one passes).
- Calendar event JSON for `add-event`: `cat` (`todo`, `timed`, `allday`), `meta` (an object passed through verbatim; `name` required; `orrery`, `tags`, `note`, `location` are ours), for a todo `due_ms` and `done_ms` (epoch milliseconds), for timed `start_ms`, `end_ms` (with `fin` `to`), `zone`; for allday `span_days` and the date fields `parse-recur` expects (read `parse-event` and `parse-recur` in `<the calendar checkout>/code/nex/calendar/app.hoon` near line 3735 for the exact keys; the plan's Task 3 pins them). `done-event {id, done: <ms or null>}`, `del-event {id}`, `edit-event {id, ...the same fields as add}`; read those branches near lines 157, 267, 280.
- Consent: three lines join `weir-json` in app.hoon (`/sys/link/` is already a peek road there): poke `'/apps/shell.shell/desks/calendar.desk/'` and `'/apps/shell.shell/desks/auspex.desk/'` (subtree roads, the way the calendar's `'/apps/calendar.calendar/'` line names one), and keep on the calendar subtree. Approving them on the live ship's permits page is the owner's step at release.
- Facts and actions the mirror writes: `by` `calendar`, source `{"kind": "calendar", "id": <todo id>}`; the executor's claims and reports: `by` `ship`.
- No secret is ever served; no message text is stored beyond an approved payload; no em dashes; commits as nisfeb with no attribution lines; do not push (the controller pushes and releases).
- Every task ends with the gates that touch it green: `node scripts/page-test.js`, `python3 scripts/code-closure.py code`, and `python3 scripts/api-matrix.py $SHIP $JAR` (about fifteen minutes, block-buffered, 170 checks at the start of this plan) for tasks that change a route or a fiber.

---

## File map

- `code/lib/orrery.hoon`: a new section `::  ==  executors (version 34)` after the telegram section: `exec-config`, `+$  todo` and `todo-of`, `todos-of`, `plan-exec` (which open actions to take and the poke or call each needs), `event-json` (an action to `add-event` JSON), `plan-mirror` (the todo list against the actions: ops and pokes), `ms-of`/`da-of-ms`; the telegram section loses `tg-command`, `parse-value`, `tg-obs`.
- `code/nex/orrery/app.hoon`: `exec-last.json`, `exec.sig`, `weir-json` lines, `find-base` (link lookup by name), `poke-calendar`, `poke-auspex`, `send-telegram`, `exec-pass`, `mirror-pass`, `exec-record`; `tg-handle` loses the command branch; routes `GET /api/exec/last`, `POST /api/exec/wake`.
- `code/nex/orrery/orrery.js`, `orrery.css`: an Executor card under Settings.
- `scripts/api-matrix.py`: the stub gains a calendar instance and an auspex writer on the dev ship? No: a stub cannot stand in for another nexus instance. The executor section installs nothing; it exercises the Telegram send through the existing stub, and the calendar and auspex paths through a **fake base**: the fiber's `find-base` answers `~` on the dev ship (neither desk is installed there... check `curl -s -b $JAR $SHIP/grubbery/ball/apps/shell.shell/desks?raw=1` for `calendar.desk`; if the calendar is installed on the dev ship, the gate uses it for real and reads `calendar.calendar` back through the ball). The plan's Task 6 says which.
- `tests/lib/generator.hoon`: the unit tests.
- `README.md`, `docs/releasing.md`, `orrery-utils/docs/writing-a-client.md` (rule 11 and 14 rewritten: the ship executes; a client executor takes `chat` only; `mail` addresses a ship), `orrery-utils/telegram/README.md` (no commands).

---

### Task 1: The reader loses its commands

**Files:**
- Modify: `code/lib/orrery.hoon` (remove `tg-command`, `parse-value`, `tg-obs`)
- Modify: `code/nex/orrery/app.hoon` (`tg-handle`'s command branch)
- Modify: `tests/lib/generator.hoon` (remove `test-tg-command`), `scripts/api-matrix.py` (the `/at` checks), `README.md`, `orrery-utils/telegram/README.md`

**Interfaces:**
- Produces: a reader where every message with text goes to the gate; `tg-window`/`tg-remember` still skip a text starting `/` (a slash message is read but never becomes context: keep that, it costs nothing and a stray `/start` from Telegram's own UI is noise).

- [ ] **Step 1: Remove the test and the gate checks.** In `tests/lib/generator.hoon` delete `++  test-tg-command` whole. In `scripts/api-matrix.py` find the telegram section's `/at` update and the check `'a command writes without the model'` and its `read_today` companion check; delete the `/at` update and that check, and change the count check so it uses the question update alone.

- [ ] **Step 2: Remove the arms.** In `code/lib/orrery.hoon` delete `++  tg-command`, `++  parse-value` and `++  tg-obs` (and their comments). In `app.hoon`'s `tg-handle` delete the `=/  cmd=(unit tg-facts:orr)  (tg-command:orr msg u.who)` binding and the `?^  cmd` branch that files it. Build the lib, then the app: both `vase`.

- [ ] **Step 3: Docs.** README.md's telegram paragraph: drop the sentence about the commands. `orrery-utils/telegram/README.md`: the grammar section stays for the Python bot (it still has commands for a ship older than 29); add one line under its opening paragraph: the ship's reader has no commands; a slash message is read as text.

- [ ] **Step 4: Gates.** The second ship suite: 39 OK (one fewer). Api gate: ALL OK (the telegram section two checks shorter). Closure clean.

- [ ] **Step 5: Commit** (orrery, and orrery-utils separately): `The reader has no commands: a slash message is text` and `The ship's reader has no commands`.

---

### Task 2: Finding the two desks and the consent lines

**Files:**
- Modify: `code/nex/orrery/app.hoon` (`find-base`, `weir-json`)
- Test: `scripts/api-matrix.py`

**Interfaces:**
- Produces: `find-base |=(name=@ta (unit path))` in app.hoon beside `self-base`: the first lane in `/sys/link/<name>/dest.lanes`, `~` when the road is refused or no row; `self-base` becomes `(find-base %orrery)`. Three consent lines in `weir-json`.

- [ ] **Step 1: Generalise `self-base`.** Copy its body into `find-base` with the name as the argument (`[%& %& /sys/link/[name] %'dest.lanes']`), make `self-base` call it with `%orrery`. Build the app: `vase`. The api gate's sharing and page sections prove `self-base` still works.

- [ ] **Step 2: Consent lines.** In `weir-json`'s `poke` list add:
  ```hoon
          (line '/apps/shell.shell/desks/calendar.desk/' 'put an approved calendar action on your calendar, an approved task in its todo list, and keep the two in step. Refuse this and those actions wait for another executor')
          (line '/apps/shell.shell/desks/auspex.desk/' 'send an approved message by mail. Refuse this and mail actions wait for another executor')
  ```
  and in the `keep` list (find how `weir-json` separates poke, peek and keep; add to the keep list, or the peek list if keep rides on peek in this kernel: read `lay-inbox-road` and the calendar's `weir-json` for the shape) the calendar subtree with the why `read your todo list, so a todo you tick or type is a task the ship knows`. Build: `vase`.

- [ ] **Step 3: Gate check.** In the api gate, after the sharing section: `code, d = curl('GET', HOST + '/grubbery/ball/apps/shell.shell/desks/orrery.desk/desk/data/orrery.orrery_app/weir.json?raw=1')` and check the three roads appear in the served weir (`'/apps/shell.shell/desks/calendar.desk/' in json.dumps(d)` and the auspex one). Consent on the dev ship: the dev instance must have the new roads approved for the executor to work in Task 6; the gate's generator section already documents how (`POST /apps/grubbery/permits {action: approve-weir, app, picks, granted}` then `/apps/grubbery/permits/reload`); do that by hand on the dev ship now for the three roads and note the exact calls in the report so Task 6 can repeat them.

- [ ] **Step 4: Commit:** `The executor finds the calendar and auspex through link, and asks consent for their roads`.

---

### Task 3: The pure planners: an action to a calendar event, a message to its address

**Files:**
- Modify: `code/lib/orrery.hoon` (the executors section)
- Test: `tests/lib/generator.hoon`

**Interfaces:**
- Produces: `+$  exec-plan  [id=@ta kind=@tas target=?(%telegram %mail %calendar %todo) to=@t body=json note=@t]`: for telegram `to` is the chat id and `body` is the `sendMessage` JSON (`chat_id`, `text`); for mail `to` is the ship as text and `body` holds `subject` and `text`; for calendar and todo `body` is the `add-event` JSON and `to` is `''`. `plan-exec |=([acts=(list [id=@ta a=action]) all=(list loaded) multi=(set @t) now=@da] (list exec-plan))`: every `approved` action of kind `message` with `via` telegram or mail, `calendar`, `task`; a message whose person lacks the attribute the channel needs (`telegram` for telegram, `ship` for mail) yields a plan with `target` set and `to` `''` so the fiber reports `failed` with `note` (`person/x has no telegram attribute`); anything else is left out. `event-json |=([id=@ta a=action zone=@t] json)`; `ms-of |=(t=@da @ud)` epoch milliseconds; `da-of-ms |=(ms=@ud @da)`.

- [ ] **Step 1: Failing tests**

```hoon
++  exec-acts
  ^-  (list [id=@ta a=action:orr])
  =/  pay  |=(t=@t ^-(json (need (de:json:html t))))
  :~  ['m1' [%message 'Tell Nora' (pay '{"via": "telegram", "to": "person/nora", "text": "Dana could not call back"}') (sy ~['person/nora']) ~ 'telegram' now %approved '' ~]]
      ['m2' [%message 'Tell Bob' (pay '{"via": "mail", "to": "person/bob", "text": "hi"}') (sy ~['person/bob']) ~ 'telegram' now %approved '' ~]]
      ['m3' [%message 'Tell Eve' (pay '{"via": "telegram", "to": "person/eve", "text": "x"}') ~ ~ 'telegram' now %approved '' ~]]
      ['m4' [%message 'DM Nora' (pay '{"via": "chat", "to": "person/nora", "text": "x"}') ~ ~ 'telegram' now %approved '' ~]]
      ['c1' [%calendar 'Dinner with Sarah' (pay '{"title": "Dinner with Sarah", "starts": "2026-09-25T20:00:00Z", "ends": "2026-09-25T22:00:00Z", "location": "the usual place"}') ~ ~ 'telegram' now %approved '' ~]]
      ['c2' [%calendar 'Field day' (pay '{"title": "Field day", "starts": "2026-10-03T00:00:00Z", "ends": "2026-10-04T00:00:00Z"}') ~ ~ 'telegram' now %approved '' ~]]
      ['t1' [%task 'Call the shop' (pay '{"notes": "about the brakes"}') ~ `~2026.9.30 'generator' now %approved '' ~]]
      ['t2' [%task 'Old one' ~ ~ ~ 'generator' now %proposed '' ~]]
      ['t3' [%task 'Done one' ~ ~ ~ 'generator' now %done '' ~]]
  ==
++  exec-bodies
  ^-  (list loaded:orr)
  :~  (mkb 'person/nora' %person 'Nora' ~ ~[['telegram' s+'545179154']] now)
      (mkb 'person/bob' %person 'Bob' ~ ~[['ship' s+'~sampel-palnet']] now)
      (mkb 'person/eve' %person 'Eve' ~ ~ now)
  ==
++  test-plan-exec
  =/  plans  (plan-exec:orr exec-acts exec-bodies ~ now)
  =/  by-id  (~(gas by *(map @ta exec-plan:orr)) (turn plans |=(p=exec-plan:orr [id.p p])))
  ;:  weld
    (expect-eq !>(`(list @ta)`~['m1' 'm2' 'm3' 'c1' 'c2' 't1']) !>((turn plans |=(p=exec-plan:orr id.p))))
    (expect-eq !>(%telegram) !>(target:(~(got by by-id) 'm1')))
    (expect-eq !>('545179154') !>(to:(~(got by by-id) 'm1')))
    (expect-eq !>('Dana could not call back') !>((gs:orr body:(~(got by by-id) 'm1') 'text')))
    (expect-eq !>('545179154') !>((gs:orr body:(~(got by by-id) 'm1') 'chat_id')))
    (expect-eq !>(%mail) !>(target:(~(got by by-id) 'm2')))
    (expect-eq !>('~sampel-palnet') !>(to:(~(got by by-id) 'm2')))
    (expect-eq !>('Tell Bob') !>((gs:orr body:(~(got by by-id) 'm2') 'subject')))
    (expect-eq !>('') !>(to:(~(got by by-id) 'm3')))
    (expect-eq !>('person/eve has no telegram attribute') !>(note:(~(got by by-id) 'm3')))
    (expect-eq !>(%calendar) !>(target:(~(got by by-id) 'c1')))
    (expect-eq !>('timed') !>((gs:orr body:(~(got by by-id) 'c1') 'cat')))
    (expect-eq !>('allday') !>((gs:orr body:(~(got by by-id) 'c2') 'cat')))
    (expect-eq !>(%todo) !>(target:(~(got by by-id) 't1')))
    (expect-eq !>('todo') !>((gs:orr body:(~(got by by-id) 't1') 'cat')))
  ==
++  test-event-json
  =/  c1  (snag 4 exec-acts)
  =/  t1  (snag 6 exec-acts)
  =/  ej=json  (event-json:orr id.c1 a.c1 'America/New_York')
  =/  tj=json  (event-json:orr id.t1 a.t1 'America/New_York')
  =/  meta=json  (gj:orr ej 'meta')
  ;:  weld
    (expect-eq !>('add-event') !>((gs:orr ej 'action')))
    (expect-eq !>('timed') !>((gs:orr ej 'cat')))
    (expect-eq !>('Dinner with Sarah') !>((gs:orr meta 'name')))
    (expect-eq !>('c1') !>((gs:orr meta 'orrery')))
    (expect-eq !>(`(list @t)`~['orrery']) !>((strings:orr (ga:orr meta 'tags'))))
    (expect-eq !>('the usual place') !>((gs:orr meta 'location')))
    (expect-eq !>(1.790.366.400.000) !>((need (gn:orr ej 'start_ms'))))
    (expect-eq !>(1.790.373.600.000) !>((need (gn:orr ej 'end_ms'))))
    (expect-eq !>('to') !>((gs:orr ej 'fin')))
    (expect-eq !>('America/New_York') !>((gs:orr ej 'zone')))
    (expect-eq !>('todo') !>((gs:orr tj 'cat')))
    (expect-eq !>('Call the shop') !>((gs:orr (gj:orr tj 'meta') 'name')))
    (expect-eq !>('about the brakes') !>((gs:orr (gj:orr tj 'meta') 'note')))
    (expect-eq !>(1.790.726.400.000) !>((need (gn:orr tj 'due_ms'))))
    (expect-eq !>(1.790.366.400.000) !>((ms-of:orr ~2026.9.25..20.00.00)))
    (expect-eq !>(~2026.9.25..20.00.00) !>((da-of-ms:orr 1.790.366.400.000)))
  ==
```

The epoch numbers: 2026-09-25T20:00:00Z is 1,790,366,400 seconds after 1970 (check with `python3 -c "import datetime;print(int(datetime.datetime(2026,9,25,20,tzinfo=datetime.timezone.utc).timestamp()))"` and fix the literals if they differ; likewise 22:00 and 2026-09-30T00:00). The `action` type is `[kind title payload about due by proposed status note history]`; `mkb` is the existing fixture (`[id kind name aliases kvs at]`).

- [ ] **Step 2: Run, see `-find.plan-exec`.**

- [ ] **Step 3: Implement**

```hoon
::  ==  executors (version 34): the ship carries out its own approved
::  actions. +plan-exec says what to do for each; the fiber does it.
::
++  ms-of  |=(t=@da ^-(@ud (div (mul 1.000 (sub t ~1970.1.1)) ~s1)))
++  da-of-ms  |=(ms=@ud ^-(@da (add ~1970.1.1 (div (mul ms ~s1) 1.000))))
+$  exec-plan  [id=@ta kind=@tas target=?(%telegram %mail %calendar %todo) to=@t body=json note=@t]
::  +attr-text: a body's live string attribute, '' when none
++  attr-text
  |=  [all=(list loaded) multi=(set @t) now=@da id=@t attr=@t]
  ^-  @t
  =/  hit=(unit loaded)  (find-loaded all id)
  ?~  hit  ''
  (winner-text (fold rows.u.hit multi now) attr)
++  find-loaded
  |=  [all=(list loaded) id=@t]
  ^-  (unit loaded)
  ?~  all  ~
  ?:(=(id id.i.all) `i.all $(all t.all))
::  +whole-days: a start and an end both at midnight UTC, at least a day apart
++  whole-days
  |=  [s=@da e=@da]
  ^-  ?
  &(=(0 (mod s ~d1)) =(0 (mod e ~d1)) (gte e (add s ~d1)))
++  event-json
  |=  [id=@ta a=action zone=@t]
  ^-  json
  =/  title=@t  =/(t (gs payload.a 'title') ?:(=('' t) title.a t))
  =/  meta-base=(list [@t json])
    :~  ['name' s+title]
        ['orrery' s+id]
        ['tags' a+~[s+'orrery']]
    ==
  ?:  =(%task kind.a)
    =/  note=@t  (gs payload.a 'notes')
    %-  pairs:enjs:format
    %-  zing
    :~  ~[['action' s+'add-event'] ['cat' s+'todo']]
        :_  ~
        :-  'meta'
        (pairs:enjs:format ?:(=('' note) meta-base (snoc meta-base ['note' s+note])))
        ?~(due.a ~ ~[['due_ms' (numb:enjs:format (ms-of u.due.a))]])
    ==
  =/  s=(unit @da)  (de-iso (gs payload.a 'starts'))
  =/  e=(unit @da)  (de-iso (gs payload.a 'ends'))
  =/  start=@da  (fall s now-fallback)
  ...
```

Write the rest as the tests demand: `start` is `starts` (required; a missing one gives an event at the action's `proposed` time, which the validator never lets through anyway), `end` is `ends` or start plus an hour; `allday` when `whole-days`, then `span_days` the number of days and the date keys `parse-recur` expects for a one-off allday event (read `parse-recur`: likely `year`, `month`, `day` or a `start_ms`; the test only checks `cat`, so pin what the calendar takes and add an assertion for it); `timed` otherwise with `start_ms`, `end_ms`, `fin` `to`, `zone`. `location` goes under `meta.location` when given. `plan-exec` walks the approved actions: `message` → `via` lower-cased; `telegram` → `to` from the person's `telegram` attribute, body `{"chat_id": <to>, "text": <payload text>}`; `mail` → `to` from the person's `ship` attribute (with or without the leading `~`, normalised to have it), body `{"subject": <title>, "text": <payload text>}`; other `via` → skipped; `calendar` and `task` → `event-json` with `zone` the person/me `timezone` winner or `''` (the fiber passes it); an empty `to` for a message gets the `note` `<person> has no <attr> attribute`.

- [ ] **Step 4: Tests OK on the second ship; lib `vase`; commit:** `The executor's plans: an approved action to the poke or call that carries it out`.

---

### Task 4: The mirror planner

**Files:**
- Modify: `code/lib/orrery.hoon`
- Test: `tests/lib/generator.hoon`

**Interfaces:**
- Produces: `+$  todo  [id=@t name=@t orrery=@t done=? due=(unit @da) note=@t]`; `todos-of |=(cal=json (list todo))` from the calendar's store as the ball serves it (the `calendar.calendar` grub read back as JSON through `?blot=/json`, or its noun; Task 6 decides which the fiber reads and this arm takes the JSON shape: read `<the calendar checkout>/code/nex/calendar/app.hoon`'s JSON encoder of the store, the `events.json` route's shape: rows with `id`, `cat`, `meta` (`name`, `orrery`, `tags`, `note`), `done_ms`/`due_ms` for todos); `+$  mirror-op  $%([%writer json] [%calendar json])`; `plan-mirror |=([todos=(list todo) acts=(list [id=@ta a=action]) now=@da] (list mirror-op))` per the spec's four rules.

- [ ] **Step 1: Failing test**

```hoon
++  test-plan-mirror
  =/  acts=(list [id=@ta a=action:orr])
    :~  ['a1' [%task 'Ticked on the ship' ~ ~ ~ 'generator' now %done '' ~]]
        ['a2' [%task 'Dismissed on the ship' ~ ~ ~ 'generator' now %dismissed '' ~]]
        ['a3' [%task 'Ticked in the calendar' ~ ~ ~ 'generator' now %approved '' ~]]
        ['a4' [%task 'Due moved on the ship' ~ ~ `~2026.10.5 'generator' now %approved '' ~]]
        ['a5' [%task 'In step' ~ ~ ~ 'generator' now %approved '' ~]]
    ==
  =/  todos=(list todo:orr)
    :~  ['e1' 'Ticked on the ship' 'a1' | ~ '']
        ['e2' 'Dismissed on the ship' 'a2' | ~ '']
        ['e3' 'Ticked in the calendar' 'a3' & ~ '']
        ['e4' 'Due moved on the ship' 'a4' | `~2026.10.1 '']
        ['e5' 'In step' 'a5' | ~ '']
        ['e6' 'Buy milk' '' | `~2026.10.2 'two litres']
        ['e7' 'Already done by hand' '' & ~ '']
    ==
  =/  ops=(list mirror-op:orr)  (plan-mirror:orr todos acts now)
  =/  cal=(list json)  (murn ops |=(o=mirror-op:orr ?:(?=(%calendar -.o) `+.o ~)))
  =/  wr=(list json)  (murn ops |=(o=mirror-op:orr ?:(?=(%writer -.o) `+.o ~)))
  =/  cal-act  (turn cal |=(j=json [(gs:orr j 'action') (gs:orr j 'id')]))
  ;:  weld
    (expect !>((lien cal-act |=([a=@t i=@t] &(=('done-event' a) =('e1' i))))))
    (expect !>((lien cal-act |=([a=@t i=@t] &(=('del-event' a) =('e2' i))))))
    (expect !>((lien cal-act |=([a=@t i=@t] &(=('edit-event' a) =('e4' i))))))
    (expect !>(!(lien cal-act |=([a=@t i=@t] =('e5' i)))))
    (expect !>(!(lien cal-act |=([a=@t i=@t] =('e7' i)))))
    ::  e3: the action moves to done; e6: a task is made and the todo marked
    (expect !>((lien wr |=(j=json &(=('set-action' (gs:orr j 'op')) =('a3' (gs:orr j 'id')) =('done' (gs:orr j 'status')))))))
    (expect !>((lien wr |=(j=json &(=('act' (gs:orr j 'op')) =('Buy milk' (gs:orr (gj:orr j 'action') 'title')))))))
    (expect !>((lien wr |=(j=json &(=('act' (gs:orr j 'op')) =('approved' (gs:orr (gj:orr j 'action') 'status')))))))
    (expect !>((lien cal-act |=([a=@t i=@t] &(=('edit-event' a) =('e6' i))))))
    (expect-eq !>(1) !>((lent (skim wr |=(j=json =('act' (gs:orr j 'op')))))))
  ==
```

- [ ] **Step 2: Run, see `-find.plan-mirror`.**

- [ ] **Step 3: Implement** the four rules. The adopted task's action JSON: `kind` task, `title` the todo's name, `payload {notes}` when the note is non-empty, `due` the todo's due as ISO, `status` `approved` (the writer's `act` op takes a `status` key? check `do-act`/`fill-act-as`: an `act` op files a proposal; approval is a second `set-action`. If `act` cannot file as approved, emit `act` then a `set-action` to `approved` by `calendar` for the id the writer will assign: the id is `act-id` of the stamped action, computable in the lib with `fill-act-as` and `de-action` the way `gen-pass` does; write both ops). The edit that marks the adopted todo: `edit-event {id, cat todo, meta: {...its meta, orrery: <action id>, tags: [.., "orrery"]}, due_ms}`: read `edit-event` in the calendar to see whether it replaces the meta whole (then carry the todo's name and note) or merges. The `edit-event` for a moved due carries the action's due. `done-event {id, done: <ms now>}`; `del-event {id}`; the ticked todo's action: `set-action {id, status done, note "ticked in the calendar", by calendar}`.

- [ ] **Step 4: Tests OK; lib `vase`; commit:** `The mirror's plan: the todo list and the task actions kept in step both ways`.

---

### Task 5: The fiber, the pokes, the record

**Files:**
- Modify: `code/nex/orrery/app.hoon`
- Test: by hand on the dev ship (Task 6 writes the gate)

**Interfaces:**
- Produces: `exec.sig` (fall `[%fall %& [/ %'exec.sig'] [[/ %sig] ~]]`, `exec-last.json` fall `[%o ~]`); `exec-pass` and `mirror-pass`; `poke-calendar |=([base=path jon=json] (unit tang))`, `poke-auspex |=([base=path to=@p subject=@t body=@t] (unit tang))`, `send-telegram |=([cfg=tg-config chat=@t text=@t] [status=@ud body=@t])`; routes `GET /api/exec/last` (owner, `serve-doc`), `POST /api/exec/wake` (owner, poke `exec.sig` with `[[/ %sig] ~]`).

- [ ] **Step 1: The fiber**

```hoon
          ::  the executor (version 34): on orrery's beacon it carries out
          ::  the approved actions it can serve; on the calendar's store it
          ::  keeps the todo list and the task actions in step. It pokes
          ::  the writer, the calendar and auspex, and is poked by nothing
          ::  but the owner's wake.
          [~ %'exec.sig']
        ;<  ~  bind:m  (rise-wait:io prod "%orrery executor: failed")
        ;<  *  bind:m  (keep:io /exec (rf 0 /beacon %rev) ~)
        ;<  cal=(unit path)  bind:m  (find-base %calendar)
        ;<  *  bind:m
          ?~  cal  (pure:(fiber:fiber:nexus ,*) ~)
          (keep:io /cal [%& %& u.cal %'calendar.calendar'] ~)
        |-
        ;<  ~  bind:m  exec-pass
        ;<  ~  bind:m  mirror-pass
        ;<  *  bind:m  (take-gen-in /exec)
        $
```

`take-gen-in /exec` filters news to the `/exec` wire; news on `/cal` must also wake the loop: write `take-any-of |=(wires=(list wire) ...)` beside `take-gen-in`, or call `take-gen-in` with `/exec` and a second keep on `/exec` for the calendar (one wire, two subscriptions: `keep:io /exec road` twice is allowed if the kernel keys keeps by wire and road; check `keep` in `<the grubbery checkout>/desk/lib/fiberio.hoon`; if keyed by wire alone, use two wires and a taker that accepts either).

A calendar that is not installed at rise: the fiber keeps only orrery's beacon and `mirror-pass` answers at once; `find-base` is retried on each pass, so installing the calendar later needs no restart.

- [ ] **Step 2: The passes**

`exec-pass`: read `generator.json` (for the timezone fallback), `telegram.json` (the token), the actions, the bodies; `plans = (plan-exec:orr acts all multi now)`; for each plan: `file-ops` a `set-action` to `claimed` by `ship`; reload the actions and confirm the claimant is `ship` (the `run-merges` arm in the reconcile section does exactly this dance; copy it); then by target: `%telegram` with `to` `''` → `failed` with the note; else `send-telegram` (a `post-json` to `<api_url>/bot<token>/sendMessage` with the body; 200 and `ok` true → `done` `sent to <chat>`, else `failed` with Telegram's `description`); `%mail` → `find-base %auspex`, `~` → `failed` `auspex is not installed`; else `poke-auspex` (a `poke:io` of the raw noun `[%send (sy ~[to]) subject text '' ~ ~ ~]` with blot `[/ %auspex-action]` to `[%& %& base %'main.sig']`; a soft poke's error → `failed` with its head; else `done` `sent by mail to <ship>`); `%calendar`/`%todo` → `find-base %calendar`, `~` → `failed` `the calendar is not installed`; else `poke-calendar` (`poke-soft:io [%& %& base %'calendar.calendar'] [[/ %json] body]`); error → `failed`; else `done` `on the calendar` / `in the todo list`. Record each outcome for `exec-record`.

`mirror-pass`: `find-base %calendar`; `~` → nothing; peek the store (`peek:io [%& %& base %'calendar.calendar'] ~` gives a view; the grub's noun is the calendar's `calendar:cal` type, which orrery cannot clam; read it as JSON instead: the ball serves any grub as JSON through the `/json` tube when a marc conversion exists; from a fiber, `peek` with a blot argument? Check `peek:io`'s signature in fiberio for a `(unit blot)` conversion argument; if none, the cache grub `order.calendar-cache` or a `todos.json` the calendar could publish are the fallbacks. Decide: the plan pins the first that works and Task 6's report says which); `todos = (todos-of:orr store-json)`; `ops = (plan-mirror:orr todos acts now)`; file the writer ops through `file-ops` and each calendar op through `poke-calendar`; count them for the record.

`exec-record`: `exec-last.json` with `at`, `sent`, `placed`, `failed` (a list of `{id, title, note}` at most 20), `ticked`, `deleted`, `adopted`, `missing` (a list of `calendar`/`auspex` when `find-base` answered `~`).

- [ ] **Step 3: Routes, build, reload the dev ship, a hand probe**: approve an action of each kind on the dev ship through the API and read `exec-last.json` and the calendar (if installed on the dev ship) or the stub's `sendMessage` (the api gate's stub does not run outside the gate; start it by hand from the gate's `Stub` class, or accept a `failed` with a connection error for the hand probe and let Task 6 prove the send). Build lib and app `vase`.

- [ ] **Step 4: Commit:** `The executor fiber: approved actions carried out on the ship, and the todo list kept in step`.

---

### Task 6: The gate section, the card, the docs

**Files:**
- Modify: `scripts/api-matrix.py`, `code/nex/orrery/orrery.js`, `orrery.css`, `scripts/page-test.js`, `README.md`, `docs/releasing.md`, `orrery-utils/docs/writing-a-client.md`, `orrery-utils/telegram/README.md`

- [ ] **Step 1: Gate.** The section runs with the stub up and the telegram settings set (token `123:abc`, api_url the stub): `POST /act` a `message` `via telegram` to a person given a `telegram` attribute of `1001`, approve it, wait for `exec-last.json` to move; check the stub saw `/bot123:abc/sendMessage` with `chat_id` `1001` and the text; the action is `done` by `ship` with `sent to 1001`. A message to a person with no `telegram` attribute: `failed` with the note. A `via mail` message when auspex is absent on the dev ship: `failed` `auspex is not installed` (or, when it is installed on the dev ship, `done` and the report says so). A `calendar` action and a `task`: if the calendar is installed on the dev ship and its roads approved (Task 2's report says), `done` with `on the calendar`/`in the todo list` and the event readable through the calendar's own API (`GET /apps/calendar/api/events` or the ball's `calendar.calendar?blot=/json`) with `meta.orrery` the action id; ticking it through the calendar's API (`done-event`) moves the action to `done` within a pass; a hand-typed todo posted through the calendar's API appears as an approved task on the ship with `by` `calendar` and the todo gains the mark. If the calendar is not on the dev ship: the checks assert `failed` with `the calendar is not installed`, and the report says the mirror was proven only by the unit test; then the controller installs the calendar on the dev ship before release (a note for the controller, not this task).
- [ ] **Step 2: The card.** `executorCard(last)` under the Reconcile card: the counts, the failures with their notes, the missing desks, a wake button (`data-exec-wake`); the settings route fetches `/exec/last`; three page tests.
- [ ] **Step 3: Docs.** README: two route rows, a paragraph after the telegram one (what the ship executes, how `mail` addresses a ship, the consent roads, that the phone client's mirror must be off), the Under the hood files. `docs/releasing.md`: version 34's owner steps (approve three roads on the permits page, then reload; switch the phone client's mirror off in the same hour). Client guide: rule 11 rewritten (the ship mirrors; a client does not; a hand-typed todo is adopted by the ship), rule 14's executor half (a client executor takes `chat` only; `mail` addresses a ship through auspex; `telegram`, `mail`, `calendar`, `task` are the ship's), rule 16 unchanged. Telegram README: the executor moved to the ship; the Python executor is for a ship older than 34.
- [ ] **Step 4: Gates green** (api, page, closure, the second ship). **Commit** both repos.

---

### Task 7: Release

- [ ] `code/version.json` 34; every gate (api, key, mcp, page, smoke, closure, prompt-drift, the second ship's suites); commit `Version 34: the ship carries out its own approved actions and keeps the todo list in step`. The push, the pull onto the live ship, the consent approval on the live ship's permits page (the owner), the phone client's prompt and memory are the controller's.

## Self-review

- Spec coverage: executor (3, 5, 6), mirror (4, 5, 6), discovery and consent (2), limits (5: one claim, failed with reason, nothing retried), record and card (5, 6), reader simplified (1), the phone client's side (the controller's prompt), out of scope respected.
- Placeholders: Task 3's `event-json` body says "write the rest as the tests demand" with the rules listed; Task 5's mirror-pass names an open question (how a fiber reads another desk's typed grub as JSON) with the order to try; both are decisions for the implementer to report, not gaps in what to build.
- Types: `exec-plan`, `todo`, `mirror-op` consistent across 3, 4, 5, 6; `by` values `ship` and `calendar` consistent with the spec.
