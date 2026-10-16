# Testing orrery

Orrery is tested on its own fleet set from
[hoon-development](https://github.com/nisfeb/hoon-development), never on
`~ricsul-bilwyt`. A push to `main` reaches ricsul through its forge
(docs/releasing.md), so test here first.

| | |
|---|---|
| set | `orrery` (in hoon-development's `fleet/sets.conf`) |
| ship | `~wyl`, fake, pier `~/fleet/piers/wyl` |
| HTTP | http://localhost:8122 (loopback ames in `~/fleet/piers/wyl/.http.ports`) |
| dojo | `tmux attach -t fleet`, window `wyl` |
| grubbery | the dev platform's pin (hoon-development `platform/grubbery.ref`) |
| orrery | a dev desk at `/apps/shell.shell/desks/orrery.desk`, the same path as on ricsul, following `/orrery-dev/code` in the ball |
| test desk | `%orrery-test`, mounted, set up for the kit |

Below, `F=~/software/personal/hoon-development/fleet/fleet` and
`U=~/software/personal/hoon-development/bridge/u`. Set `FLEET_WHO` to
your session's name so claims know who is asking.

## Reset

```sh
$F reset orrery compiled   # orrery 103 installed and approved, test desk set up: ~9 s
$F reset orrery            # golden: grubbery and %unix, no orrery
$F ls                      # is ~wyl up?
$F up orrery               # restart it from its event log (vere 4.6 sometimes segfaults)
```

Start every test from `compiled`. Refresh it after a deploy that tests
should start from: `$F snap orrery compiled`. For a throwaway point,
`$F --fast snap orrery before-x` takes seconds.

## Offline tests (no ship)

```sh
scripts/offline-tests.sh                 # all three suites at once, ~75 s
scripts/offline-tests.sh nexus           # by name
python3 scripts/hoon-test-kit/offline-test.py tests/lib/orrery.hoon test-parse-bid   # one arm
```

They run the suites in `tests/lib` through `vere eval` with the kit's
`offline-test.py`, taking `test.hoon` from the dev platform's `%base`.
The model, `code/lib/orrery.hoon`, imports nothing, so no grubbery
dialect is needed. `scripts/eval-tests.sh <suite>` is the older runner
the release checklist names (its own stand-in for the test lib); both
give the same counts. The ship run is the verdict.

`code/lib/orrery-mcp.hoon` and `code/lib/tools/` name kernel types
(fibers, the nexus), so they have no offline suite; the MCP gate covers
them on the ship.

## Ship tests

```sh
scripts/hoon-test-kit/hoon-test.sh ~/fleet/piers/wyl            # every suite, 249 tests, ~50 s
scripts/hoon-test-kit/hoon-test.sh ~/fleet/piers/wyl generator  # one suite
```

The kit finds vere in `~/software`, so `VERE` need not be set. On a
fresh set (golden, or a rebuilt pier) make the test desk once:
`|new-desk %orrery-test` and `|mount %orrery-test` in the dojo, then
`scripts/hoon-test-kit/hoon-test.sh ~/fleet/piers/wyl setup`.

The HTTP gates in `scripts/` (docs/releasing.md section 8) run against
`~wyl` too. They write data, so reset afterwards:

```sh
scripts/hoon-test-kit/ship-cookie.sh ~/fleet/piers/wyl http://localhost:8122 /tmp/wyl.jar
python3 -u scripts/key-matrix.py http://localhost:8122 /tmp/wyl.jar    # 125 checks, ~2.5 min
python3 -u scripts/mcp-matrix.py http://localhost:8122 /tmp/wyl.jar    # 46 checks, ~1 min
python3 -u scripts/page-smoke.py http://localhost:8122 /tmp/wyl.jar    # 13 checks, ~20 s
ONLY=<header words> python3 -u scripts/api-matrix.py http://localhost:8122 /tmp/wyl.jar ~wyl --partial
$F reset orrery compiled
```

The generator's Armillary key, read from the offer at each call, needs Armillary on `~wyl` too: install it from the armillary repo with its `scripts/dev-deploy.py http://localhost:8122 /tmp/wyl.jar --add`, then run `python3 -u scripts/armillary-key-matrix.py http://localhost:8122 /tmp/wyl.jar` (14 checks, ~50 s). It runs its own stub model, lays test offers into Armillary's `app-inference.json` with a `/v1` address as the vendor's proxy has, checks the decider asks `<address without /v1>/alpha/decisions` (Armillary 34), and puts the files it touched back after.

`node scripts/page-test.js`, `scripts/code-closure.py code` and
`scripts/load-rows.py` need no ship.

`compiled` keeps the session the jar was minted for, so the jar works
after a reset. `api-matrix.py` refuses to start without live calendar
and auspex desks, which this set does not have; `--partial` runs it
anyway, and their checks fail. Pick sections with `ONLY`, and include
the sections a later one leans on (`outdoors` needs the home that `time
to leave` sets). The two-ship gates (`ship-share-matrix.py`,
`twins-matrix.py`, `location-matrix.py`) need a second ship, which this
set does not have.

## Deploying a change to ~wyl

```sh
python3 scripts/dev-deploy.py http://localhost:8122 /tmp/wyl.jar code
```

It writes `code/` into `/orrery-dev/code` and stamps that tree's
`version.json` with a dev time, which makes the desk pull. It refuses any
ship that is not on localhost. A release that adds a road needs
approving again: `--approve` posts the instance's own `weir.json` as
`granted` to `/apps/grubbery/permits` (`approve-weir`), then reloads its
permits. Without `granted` this kernel grants an empty weir.

How `compiled` was made, from the golden: `dev-deploy.py ... code --add
--approve`, then the test desk.

## Looking inside with u

```sh
$U orrery our
$U orrery kids /orrery-dev/code                     # files in a ball dir
$U orrery file /apps/shell.shell/desks/orrery.desk/version.json
$U orrery kids /apps/shell.shell/desks/orrery.desk/desk/data/orrery.orrery_app
```

`u` guards its subcommands. A raw `.^` in an expression that misses kills
every thread on the ship: check a path with `kids` first. Never point u,
the fleet commands or these scripts at a ship outside `orrery`.
