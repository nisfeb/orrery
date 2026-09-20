# orrery

Orrery keeps track of what is going on in your life, on your own Urbit ship. It remembers the people, places, things and situations around you, what is currently true about each of them, where every fact came from, and what your assistant proposes to do about it.

The ship stores the facts and their history. It runs no AI. The thinking happens in clients: a small model on your phone or laptop turns messages, mail and calendar events into facts and sends them in, and a larger model reads the picture back and proposes actions. You approve them, or let a policy approve the routine ones for you.

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
SHIP=http://localhost:8080          # your ship's web address
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
    {"subject": "situation/2026-09-16-breakdown", "attr": "status",       "value": "open",                   "source": {"kind": "talon-dm", "id": "msg-1"}},
    {"subject": "situation/2026-09-16-breakdown", "attr": "participants", "value": {"ref": "person/me"},    "source": {"kind": "talon-dm", "id": "msg-1"}},
    {"subject": "situation/2026-09-16-breakdown", "attr": "participants", "value": {"ref": "person/sarah"}, "source": {"kind": "talon-dm", "id": "msg-1"}},
    {"subject": "situation/2026-09-16-breakdown", "attr": "location",     "value": "Route 9",                "source": {"kind": "talon-dm", "id": "msg-1"}}
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

An executor claims an approved action before it acts, with `{"status": "claimed", "by": "telegram"}`, and the claim holds it for ten minutes.

A second executor's claim inside that lease is refused with `claimed by telegram`, only the claimant reports done or failed, and you unstick a claimed action by dismissing it.

The answer to a move carries the `by` the ship will store, and it comes back before the writer has applied the move, so an executor confirms its claim by reading the action back and acts only when the last claimed step names it.

Two claims fired in the same instant both answer ok; the writer keeps the first, and the second executor learns it lost when it reads the action back.

Every action carries its history: who proposed it, who approved it (you, or `policy`), who claimed it, and when. The audit question is answered by the action itself.

The ship proposes on its own. With the generator on (the Generator card under Settings), every change to the state wakes a pass: the ship builds the prompt from what it holds, asks the model you named through `/sys/iris/`, keeps what the schema allows and files it as proposals signed `generator`. A pass is skipped while the prompt would be the one sent last, so a quiet day costs nothing; `POST /generate` runs one regardless. Dismissing on the page asks for a reason and will not go without one ("just the event", "I always do this"); the reason rides into the next prompt with the decision, where the model generalises from it; that is how the generator learns your taste without a rulebook. The card also shows the model calls made today and the month's spend, summed from the cost figure each answer carries. The key never leaves the ship and is never read back. `docs/spikes/2026-09-19-iris-probe.md` is why the ship can wait for a slow model, and `orrery-utils/generator` remains the bench and the dry-run harness.

The ship also reconciles on its own. Twice a day, and on `POST /reconcile`, it runs the passes that used to be `orrery-utils/common/reconcile.py`, in order: a future `started` or `ended` becomes `starts` or `ends` (the schedule, dated when it was learned) and a situation status that is not open, closed or cancelled is retracted; situations that are occurrences of one repeating event (three or more with the same calendar uid or the same title) become one activity with an observation per occurrence, and the occurrences are deleted; people are read out of titles ("Mira- Ballet/Tap", "Felix Birthday") and made participants, created when the ship lacks them; bodies that name one person (an org made from a person's name, two persons whose names or addresses match) become merge proposals, actions of kind `merge` for the inbox, and the ones you approve are run; then what is over closes (a situation whose end has passed closes at that end, a trip with no end a week after it started, a situation with a start but no end that began more than thirty days ago with nothing seen since closes at its newest observation), and, when `reconcile.prune_days` in the policy is set, closed situations older than that are deleted. Every change is an ordinary observation, retraction or deletion signed `reconcile` (`retire` for the closes), filed through the writer. The settings live under `reconcile` in `policy.json`: `min_occurrences` (3), `stale_days` (30) and `prune_days` (0, off). The Settings page shows what the last run did and runs one now. Version 25 moved retire on-ship, version 26 the rest.

### Where facts come from

Every observation names its `source`, a kind and an opaque id such as the message it was read from, and its `by`, who asserted it. The text is never stored. Confidence (`conf`, 0 to 100) says how sure the asserter was.

The writer keeps a trail of its last 500 outcomes: the op, whether it applied, why not, when, and who asked. It is read through the ball browser at `GET /grubbery/ball/apps/shell.shell/desks/orrery.desk/desk/data/orrery.orrery_app/tr/log?raw=1`, with the last outcome alone at `tr/last`.

### The page

`/apps/orrery` on your ship, owner only: bodies grouped by kind with situations that are over folded under a past heading, one body with its attribute table, its situations, its open actions and its timeline with a retract button, the actions inbox with approve, dismiss, done and failed, keys with each key's scope, when it was made and last used, a revoke per key and a form that mints one and shows its token once, and settings with a Generator card (the model, the key written once and never shown, a run-now button and the last pass) above the schema and the policy as editable JSON. It refreshes itself whenever the ship's state changes.

### The vocabulary

`GET` and `PUT /schema` hold the vocabulary the models are advised to use: the kinds, the attributes each kind commonly has, notes saying what an attribute means where the name alone misleads, the action kinds with the payload shape each takes (`payloads`: a message's `via` is one of the channels listed there, `to` a body id; a calendar event's `starts`), and the one thing the ship enforces, which attributes are multi-valued. Unknown kinds and attributes are accepted; adding a new kind of fact never changes a type.

`GET` and `PUT /policy` hold the rules: `auto`, the action kinds approved on proposal; `push`, when to send a notification (`proposed`, `all` or `none`); `retention_days`, how long superseded, expired and retracted rows are kept; and `sensitive`, the attribute names a client key never sees, `health` and `income` from the start.

## Sharing a body with another ship

Sarah runs her own ship. Share her body with her and her ship mirrors what you know about her. In edit mode, what she records about herself comes back to yours.

```bash
post observe '{"bodies": [{"id": "person/sarah", "ship": "~sampel-palnet"}]}'
post share '{"id": "person/sarah", "ship": "~sampel-palnet", "mode": "edit"}'
```

On her ship (point `API` and the cookie jar at it first), `GET /api/shares` lists the offer and `post accept '{"host": "~your-ship", "id": "person/sarah"}'` takes it. Because the body carries her ship's name it lands on her own `person/me`. Her ship reads the body every five minutes and on demand (`POST /api/sync`), and every mirrored fact names its origin: `by` is your ship, and `source` is `{"kind": "ship", "id": "~your-ship/<observation id>"}`.

The unit of sharing is one body. Nothing else on your ship is visible to her. `DELETE /api/share/person/sarah/~sampel-palnet` ends it. A share carries the body whole, every attribute on it, so a body holding facts you would not share is not a body to share; the one filter is on the way back, where attributes named in her ship's `policy.sensitive` are never sent to yours. The whole protocol is in `docs/sharing.md`.

## Keys for clients that do not run a ship

A phone app, a triager or a bot gets a key instead of your cookie. A key has a name, an identity it writes as, and a scope.

```bash
post clients '{"name": "Talon on the phone", "by": "talon",
               "scope": {"kinds": ["person", "place", "thing", "situation"], "actions": ["task"], "write": true}}'
```

The answer carries the `token` once; the ship keeps only a salted hash. The client sends it as `Authorization: Bearer <token>` with no cookie.

```bash
curl -s -H "Authorization: Bearer $TOKEN" $API/state
```

What a key sees is bounded by its scope: only the kinds it was given, never the attributes named in `policy.sensitive`, never a body outside its kinds, not even through a relation pointing at one. Everything it writes is signed `by` its own identity, whatever the request said. `write: false` makes it read-only, though it may still propose actions of its kinds for you to approve. A key minted with `"sensitive": "write"` may observe the attributes `policy.sensitive` names without ever reading one back, which is how a messenger files a medical fact it overheard. `GET /api/clients` lists the keys; `DELETE /api/clients/<id>` revokes one. The page's Keys view does all three: mint with a form, read the token once, revoke with a button. The rules are in `docs/keys.md`.

## Tools for an AI analyst

If your analyst runs on the ship's MCP server, orrery ships eight tools with the owner's views and writes, apart from the routes under What stays on HTTP in `docs/mcp.md`: `orrery_state`, `orrery_body`, `orrery_resolve`, `orrery_observe`, `orrery_retract`, `orrery_act`, `orrery_actions` and `orrery_schema`. Today they are called by path (`/apps/shell.shell/desks/orrery.desk/desk/code/lib/tools/orrery-state`); by name once the kernel discovery patch in `docs/kernel` is released. `docs/mcp.md` has the parameters and what an analyst on the ship can reach.

## Install

Orrery is a desk in the grubbery shell, distributed by `~ricsul-bilwyt`. Today it runs on ricsul unpublished: only ships in its beta usergroup can read the desk, and it is not yet a stock desk. Once your ship is in that group (or once orrery is published), run grubbery from ricsul and add the desk through the shell.

```dojo
|install ~ricsul-bilwyt %grubbery
```

```bash
curl -s -b jar -H 'content-type: application/json' -X POST $SHIP/apps/grubbery/desks/add \
  -d '{"name": "orrery", "code": "~ricsul-bilwyt/apps/shell.shell/desks/orrery.desk/desk/code"}'
```

The desk syncs within a few minutes, and a consent prompt asks you to approve the roads it reaches outside its own tree: the time and your ship, the web binding, notifications, the link registry, and the sharing roads (the poke that reaches the other ship, behn timers, ames peeks and usergroups). Refuse the sharing roads and everything else keeps working with sharing off. Then open `/apps/orrery`. Updates arrive on their own whenever ricsul republishes `code/version.json`.

### Updating ricsul

Ricsul's forge tracks this repository and polls it every 15 minutes. Its desk follows the forge's tree and pulls only when `code/version.json` differs from its own, so the one thing that ships a change is the version number.

1. Bump `code/version.json` by one and push to `main`. A push without the bump reaches the forge and stops there, with nothing to tell you.
2. Wait for the poll, or pull now:

```bash
curl -s -b jar -H 'content-type: application/json' -X POST https://urbit.sneagan.com/grubbery/forge/api/run \
  -d '{"repo": "orrery.git_repo", "command": "pull"}'
```

3. Check that it landed: the desk's `version.json` reads the new number and the instance's `bang` is null.

```bash
R=https://urbit.sneagan.com
curl -s -b jar "$R/grubbery/ball/apps/shell.shell/desks/orrery.desk/version.json?raw=1"
curl -s -b jar "$R/grubbery/ball/apps/shell.shell/desks/orrery.desk/desk/data/orrery.orrery_app?info=1" | python3 -c 'import sys, json; print(json.load(sys.stdin)["bang"])'
```

A release that adds a road to the ask raises a consent prompt on ricsul. Anything else lands on its own, and every ship following ricsul's desk syncs the new version by itself. `docs/releasing.md` has the failure modes and how to get out of each.

### Opening it to beta testers

The desk stays unpublished. Testers get it through a usergroup that may read the desk's code, and nothing else on ricsul.

1. Make a usergroup for them on ricsul: a `<name>.grp` directory under `/sys/ames/usergroups` with the testers' ships in its `who.ships`, the way `/family` was made.
2. Open the desk to that group: on `/grubbery/desk/orrery`, under "Usergroups allowed to peek /desk/code", add `/<name>`. Over HTTP:

```bash
curl -s -b jar -H 'content-type: application/json' -X POST https://urbit.sneagan.com/grubbery/desk/orrery/share -d '{"add": "/<name>"}'
```

`{"remove": "/<name>"}` closes it again. The grant is peek on the code and the version file, nothing else.

3. Each tester runs the install above on a ship running grubbery, approves the ask when the desk prompts, and opens `/apps/orrery`. Every later version bump reaches them on its own.

Publishing proper, when it is time, is the stock desk line beside calendar's in grubbery's `gub/nex/shell.hoon` and opening the desk to `/public`. Nothing about the beta group has to be undone first.

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
| `PUT /generator` | merge settings; an empty or absent `api_key` keeps the stored one; owner only |
| `GET /generator/last` | what the last pass did: filed, dropped, notes, usage, error, seconds |
| `POST /generate` | run a pass now, whether or not anything changed; owner only |
| `POST /reconcile` | run the reconcile passes now, without waiting for the twice-daily run; owner only |
| `GET /reconcile/last` | what the last run did: time rows fixed, activities made, people made, participants added, merges proposed and run, retired, pruned |
| `POST /merge` | `{"from", "into"}`: fold one body into another and delete it; answers `{"from", "into", "moved", "repointed", "ok"}`; owner only |
| `POST /act` | propose; answers `{"id", "status", "existing"}` |
| `GET /actions?status=` | `open` by default (proposed, approved and claimed), `all`, or one status |
| `POST /actions/<id>` | `{"status", "note"}`: a transition |
| `GET` and `PUT /schema`, `/policy` | the whole document; owner only |
| `POST /share`, `GET /shares`, `POST /accept`, `POST /decline`, `DELETE /share/<id>/<ship>`, `POST /sync` | sharing; owner only |
| `POST /clients`, `GET /clients`, `DELETE /clients/<id>` | keys; owner only |

Live updates come from the instance's change beacon, streamed through grubbery's keep-SSE at `/grubbery/api/keep/apps/shell.shell/desks/orrery.desk/desk/data/orrery.orrery_app/beacon/rev`. It moves once per write that changed something, and a client that sees it move refetches what it shows. A write answers before the writer applies it, so read the state view for the new `rev`.

### The repository

- `code/` is the desk: the nexus at `code/nex/orrery/app.hoon` with the page beside it, the model in `code/lib/orrery.hoon` (pure, import-free, unit-tested), the MCP tools under `code/lib/tools`, the marcs under `code/mar`. `code/version.json` is what replicates.
- `tests/lib/orrery.hoon` is the unit suite for the model, run with `-test` on a dev ship.
- `scripts/` holds the gates, all against a dev ship: `api-matrix.py` (the story above, over HTTP), `key-matrix.py`, `mcp-matrix.py`, `page-smoke.py` with `page-test.js`, and `ship-share-matrix.py` across two ships.
- `docs/`: the design at `docs/superpowers/specs/2026-09-16-orrery-design.md` and the plans under `docs/superpowers/plans`; `docs/sharing.md`, `docs/keys.md`, `docs/mcp.md`; `docs/releasing.md` for how a release reaches ricsul and its subscribers; `docs/kernel` for the MCP discovery patch.
- Family: [lattice](https://github.com/nisfeb/lattice), [auspex](https://github.com/nisfeb/auspex), [calendar](https://github.com/nisfeb/calendar), installed from `~ricsul-bilwyt` the same way.
