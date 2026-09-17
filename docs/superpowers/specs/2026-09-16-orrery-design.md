# Orrery: a model of the user's world, kept on their ship

Status: approved 2026-09-16. Amended the same day after product review: a ship on a body, a self-reference guard, action history with actors, push modes and an audit log, and cross-ship sharing and scoped client keys pulled into v1 ahead of the MCP tools and the page.

## 1. What this is

Orrery keeps a model of what is going on in one person's life: the people, places, things and situations around them, what is currently true about each, where each fact came from, and what the assistant proposes to do about it. It is a grubbery desk app in the nisfeb family, installed from `~ricsul-bilwyt` the way lattice, auspex and calendar are.

The ship holds the state and its history. It runs no AI. Clients do the thinking: a local model on the client (Talon, later) triages messages, mail and calendar events into observations and submits them. A larger model reads the state back and proposes actions, or files them straight to the todo list when policy allows. In the first release the analyst is Claude Code over the HTTP API, and then over MCP tools compiled into the desk, so the loop runs before any client code exists.

The name is the instrument: a mechanical model of bodies in motion, read to know where everything is now and where it was.

## 2. The three shapes

Everything orrery stores is one of three shapes. Everything else is a directory or a JSON grub.

- A **body** is something that exists: a person, a place, a thing, an org, a situation, or a note. It has a stable id, a kind, a name, aliases and, when it is a person or a thing with a ship, an @p. The user is the body `person/me`.
- An **observation** is one claim about one body: `subject.attr = value`, with when it became true, when it is expected to stop being true, how confident the asserter was, where it came from, and who asserted it. Observations are immutable. Current state is a fold over them.
- An **action** is something to do: a task, a note to the user, or a client-executed kind such as a message. It moves through proposed, approved, claimed, done, dismissed, failed. Tasks are actions, so the todo list is "approved tasks not yet done".

Extension points are deliberate and few: body kinds, attribute names, action kinds and source kinds are all open strings, and values are JSON. Adding a new kind of fact never changes a type, a marc, or a migration.

## 3. The model

### Bodies

A body id is `<kind>/<slug>`. A kind is lowercase ascii, digits and hyphens, at most 24 bytes. A slug is the same charset, at most 64 bytes. Examples: `person/sarah`, `thing/subaru`, `place/johns-machine-shop`, `situation/2026-09-16-breakdown`.

A body carries `kind`, `name` (at most 200 bytes), `aliases` (a set of at most 32 strings of at most 100 bytes each), `created` and an optional `ship`, the @p of the body when it has one. Aliases are the names and handles a triager may see in text: "Sarah", "the shop". The ship is identity, not state: resolve matches on it exactly, and a share is addressed by it (section 11). Everything else about a body is an observation.

`person/me` is created on first load with the name `me`, the aliases `me` and `I`, and `ship` set to our own @p. The user or a client renames it.

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
| `source` | `{"kind", "id"}` | where it came from: `talon-dm`, `mail`, `calendar`, `user`, `model`, `ship` for one mirrored from another ship, or any other kind. The id is opaque, at most 200 bytes, and is the only evidence kept. Never the text |
| `by` | string | who asserted it: `talon/triage`, `claude-code`, `user`. At most 64 bytes |
| `seen` | time | when the ship recorded it. Set by the ship |
| `status` | `live` or `retracted` | the only mutable field |

A `{"ref"}` value must be a well-formed body id other than the subject itself; it need not exist yet, because bodies can be deleted and observations mirrored from other ships (section 11) may name bodies this ship does not hold. A ref-valued attribute is a relation: `spouse`, `owner`, `location`, `employer`. There is no separate relation type, and nothing traverses relations: a ref is a value, `involved` is one hop, and actions point at bodies while bodies never point at actions, so a contradictory pair of facts is two entries in two timelines for the analyst to notice, never a loop. A future transitive query gets a hop limit and a visited set.

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
| `status` | enum | `proposed`, `approved`, `claimed`, `done`, `dismissed`, `failed` |
| `note` | string | why it was dismissed or failed, at most 500 bytes |
| `history` | list of `{at, status, by}` | every status the action has held, oldest first, with who set it: the proposer, `policy` for an automatic approval, the owner, or a client's identity |

Transitions: proposed to approved or dismissed; approved to claimed, done, failed or dismissed; claimed to done, failed, dismissed or claimed again. Failed is terminal in v1; propose again. An executor claims an approved action before it acts, which holds it for ten minutes against every other actor, so a re-claim inside the lease and a done or failed by anyone but the claimant are refused with `claimed by <claimant>`. A move answers before the writer applies it and carries the `by` it will store, so an executor confirms a claim by reading the action back and acts only when the last claimed step names it; two claims in the same instant both answer ok and the writer keeps the first. Every transition appends to `history`, so the audit questions "who approved this, and when" and "who is acting on it" are answered by the action itself. Under the owner cookie the actor is whatever the request says, `user` by default; under a scoped client key (section 11) the actor is the key's identity and cannot be faked.

A proposal whose `kind` and `title` match an open action (proposed, approved or claimed) returns the existing id instead of making a second one. Fuzzy duplicates are the analyst's job: it reads the open actions before proposing.

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

`policy.json` starts as `{"auto": ["task", "note"], "push": "proposed", "retention_days": 365}`. `push` is `proposed` (notify through `/sys/push` only when an action needs a human), `all` (every new action, filed ones included) or `none`; any other value behaves as `proposed`, so a typo never silences notifications. An auto-filed action is not an interruption; it is visibility, and visibility is the audit log's job: `/tr/log` keeps the last 500 writer outcomes, each with the op, whether it applied, why not, when, and the actor. `retention_days` bounds compaction: on each write to a body, its observations that are superseded, expired or retracted and older than `retention_days` by the later of when it was true and when the ship recorded it are culled. A live observation is never culled. Ageing a row by the later of the two keeps a fact recorded today about five years ago for the retention from today.

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
docs/                            this spec, releasing.md copied from calendar, keys.md, mcp.md, sharing.md, kernel/README.md
```

Repo `nisfeb/orrery`, branch `main`. The desk is hermetic: every lib and marc it uses is inside `code/`, checked by a copy of auspex's `scripts/code-closure.py`.

Phase 2 vendored eight more marcs beside those: `gall-poke`, `poke-ack`, `ships`, `weir`, `timer-set`, `timer-rest`, `timer-wake` and `usergroups/registry-action`.

## 5. The tree and the writer

```
/main.sig                          the writer: every mutation goes through it
/bodies/<kind>/<slug>/body         one grub per body                  [/orrery %body]   history on
/bodies/<kind>/<slug>/obs/<oid>    one grub per observation           [/orrery %obs]
/actions/<aid>                     one grub per action                [/orrery %action] history on
/schema.json  /policy.json         seeded once, edits survive         [/ %json]
/beacon/rev                        the change beacon                  [/ %json]
/tr/last                           the last writer outcome, as json   [/ %json]
/tr/log                            the last 500 outcomes, the audit log [/ %json]
/web.sig  /requests/<id>           binds /apps/orrery, one fiber per request
/tile.json /icon.svg /link.json /weir.json /orrery.html /orrery.js /orrery.css   replaced on every reload
```

Phase 2 added six paths to that tree: `/shares.json`, `/shares.sig`, `/share-offers.json`, `/ship-remotes.json`, `/sync.sig` and `/tr/inbox`, the ring of 500 ship-traffic outcomes. Phase 3 added a seventh, `/clients.json`, the minted keys as salted hashes.

Everything about a body sits under its own directory, so one deep peek reads a body and one shallow peek lists a kind. Files and subdirectories are separate maps in a ball, so `body` and `obs/` never collide.

`/bodies` and `/actions` are laid with retention on, so grubbery keeps a version per write of a body's name and aliases and of an action's status. Observations are immutable, so as-of reads never need that history. Every persistent path has a covering `%fall` row in `on-load`; the page, the icon and the two manifests are `%over` so a release replaces them.

**The writer.** `/main.sig` is one long-lived fiber, the shape lattice and auspex use: rise, then loop on take-poke, apply, bump, recurse. It takes `[/ %json]` pokes carrying one op: `observe`, `retract`, `act`, `set-action`, `upsert-body`, `delete-body`, `set-schema`, `set-policy`. It applies with soft makes and overwrites, bumps `/beacon/rev` once per op that changed the tree, compacts the touched bodies, and sends the push for a new action. It never crashes on input: every refusal is a clean branch that writes `/tr/last` (fiber code cannot run under `mule`), because a crashed writer eats the next poke.

Orrery keeps no stored index. That is why the callers can answer without a reply channel: a request fiber or a tool validates the op with the pure lib, computes every id it will report, pokes the writer, and answers from its own computation. The one inaccuracy is a race between two callers, which the writer's soft make turns into "already existed" and `/tr/last` records. A reply grub per request is the upgrade if late refusals ever matter.

The beacon is nested and bumps only on a change, for the reasons auspex recorded: a root grub does not stream, and a bump on a no-op is a free reload of every open client.

## 6. Surfaces

### HTTP, under `/apps/orrery/api`

The owner cookie (eyre's `authenticated` flag and `src` equal to `our`), or a minted key within its scope (section 11 phase 3), else 403. JSON in, JSON out. Times are ISO 8601 UTC in both directions.

| method and path | does |
|---|---|
| `GET /state?at=&kind=` | the state view |
| `GET /body/<kind>/<slug>?at=` | one body with its timeline |
| `GET /resolve?q=` | bodies whose name or alias matches, exact first then prefix, case-insensitive, at most 20 |
| `POST /observe` | `{"bodies": [...], "observations": [...]}`: bodies upserted first, then observations; per-item results |
| `POST /retract` | `{"id", "note"}` |
| `POST /bodies` | upsert one body |
| `DELETE /body/<kind>/<slug>` | cull the subtree. Refs to it elsewhere render as the bare id. Owner only |
| `POST /act` | propose; answers `{"id", "status"}`, status `approved` when policy says so |
| `GET /actions?status=open` | `open` by default, meaning proposed, approved and claimed; `all`; or one status |
| `POST /actions/<id>` | `{"status", "note"}`: a transition |
| `GET` and `PUT /schema`, `/policy` | the whole document. Owner only |
| `POST /clients` | mint a key; answers the row and the token once. Owner only |
| `GET /clients` | the keys with their scope, made and last used, never the secret. Owner only |
| `DELETE /clients/<id>` | revoke a key. Owner only |

Batch caps: 50 bodies and 200 observations per observe. A caller that needs more sends more requests.

Observe answers per item so an AI client can fix the one it got wrong:

```json
{"bodies": [{"id": "place/johns-machine-shop", "ok": true, "existing": false}],
 "observations": [{"id": "1758056400-a3f9c1d2", "ok": true, "existing": false},
                  {"ok": false, "error": "unknown subject thing/subaru"}]}
```

A write answer carries no `rev`: the writer applies after the answer leaves, so a rev read then is the one before the write. The state view carries the rev, as milliseconds since 1970, which a browser keeps exact.

Live updates: `/beacon/rev` streams through grubbery's keep-SSE the way lattice's and auspex's beacons do. A client that sees it move refetches what it shows.

### MCP tools, in `code/lib/tools`

Eight tools, each a `tool:tools` core, reads by absolute peek into the instance, writes by one poke road to `/main.sig`, the shape lattice's tools use. Parameters are the five MCP scalar types, so a batch arrives as an array parameter whose description states the object shape. File names are hyphenated and declared names are underscored, so `orrery-state.hoon` declares `orrery_state`, and a client reaches it under either spelling.

| tool | parameters |
|---|---|
| `orrery-state` | `at`, `kind` |
| `orrery-body` | `id`, `at` |
| `orrery-resolve` | `q` |
| `orrery-observe` | `bodies`, `observations`, `by` |
| `orrery-retract` | `id`, `note`, `by` |
| `orrery-act` | `kind`, `title`, `payload`, `about`, `due`, `proposed`, `by` |
| `orrery-actions` | `status` to list; `id` and `status` to transition, `note` and `by` |
| `orrery-schema` | none to read; `schema` to replace |

**A gap in the kernel, found while writing this.** The mcp nexus discovers app tools by scanning `/apps/<app>/desk/code/lib/tools`, which predates desks living under the shell at `/apps/shell.shell/desks/<name>.desk/desk/code`. Lattice's tools are vendored into the kernel's own bundle for that reason. Two things follow. Any tool is callable today by location: `call_tool` with `/apps/shell.shell/desks/orrery.desk/desk/code/lib/tools/orrery-state` works without discovery, because the tools child nexus resolves an absolute source path directly, and `+await-tool` in `nex/mcp.hoon` has no callers and is not on the call path. The durable fix is a patch to three kernel files: `nex/mcp.hoon` in two hunks (`+get-app-mcp-paths` walks the shell's desks, and the discovery loop names a desk's tools `apps/<desk>` so two desks never collide) and the two walks in the tool bundle's `call-tool.hoon` and `list-tools.hoon`; it lives in `docs/kernel`, was rehearsed on `~wex` on 2026-09-17, and reaches production only through the dist branch. `tools/list` stays the kernel's three-tool protocol allowlist by design, so discovery shows instead in the tools tree and in `list_tools`. Calendar's and auspex's tools could then leave the kernel too. Phase 4 confirms the gap on `~wex` before the patch. Grants are not the blocker there: the mcp instance on `~wex` already holds peek, poke and make on the whole ball, which is also the honest answer to what an MCP analyst can reach today.

### Where the analyst runs, and what it can see

In v1 the analyst runs off the ship: Claude Code, later Talon, holding the owner's credentials for orrery's API. Over the HTTP API that is everything orrery holds and nothing else on the ship. Over the ship's MCP server it is whatever that server is granted, which today is the whole ball. Two mechanisms narrow that, and both are in v1. A scoped client key (section 11, phase 3) is the HTTP answer for a client that does not run a ship: a token bound to an identity and a scope. A share (section 11, phase 2) is the Urbit answer for an agent that does: an agent ship is a peer with a share, and it sees exactly the bodies shared with it. Which grubs reach which model is therefore a question of which key or which peer the model sits behind.

### The page, at `/apps/orrery`

One document, css inlined, one script, served no-cache, built the way calendar's is. Four views: bodies grouped by kind; a body with its attribute table, its situations, its open actions and its timeline with source pointers and a retract button; the actions inbox with approve, dismiss, done and failed; settings with the schema and the policy as editable JSON. It reloads on the raw beacon stream, read the way lattice's page reads it. It is a reader with buttons, not an editor: creating bodies and observations by hand is a v2 question.

## 7. The ask

`weir.json` declares what the instance reaches outside its own tree, in words for the person granting it:

- poke `/sys/bowl.sig`: read the time and our ship
- poke `/sys/eyre/`: bind `/apps/orrery` and answer requests
- poke `/sys/push/`: notify you when the assistant proposes or files an action. Refuse this and proposals wait silently in the inbox
- peek `/sys/link/`: find where this app is installed, so the page can address its own writer

No `/sys/ames/*`, no iris, no behn. Nothing in v1 is ship-to-ship, nothing fetches, and there is no ticker: expiry is computed on read and compaction runs on write.

Phase 2 grew the ask by the sharing roads, which is why `/sys/ames/*` and `/sys/behn/` are in it now; section 11 lists them and `weir.json` says what each one does.

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

**The analyst** reads the state, sees an open situation with a car at a shop and no action about it, and proposes `{"kind": "task", "title": "Call John's Machine Shop about the Subaru", "about": ["thing/subaru", "place/johns-machine-shop"], "due": "2026-09-17T13:00Z"}`. Assert: the answer is `approved` because policy auto-approves tasks; the open actions list has it; a second identical proposal answers the same id; the act lands in `/tr/last` and the push attempt in `/tr/log`.

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
- **Cross-ship gate**, phase 2, `scripts/ship-share-matrix.py` with `~wex` as host and `~feb` as peer: a body shared read-only arrives on the peer, a new observation on the host reaches the peer within one poll, an edit-mode observation from the peer lands on the host with the peer as actor, a revoke stops the flow. A read from the other ship, never a before-and-after on one.
- **Scoped keys gate**, phase 3, `scripts/key-matrix.py`: a key scoped to things and tasks sees no people, cannot observe a person, can file a task, cannot propose a message, and answers 403 once revoked.
- **MCP gate**, phase 4, `scripts/mcp-matrix.py` against `~wex`: a slice of section 8 through the eight tools, each called by absolute path, with every read cross-checked whole against the HTTP API's answer for the same read. `tools/list` is not the check: it stays the kernel's three-tool protocol allowlist by design, so discovery shows in `list_tools` and in the tools tree instead.
- **Page**, phase 4, `scripts/page-smoke.py` and `scripts/page-test.js`: the page, its script and its style are served to the owner and refused without the cookie, the beacon stream answers with a rev, and the render functions run under node against fixtures. Seeing the scenario in all four views is the owner's own pass, step 10 of `docs/releasing.md` section 8, before the ricsul publish.
- Never against `~ricsul-bilwyt` until all of the above pass.

## 11. Phases

Each phase is installable and useful on its own. The order changed on 2026-09-16: multiplayer is the reason to be on Urbit at all, so sharing comes before the tools and the page.

1. **Desk and model.** The repo laid out as section 4, `lib/orrery.hoon` with its tests, the writer, the HTTP API, install on `~wex`, then the amendments of this revision (the ship on a body, the self-reference guard, action history, push modes, the audit log). Gate: the unit tests and the HTTP matrix green. About two and a half days.
2. **Cross-ship sharing.** The minimal protocol below. Gate: the two-ship matrix. About three days.
3. **Scoped client keys.** Below. Gate: the additions to the HTTP matrix. About one day.
4. **MCP tools, push, and the page.** The eight tools, the discovery check and the kernel patch if the gap is confirmed, section 6's four views. Gates: the MCP scenario and the scenario visible. About two days.
5. **Release.** `docs/releasing.md` from calendar, a catalog line in the kernel's `gub/nex/shell.hoon` beside calendar's, version bump, ricsul's forge pull, the publish. Sneagan runs the ricsul steps.

Later, each with its own spec: the Talon triage client; calendar and auspex pushing structural facts into orrery on the ship, one poke road each; a `calendar` action kind that pokes the calendar desk app; body merge; fuzzy resolve; full-text search over values (lattice's term index is the reusable piece).

### Phase 2: cross-ship sharing, the minimal protocol

The unit shared is a body: its `body` grub and its observations. Calendar's ship sharing is the template for every mechanism here, and its code is the starting point.

- **Shares.** `shares.json` on the host maps a body id to the ships it is shared with and a mode, `read` or `edit`. Owner routes: `POST /api/share {"id", "ship", "mode"}`, `DELETE /api/share/<id>/<ship>`, `GET /api/shares`. Sharing registers a peek grant for that ship on the body's directory through the usergroup registry, one group per shared body, exactly as calendar keeps one group per shared calendar.
- **Offer and accept.** Sharing pokes the peer's orrery inbox, `shares.sig`, which rides on the public usergroup so any ship may offer. The offer carries the host, the body id, the body's ship if it has one, the mode, and the host's instance path, since a desk app's path differs per install. The peer stores offers in `share-offers.json`; the owner accepts with `POST /api/accept {"host", "id"}`, which writes a row to `ship-remotes.json`. An offer for a share already accepted narrows the mode at once; a wider mode waits for a new accept, and accepting an already accepted share keeps what was pushed.
- **The mapping.** An accepted body lands locally by its ship: a local body already carrying the offered ship is the target, else a body whose ship is our own @p lands on `person/me`, the host's own `person/me` lands on `person/<host>` and any other body lands under its own id. A target that does not exist yet is created with the name and ship the offer names; one that does keeps its own. So what Jackson's ship knows about Sarah becomes, on Sarah's ship, third-party observations on her own `person/me`, and Jackson's `person/me` becomes her `person/jackson`.
- **Mirroring.** A follower fiber per accepted share polls the host's body directory over `/sys/ames/ships/<host>/root/...` every five minutes on a behn tick and on demand. Each of the host's own observations, not ones the host itself mirrored from a third ship, is written locally with `source = {"kind": "ship", "id": "<host>/<oid>"}`, `by = "<host>"` and a local `seen`; the content hash makes a re-poll a no-op. Retracting a mirrored observation locally is allowed and local; the next poll does not resurrect it because the retracted grub stays.
- **Edits back.** In `edit` mode the peer may poke the host's inbox with observations about the shared body. The host applies them through the writer with `by` set to the peer's @p from the transport, never from the payload, and refuses any subject outside the share.
- **Revoke.** Removing a ship from `shares.json` drops the grant and pokes the peer, which removes its offer or accepted row for the body. If the peer cannot be reached, its next poll on that body fails instead and the row's `error` explains why.
- **The ask grows** by `/sys/gall/` (poke), `/sys/ames/ships/` (peek), `/sys/ames/registry` (poke), `/sys/ames/usergroups/` (peek, make) and `/sys/behn/` (the poll timer), each with calendar's wording. A ship that refuses them keeps everything else.
- **Not in the minimal version:** sharing actions, sharing a situation's participants transitively, conflict resolution beyond "the host's copy is the host's and the mirror is a mirror", and any UI.

### Phase 3: scoped client keys

- `clients.json` holds one row per client: a name, an id, a salted hash of the secret, the identity it acts as (`by`), a scope, when it was minted and last used. The owner mints one with `POST /api/clients {"name", "by", "scope"}` and sees the token once; `DELETE /api/clients/<id>` revokes.
- A scope is `{"kinds": [...], "actions": [...], "write": true|false}`. `kinds` are the body kinds the client may read and, with `write`, observe; `actions` the action kinds it may propose; `write` also covers approving, dismissing and completing.
- A request carrying `Authorization: Bearer <token>` acts under that scope: the state, body and resolve views omit bodies outside `kinds`, a body outside them is a 404, an observation on one is a 403, a proposal of a kind outside `actions` is a 403, and `by` is forced to the key's identity so the audit trail is honest.
- `policy.json` gains `sensitive`, a list of attribute names only the owner cookie ever sees over HTTP; a key never receives them, whatever its scope. A share (phase 2) is a grant on a directory and carries the body whole, sensitive attributes included, so the one place sharing honors the list is the push back to a host, which drops them. A client that keeps a todo list gets `{"kinds": [], "actions": ["task"], "write": true}` and never learns a health attribute exists.
- The owner cookie keeps full access. Keys are checked in-app, like calendar's CalDAV passwords, never by eyre.

## 12. Release and install

Orrery is a stock desk app. The source of truth is `nisfeb/orrery`, the publisher is `~ricsul-bilwyt`, and every other ship gets it from ricsul. Ricsul's forge polls the repo every 15 minutes; its desk pulls when `code/version.json` differs from its own; it republishes the version file and subscribers watching it sync on their own. A subscriber installs with the shell's `POST /desks/add` naming ricsul's desk, which asks consent for the roads in section 7.

The kernel needs one line, `(published our 'orrery' 'nisfeb/orrery' 'main')` beside calendar's in `gub/nex/shell.hoon`, delivered the kernel way: the mount, then `|commit %grubbery`. That and the mcp patch are the only kernel touches.

## 13. Not in v1

The Talon client. Calendar and auspex pushing into orrery. Text evidence of any kind. Body merge. Fuzzy or embedding resolve. Full-text search over values. Stored indexes and a sweeper. Transitive relation queries. The ship executing an action beyond holding it. A second owner on one ship. Editing bodies and observations by hand in the page. Sharing actions across ships.

## 14. Decisions recorded

- Event-sourced observations with a computed fold, over a typed record per kind (every new attribute would be a migration, and there would be no provenance) and over a triple store with a query language (the analyst would have to learn it, and a personal state does not need it).
- Same-ship only in v1. Sarah's state is what this ship knows about her. Observations carry `by` and `source`, which is what a share will need.
- Pointer-only evidence. The source id is enough to open the original in the client that has it.
- One writer, with callers answering from their own precomputation. Chosen for the single poke road the MCP tools need and for the shape two shipped apps proved.
- ISO 8601 UTC on the wire in both directions, because the readers and writers are language models and they handle it better than milliseconds.
- `at` ordering over `seen` ordering for the fold. Late-arriving evidence about the past must not overwrite the present.
- 2026-09-16, after product review: cross-ship sharing and scoped keys move into v1 ahead of the MCP tools and the page, because multiplayer and "which data reaches which model" are the product, and the tools and the page are cheap once the data side is right. The ship on a body is what makes a share addressable, so it landed in phase 1.
- Nothing indexed in v1, by design: no stored index means no index races and no migration bombs. The tree is the index, and compaction keeps timelines short. The measured upgrade path is a cached attrs snapshot per body, then a reverse-ref index.
- An @p on a body is identity, not an observation. Identity is what routing keys on; state is what changes.
