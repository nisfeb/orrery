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
7. `python3 scripts/api-matrix.py $SHIP $JAR` prints `ALL OK`, twice in a row. Run it first, because it deletes the bodies the sharing gate shares.
8. `python3 scripts/key-matrix.py $SHIP $JAR` prints `ALL OK`.
9. `python3 scripts/mcp-matrix.py $SHIP $JAR` prints `ALL OK`.
10. `python3 scripts/page-smoke.py $SHIP $JAR` prints `ALL OK`.
11. `python3 scripts/ship-share-matrix.py $SHIP $JAR $SHIP2 $JAR2` prints `ALL OK`.
12. Open `/apps/orrery` on the dev ship in a browser with the owner cookie: the views render, a retract and a move take effect, a settings save round-trips, and a write from a second client refreshes the page through the beacon.
13. `git push origin main`, then on the dev ship's forge: `POST /grubbery/forge/api/run {"repo":"orrery.git_repo","command":"pull"}`, and within a minute the desk's root `version.json` reads the new number and the instance's `bang` is `null`.
14. The publisher's steps: the forge pull (or the poll), the four reads of section 4, and, when the release added a road to the ask, the consent on `/apps/grubbery/permits` followed by a reload of the instance. A release that changes the starter schema or policy in the lib changes nothing on a ship that already has one: those files are seeded once, so a changed note is merged into the stored document by hand through `PUT /api/schema` or `PUT /api/policy`.

A release that raises the consent prompt leaves the new roads refused until the owner approves them, and whatever needed them stays off. Read `weir-json` in `code/nex/orrery/app.hoon` before the bump and say in the release note which lines are new.
