# The Tlon reader on the ship: Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Orrery version 38 reads the owner's Tlon DMs, group DMs and chosen group channels on the ship by polling two "changes since" scries, and runs them through the reader pipeline the Telegram reader already has, writing the same facts under the same rules.

**Architecture:** The Telegram reader's pipeline (`tg-read`, `tg-file`, the window, the cap, the status check, the escalate question) is made source-agnostic by one small record, `reader-kind`, that names the channel word, the signer, the source-id prefix and the file names; Telegram passes its own record and changes nothing else. The chat reader is a new fiber, `chat.sig`, on a timer: it scries `chat` and `channels` for changes since the last pass through `typed-scry` with the `json` mark (gall converts through Tlon's own marks), turns writs and posts into the reader's message rows, and hands each to the shared pipeline. Settings, a card and routes follow the Telegram ones. One new consent road, `/sys/scry/`.

**Tech Stack:** Hoon (grubbery nexus, fiberio `typed-scry`, `send-wait`), the lib's reader section, the page's vanilla JS, the api gate. Tlon's groups desk source is at `<the tlon-apps checkout>/desk` for shapes; the phone client's fixtures at `<the phone client's checkout>/composeApp/src/desktopTest/resources/fixtures/channels/` carry real post JSON.

**Spec:** `docs/superpowers/specs/2026-09-21-tlon-reader-design.md`. Research: `.superpowers/research-tlon-reader.md`.

## Global Constraints

- No em dashes (U+2014) anywhere in either repo. No hard-wrapped markdown. Commit messages one plain sentence, no attribution lines. Comments are complete sentences that say why.
- Never set grubbery or orrery to public. Never touch the live ship. The dev ship (`$SHIP`, `$JAR`) has the groups desk installed with no DMs; the second ship (`$SHIP2`, `$JAR2`, mount `<the second ship's mount>`, its dojo) runs the unit suites. Never boot or kill piers. No ship codes, tokens or cookies in the repo or a report.
- Fast compile: `<scratchpad>/build.sh lib/orrery.hoon` (or `nex/orrery/app.hoon`, `nex/orrery/orrery.js`) prints `build: vase` (`mime` for JS) or the error.
- Unit tests on the second ship: `\cp -f` the lib and `tests/lib/*.hoon` into the mount, then in its dojo: `C-u`, `|commit %grubbery`, wait 12 s, `C-u`, type `-test /=grubbery=/tests/lib/generator ~` (a leading dash needs `--` before it when sent through a multiplexer), confirm the line echoed in the pane before sending `Enter`, then wait for `ok=%.y`; the dojo drops keystrokes right after a commit, so retry the typing when the echo is missing. The runner `<scratchpad>/febtest.sh <suite>` does all of this and prints the result. Counts at the start of this plan: generator 45 (after version 36's tasks, more; read the ledger), orrery 59.
- Gates: `python3 scripts/code-closure.py code`, `python3 scripts/prompt-drift.py ../orrery-utils/common`, `node scripts/page-test.js`, `python3 scripts/api-matrix.py $SHIP $JAR` (about 15 minutes, ends `ALL OK`).
- Facts from Tlon are signed `chat`, source kind `chat`, source id `chat/<whom or nest>/<seal.id>` (The phone client's ids), exactly.
- Message text lives only in the reader's window file, never in a view, a key, a share or another prompt.

---

### Task 1: The reader made source-agnostic

**Files:**
- Modify: `code/lib/orrery.hoon` (reader section: `tg-source` 3121, `tg-window` 3127, `tg-remember` 3138, `reader-prompt` 3266 with its `'Channel: telegram'` line)
- Modify: `code/nex/orrery/app.hoon` (`tg-handle` 2954, `tg-read` 3013, `tg-file` 3120, `tg-final-row` 3140, `tg-record` 3192)
- Test: `tests/lib/generator.hoon` (the existing reader tests keep passing; two new assertions)

**Interfaces:**
- Produces: `+$ reader-kind [channel=@t by=@t prefix=@t recent=@ta last=@ta]` in the lib; `telegram-kind` = `['telegram' 'telegram' 'telegram/' %'telegram-recent.json' %'telegram-last.json']`; `chat-kind` = `['chat' 'chat' 'chat/' %'chat-recent.json' %'chat-last.json']`. `reader-prompt` takes a `kind` and writes `Channel: <channel.kind>`. `tg-source`, `tg-final-row`, `tg-file` take the kind and use `prefix`/`by`. `tg-read` takes the kind. Nothing else about the Telegram reader changes; `telegram.json` and its routes are untouched.

- [ ] **Step 1: Failing tests.** In the generator suite, beside `test-reader-prompt` (or the nearest reader test): `(expect !>((has-sub (reader-prompt:orr rows ctx tz chat-kind:orr) 'Channel: chat')))` and `(expect-eq !>('chat/~sampel-palnet/~sampel-palnet/170.141.184.505.999.000.000.000.000.000.000.000') !>(id:(tg-source:orr m chat-kind:orr)))` for a `tg-msg` whose `chat` is `~sampel-palnet` and `mid` is the dotted id. Existing calls gain `telegram-kind:orr` as the last argument.
- [ ] **Step 2: Run on the second ship, `-find`.**
- [ ] **Step 3: The record and the threading.** Add the type and the two constants at the top of the reader section. Thread `kind` through `reader-prompt` (the `Channel:` line), `tg-source` (`(rap 3 prefix.kind chat.m '/' mid.m ~)`), `tg-final-row` (`['by' s+by.kind]`), `tg-file` (`fill-act-as a now by.kind`), `tg-read`'s prompt call, `tg-handle`'s reads of the window and last files (`recent.kind`, `last.kind`). Telegram's callers pass `telegram-kind:orr`. Do not rename the `tg-` arms; the prefix says where they came from and a rename touches every test.
- [ ] **Step 4: The second ship green (the suite's count plus 2), build app vase, api gate ALL OK (the Telegram section proves nothing moved). Commit** `The reader takes its channel, signer and files from a record, so a second source can share it`.

---

### Task 2: The chat settings, their routes and the record

**Files:**
- Modify: `code/lib/orrery.hoon` (a `chat` section after the telegram section: `+$ chat-config`, `de-chat-config`, `en-chat-config`), `code/nex/orrery/app.hoon` (falls for `chat.json` `[%o ~]`, `chat-last.json`, `chat-seen.json` `[%a ~]`, `chat-recent.json`; `GET`/`PUT /api/chat` owner or a key with `write`, mirrored on `serve-telegram`/`serve-set-telegram` with no masking since there is no secret; `do-set-chat` beside `do-set-telegram`; `POST /api/chat/wake`; `GET /api/chat/last`)
- Test: `tests/lib/generator.hoon`

**Interfaces:**
- Produces: `+$ chat-config [enabled=? dms=(set @t) channels=(set @t) people=(map @t @t) read-own=? poll=@ud backfill=@ud gate=@ud escalate=@ud max-daily=@ud model=@t]`; `de-chat-config |=(json chat-config)` with defaults `poll_minutes` 5, `backfill_hours` 24, `gate` 30, `escalate` 60, `max_daily_messages` 500, `model` `deepseek/deepseek-v4-flash`, `read_own` false; `en-chat-config`. `PUT /api/chat` merges the given keys over the stored ones (a missing key keeps its value; `dms`, `channels` and `people` replace whole when given). The record `chat-last.json`: `since` (ISO), `at`, `read`, `filed`, `strangers`, `dropped`, `read_today`, `day`, `notes`, `down` (the Telegram record's shape, plus `since`).

- [ ] **Step 1: Failing tests** for `de-chat-config` (defaults, a full object, `people` keys normalised to lower case with a leading `~`, `dms` and `channels` trimmed) and the `en` round trip.
- [ ] **Step 2: The second ship `-find`.**
- [ ] **Step 3: The lib arms and the app routes.** Copy the Telegram ones; the key path: a key whose scope has `write` may `PUT /api/chat` (rule: The phone client sets the lists), read is owner-only or that same key. The wake route pokes `chat.sig` with `[[/ %sig] ~]` (the fiber comes in Task 5; the route compiles against the fall now).
- [ ] **Step 4: Gate section** `the chat reader's settings`: `PUT` with two dms, one channel, one person; `GET` returns them; a second `PUT` with `poll_minutes` only keeps the lists; a read-only key gets 403; `GET /api/chat/last` answers `{}` before any pass. **The second ship green, build, api gate. Commit** `The chat reader's settings, routes and record`.

---

### Task 3: Tlon's JSON into message rows

**Files:**
- Modify: `code/lib/orrery.hoon` (the chat section)
- Test: `tests/lib/generator.hoon`, fixtures inline from the phone client's `post-with-reply-and-reacts.json` (read it; copy the parts you need into a `jo` cord) and a hand-written `changes` answer for chat.

**Interfaces:**
- Produces: `story-text |=(story=json @t)` (walk verses; strings appended; `{break}` is a newline; `{ship: "~p"}` is `~p`; `{bold|italics|strike|blockquote: [...]}` recurse; `{link: {content}}` its content; `{"inline-code"|code|tag: t}` t; a `{block}` verse is skipped); `chat-rows |=([changes=json cfg=chat-config since=@da] (list tg-msg))` for the chat agent's `changes` answer (a map from `whom` to `writs` or null): for each `whom` in `dms.cfg` (or every whom when `dms` is empty? No: the owner picks; an empty list reads nothing), each writ that is not a tombstone (`seal` present, `essay` present), `essay.sent` (ms) after `since`, author (`essay.author` a string, or its `ship` field when an object) not the owner's ship unless `read-own`, gives `tg-msg` `[chat=whom from=author text=(story-text content) at=(da-of-ms sent) mid=seal.id business='']`; replies inside `seal.replies` the same with their own ids; `channel-rows |=([changes=json cfg=chat-config since=@da] (list tg-msg))` the same over the channels agent's answer (a map from nest to posts or null; `chat=nest`); both sorted by `at` ascending; `mid` is the id string as Tlon writes it (`~author/170.141...` for a writ, the dotted `@ud` for a post).

- [ ] **Step 1: Failing tests:** `story-text` on `[{"inline": ["hi ", {"bold": ["there"]}, {"break": null}, {"ship": "~sampel-palnet"}]}]` is `'hi there\0a~sampel-palnet'`; `chat-rows` on a two-whom changes answer where one whom is not in `dms` (dropped), one writ is a tombstone (dropped), one is older than `since` (dropped), one is the owner's own (dropped unless `read-own`), and two remain in time order with the right `mid`s and text; `channel-rows` on the phone client's fixture's post shape inside a `changes` map keyed by `chat/~host/name`, the reply included as its own row.
- [ ] **Step 2: The second ship `-find`.**
- [ ] **Step 3: The arms.** Read `<the tlon-apps checkout>/desk/lib/chat-json.hoon` (writs bag: an object keyed by dotted time, each `{seal, essay}`), `channel-json.hoon` (posts bag keyed by id: `{seal, essay, type}` or null for a tombstone; `essay.sent` ms; `essay.author` string or `{ship, nickname, avatar}`), `story-json.hoon` (verses and inlines) for the exact keys, and cite the lines in comments.
- [ ] **Step 4: The second ship green. Commit** `Tlon's writs and posts become the reader's message rows`.

---

### Task 4: The scries and the consent road

**Files:**
- Modify: `code/nex/orrery/app.hoon` (`weir-json` gains `(line '/sys/scry/' 'read your Tlon messages, the DMs and the group channels you pick, so what people tell you on Urbit becomes facts the ship knows. Refuse this and the ship reads no chat')` in the poke list; a `chat-scry` arm beside `find-base`)
- Modify: `scripts/api-matrix.py` (the ask section checks the new road)
- Test: by hand on the dev ship (consent must be granted there by hand first: the approve-weir call in `.superpowers/sdd/2026-09-21-executors-on-ship/task-2-report.md` section "Consent on the dev ship", plus the new road; record the exact call in the report)

**Interfaces:**
- Produces: `groups-live |=(~ (fiber ,?))`: `(typed-scry:io ? %loob /gu/chat/$)` and the same for `channels`, both true; `chat-changes |=(since=@da (fiber ,(unit json)))`: `(typed-scry:io json %json /gx/chat/v4/changes/(scot %da since)/json)`; `channel-changes |=(since=@da (fiber ,(unit json)))` with `/gx/channels/v6/changes/(scot %da since)/json`; each answers `~` when the `/sys/scry/` road is vetoed (catch the veto the way `font-soft` in the executor section catches one) and notes it once in the record.

- [ ] **Step 1: The road and the gate check** (`the ask names /sys/scry/`).
- [ ] **Step 2: The arms.** `typed-scry` is `|*  [=mold mark=@tas =path]` in fiberio 932; lattice's calls are the model (`<the lattice checkout>/code/nex/lattice/app.hoon` around 2785 to 2799: `%gu` first, then `%gx ... /json`). A `%gx` on an absent agent crashes the fiber, so `groups-live` runs first and a false answer skips the pass with the note `groups desk not installed`.
- [ ] **Step 3: Hand probe on the dev ship** through a temporary `GET /api/chat/probe` route? No: write the arms and prove them from the fiber in Task 5; here prove the road only: after the grant, a `typed-scry` from the reconcile fiber is not available either. Ruling: this task builds and commits the arms and the road; Task 5's fiber proves them (its first pass on the dev ship must record `since` moving and no note, with both scries answering empty maps). Build app vase, api gate. **Commit** `The scry road, and the chat and channels scries`.

---

### Task 5: The fiber

**Files:**
- Modify: `code/nex/orrery/app.hoon` (the fiber list: `chat.sig` after `exec.sig`; `chat-pass`, `chat-handle`, `chat-record`)

**Interfaces:**
- Consumes: Task 1's `chat-kind` and the shared `tg-read`/`tg-file`/window; Task 2's config and record; Task 3's rows; Task 4's scries.
- Produces: `chat.sig`:

```hoon
          ::  the chat reader (version 38): every poll_minutes, the writs
          ::  and posts changed since the last pass, read through Tlon's
          ::  own JSON, each through the reader's pipeline. Nothing pokes
          ::  it but the owner's wake; a wake runs a pass at once.
          [~ %'chat.sig']
        ;<  ~  bind:m  (rise-wait:io prod "%orrery chat: failed")
        |-
        ;<  ~  bind:m  chat-pass
        ;<  cfg=chat-config:orr  bind:m  (read-chat-config 0)
        ;<  now=@da  bind:m  get-time:io
        ;<  *  bind:m  (take-poke-or-timer /chat (add now (mul (max 1 poll.cfg) ~m1)))
        $
```

`take-poke-or-timer` is a taker that ends on the wake poke or the timer (`set-timer` on a stable wire and a taker like `take-exec-in` that accepts a wake or a poke; read `send-wait` in fiberio 1433 and `take-exec-in` in the executor section).

`chat-pass`: read the config; if not enabled, return; `groups-live`, else note and return; `since` from the record (first run: `now - backfill_hours`); the two scries; `rows = (weld (chat-rows ...) (channel-rows ...))` sorted by `at`; drop each whose `mid` is in `chat-seen.json` (a JSON array of the last 5,000 ids; append as you go); for each row: the sender through `people` merged with the ship attribute map (`people-of-ships |=(all (map @t @t))`: every person body's `ship` attribute lower-cased to its id; the owner's own ship to `person/me`), a stranger is counted and skipped; the cap as `tg-handle` does; then `(tg-read cfg' msg who now chat-kind)` where `cfg'` is a `tg-config` view of the chat config (gate, escalate, model, max-daily: write `tg-config-of-chat`) and `tg-file`, the window update; on `down` (the model out), stop the pass without moving `since` and set `down` in the record with a retry in five minutes (the Telegram reader's `tg-record-down` is the model); at the end `since` becomes the pass's `now` and the record is written.

- [ ] **Step 1: Build, reload the dev ship, probe:** with the reader enabled on the dev ship and consent granted, `POST /api/chat/wake`, then `GET /api/chat/last`: `since` and `at` set, `read` 0, `notes` empty (the scries answered empty maps). Disable the reader: a wake moves nothing. Withdraw the `/sys/scry/` road (approve-weir without it, reload), wake: `notes` carries the veto and the fiber stays alive (a second wake answers ok); regrant.
- [ ] **Step 2: A read on the dev ship** if any Tlon message can be produced there (a DM to the dev ship from the second ship through the groups app if both are on the same network; if not, say so and leave the live proof to the live ship at release).
- [ ] **Step 3: Api gate** (a section `the chat reader`: enable, wake, read the record's shape; disable). **Commit** `The chat reader: Tlon's DMs and channels read on the ship every few minutes`.

---

### Task 6: The card, the docs, release prep

**Files:**
- Modify: `code/nex/orrery/orrery.js`, `orrery.css`, `scripts/page-test.js` (a Chat card beside the Telegram card: on/off, poll minutes, backfill hours, gate, escalate, cap, model, `read_own`; the DM list as checkboxes from `GET /api/chat/dms` (a small route that scries `/gx/chat/dm/json` and answers the list; add it in this task to app.hoon) and the channel list from `GET /api/chat/channels` (`/gx/channels/v5/channels/json`? read `<the tlon-apps checkout>/desk/app/channels.hoon` around line 227 for the scry that lists channels with their titles, or the groups scry `/gx/groups/groups/light/json` with its channels; pick the one that gives nest and title, cite it); the people map as rows; the last pass; a wake button)
- Modify: `README.md`, `docs/releasing.md` (version 38 owner steps: approve `/sys/scry/` on the permits page, reload; on the Chat card pick DMs and channels, map people, enable; then tell the phone client to stop reading chats), `orrery-utils/docs/writing-a-client.md` (rule 1's "never triage twice": the ship's chat reader uses the phone client's source ids, so a client that still reads chats must stop; a line in rule 14's reader half), `orrery-utils/telegram/README.md` (a pointer), `code/version.json` 38.
- [ ] **Step 1: The two list routes and the card, four page tests** (renders off, renders the lists with checked boxes for the chosen ones, the people rows, the last line).
- [ ] **Step 2: Docs.**
- [ ] **Step 3: Every gate** (closure, tools.hoon cmp, drift, page-test, api, key, mcp, smoke, share, both suites on the second ship). **Commit** orrery `Version 37: the ship reads Tlon DMs and group channels`; utils `Rule 1 and rule 14 for a ship that reads its own chats`. The push, the live ship's pull, the permits approval, the card setup and the phone client's note are the controller's and the owner's.

## Self-review

- Spec coverage: polling with the two changes scries and `%gu` (T4, T5); the pipeline shared with Telegram (T1, T5); settings, routes, card, wake (T2, T6); the people map merged with ship attributes (T5); source ids (T1's constant); the window and cap (T5 through the shared arms); the consent road (T4); the record (T2, T5); backfill on first run (T5); the 1 MB answer rule is not in a task: Ruling for T5: read the answer's ids and skip text when the scry's JSON is over 1 MB, noting it, as the spec says; the implementer carries it.
- Placeholders: T4 Step 3 records a ruling instead of a probe (the fiber proves the scries); T6's channel-list scry names two candidates and asks for the one that yields nest and title, with a citation.
- Types: `reader-kind`, `chat-config`, `tg-msg` reused for chat rows (`business` left `''`), `chat-rows`/`channel-rows` signatures consistent across T3 and T5.
