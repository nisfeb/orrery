# What orrery prints, and what it records instead

Orrery follows the Groundwire Foundation's Logging Management Policy
(draft of 1 October 2026): a healthy ship prints nothing; a line on the
console reports a departure from normal that a person can act on and
says what to do; a fault that lasts is recorded where one read returns
it; diagnosis is opt-in. This page is orrery's application of it: the
lines it can print, the state it keeps instead, where it still fails in
silence, and the quiet gate a release passes.

## The lines

Orrery's own code prints from four sites, all in `code/nex/orrery/app.hoon`.
Nothing in the lib, the tools or the marks prints. Each line names its
source first (`%orrery <fiber>`), says what happened, and ends with the
remedy, in stable words with the variable parts last.

| marker | when | the line | recorded in |
|---|---|---|---|
| `>>>` Error | the weir refuses the clock (`/sys/bowl.sig`) or the timer (`/sys/behn`), so a crashed fiber cannot plan its restart | `%orrery <fiber>: parked, the weir refuses the clock (/sys/bowl.sig); grant it on /apps/grubbery/permits, then reload` | `rise.json`, key `parked`; cleared by the next clean start |
| `>>` Warning | a fiber crashed and will come back by itself | `%orrery <fiber>: crashed; it comes back by itself in N min; the trace is above, file it if it crashes again`, then on each later crash `%orrery <fiber>: crashed again (N times running); next try in M min` | `rise.json`, one row per fiber: the count, the last crash, the next try |
| `>>` Warning | a request fiber crashed | `%orrery request: a request crashed; the trace is above, file it; the count is in rise.json under %orrery request`, once; later crashes only count | `rise.json`, key `%orrery request` |

One refused weir fails every fiber at once, and before this policy each
printed. Now the first fiber to record the park prints and the rest find
it recorded. Fibers that fail in the same event each write `rise.json`
from what they read, so the first refusal can still print more than once
(the `ponytail:` note on `+rise-later` names the race); a grub per fiber
would end it.

The crash trace is never orrery's to print: the kernel prints
`%fiber-crash <path>` and the whole trace for every fiber crash,
ungated, so orrery's line adds only the retry plan and the record's
name. The two faults split the other way: a road orrery refuses softly
(the clock and the timer in `+rise-later`) prints nothing from the
kernel, so orrery's `>>>` line is the only one; a road whose refusal
crashes a fiber bangs it, the kernel prints its one parked line with
the same remedy, and orrery, which never runs again until the reload,
prints nothing. The trace is the one thing on the console that could carry a
user's words; that is the kernel's to gate, and is on the register
below.

Orrery has no debug output and so defines no `++  dbg`. A change that
adds diagnostic prints defines one in the core whose arms test it, as
the policy says, and prints through `~?  dbg` with no marker.

## The state

What a reader of the ship needs is kept where one read returns it, each
record bounded and overwritten in place. The ball browser shows every
one of them under the instance's data directory.

| record | holds | bounded by |
|---|---|---|
| `tr/last`, `tr/log`, `tr/inbox` | the writer's last outcome, its last 500, ship traffic's last 500 | fixed rings |
| `rise.json` | each fiber's crashes in a row and its next try; `parked` while the weir refuses a road every fiber needs; `%orrery request` for crashed requests | one row per fiber, keys overwritten |
| `generator-last.json`, `reconcile-last.json`, `exec-last.json`, `calendar-events-last.json`, `telegram-last.json`, `chat-last.json`, `mail-last.json`, `read-last.json`, `brief-last.json` | what each pass last did, when, and its notes: what was dropped and why, a model that could not be reached, a gate that said no | one document each |
| the bang on `orrery.orrery_app` | the compile error, with line and column, when the instance does not build; `null` while it runs | the kernel's |

A refusal the HTTP route can answer is answered, with the reason, and
recorded in the writer's trail. A refusal with no other channel, a poke
the fiber took before the app judged it, goes to the pass's record.

## Where silence is not yet true

A failure that prints nothing and records nothing breaks the policy as
surely as noise. These are the soft reads and pokes in the nexus that
return nothing and move on, with what records each today.

| site | on a refusal or a bad shape | recorded |
|---|---|---|
| `+events-pass`, the calendar's order index | the pass does nothing | yes, since this page: `calendar-events-last.json` carries `note` until a pass reads the index again |
| `+events-pass`, the calendar store | the pass does nothing | no: `calendar-events-last.json` stops moving. The executor's own record says when the store last turned |
| the mail pass, auspex's thread tree and inbox index | the thread is skipped, or the tree's order is used | partly: a refused auspex fails the action with auspex's reason; a thread the peek cannot read is not noted |
| the sharing fibers, `/sys/link` lanes and the peer's weir | the share is not carried | no: the share's own status row is the record, and it stays at its last state |
| the executor's `soft` pokes to the calendar and the todo list | the action stays approved | yes: the action's note, when the executor reports |
| `+soft-now`, `+soft-behn` in `+rise-later` | the fiber parks | yes, since this page: `rise.json`, `parked` |

Fixing the rest means a `note` on the pass's record at each site, the
way the calendar index now has one. None of them hides a fault from the
owner for long, since every pass has a record whose `at` stops moving,
but the record should say why.

## The known-noise register

Lines on an orrery ship's console that orrery does not print. They are
the runtime's and the kernel's, reported upstream, and listed so an
operator can tell an old line from a new one. The quiet gate ignores
the ones marked.

| line | from | gate |
|---|---|---|
| `>>  [%desk-source-unreachable '<source>' retry-in=~h1]` | grubbery's desk sync, once an hour per desk whose publisher is down | ignored |
| `%fiber-crash <path> in=<tag>` and the trace that follows | grubbery, on every fiber crash, ungated | a finding when orrery's own fiber crashed |
| `fiber parked: a dart was refused by the weir` / `fiber parked: restarted over N times in one event` | grubbery, the bang on a parked fiber | a finding |
| `BANG nexus <path>` and the compile error | grubbery, when a nexus does not build | a finding |
| `>>  [%veto-received-from ...]` | grubbery, a remote host refusing one of ours | a finding when orrery's share was refused |
| `>>> grubbery: <app> is parked: it may not <poke, peek or make> <road>; grant it at /apps/grubbery/permits, then reload` | grubbery, once per app while one of its fibers is banged by a refusal it did not handle | a finding |
| `[%process-dart-vetoed ...]`, `[%weir-veto-at ...]` | grubbery, behind its debug flag since its quiet-console branch; a release prints neither | debug only |
| `grubbery: migrating state ...` | grubbery, on a kernel upgrade | ignored during a kernel deploy |
| `eyre: replacing existing binding at /apps/orrery` | eyre, each time the instance starts and binds its path again: every reload, every release | ignored |
| `http: fail (<n>, <status>): connection failure` | vere's HTTP client, once per outbound request that could not connect (the model, Telegram); orrery records the same failure on the pass's record | ignored |
| `newt: ...`, `loom: ...`, `conn: ...` | vere | not orrery's; see the test kit's reference on conn.sock |

## The quiet gate

Every release passes this on a test ship before it ships. The script
runs the two steps a script can run; the rest are the operator's.

1. `python3 scripts/quiet-gate.py <tmux target> $SHIP $JAR`: the ship's
   console is captured from its tmux pane, the instance is reloaded
   through the explorer, and once the bang is `null` again every new
   console line not on the register is a finding. Each new line is
   printed, as a finding or as ignored, so a pass shows what it
   ignored. Exit 0 is a pass; exit 2 means the console could not be
   matched before and after, and nothing can be said.
2. Install the release on a ship that has data and grant its
   permissions. After start-up, nothing new on the console.
3. Refuse a road orrery needs on `/apps/grubbery/permits`. Exactly one
   `>>>` line names the road and says to grant it and reload, and
   `rise.json` reads `parked`.
4. Grant it again and reload. `parked` is gone from `rise.json`, the
   fibers run, and nothing printed.

A line printed by a healthy orrery is a bug. So is a failure that left
no line and no record. Both are filed and fixed like any other defect.
In review, a change that adds a print states its level from the table
above and why the fact is not recorded state instead; prints on success
paths and prints inside loops over data are rejected.
