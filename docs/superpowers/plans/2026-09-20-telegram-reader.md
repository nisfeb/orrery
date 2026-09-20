# Telegram Reader on the Ship (version 29) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Orrery version 29 reads Telegram itself: a webhook takes each update, a fiber runs the bot's pipeline (filters, commands, gate, analyst, validation, grounding, status check, escalation) with the shared prompts, and the facts land signed `telegram` with the same source pointers the Python bot writes.

**Architecture:** One inbound route (`POST /apps/orrery/telegram`, secret header, answered before `identify`) writes the update into an inbox grub; a `telegram.sig` fiber keeps a subscription on the inbox and drains it in order. Every pure step (parsing an update, the window, the context, the prompt, validation, grounding, the decider bodies) is an arm in `code/lib/orrery.hoon` with a unit test in `tests/lib/generator.hoon`; every side effect (HTTP through iris, the writer ops, the record) lives in `code/nex/orrery/app.hoon` next to the generator's arms and reuses them. The analyst prompt is a cord in the lib, held to `orrery-utils/common/analyst-prompt.md` by a script.

**Tech Stack:** Hoon on the grubbery nexus (fibers, iris through `/sys/iris/`, ball grubs), the orrery page (plain JS), Python gates (`scripts/api-matrix.py`, `scripts/page-test.js`).

**Spec:** `docs/superpowers/specs/2026-09-20-telegram-on-ship.md`

## Global Constraints

- Every read of the ball's `?info=1` must check `build.status` (`vase` compiled, `tang` failed); `bang` says nothing. The fast loop is `write-text` to `/grubbery/ball/apps/shell.shell/desks/orrery.desk/desk/code/<file>` on ~wex (`localhost:8080`, jar `/tmp/wex.cookies`), verified by read-back (the scratchpad `build.sh` does both).
- Clay unit tests run on ~feb's grubbery desk (copies at `~/software/feb/grubbery/lib/orrery.hoon` and `~/software/feb/grubbery/tests/lib/generator.hoon`, `|commit %grubbery` then `-test /=grubbery=/tests/lib/generator ~` in tmux window `0:6`). Wex's clay desk fails `|commit` (out of memory) and is not used for tests.
- Tall `:~` items on one line need two-space gaps. A wet gate (`sy`, `slag`, `levy`) on a `?~`-narrowed list fails with `mull-grow`; bind to a typed face or cast first. `\'` inside a cord; `\{` for a brace in a tape.
- Facts written by the reader: `by` is `telegram`, source `{"kind": "chat", "id": "telegram/<chat id>/<message id>"}`, identical to the Python bot.
- No secret is ever served back: the token and the webhook secret read as `token_set` and `secret_set`.
- The webhook is unauthenticated by design and the secret header is its whole credential: `PUT /telegram` refuses a `secret` shorter than 16 bytes (400, `secret: 16 bytes at least`); the hook compares the header before parsing the body and refuses a body over 64 KB (413) before the parse; the card generates a 32-byte secret on demand (`crypto.getRandomValues`, hex).
- Never publish grubbery on ricsul; never touch ricsul by dojo or ssh; a release is a forge pull (`POST /grubbery/forge/api/run {"repo": "orrery.git_repo", "command": "pull"}`).
- Commits as nisfeb, no AI attribution line, no em dashes.
- Every task ends with the gates that touch it green: `node scripts/page-test.js`, `python3 scripts/code-closure.py code`, and the api gate `python3 scripts/api-matrix.py http://localhost:8080 /tmp/wex.cookies` for tasks that change a route or a fiber.

---

## File map

- `code/lib/orrery.hoon`: new section `::  ==  telegram reader` after the reconcile section, before the final `--`: `tg-config`, `de-tg-config`, `en-tg-config-masked`, `tg-message`, `tg-source`, `tg-remember`, `tg-window`, `tg-command`, `reader-context`, `reader-prompt`, `analyst-prompt`, `validate-reader`, `ground`, `named-in`, `words`, `gate-body`, `status-body`, `escalate-body`, `noul-of`, `choice-of`, `reader-batch`.
- `code/nex/orrery/app.hoon`: `telegram.json`, `telegram-recent.json`, `telegram-last.json`, `telegram-connections.json`, `/telegram-inbox` directory, `telegram.sig` fiber; routes `POST /telegram` (before identify), `GET/PUT /api/telegram`, `GET /api/telegram/last`, `POST /api/telegram/webhook`; arms `serve-telegram-hook`, `serve-telegram`, `do-set-telegram`, `serve-set-webhook`, `tg-drain`, `tg-handle`, `tg-read`, `tg-file`, `tg-record`, `post-json` (the HTTP call the generator's `ask-model` becomes), `ask-decider`, `tg-connection-owner`.
- `code/nex/orrery/orrery.js`, `orrery.css`: a Telegram card under Settings.
- `scripts/api-matrix.py`: a Telegram section with a stub for the model, the decider and Telegram's API.
- `scripts/page-test.js`: the card.
- `scripts/prompt-drift.py`: holds the lib's `analyst-prompt` cord to `orrery-utils/common/analyst-prompt.md`.
- `tests/lib/generator.hoon`: the unit tests.
- `README.md`, `docs/releasing.md`, `orrery-utils/telegram/README.md`, `orrery-utils/docs/writing-a-client.md`.

Existing arms the tasks lean on (all in `code/lib/orrery.hoon` unless said): `gs`, `gj`, `ga`, `gn`, `gt`, `strings`, `has-key`, `de-iso`, `en-iso`, `en-time`, `tokens`, `lower`, `parse-bid`, `ok-attr`, `normalize-title`, `same-person`, `slug`, `split-char`, `split-ws`, `join-cords`, `join-tapes`, `trim-tape`, `plan-problem` does not exist in Hoon yet (Task 6 writes it), `parse-answer`, `fill-act-as`, `de-action`; in `app.hoon`: `read-json`, `load-bodies`, `find-loaded`, `poke-soft:io` to `main.sig`, `ask-model`, `send-json`, `send-err`, `rf`, `rv`, `gen-in`, `take-gen-in`, `settle`, `file-ops`.

---

### Task 1: The settings document and its route

**Files:**
- Modify: `code/lib/orrery.hoon` (new section, after `plan-prune`)
- Modify: `code/nex/orrery/app.hoon` (falls, routes, `serve-telegram`, `do-set-telegram`, the writer op)
- Modify: `code/lib/orrery.hoon` starter schema: `person` attrs gain `telegram`
- Test: `tests/lib/generator.hoon`, `scripts/api-matrix.py`

**Interfaces:**
- Produces: `+$  tg-config  [enabled=? token=@t secret=@t api-url=@t public-url=@t model=@t max-tokens=@ud chats=(set @t) people=(map @t @t) gate=@ud escalate=@ud max-daily=@ud]` where `gate` and `escalate` are thresholds in hundredths (30 and 60), `people` maps a Telegram user id (as text) to a body id. `de-tg-config:orr`, `en-tg-config-masked:orr`. Routes `GET /api/telegram` (masked), `PUT /api/telegram` (merge; blank `token`/`secret` keep, JSON `null` clears, like the generator). The op name is `set-telegram`.

- [ ] **Step 1: Write the failing unit test** (append to `tests/lib/generator.hoon` before the final `--`)

```hoon
++  test-tg-config
  =/  bare=tg-config:orr  (de-tg-config:orr (jo '{}'))
  =/  full=tg-config:orr
    %-  de-tg-config:orr
    %-  jo
    '{"enabled": true, "token": "123:abc", "secret": "s", "chats": [1001, "-42"], "people": {"1001": "person/me"}, "gate": 0.3, "escalate": 0.6, "max_daily_messages": 20, "model": "x/y", "public_url": "https://ship.example"}'
  =/  shown=json  (en-tg-config-masked:orr full)
  ;:  weld
    (expect-eq !>(|) !>(enabled.bare))
    (expect-eq !>('https://api.telegram.org') !>(api-url.bare))
    (expect-eq !>(500) !>(max-daily.bare))
    (expect-eq !>(30) !>(gate.bare))
    (expect-eq !>(60) !>(escalate.bare))
    (expect !>((~(has in chats.full) '1001')))
    (expect !>((~(has in chats.full) '-42')))
    (expect-eq !>(`(unit @t)`[~ 'person/me']) !>((~(get by people.full) '1001')))
    (expect-eq !>(20) !>(max-daily.full))
    (expect-eq !>(`json`~) !>((gj:orr shown 'token')))
    (expect-eq !>(`json`b+&) !>((gj:orr shown 'token_set')))
    (expect-eq !>(`json`b+&) !>((gj:orr shown 'secret_set')))
    (expect-eq !>('x/y') !>((gs:orr shown 'model')))
  ==
```

- [ ] **Step 2: Run it to see it fail** (copy lib and tests to feb, commit, run; expect `FAILED  /tests/lib/generator/hoon (build)` with `-find.de-tg-config`)

- [ ] **Step 3: Write the lib section**

Add to the starter schema's person attrs list (the `~['status' 'location' 'phone' 'email' 'ship' ...]` line) the name `'telegram'`, and a note in the same `:~` of notes:

```hoon
              ['telegram' 'the Telegram chat id the ship reaches this person at, a number as text; identity, like phone']
```

Add `'telegram'` beside `'email'` and `'phone'` in `identity-values` (the `weld` of the two lists gains a third).

Then the section, before the final `--`:

```hoon
::  ==  telegram reader (version 29): the settings, the update, the window
::
::  gate and escalate are thresholds in hundredths, since a JSON 0.3 is a
::  cord the ship would otherwise have to parse as a fraction
+$  tg-config
  $:  enabled=?
      token=@t
      secret=@t
      api-url=@t
      public-url=@t
      model=@t
      max-tokens=@ud
      chats=(set @t)
      people=(map @t @t)
      gate=@ud
      escalate=@ud
      max-daily=@ud
  ==
::  +hundredths: a JSON number (0.3, "0.6", 1) as hundredths, 0 to 100
++  hundredths
  |=  [j=json default=@ud]
  ^-  @ud
  =/  t=@t
    ?+  -.j  ''
      %n  p.j
      %s  p.j
    ==
  ?:  =('' t)  default
  (min 100 (div (micro-of t) 10.000))
++  de-tg-config
  |=  j=json
  ^-  tg-config
  =/  chats=(set @t)
    %-  sy
    %+  turn  (ga j 'chats')
    |=  c=json
    ^-  @t
    ?+  -.c  ''
      %s  p.c
      %n  p.c
    ==
  =/  people=(map @t @t)
    =/  p=json  (gj j 'people')
    ?.  ?=([%o *] p)  ~
    %-  ~(gas by *(map @t @t))
    %+  murn  ~(tap by p.p)
    |=  [k=@t v=json]
    ?.(?=([%s *] v) ~ `[k p.v])
  :*  =/(e (gj j 'enabled') ?:(?=([%b *] e) p.e |))
      (gs j 'token')
      (gs j 'secret')
      =/(u (gs j 'api_url') ?:(=('' u) 'https://api.telegram.org' u))
      (gs j 'public_url')
      =/(m (gs j 'model') ?:(=('' m) 'deepseek/deepseek-v4-flash' m))
      (fall (gn j 'max_tokens') 4.000)
      (~(del in chats) '')
      people
      (hundredths (gj j 'gate') 30)
      (hundredths (gj j 'escalate') 60)
      (fall (gn j 'max_daily_messages') 500)
  ==
++  en-tg-config-masked
  |=  c=tg-config
  ^-  json
  %-  pairs:enjs:format
  :~  ['enabled' b+enabled.c]
      ['token_set' b+!=('' token.c)]
      ['secret_set' b+!=('' secret.c)]
      ['api_url' s+api-url.c]
      ['public_url' s+public-url.c]
      ['model' s+model.c]
      ['max_tokens' (numb:enjs:format max-tokens.c)]
      ['chats' a+(turn ~(tap in chats.c) |=(c=@t `json`s+c))]
      ['people' [%o (~(run by people.c) |=(v=@t `json`s+v))]]
      ['gate' (numb:enjs:format gate.c)]
      ['escalate' (numb:enjs:format escalate.c)]
      ['max_daily_messages' (numb:enjs:format max-daily.c)]
  ==
```

The page and the gate send `gate` and `escalate` as hundredths (30, 60) and read them back the same, so a PUT of `{"gate": 30}` keeps 30 (`hundredths` of the number `30` is 30 because `micro-of '30'` is 30,000,000 and divided by 10,000 is 3,000, capped to 100: wrong). Fix that in `hundredths`: a value at or above 1 is already hundredths:

```hoon
  =/  micro=@ud  (micro-of t)
  ?:  (gte micro 1.000.000)  (min 100 (div micro 1.000.000))
  (min 100 (div micro 10.000))
```

So `0.3` gives 30, `30` gives 30, `1` gives 1 (one hundredth: a caller who means "always" sends 100).

- [ ] **Step 4: The app side**

Falls, beside the generator's:

```hoon
          ::  the telegram reader (version 29): settings with the bot token
          ::  and webhook secret, never served; the context window, the
          ::  last update handled, the business connections checked, and
          ::  the inbox the webhook writes into
          [%fall %& [/ %'telegram.json'] [[/ %json] [%o (my ~[['enabled' b+|]])]]]
          [%fall %& [/ %'telegram-recent.json'] [[/ %json] [%o ~]]]
          [%fall %& [/ %'telegram-last.json'] [[/ %json] [%o ~]]]
          [%fall %& [/ %'telegram-connections.json'] [[/ %json] [%o ~]]]
          [%fall %| /telegram-inbox empty-dir:loader]
```

Routes, beside the generator's:

```hoon
  ?:  &(=('GET' meth) ?=([%api %telegram ~] suffix))         (own (serve-telegram eyre-id))
  ?:  &(=('PUT' meth) ?=([%api %telegram ~] suffix))         (own (serve-set-doc eyre-id 'set-telegram' jon))
  ?:  &(=('GET' meth) ?=([%api %telegram %last ~] suffix))   (own (serve-doc eyre-id %'telegram-last.json'))
```

The writer op in `apply`: `?:  =('set-telegram' op)  (do-set-telegram jon)`.

```hoon
::  +serve-telegram: the reader's settings without the token or secret
::
++  serve-telegram
  |=  eyre-id=@ta
  =/  m  (fiber:fiber:nexus ,~)
  ^-  form:m
  ;<  j=json  bind:m  (read-json (rf 1 / %'telegram.json'))
  (send-json eyre-id 200 (en-tg-config-masked:orr (de-tg-config:orr j)))
::  +do-set-telegram: merge the owner's settings over the stored ones; a
::  blank or missing token or secret keeps the stored one, a JSON null
::  clears it. The same shape as +do-set-generator.
::
++  do-set-telegram
  |=  jon=json
  =/  m  (fiber:fiber:nexus ,?)
  ^-  form:m
  ?.  ?=([%o *] jon)  (refuse 'set-telegram' 'expected an object')
  ;<  old=json  bind:m  (read-json (rf 0 / %'telegram.json'))
  =/  base=(map @t json)  ?:(?=([%o *] old) p.old ~)
  =/  merged=(map @t json)
    %+  roll  ~(tap by p.jon)
    |=  [[k=@t v=json] acc=_base]
    ?:  &(|(=('token' k) =('secret' k)) ?=([%s *] v) =('' p.v))  acc
    ?:  &(|(=('token' k) =('secret' k)) ?=(~ v))  (~(del by acc) k)
    (~(put by acc) k v)
  ;<  ~  bind:m  (over:io (rf 0 / %'telegram.json') [[/ %json] [%o merged]])
  ;<  ~  bind:m  (note 'set-telegram' & '')
  (pure:m |)
```

Note `(pure:m |)`: settings are not model state, the beacon does not move, the same as `do-set-generator`. Check how `do-set-generator` is written and match it line for line where they differ from the above; the intent above is the contract.

- [ ] **Step 5: Build on wex, run the unit test on feb**: lib and app `build: vase`; the feb suite shows `OK  /tests/lib/generator/test-tg-config`.

- [ ] **Step 6: Gate checks** (append to `scripts/api-matrix.py` before the `print()` of the verdict, a new section)

```python
# ---- the telegram reader's settings ----
curl('PUT', API + '/telegram', {'enabled': False, 'token': None, 'secret': None})
code, d = curl('GET', API + '/telegram')
check('telegram settings read masked', code == 200 and dictish(d).get('token_set') is False and 'token' not in dictish(d), (code, d))
code, d = curl('PUT', API + '/telegram', {'token': '123:abc', 'secret': 'hook-secret', 'chats': [1001], 'people': {'1001': 'person/me'}, 'gate': 30, 'escalate': 60})
time.sleep(0.5)
code, d = curl('GET', API + '/telegram')
check('the token and secret are set and never served', dictish(d).get('token_set') is True and dictish(d).get('secret_set') is True and '123:abc' not in json.dumps(d) and dictish(d).get('chats') == ['1001'], d)
code, d = curl('PUT', API + '/telegram', {'chats': [1001, 1002]})
time.sleep(0.5)
code, d = curl('GET', API + '/telegram')
check('a write without the token keeps it', dictish(d).get('token_set') is True and sorted(dictish(d).get('chats') or []) == ['1001', '1002'], d)
```

- [ ] **Step 7: Run the api gate, then commit**

```bash
git add code/lib/orrery.hoon code/nex/orrery/app.hoon tests/lib/generator.hoon scripts/api-matrix.py
git commit -m "The telegram reader's settings: the token and secret written once and never served, chats and people, thresholds, a daily cap"
```

---

### Task 2: The update and the window

**Files:**
- Modify: `code/lib/orrery.hoon` (telegram section)
- Test: `tests/lib/generator.hoon`

**Interfaces:**
- Produces: `+$  tg-msg  [chat=@t from=@t text=@t at=@da mid=@t business=@t]` (`business` is the connection id or `''`); `tg-message |=(update=json (unit tg-msg))`; `tg-source |=(m=tg-msg source)` giving `['chat' 'telegram/<chat>/<mid>']`; `tg-window |=([recent=json chat=@t] (list [id=@t at=@t who=@t text=@t]))` the chat's window oldest first; `tg-remember |=([recent=json m=tg-msg who=@t now=@da] json)` the window file with this message appended, five per chat, entries older than a day dropped.

- [ ] **Step 1: Failing tests**

```hoon
++  test-tg-message
  =/  up=json  (jo '{"update_id": 7, "message": {"message_id": 13, "date": 1789660800, "chat": {"id": -1001}, "from": {"id": 42}, "text": "  hi there "}}')
  =/  biz=json  (jo '{"update_id": 8, "business_message": {"message_id": 2, "date": 1789660800, "business_connection_id": "c1", "chat": {"id": 55}, "from": {"id": 55}, "text": "yo"}}')
  =/  got=(unit tg-msg:orr)  (tg-message:orr up)
  ;:  weld
    (expect !>(?=(^ got)))
    (expect-eq !>('-1001') !>(chat:(need got)))
    (expect-eq !>('42') !>(from:(need got)))
    (expect-eq !>('hi there') !>(text:(need got)))
    (expect-eq !>('13') !>(mid:(need got)))
    (expect-eq !>('') !>(business:(need got)))
    (expect-eq !>('2026-09-17T16:00:00Z') !>((en-iso:orr at:(need got))))
    (expect-eq !>('c1') !>(business:(need (tg-message:orr biz))))
    (expect-eq !>(*(unit tg-msg:orr)) !>((tg-message:orr (jo '{"update_id": 9, "edited_message": {}}'))))
    (expect-eq !>(`source:orr`['chat' 'telegram/-1001/13']) !>((tg-source:orr (need got))))
  ==
++  test-tg-window
  =/  m1=tg-msg:orr  ['1001' '42' 'first' (sub now ~h2) '1' '']
  =/  m2=tg-msg:orr  ['1001' '42' 'second' (sub now ~h1) '2' '']
  =/  old=tg-msg:orr  ['1001' '42' 'stale' (sub now ~d2) '0' '']
  =/  cmd=tg-msg:orr  ['1001' '42' '/status x' now '3' '']
  =/  w=json  (tg-remember:orr (jo '{}') old 'person/me' (sub now ~d2))
  =.  w  (tg-remember:orr w m1 'person/me' (sub now ~h2))
  =.  w  (tg-remember:orr w m2 'person/me' (sub now ~h1))
  =.  w  (tg-remember:orr w cmd 'person/me' now)
  =/  win  (tg-window:orr w '1001')
  =/  six=json
    %+  roll  (gulf 1 6)
    |=  [n=@ud acc=json]
    (tg-remember:orr acc ['9' '42' (crip (a-co:co n)) now (crip (a-co:co n)) ''] 'person/me' now)
  ;:  weld
    ::  the stale one aged out, the command never went in
    (expect-eq !>(`(list @t)`~['telegram/1001/1' 'telegram/1001/2']) !>((turn win |=([id=@t *] id))))
    (expect-eq !>('second') !>(text:(rear win)))
    (expect-eq !>('person/me') !>(who:(rear win)))
    (expect-eq !>(5) !>((lent (tg-window:orr six '9'))))
    (expect-eq !>('2') !>(text:(snag 0 (tg-window:orr six '9'))))
    (expect-eq !>(`(list [@t @t @t @t])`~) !>((tg-window:orr w '2')))
  ==
```

Note `tg-remember`'s `now` argument is the moment of remembering: entries whose `at` is more than a day before it are dropped.

- [ ] **Step 2: Run to see it fail** (`-find.tg-message`)

- [ ] **Step 3: Implement**

```hoon
::  the update, as far as the reader reads it
+$  tg-msg  [chat=@t from=@t text=@t at=@da mid=@t business=@t]
++  tg-message
  |=  update=json
  ^-  (unit tg-msg)
  =/  biz=json  (gj update 'business_message')
  =/  msg=json  ?:(?=([%o *] biz) biz (gj update 'message'))
  ?.  ?=([%o *] msg)  ~
  =/  num  |=(j=json ^-(@t ?+(-.j '' %n p.j, %s p.j)))
  =/  chat=@t  (num (gj (gj msg 'chat') 'id'))
  =/  from=@t  (num (gj (gj msg 'from') 'id'))
  ?:  |(=('' chat) =('' from))  ~
  =/  secs=@ud  (fall (gn msg 'date') 0)
  :-  ~
  :*  chat
      from
      (crip (trim-tape (trip (gs msg 'text'))))
      (add ~1970.1.1 (mul secs ~s1))
      (num (gj msg 'message_id'))
      ?:(?=([%o *] biz) (gs msg 'business_connection_id') '')
  ==
++  tg-source
  |=  m=tg-msg
  ^-  source
  ['chat' (rap 3 'telegram/' chat.m '/' mid.m ~)]
::  +tg-window: a chat's last free-text messages, oldest first, as the
::  analyst's context rows
++  tg-window
  |=  [recent=json chat=@t]
  ^-  (list [id=@t at=@t who=@t text=@t])
  %+  murn  (ga recent chat)
  |=  r=json
  ^-  (unit [id=@t at=@t who=@t text=@t])
  =/  id=@t  (gs r 'id')
  ?:(=('' id) ~ `[id (gs r 'at') (gs r 'who') (gs r 'text')])
::  +tg-remember: the window with this message appended: commands and
::  empty text never go in, five per chat, nothing older than a day
++  tg-remember
  |=  [recent=json m=tg-msg who=@t now=@da]
  ^-  json
  =/  base=(map @t json)  ?:(?=([%o *] recent) p.recent ~)
  ?:  |(=('' text.m) =('/' (end [3 1] text.m)))  [%o base]
  =/  cutoff=@da  (sub now ~d1)
  =/  kept=(list json)
    %+  skip  (ga recent chat.m)
    |=  r=json
    =/  at=(unit @da)  (de-iso (gs r 'at'))
    ?~(at & (lth u.at cutoff))
  =/  row=json
    %-  pairs:enjs:format
    :~  ['id' s+id:(tg-source m)]
        ['at' s+(en-iso at.m)]
        ['who' s+who]
        ['text' s+(end [3 2.000] text.m)]
    ==
  =/  all=(list json)  (snoc kept row)
  =/  n=@ud  (lent all)
  [%o (~(put by base) chat.m a+(slag (sub n (min n 5)) all))]
```

`~1970.1.1` plus seconds: check `unix-secs` in the lib (used by `act-id`) for the inverse and keep the two in step. If `tg-msg`'s tuple order in tests fails to nest, name every leg in the test literals the way the type does.

- [ ] **Step 4: Run the tests on feb: both OK. Commit.**

```bash
git add code/lib/orrery.hoon tests/lib/generator.hoon
git commit -m "The reader's update and its window: five free-text messages per chat, a day old at most"
```

---

### Task 3: Commands and the sender filter

**Files:**
- Modify: `code/lib/orrery.hoon`
- Test: `tests/lib/generator.hoon`

**Interfaces:**
- Produces: `+$  tg-facts  [bodies=(list json) obs=(list json) acts=(list json) notes=(list @t) escalate=(list @t)]` with `escalate` the ids for the urgent pass (empty list = no escalation; the fiber uses a separate flag, see Task 9); `tg-command |=([m=tg-msg who=@t] (unit tg-facts))`: `~` when the text is not a command, else the facts (or a note) for `/at`, `/status`, `/obs`, `/task`, and a note `commands: /at, /status, /obs, /task` for any other slash word. Observation rows here are JSON in the writer's observe shape: `subject`, `attr`, `value`, `at` (ISO), `conf` 100, `source`, `by` `telegram`. Action rows are JSON for `fill-act-as`: `kind`, `title`, optional `due`.

- [ ] **Step 1: Failing tests**

```hoon
++  test-tg-command
  =/  at=@da  ~2026.9.17..16.10.00
  =/  m  |=(t=@t ^-(tg-msg:orr ['1001' '42' t at '5' '']))
  =/  loc  (need (tg-command:orr (m '/at the shop') 'person/me'))
  =/  st   (need (tg-command:orr (m '/status - ') 'person/me'))
  =/  ob   (need (tg-command:orr (m '/obs thing/subaru status at the shop') 'person/me'))
  =/  tk   (need (tg-command:orr (m '/task Call the shop due 2026-10-02') 'person/me'))
  =/  bad  (need (tg-command:orr (m '/nope x') 'person/me'))
  =/  usage  (need (tg-command:orr (m '/at') 'person/me'))
  ;:  weld
    (expect-eq !>(*(unit tg-facts:orr)) !>((tg-command:orr (m 'car died') 'person/me')))
    (expect-eq !>('location') !>((gs:orr (snag 0 obs.loc) 'attr')))
    (expect-eq !>('the shop') !>((gs:orr (snag 0 obs.loc) 'value')))
    (expect-eq !>('person/me') !>((gs:orr (snag 0 obs.loc) 'subject')))
    (expect-eq !>('telegram/1001/5') !>((gs:orr (gj:orr (snag 0 obs.loc) 'source') 'id')))
    (expect-eq !>('2026-09-17T16:10:00Z') !>((gs:orr (snag 0 obs.loc) 'at')))
    (expect-eq !>(`json`~) !>((gj:orr (snag 0 obs.st) 'value')))
    (expect-eq !>('thing/subaru') !>((gs:orr (snag 0 obs.ob) 'subject')))
    (expect-eq !>('at the shop') !>((gs:orr (snag 0 obs.ob) 'value')))
    (expect-eq !>('Call the shop') !>((gs:orr (snag 0 acts.tk) 'title')))
    (expect-eq !>('2026-10-02T00:00:00Z') !>((gs:orr (snag 0 acts.tk) 'due')))
    (expect-eq !>(`(list @t)`~['commands: /at, /status, /obs, /task']) !>(notes.bad))
    (expect-eq !>(`(list @t)`~['usage: /at <place>']) !>(notes.usage))
    (expect-eq !>(0) !>((lent obs.usage)))
  ==
```

- [ ] **Step 2: Run to see it fail**

- [ ] **Step 3: Implement**

```hoon
+$  tg-facts
  $:  bodies=(list json)
      obs=(list json)
      acts=(list json)
      notes=(list @t)
      escalate=(list @t)
  ==
::  +tg-obs: one observation row in the writer's shape, signed telegram
++  tg-obs
  |=  [m=tg-msg subject=@t attr=@t value=json conf=@ud]
  ^-  json
  (obs-row subject attr value at.m ~ conf (tg-source m) 'telegram')
::  +parse-value: a command's value: a body id becomes a ref, "-" and
::  "null" become null, else the text
++  parse-value
  |=  t=@t
  ^-  json
  ?:  |(=('-' t) =('null' t))  ~
  ?^  (parse-bid t)  (pairs:enjs:format ~[['ref' s+t]])
  s+t
::  +tg-command: the slash grammar; ~ for free text
++  tg-command
  |=  [m=tg-msg who=@t]
  ^-  (unit tg-facts)
  ?.  =('/' (end [3 1] text.m))  ~
  =/  ws=(list tape)  (split-ws (trip text.m))
  ?~  ws  ~
  =/  cmd=@t  (crip (cass (scag (fall (find "@" i.ws) (lent i.ws)) i.ws)))
  =/  rest=@t  (crip (join-tapes " " t.ws))
  =/  usage  |=(u=@t ^-((unit tg-facts) `[~ ~ ~ ~[u] ~]))
  ?:  =('/at' cmd)
    ?:  =('' rest)  (usage 'usage: /at <place>')
    `[~ ~[(tg-obs m who 'location' (parse-value rest) 100)] ~ ~ ~]
  ?:  =('/status' cmd)
    ?:  =('' rest)  (usage 'usage: /status <text>, or /status - to clear')
    `[~ ~[(tg-obs m who 'status' ?:(=('-' rest) ~ s+rest) 100)] ~ ~ ~]
  ?:  =('/obs' cmd)
    =/  parts=(list tape)  t.ws
    ?:  (lth (lent parts) 3)  (usage 'usage: /obs <subject> <attr> <value>')
    =/  subject=@t  (crip (snag 0 parts))
    =/  attr=@t  (crip (cass (snag 1 parts)))
    ?.  (ok-attr attr)  (usage 'attr must be lowercase letters, digits and hyphens')
    =/  value=@t  (crip (join-tapes " " (slag 2 parts)))
    `[~ ~[(tg-obs m subject attr (parse-value value) 100)] ~ ~ ~]
  ?:  =('/task' cmd)
    ?:  =('' rest)  (usage 'usage: /task <title> [due YYYY-MM-DD]')
    =/  parts=(list tape)  t.ws
    =/  n=@ud  (lent parts)
    =/  due=(unit @t)
      ?.  (gte n 3)  ~
      ?.  =("due" (cass (snag (sub n 2) parts)))  ~
      =/  d=tape  (snag (dec n) parts)
      ?.  =(10 (lent d))  ~
      ?~((de-iso (crip d)) ~ `(crip (weld d "T00:00:00Z")))
    =/  title=@t
      ?~  due  rest
      (crip (join-tapes " " (scag (sub n 2) parts)))
    =/  act=json
      %-  pairs:enjs:format
      %-  zing
      :~  ~[['kind' s+'task'] ['title' s+(end [3 200] title)]]
          ?~(due ~ ~[['due' s+u.due]])
      ==
    `[~ ~ ~[act] ~ ~]
  (usage 'commands: /at, /status, /obs, /task')
```

`de-iso` takes a full ISO time; a bare date `2026-10-02` needs the `T00:00:00Z` before the check. Write it as `(de-iso (crip (weld d "T00:00:00Z")))` in the condition. The Python's `/obs` resolves the subject through `subject_of` (a body id, a person's name via `/resolve`, or `me`); the ship's version takes a body id only, and a subject that does not parse is refused with `usage: /obs <kind>/<slug> <attr> <value>` since the writer would drop an unknown subject anyway.

- [ ] **Step 4: Tests OK on feb. Commit.**

```bash
git commit -am "The reader's command grammar: /at, /status, /obs, /task, as the bot has them"
```

---

### Task 4: The reader's context and prompt

**Files:**
- Modify: `code/lib/orrery.hoon`
- Test: `tests/lib/generator.hoon`

**Interfaces:**
- Produces: `+$  ctx-body  [id=@t name=@t aliases=(list @t)]`; `+$  reader-ctx  [bodies=(list ctx-body) attrs=(map @t (list @t)) notes=(map @t (map @t @t)) me=@t kinds=(list @t) payloads=(map @t json)]`; `reader-context |=([all=(list loaded) schema=json now=@da] reader-ctx)`; `+$  window-row  [id=@t at=@t who=@t text=@t context=?]`; `reader-prompt |=([rows=(list window-row) ctx=reader-ctx tz=@t] @t)`. The prompt text follows `analyze.prompt` line for line: `Channel: telegram`, `The owner is person/me.`, attribute names by kind, what the attributes mean, action kinds and payload shapes, existing bodies, the earlier messages as context, the new messages, `---`, `Answer with the JSON object.`

- [ ] **Step 1: Failing test**

```hoon
++  test-reader-prompt
  =/  schema=json
    %-  jo
    '{"kinds": {"person": {"attrs": ["status", "location"], "notes": {"status": "what they are doing"}}, "situation": {"attrs": ["status"]}}, "actions": ["task", "note", "message", "calendar"], "payloads": {"calendar": {"title": "required", "starts": "required: ISO 8601 UTC"}, "message": {"via": "required: one of telegram, mail, chat", "to": "required: the body id", "text": "required"}, "note": {"text": "required"}}}'
  =/  all=(list loaded:orr)
    :~  (mkb 'person/me' %person 'me' ~['I'] ~ now)
        (mkb 'person/sarah' %person 'Sarah' ~['wife'] ~ now)
        (mkb 'situation/2026-05-01-old' %situation 'Old' ~ ~[['status' s+'closed'] ['ended' s+'2026-05-01T00:00:00Z']] (sub now ~d100))
        (mkb 'situation/2026-09-10-fresh' %situation 'Fresh' ~ ~[['status' s+'closed'] ['ended' s+'2026-09-10T00:00:00Z']] now)
    ==
  =/  ctx=reader-ctx:orr  (reader-context:orr all schema now)
  =/  rows=(list window-row:orr)
    :~  ['telegram/1/1' '2026-09-17T16:00:00Z' 'person/me' 'jury duty tomorrow' &]
        ['telegram/1/2' '2026-09-17T16:10:00Z' 'person/me' 'home now, car is at the shop' |]
    ==
  =/  p=tape  (trip (reader-prompt:orr rows ctx 'America/New_York'))
  ;:  weld
    (expect-eq !>(`(list @t)`~['task' 'calendar' 'message']) !>(kinds.ctx))
    (expect-eq !>(3) !>((lent bodies.ctx)))
    (expect !>(?=(^ (find "person/sarah | Sarah | wife" p))))
    (expect !>(?=(^ (find "Channel: telegram" p))))
    (expect !>(?=(^ (find "person: status, location" p))))
    (expect !>(?=(^ (find "person.status: what they are doing" p))))
    (expect !>(?=(^ (find "Action kinds you may propose: task, calendar, message" p))))
    (expect !>(?=(^ (find "calendar payload: {\"title\": \"required\"" p))))
    (expect !>(?=(^ (find "--- context telegram/1/1 | 2026-09-17T12:00:00-04:00 | from person/me" p))))
    (expect !>(?=(^ (find "New messages, oldest first:" p))))
    (expect !>(?=(^ (find "--- message telegram/1/2 | 2026-09-17T12:10:00-04:00 | from person/me" p))))
    (expect !>(?=(~ (find "situation/2026-05-01-old" p))))
    (expect !>(?=(^ (find "situation/2026-09-10-fresh" p))))
    (expect-eq !>("Answer with the JSON object.") !>((slag (sub (lent p) 28) p)))
  ==
```

The local time line: the Python prints the message time in the box's zone with its offset. The ship has no zone of its own; it takes `timezone` from the generator's config or `person/me.timezone`, the way `gen-pass` computes `tz`, and a fixed-offset rendering is enough for the model: implement `local-iso |=([at=@t tz=@t] @t)` that knows the US zones and Europe/London by name with a DST rule (second Sunday of March to first Sunday of November for the US, last Sunday of March to last Sunday of October for the UK) and falls back to the UTC text with `Z` for any other name. Put the zone table in the lib beside `en-iso`.

- [ ] **Step 2: Run to see it fail**

- [ ] **Step 3: Implement**

```hoon
+$  ctx-body  [id=@t name=@t aliases=(list @t)]
+$  reader-ctx
  $:  bodies=(list ctx-body)
      attrs=(map @t (list @t))
      notes=(map @t (map @t @t))
      me=@t
      kinds=(list @t)
      payloads=(map @t json)
  ==
+$  window-row  [id=@t at=@t who=@t text=@t context=?]
++  reader-kinds  `(list @t)`~['task' 'calendar' 'message']
++  reader-context
  |=  [all=(list loaded) schema=json now=@da]
  ^-  reader-ctx
  =/  multi=(set @t)  (multi-of schema)
  =/  cutoff=@da  (sub now ~d30)
  =/  bodies=(list ctx-body)
    %-  scag  :-  300
    %+  murn  all
    |=  l=loaded
    ^-  (unit ctx-body)
    ?:  &(=(%situation kind.body.l) (closed-before l multi cutoff now))  ~
    `[id.l name.body.l (sort ~(tap in aliases.body.l) aor)]
  =/  kinds-j=json  (gj schema 'kinds')
  =/  attrs=(map @t (list @t))
    ?.  ?=([%o *] kinds-j)  ~
    %-  ~(run by p.kinds-j)
    |=(spec=json (strings (ga spec 'attrs')))
  =/  notes=(map @t (map @t @t))
    ?.  ?=([%o *] kinds-j)  ~
    %-  ~(gas by *(map @t (map @t @t)))
    %+  murn  ~(tap by p.kinds-j)
    |=  [k=@t spec=json]
    =/  n=json  (gj spec 'notes')
    ?.  ?=([%o *] n)  ~
    :-  ~
    :-  k
    %-  ~(gas by *(map @t @t))
    (murn ~(tap by p.n) |=([a=@t v=json] ?.(?=([%s *] v) ~ `[a p.v])))
  =/  listed=(set @t)  (sy (strings (ga schema 'actions')))
  =/  kinds=(list @t)
    =/  k=(list @t)  (skim reader-kinds |=(x=@t (~(has in listed) x)))
    ?~(k ~['task'] k)
  =/  payloads=(map @t json)
    =/  p=json  (gj schema 'payloads')
    ?.  ?=([%o *] p)  ~
    %-  ~(gas by *(map @t json))
    (skim ~(tap by p.p) |=([k=@t v=json] &(?=([%o *] v) (lien kinds |=(x=@t =(x k))))))
  [bodies attrs notes 'person/me' kinds payloads]
::  +closed-before: a situation closed, with its end before the cutoff
++  closed-before
  |=  [l=loaded multi=(set @t) cutoff=@da now=@da]
  ^-  ?
  =/  w=(map @t (list row))  (fold rows.l multi now)
  ?.  =('closed' (winner-text w 'status'))  |
  =/  e=(unit @da)  (timed l w 'ended')
  =/  end=(unit @da)  ?^(e e (timed l w 'ends'))
  ?~(end (lth created.body.l cutoff) (lth u.end cutoff))
++  reader-prompt
  |=  [rows=(list window-row) ctx=reader-ctx tz=@t]
  ^-  @t
  =/  head=(list @t)
    :~  'Channel: telegram'
        (cat 3 'The owner is ' (cat 3 me.ctx '.'))
    ==
  =/  attr-lines=(list @t)
    ?:  =(~ attrs.ctx)  ~
    :-  'Attribute names by kind:'
    %+  turn  (sort ~(tap by attrs.ctx) |=([a=[@t *] b=[@t *]] (aor -.a -.b)))
    |=([k=@t names=(list @t)] (rap 3 '  ' k ': ' (join-cords ', ' names) ~))
  =/  note-lines=(list @t)
    ?:  =(~ notes.ctx)  ~
    :-  'What the attributes mean:'
    %-  zing
    %+  turn  (sort ~(tap by notes.ctx) |=([a=[@t *] b=[@t *]] (aor -.a -.b)))
    |=  [k=@t ns=(map @t @t)]
    %+  turn  (sort ~(tap by ns) |=([a=[@t *] b=[@t *]] (aor -.a -.b)))
    |=([a=@t t=@t] (rap 3 '  ' k '.' a ': ' t ~))
  =/  kind-lines=(list @t)
    :-  (cat 3 'Action kinds you may propose: ' (join-cords ', ' kinds.ctx))
    %+  turn  (sort ~(tap by payloads.ctx) |=([a=[@t *] b=[@t *]] (aor -.a -.b)))
    |=([k=@t shape=json] (rap 3 '  ' k ' payload: ' (en:json:html shape) ~))
  =/  body-lines=(list @t)
    :-  'Existing bodies (id | name | aliases):'
    ?~  bodies.ctx  ~['  (none known)']
    %+  turn  bodies.ctx
    |=(b=ctx-body (rap 3 '  ' id.b ' | ' name.b ' | ' (join-cords ', ' aliases.b) ~))
  =/  earlier=(list window-row)  (skim rows |=(r=window-row context.r))
  =/  fresh=(list window-row)  (skip rows |=(r=window-row context.r))
  =/  line  |=([r=window-row tag=@t] (rap 3 '--- ' tag ' ' id.r ' | ' (local-iso at.r tz) ' | from ' who.r ~))
  =/  msg-lines=(list @t)
    %-  zing
    :~  ?~  earlier  ~['Messages, oldest first:']
        :-  'Earlier messages, context only, oldest first (write no facts from these):'
        %-  zing
        (turn earlier |=(r=window-row ~[(line r 'context') (end [3 8.000] text.r)]))
        ?~(earlier ~ ~['New messages, oldest first:'])
        (zing (turn fresh |=(r=window-row ~[(line r 'message') (end [3 8.000] text.r)])))
        ~['---' 'Answer with the JSON object.']
    ==
  %+  join-cords  nl
  ;:  weld  head  attr-lines  note-lines  kind-lines  body-lines  ~['']  msg-lines  ==
```

The `%-  zing  :~ ... ==` with a `?~` inside a list needs each element to be a `(list @t)`; write `?~(earlier ~ ~['New messages, oldest first:'])` and the others as shown, casting with `` `(list @t)` `` where the compiler asks. `en:json:html` of a payload shape prints keys in map order, not insertion order: the test checks only the leading `{"title": "required"` of the calendar shape, so put `title` first by sorting nothing and accept the map's order in the test if it differs (adjust the expected fragment to whatever key the map puts first; the model reads either).

- [ ] **Step 4: Tests OK on feb. Commit.**

```bash
git commit -am "The reader's context and prompt, line for line as analyze.prompt writes them"
```

---

### Task 5: The analyst prompt cord and its drift check

**Files:**
- Modify: `code/lib/orrery.hoon` (`analyst-prompt`)
- Create: `scripts/prompt-drift.py`
- Test: run the script

**Interfaces:**
- Produces: `analyst-prompt` in the lib, a cord equal to `orrery-utils/common/analyst-prompt.md` byte for byte, the way `system-prompt` equals `generator-prompt.md`.

- [ ] **Step 1: Write the script**

```python
#!/usr/bin/env python3
"""prompt-drift: the lib's prompt cords are the shared files, byte for byte.

    python3 scripts/prompt-drift.py ../orrery-utils/common
"""
import re
import sys

utils = sys.argv[1].rstrip('/')
lib = open('code/lib/orrery.hoon').read()
PAIRS = [('system-prompt', 'generator-prompt.md'), ('analyst-prompt', 'analyst-prompt.md')]


def cord_of(arm):
    m = re.search(r"\n\+\+  %s\n  \^-  @t\n  '((?:[^'\\]|\\.)*)'" % re.escape(arm), lib, re.S)
    if not m:
        raise SystemExit('no cord for ' + arm)
    s = m.group(1)
    return s.replace("\\'", "'").replace('\\\\', '\\').replace('\\0a', '\n').replace('\\"', '"')


bad = 0
for arm, name in PAIRS:
    want = open('%s/%s' % (utils, name)).read()
    got = cord_of(arm)
    if got.strip() != want.strip():
        bad += 1
        print('DRIFT %s != %s' % (arm, name))
    else:
        print('ok   %s == %s' % (arm, name))
sys.exit(1 if bad else 0)
```

Read how `system-prompt` is written in the lib first (its escaping of quotes, backslashes and newlines) and make `cord_of` undo exactly that. If `system-prompt` uses a different rune shape than `^-  @t` followed by the cord, match the shape the lib uses; the script fails loudly when it cannot find the cord.

- [ ] **Step 2: Run it: expect `no cord for analyst-prompt`.**

- [ ] **Step 3: Add the cord** with a small helper that writes it from the file, so no hand escaping:

```python
import re
md = open('../orrery-utils/common/analyst-prompt.md').read().strip()
esc = md.replace('\\', '\\\\').replace("'", "\\'").replace('\n', '\\0a')
arm = "::  +analyst-prompt: orrery-utils/common/analyst-prompt.md, word for\n::  word; scripts/prompt-drift.py holds it there. Edit the file, not this.\n::\n++  analyst-prompt\n  ^-  @t\n  '%s'\n" % esc
lib = open('code/lib/orrery.hoon').read()
marker = '::  ==  telegram reader (version 29)'
lib = lib.replace(marker, arm + marker, 1)
open('code/lib/orrery.hoon', 'w').write(lib)
```

Check that `\0a` is how `system-prompt` carries its newlines; if it uses real newlines inside a multi-line cord form, use that form instead and change the script the same way.

- [ ] **Step 4: Run the script: two `ok` lines. Build the lib on wex: `vase`. Commit.**

```bash
git add code/lib/orrery.hoon scripts/prompt-drift.py
git commit -m "The analyst prompt lives in the lib, held to the shared file by a script"
```

---

### Task 6: Validation, the port of analyze.validate

**Files:**
- Modify: `code/lib/orrery.hoon`
- Test: `tests/lib/generator.hoon`

**Interfaces:**
- Produces: `validate-reader |=([answer=json rows=(list window-row) ctx=reader-ctx] tg-facts)` (the `escalate` leg empty; `bodies` are body JSON for the observe op `{id, name, aliases}` or `{id, aliases}` for a known body's new names; `obs` rows are the validated shape `{subject, attr, value, at, conf, message, until?}` where `message` is the window row id; `acts` are action JSON `{kind, title, about, message, due?, payload?}`); `plan-problem |=([payload=(map @t json) text=@t at=@t] (unit @t))` with the Task-4 rules of `analyze.plan_problem`; `fixes-a-time |=(text=@t ?)`.

- [ ] **Step 1: Failing tests** (the same cases `common/test_analyze.py` holds; keep the fixtures small)

```hoon
++  tg-ctx
  ^-  reader-ctx:orr
  :*  ~[['person/me' 'me' ~['I']] ['person/sarah' 'Sarah' ~['wife']] ['place/home' 'Home' ~] ['thing/subaru' 'the Subaru' ~['the car']]]
      (my ~[['person' `(list @t)`~['status' 'location' 'health']] ['thing' `(list @t)`~['status' 'location']] ['situation' `(list @t)`~['status' 'starts' 'location']]])
      ~
      'person/me'
      ~['task' 'calendar' 'message']
      %-  my
      :~  ['calendar' (jo '{"title": "required", "starts": "required: ISO 8601 UTC", "ends": "optional: ISO 8601 UTC", "location": "optional"}')]
          ['message' (jo '{"via": "required: one of telegram, mail, chat", "to": "required: the body id of the person", "text": "required"}')]
      ==
  ==
++  tg-rows
  ^-  (list window-row:orr)
  :~  ['telegram/1/1' '2026-09-17T16:00:00Z' 'person/me' 'jury duty tomorrow' &]
      ['telegram/1/2' '2026-09-17T16:10:00Z' 'person/me' 'home now, car is at the shop; dinner with sarah friday at 8 at the usual place' |]
  ==
++  test-validate-reader
  =/  answer=json
    %-  jo
    '{"bodies": [{"id": "place/johns-machine-shop", "name": "John\'s Machine Shop"}, {"id": "person/sara", "name": "sara"}, {"id": "Person/Me", "aliases": ["the boss"]}, {"id": "cat/x", "name": "x"}], "observations": [{"subject": "person/me", "attr": "location", "value": {"ref": "place/home"}, "conf": 80, "message": "telegram/1/2"}, {"subject": "person/me", "attr": "mood", "value": "tired", "message": "telegram/1/2"}, {"subject": "person/me", "attr": "status", "value": "on jury duty", "message": "telegram/1/1"}, {"subject": "thing/subaru", "attr": "status", "value": "at the shop", "message": "telegram/1/2"}, {"subject": "person/sara", "attr": "status", "value": "x", "message": "telegram/1/2"}, {"subject": "person/me", "attr": "income", "value": 5, "message": "telegram/1/2"}, {"subject": "situation/2026-09-19-x", "attr": "status", "value": "upcoming", "message": "telegram/1/2"}], "actions": [{"kind": "calendar", "title": "Dinner with Sarah", "about": ["person/sarah"], "payload": {"title": "Dinner with Sarah", "starts": "2026-09-19T20:00:00-04:00", "ends": "2026-11-01T00:00:00Z", "location": "the usual place"}, "message": "telegram/1/2"}, {"kind": "message", "title": "Tell Sarah", "payload": {"via": "Telegram", "to": "person/sara", "text": "hi"}, "message": "telegram/1/2"}, {"kind": "home", "title": "Porch", "payload": {"service": "x"}, "message": "telegram/1/2"}, {"kind": "task", "title": "Call the shop", "about": ["thing/subaru", "org/nope"], "due": "2026-09-18", "message": "telegram/1/2"}]}'
  =/  got=tg-facts:orr  (validate-reader:orr answer tg-rows tg-ctx)
  ;:  weld
    ::  bodies: the shop is new and kept (grounding decides later), sara is Sarah, me gains an alias, cat is no kind
    (expect-eq !>(`(list @t)`~['place/johns-machine-shop' 'person/me']) !>((turn bodies.got |=(b=json (gs:orr b 'id')))))
    (expect-eq !>(`(list @t)`~['the boss']) !>((strings:orr (ga:orr (snag 1 bodies.got) 'aliases'))))
    (expect !>((lien notes.got |=(n=@t =(n 'person/sara is person/sarah')))))
    ::  observations: mood is a sink, the context message yields nothing, income is unlisted, an upcoming status goes
    (expect-eq !>(`(list @t)`~['location' 'status' 'status']) !>((turn obs.got |=(o=json (gs:orr o 'attr')))))
    (expect-eq !>('person/sarah') !>((gs:orr (snag 2 obs.got) 'subject')))
    (expect-eq !>('2026-09-17T16:10:00Z') !>((gs:orr (snag 0 obs.got) 'at')))
    (expect-eq !>(80) !>((need (gn:orr (snag 0 obs.got) 'conf'))))
    (expect-eq !>(70) !>((need (gn:orr (snag 1 obs.got) 'conf'))))
    (expect !>((lien notes.got |=(n=@t ?=(^ (find "income" (trip n)))))))
    (expect !>((lien notes.got |=(n=@t ?=(^ (find "a situation is open, closed or cancelled" (trip n)))))))
    ::  actions: the plan stands with ends dropped, the message via is lower-cased and to canonised, home is not a reader's kind, the task's about keeps only known bodies
    (expect-eq !>(`(list @t)`~['calendar' 'message' 'task']) !>((turn acts.got |=(a=json (gs:orr a 'kind')))))
    (expect-eq !>(`json`~) !>((gj:orr (gj:orr (snag 0 acts.got) 'payload') 'ends')))
    (expect-eq !>('the usual place') !>((gs:orr (gj:orr (snag 0 acts.got) 'payload') 'location')))
    (expect-eq !>('2026-09-20T00:00:00Z') !>((gs:orr (gj:orr (snag 0 acts.got) 'payload') 'starts')))
    (expect-eq !>('telegram') !>((gs:orr (gj:orr (snag 1 acts.got) 'payload') 'via')))
    (expect-eq !>('person/sarah') !>((gs:orr (gj:orr (snag 1 acts.got) 'payload') 'to')))
    (expect-eq !>(`(list @t)`~['thing/subaru']) !>((strings:orr (ga:orr (snag 2 acts.got) 'about'))))
    (expect-eq !>('2026-09-18T00:00:00Z') !>((gs:orr (snag 2 acts.got) 'due')))
    (expect-eq !>('telegram/1/2') !>((gs:orr (snag 2 acts.got) 'message')))
  ==
++  test-plan-problem
  =/  p  |=(t=@t ^-((map @t json) ?:(?=([%o *] (jo t)) p:(jo t) ~)))
  =/  at=@t  '2026-09-19T12:00:00Z'
  ;:  weld
    (expect-eq !>(`(unit @t)`[~ 'the message fixes no time']) !>((plan-problem:orr (p '{"title": "Dinner", "starts": "2026-09-25T20:00:00Z"}') 'we should get dinner sometime' at)))
    (expect-eq !>(`(unit @t)`[~ 'the title is not in the message\'s words']) !>((plan-problem:orr (p '{"title": "Haircut", "starts": "2026-09-22T14:30:00Z"}') 'dentist tuesday at 2:30' at)))
    (expect-eq !>(`(unit @t)`[~ 'starts is not within the year ahead of the message']) !>((plan-problem:orr (p '{"title": "Dentist", "starts": "2027-11-22T14:30:00Z"}') 'dentist tuesday at 2:30' at)))
    (expect-eq !>(*(unit @t)) !>((plan-problem:orr (p '{"title": "Dentist", "starts": "2026-09-22T14:30:00Z"}') 'dentist tuesday at 2:30' at)))
    (expect !>((fixes-a-time:orr 'see you tonight')))
    (expect !>((fixes-a-time:orr 'on the 3rd')))
    (expect !>((fixes-a-time:orr 'Sep 12 works')))
    (expect !>(!(fixes-a-time:orr 'sometime soon')))
  ==
```

- [ ] **Step 2: Run to see it fail**

- [ ] **Step 3: Implement.** The rules, in the order the Python applies them, each as its own arm so the tests point at one:

```hoon
++  sink-attrs       `(set @t)`(sy `(list @t)`~['mood' 'feeling' 'feelings' 'emotion'])
++  sensitive-attrs  `(set @t)`(sy `(list @t)`~['health' 'income'])
++  body-kinds       `(set @t)`(sy `(list @t)`~['person' 'place' 'thing' 'org' 'situation' 'note' 'activity'])
::  +fixes-a-time: a day, a date or an hour in the words (analyze.FIXES_A_TIME)
++  fixes-a-time
  |=  text=@t
  ^-  ?
  =/  toks=(list tape)  (split-ws (cass (trip text)))
  =/  clean=(list tape)  (turn toks strip-punct-tail)
  =/  words=(set @t)  (sy (turn clean crip))
  ?:  (lien `(list @t)`~['noon' 'midnight' 'tonight' 'tomorrow' 'today'] |=(w=@t (~(has in words) w)))  &
  =/  day-heads=(list tape)  ~["mon" "tue" "wed" "thu" "fri" "sat" "sun"]
  =/  days=(list tape)  ~["mon" "monday" "tue" "tues" "tuesday" "wed" "wednesday" "thu" "thurs" "thursday" "fri" "friday" "sat" "saturday" "sun" "sunday"]
  ?:  (lien clean |=(t=tape (lien days |=(d=tape =(d t)))))  &
  ?:  (lien clean |=(t=tape |((is-time-token t) (is-slash-date t))))  &
  ?:  (lien clean |=(t=tape &((gte (lent t) 4) (is-digits (scag (sub (lent t) 2) t)) (lien `(list tape)`~["st" "nd" "rd" "th"] |=(s=tape =(s (slag (sub (lent t) 2) t)))))))  &
  ?:  (lien clean |=(t=tape &((gte (lent t) 4) (is-digits (scag (sub (lent t) 2) t)) =(':' (snag (sub (lent t) 3) t)))))  &
  =/  pairs  |-(^-(? ?~(clean | ?~(t.clean | ?:(&(|((is-clock i.clean) &((has-head i.clean month-heads))) ?|(&(=("at" i.clean) (is-clock i.t.clean)) &((has-head i.clean month-heads) (is-digits i.t.clean) (lte (lent i.t.clean) 2)) &((is-clock i.clean) |(=("am" i.t.clean) =("pm" i.t.clean))))) & $(clean t.clean)))))
  pairs
```

That last line is dense; write it as a plain loop over adjacent pairs instead:

```hoon
  =/  rest=(list tape)  clean
  |-
  ?~  rest  |
  ?~  t.rest  |
  =/  a=tape  i.rest
  =/  b=tape  i.t.rest
  ?:  &(=("at" a) (is-clock b))  &
  ?:  &((has-head a month-heads) (is-digits b) (lte (lent b) 2))  &
  ?:  &((is-clock a) |(=("am" b) =("pm" b)))  &
  $(rest t.rest)
```

The Python regex also accepts `\d{1,2}:\d{2}` (handled by `is-clock` with a colon: add a check `(is-clock t)` with length 4 or 5) and `\d{1,2}(:\d{2})?(am|pm)` glued (that is `is-time-token`). Keep `is-clock` for the bare `6` only inside the `at 6` and `6 pm` pairs, since a bare number fixes no time.

```hoon
::  +plan-problem: analyze.plan_problem: why a calendar action does not
::  stand against its message, or ~; ends and location are pruned in
::  place by the caller reading the returned map (see +hold-plan)
++  plan-problem
  |=  [payload=(map @t json) text=@t at=@t]
  ^-  (unit @t)
  ?.  (fixes-a-time text)  `'the message fixes no time'
  =/  words=(set @t)  (sy (skim (tokens text) |=(w=@t (gte (met 3 w) 3))))
  =/  title=@t  (fall (~(get by payload) 'title') '') 
  =/  title-words=(list @t)  (skim (tokens (ref-or-text title)) |=(w=@t (gte (met 3 w) 3)))
  ?.  (lien title-words |=(w=@t (~(has in words) w)))  `'the title is not in the message\'s words'
  =/  start=(unit @da)  (de-iso (ref-or-text (fall (~(get by payload) 'starts') ~)))
  ?~  start  `'starts is not a time'
  =/  when=@da  (fall (de-iso at) u.start)
  ?:  |((lth u.start (sub when ~h6)) (gth u.start (add when ~d366)))  `'starts is not within the year ahead of the message'
  ~
::  +hold-plan: the payload with ends and location kept only as the rules
::  allow: an end after the start and within a fortnight, a place the
::  message says
++  hold-plan
  |=  [payload=(map @t json) text=@t]
  ^-  (map @t json)
  =/  start=(unit @da)  (de-iso (ref-or-text (fall (~(get by payload) 'starts') ~)))
  =/  end=(unit @da)  (de-iso (ref-or-text (fall (~(get by payload) 'ends') ~)))
  =.  payload
    ?:  &(?=(^ start) ?=(^ end) (gth u.end u.start) (lte u.end (add u.start ~d14)))  payload
    (~(del by payload) 'ends')
  =/  loc=@t  (ref-or-text (fall (~(get by payload) 'location') ~))
  ?:  &(!=('' loc) ?=(^ (find (trip (lower loc)) (trip (lower text)))))  payload
  (~(del by payload) 'location')
```

`title` in the payload is `[%s @t]`; `ref-or-text` reads a string JSON as its text, which is what these want. Note `fall` on a `(unit json)` with `~` as the default: write `(fall (~(get by payload) 'title') `json`~)`.

Then the validator. The `canon` map and the `known` set grow as bodies are accepted, so it is one loop with state, written as three arms called in turn:

```hoon
++  validate-reader
  |=  [answer=json rows=(list window-row) ctx=reader-ctx]
  ^-  tg-facts
  =/  known=(set @t)  (sy (turn bodies.ctx |=(b=ctx-body id.b)))
  =/  ids=(list @t)  (turn (skip rows |=(r=window-row context.r)) |=(r=window-row id.r))
  =/  context-ids=(set @t)  (sy (turn (skim rows |=(r=window-row context.r)) |=(r=window-row id.r)))
  =/  at-of=(map @t @t)  (~(gas by *(map @t @t)) (turn rows |=(r=window-row [id.r at.r])))
  =/  text-of=(map @t @t)  (~(gas by *(map @t @t)) (turn rows |=(r=window-row [id.r text.r])))
  =/  last=@t  ?~(ids '' (rear ids))
  =/  vb  (validate-bodies (ga answer 'bodies') ctx known)
  =/  vo  (validate-obs (ga answer 'observations') ctx known.vb alias.vb ids context-ids at-of last)
  =/  va  (validate-acts (ga answer 'actions') ctx known.vb alias.vb ids context-ids at-of text-of last)
  [bodies.vb obs.vo acts.va :(weld notes.vb notes.vo notes.va) ~]
++  validate-bodies
  |=  [raw=(list json) ctx=reader-ctx known=(set @t)]
  ^-  [bodies=(list json) known=(set @t) alias=(map @t @t) notes=(list @t)]
  =|  out=(list json)
  =|  alias=(map @t @t)
  =|  notes=(list @t)
  =/  made=(list ctx-body)  ~
  |-
  ?~  raw  [(flop out) known alias (flop notes)]
  =/  b=json  i.raw
  ?.  ?=([%o *] b)  $(raw t.raw)
  =/  bid=@t  (lower (trim-cord (gs b 'id')))
  =/  pk  (parse-bid bid)
  ?~  pk  $(raw t.raw, notes [(cat 3 'dropped body with a bad id: ' bid) notes])
  ?.  (~(has in body-kinds) kind.u.pk)  $(raw t.raw, notes [(cat 3 'dropped body of an unknown kind: ' bid) notes])
  =/  aliases=(list @t)
    %+  scag  32
    %+  murn  (ga b 'aliases')
    |=(a=json ?.(?=([%s *] a) ~ =/(t (trim-cord p.a) ?:(=('' t) ~ `(end [3 100] t)))))
  ?:  (~(has in known) bid)
    =/  have=(set @t)
      =/  hit=(unit ctx-body)  (find-ctx bodies.ctx bid)
      ?~(hit ~ (~(put in (sy aliases.u.hit)) name.u.hit))
    =/  fresh=(list @t)  (skip aliases |=(a=@t (~(has in have) a)))
    ?~  fresh  $(raw t.raw)
    =/  row=json  (pairs:enjs:format ~[['id' s+bid] ['aliases' a+(turn fresh |=(a=@t `json`s+a))]])
    $(raw t.raw, out [row out])
  =/  name=@t
    =/  n=@t  (trim-cord (gs b 'name'))
    ?:(=('' n) (crip (turn (trip slug.u.pk) |=(c=@ ?:(=('-' c) ' ' c)))) (end [3 200] n))
  =/  cb=ctx-body  [bid name aliases]
  =/  twin=(unit @t)  (existing-for cb bodies.ctx made)
  ?^  twin
    $(raw t.raw, alias (~(put by alias) bid u.twin), notes [(rap 3 bid ' is ' u.twin ~) notes])
  =/  row=json
    %-  pairs:enjs:format
    %-  zing
    :~  ~[['id' s+bid] ['name' s+name]]
        ?~(aliases ~ ~[['aliases' a+(turn aliases |=(a=@t `json`s+a))]])
    ==
  $(raw t.raw, out [row out], known (~(put in known) bid), made (snoc made cb))
++  find-ctx
  |=  [bodies=(list ctx-body) id=@t]
  ^-  (unit ctx-body)
  ?~  bodies  ~
  ?:(=(id id.i.bodies) `i.bodies $(bodies t.bodies))
::  +existing-for: analyze.existing_for: a situation or activity with the
::  same normalised title, or the one person the same words name
++  existing-for
  |=  [b=ctx-body pool=(list ctx-body) made=(list ctx-body)]
  ^-  (unit @t)
  =/  all=(list ctx-body)  (weld pool made)
  =/  kind=@t  (end [3 (fall (find "/" (trip id.b)) 0)] id.b)
  ?:  |(=('situation' kind) =('activity' kind))
    =/  key=@t  (normalize-title name.b)
    ?:  =('' key)  ~
    =/  hit=(list ctx-body)
      %+  skim  all
      |=  x=ctx-body
      =/  k=@t  (end [3 (fall (find "/" (trip id.x)) 0)] id.x)
      &(|(=('situation' k) =('activity' k)) =(key (normalize-title name.x)))
    ?~(hit ~ `id.i.hit)
  ?.  =('person' kind)  ~
  =/  hits=(list ctx-body)
    %+  skim  all
    |=  x=ctx-body
    ?.  =('person/' (end [3 7] id.x))  |
    ?|  (same-person name.b name.x)
        (lien aliases.x |=(a=@t (same-person name.b a)))
    ==
  ?:  =(1 (lent hits))  `id.i.hits
  ?~  hits  ~
  =/  flat  |=(n=@t (crip (join-tapes " " (split-ws (cass (trip n))))))
  =/  exact=(list ctx-body)
    %+  skim  hits
    |=  x=ctx-body
    |(=((flat name.x) (flat name.b)) (lien aliases.x |=(a=@t =((flat a) (flat name.b)))))
  ?:(=(1 (lent exact)) `id.i.exact ~)
```

`validate-obs` and `validate-acts` follow the Python block for block; the rules to carry, in order, for an observation: not an object skip; `subject` canonised through `alias` and lower-cased; a `{ref}` value canonised the same way; subject not in known drop "dropped observation on an unknown body: "; `ok-attr` on the attr else "dropped observation with a bad attr: "; a situation's `status` not open/closed/cancelled drop with the times sentence; a sink attr skip silently; a `message` in context-ids skip silently; a kind the schema lists whose attr list does not hold the attr drop with "the owner's policy keeps it from keys" when the attr is in `sensitive-attrs` else "not an attribute of <kind>"; the value cleaned (`clean-value`: null, booleans and numbers as they are; a string trimmed and cut at 2,000 bytes; a `{ref}` whose ref parses as a body id; any other object or array kept when its JSON is at most 2,000 bytes; else a note); `message` set to the given id when it is one of the new ids else `last`; `at` from the row's ISO when it parses else the message's `at`; `conf` clamped 0 to 100 with 70 the default; `until` when it parses. For an action: `kind` lower-cased, `task` when blank; `title` trimmed and cut at 200; a `message` in context-ids skip; a kind not in `kinds.ctx` or an empty title drop "dropped action: <title>"; `about` canonised, kept when known, unique, at most 20; `message` as for observations; `due` when it parses; the payload held to the kind's shape from `payloads.ctx` (ISO keys normalised, required keys present else "dropped action <title>: payload lacks a, b", a `one of` key lower-cased and in the list else "dropped action <title>: <k> is <v>, not one of a, b", a `to` key described with "body id" canonised and known else "dropped action <title>: to names a body that does not exist: <v>"); a calendar action held by `plan-problem` (drop with its reason) and `hold-plan`, and a second plan from one message dropped "dropped action <title>: a second plan from one message". Write `one-of |=(shape-value=@t (list @t))` reading the words after `one of`, splitting on commas, spaces and the word `or`.

- [ ] **Step 4: Tests OK on feb. Commit.**

```bash
git commit -am "The reader's validation, rule for rule as analyze.validate holds a small model's answer"
```

---

### Task 7: Grounding, the port of bot.grounded

**Files:**
- Modify: `code/lib/orrery.hoon`
- Test: `tests/lib/generator.hoon`

**Interfaces:**
- Produces: `ground |=([facts=tg-facts rows=(list window-row) ctx=reader-ctx] tg-facts)`; `words |=(t=@t @t)` (the text lower-cased, tokens of `[a-z0-9']+` joined by single spaces with a space at each end); `named-in |=([text=@t bodies=(list ctx-body)] (set @t))`.

- [ ] **Step 1: Failing tests**

```hoon
++  test-ground
  =/  facts=tg-facts:orr
    %-  validate-reader:orr  :_  [tg-rows tg-ctx]
    %-  jo
    '{"bodies": [{"id": "place/johns-machine-shop", "name": "John\'s Machine Shop"}, {"id": "place/home", "aliases": ["the house", "next door"]}], "observations": [{"subject": "person/me", "attr": "location", "value": {"ref": "place/home"}, "conf": 80, "message": "telegram/1/2"}, {"subject": "thing/subaru", "attr": "location", "value": {"ref": "place/johns-machine-shop"}, "message": "telegram/1/2"}, {"subject": "thing/subaru", "attr": "status", "value": "at the shop", "message": "telegram/1/2"}, {"subject": "person/sarah", "attr": "status", "value": "on jury duty", "message": "telegram/1/2"}, {"subject": "person/me", "attr": "status", "value": "on jury duty", "message": "telegram/1/2"}, {"subject": "person/me", "attr": "health", "value": "covid positive", "message": "telegram/1/2"}], "actions": []}'
  =/  got=tg-facts:orr  (ground:orr facts tg-rows tg-ctx)
  ;:  weld
    ::  home is named (Home); the shop is not; the car's status is in the words; sarah is not named; my status echoes the earlier message
    (expect-eq !>(`(list @t)`~['location' 'status' 'health']) !>((turn obs.got |=(o=json (gs:orr o 'attr')))))
    (expect-eq !>(`(list @t)`~['person/me' 'thing/subaru' 'person/me']) !>((turn obs.got |=(o=json (gs:orr o 'subject')))))
    (expect !>((lien notes.got |=(n=@t =(n 'dropped thing/subaru.location: the message does not name place/johns-machine-shop')))))
    (expect !>((lien notes.got |=(n=@t =(n 'dropped person/sarah.status: not the author and not named in the message')))))
    (expect !>((lien notes.got |=(n=@t =(n 'dropped person/me.status: read from the earlier messages')))))
    ::  the shop body had no fact left about it; home keeps no alias the message does not use
    (expect-eq !>(`(list json)`~) !>(bodies.got))
    (expect !>((lien notes.got |=(n=@t =(n 'dropped body place/johns-machine-shop: no fact is about it')))))
  ==
++  test-ground-someone-else
  =/  rows=(list window-row:orr)  ~[['telegram/1/3' '2026-09-17T16:20:00Z' 'person/sarah' 'grandpa\'s flight got cancelled' |]]
  =/  facts=tg-facts:orr
    %-  validate-reader:orr  :_  [rows tg-ctx]
    (jo '{"bodies": [], "observations": [{"subject": "person/sarah", "attr": "status", "value": "flight cancelled", "message": "telegram/1/3"}], "actions": []}')
  =/  got=tg-facts:orr  (ground:orr facts rows tg-ctx)
  ;:  weld
    (expect-eq !>(0) !>((lent obs.got)))
    (expect !>((lien notes.got |=(n=@t =(n 'dropped person/sarah.status: the message is about someone else')))))
    (expect-eq !>(' car died on route 9 ') !>((words:orr 'Car died, on Route 9!')))
    (expect !>((~(has in (named-in:orr 'home now' bodies.tg-ctx)) 'place/home')))
    (expect !>((~(has in (named-in:orr 'sarah called' bodies.tg-ctx)) 'person/sarah')))
    (expect !>(!(~(has in (named-in:orr 'me too' bodies.tg-ctx)) 'person/me')))
  ==
```

The first test's health row: `covid positive` is a status word list hit only when the attr is `status`; here it is written as `health` directly and `health` is in the person's attrs, so it stands (the value shares `covid` with nothing in the text? It does not: the Python's paraphrase rule applies to `health` too, and drops it when it shares no word with the text but shares one with an earlier message; here it shares with neither, so it is kept). Keep the expectation as written and change it to match the Python's exact outcome if the port disagrees, by running the same answer through `bot.grounded` in orrery-utils first:

```bash
cd ../orrery-utils/telegram && python3 -c "import bot, json; print(bot.grounded(json.loads(open('/dev/stdin').read()), [...], {...}))"
```

- [ ] **Step 2: Run to see it fail**

- [ ] **Step 3: Implement**

```hoon
++  first-person   `(set @t)`(sy `(list @t)`~['i' 'i\'m' 'im' 'i\'ve' 'i\'ll' 'i\'d' 'me' 'my' 'mine' 'myself' 'we' 'we\'re' 'we\'ve' 'we\'ll' 'us' 'our' 'ours'])
++  someone-else   `(set @t)`(sy `(list @t)`~['he' 'he\'s' 'him' 'his' 'she' 'she\'s' 'her' 'hers' 'they' 'they\'re' 'them' 'their' 'grandma' 'grandpa' 'granny' 'nana' 'mom' 'mum' 'mother' 'dad' 'father' 'wife' 'husband' 'son' 'daughter' 'brother' 'sister' 'aunt' 'uncle' 'cousin' 'baby' 'kids' 'boss' 'friend'])
++  medical-words  `(set @t)`(sy `(list @t)`~['covid' 'flu' 'cancer' 'positive' 'diagnosed' 'diagnosis' 'infection' 'fever' 'surgery' 'chemo' 'pregnant' 'hospital' 'hospitalized' 'medication'])
++  paraphrased    `(set @t)`(sy `(list @t)`~['status' 'health'])
::  +word-list: the [a-z0-9']+ runs of a text, lower-cased
++  word-list
  |=  t=@t
  ^-  (list @t)
  =/  low=tape  (cass (trip t))
  %+  turn  (split-char ' ' (turn low |=(c=@ ?:(|(&((gte c 'a') (lte c 'z')) (is-digit c) =(c '\'')) c ' '))))
  crip
++  words  |=(t=@t ^-(@t (rap 3 ' ' (join-cords ' ' (word-list t)) ' ' ~)))
::  +named-in: bot.named_in: the bodies a text names, a name or alias as
::  whole words or a person's first name, three letters at least
++  named-in
  |=  [text=@t bodies=(list ctx-body)]
  ^-  (set @t)
  =/  said=@t  (words text)
  %-  sy
  %+  murn  bodies
  |=  b=ctx-body
  ^-  (unit @t)
  =/  names=(list @t)  [name.b aliases.b]
  =?  names  =('person/' (end [3 7] id.b))
    =/  first=(list @t)  (split-char ' ' (trip name.b))
    ?~(first names (snoc names (crip i.first)))
  ?:  %+  lien  names
      |=  n=@t
      =/  w=@t  (words n)
      ?:  (lth (met 3 (trim-cord n)) 3)  |
      ?:  =(' ' (trim-cord w))  |
      ?=(^ (find (trip w) (trip said)))
    `id.b
  ~
++  shares-a-word
  |=  [value=@t text=@t]
  ^-  ?
  =/  long=(set @t)  (sy (skim (word-list value) |=(w=@t (gte (met 3 w) 4))))
  (lien (word-list text) |=(w=@t (~(has in long) w)))
++  ground
  |=  [facts=tg-facts rows=(list window-row) ctx=reader-ctx]
  ^-  tg-facts
  =/  by-id=(map @t window-row)  (~(gas by *(map @t window-row)) (turn rows |=(r=window-row [id.r r])))
  =/  earlier=(list @t)  (turn (skim rows |=(r=window-row context.r)) |=(r=window-row text.r))
  =/  new-bodies=(list ctx-body)
    %+  murn  bodies.facts
    |=(b=json ?:(=('' (gs b 'name')) ~ `[(gs b 'id') (gs b 'name') (strings (ga b 'aliases'))]))
  =/  pool=(list ctx-body)  (weld bodies.ctx new-bodies)
  =|  keep=(list json)
  =|  notes=(list @t)
  =/  rest=(list json)  obs.facts
  |-
  ?~  rest
    =/  kept=(list json)  (flop keep)
    =/  used=(set @t)
      %-  sy
      %-  zing
      :~  (turn kept |=(o=json (gs o 'subject')))
          (murn kept |=(o=json =/(r (gs (gj o 'value') 'ref') ?:(=('' r) ~ `r))))
          (zing (turn acts.facts |=(a=json (strings (ga a 'about')))))
      ==
    =/  known=(set @t)  (sy (turn bodies.ctx |=(b=ctx-body id.b)))
    =/  said=@t  (words (join-cords ' ' (turn (skip rows |=(r=window-row context.r)) |=(r=window-row text.r))))
    =/  bodies-out
      %+  roll  bodies.facts
      |=  [b=json acc=[out=(list json) notes=(list @t)]]
      =/  id=@t  (gs b 'id')
      ?:  (~(has in known) id)
        =/  als=(list @t)  (skim (strings (ga b 'aliases')) |=(a=@t &(!=(' ' (words a)) ?=(^ (find (trip (words a)) (trip said))))))
        ?~  als  [out.acc [(cat 3 'dropped new names for ' (cat 3 id ': not in the message')) notes.acc]]
        [(snoc out.acc (pairs:enjs:format ~[['id' s+id] ['aliases' a+(turn als |=(a=@t `json`s+a))]])) notes.acc]
      ?:  (~(has in used) id)  [(snoc out.acc b) notes.acc]
      [out.acc [(rap 3 'dropped body ' id ': no fact is about it' ~) notes.acc]]
    [out.bodies-out kept acts.facts :(weld notes.facts (flop notes) (flop notes.bodies-out)) escalate.facts]
  =/  o=json  i.rest
  =/  m=window-row  (fall (~(get by by-id) (gs o 'message')) ['' '' '' '' |])
  =/  text=@t  text.m
  =/  said=(set @t)
    %-  sy
    %-  zing
    %+  turn  (word-list text)
    |=(w=@t ?:(=('\'s' (rsh [3 (sub (met 3 w) (min 2 (met 3 w)))] w)) ~[w (end [3 (sub (met 3 w) 2)] w)] ~[w]))
  =/  named=(set @t)  (named-in text pool)
  =/  others=(set @t)  (~(del in (sy (skim ~(tap in named) |=(n=@t =('person/' (end [3 7] n)))))) who.m)
  =/  subject=@t  (gs o 'subject')
  =/  attr=@t  (gs o 'attr')
  =/  value=json  (gj o 'value')
  =/  vtext=@t  (ref-or-text value)
  =/  medical=?  &(=('status' attr) ?=([%s *] value) (lien (word-list p.value) |=(w=@t (~(has in medical-words) w))))
  =/  kind=@t  (end [3 (fall (find "/" (trip subject)) 0)] subject)
  =/  listed=(list @t)  (fall (~(get by attrs.ctx) kind) ~)
  =/  why=@t
    ?:  =('?' (rsh [3 (dec (met 3 (trim-cord text)))] (trim-cord text)))  'a question states nothing'
    ?:  &(!=(subject who.m) !(~(has in named) subject))  'not the author and not named in the message'
    ?:  ?&  =(subject who.m)  !(~(has in named) subject)
            |(!=(~ (~(int in said) someone-else)) !=(~ others))
            =(~ (~(int in said) first-person))
        ==
      'the message is about someone else'
    ?:  &(medical !(lien listed |=(a=@t =('health' a))))  'a medical fact goes under health, which this key may not write'
    ?:  &(!(~(has in paraphrased) attr) ?=([%o *] value) !(~(has in named) (gs value 'ref')))  (cat 3 'the message does not name ' (gs value 'ref'))
    ?:  &(!(~(has in paraphrased) attr) ?=(?([%s *] [%n *]) value) ?=(~ (find (trip (lower vtext)) (trip (lower text)))))  'the value is not in the message'
    ?:  &((~(has in paraphrased) attr) ?=([%s *] value) !(shares-a-word p.value text) (lien earlier |=(e=@t (shares-a-word p.value e))))  'read from the earlier messages'
    ''
  ?.  =('' why)
    $(rest t.rest, notes [(rap 3 'dropped ' subject '.' attr ': ' why ~) notes])
  =/  fixed=json
    =/  at=@t  (gs o 'at')
    =/  o2=json
      ?.  &(=('T00:00:00Z' (rsh [3 10] at)) =((end [3 10] at) (end [3 10] at.m)))  o
      (set-key o 'at' s+at.m)
    ?.  medical  o2
    (set-key o2 'attr' s+'health')
  =?  notes  medical  [(rap 3 'moved ' subject '.status to health: a medical fact' ~) notes]
  $(rest t.rest, keep [fixed keep])
```

`set-key |=([j=json k=@t v=json] json)` puts one key on an object; write it beside `has-key` if the lib lacks one (check `with-default` and `force-string` near `fill-act-as`, which do the same kind of thing). The possessive line above builds `w` and `w` without the trailing `'s`; write it as a small `possessive-free` gate rather than the inline arithmetic if the compiler complains.

- [ ] **Step 4: Tests OK on feb. Commit.**

```bash
git commit -am "Grounding, the bot's rules: a fact traces to its message, a paraphrase to its words, a body to a fact about it"
```

---

### Task 8: The decider bodies and the HTTP call

**Files:**
- Modify: `code/lib/orrery.hoon` (`gate-body`, `status-body`, `escalate-body`, `noul-of`, `choice-of`, `known-lines`, `rank-bodies`)
- Modify: `code/nex/orrery/app.hoon` (`post-json` out of `ask-model`, `ask-decider`)
- Test: `tests/lib/generator.hoon`

**Interfaces:**
- Produces: `gate-body |=([rows=(list window-row) ctx=reader-ctx] json)` the decisions request body's `state` and `questions` for `worth_reading`; `escalate-body |=([rows ctx facts=(list json)] json)` for `needs_help_now`; `status-body |=([rows obs=(list json)] json)` for `status_<i>` choice questions over the person status rows; `noul-of |=([answers=json key=@t] @ud)` the probability in hundredths, 0 when absent; `choice-of |=([answers=json key=@t] [choice=@t p=@ud])`. In the app: `post-json |=([url=@t key=@t body=json timeout=@dr] [status=@ud body=@t secs=@ud])`, which `ask-model` now calls; `ask-decider |=([cfg=config:orr body=json] (unit json))` posting to `https://openrouter.ai/api/alpha/decisions` with the generator's key and provider rule, `~` on any failure.

- [ ] **Step 1: Failing tests**

```hoon
++  test-decider-bodies
  =/  g=json  (gate-body:orr tg-rows tg-ctx)
  =/  st=json  (gj:orr g 'state')
  =/  e=json  (escalate-body:orr tg-rows tg-ctx ~[(jo '{"subject": "person/me", "attr": "status", "value": "stranded, waiting for a tow"}')])
  =/  s=json  (status-body:orr tg-rows ~[(jo '{"subject": "person/me", "attr": "status", "value": "on jury duty"}') (jo '{"subject": "thing/subaru", "attr": "status", "value": "broken"}') (jo '{"subject": "person/me", "attr": "status", "value": "fed up"}')])
  ;:  weld
    (expect-eq !>('home now, car is at the shop; dinner with sarah friday at 8 at the usual place') !>((gs:orr st 'message')))
    (expect-eq !>('person/me') !>((gs:orr st 'from')))
    (expect-eq !>(`(list @t)`~['jury duty tomorrow']) !>((strings:orr (ga:orr st 'earlier'))))
    ::  ranked: the bodies the message names first, then people
    (expect-eq !>('person/sarah | Sarah | wife') !>((gs:orr (snag 0 (ga:orr st 'known_bodies')) '')))
    (expect !>((has-key:orr (gj:orr g 'questions') 'worth_reading')))
    (expect-eq !>('noul') !>((gs:orr (gj:orr (gj:orr g 'questions') 'worth_reading') 'type')))
    (expect-eq !>('stranded, waiting for a tow') !>((gs:orr (snag 0 (ga:orr (gj:orr e 'state') 'facts')) 'value')))
    (expect !>((has-key:orr (gj:orr e 'questions') 'needs_help_now')))
    (expect !>((has-key:orr (gj:orr s 'questions') 'status_0')))
    (expect !>((has-key:orr (gj:orr s 'questions') 'status_2')))
    (expect !>(!(has-key:orr (gj:orr s 'questions') 'status_1')))
    (expect-eq !>(88) !>((noul-of:orr (jo '{"worth_reading": {"type": "noul", "noul": 0.88}}') 'worth_reading')))
    (expect-eq !>(0) !>((noul-of:orr (jo '{}') 'worth_reading')))
    (expect-eq !>(`[@t @ud]`['feeling' 95]) !>((choice-of:orr (jo '{"status_2": {"type": "choice", "choice": "feeling", "probabilities": {"feeling": 0.95}}}') 'status_2')))
  ==
```

`known_bodies` entries are strings, so the check `(gs (snag 0 ...) '')` is wrong: use `(ref-or-text (snag 0 (ga st 'known_bodies')))` and compare to the string.

- [ ] **Step 2: Run to see it fail**

- [ ] **Step 3: Implement.** The question texts are `analyze.GATE_QUESTION`, `ESCALATE_QUESTION` and `STATUS_CRITERIA` word for word (copy them from `orrery-utils/common/analyze.py`; add the three to `scripts/prompt-drift.py` as a second kind of check that greps the Python for each `instructions` string and finds it in the lib):

```hoon
++  known-line
  |=  b=ctx-body
  ^-  @t
  (rap 3 id.b ' | ' name.b ?~(aliases.b '' (cat 3 ' | ' (join-cords ', ' aliases.b))) ~)
::  +rank-bodies: analyze.rank_bodies: the bodies the window names first,
::  then people, then activities, places and orgs, then situations, then
::  things; at most a thousand
++  rank-bodies
  |=  [bodies=(list ctx-body) rows=(list window-row)]
  ^-  (list ctx-body)
  =/  text=@t  (join-cords ' ' (turn rows |=(r=window-row text.r)))
  =/  named=(set @t)  (named-in text bodies)
  =/  rank
    |=  b=ctx-body
    ^-  @ud
    =/  k=@t  (end [3 (fall (find "/" (trip id.b)) 0)] id.b)
    =/  base=@ud
      ?+  k  5
        %person  1
        %activity  2
        %place  2
        %org  2
        %situation  3
        %thing  4
      ==
    ?:((~(has in named) id.b) 0 base)
  %+  scag  1.000
  %+  sort  bodies
  |=([a=ctx-body b=ctx-body] ?:(=((rank a) (rank b)) (aor id.a id.b) (lth (rank a) (rank b))))
++  gate-state
  |=  [rows=(list window-row) ctx=reader-ctx]
  ^-  json
  =/  new=(list window-row)  (skip rows |=(r=window-row context.r))
  =/  earlier=(list window-row)  (skim rows |=(r=window-row context.r))
  %-  pairs:enjs:format
  :~  ['message' s+?~(new '' text:(rear new))]
      ['from' s+?~(new '' who:(rear new))]
      ['earlier' a+(turn earlier |=(r=window-row `json`s+text.r))]
      ['known_bodies' a+(turn (rank-bodies bodies.ctx rows) |=(b=ctx-body `json`s+(known-line b)))]
      ['rule' s+'a status is a circumstance, never a feeling; only facts about people, things, places and plans are recorded']
  ==
++  noul-question
  |=  [instructions=@t yes=@t no=@t]
  ^-  json
  (pairs:enjs:format ~[['type' s+'noul'] ['instructions' s+instructions] ['criteria' (pairs:enjs:format ~[['true' s+yes] ['false' s+no]])]])
++  gate-body
  |=  [rows=(list window-row) ctx=reader-ctx]
  ^-  json
  %-  pairs:enjs:format
  :~  ['state' (gate-state rows ctx)]
      :-  'questions'
      %-  pairs:enjs:format
      :_  ~
      :-  'worth_reading'
      %^  noul-question
        'Does the new message state a fact worth recording about a person, thing, place, or a plan, that the analyst should read?'
        'it says where someone is, what they are dealing with, what happened, or what will happen, to whom and when'
      'chatter, greetings, feelings, jokes, a question, or a request that carries no fact about anyone'
  ==
++  escalate-body
  |=  [rows=(list window-row) ctx=reader-ctx facts=(list json)]
  ^-  json
  =/  st=json  (gate-state rows ctx)
  =/  st2=json
    =/  facts-j=json
      :-  %a
      %+  turn  (scag 40 facts)
      |=(o=json (pairs:enjs:format ~[['subject' s+(gs o 'subject')] ['attr' s+(gs o 'attr')] ['value' s+(ref-or-text (gj o 'value'))]]))
    (set-key (set-key st 'facts' facts-j) 'rule' s+'help within the hour means someone must act now; a plan or an update is not that')
  %-  pairs:enjs:format
  :~  ['state' st2]
      :-  'questions'
      %-  pairs:enjs:format
      :_  ~
      :-  'needs_help_now'
      %^  noul-question
        'Does the new message describe a situation in which the owner, or someone close to them, needs help within the hour?'
        'a breakdown, an accident, an injury or sudden illness, being stranded, locked out or without power, a child who must be picked up now, a missed or cancelled flight today, an emergency at home or at work'
      'a plan, news, a routine update, a feeling, a complaint, or anything that can wait until tomorrow'
  ==
++  status-body
  |=  [rows=(list window-row) obs=(list json)]
  ^-  json
  =/  new=(list window-row)  (skip rows |=(r=window-row context.r))
  =/  asked=(list [i=@ud o=json])
    =/  n=@ud  0
    |-  ^-  (list [i=@ud o=json])
    ?~  obs  ~
    =/  rest  $(obs t.obs, n +(n))
    ?:  &(=('status' (gs i.obs 'attr')) =('person/' (end [3 7] (gs i.obs 'subject'))))  [[n i.obs] rest]
    rest
  %-  pairs:enjs:format
  :~  :-  'state'
      %-  pairs:enjs:format
      :~  ['message' s+?~(new '' text:(rear new))]
          ['from' s+?~(new '' who:(rear new))]
          ['proposals' a+(turn asked |=([i=@ud o=json] (pairs:enjs:format ~[['n' (numb:enjs:format i)] ['subject' s+(gs o 'subject')] ['value' s+(ref-or-text (gj o 'value'))]])))]
          ['rule' s+'status on a person is what they are doing or dealing with right now, in plain words; never a feeling, a quote or a wish']
      ==
      :-  'questions'
      %-  pairs:enjs:format
      %+  turn  asked
      |=  [i=@ud o=json]
      :-  (crip "status_{(a-co:co i)}")
      %-  pairs:enjs:format
      :~  ['type' s+'choice']
          ['instructions' s+(rap 3 'Is this proposed status for the person a circumstance or a feeling? The proposal is n=' (crip (a-co:co i)) ': "' (ref-or-text (gj o 'value')) '".' ~)]
          :-  'criteria'
          %-  pairs:enjs:format
          :~  ['circumstance' s+'what the person is doing or dealing with right now, as an observer would put it: on jury duty, stranded waiting for a tow, travelling, sick, home with the kids']
              ['feeling' s+'how they feel about it: frustrated, happy, anxious, fed up, want to scream']
              ['neither' s+'not a status at all: a quote, a wish, a plan, a fact about something else']
          ==
      ==
  ==
```

Copy the three `STATUS_CRITERIA` strings from `analyze.py` exactly; the ones above are from memory and the drift check will say. Then:

```hoon
++  noul-of
  |=  [answers=json key=@t]
  ^-  @ud
  =/  a=json  (gj answers key)
  =/  n=json  (gj a 'noul')
  ?.  ?=([%n *] n)  0
  (min 100 (div (micro-of p.n) 10.000))
++  choice-of
  |=  [answers=json key=@t]
  ^-  [choice=@t p=@ud]
  =/  a=json  (gj answers key)
  =/  c=@t  (gs a 'choice')
  ?:  =('' c)  ['' 0]
  =/  p=json  (gj (gj a 'probabilities') c)
  [c ?.(?=([%n *] p) 0 (min 100 (div (micro-of p.p) 10.000)))]
```

In the app, lift the HTTP call out of `ask-model`:

```hoon
::  +post-json: one POST through iris, under the app's own timer (iris
::  has none); status 0 with why in the body when the timer wins or the
::  road is refused. +ask-model and +ask-decider both use it.
::
++  post-json
  |=  [url=@t key=@t body=json timeout=@dr wire=@ta]
  =/  m  (fiber:fiber:nexus ,[status=@ud body=@t secs=@ud])
  ^-  form:m
  =/  =request:http
    :^  %'POST'  url
      :~  ['content-type' 'application/json']
          ['authorization' (cat 3 'Bearer ' key)]
      ==
    `(as-octs:mimes:html (en:json:html body))
  ...the rest of ask-model's body, with /model replaced by /[wire] in the timer path checks...
++  ask-model
  |=  [cfg=config:orr parts=(list @t)]
  =/  m  (fiber:fiber:nexus ,[status=@ud body=@t secs=@ud])
  ^-  form:m
  (post-json (cat 3 url.cfg '/chat/completions') api-key.cfg (chat-body:orr cfg parts) ~m10 %model)
::  +ask-decider: one decisions call with the generator's key and provider
::  rule; ~ when it fails, so a decider that cannot answer decides nothing
::
++  ask-decider
  |=  [cfg=config:orr body=json]
  =/  m  (fiber:fiber:nexus ,(unit json))
  ^-  form:m
  =/  full=json
    =/  base=(map @t json)  ?:(?=([%o *] body) p.body ~)
    [%o (~(put by (~(put by base) 'model' s+'typesafe/jev-1.13') 'provider' (pairs:enjs:format ~[['zdr' b+&]]))]
  ;<  got=[status=@ud body=@t secs=@ud]  bind:m
    (post-json 'https://openrouter.ai/api/alpha/decisions' api-key.cfg full ~s30 %decider)
  ?.  =(200 status.got)  (pure:m ~)
  =/  resp=json  (fall (de:json:html body.got) ~)
  =/  answers=json  (gj:orr resp 'answers')
  (pure:m ?.(?=([%o *] answers) ~ `answers))
```

Two fibers may be inside `post-json` at once (the generator and the reader): each waits for `[/ %http-response]` on its own fiber, and iris answers the fiber that sent, so the wires do not cross. If the kernel's iris delivery is per nexus rather than per fiber, the reader must not overlap the generator: check `docs/spikes/2026-09-19-iris-probe.md` and the calendar's `fetch-hdr`, and if in doubt make the reader take the generator's `/model` answer as its own by tagging the timer paths and reading the response's wire. Prove it in the gate (Task 9 runs a reader message while a generator pass is in flight).

- [ ] **Step 4: Tests OK on feb; lib and app `vase` on wex; the api gate's generator section still green. Commit.**

```bash
git commit -am "The decider questions as the shared code asks them, and one HTTP call the model and the decider share"
```

---

### Task 9: The webhook, the inbox and the fiber

**Files:**
- Modify: `code/nex/orrery/app.hoon`
- Modify: `scripts/api-matrix.py` (a stub for the model, the decider and Telegram)
- Test: the api gate

**Interfaces:**
- Consumes: everything above.
- Produces: `POST /apps/orrery/telegram` (header `x-telegram-bot-api-secret-token` equal to the stored secret, else 403; a disabled reader answers 200 and drops; the update written to `/telegram-inbox/<update_id padded to 12 digits>` and `/telegram-inbox/rev` bumped); `telegram.sig`; `telegram-last.json` `{at, update_id, chat, from, outcome, notes, day, read_today}`; the record of the whole pipeline's notes for the page.

- [ ] **Step 1: The gate first** (append a section to `scripts/api-matrix.py`; the stub server the generator section starts already answers `/chat/completions` with `CANNED`; teach it two more paths)

```python
# ---- the telegram reader: a webhook update becomes facts through the stub model and decider ----
TG_CANNED = {'choices': [{'message': {'content': json.dumps({
    'bodies': [{'id': 'place/gate-shop', 'name': 'the gate shop'}],
    'observations': [{'subject': 'person/me', 'attr': 'status', 'value': 'stranded, waiting for a tow', 'conf': 85, 'message': 'telegram/1001/501'},
                     {'subject': 'thing/gate-car', 'attr': 'status', 'value': 'broken down', 'message': 'telegram/1001/501'},
                     {'subject': 'thing/gate-car', 'attr': 'location', 'value': {'ref': 'place/gate-shop'}, 'message': 'telegram/1001/501'}],
    'actions': [{'kind': 'task', 'title': 'Call a tow for the gate car', 'about': ['thing/gate-car'], 'message': 'telegram/1001/501'}]})}}],
    'usage': {'prompt_tokens': 10, 'completion_tokens': 5, 'cost': 0.0001}}
DECIDER_CANNED = {'answers': {'worth_reading': {'type': 'noul', 'noul': 0.9}, 'needs_help_now': {'type': 'noul', 'noul': 0.9},
                              'status_0': {'type': 'choice', 'choice': 'circumstance', 'probabilities': {'circumstance': 0.97}}}}
```

Make the stub's `do_POST` answer by path: `/chat/completions` with `CANNED` unless the request body's system prompt starts with `You read` (the analyst's), then `TG_CANNED`; `/api/alpha/decisions` with `DECIDER_CANNED`; `/bot123:abc/setWebhook` and `/bot123:abc/getBusinessConnection` with `{'ok': True, 'result': {'user': {'id': 1001}}}` (record every request in `seen` as now, path included: change the tuple to `(path, headers, body)` and fix the two existing checks that index it).

```python
curl('DELETE', API + '/body/thing/gate-car'); curl('DELETE', API + '/body/place/gate-shop')
observe([{'id': 'thing/gate-car', 'name': 'the gate car', 'aliases': ['gate car']}], [])
curl('PUT', API + '/generator', {'enabled': True, 'url': 'http://127.0.0.1:%d' % STUB_PORT, 'api_key': 'sk-stub', 'reasoning': {'enabled': False}, 'cooldown_minutes': 1440, 'max_daily': 1000})
curl('PUT', API + '/telegram', {'enabled': True, 'token': '123:abc', 'secret': 'hook-secret', 'api_url': 'http://127.0.0.1:%d' % STUB_PORT, 'public_url': 'http://localhost:8080',
                               'chats': [1001], 'people': {'1001': 'person/me'}, 'gate': 30, 'escalate': 60, 'max_daily_messages': 500})
time.sleep(1)
HOOK = HOST + '/apps/orrery/telegram'
def update(uid, mid, text, chat=1001, user=1001, business=None):
    msg = {'message_id': mid, 'date': int(time.time()), 'chat': {'id': chat}, 'from': {'id': user}, 'text': text}
    if business:
        msg['business_connection_id'] = business
        return {'update_id': uid, 'business_message': msg}
    return {'update_id': uid, 'message': msg}
def hook(body, secret='hook-secret'):
    cmd = ['curl', '-s', '-m', '30', '-X', 'POST', '-w', '\n%{http_code}', HOOK, '-H', 'content-type: application/json', '-d', json.dumps(body)]
    if secret is not None:
        cmd += ['-H', 'x-telegram-bot-api-secret-token: ' + secret]
    out = subprocess.run(cmd, capture_output=True, text=True).stdout
    return int(out.rpartition('\n')[2] or 0)
def tg_last(after_uid):
    deadline = time.time() + 60
    while time.time() < deadline:
        code, last = curl('GET', API + '/telegram/last')
        if dictish(last).get('update_id') == after_uid:
            return last
        time.sleep(2)
    return last
check('a wrong secret is refused', hook(update(1, 500, 'x'), secret='nope') == 403, None)
check('no secret is refused', hook(update(1, 500, 'x'), secret=None) == 403, None)
check('a body over 64 KB is refused before the parse', hook({'update_id': 1, 'pad': 'x' * 70000}) == 413, None)
code, d = curl('PUT', API + '/telegram', {'secret': 'short'})
check('a short secret is refused', code == 400, (code, d))
check('the webhook answers 200 at once', hook(update(2, 501, 'car died on route 9, stranded waiting for a tow')) == 200, None)
last = tg_last(2)
b = curl('GET', API + '/body/thing/gate-car')[1]
st = dictish(dictish(b).get('attrs')).get('status') or {}
check('the message became facts signed telegram with the message as source', st.get('value') == 'broken down' and st.get('by') == 'telegram' and dictish(st.get('source')) == {'kind': 'chat', 'id': 'telegram/1001/501'}, st)
check('a body the message does not name was dropped with its fact', 'place/gate-shop' not in {x['id'] for x in state()['bodies']} and any('no fact is about it' in n for n in dictish(last).get('notes', [])), last)
me = dictish(dictish(curl('GET', API + '/body/person/me')[1]).get('attrs')).get('status') or {}
check('the owner\'s status stands, checked as a circumstance', me.get('value') == 'stranded, waiting for a tow', me)
acts = [a for a in (curl('GET', API + '/actions?status=open')[1] or []) if a.get('title') == 'Call a tow for the gate car']
check('the task was filed by telegram', len(acts) == 1 and acts[0].get('by') == 'telegram', acts)
code, glast = curl('GET', API + '/generator/last')
check('the escalation ran an urgent pass', any(x.startswith('urgent pass') for x in dictish(glast).get('notes', [])), glast)
check('the record says what happened', dictish(last).get('outcome') == 'facts' and dictish(last).get('read_today', 0) >= 1, last)
check('a question yields nothing and is remembered as context', hook(update(3, 502, 'is the shop open?')) == 200 and dictish(tg_last(3)).get('outcome') == 'nothing', None)
check('a chat not in chats is ignored', hook(update(4, 503, 'hello', chat=9)) == 200 and dictish(tg_last(4)).get('outcome') == 'ignored', None)
check('a command writes without the model', hook(update(5, 504, '/at the gate shop')) == 200 and dictish(dictish(dictish(curl('GET', API + '/body/person/me')[1]).get('attrs')).get('location')).get('value') == 'the gate shop', None)
hook(update(6, 505, 'still on route 9', business='conn-1'))
check('a business message from a connection the stub owns is read', dictish(tg_last(6)).get('outcome') in ('facts', 'nothing'), tg_last(6))
check('the stub was asked the gate, the analyst, the status and the escalate questions', [p for p, _, _ in seen if 'decisions' in p] and any(p.endswith('/chat/completions') for p, _, _ in seen), [p for p, _, _ in seen][-8:])
curl('PUT', API + '/telegram', {'enabled': False, 'token': None, 'secret': None})
curl('PUT', API + '/generator', {'enabled': False, 'api_key': None, 'cooldown_minutes': 60})
curl('DELETE', API + '/body/thing/gate-car'); curl('DELETE', API + '/body/place/gate-shop')
for a in acts:
    curl('POST', API + '/actions/' + a['id'], {'status': 'dismissed', 'by': 'gate', 'note': 'gate'})
```

Run the gate: every new check fails (404 on the hook). That is the failing test.

- [ ] **Step 2: The route**, in `handle-request` before `;<  who=(unit actor)  bind:m  (identify req src our)`:

```hoon
  ::  the telegram webhook carries no cookie and no key: the secret header
  ::  is its whole credential, and it is answered before +identify
  ?:  &(=('POST' meth) ?=([%telegram ~] suffix))  (serve-telegram-hook eyre-id req)
```

```hoon
::  +serve-telegram-hook: an update from Telegram. The secret header must
::  equal the stored secret; the update goes to the inbox as its own grub
::  and the request answers at once, since Telegram gives up on a slow
::  answer and sends the update again. A disabled reader drops it.
::
++  serve-telegram-hook
  |=  [eyre-id=@ta req=inbound-request:eyre]
  =/  m  (fiber:fiber:nexus ,~)
  ^-  form:m
  ;<  cfg-j=json  bind:m  (read-json (rf 1 / %'telegram.json'))
  =/  cfg=tg-config:orr  (de-tg-config:orr cfg-j)
  =/  given=@t  (fall (get-header:http 'x-telegram-bot-api-secret-token' header-list.request.req) '')
  ?:  |(=('' secret.cfg) !=(given secret.cfg))  (send-err eyre-id 403 'forbidden')
  ?:  &(?=(^ body.request.req) (gth p.u.body.request.req 65.536))  (send-err eyre-id 413 'too large')
  ?.  enabled.cfg  (send-json eyre-id 200 (pairs:enjs:format ~[['ok' b+&] ['dropped' s+'the reader is off']]))
  =/  jon=json  (fall (de:json:html ?~(body.request.req '' q.u.body.request.req)) ~)
  =/  uid=@ud  (fall (gn:orr jon 'update_id') 0)
  =/  name=@ta  (crip ((d-co:co 12) uid))
  ;<  err=(unit tang)  bind:m
    (make-soft:io (rf 1 /telegram-inbox name) |+[[[/ %json] jon] ~])
  ;<  ~  bind:m  (over:io (rf 1 /telegram-inbox %rev) [[/ %json] (numb:enjs:format uid)])
  (send-json eyre-id 200 (pairs:enjs:format ~[['ok' b+&]]))
```

`(d-co:co 12)` pads to twelve digits so the inbox lists in update order as text. `make-soft` on an existing name (Telegram resent an update the reader has) answers an error; that is fine, the rev bump still wakes the fiber and the fiber handles the file once.

- [ ] **Step 3: The fiber**, in `on-file` beside the generator's:

```hoon
          ::  the telegram reader (version 29): wakes on the inbox, drains
          ::  it in update order, runs the bot's pipeline for each and
          ::  files the facts through the writer. It is never poked by
          ::  the writer; an urgent message pokes the generator.
          [~ %'telegram.sig']
        ;<  ~  bind:m  (rise-wait:io prod "%orrery telegram: failed")
        ;<  *  bind:m  (keep:io /tg (rf 0 /telegram-inbox %rev) ~)
        |-
        ;<  ~  bind:m  tg-drain
        ;<  *  bind:m  (take-gen-in /tg)
        $
```

with the fall `[%fall %& [/ %'telegram.sig'] [[/ %sig] ~]]` and `[%fall %& [/telegram-inbox %rev] [[/ %json] (numb:enjs:format 0)]]`.

```hoon
::  +tg-drain: every update in the inbox, in order, each handled then
::  culled, so a crash mid-way leaves the rest for the next wake
::
++  tg-drain
  =/  m  (fiber:fiber:nexus ,~)
  ^-  form:m
  ;<  vw=view:nexus  bind:m  (peek:io (rv 0 /telegram-inbox) ~)
  ?.  ?=([%ball *] vw)  (pure:m ~)
  ?~  fil.ball.vw  (pure:m ~)
  =/  names=(list @ta)
    %+  sort  (skip (turn ~(tap by contents.u.fil.ball.vw) head) |=(n=@ta =(%rev n)))
    aor
  |-
  ?~  names  (pure:m ~)
  ;<  update=json  bind:m  (read-json (rf 0 /telegram-inbox i.names))
  ;<  ~  bind:m  (tg-handle update)
  ;<  *  bind:m  (cull-soft:io (rf 0 /telegram-inbox i.names))
  $(names t.names)
```

If `cull-soft:io` takes a directory road only, cull the file with the road form `do-delete-body` uses for a body directory, applied to the file's own `rf` road; check `cull` in `lib/fiberio.hoon` of the grubbery desk.

```hoon
::  +tg-handle: one update: the filters, then a command or the model, then
::  the filing, then the window and the record
::
++  tg-handle
  |=  update=json
  =/  m  (fiber:fiber:nexus ,~)
  ^-  form:m
  ;<  now=@da  bind:m  get-time:io
  ;<  cfg-j=json  bind:m  (read-json (rf 0 / %'telegram.json'))
  =/  cfg=tg-config:orr  (de-tg-config:orr cfg-j)
  =/  uid=@ud  (fall (gn:orr update 'update_id') 0)
  =/  mu=(unit tg-msg:orr)  (tg-message:orr update)
  ?~  mu  (tg-record now uid '' '' 'ignored' ~['not a message'])
  =/  msg=tg-msg:orr  u.mu
  ?.  (~(has in chats.cfg) chat.msg)
    (tg-record now uid chat.msg from.msg 'ignored' ~[(rap 3 'chat ' chat.msg ' is not in chats' ~)])
  =/  who=(unit @t)  (~(get by people.cfg) from.msg)
  ?~  who  (tg-record now uid chat.msg from.msg 'ignored' ~[(rap 3 'sender ' from.msg ' is not in people' ~)])
  ;<  stranger=?  bind:m  (tg-stranger cfg business.msg)
  ?:  stranger  (tg-record now uid chat.msg from.msg 'ignored' ~['business connection of an account not in people'])
  ?:  =('' text.msg)  (tg-record now uid chat.msg from.msg 'ignored' ~['no text'])
  ;<  last=json  bind:m  (read-json (rf 0 / %'telegram-last.json'))
  =/  day=@t  (end [3 10] (en-iso:orr now))
  =/  today=@ud  ?:(=(day (gs:orr last 'day')) (fall (gn:orr last 'read_today') 0) 0)
  =/  cmd=(unit tg-facts:orr)  (tg-command:orr msg u.who)
  ?^  cmd
    ;<  ~  bind:m  (tg-file u.cmd u.who now)
    (tg-record now uid chat.msg from.msg ?:(=(~ obs.u.cmd) ?:(=(~ acts.u.cmd) 'refused' 'facts') 'facts') notes.u.cmd)
  ?:  (gte today max-daily.cfg)
    (tg-record now uid chat.msg from.msg 'held' ~['today\'s messages are spent'])
  ;<  facts=tg-facts:orr  bind:m  (tg-read cfg msg u.who now)
  ;<  ~  bind:m  (tg-file facts u.who now)
  ;<  recent=json  bind:m  (read-json (rf 0 / %'telegram-recent.json'))
  ;<  ~  bind:m  (over:io (rf 0 / %'telegram-recent.json') [[/ %json] (tg-remember:orr recent msg u.who now)])
  =/  outcome=@t  ?:(&(=(~ obs.facts) =(~ bodies.facts) =(~ acts.facts)) 'nothing' 'facts')
  (tg-record now uid chat.msg from.msg outcome notes.facts)
```

Remember the message even when the day's cap held it? No: a held message is not read and not context; the record says so. The window is written after reading, whatever the outcome, so a question rides along as the next message's context (the gate test expects that).

```hoon
::  +tg-read: the gate, the analyst, validation, grounding, the status
::  check and the escalate question, with the window as context
::
++  tg-read
  |=  [cfg=tg-config:orr msg=tg-msg:orr who=@t now=@da]
  =/  m  (fiber:fiber:nexus ,tg-facts:orr)
  ^-  form:m
  =/  q=?  =('?' (rsh [3 (dec (met 3 text.msg))] text.msg))
  ?:  q  (pure:m [~ ~ ~ ~['a question states nothing'] ~])
  ;<  gen-j=json  bind:m  (read-json (rf 0 / %'generator.json'))
  =/  gen=config:orr  (de-config:orr gen-j)
  ?:  =('' api-key.gen)  (pure:m [~ ~ ~ ~['no api_key set on the generator: the reader has no model'] ~])
  ;<  schema=json  bind:m  (read-json (rf 0 / %'schema.json'))
  ;<  all=(list loaded:orr)  bind:m  (load-bodies 0)
  ;<  recent=json  bind:m  (read-json (rf 0 / %'telegram-recent.json'))
  =/  ctx=reader-ctx:orr  (reader-context:orr all schema now)
  =/  rows=(list window-row:orr)
    %+  snoc
      (turn (tg-window:orr recent chat.msg) |=([id=@t at=@t w=@t t=@t] [id at w t &]))
    [id:(tg-source:orr msg) (en-iso:orr at.msg) who text.msg |]
  ;<  gate=(unit json)  bind:m  (ask-decider gen (gate-body:orr rows ctx))
  =/  p=@ud  ?~(gate 100 (noul-of:orr u.gate 'worth_reading'))
  =/  gate-note=@t
    ?~  gate  'gate unavailable, analyst asked'
    (rap 3 'gate: ' (crip (a-co:co p)) ?:((lth p gate.cfg) ', not read' ', read') ~)
  ?:  (lth p gate.cfg)  (pure:m [~ ~ ~ ~[gate-note] ~])
  =/  tz=@t
    =/  me=(unit loaded:orr)  (find-loaded all 'person/me')
    =/  from-me=@t  ?~(me '' (winner-text:orr (fold:orr rows.u.me (multi-of:orr schema) now) 'timezone'))
    ?:(=('' from-me) timezone.gen from-me)
  =/  small=config:orr  gen(model model.cfg, max-tokens max-tokens.cfg, reasoning [%o (my ~[['enabled' b+|]])])
  ;<  got=[status=@ud body=@t secs=@ud]  bind:m
    (post-json (cat 3 url.gen '/chat/completions') api-key.gen (chat-body:orr small ~[analyst-prompt:orr (reader-prompt:orr rows ctx tz)]) ~m5 %reader)
  ?.  =(200 status.got)  (pure:m [~ ~ ~ ~[gate-note (rap 3 'model: ' (crip (a-co:co status.got)) ' ' (end [3 200] body.got) ~)] ~])
  =/  ans  (answer-of:orr (fall (de:json:html body.got) [%o ~]))
  ?:  ?=(%| -.ans)  (pure:m [~ ~ ~ ~[gate-note p.ans] ~])
  =/  parsed=(unit json)  (parse-answer:orr text.p.ans)
  ?~  parsed  (pure:m [~ ~ ~ ~[gate-note 'model: the answer is not JSON'] ~])
  =/  facts=tg-facts:orr  (ground:orr (validate-reader:orr u.parsed rows ctx) rows ctx)
  =.  notes.facts  [gate-note notes.facts]
  ;<  facts  bind:m  (tg-status-check gen rows facts)
  ;<  esc=(unit json)  bind:m
    ?:  =(~ obs.facts)  (pure:(fiber:fiber:nexus ,(unit json)) ~)
    (ask-decider gen (escalate-body:orr rows ctx obs.facts))
  =/  e=@ud  ?~(esc 0 (noul-of:orr u.esc 'needs_help_now'))
  =?  notes.facts  ?=(^ esc)  (snoc notes.facts (rap 3 'escalate: ' (crip (a-co:co e)) ~))
  =?  escalate.facts  (gte e escalate.cfg)  [(urgent-ids:orr facts) ~]
  (pure:m facts)
```

`chat-body:orr` takes `parts`, the generator's list of prompt pieces with cache marks; pass the analyst prompt as the system part and the reader prompt as the one user part. Read `chat-body` and give it what it expects (it may take `[system user-parts]`; the intent is the same request shape the generator sends, reasoning off).

`escalate.facts` above is `(list @t)` for the ids and the fiber needs a flag too; make the leg `escalate=(unit (list @t))`: `~` no, `[~ ids]` yes. Fix `tg-facts` in Task 3 accordingly (the tests there build `~` for it either way). `urgent-ids |=(facts=tg-facts (list @t))`: the situations the observations and new bodies are about, else things, places and orgs, at most five, as `analyze.urgent_ids`.

```hoon
++  tg-status-check
  |=  [gen=config:orr rows=(list window-row:orr) facts=tg-facts:orr]
  =/  m  (fiber:fiber:nexus ,tg-facts:orr)
  ^-  form:m
  =/  asked=(list @ud)
    =/  n=@ud  0
    |-  ^-  (list @ud)
    ?~  obs.facts  ~
    =/  rest  $(obs.facts t.obs.facts, n +(n))
    ?:(&(=('status' (gs:orr i.obs.facts 'attr')) =('person/' (end [3 7] (gs:orr i.obs.facts 'subject')))) [n rest] rest)
  ?~  asked  (pure:m facts)
  ;<  ans=(unit json)  bind:m  (ask-decider gen (status-body:orr rows obs.facts))
  ?~  ans  (pure:m facts(notes (snoc notes.facts 'status check unavailable, kept')))
  =/  drop=(set @ud)
    %-  sy
    %+  skim  asked
    |=  i=@ud
    =/  c  (choice-of:orr u.ans (crip "status_{(a-co:co i)}"))
    &(!=('' choice.c) (gte p.c 60) !=('circumstance' choice.c))
  =/  kept=(list json)
    =/  n=@ud  0
    |-  ^-  (list json)
    ?~  obs.facts  ~
    =/  rest  $(obs.facts t.obs.facts, n +(n))
    ?:((~(has in drop) n) rest [i.obs.facts rest])
  =/  said=(list @t)
    %+  turn  ~(tap in drop)
    |=(i=@ud (rap 3 'status "' (ref-or-text (gj:orr (snag i obs.facts) 'value')) '": dropped as a feeling' ~))
  (pure:m facts(obs kept, notes (weld notes.facts said)))
::  +tg-file: the facts through the writer, then the urgent pass
::
++  tg-file
  |=  [facts=tg-facts:orr who=@t now=@da]
  =/  m  (fiber:fiber:nexus ,~)
  ^-  form:m
  =/  obs=(list json)  (turn obs.facts |=(o=json (tg-final-row o who)))
  ;<  *  bind:m  (file-ops (observe-ops:orr bodies.facts obs))
  =/  act-ops=(list json)
    %+  turn  acts.facts
    |=(a=json (pairs:enjs:format ~[['op' s+'act'] ['action' (fill-act-as:orr a now 'telegram')]]))
  ;<  *  bind:m  (file-ops act-ops)
  ?~  escalate.facts  (pure:m ~)
  ;<  *  bind:m
    %+  poke-soft:io  (rf 0 / %'gen.sig')
    [[/ %json] (pairs:enjs:format ~[['force' b+&] ['about' a+(turn u.escalate.facts |=(x=@t `json`s+x))]])]
  (pure:m ~)
```

`tg-final-row` turns a validated observation (`subject`, `attr`, `value`, `at`, `conf`, `message`, `until`) into the writer's row: `source` from the `message` id (`{"kind": "chat", "id": <message>}`), `by` `telegram`, the `message` key dropped. The `obs-row` arm from the reconcile section builds the shape; use it with the source `['chat' message]`. `observe-ops` batches fifty bodies and two hundred rows, as the route does.

`tg-stranger |=([cfg=tg-config:orr conn=@t] ?)`: `|` when `conn` is `''`; else the connection's owner from `telegram-connections.json`, or one `GET <api_url>/bot<token>/getBusinessConnection?business_connection_id=<conn>` through `post-json`'s sibling `get-json` (write it beside `post-json`, a GET with no body and no bearer header) remembered in the file under the connection id; `&` when the owner's user id is not in `people.cfg`.

```hoon
++  tg-record
  |=  [now=@da uid=@ud chat=@t from=@t outcome=@t notes=(list @t)]
  =/  m  (fiber:fiber:nexus ,~)
  ^-  form:m
  ;<  last=json  bind:m  (read-json (rf 0 / %'telegram-last.json'))
  =/  day=@t  (end [3 10] (en-iso:orr now))
  =/  today=@ud  ?:(=(day (gs:orr last 'day')) (fall (gn:orr last 'read_today') 0) 0)
  =/  read=?  |(=('facts' outcome) =('nothing' outcome))
  %+  over:io  (rf 0 / %'telegram-last.json')
  :-  [/ %json]
  %-  pairs:enjs:format
  :~  ['at' s+(en-iso:orr now)]
      ['update_id' (numb:enjs:format uid)]
      ['chat' s+chat]
      ['from' s+from]
      ['outcome' s+outcome]
      ['notes' a+(turn (scag 20 notes) |=(n=@t `json`s+(end [3 300] n)))]
      ['day' s+day]
      ['read_today' (numb:enjs:format ?:(read +(today) today))]
  ==
```

A command's outcome counts as read too when it wrote; keep `read` as the two outcomes that ran the model, since the cap is about the model.

- [ ] **Step 4: Build on wex (`vase` for lib and app), run the api gate: the telegram section green and every earlier section still green.** If the reader's iris answer lands on the generator fiber or the other way round, that shows here as the gate's generator checks failing with the reader's canned answer; then tag the requests (the `wire` argument of `post-json` names the timer only, the response has no wire) by running the reader's model call through the generator fiber instead: the reader pokes `gen.sig` with `{"read": <prompt>}` and takes the answer back as a poke. Prefer proving the simple form works first; the calendar desk runs a fetch fiber beside the sync fiber the same way.

- [ ] **Step 5: Commit**

```bash
git add code/nex/orrery/app.hoon scripts/api-matrix.py
git commit -m "The telegram reader: a webhook into an inbox, a fiber that drains it through the gate, the analyst, validation, grounding, the status check and the escalate question, and files the facts signed telegram"
```

---

### Task 10: The webhook registration route

**Files:**
- Modify: `code/nex/orrery/app.hoon`
- Test: `scripts/api-matrix.py`

**Interfaces:**
- Produces: `POST /api/telegram/webhook` (owner): the ship calls `<api_url>/bot<token>/setWebhook` with `{"url": "<public_url>/apps/orrery/telegram", "secret_token": <secret>, "allowed_updates": ["message", "business_message"]}` and answers `{"ok": <Telegram's ok>, "description": <Telegram's description>}`; 400 when the token, secret or public URL is blank.

- [ ] **Step 1: Gate check** (in the telegram section, while the stub token is set)

```python
code, d = curl('POST', API + '/telegram/webhook')
check('the ship registers its webhook with telegram', code == 200 and dictish(d).get('ok') is True, (code, d))
sw = [b for p, _, b in seen if p.endswith('/setWebhook')]
check('setWebhook carried the public url, the secret and the update kinds', sw and sw[-1].get('url') == 'http://localhost:8080/apps/orrery/telegram' and sw[-1].get('secret_token') == 'hook-secret' and sw[-1].get('allowed_updates') == ['message', 'business_message'], sw[-1:] )
```

- [ ] **Step 2: Implement**

```hoon
  ?:  &(=('POST' meth) ?=([%api %telegram %webhook ~] suffix))  (own (serve-set-webhook eyre-id))
```

```hoon
++  serve-set-webhook
  |=  eyre-id=@ta
  =/  m  (fiber:fiber:nexus ,~)
  ^-  form:m
  ;<  cfg-j=json  bind:m  (read-json (rf 1 / %'telegram.json'))
  =/  cfg=tg-config:orr  (de-tg-config:orr cfg-j)
  ?:  |(=('' token.cfg) =('' secret.cfg) =('' public-url.cfg))
    (send-err eyre-id 400 'the token, the secret and the public URL must be set first')
  =/  body=json
    %-  pairs:enjs:format
    :~  ['url' s+(cat 3 public-url.cfg '/apps/orrery/telegram')]
        ['secret_token' s+secret.cfg]
        ['allowed_updates' a+~[s+'message' s+'business_message']]
    ==
  ;<  got=[status=@ud body=@t secs=@ud]  bind:m
    (post-json (rap 3 api-url.cfg '/bot' token.cfg '/setWebhook' ~) '' body ~s30 %webhook)
  =/  resp=json  (fall (de:json:html body.got) [%o ~])
  %^  send-json  eyre-id  ?:(=(200 status.got) 200 502)
  (pairs:enjs:format ~[['ok' (gj:orr resp 'ok')] ['description' (gj:orr resp 'description')]])
```

`post-json` with an empty key must send no authorization header: make the header list conditional on `key`.

- [ ] **Step 3: Gate green. Commit.**

```bash
git commit -am "The ship registers its own webhook with Telegram"
```

---

### Task 11: The page

**Files:**
- Modify: `code/nex/orrery/orrery.js`, `code/nex/orrery/orrery.css`
- Test: `scripts/page-test.js`

**Interfaces:**
- Produces: `telegramCard(t, last)` rendered under the Reconcile card in `settings(schema, policy, generator, last, reconcile, telegram, telegramLast)`; the settings route fetches `/telegram` and `/telegram/last` as well; buttons `data-save-telegram` (PUT the form) and `data-webhook` (POST `/telegram/webhook`).

- [ ] **Step 1: Failing page tests**

```javascript
const tg = { enabled: true, token_set: true, secret_set: false, api_url: 'https://api.telegram.org', public_url: 'https://ship.example', model: 'deepseek/deepseek-v4-flash', max_tokens: 4000, chats: ['1001'], people: { '1001': 'person/me' }, gate: 30, escalate: 60, max_daily_messages: 500 };
const tgLast = { at: '2026-09-20T13:00:00Z', update_id: 7, chat: '1001', from: '1001', outcome: 'facts', notes: ['gate: 90, read', 'escalate: 12'], day: '2026-09-20', read_today: 3 };
const tgSettings = render.settings({ kinds: {} }, {}, gen, genLast, {}, tg, tgLast);
ok('the telegram card follows reconcile with the token masked and the secret wanted', tgSettings.indexOf('<h2>Reconcile</h2>') < tgSettings.indexOf('<h2>Telegram</h2>') && tgSettings.includes('a token is set') && tgSettings.includes('no secret set') && !tgSettings.includes('123:abc'));
ok('the card holds chats, people, thresholds and the cap', tgSettings.includes('name="chats" value="1001"') && tgSettings.includes('"1001": "person/me"') && tgSettings.includes('name="gate" value="30"') && tgSettings.includes('name="max_daily_messages" value="500"'));
ok('the card offers save and register', tgSettings.includes('data-save-telegram="1"') && tgSettings.includes('data-webhook="1"'));
ok('the last update is summarised', tgSettings.includes('Last update 7') && tgSettings.includes('facts') && tgSettings.includes('Read today: 3') && tgSettings.includes('gate: 90, read'));
ok('a reader that never ran shows the card without a last line', !render.settings({ kinds: {} }, {}, gen, genLast, {}, { enabled: false }, {}).includes('Last update'));
```

- [ ] **Step 2: Run: fails on `telegramCard`/the sixth argument.**

- [ ] **Step 3: Implement** beside `reconcileCard`:

```javascript
  // the telegram card: the reader's settings, the token and secret written
  // and never read back, the webhook registered from here, the last update
  function telegramCard(t, last) {
    t = t || {}; last = last || {};
    var people = t.people ? JSON.stringify(t.people) : '{}';
    var out = '<div class="card"><h2>Telegram</h2><div id="telegram">' +
      '<p><label class="box"><input type="checkbox" name="enabled"' + (t.enabled ? ' checked' : '') + '> on: the ship reads the chats below through its webhook</label></p>' +
      '<p><label class="field">bot token <input name="token" type="password" placeholder="' + (t.token_set ? 'a token is set; leave blank to keep it' : 'no token set') + '"></label> ' +
      '<label class="field">webhook secret <input name="secret" type="password" placeholder="' + (t.secret_set ? 'a secret is set; leave blank to keep it' : 'no secret set') + '"></label></p>' +
      '<p><label class="field">public URL of this ship <input name="public_url" value="' + esc(t.public_url || '') + '" placeholder="https://your.ship"></label> ' +
      '<label class="field">reader model <input name="model" value="' + esc(t.model || '') + '"></label></p>' +
      '<p><label class="field">chats (ids, comma separated) <input name="chats" value="' + esc((t.chats || []).join(',')) + '"></label></p>' +
      '<p><label class="field wide">people (Telegram user id to body id, JSON) <textarea name="people" rows="3">' + esc(people) + '</textarea></label></p>' +
      '<p><label class="field">gate (hundredths) <input name="gate" value="' + esc(t.gate != null ? t.gate : '') + '"></label> ' +
      '<label class="field">escalate (hundredths) <input name="escalate" value="' + esc(t.escalate != null ? t.escalate : '') + '"></label> ' +
      '<label class="field">messages per day at most <input name="max_daily_messages" value="' + esc(t.max_daily_messages != null ? t.max_daily_messages : '') + '"></label></p>' +
      '<p><button data-save-telegram="1">save telegram</button><button data-webhook="1">register the webhook</button></p></div>';
    if (last.at) {
      out += '<p class="muted">Last update ' + esc(String(last.update_id)) + ' at ' + fmtTime(last.at) + ' from ' + esc(last.from || '') + ' in ' + esc(last.chat || '') + ': ' + esc(last.outcome || '') + '. Read today: ' + (last.read_today || 0) + '.</p>';
      (last.notes || []).forEach(function (n) { out += '<p class="muted">' + esc(n) + '</p>'; });
    }
    return out + '</div>';
  }
```

`settings` takes the two extra arguments and appends `telegramCard(telegram, telegramLast)` after `reconcileCard(reconcile)`; the settings route's `Promise.all` gains `api('/telegram')` and `api('/telegram/last')`; the click handler gains:

```javascript
    } else if (b.dataset.saveTelegram) {
      post('/telegram', telegramForm(), 'PUT').then(function () { say('telegram saved'); later(); }).catch(function (e) { say(e.message, true); });
    } else if (b.dataset.webhook) {
      post('/telegram/webhook', {}).then(function (d) { say(d && d.ok ? 'webhook registered' : 'telegram said: ' + (d && d.description)); }).catch(function (e) { say(e.message, true); });
    }
```

and `telegramForm()` reads the fields the way `generatorForm()` does: `chats` split on commas and trimmed, `people` parsed as JSON (a parse error is `say`'d and the save stops), `gate`, `escalate` and `max_daily_messages` as integers, `token` and `secret` only when non-blank. The CSS rule for `#generator .field` gains `#telegram`.

- [ ] **Step 4: Page test green (`ALL OK (56 checks)`). Commit.**

```bash
git commit -am "A Telegram card under Settings: the token and secret written once, chats and people, the webhook registered from the page, the last update"
```

---

### Task 12: Documentation

**Files:**
- Modify: `README.md` (route rows; a paragraph after the generator's; the Under the hood list gains the reader's files), `docs/releasing.md` (no new consent: iris is granted already; the owner sets the token, the secret and the public URL, then presses register), `orrery-utils/telegram/README.md` (the bot is the backfill and dry run, and the reader for a ship older than 29; the same config keys), `orrery-utils/docs/writing-a-client.md` (a line under rule 9 and rule 16 that the ship's own reader follows them, and where its window lives).

- [ ] **Step 1: README rows**

```
| `POST /telegram` | Telegram's webhook; the secret header is its credential; answers at once |
| `GET` and `PUT /telegram` | the reader's settings, the token and secret masked as `token_set` and `secret_set`; owner only |
| `GET /telegram/last` | the last update handled: outcome, notes, messages read today |
| `POST /telegram/webhook` | register this ship's webhook with Telegram; owner only |
```

- [ ] **Step 2: README paragraph**, after the generator's:

"The ship reads Telegram itself (version 29). Make a bot with BotFather, put its token, a secret of your own and this ship's public URL on the Telegram card under Settings, list the chat ids to read and map each Telegram user id to a person on the ship, and press register: the ship tells Telegram to push every message to `POST /apps/orrery/telegram`. Each one runs the pipeline the Python bot ran on a box: the gate and the analyst (through the generator's key and the reader's own small model), validation and grounding as `orrery-utils/common/analyze.py` and `telegram/bot.py` hold them, the status check, and the escalate question that asks the generator for an urgent pass. Facts are signed `telegram` with the message as their source, `telegram/<chat>/<message>`, the same pointers the bot writes, so a backfill from an export and the live reader agree. The commands `/at`, `/status`, `/obs` and `/task` write without the model. The last five free-text messages per chat are kept a day as the next message's context, in the reader's own file and nowhere else; they are the one text the ship holds and no view, key or share sees them. With Telegram Premium a Business connection delivers your own private chats to the same webhook; a connection whose owner is not in `people` is ignored. `max_daily_messages` (500) bounds the model calls. Replies and the `via: telegram` executor come in version 30."

- [ ] **Step 3: The other three files**, then commit.

```bash
git add README.md docs/releasing.md
git commit -m "The reader's routes and settings in the README; releasing says what the owner sets"
cd ../orrery-utils && git add telegram/README.md docs/writing-a-client.md && git commit -m "The bot is the backfill and the dry run; the ship reads Telegram itself as of orrery 29" && git push
```

---

### Task 13: Release

**Files:**
- Modify: `code/version.json` (29)

- [ ] **Step 1: `printf '{"version": 29}\n' > code/version.json`**
- [ ] **Step 2: The full gates on wex**: `python3 scripts/api-matrix.py http://localhost:8080 /tmp/wex.cookies` (every section), `python3 scripts/key-matrix.py` and `python3 scripts/mcp-matrix.py` the way `docs/releasing.md` runs them, `node scripts/page-test.js`, `python3 scripts/code-closure.py code`, `python3 scripts/prompt-drift.py ../orrery-utils/common`, the feb unit suite.
- [ ] **Step 3: Commit and push**

```bash
git add code/version.json
git commit -m "Version 29: the ship reads Telegram through its webhook"
git push
```

- [ ] **Step 4: Pull onto ricsul** (`POST /grubbery/forge/api/run {"repo": "orrery.git_repo", "command": "pull"}` over HTTPS with the owner cookie), confirm `version.json` reads 29 and `GET /api/telegram` answers masked settings.
- [ ] **Step 5: Hand-off to the owner**: on ricsul's Settings, the Telegram card: token, secret, public URL `https://urbit.sneagan.com`, the chats and people from the bot's `config.json`, gate 30, escalate 60, then register. Stop the Python bot's loop (its executor keeps working until version 30 only if it runs; the reading half must not run beside the webhook, since Telegram delivers to one or the other). Text the bot and watch the card's last line.
- [ ] **Step 6: Memory**: update `project/orrery/status` (version 29, what moved, the window file, the lessons) in lattice.

---

## Self-review

- Spec coverage: webhook before identify (Task 9), inbox and fiber (9), settings masked (1), window five a day (2), commands (3), context and prompt (4), shared analyst prompt held by a script (5), validation (6), grounding (7), gate, status check, escalate through the decider (8, 9), filing signed `telegram` with the bot's source ids (9), the urgent pass (9), business connections (9), daily cap (9), registration (10), the card (11), docs (12), release and the owner's hand-off (13). Sending is out of scope, as the spec says.
- Placeholders: Task 9's `post-json` shows its head and says "the rest of ask-model's body" with the one rename; that is a refactor of code already in the file, not a placeholder. Task 6 describes the two remaining validators rule by rule rather than as code because they are the Python's blocks in order; an implementer follows the list against `analyze.py` lines 830 to 916.
- Type consistency: `tg-facts.escalate` is `(unit (list @t))` from Task 9 on; Task 3's literals build it as `~`, which nests. `window-row` has five legs everywhere. `reader-ctx.kinds` is `(list @t)`. `noul-of` and thresholds are hundredths throughout.
