# Refine at approval, the channel rule, the prose rules: Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Orrery version 36: a note typed under a proposed action refines it (and may add extras) through one model call on the ship; a message to a person with a ship is filed `via` `chat`; message text follows the owner's prose rules, in the prompts and, as a last line, in the executor.

**Architecture:** Three small additions to what version 34 left. The prose rules and the channel note are text: the starter schema's notes, the shared prompt files in orrery-utils and the lib cords that mirror them under `scripts/prompt-drift.py`, plus a two-line `clean-text` the executor applies before a send. The channel rule is one pure arm the writer's `do-act` calls with the target person's `ship` attribute. Refine is a pure planner in the lib (the prompt text, the answer's checks, the two writer ops) and one request-fiber route in app.hoon that runs the model call the way the reader does and files what the planner answers.

**Tech Stack:** Hoon (grubbery nexus, fiberio), the lib's reader arms (`hold-payload`, `canon-id`, `reader-context`, `chat-body-with`, `answer-of`, `parse-answer`), the page's vanilla JS, the api gate's stub.

**Spec:** `docs/superpowers/specs/2026-09-21-refine-channel-prose-design.md`. The client contract is rule 17 of `orrery-utils/docs/writing-a-client.md` (commit 18994a4), binding.

## Global Constraints

- No em dashes (U+2014) anywhere in either repo, in code, comments, docs or the prompts that state the rule (name it by its code point). No hard-wrapped markdown.
- Commit messages are one plain sentence in the style of `git log`, no attribution lines. Comments are complete sentences that say why.
- Never set grubbery or orrery to public. Never touch ricsul (the live ship): wex (`http://localhost:8080`, cookie jar `/tmp/wex.cookies`) is the dev ship; feb (`http://localhost:8081`, `/tmp/feb.cookies`, mounted desk `/home/sneagan/software/feb/grubbery`, dojo in tmux `0:6`) runs the unit suites. Never boot or kill piers. No ship codes, tokens or cookies in the repo or a report.
- Fast compile: `/tmp/claude-1001/-home-sneagan-software-personal-orrery/2a3e16c2-f1c6-43d8-a630-854483ecbe32/scratchpad/build.sh lib/orrery.hoon` (or `nex/orrery/app.hoon`, `nex/orrery/orrery.js`) writes the file to wex and prints `build: vase` (or `mime` for JS) or the compile error.
- Unit tests on feb: copy `code/lib/orrery.hoon` to `<mount>/lib/orrery.hoon` and `tests/lib/*.hoon` to `<mount>/tests/lib/` with `\cp -f`, then in tmux `0:6`: `C-u`, `|commit %grubbery`, wait 8 s, `C-u`, `send-keys -- "-test /=grubbery=/tests/lib/generator ~"` (the `--` matters), wait for `ok=%.y`; the generator suite is 44 OK at the start of this plan, the orrery suite 59.
- Gates before a commit that touches them: `python3 scripts/code-closure.py code`, `python3 scripts/prompt-drift.py ../orrery-utils/common`, `node scripts/page-test.js` (63), `python3 scripts/api-matrix.py http://localhost:8080 /tmp/wex.cookies` (210, about 15 minutes, ends `ALL OK`).
- The prose rules, verbatim wherever they are stated: `No em dashes. No semicolons or colons joining independent clauses. Simple, direct sentences, their lengths varied naturally. A sentence with more than one parenthetical thought is split in two.`
- Every write-up goes to the ledger and the task report, not the chat.

---

### Task 1: The prose rules and the channel note, in the schema, the prompts and the executor

**Files:**
- Modify: `code/lib/orrery.hoon` (starter-schema payload notes around line 1004; `system-prompt` cord at 1943; `analyst-prompt` cord at 2971; the executors section after `send-telegram`'s planner)
- Modify: `code/nex/orrery/app.hoon` (`send-telegram` 3551, `poke-auspex` 3569)
- Modify: `orrery-utils/common/generator-prompt.md`, `orrery-utils/common/analyst-prompt.md`
- Test: `tests/lib/generator.hoon`

**Interfaces:**
- Produces: `clean-text |=(t=@t @t)` in the lib (em dash to comma), used by Task 5's executor sends and by the refine route; the two new schema notes read by Task 4's prompt.

- [ ] **Step 1: The failing test for clean-text**

```hoon
++  test-clean-text
  ;:  weld
    (expect-eq !>('Rose, call me back') !>((clean-text:orr 'Rose — call me back')))
    (expect-eq !>('Rose, call me back') !>((clean-text:orr 'Rose—call me back')))
    (expect-eq !>('plain') !>((clean-text:orr 'plain')))
  ==
```

Write the em dash in the test as the three-byte UTF-8 sequence through `(crip ~[0xe2 0x80 0x94])`, not as a literal, so the repo holds none: build the fixtures with `(rap 3 'Rose ' em ' call me back' ~)` where `=/  em=@t  (crip (tufa ~[0x2014]))`.

- [ ] **Step 2: Run it (feb) and see `-find.clean-text`**

- [ ] **Step 3: clean-text in the lib, in the executors section**

```hoon
::  +clean-text: the owner's first prose rule enforced on what leaves
::  the ship: an em dash becomes a comma, one space after it and none
::  before, whatever a model wrote. The rest of the rules are the
::  prompts' to keep.
::
++  clean-text
  |=  t=@t
  ^-  @t
  =/  em=tape  (tufa ~[0x2014])
  =/  s=tape  (trip t)
  =|  out=tape
  |-
  ?~  s  (crip (flop out))
  ?.  =(em (scag 3 s))  $(s t.s, out [i.s out])
  =/  rest=tape  (slag 3 s)
  =/  before=tape  (flop (skip-trailing-space out))
  =.  rest  ?:(?=([%' ' *] rest) t.rest rest)
  $(s rest, out (flop (weld before ", ")))
```

Write `skip-trailing-space` beside it (drops spaces from the head of the reversed accumulator). Keep it simple; a tape pass is fine at message length.

- [ ] **Step 4: The schema notes.** In `starter-schema`, the `message` shape becomes:

```hoon
          :-  'message'
          %-  shape
          :~  ['via' 'required: one of chat, telegram, mail; chat when the person has a ship, telegram only when they have none']
              ['to' 'required: the body id of the person, e.g. person/andrea']
              ['text' 'required: the message, short, in the owner\'s own voice. No em dashes. No semicolons or colons joining independent clauses. Simple, direct sentences, their lengths varied naturally. A sentence with more than one parenthetical thought is split in two.']
          ==
```

- [ ] **Step 5: The prompts.** In `orrery-utils/common/generator-prompt.md` line 12, after `in the owner's own voice, short`, add the sentence `The text keeps the owner's prose rules: no em dashes, no semicolons or colons joining independent clauses, simple direct sentences of varied length, and a sentence with more than one parenthetical thought split in two.` In `analyst-prompt.md` line 5, after `text, short, in the owner's own voice`, add the same sentence. Then regenerate the lib's cords: `system-prompt` and `analyst-prompt` must equal the files byte for byte; `python3 scripts/prompt-drift.py ../orrery-utils/common` says which lines differ. Do not touch `brief-prompt.md`.

- [ ] **Step 6: The executor applies clean-text.** In `send-telegram`, the `text` field of the body sent is `(clean-text text)`; in `poke-auspex`, the body cord is `(clean-text body)`. Two one-line changes; find where the plan's `body` json's `text` is read (`exec-one`'s `%telegram` and `%mail` arms) and clean there, once.

- [ ] **Step 7: Build lib and app, run the generator suite on feb (45 OK), prompt-drift (exit 0), then the api gate (210 ALL OK; the telegram section's canned reply carries no em dash, so nothing moves).**

- [ ] **Step 8: Commit** orrery: `The prose rules in the schema and the prompts, and an em dash never leaves the ship`; orrery-utils: `The prompts carry the owner's prose rules for a message`.

---

### Task 2: The channel rule in the writer

The rule runs in `do-act` only. `do-revise-action` (Task 3) never calls `route-message`: a channel the owner set at approval stands.

**Files:**
- Modify: `code/lib/orrery.hoon` (a pure arm beside `plan-exec`)
- Modify: `code/nex/orrery/app.hoon` (`do-act` at 1094)
- Test: `tests/lib/generator.hoon`

**Interfaces:**
- Produces: `route-message |=([a=action ship=@t] [a=action note=@t])`: a message whose `via` is `telegram` or `mail`, when `ship` (the target person's `ship` attribute) is non-empty, comes back with `via` `chat` and the note `via rewritten to chat: <to> has a ship`; anything else comes back unchanged with note `''`.

- [ ] **Step 1: The failing test**

```hoon
++  test-route-message
  =/  jo  |=(t=@t ^-(json (need (de:json:html t))))
  =/  m=action:orr  [%message 'Tell Rose' (jo '{"via": "telegram", "to": "person/rose", "text": "hi"}') ~ ~ 'mail' now %proposed '' ~]
  =/  got  (route-message:orr m '~sampel-palnet')
  =/  same  (route-message:orr m '')
  =/  chat  (route-message:orr m(payload (jo '{"via": "chat", "to": "person/rose", "text": "hi"}')) '~sampel-palnet')
  =/  task  (route-message:orr m(kind %task) '~sampel-palnet')
  ;:  weld
    (expect-eq !>('chat') !>((gs:orr payload.a.got 'via')))
    (expect-eq !>('via rewritten to chat: person/rose has a ship') !>(note.got))
    (expect-eq !>('telegram') !>((gs:orr payload.a.same 'via')))
    (expect-eq !>('') !>(note.same))
    (expect-eq !>('') !>(note.chat))
    (expect-eq !>('') !>(note.task))
  ==
```

- [ ] **Step 2: Run it (feb), `-find.route-message`**

- [ ] **Step 3: The arm**

```hoon
::  +route-message: the owner's channel rule. A person with a ship is
::  reached on Urbit, so a message proposed for telegram or mail to
::  such a person is filed via chat, which Talon sends; telegram is for
::  a person with no ship. The note goes to the trail so the rewrite
::  is visible.
::
++  route-message
  |=  [a=action ship=@t]
  ^-  [a=action note=@t]
  ?.  =(%message kind.a)  [a '']
  ?:  =('' ship)  [a '']
  =/  via=@t  (lower (gs payload.a 'via'))
  ?.  |(=('telegram' via) =('mail' via))  [a '']
  :-  a(payload (set-key payload.a 'via' s+'chat'))
  (rap 3 'via rewritten to chat: ' (gs payload.a 'to') ' has a ship' ~)
```

- [ ] **Step 4: do-act calls it.** After `=/  a=action:orr  ?.(auto p.got ...)` and before `=/  id=@ta  (act-id:orr a)`: read the target's ship. Write `body-attr |=([up=@ud id=bid attr=@t] (fiber ,@t))` in app.hoon beside `first-missing`: parse the id with `parse-bid:orr`, peek `(rv up (body-dir kind slug))` as a ball, `body-in` and `rows-in` from it into a `loaded`, then `(attr-text:orr ~[l] ~ now id attr)` (`attr-text` is in the lib's executors section; it takes `all multi now id attr`), `''` when the body is missing. Then:

```hoon
  =/  routed  (route-message:orr a ship)
  =.  a  a.routed
  ;<  ~  bind:m  ?:(=('' note.routed) (pure:(fiber:fiber:nexus ,~) ~) (note 'act' & note.routed))
```

`note` is the writer's trail arm (see `note-by` at 380 for the shape). The id is computed after the rewrite, so a twin check on the rewritten action agrees with what is stored.

- [ ] **Step 5: A gate check.** In `scripts/api-matrix.py`'s executor section, after the `person/gate-people` checks: observe a body `person/gate-shipped` with a `ship` attribute `~wex` and a `telegram` attribute `1002`; `POST /act` a `message` via `telegram` to it; read it back: `payload.via == 'chat'`; and `GET /tr/log` (or however the section reads the trail; see the sharing section) carries `via rewritten to chat: person/gate-shipped has a ship`. Approve it and confirm the executor leaves it approved (it is `chat`, Talon's) and the record's `claimed` did not move. Dismiss it and delete the body in the section's teardown.

- [ ] **Step 6: Build, feb (46 OK), api gate (ALL OK, 213). Commit** `A message to a person with a ship is filed via chat`.

---

### Task 3: The writer's revise-action op

**Files:**
- Modify: `code/lib/orrery.hoon` (beside `transition`, around 700)
- Modify: `code/nex/orrery/app.hoon` (the op dispatch at 337, a `do-revise-action` beside `do-set-action`)
- Test: `tests/lib/generator.hoon`

**Interfaces:**
- Produces: `revise |=([a=action title=@t payload=json about=(set bid) due=(unit @da) by=@t now=@da] action)` in the lib: the four fields replaced, `history` gains `[now %revised by]`, status unchanged. `revise-action-op |=([id=@ta title=@t payload=json about=(list @t) due=(unit @da) by=@t] json)` builds the writer op `{"op": "revise-action", "id", "title", "payload", "about", "due", "by"}`. The writer refuses the op unless the action is `proposed`.

- [ ] **Step 1: The failing test**

```hoon
++  test-revise
  =/  jo  |=(t=@t ^-(json (need (de:json:html t))))
  =/  m=action:orr  [%message 'Tell Rose' (jo '{"via": "chat", "to": "person/rose", "text": "hi"}') (sy ~['person/rose']) ~ 'mail' now %proposed '' ~[[now %proposed 'mail']]]
  =/  got  (revise:orr m 'Tell Rose and Susan' (jo '{"via": "chat", "to": "person/rose", "text": "hi both"}') (sy ~['person/rose' 'person/susan-egan']) `(add now ~d1) 'user' (add now ~m5))
  =/  op=json  (revise-action-op:orr 'a1' 'T' (jo '{}') ~['person/rose'] ~ 'user')
  ;:  weld
    (expect-eq !>('Tell Rose and Susan') !>(title.got))
    (expect-eq !>(%proposed) !>(status.got))
    (expect-eq !>(2) !>((lent history.got)))
    (expect-eq !>([%revised 'user']) !>([status by]:(rear history.got)))
    (expect-eq !>(`(add now ~d1)) !>(due.got))
    (expect-eq !>('revise-action') !>((gs:orr op 'op')))
    (expect-eq !>('a1') !>((gs:orr op 'id')))
  ==
```

- [ ] **Step 2: Run (feb), `-find.revise`**

- [ ] **Step 3: The lib arms**

```hoon
::  +revise: the owner's note applied to a proposed action: the four
::  fields the note can change, replaced whole; the id, the status and
::  the history stay, with one step saying the owner revised it. The
::  status does not move, so the transition table has no say.
::
++  revise
  |=  [a=action title=@t payload=json about=(set bid) due=(unit @da) by=@t now=@da]
  ^-  action
  a(title title, payload payload, about about, due due, history (snoc history.a [now %revised by]))
++  revise-action-op
  |=  [id=@ta title=@t payload=json about=(list @t) due=(unit @da) by=@t]
  ^-  json
  %-  pairs:enjs:format
  %-  zing
  :~  :~  ['op' s+'revise-action']
          ['id' s+id]
          ['title' s+title]
          ['payload' payload]
          ['about' a+(turn about |=(x=@t `json`s+x))]
          ['by' s+by]
      ==
      ?~(due ~ ~[['due' s+(en-iso u.due)]])
  ==
```

- [ ] **Step 4: The writer.** Dispatch: `?:  =('revise-action' op)  (do-revise-action jon)`. The arm, a copy of `do-set-action`'s shape: read the action at `(rf 0 /actions id)`, refuse `no action <id>` / `unreadable action`; refuse `only a proposed action can be revised` unless `=(%proposed status.u.a)`; `title` non-empty and at most 200 bytes else refuse `title: required`; `about` through `first-missing` (refuse `about: no such body <x>`); `due` through `de-iso-any:orr` when present (refuse `due: not a time`); then `revise:orr` and `over:io` the stored action `[%2 next]`; `(note-by 'revise-action' & '' who)`; answer `&`. The beacon moves on the write like any action write (confirm how `do-set-action`'s write moves it; nothing extra to do if it is the writer's settle).

- [ ] **Step 5: Build lib and app, feb (47 OK). Commit** `The writer revises a proposed action in place`.

---

### Task 4: The refine planner in the lib

**Files:**
- Modify: `code/lib/orrery.hoon` (a new section `refine` after the reader's `ground`)
- Create: `orrery-utils/common/refine-prompt.md`
- Modify: `scripts/prompt-drift.py` (PAIRS gains `('refine-prompt', 'refine-prompt.md')`)
- Test: `tests/lib/generator.hoon`

**Interfaces:**
- Consumes: `reader-ctx`, `ctx-body`, `reader-context`, `hold-payload`, `canon-id`, `local-iso`, `de-iso-any`, `en-iso`, `clean-text` (Task 1), `revise-action-op` (Task 3), `fill-act-as` (the executors section, used by `adopt-ops`).
- Produces:
  - `refine-prompt` cord (the system text, equal to the file byte for byte).
  - `refine-user |=([a=action id=@ta ctx=reader-ctx text=@t now=@da tz=@t] @t)`: the user prompt.
  - `+$ refined [title=@t payload=json about=(list @t) due=(unit @da) extras=(list json)]` where each extra is an `act`-ready json (kind, title, payload with `refined_from`, about, due) not yet stamped.
  - `refine-check |=([answer=json a=action id=@ta ctx=reader-ctx now=@da] (each refined @t))`.
  - `refine-ops |=([r=refined id=@ta by=@t now=@da] (list json))`: the `revise-action` op then one `act` op per extra (through `fill-act-as` with `by`).

- [ ] **Step 1: The prompt file** `orrery-utils/common/refine-prompt.md` (no hard wraps; the exact text the cord holds):

```
You refine one proposed action for orrery, a model of one person's world, from a note the owner typed while approving it.

You are given the action as JSON, the shapes the schema allows for each action kind, the bodies the ship knows (id, name, aliases), the owner's clock, and the note. Answer with one JSON object and nothing else: {"action": {"title": ..., "payload": {...}, "about": [...], "due": ... or null}, "extras": [...], "refused": ""}.

The action keeps its kind and its purpose; the note changes what it says. "Include Susan in this" adds a person the ship knows to a message's recipients or an event's participants and names them in the text or title; "make it 3pm" moves the time on the owner's clock; "shorter" or "friendlier" rewrites the text in the owner's own voice. "Send this as mail" sets via to mail, "as a DM" to chat, "over telegram" to telegram; the owner's word on the channel is final. Every body you name is an id from the list, never a name you made up. A time is ISO 8601 UTC; a bare clock time in the note is on the owner's clock.

What the note asks for beyond this action goes in extras, each a complete new action with kind, title, payload in the schema's shape, about and due: "also add a todo the day before to go shopping" is a task due one day before the event's start. Never repeat the action itself as an extra.

The owner's prose rules hold for every text and title you write: No em dashes. No semicolons or colons joining independent clauses. Simple, direct sentences, their lengths varied naturally. A sentence with more than one parenthetical thought is split in two.

When the note names a person the ship does not know, or asks for something no action kind can carry, answer {"refused": "<one plain sentence saying what is missing>"} and change nothing.
```

Add the cord to the lib as `++  refine-prompt` in the style of `analyst-prompt` (a `'''` cord, each line of the file one line of the cord) and the pair to `PAIRS` in `scripts/prompt-drift.py`.

- [ ] **Step 2: The failing tests**

```hoon
++  refine-ctx
  ^-  reader-ctx:orr
  =/  schema=json  starter-schema:orr
  %-  reader-context:orr
  :+  :~  (mkb 'person/rose' %person 'Rose' ~ ~[['ship' s+'~sampel-palnet']] now)
          (mkb 'person/susan-egan' %person 'Susan Egan' (sy ~['susan']) ~ now)
      ==
    schema
  now
++  refine-act
  ^-  action:orr
  [%message 'Tell Rose' (jo '{"via": "chat", "to": "person/rose", "text": "hi"}') (sy ~['person/rose']) ~ 'mail' now %proposed '' ~[[now %proposed 'mail']]]
++  test-refine-check
  =/  good=json  (jo '{"action": {"title": "Tell Rose and Susan", "payload": {"via": "chat", "to": "person/rose", "text": "hi both"}, "about": ["person/rose", "susan"], "due": null}, "extras": [{"kind": "task", "title": "Go shopping", "payload": {"notes": "before the dinner"}, "about": ["person/rose"], "due": "2026-09-24T14:00:00Z"}], "refused": ""}')
  =/  got  (refine-check:orr good refine-act 'a1' refine-ctx now)
  =/  nobody=json  (jo '{"action": {"title": "Tell Rose", "payload": {"via": "chat", "to": "person/rose", "text": "hi"}, "about": ["person/nobody"]}, "extras": [], "refused": ""}')
  =/  refused=json  (jo '{"refused": "no person named Karl on the ship"}')
  =/  badkind=json  (jo '{"action": {"title": "T", "payload": {"via": "chat", "to": "person/rose", "text": "x"}, "about": []}, "extras": [{"kind": "home", "title": "Lights", "payload": {}, "about": []}], "refused": ""}')
  =/  past=json  (jo '{"action": {"title": "T", "payload": {"via": "chat", "to": "person/rose", "text": "x"}, "about": []}, "extras": [{"kind": "calendar", "title": "Dinner", "payload": {"title": "Dinner", "starts": "2020-01-01T00:00:00Z"}, "about": []}], "refused": ""}')
  ;:  weld
    (expect !>(?=(%& -.got)))
    (expect-eq !>('Tell Rose and Susan') !>(?>(?=(%& -.got) title.p.got)))
    (expect-eq !>(`(list @t)`~['person/rose' 'person/susan-egan']) !>(?>(?=(%& -.got) about.p.got)))
    (expect-eq !>(1) !>(?>(?=(%& -.got) (lent extras.p.got))))
    (expect-eq !>('a1') !>(?>(?=(%& -.got) (gs:orr (gj:orr (snag 0 extras.p.got) 'payload') 'refined_from'))))
    (expect !>(?=(%| -.(refine-check:orr nobody refine-act 'a1' refine-ctx now))))
    (expect-eq !>('no person named Karl on the ship') !>(?>(?=(%| -.(refine-check:orr refused refine-act 'a1' refine-ctx now)) p.(refine-check:orr refused refine-act 'a1' refine-ctx now))))
    ::  an extra of a kind a reader may not propose is dropped, not fatal
    (expect-eq !>(0) !>(?>(?=(%& -.(refine-check:orr badkind refine-act 'a1' refine-ctx now)) (lent extras.p.(refine-check:orr badkind refine-act 'a1' refine-ctx now)))))
    ::  a calendar extra in the past is dropped
    (expect-eq !>(0) !>(?>(?=(%& -.(refine-check:orr past refine-act 'a1' refine-ctx now)) (lent extras.p.(refine-check:orr past refine-act 'a1' refine-ctx now)))))
  ==
++  test-refine-ops
  =/  r=refined:orr  ['T' (jo '{"via": "chat", "to": "person/rose", "text": "x"}') ~['person/rose'] ~ ~[(jo '{"kind": "task", "title": "Go shopping", "payload": {"refined_from": "a1"}, "about": ["person/rose"]}')]]
  =/  ops=(list json)  (refine-ops:orr r 'a1' 'user' now)
  ;:  weld
    (expect-eq !>(2) !>((lent ops)))
    (expect-eq !>('revise-action') !>((gs:orr (snag 0 ops) 'op')))
    (expect-eq !>('act') !>((gs:orr (snag 1 ops) 'op')))
    (expect-eq !>('user') !>((gs:orr (gj:orr (snag 1 ops) 'action') 'by')))
  ==
++  test-refine-user
  =/  t=@t  (refine-user:orr refine-act 'a1' refine-ctx 'include susan in this' now 'America/New_York')
  ;:  weld
    (expect !>((has-sub t 'person/susan-egan | Susan Egan | susan')))
    (expect !>((has-sub t 'include susan in this')))
    (expect !>((has-sub t 'message payload:')))
    (expect !>((has-sub t 'The owner\'s clock reads 2026-09-18T08:00:00-04:00')))
  ==
```

`mkb` is the fixture the exec tests use (id kind name aliases attrs now); the test file's `now` is `~2026.9.18..12.00.00`. Adjust the fixture arity to `mkb`'s actual one (read it at the top of the exec tests).

- [ ] **Step 3: Run (feb), `-find.refine-check`**

- [ ] **Step 4: The planner**

```hoon
::  ==  refine: the owner's note under a proposed action, applied
::  through one model call (version 36). The checks are the reader's
::  where they apply: the payload shape, the bodies, the times.
::
+$  refined  [title=@t payload=json about=(list @t) due=(unit @da) extras=(list json)]
++  refine-prompt
  '''
  ...the file, line for line...
  '''
::  +refine-user: the user prompt: the clock, the shapes, the bodies,
::  the action and the note, in that order, so the note is the last
::  thing the model reads.
::
++  refine-user
  |=  [a=action id=@ta ctx=reader-ctx text=@t now=@da tz=@t]
  ^-  @t
  =/  kind-lines=(list @t)
    :-  (cat 3 'Action kinds an extra may have: ' (join-cords ', ' kinds.ctx))
    %+  turn  (sort ~(tap by payloads.ctx) |=([a=[@t *] b=[@t *]] (aor -.a -.b)))
    |=([k=@t shape=json] (rap 3 '  ' k ' payload: ' (en:json:html shape) ~))
  =/  body-lines=(list @t)
    :-  'Bodies the ship knows (id | name | aliases):'
    ?~  bodies.ctx  `(list @t)`~['  (none known)']
    (turn bodies.ctx |=(b=ctx-body (rap 3 '  ' id.b ' | ' name.b ' | ' (join-cords ', ' aliases.b) ~)))
  %-  join-cords  :-  '\0a'
  ;:  weld
    ~[(rap 3 'The owner\'s clock reads ' (local-iso (en-iso now) tz) '.' ~)]
    kind-lines
    body-lines
    ~[(cat 3 'The action: ' (en:json:html (en-action id a)))]
    ~[(cat 3 'The note: ' text)]
  ==
```

`en-action` is the lib's action view encoder (find its name near `en-attrs`; it takes the id and the action). `refine-check`:

```hoon
++  refine-check
  |=  [answer=json a=action id=@ta ctx=reader-ctx now=@da]
  ^-  (each refined @t)
  =/  refused=@t  (gs answer 'refused')
  ?.  =('' refused)  [%| refused]
  =/  known=(set @t)  (sy (turn bodies.ctx |=(b=ctx-body id.b)))
  =/  alias=(map @t @t)
    %-  ~(gas by *(map @t @t))
    %-  zing
    %+  turn  bodies.ctx
    |=(b=ctx-body [[(lower name.b) id.b] (turn aliases.b |=(x=@t [(lower x) id.b]))])
  =/  act=json  (gj answer 'action')
  ?.  ?=([%o *] act)  [%| 'the model answered no action']
  =/  title=@t  =/(t (end [3 200] (trim-cord (gs act 'title'))) ?:(=('' t) title.a t))
  =/  about-raw=(list @t)  (turn (ga act 'about') |=(x=json (canon-id alias (lower (trim-cord (ref-or-text x))))))
  =/  bad=(list @t)  (skip about-raw |=(x=@t (~(has in known) x)))
  ?^  bad  [%| (rap 3 'no body named ' i.bad ' on the ship' ~)]
  =/  about=(list @t)  (scag 20 (dedupe about-raw))
  =/  pay=(map @t json)  =/(p (gj act 'payload') ?:(?=([%o *] p) p.p ~))
  =/  held  (hold-payload pay (fall (~(get by payloads.ctx) kind.a) `json`~) known alias)
  ?:  ?=([%| *] held)  [%| p.held]
  =/  due=(unit @da)  =/(d (gs act 'due') ?:(=('' d) ~ (de-iso-any d)))
  =/  extras=(list json)
    %+  murn  (ga answer 'extras')
    |=  e=json
    ^-  (unit json)
    ?.  ?=([%o *] e)  ~
    =/  kind=@t  (lower (trim-cord (gs e 'kind')))
    ?.  (lien reader-kinds |=(k=@t =(k kind)))  ~
    =/  et=@t  (end [3 200] (trim-cord (gs e 'title')))
    ?:  =('' et)  ~
    =/  eabout=(list @t)
      (skim (turn (ga e 'about') |=(x=json (canon-id alias (lower (trim-cord (ref-or-text x)))))) |=(x=@t (~(has in known) x)))
    =/  epay=(map @t json)  =/(p (gj e 'payload') ?:(?=([%o *] p) p.p ~))
    =/  eheld  (hold-payload epay (fall (~(get by payloads.ctx) kind) `json`~) known alias)
    ?:  ?=([%| *] eheld)  ~
    =/  edue=(unit @da)  =/(d (gs e 'due') ?:(=('' d) ~ (de-iso-any d)))
    ?:  &(=('calendar' kind) !(extra-plan-ok p.eheld now))  ~
    :-  ~
    %-  pairs:enjs:format
    %-  zing
    :~  :~  ['kind' s+kind]
            ['title' s+et]
            ['payload' [%o (~(put by p.eheld) 'refined_from' s+id)]]
            ['about' a+(turn (dedupe (weld eabout ~(tap in about.a))) |=(x=@t `json`s+x))]
        ==
        ?~(edue ~ ~[['due' s+(en-iso u.edue)]])
    ==
  [%& title (clean-json-text [%o p.held]) about due extras]
```

`extra-plan-ok`: `starts` parses, is after `now` and before `now + ~d365`, and `ends`, when present, is after `starts`. `clean-json-text` applies `clean-text` to the payload's `text` key when it is a string (one small arm). `refine-ops`:

```hoon
++  refine-ops
  |=  [r=refined id=@ta by=@t now=@da]
  ^-  (list json)
  :-  (revise-action-op id title.r payload.r about.r due.r by)
  %+  turn  extras.r
  |=  e=json
  (pairs:enjs:format ~[['op' s+'act'] ['action' (fill-act-as e by now)]])
```

Check `fill-act-as`'s signature in the executors section and match it (Task 4 of version 34 used it in `adopt-ops`).

- [ ] **Step 5: Build the lib, feb (50 OK), prompt-drift exit 0. Commit** orrery `The refine planner: a note under a proposed action becomes a revision and its extras`; orrery-utils `The refine prompt`.

---

### Task 5: The route, the page, the gate

**Files:**
- Modify: `code/nex/orrery/app.hoon` (`handle-request` near 714, a `serve-refine` beside `serve-set-action`)
- Modify: `code/nex/orrery/orrery.js` (`inbox` at 187; the click handling for `data-move` gains `data-refine`), `code/nex/orrery/orrery.css`
- Modify: `scripts/api-matrix.py` (the stub gains `REFINE_CANNED`; an executor-section block or its own section), `scripts/page-test.js`
- Test: the gate and the page tests

**Interfaces:**
- Consumes: Task 3's op and Task 4's planner; `identify`/`actor` (owner or key; `scope.act` with `action-in-scope:orr` and `write`), `ask-model`, `chat-body-with:orr`, `answer-of:orr`, `parse-answer:orr`, `reader-context:orr`, `load-bodies`, `load-actions`, `file-ops`.
- Produces: `POST /api/actions/<id>/refine`.

- [ ] **Step 1: The route.** In `handle-request`: `?:  &(=('POST' meth) ?=([%api %actions @ %refine ~] suffix))  (serve-refine eyre-id s2 jon act)`. The arm:

```hoon
++  serve-refine
  |=  [eyre-id=@ta id=@ta jon=json act=actor]
  =/  m  (fiber:fiber:nexus ,~)
  ^-  form:m
  ?.  ?=([%o *] jon)  (send-err eyre-id 400 'expected an object')
  =/  text=@t  (trim-cord:orr (gs:orr jon 'text'))
  ?:  =('' text)  (send-err eyre-id 400 'text: required')
  ?:  (gth (met 3 text) 2.000)  (send-err eyre-id 400 'text: over 2000 bytes')
  ;<  cur=view:nexus  bind:m  (peek:io (rf 1 /actions id) ~)
  ?.  ?=([%file *] cur)  (send-err eyre-id 404 'no such action')
  =/  a=(unit action:orr)  (read-action:orr (sang-noun:tarball sang.cur))
  ?~  a  (send-err eyre-id 500 'unreadable action')
  ?:  &(?=(^ scope.act) !(action-in-scope:orr u.scope.act kind.u.a))  (send-err eyre-id 404 'no such action')
  ?:  &(?=(^ scope.act) !write.u.scope.act)  (send-err eyre-id 403 'read only key')
  ?.  =(%proposed status.u.a)  (send-err eyre-id 409 'only a proposed action can be refined')
  ;<  busy=?  bind:m  (peek-exists:io (rf 1 /refining id))
  ?:  busy  (send-err eyre-id 409 'a refinement is running')
  ;<  *  bind:m  (make-gained-soft:io (rf 1 /refining id) |+[[[/ %json] `json`[%o ~]] ~])
  ;<  cfg=config:orr  bind:m  (read-generator 1)
  ?:  =('' api-key.cfg)
    ;<  ~  bind:m  (cull-soft (rf 1 /refining id))
    (send-err eyre-id 503 'the generator has no key')
  ;<  now=@da  bind:m  get-time:io
  ;<  schema=json  bind:m  (read-json (rf 1 / %'schema.json'))
  ;<  all=(list loaded:orr)  bind:m  (load-bodies 1)
  =/  ctx=reader-ctx:orr  (reader-context:orr all schema now)
  =/  tz=@t  (attr-text:orr all (multi-of:orr schema) now 'person/me' 'timezone')
  =/  who=@t  ?:(owner.act 'user' by.act)
  ;<  got=[status=@ud body=@t secs=@ud]  bind:m
    (post-json (cat 3 url.cfg '/chat/completions') api-key.cfg (chat-body-with:orr cfg refine-prompt:orr ~[(refine-user:orr u.a id ctx text now tz)]) ~m2 %model)
  ;<  ~  bind:m  (cull-soft (rf 1 /refining id))
  ?.  =(200 status.got)  (send-err eyre-id 502 (rap 3 'the model answered ' (crip (a-co:co status.got)) ~))
  =/  ans  (answer-of:orr (fall (de:json:html body.got) ~))
  ?:  ?=(%| -.ans)  (send-err eyre-id 502 p.ans)
  =/  parsed=json  (fall (parse-answer:orr text.p.ans) ~)
  =/  checked  (refine-check:orr parsed u.a id ctx now)
  ?:  ?=(%| -.checked)
    (send-json eyre-id 200 (pairs:enjs:format ~[['ok' b+|] ['note' s+p.checked]]))
  ;<  ~  bind:m  (file-ops (refine-ops:orr p.checked id who now))
  ;<  after=view:nexus  bind:m  (peek:io (rf 1 /actions id) ~)
  ... read the revised action back and each extra by its computed id (act-id of the stamped extra, as the mirror's adoption does) ...
  (send-json eyre-id 200 (pairs:enjs:format ~[['ok' b+&] ['action' <view>] ['extras' a+<views>] ['note' s+<dropped extras, if any>]]))
```

Confirm the names: `read-generator`, `cull-soft` (or the arm the reader uses to drop an inbox grub), `file-ops` from a request fiber (the sharing routes file ops from the request fiber; copy their pattern, including `settle`), and how `serve-actions` encodes an action view. `/refining/<id>` is the per-action lock; a crashed route leaves it, so the lock is also dropped by a `POST /api/exec/wake`? No: keep it simple, and drop the lock grub when its mtime is older than five minutes (read its `cass` from the peek) instead of refusing.

- [ ] **Step 2: The stub.** In `scripts/api-matrix.py`'s `Stub.answer`, before the `CANNED` fallback: `elif system.startswith('You refine'): out = REFINE_CANNED`, where `REFINE_CANNED` is a chat completion whose content is the JSON `{"action": {"title": "Tell Rose and Susan the tow is booked", "payload": {"via": "chat", "to": "person/gate-shipped", "text": "The tow is booked. Susan knows too."}, "about": ["person/gate-shipped"], "due": null}, "extras": [{"kind": "task", "title": "Gate: buy the tow guy a coffee", "payload": {"notes": "before the tow"}, "about": ["person/gate-shipped"], "due": "2099-01-01T12:00:00Z"}], "refused": ""}` (a `2099` due so the retire and expire passes never touch it). A second canned reply for the refused case: when the request's user prompt ends with `The note: who is karl`, answer `{"refused": "no person named Karl on the ship"}`.

- [ ] **Step 3: The gate checks** (in the executor section, after Task 2's `person/gate-shipped` message is filed and before it is dismissed; the stub is up and the generator points at it there):
  - `POST /api/actions/<id>/refine {"text": "include susan in this"}` answers 200 `ok` true, `action.title` is the canned title, `action.payload.via` is `chat`, `extras` has one task whose `payload.refined_from` is the id and whose `about` holds `person/gate-shipped`.
  - `GET /api/actions/<id>` shows status `proposed`, the new title, and a last history step `revised` by `user`.
  - The extra exists in `GET /api/actions?status=open` (approved under `auto`, since it is a task) and its todo is placed by the executor (poll `todo_for`); dismiss it and add it to `MADE`.
  - `POST .../refine {"text": "who is karl"}` answers 200 `ok` false with the note, and the title is unchanged.
  - Refining an approved action answers 409; refining with a key whose `actions` lacks `message` answers 404; a read-only key answers 403 (the key section has fixtures for these; add one refine call there, or make the keys here).
  - The trail (`/tr/log`) has a `revise-action` line.
  - `POST .../refine {"text": "send this as mail"}` on a fresh `chat` message answers `ok` true with `action.payload.via` `mail`, and reading the action back shows `mail` (the stub answers `{"action": {... "via": "mail" ...}, "extras": [], "refused": ""}` when the user prompt ends with `The note: send this as mail`); approve it and the executor sends it by auspex (`sent by mail to ~wex`), which proves a revision is not rerouted.

- [ ] **Step 4: The page.** In `inbox`, for `a.status === 'proposed'`, after the move buttons: `'<p class="refine"><input data-refine-text="' + esc(a.id) + '" placeholder="a note for this action"> <button data-refine="' + esc(a.id) + '">refine</button> <span class="muted" data-refine-note="' + esc(a.id) + '"></span></p>'`. The click handler beside `data-move`'s: read the input, `api('/actions/' + id + '/refine', {method: 'POST', body: {text}})`, then on `ok` false put the note in the span, on `ok` true say `revised` in the span and let the beacon refresh redraw (the write moved it). Three page tests: a proposed action renders the input and the button with its id; an approved one does not; the note span is empty on render.

- [ ] **Step 5: Build app and page (`build.sh nex/orrery/orrery.js` prints `mime`), page-test (66), api gate (ALL OK, count in the report), smoke (13). Commit** `The refine route, its box on the page, and the gate`.

---

### Task 6: Docs and release prep

**Files:**
- Modify: `README.md` (routes table: `POST /actions/<id>/refine`; the executor paragraph gains the channel rule and the prose rules; Under the hood gains `refine-prompt.md`), `docs/releasing.md` (version 36's owner steps: none on the permits page; the controller merges the two schema notes into ricsul's stored schema through `PUT /api/schema` after the pull, and the Talon agent gets rule 17), `code/version.json` 36.
- Modify: `orrery-utils/common/README.md` (the three prompt files and the drift check), `orrery-utils/docs/writing-a-client.md` rule 14 (one sentence: the ship files a message to a person with a ship via `chat`, so a client executor may see `chat` messages that were proposed as `telegram`).

- [ ] **Step 1: The docs**, in each file's voice, no hard wraps.
- [ ] **Step 2: Every gate:** closure, `cmp code/lib/tools.hoon /home/sneagan/software/groundwire/grubbery/desk/gub/lib/tools.hoon`, prompt-drift, page-test, api-matrix, key-matrix (107), mcp-matrix (38), page-smoke (13), ship-share-matrix (79), feb suites (generator 50, orrery 59).
- [ ] **Step 3: Commit** orrery `Version 36: a note at approval refines the action, a message to a ship goes via chat, and the prose rules hold`; orrery-utils `Rule 14 and the common README for orrery 36`. The push, the pull onto ricsul, the schema merge on ricsul and the Talon note are the controller's.

## Self-review

- Spec coverage: refine route, checks, ops, page, lock (Task 3, 4, 5); channel rule and the schema note (Task 2, 1); prose rules in schema, prompts, executor (Task 1); the ricsul schema merge (Task 6's release note, the controller's); out of scope respected (no kind change: `refine-check` keeps `kind.a`; no chat executor).
- Placeholders: Task 5's route has one elided read-back (`... read the revised action back ...`); it names the arms to copy (`serve-actions`'s view encoder, the mirror's `act-id` computation) so the implementer has the how. Task 4's cord is `...the file, line for line...` by necessity (the file is in Step 1).
- Types: `refined` fields used the same in Tasks 4 and 5; `route-message` returns `[a note]` in Task 2 and is read as `a.routed`/`note.routed`; `revise-action-op` takes `about` as a list and `refined` holds a list; `refine-ops` passes `by` to `fill-act-as` the way `adopt-ops` does.
