---
name: hoon-test-kit
description: Use when running, writing, auditing or measuring the coverage of a Hoon app's unit tests (-test suites, tests/lib/*.hoon), when setting up a test desk on a fake ship, or when asked to mutation-test Hoon libs or find what the Hoon tests miss. Runs suites in seconds over conn.sock, with no dojo, and reports mutants no test catches.
---

# hoon-test-kit

The kit runs a Hoon app's suites on a fake ship through a test desk that
holds only the libs under test, and mutation-checks them. Its home is
`~/software/personal/hoon-test-kit` (GitHub `nisfeb/hoon-test-kit`). An app
that already uses it has a vendored copy at `scripts/hoon-test-kit/` and a
`hoon-test.conf` at its root.

**Before the first run on an app, read `PLAYBOOK.md`.** It has the rollout
order, the triage rules and the traps. This file is the short version.

## Find out where the app stands

1. Is there a `hoon-test.conf` at the repo root? If not, the app is not set
   up: follow "Installing it in an app" in the kit's `README.md`, starting
   from `hoon-test.conf.example`.
2. Which ship? Use a fake ship the user named, or ask. Never assume a port
   or a tmux pane; `ss -ltn` shows what is listening. Never use the user's
   real ship (the one their memory store lives on).
3. Is the test desk there? If `<pier>/<DESK>/` does not exist, it needs
   `|new-desk %<DESK>` and `|mount %<DESK>` in that ship's dojo, then
   `hoon-test.sh <pier> setup`.

## Run

```sh
scripts/hoon-test-kit/hoon-test.sh <pier>              # all suites; exit 0 = pass
scripts/hoon-test-kit/hoon-test.sh <pier> <suite>      # one test file, no .hoon
scripts/hoon-test-kit/hoon-mutate.py <pier> --list     # always size a run first
scripts/hoon-test-kit/hoon-mutate.py <pier>            # boundary,conjunct (the cheap pass)
scripts/hoon-test-kit/hoon-mutate.py <pier> --ops branch,equal,flag
scripts/hoon-test-kit/hoon-mutate.py <pier> --only <arm>,<arm>   # recheck fixed arms
scripts/hoon-test-kit/hoon-mutate.py <pier> --since <rev>          # arms a diff touches
```

Exit codes: **1** means a test failed (the names are in the ship's terminal,
not stdout), **3** means a lib did not build, **4** means the ship did not
answer. **4 is never a test result.** Stop and report it.

## Rules

- **Size before you run.** Each mutant takes about 10 s and one commit, and
  commits cost loom. For a run over ~50 mutants, tell the user the count
  and the time, and prefer a ship nothing else is building on.
- **A crash is stop-and-report.** Never restart a pier yourself. If results
  suddenly come back in 0 s, the ship is down, whatever the verdicts say.
  When the runner says the ship stopped answering, believe it: a vere
  process still listed in `ps` is not a ship that answers.
- **Mutate new code while it is new.** Run `--since <rev>` right after a
  change: code written in one pass arrives without its boundary tests
  (44 of 51 survived on orrery's first such run).
- **After a crash, settle the desk** with `NOSYNC=1 hoon-test.sh <pier>`.
  A clean mount is not a clean desk.
- **Check the no-build rate per op** before trusting survivors. A high rate
  means the site regex is wrong, and that op did not really run.
- **Re-trace every survivor before writing a test for it.** Many are
  equivalent: fast paths, comparators behind an equality guard, running
  maxima, cost-only bounds, `$~` defaults on molds never bunted. PLAYBOOK.md
  lists them.
- **For real gaps**: add the check to the test that owns the rule, test
  caps as a pair (the cap accepted, cap + 1 refused), and prove the fix by
  rerunning `--only <arm>` until the mutant is killed.
- **Update the docs as you go.** A new trap or technique goes into the
  kit's `PLAYBOOK.md`, in the kit repo, then re-vendor. Per-app findings go
  in the app's own docs. The user asked for this explicitly.
