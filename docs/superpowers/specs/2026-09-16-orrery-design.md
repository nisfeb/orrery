# Orrery: a model of the user's world, kept on their ship

Status: draft for review. 2026-09-16.

## 1. What this is

Orrery keeps a model of what is going on in one person's life: the people, places, things and situations around them, what is currently true about each, where each fact came from, and what the assistant proposes to do about it. It is a grubbery desk app in the nisfeb family, installed from `~ricsul-bilwyt` the way lattice, auspex and calendar are.

The ship holds the state and its history. It runs no AI. Clients do the thinking: a local model on the client (Talon, later) triages messages, mail and calendar events into observations and submits them. A larger model reads the state back and proposes actions, or files them straight to the todo list when policy allows. In the first release the analyst is Claude Code over MCP tools compiled into the desk, so the loop runs before any client code exists.

The name is the instrument: a mechanical model of bodies in motion, read to know where everything is now and where it was.

## 2. The three shapes

Everything orrery stores is one of three shapes. Everything else is a directory or a JSON grub.

- A **body** is something that exists: a person, a place, a thing, an org, a situation, or a note. It has a stable id, a kind, a name and aliases. The user is the body `person/me`.
- An **observation** is one claim about one body: `subject.attr = value`, with when it became true, when it is expected to stop being true, how confident the asserter was, where it came from, and who asserted it. Observations are immutable. Current state is a fold over them.
- An **action** is something to do: a task, a note to the user, or a client-executed kind such as a message. It moves through proposed, approved, done, dismissed, failed. Tasks are actions, so the todo list is "approved tasks not yet done".

Extension points are deliberate and few: body kinds, attribute names, action kinds and source kinds are all open strings, and values are JSON. Adding a new kind of fact never changes a type, a marc, or a migration.

## 3. The model

### Bodies

A body id is `<kind>/<slug>`. A kind is lowercase ascii, digits and hyphens, at most 24 bytes. A slug is the same charset, at most 64 bytes. Examples: `person/sarah`, `thing/subaru`, `place/johns-machine-shop`, `situation/2026-09-16-breakdown`.

A body carries `kind`, `name` (at most 200 bytes), `aliases` (a set of at most 32 strings of at most 100 bytes each) and `created`. Aliases are the names and handles a triager may see in text: "Sarah", "~sampel-palnet", "the shop". Everything else about a body is an observation.

`person/me` is created on first load with the name `me` and the aliases `me`, `I` and the ship's own `@p`. The user or a client renames it.

An upsert of an existing id replaces the name if one is given and unions the aliases. There is no merge of two bodies in v1: retract the observations on the duplicate and delete it.

### Observations

| field | type | rule |
|---|---|---|
| `subject` | body id | must exist, or be created in the same batch |
| `attr` | string | lowercase ascii, digits, hyphens, at most 48 bytes |
| `value` | JSON | a string (at most 2000 bytes), number, boolean, `null`, `{"ref": "<body id>"}`, or any other object at most 2000 bytes serialized |
| `at` | time | when it became true. ISO 8601 UTC on the wire. Defaults to now |
| `until` | time or null | when it is expected to stop being true. Optional |
| `conf` | 0 to 100 | how confident the asserter was. Defaults to 100 |
| `source` | `{"kind", "id"}` | where it came from: `talon-dm`, `mail`, `calendar`, `user`, `model`, or any other kind. The id is opaque, at most 200 bytes, and is the only evidence kept. Never the text |
| `by` | string | who asserted it: `talon/triage`, `claude-code`, `user`. At most 64 bytes |
| `seen` | time | when the ship recorded it. Set by the ship |
| `status` | `live` or `retracted` | the only mutable field |

A `{"ref"}` value must name an existing body. A ref-valued attribute is a relation: `spouse`, `owner`, `location`, `employer`. There is no separate relation type.

A `null` value clears a single-valued attribute: "no longer stranded" without pretending to know the new state.

The observation id is the unix seconds of `at`, a hyphen, and the first 8 hex digits of `(sham [subject attr value at source])`. The same claim from the same source resubmitted is the same id and a no-op. `by` and `seen` are outside the hash so two clients asserting one fact do not make two.

Retraction sets `status` to `retracted` with a note. The grub stays. Superseded and expired are never stored; they are computed on read.

### Actions

| field | type | rule |
|---|---|---|
| `kind` | string | `task` and `note` are native: the ship holds them and the user marks them done. Any other kind (`message`, `calendar`, ...) is executed by a client that then reports done or failed |
| `title` | string | at most 200 bytes |
| `payload` | JSON | at most 4000 bytes serialized. For a task: notes. For a message: recipient and text |
| `about` | set of body ids | at most 20, each must exist |
| `due` | time or null | optional |
| `by` | string | who proposed it |
| `proposed` | time | set by the ship |
| `status` | enum | `proposed`, `approved`, `done`, `dismissed`, `failed` |
| `note` | string | why it was dismissed or failed, at most 500 bytes |

Transitions: proposed to approved or dismissed; approved to done, failed or dismissed. Failed is terminal in v1; propose again.

A proposal whose `kind` and `title` match an open action (proposed or approved) returns the existing id instead of making a second one. Fuzzy duplicates are the analyst's job: it reads the open actions before proposing.

`policy.json` names the kinds that are approved the moment they are proposed. With `{"auto": ["task", "note"]}` the assistant adding a todo item is one write and no question. Everything not listed waits in the inbox.

### Derived views, never stored

A body's current attributes are a fold over its live observations:

- A single-valued attribute takes the observation with the latest `at`, ties broken by latest `seen`. Event time wins over arrival time, so a tow receipt that arrives at 23:00 saying the car was picked up at 19:30 cannot overwrite the 21:00 fact that it is at the shop.
- A multi-valued attribute, one listed under `multi` in `schema.json`, collects the distinct values of its live observations, each carrying its latest observation. Reasserting a value refreshes it. Removing a value is retracting its observations.
- An observation with `until` in the past is expired and does not contribute. An observation that lost the fold is superseded. Both are labelled in the timeline and neither is stored.
- A `null` value wins its slot and clears it.
- `?at=<time>` folds only observations with `at` at or before that time. "What was true on Tuesday" is a filter over immutable events, not a grubbery history read.

`involved` on a body view lists the situations whose `participants` name it and whose `status` is not `closed`. This is the reverse reference that makes Sarah's state reflect the breakdown without a copy: she is a participant, and a triager may also assert `person/sarah.status` directly.

The state view is every body with its current attributes, the open situations, the open actions and the schema, as one JSON document. It is what the analyst reads. It takes `?at` and `?kind`. A body view adds the full timeline, newest first, each entry with its computed status and its source pointer.

### schema.json and policy.json

`schema.json` is advisory vocabulary for the models: the kinds, the attributes each kind commonly has, the action kinds, and the one thing the ship enforces, which attributes are multi-valued. Unknown kinds and attributes are accepted. The user edits it; a client may too. It is seeded once and edits survive reloads.

The starter schema:

```json
{
  "kinds": {
    "person":    {"attrs": ["status", "location", "phone", "email", "ship", "birthday", "relationship", "employer", "timezone", "likes", "dislikes"]},
    "place":     {"attrs": ["type", "address", "phone", "hours", "geo"]},
    "thing":     {"attrs": ["type", "status", "location", "owner", "make", "model", "plate", "last-service", "warranty-until"]},
    "org":       {"attrs": ["type", "phone", "email", "website", "contact", "address"]},
    "situation": {"attrs": ["status", "participants", "location", "started", "ended", "summary"]},
    "note":      {"attrs": ["text"]}
  },
  "multi": ["participants", "likes", "dislikes", "household", "vehicles", "children", "owners", "members", "aware-of"],
  "actions": ["task", "note", "message", "calendar"]
}
```

`policy.json` starts as `{"auto": ["task", "note"], "push": true, "retention_days": 365}`. `push` sends a notification through `/sys/push` for every new action, proposed or auto-approved. `retention_days` bounds compaction: on each write to a body, its observations that are superseded, expired or retracted and older than the retention are culled. A live observation is never culled.

## 4. Shape of the desk

```
code/
  bill.json          {"orrery.orrery_app": "/orrery/app"}
  version.json       what replicates: a subscriber re-syncs only when it changes
  tile.json  icon.svg
  nex/orrery/app.hoon            the nexus
  nex/orrery/orrery.html  orrery.js  orrery.css    the page, plain files, no build
  lib/orrery.hoon                import-free: types, ids, validation, the fold, resolve, codecs
  lib/tools.hoon                 the tool types, vendored from the kernel
  lib/tools/orrery-*.hoon        the MCP tools
  mar/orrery/body.hoon  obs.hoon  action.hoon      noun passthroughs
  mar/json.hoon  sig.hoon  mime.hoon               the kernel marcs the tree lays, vendored as auspex does
tests/lib/orrery.hoon            unit tests, run on ~wex with the revision pinned
scripts/api-matrix.py            the HTTP gate against ~wex
docs/                            this spec, releasing.md copied from calendar, using.md
```

Repo `nisfeb/orrery`, branch `main`. The desk is hermetic: every lib and marc it uses is inside `code/`, checked by a copy of auspex's `scripts/code-closure.py`.

## 5. The tree and the writer

```
/main.sig                          the writer: every mutation goes through it
/bodies/<kind>/<slug>/body         one grub per body                  [/orrery %body]   history on
/bodies/<kind>/<slug>/obs/<oid>    one grub per observation           [/orrery %obs]
/actions/<aid>                     one grub per action                [/orrery %action] history on
/schema.json  /policy.json         seeded once, edits survive         [/ %json]
/beacon/rev                        the change beacon                  [/ %json]
/tr/last                           the last writer outcome, as json   [/ %json]
/ui/main.sig  /ui/requests/<id>    binds /apps/orrery, one fiber per request
/tile.json /icon.svg /link.json /weir.json /orrery.html /orrery.js /orrery.css   replaced on every reload
```

Everything about a body sits under its own directory, so one deep peek reads a body and one shallow peek lists a kind. Files and subdirectories are separate maps in a ball, so `body` and `obs/` never collide.

`/bodies` and `/actions` are laid with retention on, so grubbery keeps a version per write of a body's name and aliases and of an action's status. Observations are immutable, so as-of reads never need that history. Every persistent path has a covering `%fall` row in `on-load`; the page, the icon and the two manifests are `%over` so a release replaces them.

**The writer.** `/main.sig` is one long-lived fiber, the shape lattice and auspex use: rise, then loop on take-poke, apply, bump, recurse. It takes `[/ %json]` pokes carrying one op: `observe`, `retract`, `act`, `set-action`, `upsert-body`, `delete-body`, `set-schema`, `set-policy`. It applies with soft makes and overwrites, bumps `/beacon/rev` once per op that changed the tree, compacts the touched bodies, and sends the push for a new action. It never crashes on input: every refusal is a clean branch under `mule` with a `~|` label, written to `/tr/last`, because a crashed writer eats the next poke.

Orrery keeps no stored index. That is why the callers can answer without a reply channel: a request fiber or a tool validates the op with the pure lib, computes every id it will report, pokes the writer, and answers from its own computation. The one inaccuracy is a race between two callers, which the writer's soft make turns into "already existed" and `/tr/last` records. A reply grub per request is the upgrade if late refusals ever matter.

The beacon is nested and bumps only on a change, for the reasons auspex recorded: a root grub does not stream, and a bump on a no-op is a free reload of every open client.

## 6. Surfaces

### HTTP, under `/apps/orrery/api`

Owner only: the eyre `authenticated` flag and `src` equal to `our`, else 403. JSON in, JSON out. Times are ISO 8601 UTC in both directions.

| method and path | does |
|---|---|
| `GET /state?at=&kind=` | the state view |
| `GET /body/<kind>/<slug>?at=` | one body with its timeline |
| `GET /resolve?q=` | bodies whose name or alias matches, exact first then prefix, case-insensitive, at most 20 |
| `POST /observe` | `{"bodies": [...], "observations": [...]}`: bodies upserted first, then observations; per-item results |
| `POST /retract` | `{"id", "note"}` |
| `POST /bodies` | upsert one body |
| `DELETE /body/<kind>/<slug>` | cull the subtree. Refs to it elsewhere render as the bare id |
| `POST /act` | propose; answers `{"id", "status"}`, status `approved` when policy says so |
| `GET /actions?status=open` | `open` by default, meaning proposed and approved; `all`; or one status |
| `POST /actions/<id>` | `{"status", "note"}`: a transition |
| `GET` and `PUT /schema`, `/policy` | the whole document |

Batch caps: 50 bodies and 200 observations per observe. A caller that needs more sends more requests.

Observe answers per item so an AI client can fix the one it got wrong:

```json
{"rev": 42,
 "bodies": [{"id": "place/johns-machine-shop", "ok": true, "existing": false}],
 "observations": [{"id": "1758056400-a3f9c1d2", "ok": true, "existing": false},
                  {"ok": false, "error": "unknown subject thing/subaru"}]}
```

Live updates: `/beacon/rev` streams through grubbery's keep-SSE the way lattice's and auspex's beacons do. A client that sees it move refetches what it shows.

### MCP tools, in `code/lib/tools`

Eight tools, each a `tool:tools` core, reads by absolute peek into the instance, writes by one poke road to `/main.sig`, the shape lattice's tools use. Parameters are the five MCP scalar types, so a batch arrives as an array parameter whose description states the object shape.

| tool | parameters |
|---|---|
| `orrery-state` | `at`, `kind` |
| `orrery-body` | `id` |
| `orrery-resolve` | `q` |
| `orrery-observe` | `bodies`, `observations`, `by` |
| `orrery-retract` | `id`, `note` |
| `orrery-act` | `kind`, `title`, `payload`, `about`, `due`, `by` |
| `orrery-actions` | `status` to list; `id` and `status` to transition, `note` |
| `orrery-schema` | none to read; `schema` to replace |

**A gap in the kernel, found while writing this.** The mcp nexus discovers app tools by scanning `/apps/<app>/desk/code/lib/tools`, which predates desks living under the shell at `/apps/shell.shell/desks/<name>.desk/desk/code`. Lattice's tools are vendored into the kernel's own bundle for that reason. Two things follow. Any tool is callable today by location, since `await-tool` takes an absolute source path in place of a name, so `call_tool` with `/apps/shell.shell/desks/orrery.desk/desk/code/lib/tools/orrery-state` works without discovery. The durable fix is a small patch to `+get-app-mcp-paths` in `gub/nex/mcp.hoon` that also walks `/apps/shell.shell/desks/*/desk/code/lib/tools`, rehearsed on `~wex` and released with the dist branch. Calendar's and auspex's tools could then leave the kernel too. Phase 2 confirms the gap on `~wex` before the patch, and confirms what grants the mcp instance holds toward a desk app, since lattice's tools reach lattice through roads that exist somewhere.

### The page, at `/apps/orrery`

One document, css inlined, one script, served no-cache, built the way calendar's is. Four views: bodies grouped by kind; a body with its attribute table, its situations, its open actions and its timeline with source pointers and a retract button; the actions inbox with approve, dismiss, done and failed; settings with the schema and the policy as editable JSON. It reloads on the beacon. It is a reader with buttons, not an editor: creating bodies and observations by hand is a v2 question.

## 7. The ask

`weir.json` declares what the instance reaches outside its own tree, in words for the person granting it:

- poke `/sys/bowl.sig`: read the time and our ship
- poke `/sys/eyre/`: bind `/apps/orrery` and answer requests
- poke `/sys/push/`: notify you when the assistant proposes or files an action. Refuse this and proposals wait silently in the inbox
- peek `/sys/link/`: find where this app is installed, so the page can address its own writer

No `/sys/ames/*`, no iris, no behn. Nothing in v1 is ship-to-ship, nothing fetches, and there is no ticker: expiry is computed on read and compaction runs on write.

## 8. The acceptance scenario

Three messages, one analyst step. `scripts/api-matrix.py` runs this over HTTP against `~wex`; phase 2 runs it again from the raw text over MCP with Claude Code as the triager and the analyst, and the state must match.

**Setup.** Bodies: `person/me`, `person/sarah` (aliases Sarah, wife), `thing/subaru` (aliases the car, subaru), `place/home`. Observations: `person/me.spouse = {ref person/sarah}`, `person/me.home = {ref place/home}`, `thing/subaru.owner = {ref person/me}`. Policy: the starter.

**Message 1**, 2026-09-16T22:05Z, DM to Sarah: "car died on route 9, stranded waiting for a tow". The triager submits:

- `person/me.status = "stranded, waiting for a tow"`, `at` 22:00, `until` 02:00 next day, conf 90
- `person/me.location = "Route 9"`
- `thing/subaru.status = "broken down"`, `thing/subaru.location = "Route 9"`
- a new body `situation/2026-09-16-breakdown` with `status = "open"`, `participants` = me, Sarah, the Subaru, `location = "Route 9"`, `started` 22:00

Assert: the state view shows all of it; `person/sarah`'s `involved` names the situation.

**Message 2**, 23:40Z: "tow guy is here, taking it to john's machine shop". The triager resolves "john's machine shop", finds nothing, creates `place/johns-machine-shop` (aliases John's, the shop) in the same batch, and submits `thing/subaru.status = "being towed to John's Machine Shop"` and `person/me.status = "riding with the tow"`.

**Message 3**, 2026-09-17T02:10Z: "home. left the car at john's overnight, they'll look at it in the morning". The triager submits `thing/subaru.location = {ref place/johns-machine-shop}`, `thing/subaru.status = "at the shop, awaiting diagnosis"`, `person/me.location = {ref place/home}`, `person/me.status = null`, and `situation/2026-09-16-breakdown.status = "car at shop, awaiting diagnosis"`.

Assert: the Subaru is at John's and me is home with no status; `?at=2026-09-16T23:00Z` still puts the Subaru on Route 9; the situation is still open; resubmitting message 3's batch changes nothing and answers `existing` on every item.

**The analyst** reads the state, sees an open situation with a car at a shop and no action about it, and proposes `{"kind": "task", "title": "Call John's Machine Shop about the Subaru", "about": ["thing/subaru", "place/johns-machine-shop"], "due": "2026-09-17T13:00Z"}`. Assert: the answer is `approved` because policy auto-approves tasks; the open actions list has it; a second identical proposal answers the same id; `/tr/last` records the push attempt.

**Cleanup checks.** Retract the "riding with the tow" observation: the timeline labels it retracted and the fold ignores it. Mark the task done: it leaves the open list. Set `retention_days` to 0 and write to the Subaru: the superseded observations are culled, the live ones remain.

## 9. Constraints this build honors

From the lattice, auspex and calendar releases, each silent at the point of failure:

1. Every blot the tree lays has a marc inside the desk, or the poke parks silently.
2. Every marc is a noun passthrough; the shape ladder lives in the reader, newest shape first, under `mule`.
3. Every persistent path has a covering row in `on-load`; an uncovered path is deleted on reload.
4. Long-lived fibers use absolute roads.
5. No `$` with arguments inside a `;<` continuation.
6. The writer never crashes on input.
7. A release is a `code/version.json` bump, and the instance's `bang` is the proof it landed, not the version number.
8. Nothing touches `~ricsul-bilwyt` until it has passed on `~wex`, and the publish is sneagan's action.

## 10. Testing

- **Unit**, `tests/lib/orrery.hoon`, on `~wex` with the revision pinned: id derivation is deterministic and excludes `by`; kind, slug, attr and cap validation; the single-valued fold prefers latest `at` and breaks ties on `seen`; the multi fold collects and refreshes; `until` expires; `null` clears; retracted observations are ignored; `?at` filtering; `involved`; resolve ordering; JSON round-trips for all three shapes.
- **HTTP gate**, `scripts/api-matrix.py` against `~wex`: section 8, plus 403 for a non-owner, 400 with the field named for every cap, and the batch caps.
- **MCP gate**, phase 2: the tools list from `tools/list` includes the eight, and the section 8 scenario from raw text through Claude Code lands the same state.
- **Page**, phase 3: by hand on `~wex`, the scenario visible in all four views.
- Never against `~ricsul-bilwyt` until all of the above pass.

## 11. Phases

Each phase is installable and useful on its own.

1. **Desk and model.** The repo laid out as section 4, `lib/orrery.hoon` with its tests, the writer, the HTTP API, install on `~wex`. Gate: the unit tests and the HTTP matrix green. About two days.
2. **MCP and push.** The eight tools, the discovery check and the kernel patch if the gap is confirmed, the push on proposal. Gate: the MCP scenario. About one day.
3. **The page.** Section 6's four views. Gate: the scenario visible. About one day.
4. **Release.** `docs/releasing.md` from calendar, a catalog line in the kernel's `gub/nex/shell.hoon` beside calendar's, version bump, ricsul's forge pull, the publish. Sneagan runs the ricsul steps.

Later, each with its own spec: the Talon triage client; cross-ship sharing of a body's subtree to the ship it belongs to, calendar-style; a `calendar` action kind that pokes the calendar desk app; body merge; fuzzy resolve.

## 12. Release and install

Orrery is a stock desk app. The source of truth is `nisfeb/orrery`, the publisher is `~ricsul-bilwyt`, and every other ship gets it from ricsul. Ricsul's forge polls the repo every 15 minutes; its desk pulls when `code/version.json` differs from its own; it republishes the version file and subscribers watching it sync on their own. A subscriber installs with the shell's `POST /desks/add` naming ricsul's desk, which asks consent for the roads in section 7.

The kernel needs one line, `(published our 'orrery' 'nisfeb/orrery' 'main')` beside calendar's in `gub/nex/shell.hoon`, delivered the kernel way: the mount, then `|commit %grubbery`. That and the mcp patch are the only kernel touches.

## 13. Not in v1

Cross-ship anything. The Talon client. Text evidence of any kind. Body merge. Fuzzy or embedding resolve. Stored indexes and a sweeper. The ship executing an action beyond holding it. A second owner on one ship. Editing bodies and observations by hand in the page.

## 14. Decisions recorded

- Event-sourced observations with a computed fold, over a typed record per kind (every new attribute would be a migration, and there would be no provenance) and over a triple store with a query language (the analyst would have to learn it, and a personal state does not need it).
- Same-ship only in v1. Sarah's state is what this ship knows about her. Observations carry `by` and `source`, which is what a share will need.
- Pointer-only evidence. The source id is enough to open the original in the client that has it.
- One writer, with callers answering from their own precomputation. Chosen for the single poke road the MCP tools need and for the shape two shipped apps proved.
- ISO 8601 UTC on the wire in both directions, because the readers and writers are language models and they handle it better than milliseconds.
- `at` ordering over `seen` ordering for the fold. Late-arriving evidence about the past must not overwrite the present.
