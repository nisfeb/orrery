# Hoon unit tests and mutation checks

Orrery's model, `code/lib/orrery.hoon`, is pure and imports nothing, so its
suites run on a test desk through the vendored
[hoon-test-kit](https://github.com/nisfeb/hoon-test-kit) at
`scripts/hoon-test-kit/`. `hoon-test.conf` at the repo root names the desk
and the files. The kit's `PLAYBOOK.md` has the method and the traps; this
file is what applies to orrery and what the runs found.

## Running

The test desk is `%orrery-test` on the fake ship `~nec` (pier
`~/software/nec`, dojo in tmux window `nec`). Once per ship, in its dojo:

```
|new-desk %orrery-test
|mount %orrery-test
```

then, from the repo:

```sh
scripts/hoon-test-kit/hoon-test.sh ~/software/nec setup
scripts/hoon-test-kit/hoon-test.sh ~/software/nec              # both suites, about 17 s
scripts/hoon-test-kit/hoon-test.sh ~/software/nec generator    # one file
```

Exit 0 is a pass. The runner prints each test's result, and for a
failure its expected and actual values.

The mutation runner takes about 16 s a mutant here, since each one
rebuilds the whole 6,200-line lib. The whole menu is about 1,400 mutants,
so aim it:

```sh
scripts/hoon-test-kit/hoon-mutate.py ~/software/nec --list                 # size first
scripts/hoon-test-kit/hoon-mutate.py ~/software/nec                        # boundary,conjunct: 206
scripts/hoon-test-kit/hoon-mutate.py ~/software/nec --since main --ops branch,equal,flag
scripts/hoon-test-kit/hoon-mutate.py ~/software/nec --only same-title      # recheck a fixed arm
```

`|meld` `~nec` before a long run.

The HTTP gates (`scripts/api-matrix.py` and the others) still run against
an orrery instance on `~feb`. They cover the nexus's wiring: its reads and
writes, and which handler each route reaches.

## What the runs found

### 2026-09-25: the first runs, after the business-logic review

The baseline was 127 test arms, all passing. Three runs followed:

- A first cheap pass stopped at mutant 7 of 206 when `~nec` died (see
  the kit's PLAYBOOK, "Look after the ship"). Its six results found
  three gaps in `+ok-chars`.
- `--since HEAD` ran the cheap ops on the arms the review had just
  changed: 51 mutants, 7 killed and 44 survived.
- `--only` rechecked the fixed arms. Every real gap is now killed, and
  what survives there is equivalent or accepted.

| verdict | count | what |
|---|---|---|
| real gap, closed | 24 | the cap pairs on `source.id`, `by`, a kind and a slug; a `z` and a leading `a` in an id; `phase` at an end or start of exactly now, and at a start equal to its end; `plan-retire` when a status shares the close's instant, and at a start equal to its end; `same-title` at exactly the share needed; two same-titled one-offs exactly a day apart; exactly 50 bodies in `observe-ops`; the brief's day edges (an event ending as the day starts, one starting as it ends, tomorrow's all-day event, a date-due todo tomorrow, a timed span of exactly the day) and exactly ten undated todos; each of `events-in`'s three own-event marks alone |
| equivalent | 4 | `newest-bodies`'s comparator behind its equality guard; `is-weekday`'s length test, since no two-letter weekday exists; `same-event`'s `gth` on a tie, where both branches measure 0; `micro-of`'s saturation at exactly 30, where saturating and computing agree |
| accepted | 20 | exact-instant comparisons against now in passes that rerun within minutes (`plan-retire`'s windows, five sites, `plan-events`' behind and ahead, six, `prune-seen`, `tg-remember`'s day, the brief's two timed dues and a situation at either edge of the window); the brief's two sort comparators on ties it does not order; `own-words`' ten-byte floor, reachable only by the line "On  wrote:" |

The new tests are in `tests/lib/orrery.hoon` (`test-ok-kind`,
`test-ok-slug`, the decoder caps) and `tests/lib/generator.hoon`
(`test-phase`, `test-plan-retire-after-status`, `test-same-title`,
`test-same-event-window`, `test-observe-ops-split`,
`test-brief-today-edges`, `test-events-of`).

Not run yet: the cheap pass on the arms outside this review, about 150
mutants, and `branch,equal,flag` (377 mutants within `--since` of the
review's base). The wide `&(...)` and `|(...)` guards, which most of this
lib uses, are outside the kit's `conjunct` op today.

## Reaching the nexus (version 60)

The nexus (`code/nex/orrery/app.hoon`, about 5,600 lines) could not be
unit tested. Following the kit's playbook ("Testing nexus code"), its
rules moved into the lib, and the nexus keeps the reads, the writes and
a one-line alias per moved arm, so no call site changed.

- **Moved as they were:** the 21 arms that neither run as a fiber nor
  touch the tree, and the types they need (`actor`, the tallies, the
  telegram runs). Among them are the rules for what a key sees
  (`view-of`, `hidden-for`, `seen-by`) and writes (`deny-observe`,
  `deny-write`). The MCP lib's copy of `open-twin` is an alias now too.
- **Lifted out of the fibers:** the decisions each fiber made between
  its reads and writes, each now one pure arm:
  - `route-of`: the route table, and who may take each route.
  - `access-refusal` and `request-refusal`: the 403s, the 415 and the
    cross-site check.
  - `act-refusal` and `de-mint`: a key's proposal and a new key's request.
  - `run-fresh`, `run-rows`, `gate-verdict`, `reader-answer`: the readers'
    verdicts.
  - `read-item`, `read-held`, `key-hide`: the read channel.
  - `mail-since`, `mail-fresh`, `brief-replies-of`, `mail-rows`: the mail
    reader's choices.
  - `chat-since`, `chat-next`, `sift-rows`: the chat and mail readers'
    sift, which was written out twice.
  - `day-count`, `month-spend`, `counted-call`, `counted-pass`,
    `gen-record-doc`, `transient-status`: the generator's records.
  - `reabout-one`, `repoint-people`, `op-gone`: a body merged or deleted.
  - `revives`, `dead-rows`, `offer-refusal`, `replacement`, `answer-fits`,
    `tg-why`, `touch-due`, `owner-zone`: the writer, sharing, the brief,
    iris and the telegram filter.

**Proving the nexus unchanged.** Before staging, a script recorded 68
answers from `~feb`: every read route as the owner, a writing key and a
read-only key, and every refusal the router makes (owner only, read only,
no route, no credentials, 415, cross-site, and a key's refused
proposals). It recorded them again after staging. 61 were
byte-identical. The other 7 differed only in time: the state's `at`, the
keys' last-used stamps, and the reconcile, executor and calendar passes
that ran again when the nexus reloaded.

`tests/lib/nexus.hoon` tests every moved and lifted arm; one test holds
all 63 routes and their access, generated from the lib's table.

**Mutation.** `~nec` died three times during these runs (the kit's
PLAYBOOK, "Look after the ship"). What ran:

| pass | mutants run | killed | no-build | survived |
|---|---|---|---|---|
| boundary, conjunct on the lifted arms | 36 of 165 before a death | 31 | 1 | 4 |
| the four ops on `rise-plan`, `rise-row`, `mail-threads` | 4 | 4 | 0 | 0 |
| `dead-rows`' horizon, rechecked | 1 | 1 | 0 | 0 |
| `wide` (the `&(...)` and `\|(...)` guards) on all of them | 61 | 53 | 4 | 4 |
| branch, equal on the lifted arms | 80 of 133 before a death | 68 | 11 | 0 |
| `wide` on the three arms its survivors were in, rechecked | 17 | 16 | 1 | 0 |
| equal on the 53 the death left, less `brief-texts` | 53 | 53 | 0 | 0 |
| `route-of` under `equal` | 63 | 63 | 0 | 0 |

Every no-build drops or flips a `?=` whose narrowing later code needs,
which cannot compile. The survivors:

- `dead-rows`: nothing held a row recorded exactly at the horizon. It is
  kept, and `test-dead-rows` now says so; the recheck killed it.
- `mail-since` and `chat-since`: their "before 1970" branch is defensive.
  The settings cap `backfill_hours` at 720, so the span never passes now.
- `mail-fresh`: its sort comparator on ties, which it does not order.
- `open-twin` without its title check, `brief-replies-of` without "the
  message answered is ours", and `reabout-one` without either half of
  "an open message to from, and a body to send it to": real gaps, each
  now a case in `tests/lib/nexus.hoon`; the recheck killed all four.

Left out: `brief-texts`' two mutants. Two of `~nec`'s three deaths came
while one of them ran, which points at a runtime fault rather than at
orrery; reproducing it would crash the ship on purpose.

## The upgrade and weir tests (version 60)

Before version 60 every fiber came back from a crash through
`rise-wait:io`. That never spun, but the writer lost the first op after a
crash, and every fiber nothing pokes stayed down until a reload. Version
60 ports calendar's `+rise-later`, and its back-off is the lib's
`+rise-plan`, tested in `test-rise-plan`. Both tests ran on `~feb` with
the stock grubbery kernel on 2026-09-25 (README, Development, has the
steps):

- **The upgrade.** Version 59 went back on the ship and took
  `scripts/upgrade-seed.py`'s odd data: settings of the wrong types,
  read-inbox items with odd fields, observations at the size caps and
  unreadable times, and actions with payloads of odd shapes. Then the new
  code went over it. For five minutes the worker's CPU stayed between 0
  and 22%, the instance's bang stayed null, the route answered, and a
  write landed.
- **`/sys/behn/` refused.** Every fiber that sets a timer crashed once,
  printed its trace once, said "no timer (weir?); waiting for a poke" and
  parked. CPU stayed under 21% for five minutes, and a wake sent
  meanwhile was refused with a 500. With the road back, the next wake
  resumed the fiber.
- **`/sys/bowl.sig` refused.** Every fiber that reads the clock parked
  with "no clock", the web binder included, so orrery's routes were dead
  while the CPU stayed under 14%. That is a parked app, not a spin.
- **`/sys/iris/` refused**, with the generator given a key and a forced
  pass. It crashed on the model call and came back by itself after 1,
  then 2, then 4 minutes, printing only "again (3 times running)" the
  third time. A forced pass sent while it waited was refused with a 500.

On a kernel with the fiber-safety guards, the kernel parked the fibers
itself, and orrery's own handling never ran. Run these on the stock
kernel.

**The kick (rule 9).** The port first shipped without calendar's later
`+take-kick`: a restarted fiber's first step sent at once, and grubbery
queues the restart's null kick behind whatever the fiber was holding, so
a held input crashed the step (`real-input-to-oneshot-step`) and counted
as another crash. `+rise-later` and the request fiber now take the kick
first. Eleven reloads of `~feb`'s instance with writes in flight never
tripped it on the old code, so the test did not bite here; the forced
crash test ran again with the fix and backed off 1, 2 and 4 minutes as
before.

## The prompt review (version 60)

The prompt review's code changes brought new arms and changed old ones:
`decision-lines`, `owner-lines`, `relation-words` with `person-key`,
the owner's claim in `known-people` and `people-of-ships`, and the owner's
place in `cast` and `plan-events`. The first run used all six ops on the
small arms, and `wide` and `equal` on `plan-events`: 86 mutants.

- `decision-lines`: the older dismissals kept had no done action with a
  note and no dismissal without a reason within the last forty. Both are
  now in `test-decision-lines`, and the recheck killed both mutants.
- `person-key`: dropping "a name besides the relation" changed nothing.
  A relation word alone leaves no name either way, so the conjunct went.
- `plan-events`: the retraction's guard without `with-me` survived.
  `test-plan-events-owner` now holds an old row on an event that names
  the owner, and the recheck killed it.

Left as they were: ten `wide` survivors in `plan-events`' older guards
(repeats, stale cadence, the seen marks, the cancel of a vanished
one-off) and one in `cast`'s lead name. That code predates this change,
and none of those guards is tested alone yet.
