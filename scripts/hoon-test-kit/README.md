# hoon-test-kit

Run a Hoon app's unit suites on a running fake ship **in seconds, with no
dojo**, and check that they actually catch breaks.

- `hoon-test.sh`: syncs the libs under test, their tests and fixtures into
  a desk that holds nothing else, commits it, and runs `%test` over the
  pier's `conn.sock`. On auspex, 156 tests take about 7 s, against roughly
  two minutes for a commit to the app's own desk.
- `hoon-mutate.py`: breaks one thing at a time in those libs (a boundary,
  a guard's condition, a branch, an equality, a flag), reruns the suites,
  and reports every break that no test noticed.

[PLAYBOOK.md](PLAYBOOK.md) is the procedure: rolling this out to an app,
reading and triaging the results, and every trap we hit building it. Read
it before the first run on a new app.

## Requirements

A running fake ship, and on the machine: `bash`, `python3`, `socat`,
`rsync`, `perl`, and a vere binary. The kit only uses vere for its
`eval --jam/--cue` framing. Set `VERE=<path>`; otherwise the kit uses the
newest `vere-*-linux-x86_64` in the directory that holds the pier.

## Installing it in an app

Vendor the kit, write one config file, and set up a desk once per ship.

```sh
# from the app repo
rsync -a --delete --exclude .git ~/software/personal/hoon-test-kit/ scripts/hoon-test-kit/
git -C ~/software/personal/hoon-test-kit rev-parse --short HEAD > scripts/hoon-test-kit/.kit-version
cp scripts/hoon-test-kit/hoon-test.conf.example hoon-test.conf   # then edit it
```

Rerun the same two lines to update, then commit the vendored copy. The kit
is vendored rather than fetched so an app's tests never change under it.

Then, once per ship. In its dojo:

```
|new-desk %<app>-test
|mount %<app>-test
```

and from the repo:

```sh
scripts/hoon-test-kit/hoon-test.sh <pier> setup
```

Setup copies `lib/test.hoon` and the config's `MARKS` in from the ship's
own `%base`, so they always match its kelvin. It skips anything already
present, so it is safe to rerun.

## hoon-test.conf

At the app repo's root. `bash` sources it and `python` parses it, so it
holds plain `KEY="value"` lines only. Paths are relative to the file.

| key | meaning |
|---|---|
| `DESK` | the test desk, e.g. `auspex-test`. Never the app's own desk. |
| `LIBS` | the libs under test, space-separated. Each lands at `lib/<name>.hoon` and is what `hoon-mutate.py` mutates. List any lib they import too. |
| `TESTS` | a directory; every `*.hoon` in it lands in `tests/lib/`. |
| `FILES` | optional fixtures, landing at the same path on the desk, or `src=dest` to move one (`code/sur/x.hoon=sur/x.hoon`). |
| `MARKS` | marks copied from `%base` at setup. Default `json mime`: a `/*` of a json file needs both. |

The kit finds the config in the current directory or the nearest one above
it. `HOON_TEST_CONF=<path>` overrides that.

## Running

```sh
scripts/hoon-test-kit/hoon-test.sh <pier>                 # every suite
scripts/hoon-test-kit/hoon-test.sh <pier> <suite> ...     # by test file name, no .hoon
NOSYNC=1 scripts/hoon-test-kit/hoon-test.sh <pier>        # commit the mount as it stands

scripts/hoon-test-kit/hoon-mutate.py <pier> --list                   # size a run first
scripts/hoon-test-kit/hoon-mutate.py <pier>                          # boundary,conjunct
scripts/hoon-test-kit/hoon-mutate.py <pier> --ops branch,equal,flag
scripts/hoon-test-kit/hoon-mutate.py <pier> --only arm-a,arm-b       # recheck after a fix
scripts/hoon-test-kit/hoon-mutate.py <pier> --since main              # only the arms a diff touches
```

`--since <rev>` keeps the mutants in arms that `git diff <rev>` touches in
the libs under test. On a big lib it is how the expensive ops stay
affordable: on orrery's 6,200-line lib the whole menu is about 1,400
mutants, and `--since HEAD` after one review pass was 428.

`hoon-test.sh` exit codes:

| code | meaning |
|---|---|
| 0 | every test passed |
| 1 | a test failed. The names are in the **ship's terminal**, not here: `%test` slogs them and returns only a flag. |
| 3 | a lib did not build |
| 4 | the ship did not answer. This is never a test verdict. |

`hoon-mutate.py` needs about 10 s **and one commit** per mutant (more for
a big lib: each mutant rebuilds the whole lib and every test file, so
orrery's 6,200 lines take about 16 s, and 15 to 60 s on a busy host), and every
commit costs the ship loom. Size a run with `--list` first, and run long
ones on a ship nothing else is building on (PLAYBOOK.md, "Look after the
ship").

## Claude Code

`skill/hoon-test-kit/SKILL.md` teaches an agent to use the kit. Install it
for every project with:

```sh
ln -s ~/software/personal/hoon-test-kit/skill/hoon-test-kit ~/.claude/skills/hoon-test-kit
```

## Origin

Built for auspex on 2026-09-25. The first mutation runs found 26 real
gaps in a suite that already had 90 tests. `auspex/docs/hoon-testing.md`
is that case study.
