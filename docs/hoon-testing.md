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

Exit 0 is a pass. On a failure the test names are in `~nec`'s terminal,
not on stdout.

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
an orrery instance on `~feb`. They cover the nexus, which no unit test
reaches.

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
