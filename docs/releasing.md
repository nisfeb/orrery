# Releasing orrery: what makes the publisher update, and what makes its subscribers update

Orrery is a **stock desk app**: the source of truth is this git repo, one ship publishes it, and every other ship gets it from that publisher. Two separate mechanisms move a change along that path, and they fail in different ways. This file is the same in nisfeb/lattice, nisfeb/auspex and nisfeb/calendar, because the mechanism is identical for all four and the thing that costs hours is not knowing which half you are looking at.

Written 2026-09-15 from the grubbery kernel source (`gub/nex/desk.hoon`) and from failures measured that day on a publisher, a subscriber and a dev ship. Line references are to grubbery's `desk/gub/nex/desk.hoon`.

## The short version

```
you: git push  (ref main)
  |
  |  the publisher's forge polls the remote every 15 min  (config.json "poll": 15)
  v
the publisher's forge repo    /apps/forge.git_forge/repos/orrery.git_repo/data/tree/code
  |
  |  the publisher's orrery.desk watches that tree's code/version.json
  |  and pulls when it DIFFERS from its own root version.json
  v
the publisher's desk          /apps/shell.shell/desks/orrery.desk/desk/code
  |
  |  the publisher REPUBLISHES the version file; subscribers watch that
  v
every subscriber's desk       source.json -> <publisher>/apps/shell.shell/desks/orrery.desk/desk/code
```

**The single thing that makes anything update is `code/version.json` changing.** Not a new commit, not changed code: the version number. Everything below is detail on that one fact.

## 1. What makes the publisher update

The publisher's forge repo tracks this repo. Its config:

```json
{"token":"","ref":"main","repo":"nisfeb/orrery","poll":15}
```

So a `git push` to `main` reaches the publisher **on its own within about 15 minutes**. There is no staging state for a desk app: pushing is deploying, on a timer.

To make it immediate instead of waiting for the poll, with the publisher's owner cookie:

```sh
POST $SHIP/grubbery/forge/api/run
     {"repo":"orrery.git_repo","command":"pull"}
```

It answers `ok`, which means the forge accepted the command, **not** that the desk has rebuilt. The pull checks the repo out into the forge tree; the desk then has to notice.

The publisher's orrery desk points at that tree:

```json
{"code":"/apps/forge.git_forge/repos/orrery.git_repo/data/tree/code"}
```

A local path, not a ship. The publisher reads its own forge. (Subscribers point at the publisher over ames instead; see section 2.)

## 2. What makes the subscribers update

Every subscriber's orrery desk has a `source.json` naming the publisher:

```json
{"code":"<publisher>/apps/shell.shell/desks/orrery.desk/desk/code"}
```

The desk nexus keeps a subscription on the source's `code/version.json` (desk.hoon:163-186). On a `%news` for that file it runs `do-snapshot` then `sync-release`. **No user action is required**: nobody has to press Fetch Latest, and no consent prompt appears unless the release adds a road to `ask.json`.

The gate is exactly this (`+source-behind`):

```hoon
(pure:m !=(src-ver own))
```

An inequality between the source's `code/version.json` and the desk's own root `version.json`. Nothing else is compared: not file hashes, not commit ids, not timestamps.

`sync-release` then mirrors the code tree and **republishes the version file locally**, with the kernel's own comment explaining why:

> mirror the source's version file locally, under its own name, so followers of THIS desk watch our republished version

That is the relay hop. It is why a subscriber can itself be a publisher.

## 3. Therefore: bump `code/version.json` on every release

| what you did | what happens |
|---|---|
| changed code, bumped version | the publisher syncs, subscribers sync. Correct. |
| changed code, **forgot** the bump | **nothing propagates.** The publisher's forge has your commit; no desk ever pulls it. Everything looks fine and nothing shipped. |
| bumped version, no code change | the version file syncs and nothing else does. `sync-dir` is content-addressed: only real changes write, so no nexus rebuilds. |

The second row is the common mistake and it is silent. The third row matters when you are trying to force a rebuild: a version-only bump will not do it.

## 4. Verifying a release actually landed

Check all four, in this order, on the ship in question (`$SHIP`, with its owner cookie). Each separates a different failure.

```sh
# 1. did the forge fetch? (the publisher only)
GET $SHIP/grubbery/ball/apps/forge.git_forge/repos/orrery.git_repo/data/tree/code/version.json?raw=1

# 2. did the desk mirror it?
GET $SHIP/grubbery/ball/apps/shell.shell/desks/orrery.desk/desk/code/version.json?raw=1
GET $SHIP/grubbery/ball/apps/shell.shell/desks/orrery.desk/version.json?raw=1

# 3. did the instance rebuild, or is it BANGed?
GET $SHIP/grubbery/ball/apps/shell.shell/desks/orrery.desk/desk/data/orrery.orrery_app?info=1
#    bang: null  = healthy.  bang: "no built nexus %orrery--app ..." = dead.

# 4. does the route answer?
GET $SHIP/apps/orrery        # fast 200/403 = alive.  hang = dead instance holding the route.
```

A version number is not proof. **The instance's `bang` is the proof**, and the route is the proof a user cares about.

## 5. The failure modes, all measured

### 5a. Version matches, code tree empty: wedged for ever

Measured on a subscriber, 2026-09-15. Its calendar desk read `{"version": 15}` at the root, the publisher published 15, and `code/` was **empty**: zero children. `source-behind` compared 15 to 15, answered "not behind", and never synced again. The desk page reported itself up to date. `/apps/orrery` hung for 30 seconds on every request.

The version gate is the trap: it suppresses the only thing that would refill the tree. The escape is the unconditional pull, which has no version gate:

```sh
POST $SHIP/grubbery/desk/orrery/fetch-latest
```

(`+do-fetch`, desk.hoon: *"pull the source's current code now, unconditionally (no version gate)"*. The same thing runs from a `{"action":"fetch"}` poke at the desk's `main.sig`.)

### 5b. A BANGed instance is not healed by a successful sync

Same ship, same incident. After `fetch-latest` refilled the tree, `/nex/orrery/app.hoon` compiled cleanly in 11.8s, and the instance stayed BANGed. `reload-changed-nexuses` ran for 28ms and never visited it, because a nexus that never built has no recorded refs for a changed-refs walk to follow.

It came back only when the instance was reloaded explicitly. Over HTTP, that is a form-encoded POST to the instance's own explorer URL:

```sh
POST $SHIP/grubbery/ball/apps/shell.shell/desks/orrery.desk/desk/data/orrery.orrery_app
     action=reload-nexus
```

So: **a clean compile does not imply a live app.** Check the bang.

### 5c. A neck-less `/desk/code` never compiles anything

A `/desk/code` that was created as a plain directory, by an older kernel, or by hand, has no `[/ %code]` neck, and a dir without that neck is not a code namespace, so grubbery never runs `build-code` over it. Files land with the right marks and nothing compiles them. The desk page says "nothing to pull" while the app is dead.

`+ensure-code-nexus` repairs it. It used to run only when the desk nexus rose, which a subscriber does not do by itself; since 2026-09-15 it also runs from `sync-release`, so an arriving release repairs it. Check the neck with:

```sh
GET $SHIP/grubbery/ball/apps/shell.shell/desks/orrery.desk/desk?info=1
#    "code" child should have  neck: "/code"
```

### 5d. Symptom shapes

| symptom | usual cause |
|---|---|
| route **hangs** (no response, times out) | dead instance still holding the eyre binding |
| route **404s** | no instance bound at all |
| route **403s fast** | healthy; that is just unauthenticated |
| desk says up to date, app dead | 5a (empty tree) or 5c (neck-less dir) |

## 6. Desk apps and the kernel are delivered differently

Do not mix these up. Calendar, lattice, auspex and orrery are **desk apps**. Grubbery itself is the **kernel**.

| | desk app (calendar / lattice / auspex / orrery) | kernel (grubbery) |
|---|---|---|
| source of truth | this git repo | nisfeb/grubbery branch |
| how it reaches the publisher | `git push`, then forge poll or forge pull | copy into the publisher's clay mount, then `\|commit %grubbery` in the dojo |
| how it reaches subscribers | version bump, automatically | kiln desk sync, automatically |
| release unit | `code/version.json` | a clay commit |

Two notes on the kernel side, both learned the hard way:

- Touching `lib/*.hoon` or `app/grubbery.hoon` bumps the **gall agent**: the ship stops answering HTTP for minutes. Touching `gub/nex/*.hoon` only rebuilds a nexus, which is seconds.
- A `\|commit` that prints only `>=` with no rebuild means clay saw no change. That usually means it was already committed, not that the commit failed.

## 7. Testing before you ship

Test on a dev ship, a fake one if you have it, never on the publisher. Writing into a desk's code tree there compiles **immediately**, with no commit, which is the fast loop:

```sh
POST $SHIP/grubbery/ball/apps/shell.shell/desks/orrery.desk/desk/code/nex/orrery/app.hoon
     action=write-text  content=<the file>
```

Then read the instance's `?info=1`: `bang: null` means it compiled, and a non-null bang **carries the compile error with line and column**. That is about a minute per iteration. A file that does not exist yet needs `action=create-file&filename=<name>` first. `write-text` 404s on a missing file.

A `write-text` edit is not put back by a forge pull, because the version gate sees the same number on both sides and syncs nothing; the restore is another `write-text` of the committed file, or `fetch-latest`.

Fake ships derive every keypair from the `@p`, so anything key-dependent behaves differently there than on a real ship. Verify crypto paths on a real ship, not only on a fake one.

## 8. Orrery's release checklist

`$SHIP` and `$JAR` are the dev ship's web address and its owner cookie jar; `$SHIP2` and `$JAR2` a second ship for the sharing gate.

1. `code/version.json` bumped, the number one higher than the last release.
2. `python3 scripts/code-closure.py code` reports nothing missing.
3. `cmp code/lib/tools.hoon <grubbery checkout>/desk/gub/lib/tools.hoon` prints nothing, against the grubbery kernel checkout. The vendored tool types must equal the kernel's or every tool call breaks.
4. `python3 scripts/prompt-drift.py <orrery-utils checkout>/common` exits 0: the prompt cords in the lib equal the shared prompt files.
5. Unit tests green on a ship whose grubbery desk holds the lib and the test files: `-test /=grubbery=/tests/lib/orrery ~` and `-test /=grubbery=/tests/lib/generator ~`.
6. `node scripts/page-test.js` passes.
7. `python3 scripts/api-matrix.py $SHIP $JAR [~ship]` prints `ALL OK`, twice in a row; the third argument is the dev ship's own name, `~wex` unless given, so the mail check's letter lands in its own inbox. Run it first, because it deletes the bodies the sharing gate shares.
8. `python3 scripts/key-matrix.py $SHIP $JAR` prints `ALL OK`.
9. `python3 scripts/mcp-matrix.py $SHIP $JAR` prints `ALL OK`.
10. `python3 scripts/page-smoke.py $SHIP $JAR` prints `ALL OK`.
11. `python3 scripts/ship-share-matrix.py $SHIP $JAR $SHIP2 $JAR2` prints `ALL OK`.
12. Open `/apps/orrery` on the dev ship in a browser with the owner cookie: the views render, a retract and a move take effect, a settings save round-trips, and a write from a second client refreshes the page through the beacon.
13. `git push origin main`, then on the dev ship's forge: `POST /grubbery/forge/api/run {"repo":"orrery.git_repo","command":"pull"}`, and within a minute the desk's root `version.json` reads the new number and the instance's `bang` is `null`.
14. The publisher's steps: the forge pull (or the poll), the four reads of section 4, and, when the release added a road to the ask, the consent on `/apps/grubbery/permits` followed by a reload of the instance. A release that changes the starter schema or policy in the lib changes nothing on a ship that already has one: those files are seeded once, so a changed note is merged into the stored document by hand through `PUT /api/schema` or `PUT /api/policy`.

A release that raises the consent prompt leaves the new roads refused until the owner approves them, and whatever needed them stays off. Read `weir-json` in `code/nex/orrery/app.hoon` before the bump and say in the release note which lines are new.

### Version 59's owner steps

None. A task adopted from a todo the owner typed by hand is no longer pushed as "Orrery filed" (it read as the ship proposing the owner's own words). `POST /api/read` takes text a client hands the ship to read (the browser extension's page, a note), open to a key with `write`, and the read fiber runs it through the reader's pipeline like a message, the page as every fact's source; settings on the Read card (`/api/read/settings`, on by default, the mail reader's shape), record at `/api/read/last`. No new road.

### Version 58's owner steps

None on a ship that has set its cards; a fresh ship is on by default now. The generator, the Telegram reader, the chat reader (every DM until some are picked; channels only when picked), the mail reader and DMs from the ship all read on unless the owner turns them off, so orrery is as useful as the ship's desks and keys allow from the first hour (a reader without its key or desk notes so and waits). The Bodies view is a connection graph in three dimensions with a pane beside it: drag to turn, wheel to zoom, click a body or a line between two, find by name, and past situations on request.

### Version 57's owner steps

A second kernel marc: a `message` via `chat` whose payload names a `channel` (a nest such as `chat/~host/general`) is posted there through `%channels`, and the kernel checks the noun with `gub/mar/clay/groups/channel/action-2.hoon` (grubbery branch `dist/single-release`); a kernel without it crashes on the poke the way the DM one did, so keep `send_dms` off until it lands, or post to no channel. Also: a sender not in the owner's Tlon contact book stays a stranger to the mail reader instead of becoming a person body; a mail auspex rejects (its trail's last entry) fails the action with auspex's reason instead of reading done; `GET /version` answers the desk's version to any key; `GET /chat/lists` gives the page both chat lists in one pass; the calendar seen map drops occurrences older than sixty days.

### Version 56's owner steps

None. A thread's meta is read by its first three fields (version, read, archived), whatever version auspex writes, so auspex's coming `%3` meta (a `folded` set) lands in either order with this.

### Version 55's owner steps

None. Three adjustments for auspex 14: a thread's meta is read in its `%2` shape (else `%1`), so archived threads are left alone again; a ship that writes the owner and has no person body is made one (`person/<ship>`, named by its ship, the ship on the record), so its mail is read instead of counted as a stranger's; and a reply to the brief counts only when the message it answers is the ship's own brief, word for word, so a reply to a client's brief for the same day never moves the ship's tags.

### Version 54's owner steps

None. Auspex version 14 takes only the five-field `%send`, so the seven-field poke is gone; a ship whose auspex is older than 14 sends no mail from orrery until it is updated.

### Version 53's owner steps

None. A message by mail or chat finds the person's ship on the body's record too, not only in a `ship` attribute; 52 planned nothing for a person whose ship is on the record (which is where the page and the chat reader keep it).

### Version 52's owner steps

The consent prompt is raised: the ask gains a peek of the auspex desk (`/apps/shell.shell/desks/auspex.desk/`, to read the mail) and the `/sys/gall/` line now also says it sends an approved message as a Tlon DM. Approve on `/apps/grubbery/permits`, then reload the instance. Then on the Mail card turn the reader on; the first pass looks back `backfill_hours`. The brief goes at seven on `person/me`'s timezone from the next morning; `POST /api/brief/wake` sends one now. A `message` via `chat` is sent by the ship only with `send_dms` on (the Chat card), and only once the kernel carries `gub/mar/clay/groups/chat/dm/action-2.hoon` (grubbery branch `dist/single-release`, commit "a typed marc for poking %chat with a DM"): a kernel without it crashes on the poke (`marc-not-found`) and the executor stands at that dart until the instance reloads, so leave the switch off until the kernel lands and keep the client sending chat. Switch the client's mail reader and brief off once the ship's are on. Auspex is changing its `%send` action from seven fields to five: every mail the executor or the brief sends is poked in both layouts, so exactly one lands on either auspex and the other shows as a `malformed action` reject in auspex's trail; drop the seven-field poke in `poke-auspex` once every ship's auspex takes five. (Version 52 also found that no executor mail had landed on feb since its auspex changed layout, while the action read `done`: auspex's refusal is silent to the poker.)

### Version 51's owner steps

None. An activity whose cadence the ship holds at another word than the calendar's rule gives is corrected on the next pass, dated now, whatever the seen map remembers; 50 only dated a re-saying now and the twenty-four `rrule` cadences 47 wrote had no re-saying due. No new road.

### Version 50's owner steps

None. A series whose content is said again (its cadence, schedule, people or place moved) is dated now, so the new saying wins the fold; 49's corrected cadences were dated at the last occurrence and lost to 47's rows. No new road.

### Version 49's owner steps

None. An imported RRULE's frequency is the activity's cadence (`weekly` for `FREQ=WEEKLY;BYDAY=TU`) where 48 wrote `rrule`; the next pass re-says the content of every such activity. No new road.

### Version 48's owner steps

None. Version 48 fixes two things: the calendar events reader takes when each event happens from the calendar's own order cache (peeked under the same desk, no new road), so imported RRULEs and every other rule kind the calendar knows are read, where 47 knew six and wrote a bare `rrule` cadence for the rest; and grounding keeps the facts about a body the same batch creates when a distinctive word of its name is in the message, keeps a ref to the message's author, and no longer holds a time value to being quoted (nisfeb/orrery#1). The reader's record loses its `unknown` list. Activities 47 wrote with cadence `rrule` are corrected by the next pass, since their content is re-said when it changes.

### Version 47's owner steps

None. Version 47 reads the calendar's events into situations and activities on the ship, inside the executor's pass, the way a phone client's calendar pipe did: switch that pipe off in the client once the version is installed, or every event is written twice. Bodies the client already wrote are found by the uid on their rows' source and by the title, so nothing is migrated. The record is `GET /api/calendar/last` and the Executor card. No new road: the executor already reads the calendar's store, and the order index it now reads too is under the same desk.

### Version 46's owner steps

None. Version 46 reads a chat's new messages as one run: the Telegram drain sifts every waiting update first and hands the analyst one run per chat, and the chat reader does the same per conversation per pass, so a message further down that settles an earlier one is seen before anything is proposed, and a run's facts land in one write. The record's `read_today` counts messages, not runs. No new road.

### Version 45's owner steps

None. Version 45 adds `GET /api/chat/peek?since=<iso>`, the owner's way to ask what the reader's scries hold for any window without reading it, so a quiet day can be told from a reader that sees nothing. No new road.

### Version 43's owner steps

None. Version 43 makes a missing scry answer legible: the chat record's notes now say by name when the chat or channels agent gave no answer, an answer that is not JSON, or a JSON null, which is what an older groups desk answers for a scry it lacks; the two list routes say the same in their note. Version 44 adds two counts to the record and the card, `unpicked` and `own`, so a pass that read nothing says whether the conversations that changed were ones the owner did not pick, or the owner's own words left unread. No new road.

### Version 42's owner steps

None. Version 42 is the Chat card and the settings routes after the owner's first use: the picked DMs and channels are lists with a filtered picker that shows a DM's nickname from the contact book and a channel's group and channel titles (two new scries on the same road, `/gx/contacts/v1/book/json` and `/gx/groups/v2/light/groups/json`); every stamp on the page is in the reader's local time; a settings `PUT` answers the document as stored once the write has landed, so a client that read straight back no longer sees its save as lost; and the chat record says how many conversations and messages the scries answered. No new road.

### Version 41's owner steps

None. Version 41 is the third review round on the chat reader: a scry the groups desk never answers ends on a thirty-second timer instead of holding the reader, a hold by the daily cap resumes at the first held message, a wild poll or backfill number is clamped, one agent short does not read as the road refused, a null on any settings key puts the default back (the card sends one for a blank number), and the bodies are loaded once per pass rather than once per message. No new road.

### Version 40's owner steps

None. Version 40 fixes the chat reader's first release from the review of version 39: a message the daily cap held is found again the next day, a writ delivered late is read, a DM typed with a capital or without its sig is matched, a blank number on the Chat card leaves the ship's default in place, and the record of a Telegram token reset survives a model outage. No new road.

### Version 39's owner steps

Version 39 adds one road, `/sys/scry/`, so the consent prompt comes back: approve it on `/apps/grubbery/permits` and reload the instance. Then on the Chat card under Settings pick the DMs and the channels the ship should read, add a people row for any sender who is not a person body with a ship, and turn it on; the first pass looks back 24 hours. The phone client's chat reader is then switched off, since both write the same source ids and a message must be triaged once.

### Version 38's owner steps

None. Version 38 opens `POST` and `GET /api/telegram/webhook` to a key with `write` beside the owner, so a client that walks the owner through the Telegram setup can register the webhook and read back what Telegram holds; it raises no consent prompt and adds no road. The tlon reader the 2026-09-21 spec calls version 38 becomes 39.

### Version 37's owner steps

Version 37 raises no consent prompt: a cancel rides the calendar roads version 34 already asked for. Two things belong to the owner, in this order.

1. The calendar desk reaches version 17 or later first, on every ship that will run orrery 37. Skipping one occurrence of a repeat is the `skip-at {id, start_ms}` poke that release adds, and an older calendar takes a poke it does not know and does nothing with it, so the action would read `done` with `that occurrence skipped` while the occurrence stayed on the calendar. Cancelling a one-off is `del-event` and works against any calendar. Push the calendar repo before the pull: the two commits that carry this sit unpushed otherwise, and nothing reaches any ship. Version 17 is what lets the ship see that a skip took, so on 16 a skip reports `that occurrence skipped` without proof.
2. After the pull, merge the changed schema notes into the ship's stored document. The starter schema in the lib is only a fall for a ship that has none, so a ship that already runs orrery keeps the schema it was seeded with: read it with `GET /api/schema`, change the keys below, and write the whole thing back with `PUT /api/schema`, the bare document and not a patch. Word for word:
   - `kinds.activity.attrs` gains `skipped`. This one is not cosmetic: the writer drops an observation whose attribute is not in that list, with `not an attribute of activity`, so until it is there every cancelled occurrence a reader writes is thrown away while the calendar action half still works, which looks like a half-broken feature. On a ship whose stored schema has no `kinds.activity` block at all, copying the whole block also starts enforcing the attribute list for activities for the first time, so a client with its own activity vocabulary loses those rows from that moment (a stored schema seeded before the activity kind existed has no `kinds.activity` at all, in which case copy the whole block from `starter-schema` in `code/lib/orrery.hoon`).
   - `kinds.activity.notes.status`: `active, or cancelled when the whole series has ended; one occurrence that is off goes under skipped`
   - `kinds.activity.notes.skipped`: `the start of one occurrence that is off, ISO 8601 UTC, one row per occurrence; the activity itself stays active`
   - `payloads.calendar.mode`: `optional: add (the default) or cancel`
   - `payloads.calendar.event`: `optional: the calendar id of the event to cancel`
   - `multi` gains `skipped`, beside `participants`. Multi-valued is the one thing the ship enforces and it reads that list from the stored document, so until `skipped` is there a second cancelled occurrence supersedes the first instead of standing beside it.
