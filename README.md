# orrery

Orrery is a model of one person's world, kept on their own Urbit ship. It holds the bodies around them (people, places, things, orgs, situations, activities), a dated and sourced observation for every fact learned about each one, folded into what is currently true now or at any past time, the situations and activities each body is part of, and the actions an assistant proposes: held under a policy that approves the routine ones and waits for a tap on the rest, with a claim step so two executors never act twice, and a history on every action that says who proposed, approved and carried it out. The writer keeps an audit trail of every write. A body can be shared with another ship, a client that runs no ship gets a scoped key, an analyst on the ship's MCP server gets tools, and the owner gets a page.

The ship stores the facts and their history. Models do the thinking, and none runs on the ship: a small one turns messages, mail and calendar events into facts, on a phone or laptop client or through the ship's own readers, and a larger one reads the picture back and proposes actions. You approve them, or let a policy approve the routine ones for you.

The name is the instrument: a mechanical model of bodies in motion, read to know where everything is now and where it was.

## A day with orrery

At 10pm you text Sarah: "car died on route 9, stranded waiting for a tow". Your triager reads that message and records a few facts on the ship: you are stranded and waiting for a tow, you are on Route 9, the Subaru is broken down on Route 9, and there is a new situation, the breakdown, with you, Sarah and the car as its participants.

At 11:40pm: "tow guy is here, taking it to john's machine shop". The triager looks the shop up, finds nothing, creates it, and records that the car is being towed there and that you are riding along.

At 2:10am: "home. left the car at john's overnight, they'll look at it in the morning". Now the car is at the shop awaiting diagnosis, you are home, and your status is cleared. Not stranded, not anything.

In the morning your assistant reads the state: an open situation, a car at a shop, and nothing being done about it. It proposes a task, "Call the shop about the Subaru", due at 9am. Your policy says tasks are approved the moment they are proposed, so it lands on your todo list with no question asked. A proposed text message to Sarah would wait for your approval instead.

Ask the ship what was true at 11pm and it still puts the car on Route 9. Ask it why it thinks the car is at the shop and it points at the 2:10am message. None of the messages themselves were stored, only the facts, each with a pointer back to where it came from.

## Try it

Everything below talks to the HTTP API with the ship's owner cookie. Log in once and keep the cookie jar.

```bash
SHIP=https://your-ship.example      # your ship's web address
curl -s -c jar -X POST -d "password=$CODE" $SHIP/~/login    # $CODE is what +code prints in the dojo
API=$SHIP/apps/orrery/api
post() { curl -s -b jar -H 'content-type: application/json' -X POST "$API/$1" -d "$2"; echo; }
```

### Record a fact

A fact is an observation: one claim about one body, with where it came from. This one creates Sarah and says where she is.

```bash
post observe '{
  "bodies": [{"id": "person/sarah", "name": "Sarah", "aliases": ["wife"]}],
  "observations": [
    {"subject": "person/sarah", "attr": "location", "value": "Lisbon",
     "source": {"kind": "user", "id": "readme"}}
  ]
}'
```

The answer has one line per item, so a client can fix the one it got wrong.

```json
{"bodies": [{"id": "person/sarah", "ok": true, "existing": false}],
 "observations": [{"id": "1758110400-3b9ac1f0", "ok": true, "existing": false}]}
```

### Read it back

```bash
curl -s -b jar $API/body/person/sarah          # one body: attributes, situations, actions, timeline
curl -s -b jar "$API/resolve?q=wife"           # find bodies by identity, name or alias
curl -s -b jar $API/state                      # everything at once: the view an assistant reads
```

The body view shows the current attributes and, below them, every observation ever made about her, newest first, each labelled live, future, superseded, expired or retracted.

```json
{"id": "person/sarah", "kind": "person", "name": "Sarah", "aliases": ["wife"], "created": "2026-09-17T12:00:00Z", "ship": null,
 "attrs": {"location": {"value": "Lisbon", "at": "2026-09-17T12:00:00Z", "until": null, "conf": 100,
                        "source": {"kind": "user", "id": "readme"}, "by": "user", "obs": "1758110400-3b9ac1f0"}},
 "involved": [], "actions": [],
 "observations": [{"id": "1758110400-3b9ac1f0", "attr": "location", "value": "Lisbon", "status": "live", "...": "..."}]}
```

### Facts change

Record a newer location and it wins. The old one stays in the timeline as superseded, and the question "what was true then" is a query, not a guess.

```bash
post observe '{"observations": [
  {"subject": "person/sarah", "attr": "location", "value": "Porto",
   "at": "2026-10-01T09:00:00Z", "source": {"kind": "user", "id": "readme-2"}}]}'
curl -s -b jar $API/body/person/sarah                                  # Porto
curl -s -b jar "$API/body/person/sarah?at=2026-09-20T00:00:00Z"        # Lisbon
```

The rule is that the fact with the latest `at` wins, not the one that arrived last. A tow receipt that arrives at 11pm saying the car was picked up at 7:30pm cannot overwrite the 9pm fact that it is at the shop.

Three more ways a fact changes:

- `"until": "2026-09-17T02:00:00Z"` says when the fact is expected to stop being true. After that it is expired and no longer counts.
- `"value": null` clears an attribute. "No longer stranded" without pretending to know the new state.
- A wrong fact is retracted, never edited: `post retract '{"id": "1758110400-3b9ac1f0", "note": "wrong Sarah"}'`. It stays in the timeline, labelled retracted.

Sending the same observation twice is a no-op. The id is a hash of the claim and its source, so the answer says `existing: true` and nothing is written.

### Relations

A value can point at another body. Nothing follows these pointers for you; they are values a reader can look up.

```bash
post observe '{
  "bodies": [{"id": "place/home", "name": "Home"}],
  "observations": [
    {"subject": "person/me", "attr": "spouse", "value": {"ref": "person/sarah"}, "source": {"kind": "user", "id": "readme"}},
    {"subject": "person/me", "attr": "home",   "value": {"ref": "place/home"},   "source": {"kind": "user", "id": "readme"}}
  ]
}'
```

`person/me` is you. It is made on the first request, with your ship's name on it, and you or a client rename it.

### Situations

A situation is a body like any other, of kind `situation`, whose `participants` name the bodies involved. While it is open, every participant's view lists it under `involved`, so Sarah's page shows the breakdown without anyone writing a fact about Sarah.

```bash
post observe '{
  "bodies": [{"id": "situation/2026-09-16-breakdown", "name": "The breakdown"}],
  "observations": [
    {"subject": "situation/2026-09-16-breakdown", "attr": "status",       "value": "open",                   "source": {"kind": "phone-dm", "id": "msg-1"}},
    {"subject": "situation/2026-09-16-breakdown", "attr": "participants", "value": {"ref": "person/me"},    "source": {"kind": "phone-dm", "id": "msg-1"}},
    {"subject": "situation/2026-09-16-breakdown", "attr": "participants", "value": {"ref": "person/sarah"}, "source": {"kind": "phone-dm", "id": "msg-1"}},
    {"subject": "situation/2026-09-16-breakdown", "attr": "location",     "value": "Route 9",                "source": {"kind": "phone-dm", "id": "msg-1"}}
  ]
}'
```

`participants` is multi-valued: each observation adds a value instead of replacing the last one. The schema says which attributes work that way. A situation's schedule is `starts` and `ends`; `started` and `ended` are written once it has happened; its `status` is only ever `open`, `closed` or `cancelled`, and the page reads upcoming, under way or over off the times. Set `status` to `closed` when it is over and it leaves everyone's `involved` list.

A situation happens once. Something that keeps happening is an `activity`: the weekly game night, the standing Tuesday call, the gym. It carries a `schedule` and a `cadence` alongside the `participants`, so a repeating event is one body with a `next`, not one situation per occurrence.

Two bodies that turn out to be the same person are folded with `POST /api/merge`, `{"from": "org/sarah-connor", "into": "person/sarah"}`: every observation moves onto `into` keeping its own time and source, every reference to `from` is repointed at `into` and the old one retracted, the aliases union, and `from` is deleted. `person/me` can be merged into but never away.

### Actions

An action is something to do. An assistant proposes it, and it moves through proposed, approved, claimed, done, dismissed or failed.

```bash
post act '{"kind": "task", "title": "Ask Sarah about the move to Porto",
           "about": ["person/sarah"], "due": "2026-10-02T13:00:00Z"}'
```

```json
{"id": "1758110400-9c2e41aa", "status": "approved", "existing": false}
```

It is `approved` at once because the starter policy auto-approves tasks and notes. A `message` or a `calendar` action answers `proposed` and waits for you. Proposing the same kind and title again answers the existing id instead of making a second one.

```bash
curl -s -b jar "$API/actions?status=open"                  # proposed, approved and claimed, the todo list
post actions/1758110400-9c2e41aa '{"status": "done"}'      # or dismissed, or failed with a note
```

An executor (the ship itself for `telegram`, `mail`, `calendar` and `task` since version 34; a phone client for `chat`) claims an approved action before it acts, with `{"status": "claimed", "by": "telegram"}`, and the claim holds it for ten minutes.

A second executor's claim inside that lease is refused with `claimed by telegram`, only the claimant reports done or failed, and you unstick a claimed action by dismissing it.

The answer to a move carries the `by` the ship will store, and it comes back before the writer has applied the move, so an executor confirms its claim by reading the action back and acts only when the last claimed step names it.

Two claims fired in the same instant both answer ok; the writer keeps the first, and the second executor learns it lost when it reads the action back.

Every action carries its history: who proposed it, who approved it (you, or `policy`), who claimed it, and when. The audit question is answered by the action itself.

#### The generator

The ship proposes on its own. With the generator on (the Generator card under Settings), every change to the state wakes a pass: the ship builds the prompt from what it holds, asks the model you named through `/sys/iris/`, keeps what the schema allows and files it as proposals signed `generator`. A pass is skipped while the prompt would be the one sent last, so a quiet day costs nothing; `POST /generate` runs one regardless.

Dismissing on the page asks for a reason and will not go without one ("just the event", "I always do this"). The reason rides into the next prompt with the decision, where the model generalises from it; that is how the generator learns your taste without a rulebook.

The card also shows the model calls made today and the month's spend, summed from the cost figure each answer carries. The key never leaves the ship and is never read back.

A reader that judges a message needs help within the hour (the client guide's rule 16) asks for an urgent pass with `POST /generate {"about": [...]}`: it runs at once, past the cooldown, with those situations put first under a line saying the owner may need help now, at most `max_urgent` times a day (five unless set).

`docs/spikes/2026-09-19-iris-probe.md` is why the ship can wait for a slow model, and `orrery-utils/generator` remains the bench and the dry-run harness.

#### The Telegram reader

The ship reads Telegram itself (version 29). Make a bot with BotFather, put its token, a secret of your own and this ship's public URL on the Telegram card under Settings, list the chat ids to read and map each Telegram user id to a person on the ship, and press register: the ship tells Telegram to push every message to `POST /apps/orrery/telegram`, one connection at a time, since updates are handled in id order.

Each one runs the pipeline the Python bot ran on a box. First the gate and the analyst, both called through the generator's OpenRouter key, so the Generator card's key must be set for the reader to read: the gate is `typesafe/jev-1.13`, reached through the generator's own url; the analyst is the reader's own small model, `model` in its settings.

Then validation and grounding as `orrery-utils/common/analyze.py` and `telegram/bot.py` hold them, the status check, and, at or above `escalate`, a question that asks the generator for an urgent pass over the situations just written (the client guide's rule 16, which the ship's own reader now follows too).

The reader's settings fall back on their own: `model` is `deepseek/deepseek-v4-flash` unless set, answering in `max_tokens` (4000) at most; `gate` and `escalate` are hundredths, 30 and 60 unless set; `api_url` is `https://api.telegram.org` unless set.

Facts are signed `telegram`, their source `{"kind": "chat", "id": "telegram/<chat>/<message>"}`, the same pointers the bot writes, so a backfill from an export and the live reader agree.

A chat's new messages are read together, as one run: everything that arrived in one drain (or, for the chat reader, one pass) for the same chat goes to the analyst in one call, oldest first, so a message further down that settles an earlier one is seen before anything is proposed from the earlier one alone (version 46). The run's facts are filed in one write, so the generator's next pass sees the settled state rather than the state between two messages.

The last five free-text messages per chat are kept a day as the next message's context, in the reader's own file and nowhere else, a chat's window dropped once it leaves the settings. They are the one message text the ship holds, and no view, key or share sees them.

With Telegram Premium a Business connection delivers your own private chats to the same webhook; a connection whose owner is not in `people` is ignored. `max_daily_messages` (500) bounds the messages the analyst is asked about, not questions. Changing the token on the card starts the update ids over, so it also resets the reader's last-handled one.

An update the analyst could not read (unreachable, a timeout, 401 to 404, 408, 429 or a 5xx) stays in the inbox and is read again five minutes later. `POST /api/telegram/wake` reads it now, and is the remedy when the card's last update stops moving, since it also restarts a reader that crashed.

The reader sends nothing: the `via: telegram` executor is the ship's own, below.

#### The chat reader

The ship reads your Tlon DMs, group DMs and the group channels you pick (version 39). Turn it on on the Chat card under Settings, list the conversations (a DM is its `whom`, `~ship` or `0v...`; a channel its nest, `chat/~host/name`; the card offers what the ship holds), and map any sender the ship does not know to a person; a person body that carries a ship needs no row. Every `poll_minutes` (5) the reader asks the groups desk for what changed since its last pass, through the ship's own scry service (the `/sys/scry/` road, approved on the permits page), and reads the new writs and posts through the pipeline the Telegram reader uses, one run per conversation with the same gate, analyst, checks and window, the analyst told `Channel: chat`. The first pass looks back `backfill_hours` (24). Your own words are skipped unless `read_own` is set. A sender in no map is a stranger and is counted, not read.

Facts are signed `chat`, their source `{"kind": "chat", "id": "chat/<whom or nest>/<message id>"}`, the ids the phone client's reader used, so a client that still reads chats must stop or the same message is triaged twice. `GET` and `PUT /api/chat` take the owner or a key with `write`, so a client can set the lists. `GET /api/chat/last` is the record: `since` is where the next pass starts, and it moves only when every message of a pass was read, so a model outage leaves the rest for the next tick, said under `down`; `POST /api/chat/wake` runs a pass now. Without the groups desk, or with the road refused, the record says so and nothing is read.

#### The executor

The ship carries out its own approved actions (version 34). An executor fiber keeps the beacon and, on every change, takes each approved action it can serve.

- A `message` whose `via` is `telegram` goes as one `sendMessage` through the reader's token to the chat id in the person's `telegram` attribute, or, when there is none, to the Telegram user id the reader's `people` map gives that person.
- A `message` via `mail` goes through auspex, which is mail between ships, so `to` is a person whose `ship` attribute names their ship; the action's title is the subject and the payload's text the body.
- A `calendar` action becomes an event on the calendar, timed from `starts` to `ends` (an hour when `ends` is absent) or all-day when both are whole days, in the owner's `timezone` from `person/me`, carrying the action id as `meta.orrery` and the tag `orrery`.
- A `calendar` action whose payload says `mode: cancel` takes an event off the calendar instead: the event is `event`, the calendar's own id, and one that repeats is skipped for the occurrence `starts` names rather than deleted.
- A `task` becomes a todo in the calendar's list with its notes and its due, marked the same way.

A message to a person with a `ship` attribute is always filed `via` `chat` instead, whatever channel it was proposed on, since Telegram is only for a person with none and mail stays for a person with a ship only when they have no chat, which today never happens; the trail notes the rewrite. A note at approval (below) can still choose the channel by hand, "send this as mail" or "over telegram", since that rewrite runs only when an action is first filed, never on a revision.

Messages and calendar actions follow the claim protocol: claimed `by` `ship`, then `done` with `sent to <chat>`, `sent by mail to <ship>`, `on the calendar`, `off the calendar` or `that occurrence skipped`, or `failed` with the reason (Telegram's own description, auspex's refusal, or, for a cancel, `the calendar does not have that event` or `that event repeats, so the occurrence is needed`).

As the last step before a message leaves the ship, whether by `sendMessage` or the auspex poke, an em dash (U+2014) in its text is swapped for a comma, with one space after and none before, so none leaves the ship whatever a model wrote.

The schema's note for `message.text` and the shared prompts carry the same rules word for word: no em dashes, no semicolons or colons joining independent clauses, simple direct sentences of varied length, a sentence with more than one parenthetical thought split in two.

A message with no address (no `telegram` attribute and not in `people`, no `ship` attribute), or a Telegram one while the reader has no bot token, is not claimed: it stays approved and is named in the record's `notes` on every pass until it is dismissed or the address is added. An action a client left `claimed` past its lease is not taken by the ship either; the owner dismisses it.

A task is placed without a claim and stays `approved` until it is done, and the mirror runs both ways:

- Ticked in the calendar, its action goes `done` by `calendar` with `ticked in the calendar`.
- Marked done on the page, its todo is ticked.
- Dismissed or failed on the page, its todo is deleted.
- A todo you type into the calendar by hand becomes an approved task filed `by` `calendar` and gains the mark in the same pass, so it is adopted once.

The mirror runs on the calendar's own changes, so a tick reaches the ship within seconds. A message via `chat` is the companion client's, whose store the DM lives in, and is never touched.

Two things to know: a todo the ship placed and you delete in the calendar is placed again on the next pass, since the ship is the source of truth for what it made, so dismiss the action on the page instead; and a task adopted from a hand-typed todo that you then delete stays approved on the ship until you dismiss it on the page.

The desks are found through `/sys/link/`, a peek road the ship had already, and three lines need your consent once on `/apps/grubbery/permits`:

- a poke of the calendar instance (its writer),
- a peek of it (its store, kept for the mirror),
- a poke of auspex's writer.

A desk that is not installed, or a road refused, leaves those actions approved for another executor and is named on the Executor card under Settings, which shows what the last pass did, the failures with their notes, and wakes the executor.

A companion client's own task mirror and its senders must be off once this runs: two mirrors over one todo list place and tick twice, and two senders send twice.

#### A note at approval

A proposed action on the page carries a box under it for a note (version 36): "include dana in this", "make it 3pm", "send this as mail". `POST /actions/<id>/refine` runs one model call and rewrites the action's title, payload, `about` and `due` in place, keeping its id and history and appending one step `revised` by whoever asked.

A name the note gives that the ship does not have becomes a new person with no attributes, the way a reader creates one from a message; the owner does not add every person they meet by hand.

Anything the note asks for beyond the action itself, such as a todo the day before, comes back as an `extra`, a second action carrying `refined_from` and the original's `about`, filed as any proposal is: under the policy's `auto` list a task lands approved, anything else waits for its tap.

A note the ship cannot carry out, such as switching a light, changes nothing and answers why in `note`.

The action stays `proposed` until approved as before, and only a proposed action can be refined: approve first, and a done action is history. One refinement runs at a time per action; a second while the first is still running answers 409.

#### Reconcile

The ship also reconciles on its own. Twice a day, and on `POST /reconcile`, it runs the passes that used to be `orrery-utils/common/reconcile.py`, in order:

1. A future `started` or `ended` becomes `starts` or `ends` (the schedule, dated when it was learned), and a situation status that is not open, closed or cancelled is retracted.
2. Situations that are occurrences of one repeating event (three or more with the same calendar uid or the same title) become one activity with an observation per occurrence, and the occurrences are deleted.
3. People are read out of titles ("Mira- Ballet/Tap", "Felix Birthday") and made participants, created when the ship lacks them.
4. Bodies that name one person (an org made from a person's name, two persons whose names or addresses match) become merge proposals, actions of kind `merge` for the inbox, and the ones you approve are run.
5. Then what is over closes: a situation whose end has passed closes at that end, a trip with no end a week after it started, a scheduled situation with a `starts` but no end six hours after it starts, a situation with a start but no end that started more than thirty days ago with nothing seen since closes at its newest observation. Times are read as the readers write them, a bare date included.
6. A thing whose delivery stage has stood too long is presumed delivered (`out for delivery` three days on, `shipped` or `in transit` a fortnight on): a `status` of `delivered` at the end of the grace, conf 60, signed `retire`, so a carrier's own word later supersedes it.
7. When `reconcile.prune_days` in the policy is set, closed situations older than that are deleted.

Every change is an ordinary observation, retraction or deletion signed `reconcile` (`retire` for the closes), filed through the writer.

The settings live under `reconcile` in `policy.json`: `min_occurrences` (3), `stale_days` (30) and `prune_days` (0, off). The Settings page shows what the last run did and runs one now. Version 25 moved retire on-ship, version 26 the rest, version 35 added the scheduled and the delivery rules.

### The calendar's events

Since version 47 the executor also reads the calendar's events into facts, the way a phone client's calendar pipe did, so that pipe can be switched off. A one-off event becomes a situation, `situation/<date>-<slug>` with the calendar's uid as an alias, carrying `starts` and `ends` while it is ahead (dated when the ship learned of it) and `started` and `ended` once it is behind (dated at the event), the participants (`person/me` and whoever the title or the note names, a person the title is sure of made when the ship lacks them) and the location. A repeating event becomes an activity, `activity/<slug>`, with `cadence` (the rule's kind), `schedule` (the kind and the first tag), participants, `organizer` and location, each occurrence behind as a `last` and the next ahead as a `next` anchored at the end of the one before it, until its own end. A one-off the calendar no longer holds whose start is still ahead is marked `status: cancelled`, once. Todos and the events the ship itself placed (`meta.orrery`, the `orrery` tag) are not read; a rule the ship does not know (anything but `once`, `daily`, `weekly`, `monthly`, `yearly`, `every`) is named in the record's `unknown`. Every row's source is `calendar` with the uid, and what was written is remembered in `calendar-seen.json` so each occurrence is said once. The pass runs whenever the store changes and at least hourly, on the executor's own calendar read; its record is `GET /calendar/last`.

### Where facts come from

Every observation names its `source`, a kind and an opaque id such as the message it was read from, and its `by`, who asserted it. The text is never stored. Confidence (`conf`, 0 to 100) says how sure the asserter was.

The writer keeps a trail of its last 500 outcomes: the op, whether it applied, why not, when, and who asked. It is read through the ball browser at `GET /grubbery/ball/apps/shell.shell/desks/orrery.desk/desk/data/orrery.orrery_app/tr/log?raw=1`, with the last outcome alone at `tr/last`.

### The page

`/apps/orrery` on your ship, owner only: bodies grouped by kind with situations that are over folded under a past heading, one body with its attribute table, its situations, its open actions and its timeline with a retract button, the actions inbox with approve, dismiss, done and failed, keys with each key's scope, when it was made and last used, a revoke per key and a form that mints one and shows its token once, and settings with a Generator card (the model, the key written once and never shown, a run-now button and the last pass), a Reconcile card, an Executor card (what the last pass did, the failures with their notes, the desks it could not find, what the calendar's events gave, and a wake button) and a Telegram card above the schema and the policy as editable JSON. It refreshes itself whenever the ship's state changes.

### The vocabulary

`GET` and `PUT /schema` hold the vocabulary the models are advised to use: the kinds, the attributes each kind commonly has, notes saying what an attribute means where the name alone misleads, the action kinds with the payload shape each takes (`payloads`: a message's `via` is one of the channels listed there, `to` a body id; a calendar event's `starts`), and the one thing the ship enforces, which attributes are multi-valued. Unknown kinds and attributes are accepted; adding a new kind of fact never changes a type.

Two notes are worth reading before a client writes a cancellation. An activity's `status` is the series, `active` until it folds and `cancelled` when it has, while `skipped` is multi-valued and holds the start of one occurrence that is off, so one practice called off never cancels the class. A `calendar` payload's `mode` is `add`, the default and everything before version 37, or `cancel`, which takes `event`, the calendar's own id for the event to remove, and `starts` when it repeats.

`GET` and `PUT /policy` hold the rules: `auto`, the action kinds approved on proposal; `push`, when to send a notification (`proposed`, `all` or `none`); `retention_days`, how long superseded, expired and retracted rows are kept; and `sensitive`, the attribute names a client key never sees, `health` and `income` from the start.

## Sharing a body with another ship

Sarah runs her own ship. Share her body with her and her ship mirrors what you know about her. In edit mode, what she records about herself comes back to yours.

```bash
post observe '{"bodies": [{"id": "person/sarah", "ship": "~sampel-palnet"}]}'
post share '{"id": "person/sarah", "ship": "~sampel-palnet", "mode": "edit"}'
```

On her ship (point `API` and the cookie jar at it first), `GET /api/shares` lists the offer and `post accept '{"host": "~your-ship", "id": "person/sarah"}'` takes it. Because the body carries her ship's name it lands on her own `person/me`. Her ship reads the body every five minutes and on demand (`POST /api/sync`), and every mirrored fact names its origin: `by` is your ship, and `source` is `{"kind": "ship", "id": "~your-ship/<observation id>"}`.

The unit of sharing is one body. Nothing else on your ship is visible to her. `DELETE /api/share/person/sarah/~sampel-palnet` ends it. A share carries the body whole, every attribute on it, so a body holding facts you would not share is not a body to share; the one filter is on the way back, where attributes named in her ship's `policy.sensitive` are never sent to yours. The whole protocol is in `docs/sharing.md`.

## Clients and keys

A phone app, a triager or a bot that does not run a ship gets a key instead of your cookie. A key has a name, an identity it writes as, and a scope.

```bash
post clients '{"name": "The phone client", "by": "phone",
               "scope": {"kinds": ["person", "place", "thing", "situation"], "actions": ["task"], "write": true}}'
```

The answer carries the `token` once; the ship keeps only a salted hash. The client sends it as `Authorization: Bearer <token>` with no cookie.

```bash
curl -s -H "Authorization: Bearer $TOKEN" $API/state
```

What a key sees is bounded by its scope: only the kinds it was given, never the attributes named in `policy.sensitive`, never a body outside its kinds, not even through a relation pointing at one. Everything it writes is signed `by` its own identity, whatever the request said. `write: false` makes it read-only, though it may still propose actions of its kinds for you to approve. A key minted with `"sensitive": "write"` may observe the attributes `policy.sensitive` names without ever reading one back, which is how a messenger files a medical fact it overheard. `GET /api/clients` lists the keys; `DELETE /api/clients/<id>` revokes one. The page's Keys view does all three: mint with a form, read the token once, revoke with a button. The rules are in `docs/keys.md`, and the contract a client follows is the client guide, [writing-a-client.md](https://github.com/nisfeb/orrery-utils/blob/main/docs/writing-a-client.md) in orrery-utils.

## Tools for an AI analyst

If your analyst runs on the ship's MCP server, orrery ships eight tools with the owner's views and writes, apart from the routes under What stays on HTTP in `docs/mcp.md`: `orrery_state`, `orrery_body`, `orrery_resolve`, `orrery_observe`, `orrery_retract`, `orrery_act`, `orrery_actions` and `orrery_schema`. Today they are called by path (`/apps/shell.shell/desks/orrery.desk/desk/code/lib/tools/orrery-state`); by name once the kernel discovery patch in `docs/kernel` is released. `docs/mcp.md` has the parameters and what an analyst on the ship can reach.

## How orrery stores data

Orrery is a desk in the grubbery shell, and everything it keeps is a grub: a file in the ship's content-addressed namespace, under the app's instance. Bodies, observations and actions are typed nouns stored under their own marks; everything else is JSON or a directory. One fiber, the writer at `main.sig`, is the only thing that mutates the tree: every route and every tool pokes it, and it applies the op or refuses it, leaving the outcome in `tr/last`. Current state is never stored; it is the fold over the live observations, computed on every read. The beacon at `beacon/rev` moves once per op that changed something, and is what a client keeps, over grubbery's keep-SSE, to learn that there is something new to fetch.

```
/apps/shell.shell/desks/orrery.desk/desk/data/orrery.orrery_app/   the app's instance
  main.sig                    the writer: every mutation is a poke here
  web.sig                     binds /apps/orrery; one request fiber per call under requests/<id>
  requests/<id>               the request fibers, ephemeral
  bodies/
    person/sarah/
      body                    kind, name, aliases, created, ship   [/orrery %body]
      obs/
        1758110400-3b9ac1f0   one observation: subject, attr, value, at, until, conf, source, by, seen, retracted, note   [/orrery %obs]
        ...
    situation/2026-09-16-breakdown/...
    thing/subaru/...
  actions/
    1758110400-9c2e41aa       one action: kind, title, payload, about, due, by, proposed, status, note, history   [/orrery %action]
  schema.json  policy.json    the vocabulary and the policy, seeded once, editable on the page
  beacon/rev                  the change beacon clients keep
  tr/last  tr/log  tr/inbox   the writer's last outcome, the audit ring (500), ship traffic (its own ring of 500)
  shares.json                 what this ship shares out, by body id
  shares.sig                  the inbox other ships poke offers, revokes and edits into
  share-offers.json           what was offered to this ship
  ship-remotes.json           what it accepted, a row per share
  sync.sig                    the follower: pull, then push
  clients.json                the minted keys, salted hashes only
  generator.json              the generator's settings; the model key lives here and is never served
  generator-last.json         what the generator's last pass did
  gen.sig                     the generator fiber, woken by the beacon
  reconcile.sig               the reconcile fiber, twice a day and on demand
  reconcile-last.json         what its last run did
  telegram.json               the reader's settings; the bot token and webhook secret live here and are never served
  telegram-recent.json        the last five messages per chat, kept a day as context
  telegram-last.json          the last update handled
  telegram-connections.json   the Business connections checked
  telegram-inbox/<update_id>  an update the webhook took, until the reader has read it
  telegram-inbox/rev          the inbox's own beacon, which wakes the reader
  telegram.sig                the reader: drains the inbox in id order
  exec.sig                    the executor: approved actions carried out, the todo list kept in step, the calendar's events read
  exec-last.json              what its last pass did
  calendar-seen.json          the calendar occurrences the ship has written, so each is written once
  calendar-events-last.json   what the calendar events reader last did
  refining/<aid>              the lock a refine request holds on its action
  tile.json  link.json  weir.json  icon.svg  orrery.html  orrery.css  orrery.js   the manifests and the page, laid fresh on every load
```

Every path is laid by `+on-load` in `code/nex/orrery/app.hoon` as a fall, so a reload never overwrites what is there, and a stored noun carries a version head (`%2` for bodies and actions, `%1` for observations) so a later shape is told apart by the reader instead of by luck. The three marks are in `code/mar/orrery`.

## Install

Orrery installs on any ship running grubbery. Run grubbery from the publishing ship, then add the desk through the shell by name and code path; it syncs within a few minutes.

```dojo
|install ~ricsul-bilwyt %grubbery
```

```bash
curl -s -b jar -H 'content-type: application/json' -X POST $SHIP/apps/grubbery/desks/add \
  -d '{"name": "orrery", "code": "~ricsul-bilwyt/apps/shell.shell/desks/orrery.desk/desk/code"}'
```

When the desk lands, a consent prompt on `/apps/grubbery/permits` asks you to approve the roads it reaches outside its own tree: the time and your ship, the web binding, notifications, the link registry, `/sys/iris/` for the model calls, `/sys/scry/` for the chat reader, the calendar and auspex desks for the executor, and the sharing roads (the poke that reaches the other ship, behn timers, ames peeks and usergroups). Refuse the sharing roads and everything else keeps working with sharing off; refuse the calendar or auspex roads and those actions are left for another executor. Then open `/apps/orrery`.

First settings, all under Settings on the page: rename `person/me` and give it a `timezone`; on the Generator card set the model and the key and turn it on if you want the ship to propose; on the Telegram card set the bot token, a secret and the ship's public URL, list the chats and map the people, and press register if you want the ship to read Telegram. A later release that adds a road raises the consent prompt again; anything else lands on its own whenever the publisher republishes `code/version.json`. `docs/releasing.md` is the maintainer's side of that.

## Under the hood

### The three shapes

Everything orrery stores is one of three shapes; everything else is a directory or a JSON file.

- A **body** is something that exists: a person, a place, a thing, an org, a situation or a note. Its id is `<kind>/<slug>`, and it carries a name, aliases, when it was created and, when it has one, its @p.
- An **observation** is one immutable claim about one body: `subject.attr = value`, with `at` (when it became true), `until`, `conf`, `source`, `by` and `seen` (when the ship recorded it). Its only mutable parts are the retracted flag and its note.
- An **action** is something to do: a task or a note the ship holds, or a client-executed kind such as a message, claimed by its executor before it acts. It carries `kind`, `title`, `payload`, `about`, `due`, `by`, `proposed`, `status`, `note` and its `history`.

Body kinds, attribute names, action kinds and source kinds are all open strings and values are JSON, so a new kind of fact never needs a migration.

### How current state is computed

State is never stored. It is a fold over the live observations, computed on every read.

- A single-valued attribute takes the observation with the latest `at`, ties broken by the latest `seen`.
- A multi-valued attribute collects the distinct values of its live observations. Reasserting a value refreshes it; removing one is retracting its observations.
- An observation whose `until` has passed is expired. One whose `at` is still ahead of the read time is future and does not win its slot. One that lost the fold is superseded. None of these is stored as such; all are labels in the timeline.
- A `null` value wins its slot and clears it.
- `?at=<time>` folds only observations with `at` at or before that time.

An observation's id is the unix seconds of `at`, a hyphen, and eight hex digits of a hash over subject, attribute, value, time and source, so the same claim from the same source is one row however often it is sent. Retraction keeps the row. On each write to a body, its superseded, expired and retracted rows older than `retention_days`, by the later of when they were true and when the ship recorded them, are culled; a live row never is.

### The HTTP API

Under `/apps/orrery/api`, JSON in and out, times as ISO 8601 UTC. The owner cookie or a key within its scope; anything else is 403.

| method and path | does |
|---|---|
| `GET /state?at=&kind=` | every body with its attributes and involvements, the open situations, the open actions, the beacon, the time it was folded at, `me` and the schema |
| `GET /body/<kind>/<slug>?at=` | one body with its timeline |
| `GET /resolve?q=` | bodies a phrase could mean: an exact hit on a ship, an email address, a phone number, a name or an alias, then bodies sharing every word of it, then prefixes; at most 20 |
| `POST /observe` | `{"bodies": [...], "observations": [...]}`: bodies upserted first, then observations; a result per item; at most 50 bodies and 200 observations |
| `POST /retract` | `{"id", "note"}` |
| `POST /bodies` | upsert one body |
| `DELETE /body/<kind>/<slug>` | remove the body and its observations; owner only |
| `GET /generator` | the generator's settings, the key masked as `api_key_set`; owner only |
| `PUT /generator` | merge settings: a key given replaces its value, one left out keeps it, a JSON `null` clears it so the default stands; an empty or absent `api_key` keeps the stored one. Answers the settings as stored, in the shape `GET` gives, once the write has landed; owner only |
| `GET /generator/last` | what the last pass did: filed, dropped, notes, usage, error, seconds |
| `POST /generate` | run a pass now, whether or not anything changed; owner only. With `{"about": ["situation/..."]}`, from the owner or a key with `write`, an urgent pass: past the cooldown, the named situations first, counted against `max_urgent` |
| `POST /apps/orrery/telegram` | Telegram's webhook, outside `/api`; the secret header is its whole credential, 403 on a wrong or missing one; 413 on a body over 64 KB, answered before the parse; a disabled reader, or an update whose id is not past the last one handled, answers 200 and drops |
| `GET` and `PUT /telegram` | the reader's settings, the token and secret masked as `token_set` and `secret_set`; a blank token or secret on PUT keeps the stored one, a JSON `null` clears any key, a secret under 16 bytes is refused; `PUT` answers the settings as stored once the write has landed; owner only |
| `GET /telegram/last` | the last update handled: outcome, notes, messages read today |
| `POST /telegram/webhook` | register this ship's webhook with Telegram, from the token, secret and public URL on the card, asking for one connection at a time; the owner or a key with `write` (version 38), so a client walking the owner through the setup can finish it |
| `GET /telegram/webhook` | what Telegram holds for the bot: the url, updates waiting, its last delivery error; the owner or a key with `write` |
| `POST /telegram/wake` | wake the reader: drain the inbox now, an update kept through a model outage included, or restart a reader that crashed; owner only |
| `GET` and `PUT /chat` | the chat reader's settings (`enabled`, `dms`, `channels`, `people`, `read_own`, `poll_minutes`, `backfill_hours`, `gate`, `escalate`, `max_daily_messages`, `model`); a key given replaces its value whole, one left out keeps it, a JSON `null` clears it so the default stands; `PUT` answers the settings as stored once the write has landed; the owner or a key with `write` |
| `GET /chat/last` | the last pass: `since`, `at`, `conversations` and `changed` (what the scries answered), `unpicked` (conversations changed that the owner did not pick) and `own` (the owner's own messages left unread while `read_own` is off), `read`, `filed`, `strangers`, `held`, `notes`, `read_today`, `down`; owner only |
| `POST /chat/wake` | run a pass now, or restart a reader that crashed; owner only |
| `GET /chat/dms`, `GET /chat/channels` | what the groups desk holds, for a picker: `items`, each `{"id", "name"}`, the name a DM's nickname from the contact book or a channel's group and channel titles, empty when there is none; and a `note` when the list could not be read; owner only |
| `GET /chat/peek?since=<iso>` | what a pass since then would find, without reading it: per agent, whether it answered, the conversations changed, how many of them are picked, the messages the picked ones hold (the owner's own included), and the first twenty names; a day ago unless given; owner only |
| `GET /exec/last` | what the executor's last pass did: `claimed`, `sent`, `placed`, `failed` (id, title and note, newest first, twenty at most), todos `ticked`, `deleted` and `moved`, tasks `closed` from the calendar, todos `adopted`, the desks link could not find in `missing`, and `notes`; `at` is when it last looked, `acted_at` when those counts happened, since a pass that did nothing keeps the last one that did; owner only |
| `POST /exec/wake` | run an executor pass now, or restart an executor that crashed; owner only |
| `GET /calendar/last` | what the calendar events reader last did: `events` read, bodies `made`, `rows` written, situations `cancelled`, `ops` the writer took, rules in `unknown`; `at` is when it last looked, `acted_at` when those counts happened; owner only |
| `POST /reconcile` | run the reconcile passes now, without waiting for the twice-daily run; owner only |
| `GET /reconcile/last` | what the last run did: time rows fixed, activities made, people made, participants added, merges proposed and run, retired, expired (presumed delivered), pruned |
| `POST /merge` | `{"from", "into"}`: fold one body into another and delete it; answers `{"from", "into", "moved", "repointed", "ok"}`; owner only |
| `POST /act` | propose; answers `{"id", "status", "existing"}` |
| `GET /actions?status=` | `open` by default (proposed, approved and claimed), `all`, or one status |
| `POST /actions/<id>` | `{"status", "note"}`: a transition |
| `POST /actions/<id>/refine` | `{"text"}`: a note at approval revises a `proposed` action, owner or a key whose `actions` names the kind, with `write`; answers `{"ok", "action", "extras", "note"}`; 409 unless the action is `proposed` and a task, a calendar event or a message |
| `GET` and `PUT /schema`, `/policy` | the whole document; `PUT` answers it as stored once the write has landed; owner only |
| `POST /share`, `GET /shares`, `POST /accept`, `POST /decline`, `DELETE /share/<id>/<ship>`, `POST /sync` | sharing; owner only. `/sync` prods the follower and answers 500 when that fiber refused the poke, as the telegram and executor wakes do |
| `POST /clients`, `GET /clients`, `DELETE /clients/<id>` | keys; owner only |

Live updates come from the instance's change beacon, streamed through grubbery's keep-SSE at `/grubbery/api/keep/apps/shell.shell/desks/orrery.desk/desk/data/orrery.orrery_app/beacon/rev`. It moves once per write that changed something, and a client that sees it move refetches what it shows. A write answers before the writer applies it, so read the state view for the new `rev`.

### The repository

- `code/` is the desk: the nexus at `code/nex/orrery/app.hoon` with the page beside it, the model in `code/lib/orrery.hoon` (pure, import-free, unit-tested), the MCP tools under `code/lib/tools`, the marcs under `code/mar`. `code/version.json` is what replicates. The telegram reader's fibers live in the nexus beside the webhook route; its own settings, window and connections are kept in the instance's `telegram.json`, `telegram-recent.json`, `telegram-last.json` and `telegram-connections.json`, none of them in git. The executor is the fiber `exec.sig` in the nexus, its planners `plan-exec` and `plan-mirror` in the lib, and its record the instance's `exec-last.json`; `code/mar/auspex-action.hoon` is a copy of auspex's marc, since a guest distributes every marc it names. The lib's `system-prompt`, `analyst-prompt` and `refine-prompt` cords are `orrery-utils/common/generator-prompt.md`, `analyst-prompt.md` and `refine-prompt.md`, word for word, held to them by `scripts/prompt-drift.py`.
- `tests/lib/orrery.hoon` and `tests/lib/generator.hoon` are the unit suites for the model, run with `-test` on a dev ship.
- `scripts/` holds the gates, all against a dev ship: `api-matrix.py` (the story above, over HTTP), `key-matrix.py`, `mcp-matrix.py`, `page-smoke.py` with `page-test.js`, and `ship-share-matrix.py` across two ships.
- `docs/`: the design at `docs/superpowers/specs/2026-09-16-orrery-design.md` and the plans under `docs/superpowers/plans`; `docs/sharing.md`, `docs/keys.md`, `docs/mcp.md`; `docs/releasing.md` for how a release propagates from the publisher to its subscribers; `docs/kernel` for the MCP discovery patch; `docs/spikes` for what was measured before a design was settled.

## Development

Development happens against a dev ship running grubbery, with the desk's code tree written to directly (`write-text` through the ball browser compiles at once, with no commit) and the owner cookie in a jar. Below, `$SHIP` is that ship's web address, `$JAR` its cookie jar from `POST /~/login`, and `$SHIP2` and `$JAR2` a second ship for the sharing gate. Nothing is released until every gate is green:

| gate | what it proves |
|---|---|
| `python3 scripts/code-closure.py code` | the code directory is closed under every marc and import a guest resolves; `--fill <grubbery desk>` vendors what is missing |
| `cmp code/lib/tools.hoon <grubbery checkout>/desk/gub/lib/tools.hoon` | the vendored tool types equal the kernel's, or every tool call breaks |
| `python3 scripts/prompt-drift.py <orrery-utils checkout>/common` | the prompt cords in the lib equal the shared prompt files word for word |
| `-test /=grubbery=/tests/lib/orrery ~` and `-test /=grubbery=/tests/lib/generator ~` in the dojo of a ship whose grubbery desk holds `code/lib/orrery.hoon` and the test files | the unit suites |
| `node scripts/page-test.js` | the page's render tests, no ship needed |
| `python3 scripts/api-matrix.py $SHIP $JAR` | the HTTP API, the story above end to end, twice in a row; run it first, since it deletes the bodies the sharing gate shares |
| `python3 scripts/key-matrix.py $SHIP $JAR` | what a scoped key can and cannot see and do |
| `python3 scripts/mcp-matrix.py $SHIP $JAR` | the eight tools, checked against the HTTP API's answers |
| `python3 scripts/page-smoke.py $SHIP $JAR` | the page and its assets are served |
| `python3 scripts/ship-share-matrix.py $SHIP $JAR $SHIP2 $JAR2` | sharing across two ships, read mode and edit mode |

Each prints `ALL OK` or names the first check that failed. A by-hand pass on `/apps/orrery` with the owner cookie closes a release: the views render, a retract and a move take effect, a settings save round-trips, and a write from a second client refreshes the page through the beacon. The release itself is a bump of `code/version.json`; `docs/releasing.md` says why that number is the whole mechanism and how to tell a release that landed from one that did not.

## Family

[lattice](https://github.com/nisfeb/lattice), [auspex](https://github.com/nisfeb/auspex) and [calendar](https://github.com/nisfeb/calendar) are desks in the same shell, installed the same way; orrery's executor sends mail through auspex and keeps its tasks and events in the calendar. [orrery-utils](https://github.com/nisfeb/orrery-utils) holds the shared prompts, the generator bench, the Telegram bot the ship's reader replaced, and the client guide.
