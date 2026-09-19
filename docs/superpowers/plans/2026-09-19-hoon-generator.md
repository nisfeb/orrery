# On-Ship Generator Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** The action generator runs inside the orrery desk: whenever the state changes, the ship builds the prompt, asks the model over iris, validates the answer and files the proposals, with no Python process on any machine.

**Architecture:** A new pure library `code/lib/generator.hoon` holds the prompt builder, the digest, the request and answer codecs and the validator, all unit-tested on fixtures. The nexus gains a `gen.sig` fiber that the writer pokes after every change; it settles, compares the prompt's digest with the last pass, asks the model through `/sys/iris/` under a ten minute timer (the spike measured a 259 second answer delivered whole), and files what survives by poking the writer with `act` ops so the writer stays the one mutation path. A `generator.json` document holds the settings and the key; the page's Settings view edits it without ever reading the key back.

**Tech Stack:** Hoon (nexus fibers, `send-request:io`, behn timers), the existing `lib/orrery.hoon` helpers, `tests/lib` unit tests, `scripts/api-matrix.py` with a stub model server, the page's vanilla JS and `scripts/page-test.js`.

**Spec:** `docs/spikes/2026-09-19-iris-probe.md` (the transport and its ceiling), `orrery-utils/generator/README.md` and `orrery-utils/generator/run.py` (what a pass does, ported arm for arm), `orrery-utils/common/generator-prompt.md` (the system prompt, embedded verbatim).

## Global Constraints

- Every mutation goes through the writer (`/main.sig`): the generator files actions by poking `act` ops, never by writing `/actions` itself.
- The model call is `POST <url>/chat/completions` with `Authorization: Bearer <api_key>`, body `{"model", "max_tokens", "messages", "reasoning"?, "provider": {"zdr": true}, "usage": {"include": true}}`; no `temperature` when reasoning is on. Cache marks: the system block and the first three user blocks carry `{"cache_control": {"type": "ephemeral"}}`.
- The prompt is five pieces in this order: header + things/places/orgs/notes; people + activities; situations; open actions + recent decisions; the clock. The digest hashes the first four.
- A pass runs only when the digest differs from the last real pass, or when forced. No ceiling: a quiet week costs nothing.
- The app's timer on the iris request is ten minutes; a timer win or a status other than 200 is a failed pass, logged, never retried in a loop.
- `by` on every filed action is `generator`. At most `max_actions` (default 5) per pass. Word-overlap dedupe against open and decided titles, exactly as `same_title` in run.py.
- `GET /api/generator` never returns `api_key`; it returns `"api_key_set": true|false`. A `PUT` whose `api_key` is absent or empty keeps the stored key.
- The new road is `/sys/iris/` in the poke list of `weir-json`, with the why "ask a model over HTTPS when the state changes, so it can propose actions. Refuse this and the on-ship generator is off; orrery-utils can still run it from a computer".
- `code/version.json` goes to 18 in the last task only. Gates before the bump: unit tests on wex, `api-matrix.py`, `key-matrix.py`, `mcp-matrix.py`, `page-smoke.py`, `ship-share-matrix.py`, all `ALL OK`.
- No secret in the repo, in a test, in a gate's output or in a log line. Commit messages carry no AI attribution. Markdown is not hard-wrapped and uses no em dashes.

---

## File Structure

> Executed 2026-09-19. One departure from the structure below, found in Task 1: the ball imports libraries with `/<` and clay with `/+`, and one file cannot say both, so the generator's arms live at the end of `code/lib/orrery.hoon` instead of a `generator.hoon` of their own. The tests in `tests/lib/generator.hoon` alias the library as `gen`. Everything else is as written.

- Create `code/lib/generator.hoon`: pure. The system prompt as a cord, `phase`, `norm-words`, `same-title`, `line`, `build-parts`, `digest`, `chat-body`, `answer-of`, `parse-answer`, `validate`, `en-config`, `de-config`.
- Create `tests/lib/generator.hoon`: unit tests for every arm above, on a fixture state built in the test file.
- Modify `code/lib/orrery.hoon`: `is-closed` counts `cancelled`.
- Modify `code/nex/orrery/app.hoon`: the `generator.json` and `generator-last.json` documents, the `/sys/iris/` road, the `gen.sig` fiber, the writer's poke after a change, the `set-generator` op, routes `GET /api/generator`, `PUT /api/generator`, `GET /api/generator/last`, `POST /api/generate`.
- Modify `code/nex/orrery/orrery.js` and `orrery.css`: the Generator card on Settings; `scripts/page-test.js` checks.
- Modify `scripts/api-matrix.py`: a generator section with a stub model server.
- Modify `README.md`, `docs/releasing.md`, `orrery-utils/generator/README.md`, `code/version.json`.

---

### Task 1: The library's small arms: phase, title words, same-title

**Files:**
- Create: `code/lib/generator.hoon`
- Create: `tests/lib/generator.hoon`
- Modify: `code/lib/orrery.hoon` (`is-closed`, around line 585)

**Interfaces:**
- Consumes: `orrery.hoon`'s `de-iso`, `en-iso`, `gs`, `gj`, `ga`, `strings`, `row`, `obs`.
- Produces: `phase:gen`, `norm-words:gen`, `same-title:gen`, `winner-text:gen`.

- [ ] **Step 1: Write the failing tests**

```hoon
::  Unit tests for /lib/generator: the pure half of the on-ship
::  generator, on fixtures. Nothing here touches the ship.
::
/+  *test, orr=orrery, gen=generator
|%
++  jo   |=(t=@t ^-(json (need (de:json:html t))))
++  now  ~2026.9.18..12.00.00
::  a winners map with one single-valued attr: what +fold answers
++  win
  |=  kvs=(list [k=@t v=@t])
  ^-  (map @t (list row:orr))
  %-  ~(gas by *(map @t (list row:orr)))
  %+  turn  kvs
  |=  [k=@t v=@t]
  :-  k
  :_  ~
  ^-  row:orr
  [%'x' [k s+v now ~ 100 ['test' 'fx'] 'test' now] & '']
::  ==  phase
::
++  test-phase
  ;:  weld
    (expect-eq !>('closed') !>((phase:gen (win ~[['status' 'closed'] ['ends' '2099-01-01T00:00:00Z']]) now)))
    (expect-eq !>('cancelled') !>((phase:gen (win ~[['status' 'cancelled']]) now)))
    (expect-eq !>('over') !>((phase:gen (win ~[['starts' '2026-09-18T11:00:00Z'] ['ends' '2026-09-18T11:30:00Z']]) now)))
    (expect-eq !>('under way') !>((phase:gen (win ~[['starts' '2026-09-18T11:00:00Z'] ['ends' '2026-09-18T13:00:00Z']]) now)))
    (expect-eq !>('upcoming') !>((phase:gen (win ~[['status' 'under way'] ['starts' '2026-12-05T19:00:00Z']]) now)))
    (expect-eq !>('open') !>((phase:gen (win ~) now)))
  ==
::  ==  titles
::
++  test-same-title
  ;:  weld
    (expect !>((same-title:gen 'Call the shop about the Subaru' 'call the shop about the subaru.')))
    (expect !>((same-title:gen 'Call John\'s shop about the Subaru' 'Call the shop about the Subaru')))
    (expect !>(!(same-title:gen 'Pay the electricity bill' 'Call the shop about the Subaru')))
    (expect !>(!(same-title:gen '' 'Call the shop')))
    (expect-eq !>(~['call' 'the' 'shop']) !>((norm-words:gen 'Call the SHOP!')))
  ==
--
```

The `row` shape above must match `+$  row` in `lib/orrery.hoon` (read it: an obs with subject, attr, value, at, until, conf, source, by, seen, plus the live flag and note). Adjust the constructor once, in `win`, and every test uses it.

- [ ] **Step 2: Run the tests to verify they fail**

Run, on wex with the desk's code tree written by the fast loop (docs/releasing.md section 7): `-test /~wex/grubbery/<rev>/tests/lib/generator ~`
Expected: a build failure, `generator` not found.

- [ ] **Step 3: Write the library's first arms**

```hoon
::  generator: the on-ship action generator, the pure half. The prompt
::  from the state, the digest that says whether anything the model
::  would see has changed, the request and the answer as OpenRouter
::  speaks them, and the validator that keeps only what the schema and
::  the ship allow. orrery-utils/generator/run.py is the reference, arm
::  for arm; the nexus does the asking and the filing.
::
/-  *orrery
/+  orr=orrery
|%
::  +winner-text: the current string value of an attribute, or ''
::
++  winner-text
  |=  [winners=(map @t (list row:orr)) name=@t]
  ^-  @t
  =/  w=(list row:orr)  (fall (~(get by winners) name) ~)
  ?~  w  ''
  ?:(?=([%s *] value.obs.i.w) p.value.obs.i.w '')
::  +phase: a situation's phase from its times: closed or cancelled when
::  status says so, over once its end has passed, under way once its
::  start has, upcoming while its start is ahead, else its status or open
::
++  phase
  |=  [winners=(map @t (list row:orr)) now=@da]
  ^-  @t
  =/  st=@t  (winner-text winners 'status')
  ?:  |(=('closed' st) =('cancelled' st))  st
  =/  end=@t  =/(e (winner-text winners 'ended') ?:(=('' e) (winner-text winners 'ends') e))
  =/  start=@t  =/(s (winner-text winners 'started') ?:(=('' s) (winner-text winners 'starts') s))
  =/  now-iso=@t  (en-iso:orr now)
  ?:  &(!=('' end) (lte-iso end now-iso))  'over'
  ?:  &(!=('' start) (lte-iso start now-iso))  'under way'
  ?:  !=('' start)  'upcoming'
  ?:(=('' st) 'open' st)
::  +lte-iso: ISO 8601 UTC strings of the same shape compare as text
::
++  lte-iso  |=([a=@t b=@t] ^-(? !(gth-cord a b)))
++  gth-cord
  |=  [a=@t b=@t]
  ^-  ?
  =/  ta=tape  (trip a)
  =/  tb=tape  (trip b)
  |-
  ?~  ta  |
  ?~  tb  &
  ?:  =(i.ta i.tb)  $(ta t.ta, tb t.tb)
  (gth i.ta i.tb)
::  +norm-words: a title as lowercase words, punctuation gone
::
++  norm-words
  |=  t=@t
  ^-  (list @t)
  =/  low=tape  (cass (trip t))
  =/  clean=tape
    %+  turn  low
    |=(c=@ ?:(|(&((gte c 'a') (lte c 'z')) &((gte c '0') (lte c '9'))) c ' '))
  %+  murn  (split-spaces clean)
  |=(w=tape ?:(=(~ w) ~ `(crip w)))
++  split-spaces
  |=  t=tape
  ^-  (list tape)
  =|  cur=tape
  =|  out=(list tape)
  |-
  ?~  t  (flop ?:(=(~ cur) out [(flop cur) out]))
  ?:  =(' ' i.t)  $(t t.t, cur ~, out ?:(=(~ cur) out [(flop cur) out]))
  $(t t.t, cur [i.t cur])
::  +same-title: the same words, or four fifths of the shorter title's
::  words (at least two) in the longer
::
++  same-title
  |=  [a=@t b=@t]
  ^-  ?
  =/  ka=(set @t)  (sy (norm-words a))
  =/  kb=(set @t)  (sy (norm-words b))
  ?:  |(=(~ ka) =(~ kb))  |
  ?:  =(ka kb)  &
  =/  both=@ud  ~(wyt in (~(int in ka) kb))
  =/  short=@ud  (min ~(wyt in ka) ~(wyt in kb))
  (gte both (max 2 (div (mul 8 short) 10)))
--
```

`cass` lowercases a tape (stdlib). If `/-  *orrery` does not exist as a sur file in this desk, drop the line: `lib/orrery.hoon` carries its own types and `row:orr` reaches them.

- [ ] **Step 4: Make `is-closed` count cancelled**

In `code/lib/orrery.hoon`, replace the body of `++  is-closed`:

```hoon
++  is-closed
  |=  winners=(map @t (list row))
  ^-  ?
  =/  w=(list row)  (fall (~(get by winners) 'status') ~)
  ?~  w  |
  ?|  =(value.obs.i.w [%s 'closed'])
      =(value.obs.i.w [%s 'cancelled'])
  ==
```

Add to `tests/lib/orrery.hoon`, next to the existing `is-closed` case if there is one, else as a new test:

```hoon
++  test-is-closed-counts-cancelled
  =/  w  (win ~[['status' 'cancelled']])
  (expect !>((is-closed:orr w)))
```

(`win` as defined in the generator tests; copy the helper into this file if it is not there.)

- [ ] **Step 5: Run the tests to verify they pass**

Run both suites on wex. Expected: every `test-` arm passes; the count in `tests/lib/orrery.hoon` grows by one.

- [ ] **Step 6: Commit**

```bash
git add code/lib/generator.hoon tests/lib/generator.hoon code/lib/orrery.hoon tests/lib/orrery.hoon
git commit -m "lib/generator: phase, title words and same-title; a cancelled situation is closed"
```

---

### Task 2: The prompt builder and the digest

**Files:**
- Modify: `code/lib/generator.hoon`
- Modify: `tests/lib/generator.hoon`

**Interfaces:**
- Consumes: `loaded:orr` (`[id=bid body rows=(list row)]`), `action:orr`, `fold:orr`, `en-action:orr`, `is-open:orr`, `multi-of:orr`, `phase`, `winner-text`.
- Produces: `++  build-parts` returning `(list @t)` of exactly five cords; `++  digest` returning `@ux`; `++  line`.

- [ ] **Step 1: Write the failing tests**

Add to `tests/lib/generator.hoon` a fixture and the cases. The fixture mirrors `STATE` in `orrery-utils/generator/test_run.py`:

```hoon
++  fixture
  ^-  [all=(list loaded:orr) acts=(list [id=@ta a=action:orr]) schema=json]
  =/  b  |=([id=@t kind=@t name=@t kvs=(list [@t @t])] ^-(loaded:orr [id [kind name ~ ~ now] (rows kvs)]))
  :+  :~  (b 'person/me' 'person' 'dana' ~[['timezone' 'America/New_York']])
          (b 'person/sarah' 'person' 'Sarah' ~[['status' 'on jury duty']])
          (b 'thing/subaru' 'thing' 'the Subaru' ~[['status' 'at the shop, awaiting diagnosis']])
          (b 'situation/2026-09-16-breakdown' 'situation' 'The breakdown' ~[['started' '2026-09-16T22:00:00Z']])
          (b 'situation/2026-12-05-meeting' 'situation' 'Parent meeting' ~[['starts' '2026-12-05T19:00:00Z'] ['ends' '2026-12-05T20:00:00Z']])
          (b 'situation/2026-09-10-walk' 'situation' 'Walk' ~[['status' 'closed'] ['ended' '2026-09-10T15:00:00Z']])
          (b 'activity/ballet' 'activity' 'Ballet' ~[['last' '2026-09-16T20:45:00Z'] ['next' '2026-09-18T20:45:00Z']])
      ==
    :~  ['a1' (need (rights:de-action:orr (jo '{"kind":"task","title":"Call the shop about the Subaru","about":["thing/subaru"],"status":"approved","by":"mcp","proposed":"2026-09-17T02:10:00Z"}') now 'mcp'))]
    ==
  (jo '{"kinds":{},"actions":["task","note","message","home"],"payloads":{"message":{"via":"required: telegram","to":"required: a body id","text":"required"},"home":{"service":"required","entity_id":"required","data":"optional"}}}')
++  rows
  |=  kvs=(list [k=@t v=@t])
  ^-  (list row:orr)
  (turn kvs |=([k=@t v=@t] ^-(row:orr [%'x' [k s+v now ~ 100 ['test' 'fx'] 'test' now] & ''])))
++  test-build-parts
  =/  f  fixture
  =/  parts=(list @t)  (build-parts:gen all.f acts.f ~ schema.f now 'America/New_York' 5)
  =/  p0=@t  (snag 0 parts)
  =/  p1=@t  (snag 1 parts)
  =/  p2=@t  (snag 2 parts)
  =/  p3=@t  (snag 3 parts)
  =/  p4=@t  (snag 4 parts)
  ;:  weld
    (expect-eq !>(5) !>((lent parts)))
    (expect !>((has-sub p0 'The owner is person/me. Propose at most 5 actions.')))
    (expect !>((has-sub p0 'Payload shapes:')))
    (expect !>((has-sub p0 '"via": "required: telegram"')))
    (expect !>((has-sub p0 'things:')))
    (expect !>((has-sub p1 'persons:')))
    (expect !>((has-sub p1 'activities:\0a  activity/ballet | Ballet | last=2026-09-16T20:45:00Z; next=2026-09-18T20:45:00Z')))
    (expect !>((has-sub p2 'situation/2026-12-05-meeting | Parent meeting | upcoming')))
    (expect !>(!(has-sub p2 'situation/2026-09-10-walk')))
    (expect !>((has-sub p3 'Open actions')))
    (expect !>((has-sub p3 'task | Call the shop about the Subaru | about thing/subaru')))
    (expect-eq !>('Now: 2026-09-18T12:00:00Z, timezone America/New_York. Answer with the JSON object.') !>(p4))
    (expect-eq !>((digest:gen parts)) !>((digest:gen (build-parts:gen all.f acts.f ~ schema.f (add now ~m5) 'America/New_York' 5))))
    (expect !>(!=((digest:gen parts) (digest:gen (build-parts:gen all.f ~ ~ schema.f now 'America/New_York' 5)))))
  ==
++  has-sub  |=([hay=@t pin=@t] ^-(? ?=(^ (find (trip pin) (trip hay)))))
```

`rights:de-action` above stands for whichever accessor unwraps `de-action`'s `(each action @t)`; read `de-action` and use `p` of the `%&` case (write a two-line helper `++  act-of` in the test file if that is clearer). The `body` constructor `[kind name ~ ~ now]` must match `+$  body` in `lib/orrery.hoon` (kind, name, aliases, ship, created); adjust once.

- [ ] **Step 2: Run the tests to verify they fail**

Expected: `build-parts` not found.

- [ ] **Step 3: Write the builder and the digest**

Add to `code/lib/generator.hoon`, after `same-title`:

```hoon
::  the pieces of the user prompt and the count of decided actions shown
++  recent   60
++  max-bodies  300
::  +ref-or-text: a value as one token: a ref's id, a string, or its JSON
::
++  ref-or-text
  |=  v=json
  ^-  @t
  ?:  ?=([%o *] v)  =/(r (~(get by p.v) 'ref') ?:(?=([~ %s *] r) p.u.r (en:json:html v)))
  ?:(?=([%s *] v) p.v (en:json:html v))
::  +line: one body on one line: id | name (| phase for a situation) |
::  attr=value; ... with every attribute, sorted, and a multi as a list
::
++  line
  |=  [l=loaded:orr multi=(set @t) now=@da]
  ^-  @t
  =/  winners=(map @t (list row:orr))  (fold:orr rows.l multi now)
  =/  bits=(list @t)
    %+  murn  (sort ~(tap by winners) |=([[a=@t *] [b=@t *]] (aor a b)))
    |=  [k=@t w=(list row:orr)]
    ^-  (unit @t)
    ?~  w  ~
    ?:  ?=(~ value.obs.i.w)  ~
    =/  shown=@t
      ?.  (~(has in multi) k)  (ref-or-text value.obs.i.w)
      (join-cords ', ' (turn w |=(r=row:orr (ref-or-text value.obs.r))))
    `(rap 3 k '=' (end [3 120] (squeeze shown)) ~)
  =/  head=@t  (rap 3 id.l ' | ' name.body.l ~)
  =?  head  =(%situation kind.body.l)  (rap 3 head ' | ' (phase winners now) ~)
  ?~(bits head (rap 3 head ' | ' (join-cords '; ' bits) ~))
++  join-cords
  |=  [sep=@t xs=(list @t)]
  ^-  @t
  ?~  xs  ''
  (roll t.xs |=([x=@t acc=_i.xs] (rap 3 acc sep x ~)))
::  +squeeze: runs of whitespace as one space
::
++  squeeze
  |=  t=@t
  ^-  @t
  (crip (join-tapes " " (split-spaces (turn (trip t) |=(c=@ ?:(|(=(c 10) =(c 9) =(c 13)) ' ' c))))))
++  join-tapes
  |=  [sep=tape xs=(list tape)]
  ^-  tape
  ?~  xs  ""
  (roll t.xs |=([x=tape acc=_i.xs] (weld acc (weld sep x))))
::  +build-parts: the five pieces, the least changing first and the
::  clock last, so the first four are the same text from one pass to the
::  next while nothing changed. decided are the done, dismissed and
::  failed actions, oldest first; the last +recent are shown.
::
++  build-parts
  |=  $:  all=(list loaded:orr)
          acts=(list [id=@ta a=action:orr])
          decided=(list [id=@ta a=action:orr])
          schema=json
          now=@da
          tz=@t
          limit=@ud
      ==
  ^-  (list @t)
  =/  multi=(set @t)  (multi-of:orr schema)
  =/  shown=(list loaded:orr)  (scag max-bodies all)
  =/  hidden=(set @t)
    %-  sy
    %+  murn  shown
    |=  l=loaded:orr
    ?.  =(%situation kind.body.l)  ~
    =/  ph=@t  (phase (fold:orr rows.l multi now) now)
    ?:(|(=('closed' ph) =('cancelled' ph) =('over' ph)) `id.l ~)
  =/  section
    |=  kinds=(list @tas)
    ^-  (list @t)
    %-  zing
    %+  turn  kinds
    |=  k=@tas
    =/  rows=(list loaded:orr)
      (skim shown |=(l=loaded:orr &(=(k kind.body.l) !(~(has in hidden) id.l))))
    ?~  rows  ~
    :-  (cat 3 ?:(=(%activity k) 'activities' (cat 3 k 's')) ':')
    (turn rows |=(l=loaded:orr (cat 3 '  ' (line l multi now))))
  =/  head=(list @t)
    :~  (rap 3 'The owner is person/me. Propose at most ' (scot %ud limit) ' actions.' ~)
        (cat 3 'Action kinds: ' (join-cords ', ' =/(a (strings:orr (ga:orr schema 'actions')) ?~(a ~['task' 'note'] a))))
    ==
  =/  payloads=json  (gj:orr schema 'payloads')
  =?  head  ?=([%o *] payloads)
    %+  weld  head
    :-  'Payload shapes:'
    %+  turn  ~(tap by p.payloads)
    |=([k=@t v=json] (rap 3 '  ' k ': ' (en:json:html v) ~))
  =/  p0=@t  (join-cords '\0a' (weld head (section ~[%thing %place %org %note])))
  =/  p1=@t  (join-cords '\0a' (section ~[%person %activity]))
  =/  p2=@t  (join-cords '\0a' (section ~[%situation]))
  =/  open=(list @t)
    :-  'Open actions (proposed or approved, do not duplicate):'
    %+  murn  acts
    |=  [id=@ta a=action:orr]
    ?.  (is-open:orr a)  ~
    `(rap 3 '  ' kind.a ' | ' title.a ' | about ' (join-cords ', ' ~(tap in about.a)) ~)
  =/  done=(list @t)
    :-  'Recent decisions (do not propose these again):'
    %+  turn  (slag (sub (lent decided) (min recent (lent decided))) decided)
    |=([id=@ta a=action:orr] (rap 3 '  ' status.a ' | ' kind.a ' | ' title.a ~))
  =/  p3=@t  (join-cords '\0a' (weld open done))
  =/  p4=@t  (rap 3 'Now: ' (en-iso:orr now) ', timezone ' ?:(=('' tz) 'unknown' tz) '. Answer with the JSON object.' ~)
  ~[p0 p1 p2 p3 p4]
::  +digest: a hash of everything but the clock
::
++  digest
  |=  parts=(list @t)
  ^-  @ux
  (sham (join-cords '\0a' (scag 4 parts)))
```

`\0a` in a cord literal is a newline in Hoon; if the build rejects it, build the separator with `(crip ~[10])` once as `++  nl`. `en-iso:orr` renders `@da` as the ISO UTC string the ship uses everywhere (check its name in `lib/orrery.hoon`; `en-time` wraps it as JSON).

- [ ] **Step 4: Run the tests to verify they pass**

Expected: `test-build-parts` passes. If the `persons:` label or spacing differs, match the Python (`kind + 's'` except `activities`); the Python is the reference.

- [ ] **Step 5: Commit**

```bash
git add code/lib/generator.hoon tests/lib/generator.hoon
git commit -m "lib/generator: the prompt in five pieces and the digest of the stable four"
```

---

### Task 3: The request and the answer as OpenRouter speaks them

**Files:**
- Modify: `code/lib/generator.hoon`
- Modify: `tests/lib/generator.hoon`

**Interfaces:**
- Produces: `++  system-prompt` (`@t`), `++  chat-body` `|=([cfg=config parts=(list @t)] json)`, `++  answer-of` `|=(resp=json (each [text=@t usage=json] @t))`, `++  parse-answer` `|=(text=@t (unit json))`, `+$  config`, `++  de-config`, `++  en-config-masked`.

- [ ] **Step 1: Write the failing tests**

```hoon
++  cfg
  ^-  config:gen
  (de-config:gen (jo '{"enabled":true,"url":"https://openrouter.ai/api/v1","model":"moonshotai/kimi-k3","api_key":"sk-test","reasoning":{"effort":"high"},"max_tokens":32000,"max_actions":5}'))
++  test-chat-body
  =/  body=json  (chat-body:gen cfg ~['a' 'b' 'c' 'd' 'e'])
  =/  msgs  (ga:orr body 'messages')
  =/  sys=json  (snag 0 msgs)
  =/  usr=json  (snag 1 msgs)
  =/  blocks  (ga:orr usr 'content')
  ;:  weld
    (expect-eq !>('moonshotai/kimi-k3') !>((gs:orr body 'model')))
    (expect-eq !>(32.000) !>((need (gn:orr body 'max_tokens'))))
    (expect-eq !>([%o (my ~[['zdr' b+&]])]) !>((gj:orr body 'provider')))
    (expect-eq !>([%o (my ~[['include' b+&]])]) !>((gj:orr body 'usage')))
    (expect-eq !>(~) !>((gj:orr body 'temperature')))
    (expect-eq !>([%o (my ~[['effort' s+'high']])]) !>((gj:orr body 'reasoning')))
    (expect-eq !>('system') !>((gs:orr sys 'role')))
    (expect-eq !>(5) !>((lent blocks)))
    (expect-eq !>(~[& & & | |]) !>((turn blocks |=(b=json ?=(^ (~(get by ?>(?=([%o *] b) p.b)) 'cache_control'))))))
  ==
++  test-answer-of
  =/  resp=json  (jo '{"choices":[{"message":{"content":"{\\"actions\\":[]}"}}],"usage":{"prompt_tokens":8556,"completion_tokens":2125,"cost":0.0959}}')
  =/  got  (answer-of:gen resp)
  ;:  weld
    (expect !>(?=(%& -.got)))
    (expect-eq !>('{"actions":[]}') !>(?>(?=(%& -.got) text.p.got)))
    (expect !>(?=(%| -.(answer-of:gen (jo '{"error":{"message":"no endpoints"}}')))))
    (expect-eq !>(`(jo '{"actions":[]}')) !>((parse-answer:gen '```json\0a{"actions":[]}\0a```')))
    (expect-eq !>(~) !>((parse-answer:gen 'not json at all')))
  ==
++  test-config-mask
  =/  shown=json  (en-config-masked:gen cfg)
  ;:  weld
    (expect-eq !>(~) !>((gj:orr shown 'api_key')))
    (expect-eq !>(b+&) !>((gj:orr shown 'api_key_set')))
    (expect-eq !>('moonshotai/kimi-k3') !>((gs:orr shown 'model')))
    (expect-eq !>(|) !>(enabled:(de-config:gen (jo '{}'))))
    (expect-eq !>(8.000) !>(max-tokens:(de-config:gen (jo '{}'))))
  ==
```

- [ ] **Step 2: Run the tests to verify they fail**

Expected: `config` not found.

- [ ] **Step 3: Write the config, the request and the answer arms**

Add to `code/lib/generator.hoon`:

```hoon
::  +$  config: generator.json as the nexus reads it. Off until the owner
::  turns it on and gives a key. The key is read here and nowhere else.
::
+$  config
  $:  enabled=?
      url=@t
      model=@t
      api-key=@t
      reasoning=json
      max-tokens=@ud
      max-actions=@ud
      timezone=@t
  ==
++  de-config
  |=  j=json
  ^-  config
  :*  =/(e (gj:orr j 'enabled') ?:(?=([%b *] e) p.e |))
      =/(u (gs:orr j 'url') ?:(=('' u) 'https://openrouter.ai/api/v1' u))
      =/(m (gs:orr j 'model') ?:(=('' m) 'moonshotai/kimi-k3' m))
      (gs:orr j 'api_key')
      =/(r (gj:orr j 'reasoning') ?:(?=(~ r) [%o (my ~[['effort' s+'high']])] r))
      (fall (gn:orr j 'max_tokens') 8.000)
      (fall (gn:orr j 'max_actions') 5)
      (gs:orr j 'timezone')
  ==
::  +en-config-masked: what the owner reads back: everything but the key
::
++  en-config-masked
  |=  c=config
  ^-  json
  %-  pairs:enjs:format
  :~  ['enabled' b+enabled.c]
      ['url' s+url.c]
      ['model' s+model.c]
      ['api_key_set' b+!=('' api-key.c)]
      ['reasoning' reasoning.c]
      ['max_tokens' (numb:enjs:format max-tokens.c)]
      ['max_actions' (numb:enjs:format max-actions.c)]
      ['timezone' s+timezone.c]
  ==
::  +reasoning-on: any reasoning object but {"enabled": false}
::
++  reasoning-on
  |=  r=json
  ^-  ?
  ?.  ?=([%o *] r)  |
  !=(`(unit json)``b+|` (~(get by p.r) 'enabled'))
::  +chat-body: the request. Every piece of the user prompt is a content
::  block; the system block and the first three user blocks carry a
::  cache mark, so a call minutes after another reads every piece up to
::  the first changed one from the cache. No temperature when the model
::  reasons; the router reports the cost with the usage.
::
++  chat-body
  |=  [c=config parts=(list @t)]
  ^-  json
  =/  mark=json  [%o (my ~[['cache_control' [%o (my ~[['type' s+'ephemeral']])]]])]
  =/  block  |=([t=@t marked=?] ^-(json [%o (~(gas by ?:(marked ?>(?=([%o *] mark) p.mark) ~)) ~[['type' s+'text'] ['text' s+t]])]))
  =/  blocks=(list json)
    =/  n=@ud  0
    |-
    ?~  parts  ~
    [(block i.parts (lth n 3)) $(parts t.parts, n +(n))]
  =/  on=?  (reasoning-on reasoning.c)
  %-  pairs:enjs:format
  %-  zing
  :~  :~  ['model' s+model.c]
          ['max_tokens' (numb:enjs:format max-tokens.c)]
          ['messages' a+~[[%o (my ~[['role' s+'system'] ['content' a+~[(block system-prompt &)]]])] [%o (my ~[['role' s+'user'] ['content' a+blocks]])]]]
          ['provider' [%o (my ~[['zdr' b+&]])]]
          ['usage' [%o (my ~[['include' b+&]])]]
      ==
      ?:(on ~[['reasoning' reasoning.c]] ~[['temperature' (numb:enjs:format 0)]])
  ==
::  +answer-of: the model's text and the usage out of a chat completion,
::  or why there is none
::
++  answer-of
  |=  resp=json
  ^-  (each [text=@t usage=json] @t)
  =/  choices  (ga:orr resp 'choices')
  ?~  choices
    =/  err=@t  (gs:orr (gj:orr resp 'error') 'message')
    [%| ?:(=('' err) 'the model answered without choices' err)]
  =/  content=@t  (gs:orr (gj:orr i.choices 'message') 'content')
  ?:  =('' content)
    [%| ?:(=('length' (gs:orr i.choices 'finish_reason')) 'the model ran out of tokens before answering' 'the model answered without content')]
  [%& content (gj:orr resp 'usage')]
::  +parse-answer: the first JSON object in the text, fences ignored
::
++  parse-answer
  |=  text=@t
  ^-  (unit json)
  =/  t=tape  (trip text)
  =/  start=(unit @ud)  (find "{" t)
  ?~  start  ~
  =/  end=@ud  (lent t)
  |-
  ?:  (lte end u.start)  ~
  =/  cut=tape  (scag (sub end u.start) (slag u.start t))
  ?:  =('}' (rear cut))
    =/  got=(unit json)  (de:json:html (crip cut))
    ?^(got got ~)
  $(end (dec end))
```

The system prompt, as a cord, goes in the same file. It is `orrery-utils/common/generator-prompt.md` verbatim:

```hoon
++  system-prompt
  ^-  @t
  '''
  You are the analyst for orrery, a model of one person's world kept on their own ship. You read the state and propose what should be done about it. You never write facts; other clients do that. You propose actions, and the owner approves or dismisses each one.

  What you are given.
  The state: every body with its current attributes (people with status, location and relationships; things; places; orgs; situations with their times and participants; activities with their schedule, last and next occurrence), the open situations, the open actions, and the schema with its notes and the payload shapes for each action kind.
  The recent decisions: actions done, dismissed or failed lately, with their titles. Do not propose these again, or a rewording of them. A dismissal is the owner saying no.
  The time now, and the owner's timezone.

  What to propose.
  Only what the owner would want done and has not done: a call to make, a thing to buy or bring, a message to send someone, a reminder ahead of a deadline, a preparation for something upcoming, a follow-up on something that stalled. An open situation with nothing being done about it, an activity whose next occurrence needs something, a person whose status calls for a reply, a delivery that never arrived.
  Few and good. Zero is a fine answer. Never propose more than the limit given.
  An action's kind is one of the kinds the schema lists. Its payload follows the shape the schema gives for that kind, exactly; a message names who it is for as a body id and says what to send in the owner's own voice, short; a home action names a Home Assistant service and entity. A task needs only a title and, when there is one, a due time.
  "about" names the bodies the action concerns, by id, at most a few. "due" is ISO 8601 UTC, only when the timing matters.
  Respect what the facts say about time: an occurrence in the past is over; a situation that is upcoming has not happened; "last" is the most recent occurrence and "next" the nearest one ahead.
  Do not invent facts, people, places or events. Do not propose things the owner cannot act on. Do not moralise.

  Answer with one JSON object and nothing else:
  {"actions": [{"kind": "task", "title": "...", "about": ["kind/slug"], "due": "...", "payload": {...}, "why": "one sentence"}],
   "notes": ["anything you noticed that is not an action: a fact that looks wrong, a duplicate, a missing piece"]}
  "why" is for the owner's eyes on the page; keep it to one sentence. Notes are optional and short.
  '''
```

Triple-quote cords keep the newlines; the two-space indent inside is stripped by the parser (verify with a test that `system-prompt` starts with `You are the analyst`).

- [ ] **Step 4: Run the tests to verify they pass**

Expected: the three new tests pass. `parse-answer` walks the text from the first `{` to the last `}` and shortens the tail until it parses; a test with trailing chatter after the object passes too.

- [ ] **Step 5: Commit**

```bash
git add code/lib/generator.hoon tests/lib/generator.hoon
git commit -m "lib/generator: the config, the request with cache marks, the answer and the system prompt"
```

---

### Task 4: The validator

**Files:**
- Modify: `code/lib/generator.hoon`
- Modify: `tests/lib/generator.hoon`

**Interfaces:**
- Produces: `++  validate` `|=([answer=json known=(set @t) taken=(list @t) schema=json limit=@ud] [acts=(list json) notes=(list @t)])`. Each element of `acts` is the JSON an `act` op takes (`kind`, `title`, `about`, `payload`, `due`), before `fill-act-as` stamps `proposed` and `by`.

- [ ] **Step 1: Write the failing test**

The cases are `test_validation` and `test_limit` in `orrery-utils/generator/test_run.py`, one for one:

```hoon
++  test-validate
  =/  f  fixture
  =/  known=(set @t)  (sy (turn all.f |=(l=loaded:orr id.l)))
  =/  taken=(list @t)  ~['Call the shop about the Subaru' 'Pay Utility Co $142.50' 'Tell Sarah the car is at the shop']
  =/  answer=json
    %-  jo
    '''
    {"actions": [
      {"kind": "task", "title": "Ask the shop for a diagnosis estimate", "about": ["thing/subaru"], "due": "2026-09-19T13:00:00Z", "why": "the car has sat two days"},
      {"kind": "task", "title": "Call the shop about the Subaru", "about": ["thing/subaru"]},
      {"kind": "message", "title": "Tell Sarah the car is at the shop", "payload": {"via": "telegram", "to": "person/sarah", "text": "x"}},
      {"kind": "message", "title": "Wish Sarah luck at jury duty", "about": ["person/sarah"], "payload": {"via": "telegram", "to": "person/sarah", "text": "Good luck today"}},
      {"kind": "message", "title": "Ping the mechanic", "payload": {"to": "person/mechanic"}},
      {"kind": "email", "title": "Email the shop"},
      {"kind": "task", "title": "Buy a new car", "about": ["thing/tesla"]},
      {"kind": "home", "title": "Porch light on", "payload": {"service": "light.turn_on", "entity_id": "light.porch"}}
    ], "notes": ["the breakdown situation has no ended"]}
    '''
  =/  got  (validate:gen answer known taken schema.f 5)
  =/  titles=(list @t)  (turn acts.got |=(a=json (gs:orr a 'title')))
  =/  joined=@t  (join-cords:gen ' ' notes.got)
  ;:  weld
    (expect-eq !>(~['Ask the shop for a diagnosis estimate' 'Wish Sarah luck at jury duty' 'Porch light on']) !>(titles))
    (expect-eq !>('the car has sat two days') !>((gs:orr (gj:orr (snag 0 acts.got) 'payload') 'why')))
    (expect-eq !>('2026-09-19T13:00:00Z') !>((gs:orr (snag 0 acts.got) 'due')))
    (expect !>((has-sub joined 'already open or decided: Call the shop about the Subaru')))
    (expect !>((has-sub joined 'payload lacks via, text')))
    (expect !>((has-sub joined 'kind email')))
    (expect !>((has-sub joined 'thing/tesla')))
    (expect !>((has-sub joined 'model note: the breakdown situation has no ended')))
    (expect-eq !>(3) !>((lent acts:(validate:gen (jo '{"actions":[{"kind":"task","title":"Task 1"},{"kind":"task","title":"Task 2"},{"kind":"task","title":"Task 3"},{"kind":"task","title":"Task 4"}]}') known ~ schema.f 3))))
  ==
```

- [ ] **Step 2: Run the test to verify it fails**

Expected: `validate` not found.

- [ ] **Step 3: Write the validator**

```hoon
::  +validate: what the answer keeps. A kind the schema lists (task and
::  note when it lists none), a title, not a rewording of anything open
::  or decided, every about body known, every required payload key
::  present, a due that parses, the why in the payload for the page; at
::  most limit, looking at twice that. Notes name what was dropped and
::  carry the model's own notes.
::
++  validate
  |=  [answer=json known=(set @t) taken=(list @t) schema=json limit=@ud]
  ^-  [acts=(list json) notes=(list @t)]
  =/  kinds=(set @t)  =/(a (strings:orr (ga:orr schema 'actions')) (sy ?~(a ~['task' 'note'] a)))
  =/  payloads=json  (gj:orr schema 'payloads')
  =/  in=(list json)  (scag (mul 2 limit) (ga:orr answer 'actions'))
  =|  acts=(list json)
  =|  notes=(list @t)
  |-
  ?:  |(?=(~ in) (gte (lent acts) limit))
    =/  said=(list @t)
      (turn (scag 10 (ga:orr answer 'notes')) |=(n=json (cat 3 'model note: ' (end [3 200] (ref-or-text n)))))
    [(flop acts) (weld (flop notes) said)]
  =/  a=json  i.in
  ?.  ?=([%o *] a)  $(in t.in)
  =/  kind=@t  =/(k (cass-cord (gs:orr a 'kind')) ?:(=('' k) 'task' k))
  =/  title=@t  (end [3 200] (gs:orr a 'title'))
  ?:  |(!(~(has in kinds) kind) =('' title))
    $(in t.in, notes [(rap 3 'dropped: kind ' kind ' or no title (' (end [3 40] title) ')' ~) notes])
  ?:  (lien taken |=(t=@t (same-title title t)))
    $(in t.in, notes [(cat 3 'dropped as already open or decided: ' title) notes])
  =/  about=(list @t)  (turn (strings:orr (ga:orr a 'about')) cass-cord)
  =/  bad=(list @t)  (skip about |=(b=@t (~(has in known) b)))
  ?^  bad
    $(in t.in, notes [(rap 3 'dropped ' title ': names bodies that do not exist: ' (join-cords ', ' bad) ~) notes])
  =/  payload=json  =/(p (gj:orr a 'payload') ?:(?=([%o *] p) p [%o ~]))
  =/  shape=json  (gj:orr payloads kind)
  =/  missing=(list @t)
    ?.  ?=([%o *] shape)  ~
    %+  murn  ~(tap by p.shape)
    |=  [k=@t v=json]
    ?.  ?=([%s *] v)  ~
    ?.  =('required' (end [3 8] p.v))  ~
    ?:((~(has by ?>(?=([%o *] payload) p.payload)) k) ~ `k)
  ?^  missing
    $(in t.in, notes [(rap 3 'dropped ' title ': payload lacks ' (join-cords ', ' missing) ~) notes])
  =/  why=@t  (end [3 300] (gs:orr a 'why'))
  =?  payload  !=('' why)  [%o (~(put by ?>(?=([%o *] payload) p.payload)) 'why' s+why)]
  =/  due=(unit @da)  (de-iso:orr (gs:orr a 'due'))
  =/  row=json
    %-  pairs:enjs:format
    %-  zing
    :~  :~  ['kind' s+kind]
            ['title' s+title]
            ['about' a+(turn (scag 20 about) |=(b=@t `json`s+b))]
            ['payload' payload]
        ==
        ?~(due ~ ~[['due' (en-time:orr u.due)]])
    ==
  $(in t.in, acts [row acts], taken [title taken])
++  cass-cord  |=(t=@t ^-(@t (crip (cass (trip t)))))
```

- [ ] **Step 4: Run the test to verify it passes**

Expected: `test-validate` passes with the same three survivors as the Python test.

- [ ] **Step 5: Commit**

```bash
git add code/lib/generator.hoon tests/lib/generator.hoon
git commit -m "lib/generator: the validator, arm for arm with run.py"
```

---

### Task 5: The settings document and its routes

**Files:**
- Modify: `code/nex/orrery/app.hoon` (`on-load` fall list; the writer's `apply`; the dispatch; new arms `do-set-generator`, `serve-generator`, `serve-set-generator`, `serve-generator-last`)
- Modify: `scripts/api-matrix.py` (a new section at the end, before the summary)

**Interfaces:**
- Consumes: `de-config:gen`, `en-config-masked:gen`, `read-json`, `over:io`, `rf`, `own`, `send-json`, `send-err`.
- Produces: `generator.json` at the nexus root (a `%fall` with `{"enabled": false}`), `generator-last.json` (a `%fall` with `{}`), `GET /api/generator` (masked), `PUT /api/generator` (merge; empty or absent key keeps the stored one), `GET /api/generator/last`.

- [ ] **Step 1: Write the failing gate section**

Append to `scripts/api-matrix.py` before the final summary lines (find where `fails` is reported):

```python
# ---- the on-ship generator: its settings ----
code, d = owner('GET', '/generator')
check('generator settings read', code == 200 and d.get('enabled') is False and 'api_key' not in d and d.get('api_key_set') is False, (code, d))
code, d = owner('PUT', '/generator', {'enabled': False, 'model': 'moonshotai/kimi-k3', 'api_key': 'sk-gate-secret', 'max_actions': 2})
check('generator settings written', code == 200, (code, d))
time.sleep(0.5)
code, d = owner('GET', '/generator')
check('the key is never read back', code == 200 and 'api_key' not in d and d.get('api_key_set') is True and d.get('model') == 'moonshotai/kimi-k3' and d.get('max_actions') == 2, (code, d))
code, d = owner('PUT', '/generator', {'model': 'deepseek/deepseek-v4.1-flash'})
time.sleep(0.5)
code, d = owner('GET', '/generator')
check('a write without the key keeps it', d.get('api_key_set') is True and d.get('model') == 'deepseek/deepseek-v4.1-flash', d)
code, d = curl('GET', API + '/generator', jar=None)
check('the settings are the owner\'s', code == 403, (code, d))
code, d = owner('GET', '/generator/last')
check('the last pass reads as an object', code == 200 and isinstance(d, dict), (code, d))
```

`owner` is the gate's existing helper for owner-cookie calls (read the file: it wraps `curl` with `API + path`).

- [ ] **Step 2: Run the gate to verify the section fails**

Run: `python3 scripts/api-matrix.py http://localhost:8080 /tmp/wex.cookies`
Expected: the new checks FAIL with 404 `no such route`.

- [ ] **Step 3: The documents, the op and the routes**

In `on-load`'s fall list, next to `clients.json`:

```hoon
          ::  the on-ship generator: its settings (the key lives here and
          ::  is never served), and what its last pass did
          [%fall %& [/ %'generator.json'] [[/ %json] [%o (my ~[['enabled' b+|]])]]]
          [%fall %& [/ %'generator-last.json'] [[/ %json] [%o ~]]]
```

In `apply`, next to `set-policy`:

```hoon
  ?:  =('set-generator' op)  (do-set-generator jon)
```

The op merges over what is stored, keeps the key when the incoming one is blank, and moves no beacon (settings are not model state):

```hoon
::  +do-set-generator: merge the owner's generator settings over the
::  stored ones. A blank or missing api_key keeps the stored key, so the
::  page can save every other field without holding the secret.
::
++  do-set-generator
  |=  jon=json
  =/  m  (fiber:fiber:nexus ,?)
  ^-  form:m
  =/  doc=json  (gj:orr jon 'doc')
  ?.  ?=([%o *] doc)  (refuse 'set-generator' 'doc: expected an object')
  ;<  cur=json  bind:m  (read-json (rf 0 / %'generator.json'))
  =/  base=(map @t json)  ?:(?=([%o *] cur) p.cur ~)
  =/  incoming=(map @t json)  p.doc
  =?  incoming  =('' (gs:orr doc 'api_key'))  (~(del by incoming) 'api_key')
  =/  merged=json  [%o (~(uni by base) incoming)]
  ;<  ~  bind:m  (over:io (rf 0 / %'generator.json') [[/ %json] merged])
  ;<  ~  bind:m  (note-by 'set-generator' & '' 'http')
  (pure:m |)
```

`note-by` records the op in `/tr/log` the way the other ops do. Answering `|` (unchanged) keeps the beacon still.

The routes, in the dispatch before the 404:

```hoon
  ?:  &(=('GET' meth) ?=([%api %generator ~] suffix))        (own (serve-generator eyre-id))
  ?:  &(=('PUT' meth) ?=([%api %generator ~] suffix))        (own (serve-set-doc eyre-id 'set-generator' jon))
  ?:  &(=('GET' meth) ?=([%api %generator %last ~] suffix))  (own (serve-doc eyre-id %'generator-last.json'))
```

and the masked read:

```hoon
::  +serve-generator: the settings without the key
::
++  serve-generator
  |=  eyre-id=@ta
  =/  m  (fiber:fiber:nexus ,~)
  ^-  form:m
  ;<  doc=json  bind:m  (read-json (rf 1 / %'generator.json'))
  (send-json eyre-id 200 (en-config-masked:gen (de-config:gen doc)))
```

Add `gen=generator` to the app's `/+` imports next to `orr=orrery`.

- [ ] **Step 4: Write it to wex and run the gate**

Fast loop: `write-text` the app, `?info=1` reads `bang: null`. Then the gate. Expected: the six new checks pass, and every earlier check still does.

- [ ] **Step 5: Commit**

```bash
git add code/nex/orrery/app.hoon scripts/api-matrix.py
git commit -m "The generator's settings document: written whole but for the key, never read back with it"
```

---

### Task 6: The pass: the gen fiber, the iris call, the filing

**Files:**
- Modify: `code/nex/orrery/app.hoon` (`weir-json`, `on-load`, `on-file`, the writer loop, new arms `gen-pass`, `ask-model`, `gen-note`; the route `POST /api/generate`)

**Interfaces:**
- Consumes: `build-parts:gen`, `digest:gen`, `chat-body:gen`, `answer-of:gen`, `parse-answer:gen`, `validate:gen`, `de-config:gen`, `load-bodies`, `load-actions`, `fill-act-as:orr`, `send-request:io`, `set-timer:io`, `cancel-timer:io`, `poke-soft:io`.
- Produces: the `/gen.sig` fiber; the writer's poke to it after every change; `POST /api/generate` (owner) forcing a pass; `generator-last.json` holding `{"at", "rev", "digest", "skipped", "filed", "dropped", "notes", "usage", "error", "seconds"}`.

- [ ] **Step 1: Write the failing gate section**

Append to `scripts/api-matrix.py` after Task 5's section. The gate runs a stub model on a port the ship can reach and points the generator at it:

```python
# ---- the on-ship generator: a pass against a stub model ----
import http.server, socketserver
STUB_PORT = 8099
CANNED = {'choices': [{'message': {'content': json.dumps({'actions': [
    {'kind': 'task', 'title': 'Ask the shop for a diagnosis estimate', 'about': ['thing/subaru'], 'why': 'gate'},
    {'kind': 'task', 'title': 'Call the shop about the Subaru', 'about': ['thing/subaru']},
    {'kind': 'task', 'title': 'Buy a new car', 'about': ['thing/tesla']}], 'notes': ['stub note']})}}],
    'usage': {'prompt_tokens': 10, 'completion_tokens': 5, 'cost': 0.0001}}
seen = []
class Stub(http.server.BaseHTTPRequestHandler):
    def do_POST(self):
        n = int(self.headers.get('content-length', 0))
        seen.append(json.loads(self.rfile.read(n)))
        out = json.dumps(CANNED).encode()
        self.send_response(200); self.send_header('content-type', 'application/json'); self.send_header('content-length', str(len(out))); self.end_headers(); self.wfile.write(out)
    def log_message(self, *a): pass
srv = socketserver.TCPServer(('127.0.0.1', STUB_PORT), Stub)
threading.Thread(target=srv.serve_forever, daemon=True).start()
owner('POST', '/observe', {'bodies': [{'id': 'thing/subaru', 'name': 'the Subaru'}], 'observations': []})
owner('PUT', '/generator', {'enabled': True, 'url': 'http://127.0.0.1:%d' % STUB_PORT, 'api_key': 'sk-stub', 'reasoning': {'enabled': False}, 'max_actions': 5})
time.sleep(0.5)
code, d = owner('POST', '/generate')
check('a forced pass answers ok', code == 200 and d.get('ok') is True, (code, d))
deadline = time.time() + 60
last = {}
while time.time() < deadline:
    code, last = owner('GET', '/generator/last')
    if isinstance(last, dict) and last.get('at'):
        break
    time.sleep(1)
check('the pass wrote its record', last.get('filed') == 1 and last.get('dropped') == 2 and 'stub note' in ' '.join(last.get('notes', [])), last)
check('the stub saw the prompt with cache marks and no temperature', seen and seen[0].get('model') and 'temperature' not in seen[0] and seen[0]['messages'][1]['content'][0].get('cache_control'), seen[:1])
check('the key went in the header, not the body', 'sk-stub' not in json.dumps(seen[0]) if seen else False)
code, acts = owner('GET', '/actions?status=open')
mine = [a for a in acts if a.get('by') == 'generator' and a.get('title') == 'Ask the shop for a diagnosis estimate']
check('the surviving proposal is filed by generator', len(mine) == 1 and mine[0]['payload'].get('why') == 'gate', mine)
n = len(seen)
code, d = owner('POST', '/generate')
time.sleep(3)
check('a second forced pass with the same state skips the model', len(seen) == n, (n, len(seen)))
owner('POST', '/observe', {'bodies': [], 'observations': [{'subject': 'thing/subaru', 'attr': 'status', 'value': 'fixed', 'source': {'kind': 'user', 'id': 'gate'}}]})
deadline = time.time() + 60
while time.time() < deadline and len(seen) == n:
    time.sleep(1)
check('a change wakes the generator on its own', len(seen) == n + 1, (n, len(seen)))
for a in mine:
    owner('POST', '/actions/' + a['id'], {'status': 'dismissed', 'by': 'gate'})
owner('PUT', '/generator', {'enabled': False})
srv.shutdown()
```

The stub's `seen[0]['messages'][1]['content'][0]` is the first user block; it carries the mark. The gate dismisses what it filed and turns the generator off at the end, so a rerun is clean. The wake-on-change check tolerates the settle delay (see step 3).

- [ ] **Step 2: Run the gate to verify the section fails**

Expected: `POST /generate` answers 404.

- [ ] **Step 3: The road, the fiber, the pass**

The road, in `weir-json`'s poke list after `/sys/ames/registry`:

```hoon
          (line '/sys/iris/' 'ask a model over HTTPS when the state changes, so it can propose actions. Refuse this and the on-ship generator is off; orrery-utils can still run it from a computer')
```

The fiber's file in `on-load`, next to `sync.sig`:

```hoon
          [%fall %& [/ %'gen.sig'] [[/ %sig] ~]]
```

(match the exact shape the other `.sig` files use in the list.)

In `on-file`, a new rail, modelled on `sync.sig`: it waits for a poke, settles for twenty seconds so a burst of writes is one pass, then runs. A poke carrying `{"force": true}` runs regardless of the digest.

```hoon
          ::  the generator: woken by the writer after a change and by
          ::  POST /api/generate. It settles, then runs one pass; a pass
          ::  is skipped while the prompt it would send is the one it
          ::  sent last. Nothing here writes model state: proposals go
          ::  to the writer as act ops.
          [~ %'gen.sig']
        ;<  ~  bind:m  (rise-wait:io prod "%orrery generator: failed")
        |-
        ;<  [* =sage:tarball]  bind:m  take-poke-from:io
        =/  force=?  ?&(=([/ %json] p.sage) =([%b &] (gj:orr (fall (mole |.(!<(json (need-vase:tarball q.sage)))) [%o ~]) 'force')))
        ;<  now=@da  bind:m  get-time:io
        ;<  ~  bind:m  (set-timer:io /settle (add now ~s20))
        ;<  *  bind:m  take-poke-from:io
        ;<  ~  bind:m  (cancel-timer:io /settle)
        ;<  ~  bind:m  (gen-pass force)
        $
```

If `take-poke-from:io` cannot be used to wait on a timer wake this way, use the `fetch-hdr` wait pattern from the spike (a fiber function over `input:fiber:nexus` that finishes on `[/ %timer-wake]`): copy it into `++  wait-settle`.

The writer's poke, in the `main.sig` loop after `bump-beacon`:

```hoon
        ;<  changed=?  bind:m  (apply from sage)
        ;<  ~  bind:m  ?.(changed (pure:m ~) bump-beacon)
        ;<  ~  bind:m  ?.(changed (pure:m ~) (poke-gen |))
        $
```

with

```hoon
::  +poke-gen: wake the generator fiber, softly: a jailed install has
::  no fiber to wake, and the writer must never fail for it
::
++  poke-gen
  |=  force=?
  =/  m  (fiber:fiber:nexus ,~)
  ^-  form:m
  ;<  *  bind:m  (poke-soft:io (rf 0 / %'gen.sig') [[/ %json] [%o (my ~[['force' b+force]])]])
  (pure:m ~)
```

The route (owner), in the dispatch:

```hoon
  ?:  &(=('POST' meth) ?=([%api %generate ~] suffix))       (own (serve-generate eyre-id))
```

```hoon
++  serve-generate
  |=  eyre-id=@ta
  =/  m  (fiber:fiber:nexus ,~)
  ^-  form:m
  ;<  err=(unit tang)  bind:m  (poke-soft:io (rf 1 / %'gen.sig') [[/ %json] [%o (my ~[['force' b+&]])]])
  ?^  err  (send-err eyre-id 500 'the generator fiber refused the poke')
  (send-json eyre-id 200 (pairs:enjs:format ~[['ok' b+&]]))
```

The pass itself, at the root (so `rf 0`):

```hoon
::  +gen-pass: one pass. Read the settings; off means nothing. Read the
::  state the way the state view does, build the prompt, and stop when
::  its digest is the last pass's unless forced. Ask the model under a
::  ten minute timer, validate, file each survivor as an act op under
::  by generator, and record what happened in generator-last.json.
::
++  gen-pass
  |=  force=?
  =/  m  (fiber:fiber:nexus ,~)
  ^-  form:m
  ;<  cfg-json=json  bind:m  (read-json (rf 0 / %'generator.json'))
  =/  cfg=config:gen  (de-config:gen cfg-json)
  ?.  enabled.cfg  (pure:m ~)
  ?:  =('' api-key.cfg)  (gen-record ~ 0 0 0 ~['no api_key set'] ~ `'no api_key set' 0)
  ;<  now=@da  bind:m  get-time:io
  ;<  schema=json  bind:m  (read-json (rf 0 / %'schema.json'))
  ;<  all=(list loaded:orr)  bind:m  (load-bodies 0)
  ;<  acts=(list [id=@ta a=action:orr])  bind:m  (load-actions 0)
  =/  decided=(list [id=@ta a=action:orr])
    %+  sort  (skim acts |=([* a=action:orr] ?=(?(%done %dismissed %failed) status.a)))
    |=([[* a=action:orr] [* b=action:orr]] (lth proposed.a proposed.b))
  =/  me=(unit loaded:orr)  (find-loaded all 'person/me')
  =/  tz=@t
    =/  from-me=@t  ?~(me '' (winner-text:gen (fold:orr rows.u.me (multi-of:orr schema) now) 'timezone'))
    ?:(=('' from-me) timezone.cfg from-me)
  =/  parts=(list @t)  (build-parts:gen all acts decided schema now tz max-actions.cfg)
  =/  dg=@ux  (digest:gen parts)
  ;<  last=json  bind:m  (read-json (rf 0 / %'generator-last.json'))
  ;<  rev=json  bind:m  (read-json (rf 0 /beacon %rev))
  ?:  &(!force =((gs:orr last 'digest') (scot %ux dg)))
    (gen-record `dg 0 0 0 ~['nothing the model would see has changed: no pass'] ~ ~ 0 & rev)
  ;<  got=[status=@ud body=@t secs=@ud]  bind:m  (ask-model cfg parts)
  ?.  =(200 status.got)
    (gen-record `dg 0 0 0 ~ ~ `(rap 3 'the model answered ' (scot %ud status.got) ': ' (end [3 200] body.got) ~) secs.got | rev)
  =/  resp=json  (fall (de:json:html body.got) [%o ~])
  =/  ans  (answer-of:gen resp)
  ?:  ?=(%| -.ans)  (gen-record `dg 0 0 0 ~ ~ `p.ans secs.got | rev)
  =/  parsed=(unit json)  (parse-answer:gen text.p.ans)
  ?~  parsed  (gen-record `dg 0 0 0 ~ usage.p.ans `'the answer was not JSON' secs.got | rev)
  =/  known=(set @t)  (sy (turn all |=(l=loaded:orr id.l)))
  =/  taken=(list @t)
    %+  weld  (murn acts |=([* a=action:orr] ?.((is-open:orr a) ~ `title.a)))
    (turn decided |=([* a=action:orr] title.a))
  =/  v  (validate:gen u.parsed known taken schema max-actions.cfg)
  =/  filed=@ud  0
  |-
  ?~  acts.v
    ;<  ~  bind:m  (gen-record `dg filed (sub (lent (ga:orr u.parsed 'actions')) filed) 0 notes.v usage.p.ans ~ secs.got | rev)
    (pure:m ~)
  =/  stamped=json  (fill-act-as:orr i.acts.v now 'generator')
  ;<  err=(unit tang)  bind:m
    (poke-soft:io (rf 0 / %'main.sig') [[/ %json] (pairs:enjs:format ~[['op' s+'act'] ['action' stamped]])])
  $(acts.v t.acts.v, filed ?~(err +(filed) filed))
```

Record what the pass did (the digest is stored as text so the skip compares strings):

```hoon
++  gen-record
  |=  $:  dg=(unit @ux)  filed=@ud  dropped=@ud  unused=@ud  notes=(list @t)
          usage=json  error=(unit @t)  secs=@ud  skipped=?  rev=json
      ==
  =/  m  (fiber:fiber:nexus ,~)
  ^-  form:m
  ;<  now=@da  bind:m  get-time:io
  ;<  last=json  bind:m  (read-json (rf 0 / %'generator-last.json'))
  ::  a skip keeps the digest of the last real pass; a pass writes its own
  =/  keep=@t  ?:(skipped (gs:orr last 'digest') ?~(dg (gs:orr last 'digest') (scot %ux u.dg)))
  =/  doc=json
    %-  pairs:enjs:format
    :~  ['at' (en-time:orr now)]
        ['rev' rev]
        ['digest' s+keep]
        ['skipped' b+skipped]
        ['filed' (numb:enjs:format filed)]
        ['dropped' (numb:enjs:format dropped)]
        ['notes' a+(turn notes |=(n=@t `json`s+n))]
        ['usage' usage]
        ['error' ?~(error ~ s+u.error)]
        ['seconds' (numb:enjs:format secs)]
    ==
  (over:io (rf 0 / %'generator-last.json') [[/ %json] doc])
```

The `unused` argument exists only to keep the two record call sites in the pass symmetrical; drop it if the compiler complains about an unused face and adjust the calls. The model call is the spike's arm, parameterised:

```hoon
::  +ask-model: one POST to the model with the app's own ten minute
::  timer. iris has no timeout: a timer win is status 0.
::
++  ask-model
  |=  [cfg=config:gen parts=(list @t)]
  =/  m  (fiber:fiber:nexus ,[status=@ud body=@t secs=@ud])
  ^-  form:m
  =/  =request:http
    :^  %'POST'  (cat 3 url.cfg '/chat/completions')
      :~  ['content-type' 'application/json']
          ['authorization' (cat 3 'Bearer ' api-key.cfg)]
      ==
    `(as-octs:mimes:html (en:json:html (chat-body:gen cfg parts)))
  ;<  t0=@da  bind:m  get-time:io
  ;<  ~  bind:m  (send-request:io request)
  ;<  ~  bind:m  (set-timer:io /model (add t0 ~m10))
  ;<  res=(unit client-response:iris)  bind:m
    |=  input:fiber:nexus
    :+  ~  q.state
    ?+  in  [%skip ~]
        ~  [%wait ~]
        [~ %veto *]  [%done ~]
        [~ %poke * *]
      ?:  =([/ %timer-wake] p.sage.u.in)
        ?.(?=([%model *] !<(path q.sage.u.in)) [%skip ~] [%done ~])
      ?.  =([/ %http-response] p.sage.u.in)  [%skip ~]
      =/  resp=client-response:iris  !<(client-response:iris q.sage.u.in)
      ?:(?=(%cancel -.resp) [%done ~] [%done `resp])
    ==
  ;<  ~  bind:m  (cancel-timer:io /model)
  ;<  t1=@da  bind:m  get-time:io
  =/  secs=@ud  (div (sub t1 t0) ~s1)
  ?~  res  (pure:m [0 'no answer before the timer' secs])
  ?.  ?=(%finished -.u.res)  (pure:m [0 'not finished' secs])
  (pure:m [status-code.response-header.u.res ?~(full-file.u.res '' q.data.u.full-file.u.res) secs])
```

`find-loaded` is a two-line search over the list by id; write it next to `load-bodies`. The trailing `/chat/completions` on the url matches the settings document's `url` being the API base, as in orrery-utils.

- [ ] **Step 4: Consent on wex, then the gate**

Write the app with the fast loop; `?info=1` must read `bang: null`. The new road needs consent: approve the weir on `/apps/grubbery/permits` with every road in orrery's ask (`asks.json` lists them), then `POST /apps/grubbery/permits/reload {"app": "<orrery's app path>"}`, then `?info=1` shows `/sys/iris/` under `weir.poke`. Run the gate. Expected: every check in both new sections passes, and the earlier sections too.

- [ ] **Step 5: Commit**

```bash
git add code/nex/orrery/app.hoon scripts/api-matrix.py
git commit -m "The generator runs on the ship: woken by the writer, a pass under a ten minute timer, proposals filed by generator"
```

---

### Task 7: The Settings card on the page

**Files:**
- Modify: `code/nex/orrery/orrery.js` (`settings`, `refresh`, the click handler, `editing`)
- Modify: `code/nex/orrery/orrery.css`
- Modify: `scripts/page-test.js`

**Interfaces:**
- Consumes: `GET /api/generator`, `PUT /api/generator`, `POST /api/generate`, `GET /api/generator/last`.
- Produces: `settings(schema, policy, generator, last)`.

- [ ] **Step 1: Write the failing page tests**

Append to `scripts/page-test.js` before the final `console.log('ALL OK')`:

```js
const gen = { enabled: true, url: 'https://openrouter.ai/api/v1', model: 'moonshotai/kimi-k3', api_key_set: true, reasoning: { effort: 'high' }, max_tokens: 32000, max_actions: 5, timezone: '' };
const genLast = { at: '2026-09-19T01:07:41Z', filed: 3, dropped: 1, skipped: false, notes: ['model note: the trip is stale'], usage: { cost: 0.0229, prompt_tokens: 6621, completion_tokens: 1404 }, seconds: 17, error: null };
const genSettings = render.settings({ kinds: {} }, { auto: [] }, gen, genLast);
ok('the generator card shows the settings with the key masked', genSettings.includes('<h2>Generator</h2>') && genSettings.includes('name="model" value="moonshotai/kimi-k3"') && genSettings.includes('a key is set') && !genSettings.includes('sk-'));
ok('the generator card offers a run and a save', genSettings.includes('data-generate="1"') && genSettings.includes('data-save-generator="1"'));
ok('the last pass is summarised', genSettings.includes('3 filed, 1 dropped') && genSettings.includes('$0.0229') && genSettings.includes('the trip is stale'));
ok('an untouched generator renders off', render.settings({ kinds: {} }, {}, { enabled: false, api_key_set: false }, {}).includes('name="enabled">') && render.settings({ kinds: {} }, {}, { enabled: false, api_key_set: false }, {}).includes('no key set'));
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `node scripts/page-test.js`
Expected: FAIL at the first generator check (the card does not exist).

- [ ] **Step 3: The card, the wiring, the styles**

In `orrery.js`, change `settings`:

```js
  // the generator card: every setting but the key, which is written and
  // never read; a run-now button; what the last pass did
  function generatorCard(g, last) {
    g = g || {}; last = last || {};
    var out = '<div class="card"><h2>Generator</h2><div id="generator">' +
      '<p><label class="box"><input type="checkbox" name="enabled"' + (g.enabled ? ' checked' : '') + '> on: a pass runs when the state changes</label></p>' +
      '<p><label class="field">API base <input name="url" value="' + esc(g.url || '') + '" placeholder="https://openrouter.ai/api/v1"></label> ' +
      '<label class="field">model <input name="model" value="' + esc(g.model || '') + '" placeholder="moonshotai/kimi-k3"></label></p>' +
      '<p><label class="field">API key <input name="api_key" type="password" placeholder="' + (g.api_key_set ? 'a key is set; leave blank to keep it' : 'no key set') + '"></label> ' +
      '<label class="field">reasoning effort <input name="effort" value="' + esc((g.reasoning && g.reasoning.effort) || '') + '" placeholder="high, medium, low, or off"></label></p>' +
      '<p><label class="field">max tokens <input name="max_tokens" value="' + esc(g.max_tokens || '') + '"></label> ' +
      '<label class="field">max actions <input name="max_actions" value="' + esc(g.max_actions || '') + '"></label></p>' +
      '<p><button data-save-generator="1">save generator</button><button data-generate="1">run a pass now</button></p></div>';
    if (last.at) {
      var u = last.usage || {};
      out += '<p class="muted">Last pass ' + fmtTime(last.at) + ': ' + (last.skipped ? 'skipped, nothing changed' :
        (last.error ? 'failed: ' + esc(last.error) : (last.filed || 0) + ' filed, ' + (last.dropped || 0) + ' dropped' +
        (u.cost != null ? ', $' + Number(u.cost).toFixed(4) : '') + (last.seconds != null ? ', ' + last.seconds + ' s' : ''))) + '</p>';
      (last.notes || []).forEach(function (n) { out += '<p class="muted">' + esc(n) + '</p>'; });
    }
    return out + '</div>';
  }
  function settings(schema, policy, generator, last) {
    return '<h1>Settings</h1>' + generatorCard(generator, last) +
      '<div class="card"><h2>schema.json</h2><textarea id="schema" aria-label="schema.json">' + esc(JSON.stringify(schema, null, 2)) + '</textarea>' +
      '<p><button data-save="schema">save schema</button></p></div>' +
      '<div class="card"><h2>policy.json</h2><textarea id="policy" aria-label="policy.json">' + esc(JSON.stringify(policy, null, 2)) + '</textarea>' +
      '<p><button data-save="policy">save policy</button></p></div>';
  }
```

In `refresh`, the settings route fetches four things:

```js
    else if (r.name === 'settings') p = Promise.all([api('/schema'), api('/policy'), api('/generator'), api('/generator/last')]).then(function (d) { view.innerHTML = settings(d[0], d[1], d[2], d[3]); });
```

In the click handler, two new branches before `dismissToken`:

```js
    } else if (b.dataset.saveGenerator) {
      var g = generatorForm();
      post('/generator', g, 'PUT').then(function () { say('generator saved'); later(); }).catch(function (e) { say(e.message, true); });
    } else if (b.dataset.generate) {
      post('/generate', {}).then(function () { say('pass started; the last pass line updates when it ends'); setTimeout(refresh, 30000); }).catch(function (e) { say(e.message, true); });
```

and the form reader next to `mintForm`:

```js
  // the generator form as the API takes it; a blank key is left out so
  // the stored one stays; "off" reasoning is {"enabled": false}
  function generatorForm() {
    function val(name) { var el = view.querySelector('#generator input[name="' + name + '"]'); return el ? el.value.trim() : ''; }
    var effort = val('effort').toLowerCase();
    var g = { enabled: !!view.querySelector('#generator input[name="enabled"]:checked'), url: val('url'), model: val('model'),
      reasoning: effort === 'off' ? { enabled: false } : { effort: effort || 'high' },
      max_tokens: parseInt(val('max_tokens'), 10) || 8000, max_actions: parseInt(val('max_actions'), 10) || 5 };
    if (val('api_key')) g.api_key = val('api_key');
    return g;
  }
```

`editing()` already covers INPUT elements, so a beacon bump does not wipe the form while it is being typed in. In `orrery.css`, the existing `#mint .field` and `.box` rules apply; generalise their selectors to `#mint .field, #generator .field` and `#mint .box, #generator .box` in both the base rules and the phone block.

- [ ] **Step 4: Run the page tests, then the smoke gate**

Run: `node scripts/page-test.js` then `python3 scripts/page-smoke.py http://localhost:8080 /tmp/wex.cookies`. Expected: `ALL OK` on both. Open `/apps/orrery#settings` on wex in a browser: the card renders, save round-trips without the key, run-now starts a pass.

- [ ] **Step 5: Commit**

```bash
git add code/nex/orrery/orrery.js code/nex/orrery/orrery.css scripts/page-test.js
git commit -m "The page's Settings has a Generator card: the settings without the key, a run now, the last pass"
```

---

### Task 8: Docs, version 18, release

**Files:**
- Modify: `README.md` (The page; The HTTP API table; the "Tools for an AI analyst" or generator mention)
- Modify: `docs/releasing.md` (section 9: the consent prompt this release raises on ricsul)
- Modify: `orrery-utils/generator/README.md` and `orrery-utils/README.md` (the on-ship generator is the one that runs; the util stays for the bench and dry runs)
- Modify: `code/version.json`

- [ ] **Step 1: README**

In "The page": add "a Generator card on Settings with the model, the key written once and never shown, a run-now button and the last pass". In the HTTP API table add four rows:

```
| `GET /generator` | the generator's settings, the key masked; owner only |
| `PUT /generator` | merge settings; an empty `api_key` keeps the stored one; owner only |
| `GET /generator/last` | what the last pass did: filed, dropped, notes, usage, error |
| `POST /generate` | run a pass now, whether or not anything changed; owner only |
```

Add a paragraph under "Actions": "The ship proposes on its own. When the generator is on (Settings), every change to the state wakes a pass: the ship builds the prompt from what it holds, asks the model you named through `/sys/iris/`, keeps what the schema allows and files it as proposals signed `generator`. A pass is skipped while the prompt would be the one sent last, so a quiet day costs nothing. `docs/spikes/2026-09-19-iris-probe.md` is why the ship can wait for a slow model."

- [ ] **Step 2: releasing.md and the utils README**

In `docs/releasing.md` section 9, after "A change to `ask.json` raises a consent prompt on ricsul": "Version 18 adds `/sys/iris/` and raises that prompt; approve it on `/apps/grubbery/permits` and the generator is live once its key is set on the page." In `orrery-utils/generator/README.md`, first paragraph: "As of orrery 18 the ship runs this itself (Settings, the Generator card). This util remains the bench and the dry-run harness, and the way to run a pass from a computer when the ship has no key."

- [ ] **Step 3: Bump and gate**

`code/version.json` to `{"version": 18}`. Run the checklist in `docs/releasing.md` section 8: `code-closure.py`, unit tests on wex, `api-matrix.py` twice, `key-matrix.py`, `mcp-matrix.py`, `page-smoke.py`, `ship-share-matrix.py`. Every one `ALL OK`.

- [ ] **Step 4: Commit and release**

```bash
git add -A
git commit -m "The generator runs on the ship: settings and key on the page, a pass on every change through iris; version 18"
git push origin main
```

Then the forge pull on wex and on ricsul, the four verification reads, and on ricsul: approve the consent prompt, set the key and the model on the Settings card, turn it on, press run now, and read the last pass line.

---

## Self-review

**Spec coverage.** The transport (spike): Task 6's `ask-model` is the probe arm with a ten minute timer. The pass semantics (generator README): prompt layout and clock last (Task 2), skip on digest with no ceiling (Task 6, and the wake replaces `--loop`), cache marks and no temperature under reasoning (Task 3), validation arm for arm (Task 4), usage and cost recorded (Task 6 record, Task 7 card), the key never in the repo or read back (Tasks 5, 7), `by` generator (Task 6). `--dry-run`, `--no-model`, `--answer` and the bench stay in the util, which Task 8 says.

**Placeholders.** None: every step carries its code. Two arms are named but left to the implementer as two-liners with their behaviour stated (`find-loaded`, `wait-settle` if `take-poke-from` cannot wait on a timer); both are stated exactly.

**Type consistency.** `config:gen` fields (`enabled`, `url`, `model`, `api-key`, `reasoning`, `max-tokens`, `max-actions`, `timezone`) are the same in Tasks 3, 5, 6. `build-parts` takes `(all acts decided schema now tz limit)` in Tasks 2 and 6. `validate` takes `(answer known taken schema limit)` and answers `[acts notes]` in Tasks 4 and 6. `gen-record`'s ten arguments match its four call sites in Task 6. The page's `settings` takes four arguments in Task 7 and its route passes four.
