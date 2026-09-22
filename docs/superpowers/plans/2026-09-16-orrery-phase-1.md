# Orrery Phase 1 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** A grubbery desk app on the dev ship that stores bodies, observations and actions, folds observations into current state, and answers the HTTP API from spec section 6, proven by the section 8 scenario running green from `scripts/api-matrix.py`.

**Architecture:** One import-free hoon library (`code/lib/orrery.hoon`) holds the types, ids, validation, JSON codecs and the fold, and is unit-tested on the dev ship with `-test`. One nexus (`code/nex/orrery/app.hoon`) lays the tree in `on-load`, runs a single writer fiber at `/main.sig` that applies JSON ops, binds `/apps/orrery` from `/web.sig`, and answers each request on an ephemeral fiber under `/requests/`. The desk installs on the dev ship through the forge (a git mirror of `nisfeb/orrery`) and the shell's desk-add route, exactly the production path.

**Tech Stack:** Hoon at zuse 408 on grubbery (nisfeb/grubbery `dist/single-release`, local checkout `<the grubbery checkout>`), the fake dev ship (HTTP `$SHIP`, its dojo, clay mount `<the dev ship's mount>`), Python 3 with `curl` for the gate script, git with the nisfeb identity.

**Spec:** `docs/superpowers/specs/2026-09-16-orrery-design.md`. The plan argues from it; read sections 3, 5, 6 and 8 before any task.

## Global Constraints

- Prose rules for every doc, comment and commit message: no em-dashes, no hard-wrapped markdown, simple sentences (`/feedback/prose-style-rules`). Hoon comments follow grubbery's `style-guide.md`: `::  +arm: lowercase headline`, a bare `::` line below.
- No AI attribution anywhere: no `Co-Authored-By`, no `Generated with` lines, in commits or elsewhere.
- Commits go to `nisfeb/orrery` as the nisfeb identity (`git config user.name` is already `nisfeb`). Commit at the end of every task with the message given. Push only where a step says push.
- Never touch the live ship. Never boot, kill or restart a pier. Bounce is `|suspend %grubbery` then `|revive %grubbery`, never `|exit`.
- Dojo discipline (`/feedback/dojo-input-discipline`): send ONE line, verify its echo in the pane, never chain. Any wait over 2 minutes, or an echo missing after 30 seconds, is a STOP: report what is on screen. Never type an expression you have not seen work.
- Every persistent path in the tree has a covering `%fall` row in `on-load`. Every blot the tree lays has a marc inside `code/mar`. Every marc is a noun passthrough. Long-lived fibers use nexus-relative roads built with `rf` and `rv`. No `$` with arguments inside a `;<` continuation: recurse by arm name.
- The writer never crashes on input: every refusal is a clean branch that writes `/tr/last`.
- The library `code/lib/orrery.hoon` stays import-free (no `/<`, `/+`, `/-`): it must build both in the clay desk `/lib` for `-test` and in the app's code namespace.
- Hoon under zuse 408: use the colon form for wing-of-expression (`a:(b c)`), never `a.(b c)`. Widen a `?~`-narrowed list before `levy`, `roll` or `turn` (`` (levy `tape`t f) ``). Bind every computed tape to a `=/  x=tape` face before interpolating or welding it.
- Caps and shapes are the spec's, copied verbatim: kind 24 bytes, slug 64, name 200, alias 100 and 32 per body, attr 48, value 2000 serialized, source id 200, by 64, title 200, payload 4000, note 500, about 20, 50 bodies and 200 observations per observe.

---

## Working with the dev ship

Every ship step in this plan uses these recipes. Read them once.

**Login and cookie.** The dev ship answers on `$SHIP`. Its `+code` is read from its dojo. Keep the cookie jar in the session scratchpad, never in the repo:

```bash
W=$SHIP
CK=$JAR
curl -s -c $CK -o /dev/null -w '%{http_code}\n' -X POST $W/~/login --data 'password=novwel-tamfes-daplex-misdem'
# expected: 200. A 400 means the code is wrong: read it with `+code` on the dojo (recipe below).
```

**Dojo, one line at a time.** The dev ship's dojo is in its own pane. Send a line, then read the pane until the echo and the result appear:

```bash
# in the dojo: |commit %grubbery
# then read the dojo output
```

A `|commit` prints `+ /~sampel-sipnym/grubbery/<rev>/lib/orrery/hoon` lines for added files, `: /~sampel-sipnym/grubbery/<rev>/...` for changed ones, and `>=` at the end. The number after `grubbery/` is the desk revision `<rev>` used by `-test`. A commit that prints only `>=` saw no change. If the prompt shows `~sampel-sipnym:dojo/=/grubbery/...>`, the working dir is pinned: send `=dir /=base=` first (`/reference/grubbery-test-invocation-trap`).

**Unit tests.** The library and its test file are copied into the clay mount, committed, then run with the revision pinned. `-test` output ends with a `built`/`ok=%.y` or `ok=%.n` line and one `OK`/`FAILED`/`CRASHED` line per arm:

```bash
cp code/lib/orrery.hoon <the dev ship's mount>/lib/orrery.hoon
cp tests/lib/orrery.hoon <the dev ship's mount>/tests/lib/orrery.hoon
# in the dojo: |commit %grubbery
# then read the dojo output      # read <rev>
# in the dojo: -test /~sampel-sipnym/grubbery/<rev>/tests/lib/orrery ~
# then read the dojo output
```

Count only the `OK`, `FAILED` and `CRASHED` lines between your own command echo and its verdict. A compile error in the test file or the library prints a `dep failed` or a trace instead of a verdict; the file and line are in the trace. Two mechanics learned on the first runs: this shell aliases `cp` to `cp -i`, so copies into the mount are `\cp`; and a dojo line that starts with a dash needs `--` before it when it is sent through a terminal multiplexer, or the multiplexer reads the dash as a flag. A commit that touches a library the desk compiles takes 70 to 95 seconds to print; a pane that keeps changing is working, not stuck. Two hoon facts the tests taught: `%=` (the `x(face value)` form) and a dot wing (`face.x`) work on a leg bound with `=/`, not on an arm; to reach into an arm's product use the colon form (`face:x`) or bind it to a leg first.

**The fast loop for nexus code, after the desk exists (Task 4 onward).** Writing a file into the desk's code tree recompiles at once, with no commit. Then reload the instance so its long-lived fibers pick the new code up, and read `bang`:

```bash
D=$W/grubbery/ball/apps/shell.shell/desks/orrery.desk/desk
curl -s -b $CK -X POST --data-urlencode action=write-text --data-urlencode content@code/nex/orrery/app.hoon "$D/code/nex/orrery/app.hoon"
# answers: saved
curl -s -b $CK -X POST --data-urlencode action=reload-nexus "$D/data/orrery.orrery_app" -o /dev/null
sleep 20; curl -s -b $CK "$D/data/orrery.orrery_app?info=1" | python3 -c 'import sys,json; print(json.load(sys.stdin)["bang"])'
# expected: None. Otherwise the bang carries the compile error with line and column.
```

A file that does not exist in the code tree yet is created first with `action=create-file&filename=<name>` POSTed to its directory URL, then written with `write-text`. The git repo is the source of truth: edit the repo file, then write it to the ship. Never edit on the ship alone.

**Reading the tree.** `GET $W/grubbery/ball/<path>?info=1` describes a node (children, `bang`, `weir`); `GET ...?raw=1` returns a JSON grub's text. The instance root is `/apps/shell.shell/desks/orrery.desk/desk/data/orrery.orrery_app`.

---

## File Structure

| file | responsibility |
|---|---|
| `code/bill.json`, `code/version.json`, `code/tile.json`, `code/icon.svg` | the desk manifest: which nexus to instantiate, the replicating version, the launcher tile |
| `code/mar/json.hoon`, `code/mar/sig.hoon`, `code/mar/mime.hoon` | the kernel marcs the tree lays, vendored so the desk is hermetic |
| `code/mar/orrery/body.hoon`, `obs.hoon`, `action.hoon` | noun-passthrough marcs for the three stored shapes |
| `code/lib/orrery.hoon` | types, caps, validation, ids, ISO time, JSON codecs, the fold, timelines, involved, resolve, action rules, starter schema and policy. Pure, import-free |
| `tests/lib/orrery.hoon` | unit tests for the library, run on the dev ship |
| `code/nex/orrery/app.hoon` | the nexus: `on-load` rows, the writer, the HTTP binder, the request handler, tree walks |
| `scripts/api-matrix.py` | the HTTP gate: spec section 8 against the dev ship |
| `scripts/code-closure.py` | hermeticity check, copied from auspex |
| `docs/releasing.md` | the release mechanics, copied from calendar with the names changed |

---

### Task 1: The desk skeleton and the marcs

**Files:**
- Create: `code/bill.json`, `code/version.json`, `code/tile.json`, `code/icon.svg`
- Create: `code/mar/json.hoon`, `code/mar/sig.hoon`, `code/mar/mime.hoon`
- Create: `code/mar/orrery/body.hoon`, `code/mar/orrery/obs.hoon`, `code/mar/orrery/action.hoon`

**Interfaces:**
- Produces: the blots `[/ %json]`, `[/ %sig]`, `[/ %mime]`, `[/orrery %body]`, `[/orrery %obs]`, `[/orrery %action]` that Task 4's `on-load` and writer lay. The bill name `orrery.orrery_app` and neck `/orrery/app` that Task 4's nexus file path must match (`code/nex/orrery/app.hoon`).

- [ ] **Step 1: Write the manifest files**

`code/bill.json`:

```json
{
  "orrery.orrery_app": "/orrery/app"
}
```

`code/version.json` (the desk nexus compares this text opaquely; it changes only at a release):

```json
{"version": 1}
```

`code/tile.json`:

```json
{
  "title": "Orrery",
  "info": "What is going on in your world",
  "color": "#101541",
  "image": "/grubbery/tiles/icon/orrery",
  "href": "/apps/orrery"
}
```

`code/icon.svg`, the family palette (amber `#f9a804` on navy `#101541`), an orrery: three orbits and their bodies:

```svg
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 64 64" width="64" height="64">
  <rect width="64" height="64" rx="12" fill="#101541"/>
  <g fill="none" stroke="#f9a804" stroke-width="1.5">
    <circle cx="32" cy="32" r="10"/>
    <circle cx="32" cy="32" r="18"/>
    <circle cx="32" cy="32" r="26"/>
  </g>
  <g fill="#f9a804">
    <circle cx="32" cy="32" r="4"/>
    <circle cx="42" cy="32" r="2"/>
    <circle cx="32" cy="14" r="2.2"/>
    <circle cx="13.6" cy="45" r="2.4"/>
  </g>
</svg>
```

- [ ] **Step 2: Vendor the three kernel marcs**

Copy them byte for byte from the auspex desk, which took them from the kernel:

```bash
cp ../auspex/code/mar/json.hoon code/mar/json.hoon
cp ../auspex/code/mar/sig.hoon  code/mar/sig.hoon
cp ../auspex/code/mar/mime.hoon code/mar/mime.hoon
diff code/mar/json.hoon ../../groundwire/grubbery/desk/gub/mar/json.hoon && echo same
```

Expected: `same`. If the kernel copy differs, keep auspex's.

- [ ] **Step 3: Write the three orrery marcs**

All three are noun passthroughs: the shape check lives in the reader (`read-body`, `read-obs`, `read-action` in Task 2), never in the marc, because a typed marc re-validates every stored grub against the live type and a shape change would boom every one of them.

`code/mar/orrery/body.hoon`:

```hoon
::  mar/orrery/body: one body, at /bodies/<kind>/<slug>/body.
::
::    Stored as [%1 body] (see +stored-body in lib/orrery). A noun
::    passthrough: the shape ladder lives in +read-body, so a later
::    shape never booms a stored grub.
::
|_  n=*
++  grad  %noun
++  grow
  |%
  ++  noun  n
  --
++  grab
  |%
  ++  noun  *
  --
--
```

`code/mar/orrery/obs.hoon`:

```hoon
::  mar/orrery/obs: one observation, at /bodies/<kind>/<slug>/obs/<oid>.
::
::    Stored as [%1 obs]. Immutable except for the retracted flag. A
::    noun passthrough; the shape ladder is +read-obs in lib/orrery.
::
|_  n=*
++  grad  %noun
++  grow
  |%
  ++  noun  n
  --
++  grab
  |%
  ++  noun  *
  --
--
```

`code/mar/orrery/action.hoon`:

```hoon
::  mar/orrery/action: one action, at /actions/<aid>.
::
::    Stored as [%1 action]. A noun passthrough; the shape ladder is
::    +read-action in lib/orrery.
::
|_  n=*
++  grad  %noun
++  grow
  |%
  ++  noun  n
  --
++  grab
  |%
  ++  noun  *
  --
--
```

- [ ] **Step 4: Check the layout**

Run: `find code -type f | sort`

Expected:

```
code/bill.json
code/icon.svg
code/mar/json.hoon
code/mar/mime.hoon
code/mar/orrery/action.hoon
code/mar/orrery/body.hoon
code/mar/orrery/obs.hoon
code/mar/sig.hoon
code/tile.json
code/version.json
```

- [ ] **Step 5: Commit**

```bash
git add code
git commit -m "The desk skeleton: manifest, tile, icon, and the six marcs"
```

### Task 2: The library, part one: shapes, names, time, ids, decoders

**Files:**
- Create: `code/lib/orrery.hoon`
- Create: `tests/lib/orrery.hoon`

**Interfaces:**
- Produces, for Tasks 3, 4 and 5: the types `bid`, `body`, `source`, `obs`, `action`, `stored-body`, `stored-obs`, `stored-action`, `row`; the caps `max-*`; `ok-kind`, `ok-slug`, `ok-attr`, `parse-bid`, `make-bid`; `unix-secs`, `de-iso`, `en-iso`; `hex8`, `obs-id`, `act-id`; the JSON accessors `gj`, `has-key`, `gs`, `gn`, `ga`, `gt`, `strings`; `value-ok`, `de-body`, `de-obs`, `de-action`, `with-default`, `fill-obs`, `fill-act`, `prep-observe`; `read-body`, `read-obs`, `read-action`, `merge-body`, `fresh-name`. Exact signatures are in the code below.

- [ ] **Step 1: Write the failing tests**

`tests/lib/orrery.hoon`:

```hoon
::  Unit tests for /lib/orrery: names, time, ids and the decoders.
::
::    Every case a client can send, plus the cases only a broken client
::    sends. A decoder never crashes: "answers the field that failed" is
::    the behaviour under test.
::
/+  *test, orr=orrery
|%
++  jo  |=(t=@t ^-(json (need (de:json:html t))))
++  t0  ~2026.9.16..22.05.00
::
::  ==  names
::
++  test-ok-kind
  ;:  weld
    (expect !>((ok-kind:orr 'person')))
    (expect !>(!(ok-kind:orr 'Person')))
    (expect !>(!(ok-kind:orr '9lives')))
    (expect !>(!(ok-kind:orr '')))
    (expect !>(!(ok-kind:orr 'a-very-long-kind-name-over-24')))
  ==
++  test-ok-slug
  ;:  weld
    (expect !>((ok-slug:orr '2026-09-16-breakdown')))
    (expect !>((ok-slug:orr 'me')))
    (expect !>(!(ok-slug:orr '-x')))
    (expect !>(!(ok-slug:orr 'John')))
  ==
++  test-parse-bid
  ;:  weld
    (expect-eq !>(`(unit [@tas @ta])`[~ %person %sarah]) !>((parse-bid:orr 'person/sarah')))
    (expect-eq !>(`(unit [@tas @ta])`~) !>((parse-bid:orr 'sarah')))
    (expect-eq !>(`(unit [@tas @ta])`~) !>((parse-bid:orr 'Person/Sarah')))
    (expect-eq !>('thing/subaru') !>((make-bid:orr %thing %subaru)))
  ==
::
::  ==  time
::
++  test-iso-roundtrip
  =/  s=@t  '2026-09-16T22:05:00Z'
  ;:  weld
    (expect-eq !>(`(unit @da)`[~ t0]) !>((de-iso:orr s)))
    (expect-eq !>(s) !>((en-iso:orr t0)))
    (expect-eq !>(`(unit @da)`[~ t0]) !>((de-iso:orr '2026-09-16T22:05:00.250Z')))
    (expect-eq !>(`(unit @da)`~) !>((de-iso:orr '2026-09-16 22:05:00')))
    (expect-eq !>(`(unit @da)`~) !>((de-iso:orr '2026-13-01T00:00:00Z')))
    (expect-eq !>(`(unit @da)`~) !>((de-iso:orr '2026-09-16T22:05:00+02:00')))
    (expect-eq !>('1970-01-01T00:00:00Z') !>((en-iso:orr ~1970.1.1)))
  ==
++  test-unix-secs
  ;:  weld
    (expect-eq !>(`@ud`1.789.596.300) !>((unix-secs:orr t0)))
    (expect-eq !>(`@ud`0) !>((unix-secs:orr ~1969.12.31)))
  ==
::
::  ==  ids
::
++  o1
  ^-  obs:orr
  ['thing/subaru' 'location' s+'Route 9' t0 ~ 90 ['phone-dm' 'm1'] 'phone/triage' t0 | '']
++  test-obs-id-shape
  =/  id=tape  (trip (obs-id:orr o1))
  ;:  weld
    (expect-eq !>("1789596300-") !>((scag 11 id)))
    (expect-eq !>(19) !>((lent id)))
  ==
++  test-obs-id-ignores-by-and-seen
  ::  o1 is an arm, so %= cannot see its faces; bind it to a leg first
  =/  base=obs:orr  o1
  =/  o2=obs:orr  base(by 'claude-code', seen (add t0 ~h1))
  =/  o3=obs:orr  base(value s+'Route 10')
  ;:  weld
    (expect-eq !>((obs-id:orr o1)) !>((obs-id:orr o2)))
    (expect !>(!=((obs-id:orr o1) (obs-id:orr o3))))
  ==
++  test-act-id-shape
  =/  a=action:orr
    [%task 'Call the shop' ~ (sy ~['thing/subaru']) ~ 'mcp' t0 %proposed '']
  (expect-eq !>(19) !>((lent (trip (act-id:orr a)))))
::
::  ==  decoders
::
++  test-de-body-ok
  =/  got
    %+  de-body:orr
      (jo '{"id":"place/johns-machine-shop","name":"John\'s Machine Shop","aliases":["John\'s","the shop"]}')
    t0
  ?.  ?=(%& -.got)  (expect !>(|))
  ;:  weld
    (expect-eq !>('place/johns-machine-shop') !>(id.p.got))
    (expect-eq !>(%place) !>(kind.body.p.got))
    (expect-eq !>('John\'s Machine Shop') !>(name.body.p.got))
    (expect-eq !>(`(set @t)`(sy ~['John\'s' 'the shop'])) !>(aliases.body.p.got))
    (expect-eq !>(t0) !>(created.body.p.got))
  ==
++  test-de-body-refusals
  =/  bad
    |=  t=@t
    ^-  @t
    =/  got  (de-body:orr (jo t) t0)
    ?:(?=(%| -.got) p.got 'accepted')
  ;:  weld
    (expect-eq !>('id: expected <kind>/<slug>, lowercase, digits and hyphens') !>((bad '{"id":"Sarah"}')))
    (expect-eq !>('aliases: every alias is a string') !>((bad '{"id":"person/sarah","aliases":[1]}')))
    (expect-eq !>('aliases: each 1 to 100 bytes') !>((bad '{"id":"person/sarah","aliases":[""]}')))
  ==
++  test-de-obs-ok
  =/  got
    %^  de-obs:orr
      (jo '{"subject":"thing/subaru","attr":"location","value":{"ref":"place/johns-machine-shop"},"at":"2026-09-17T02:10:00Z","conf":85,"source":{"kind":"phone-dm","id":"m3"}}')
    t0  'http'
  ?.  ?=(%& -.got)  (expect !>(|))
  ;:  weld
    (expect-eq !>('thing/subaru') !>(subject.p.got))
    (expect-eq !>('location') !>(attr.p.got))
    (expect-eq !>(`json`(jo '{"ref":"place/johns-machine-shop"}')) !>(value.p.got))
    (expect-eq !>(~2026.9.17..2.10.00) !>(at.p.got))
    (expect-eq !>(`(unit @da)`~) !>(until.p.got))
    (expect-eq !>(85) !>(conf.p.got))
    (expect-eq !>(`source:orr`['phone-dm' 'm3']) !>(source.p.got))
    (expect-eq !>('http') !>(by.p.got))
    (expect-eq !>(t0) !>(seen.p.got))
    (expect-eq !>(|) !>(retracted.p.got))
  ==
++  test-de-obs-defaults
  =/  got
    %^  de-obs:orr
      (jo '{"subject":"person/me","attr":"status","value":null,"source":{"kind":"user","id":""}}')
    t0  'http'
  ?.  ?=(%& -.got)  (expect !>(|))
  ;:  weld
    (expect-eq !>(t0) !>(at.p.got))
    (expect-eq !>(100) !>(conf.p.got))
    (expect-eq !>(`json`~) !>(value.p.got))
  ==
++  test-de-obs-refusals
  =/  bad
    |=  t=@t
    ^-  @t
    =/  got  (de-obs:orr (jo t) t0 'http')
    ?:(?=(%| -.got) p.got 'accepted')
  ;:  weld
    (expect-eq !>('subject: expected <kind>/<slug>') !>((bad '{"subject":"subaru","attr":"a","value":1,"source":{"kind":"user"}}')))
    (expect-eq !>('attr: lowercase, digits and hyphens, at most 48 bytes') !>((bad '{"subject":"thing/subaru","attr":"Location","value":1,"source":{"kind":"user"}}')))
    (expect-eq !>('value: required') !>((bad '{"subject":"thing/subaru","attr":"location","source":{"kind":"user"}}')))
    (expect-eq !>('value: a string, number, boolean, null or object, at most 2000 bytes') !>((bad '{"subject":"thing/subaru","attr":"location","value":[1],"source":{"kind":"user"}}')))
    (expect-eq !>('value.ref: expected <kind>/<slug>') !>((bad '{"subject":"thing/subaru","attr":"location","value":{"ref":"nowhere"},"source":{"kind":"user"}}')))
    (expect-eq !>('at: expected an ISO 8601 UTC time such as 2026-09-16T22:05:00Z') !>((bad '{"subject":"thing/subaru","attr":"location","value":1,"at":"yesterday","source":{"kind":"user"}}')))
    (expect-eq !>('conf: 0 to 100') !>((bad '{"subject":"thing/subaru","attr":"location","value":1,"conf":101,"source":{"kind":"user"}}')))
    (expect-eq !>('conf: 0 to 100') !>((bad '{"subject":"thing/subaru","attr":"location","value":1,"conf":-5,"source":{"kind":"user"}}')))
    (expect-eq !>('conf: 0 to 100') !>((bad '{"subject":"thing/subaru","attr":"location","value":1,"conf":"high","source":{"kind":"user"}}')))
    (expect-eq !>('source.kind: required') !>((bad '{"subject":"thing/subaru","attr":"location","value":1}')))
  ==
++  test-de-action-ok
  =/  got
    %^  de-action:orr
      (jo '{"kind":"task","title":"Call John\'s Machine Shop about the Subaru","about":["thing/subaru","place/johns-machine-shop"],"due":"2026-09-17T13:00:00Z","proposed":"2026-09-17T03:00:00Z"}')
    t0  'mcp'
  ?.  ?=(%& -.got)  (expect !>(|))
  ;:  weld
    (expect-eq !>(%task) !>(kind.p.got))
    (expect-eq !>(`(set @t)`(sy ~['thing/subaru' 'place/johns-machine-shop'])) !>(about.p.got))
    (expect-eq !>(`(unit @da)`[~ ~2026.9.17..13.00.00]) !>(due.p.got))
    (expect-eq !>(~2026.9.17..3.00.00) !>(proposed.p.got))
    (expect-eq !>(%proposed) !>(status.p.got))
    (expect-eq !>('mcp') !>(by.p.got))
    (expect-eq !>(`json`~) !>(payload.p.got))
  ==
++  test-de-action-refusals
  =/  bad
    |=  t=@t
    ^-  @t
    =/  got  (de-action:orr (jo t) t0 'mcp')
    ?:(?=(%| -.got) p.got 'accepted')
  ;:  weld
    (expect-eq !>('title: 1 to 200 bytes') !>((bad '{"kind":"task"}')))
    (expect-eq !>('kind: lowercase, digits and hyphens, at most 24 bytes') !>((bad '{"kind":"Task","title":"x"}')))
    (expect-eq !>('about: expected <kind>/<slug> entries') !>((bad '{"kind":"task","title":"x","about":["subaru"]}')))
    (expect-eq !>('payload: an object, or absent') !>((bad '{"kind":"task","title":"x","payload":"notes"}')))
  ==
++  test-fill-defaults
  =/  j=json  (fill-obs:orr (jo '{"subject":"person/me","attr":"status","value":1}') t0 'http')
  =/  k=json  (fill-act:orr (jo '{"kind":"task","title":"x","by":"user"}') t0 'http')
  ;:  weld
    (expect-eq !>('2026-09-16T22:05:00Z') !>((gs:orr j 'at')))
    (expect-eq !>('http') !>((gs:orr j 'by')))
    (expect-eq !>('keep') !>((gs:orr (fill-obs:orr (jo '{"at":"keep"}') t0 'http') 'at')))
    (expect-eq !>('2026-09-16T22:05:00Z') !>((gs:orr k 'proposed')))
    (expect-eq !>('user') !>((gs:orr k 'by')))
  ==
++  test-prep-observe
  =/  got
    %^  prep-observe:orr
      (jo '{"bodies":[{"id":"place/home"},{"id":"bad"}],"observations":[{"subject":"person/me","attr":"home","value":{"ref":"place/home"},"source":{"kind":"user"}}]}')
    t0  'http'
  ;:  weld
    (expect-eq !>(2) !>((lent bodies.got)))
    (expect-eq !>(1) !>((lent obs.got)))
    (expect !>(?=([%& *] (snag 0 bodies.got))))
    (expect !>(?=([%| *] (snag 1 bodies.got))))
    (expect !>(?=([%& *] (snag 0 obs.got))))
  ==
::
::  ==  readers and merge
::
++  test-readers
  =/  b=body:orr  [%person 'Sarah' (sy ~['Sarah']) t0]
  ;:  weld
    (expect-eq !>(`(unit body:orr)`[~ b]) !>((read-body:orr [%1 b])))
    (expect-eq !>(`(unit body:orr)`~) !>((read-body:orr [%2 'nope'])))
    (expect-eq !>(`(unit obs:orr)`[~ o1]) !>((read-obs:orr [%1 o1])))
    (expect-eq !>(`(unit obs:orr)`~) !>((read-obs:orr 'garbage')))
  ==
++  test-merge-body
  =/  old=body:orr  [%person 'Sarah' (sy ~['Sarah']) t0]
  =/  new=body:orr  [%person '' (sy ~['wife']) (add t0 ~d1)]
  =/  got=body:orr  (merge-body:orr old new)
  ;:  weld
    (expect-eq !>('Sarah') !>(name.got))
    (expect-eq !>(`(set @t)`(sy ~['Sarah' 'wife'])) !>(aliases.got))
    (expect-eq !>(t0) !>(created.got))
    (expect-eq !>('Sarah B') !>(name:(merge-body:orr old new(name 'Sarah B'))))
    (expect-eq !>('sarah') !>((fresh-name:orr %sarah '')))
    (expect-eq !>('Sarah') !>((fresh-name:orr %sarah 'Sarah')))
  ==
--
```

- [ ] **Step 2: Run the tests and watch them fail**

Copy only the test file (the library does not exist yet) and run per the recipe under "Working with the dev ship":

```bash
cp tests/lib/orrery.hoon <the dev ship's mount>/tests/lib/orrery.hoon
# in the dojo: |commit %grubbery
# then read the dojo output
```

Read `<rev>` off the `+ /~sampel-sipnym/grubbery/<rev>/tests/lib/orrery/hoon` line, then:

```bash
# in the dojo: -test /~sampel-sipnym/grubbery/<rev>/tests/lib/orrery ~
# then read the dojo output
```

Expected: a build failure naming `/lib/orrery/hoon` as missing (a `%file-not-found` or `dep failed` line), no `OK` lines.

- [ ] **Step 3: Write the library**

`code/lib/orrery.hoon`:

```hoon
::  orrery: the model, pure. See docs/superpowers/specs/2026-09-16-orrery-design.md.
::
::    Import-free on purpose: the same file builds in the clay desk's
::    /lib, where -test reaches it, and in the app's code namespace,
::    where the nexus wraps it. Nothing here touches a ship: no bowl,
::    no roads, no vases.
::
|%
::  ==  the three shapes
::
+$  bid     @t                                  ::  "<kind>/<slug>"
+$  body    [kind=@tas name=@t aliases=(set @t) created=@da]
+$  source  [kind=@t id=@t]
+$  obs
  $:  subject=bid
      attr=@t
      value=json
      at=@da                                    ::  when it became true
      until=(unit @da)                          ::  expected end
      conf=@ud                                  ::  0 to 100
      =source
      by=@t
      seen=@da                                  ::  when the ship recorded it
      retracted=?
      note=@t                                   ::  why it was retracted
  ==
+$  action
  $:  kind=@tas
      title=@t
      payload=json
      about=(set bid)
      due=(unit @da)
      by=@t
      proposed=@da
      status=@tas
      note=@t
  ==
::  what the grubs hold: a version head in front of each shape, so a
::  later shape is told apart by the reader instead of clamming by luck
::
+$  stored-body    [%1 =body]
+$  stored-obs     [%1 =obs]
+$  stored-action  [%1 =action]
::  an observation with the grub name it lives under
::
+$  row  [id=@ta =obs]
::  ==  caps, the spec's
::
++  max-kind       24
++  max-slug       64
++  max-name       200
++  max-alias      100
++  max-aliases    32
++  max-attr       48
++  max-value      2.000
++  max-source-id  200
++  max-by         64
++  max-title      200
++  max-payload    4.000
++  max-note       500
++  max-about      20
++  max-bodies     50
++  max-obs        200
::  ==  names
::
::  +ok-chars: lowercase ascii, digits and hyphens, at most max bytes,
::  and when head-alpha is set the first byte is a letter
::
++  ok-chars
  |=  [t=@t max=@ud head-alpha=?]
  ^-  ?
  =/  tap=tape  (trip t)
  ?:  |(=(~ tap) (gth (lent tap) max))  |
  =/  ok-c
    |=  c=@
    ?|  &((gte c 'a') (lte c 'z'))
        &((gte c '0') (lte c '9'))
        =(c '-')
    ==
  ?.  (levy `tape`tap ok-c)  |
  =/  hed=@  (snag 0 `tape`tap)
  ?:  head-alpha  &((gte hed 'a') (lte hed 'z'))
  !=(hed '-')
++  ok-kind  |=(t=@t (ok-chars t max-kind &))
++  ok-slug  |=(t=@t (ok-chars t max-slug |))
++  ok-attr  |=(t=@t (ok-chars t max-attr &))
::  +parse-bid: "person/sarah" to its kind and slug, or ~
::
++  parse-bid
  |=  t=@t
  ^-  (unit [kind=@tas slug=@ta])
  =/  tap=tape  (trip t)
  =/  at=(unit @ud)  (find "/" tap)
  ?~  at  ~
  =/  k=@t  (crip (scag u.at tap))
  =/  s=@t  (crip (slag +(u.at) tap))
  ?.  &((ok-kind k) (ok-slug s))  ~
  `[`@tas`k `@ta`s]
++  make-bid  |=([kind=@tas slug=@ta] ^-(bid (rap 3 kind '/' slug ~)))
::  ==  time
::
::  +unix-secs: seconds since 1970, 0 before it
::
++  unix-secs
  |=  d=@da
  ^-  @ud
  ?:  (lth d ~1970.1.1)  0
  (div (sub d ~1970.1.1) ~s1)
::  +de-iso: "2026-09-16T22:05:00Z" (a fraction is allowed and dropped,
::  Z only) to a @da, or ~
::
++  de-iso
  |=  t=@t
  ^-  (unit @da)
  =/  two   (bass 10 (stun [2 2] dit))
  =/  four  (bass 10 (stun [4 4] dit))
  =/  rule
    ;~  plug
      four
      ;~(pfix hep two)
      ;~(pfix hep two)
      ;~(pfix (just 'T') two)
      ;~(pfix col two)
      ;~(pfix col two)
      (punt ;~(pfix dot (plus dit)))
      (cold ~ (just 'Z'))
    ==
  =/  got  (rush t rule)
  ?~  got  ~
  =/  [y=@ud mo=@ud d=@ud h=@ud mi=@ud s=@ud *]  u.got
  ?.  ?&  (gte mo 1)   (lte mo 12)
          (gte d 1)    (lte d 31)
          (lth h 24)   (lth mi 60)  (lth s 60)
      ==
    ~
  `(year [[& y] mo d h mi s ~])
::  +en-iso: a @da to "2026-09-16T22:05:00Z", whole seconds
::
++  en-iso
  |=  when=@da
  ^-  @t
  =/  [[* y=@ud] mo=@ud [d=@ud h=@ud mi=@ud s=@ud *]]  (yore when)
  =/  yy=tape  ((d-co:co 4) y)
  =/  mm=tape  ((d-co:co 2) mo)
  =/  dd=tape  ((d-co:co 2) d)
  =/  hh=tape  ((d-co:co 2) h)
  =/  ii=tape  ((d-co:co 2) mi)
  =/  ss=tape  ((d-co:co 2) s)
  (crip "{yy}-{mm}-{dd}T{hh}:{ii}:{ss}Z")
::  ==  ids
::
::  +hex8: eight lowercase hex digits of a noun's hash
::
++  hex8
  |=  n=*
  ^-  tape
  ((x-co:co 8) (end [3 4] (sham n)))
::  +obs-id: "<unix seconds of at>-<hex8>". by and seen stay outside the
::  hash, so two clients asserting one fact make one grub.
::
++  obs-id
  |=  o=obs
  ^-  @ta
  =/  secs=tape  (a-co:co (unix-secs at.o))
  =/  hex=tape   (hex8 [subject.o attr.o value.o at.o source.o])
  `@ta`(crip "{secs}-{hex}")
::  +act-id: the same shape over a proposal
::
++  act-id
  |=  a=action
  ^-  @ta
  =/  secs=tape  (a-co:co (unix-secs proposed.a))
  =/  hex=tape   (hex8 [kind.a title.a payload.a by.a])
  `@ta`(crip "{secs}-{hex}")
::  ==  json, read without crashing
::
++  gj                                          ::  a key's value, or null
  |=  [jon=json k=@t]
  ^-  json
  ?.  ?=([%o *] jon)  ~
  (fall (~(get by p.jon) k) ~)
++  has-key
  |=  [jon=json k=@t]
  ^-  ?
  ?.  ?=([%o *] jon)  |
  (~(has by p.jon) k)
++  gs                                          ::  a string, or ''
  |=  [jon=json k=@t]
  ^-  @t
  =/  v=json  (gj jon k)
  ?:(?=([%s *] v) p.v '')
++  gn                                          ::  a whole number
  |=  [jon=json k=@t]
  ^-  (unit @ud)
  =/  v=json  (gj jon k)
  ?.  ?=([%n *] v)  ~
  (rush p.v dem)
++  ga                                          ::  an array's items, or ~
  |=  [jon=json k=@t]
  ^-  (list json)
  =/  v=json  (gj jon k)
  ?:(?=([%a *] v) p.v ~)
++  gt                                          ::  an ISO time
  |=  [jon=json k=@t]
  ^-  (unit @da)
  =/  s=@t  (gs jon k)
  ?:(=('' s) ~ (de-iso s))
++  strings                                     ::  the strings in an array
  |=  l=(list json)
  ^-  (list @t)
  (murn l |=(j=json ?:(?=([%s *] j) `p.j ~)))
::  ==  decoders: a request's JSON to a shape, or the field that failed
::
++  value-ok
  |=  v=json
  ^-  ?
  ?~  v  &
  ?-  -.v
    %s  (lte (met 3 p.v) max-value)
    %n  &
    %b  &
    %o  (lte (met 3 (en:json:html v)) max-value)
    %a  |
  ==
::  +de-body: {"id","name","aliases"}. A name '' means "not given".
::
++  de-body
  |=  [jon=json now=@da]
  ^-  (each [id=bid =body] @t)
  =/  id=@t  (gs jon 'id')
  =/  pk  (parse-bid id)
  ?~  pk  [%| 'id: expected <kind>/<slug>, lowercase, digits and hyphens']
  =/  name=@t  (gs jon 'name')
  ?:  (gth (met 3 name) max-name)  [%| 'name: over 200 bytes']
  =/  raw=(list json)  (ga jon 'aliases')
  ?:  (gth (lent raw) max-aliases)  [%| 'aliases: over 32']
  =/  als=(list @t)  (strings raw)
  ?.  =((lent als) (lent raw))  [%| 'aliases: every alias is a string']
  ?:  (lien als |=(a=@t |(=('' a) (gth (met 3 a) max-alias))))
    [%| 'aliases: each 1 to 100 bytes']
  [%& id [kind.u.pk name (sy als) now]]
::  +de-obs: one observation. at defaults to now, conf to 100, by to
::  default-by. seen is now, retracted is no.
::
++  de-obs
  |=  [jon=json now=@da default-by=@t]
  ^-  (each obs @t)
  =/  subject=@t  (gs jon 'subject')
  ?~  (parse-bid subject)  [%| 'subject: expected <kind>/<slug>']
  =/  attr=@t  (gs jon 'attr')
  ?.  (ok-attr attr)
    [%| 'attr: lowercase, digits and hyphens, at most 48 bytes']
  ?.  (has-key jon 'value')  [%| 'value: required']
  =/  value=json  (gj jon 'value')
  ?.  (value-ok value)
    [%| 'value: a string, number, boolean, null or object, at most 2000 bytes']
  ?:  ?&  ?=([%o *] value)
          (~(has by p.value) 'ref')
          =(~ (parse-bid (gs value 'ref')))
      ==
    [%| 'value.ref: expected <kind>/<slug>']
  =/  at=(unit @da)  ?.((has-key jon 'at') `now (gt jon 'at'))
  ?~  at  [%| 'at: expected an ISO 8601 UTC time such as 2026-09-16T22:05:00Z']
  =/  until=(unit @da)  (gt jon 'until')
  ?:  &(?=(~ until) !=(~ (gj jon 'until')))
    [%| 'until: expected an ISO 8601 UTC time, or null']
  =/  conf=(unit @ud)  ?.((has-key jon 'conf') `100 (gn jon 'conf'))
  ?~  conf  [%| 'conf: 0 to 100']
  ?:  (gth u.conf 100)  [%| 'conf: 0 to 100']
  =/  sj=json  (gj jon 'source')
  =/  sk=@t  (gs sj 'kind')
  =/  si=@t  (gs sj 'id')
  ?:  =('' sk)  [%| 'source.kind: required']
  ?:  (gth (met 3 si) max-source-id)  [%| 'source.id: over 200 bytes']
  =/  by=@t  (gs jon 'by')
  =.  by  ?:(=('' by) default-by by)
  ?:  (gth (met 3 by) max-by)  [%| 'by: over 64 bytes']
  [%& subject attr value u.at until u.conf [sk si] by now | '']
::  +de-action: a proposal. proposed is read from the JSON when given
::  (the request fiber stamps it, so its id and the writer's agree).
::
++  de-action
  |=  [jon=json now=@da default-by=@t]
  ^-  (each action @t)
  =/  kind=@t  (gs jon 'kind')
  ?.  (ok-kind kind)
    [%| 'kind: lowercase, digits and hyphens, at most 24 bytes']
  =/  title=@t  (gs jon 'title')
  ?:  |(=('' title) (gth (met 3 title) max-title))  [%| 'title: 1 to 200 bytes']
  =/  payload=json  (gj jon 'payload')
  ?.  |(?=(~ payload) ?=([%o *] payload))  [%| 'payload: an object, or absent']
  ?:  (gth (met 3 (en:json:html payload)) max-payload)  [%| 'payload: over 4000 bytes']
  =/  raw=(list json)  (ga jon 'about')
  ?:  (gth (lent raw) max-about)  [%| 'about: over 20']
  =/  about=(list @t)  (strings raw)
  ?.  =((lent about) (lent raw))  [%| 'about: every entry is a body id']
  ?:  (lien about |=(b=@t =(~ (parse-bid b))))
    [%| 'about: expected <kind>/<slug> entries']
  =/  due=(unit @da)  (gt jon 'due')
  ?:  &(?=(~ due) !=(~ (gj jon 'due')))
    [%| 'due: expected an ISO 8601 UTC time, or null']
  =/  proposed=(unit @da)  ?.((has-key jon 'proposed') `now (gt jon 'proposed'))
  ?~  proposed  [%| 'proposed: expected an ISO 8601 UTC time']
  =/  by=@t  (gs jon 'by')
  =.  by  ?:(=('' by) default-by by)
  ?:  (gth (met 3 by) max-by)  [%| 'by: over 64 bytes']
  [%& `@tas`kind title payload (sy about) due by u.proposed %proposed '']
::  +with-default: set a key on an object only when it is absent
::
++  with-default
  |=  [j=json k=@t v=json]
  ^-  json
  ?.  ?=([%o *] j)  j
  ?:  (~(has by p.j) k)  j
  [%o (~(put by p.j) k v)]
::  +fill-obs, +fill-act: stamp at (or proposed) and by into a request
::  before it goes to the writer, so the id a caller reports and the id
::  the writer makes agree
::
++  fill-obs
  |=  [j=json now=@da by=@t]
  ^-  json
  (with-default (with-default j 'at' s+(en-iso now)) 'by' s+by)
++  fill-act
  |=  [j=json now=@da by=@t]
  ^-  json
  (with-default (with-default j 'proposed' s+(en-iso now)) 'by' s+by)
::  +prep-observe: every body and observation in an observe request,
::  decoded or refused, in order
::
++  prep-observe
  |=  [jon=json now=@da default-by=@t]
  ^-  [bodies=(list (each [id=bid =body] @t)) obs=(list (each obs @t))]
  :-  (turn (ga jon 'bodies') |=(j=json (de-body j now)))
  (turn (ga jon 'observations') |=(j=json (de-obs j now default-by)))
::  ==  readers: a stored noun to its shape, newest shape first, or ~
::
++  read-body
  |=  n=*
  ^-  (unit body)
  =/  r  (mule |.(;;(stored-body n)))
  ?:(?=(%& -.r) `body.p.r ~)
++  read-obs
  |=  n=*
  ^-  (unit obs)
  =/  r  (mule |.(;;(stored-obs n)))
  ?:(?=(%& -.r) `obs.p.r ~)
++  read-action
  |=  n=*
  ^-  (unit action)
  =/  r  (mule |.(;;(stored-action n)))
  ?:(?=(%& -.r) `action.p.r ~)
::  +merge-body: an upsert onto an existing body. A name '' keeps the
::  old name; aliases union; created stays.
::
++  merge-body
  |=  [old=body new=body]
  ^-  body
  :*  kind.old
      ?:(=('' name.new) name.old name.new)
      (~(uni in aliases.old) aliases.new)
      created.old
  ==
::  +fresh-name: a new body with no name is named after its slug
::
++  fresh-name
  |=  [slug=@ta name=@t]
  ^-  @t
  ?:(=('' name) `@t`slug name)
--
```

- [ ] **Step 4: Run the tests and watch them pass**

```bash
cp code/lib/orrery.hoon <the dev ship's mount>/lib/orrery.hoon
# in the dojo: |commit %grubbery
# then read the dojo output
# in the dojo: -test /~sampel-sipnym/grubbery/<rev>/tests/lib/orrery ~
# then read the dojo output
```

Expected: 19 `OK` lines, no `FAILED`, no `CRASHED`, `ok=%.y`. A compile error names the file and the line; fix the library (or the test, when the test is wrong), copy again, commit again, test again. Do not move on with a failing arm.

- [ ] **Step 5: Commit**

```bash
git add code/lib/orrery.hoon tests/lib/orrery.hoon
git commit -m "The model library: shapes, names, time, ids and the decoders, with tests"
```

### Task 3: The library, part two: encoders, the fold, timelines, involved, resolve, action rules

**Files:**
- Modify: `code/lib/orrery.hoon` (append the arms below before the closing `--`)
- Modify: `tests/lib/orrery.hoon` (append the tests below before the closing `--`)

**Interfaces:**
- Consumes: everything Task 2 produced.
- Produces, for Tasks 4 and 5: `en-source`, `en-time`, `en-maybe-time`, `en-body`, `en-obs`, `en-action`; `is-live`, `later`, `find-value`, `fold`; `status-of`, `timeline`; `ref-of`, `refs-in`, `is-closed`, `involved`; `lower`, `resolve`; `is-open`, `transition-ok`, `initial-status`; `multi-of`, `auto-of`, `retention-of`, `push-of`, `starter-policy`, `starter-schema`. Signatures are in the code.

- [ ] **Step 1: Append the failing tests**

Insert before the final `--` of `tests/lib/orrery.hoon`:

```hoon
::
::  ==  the fold
::
++  r  |=([id=@ta o=obs:orr] ^-(row:orr [id o]))
++  mk
  |=  [attr=@t v=json at=@da]
  ^-  obs:orr
  ['thing/subaru' attr v at ~ 90 ['user' ''] 'user' at | '']
::  event time wins over arrival time: a tow receipt that arrives late
::  and speaks of an earlier moment cannot overwrite the present
++  test-fold-latest-at-wins
  =/  a  (r 'a' (mk 'location' s+'Route 9' t0))
  =/  b  (r 'b' (mk 'location' s+'shop' (add t0 ~h4)))
  =/  c  (r 'c' (mk 'location' s+'tow truck' (add t0 ~h1)))
  =.  seen.obs.c  (add t0 ~h6)
  =/  w  (fold:orr ~[a b c] ~ (add t0 ~d1))
  =/  loc=(list row:orr)  (fall (~(get by w) 'location') ~)
  ;:  weld
    (expect-eq !>(1) !>((lent loc)))
    (expect-eq !>('b') !>(?~(loc '' id.i.loc)))
  ==
++  test-fold-as-of
  =/  a  (r 'a' (mk 'location' s+'Route 9' t0))
  =/  b  (r 'b' (mk 'location' s+'shop' (add t0 ~h4)))
  =/  w  (fold:orr ~[a b] ~ (add t0 ~h1))
  =/  loc=(list row:orr)  (fall (~(get by w) 'location') ~)
  (expect-eq !>('a') !>(?~(loc '' id.i.loc)))
++  test-fold-until-expires
  =/  o=obs:orr  (mk 'status' s+'stranded' t0)
  =.  until.o  `(add t0 ~h4)
  ;:  weld
    (expect-eq !>(1) !>(~(wyt by (fold:orr ~[(r 'a' o)] ~ (add t0 ~h1)))))
    (expect-eq !>(0) !>(~(wyt by (fold:orr ~[(r 'a' o)] ~ (add t0 ~h5)))))
  ==
::  a null value wins its slot and clears it; a retracted row is ignored
++  test-fold-retracted-and-null
  =/  a  (r 'a' (mk 'status' s+'stranded' t0))
  =/  b  (r 'b' (mk 'status' ~ (add t0 ~h4)))
  =/  c  (r 'c' (mk 'status' s+'home' (add t0 ~h5)))
  =.  retracted.obs.c  &
  =/  w  (fold:orr ~[a b c] ~ (add t0 ~d1))
  =/  st=(list row:orr)  (fall (~(get by w) 'status') ~)
  ;:  weld
    (expect-eq !>('b') !>(?~(st '' id.i.st)))
    (expect-eq !>(`json`~) !>(?~(st `json`~ value.obs.i.st)))
  ==
++  test-fold-multi
  =/  multi=(set @t)  (sy ~['participants'])
  =/  a  (r 'a' (mk 'participants' (jo '{"ref":"person/me"}') t0))
  =/  b  (r 'b' (mk 'participants' (jo '{"ref":"person/sarah"}') (add t0 ~m1)))
  =/  c  (r 'c' (mk 'participants' (jo '{"ref":"person/me"}') (add t0 ~m2)))
  =/  w  (fold:orr ~[a b c] multi (add t0 ~d1))
  =/  ps=(list row:orr)  (fall (~(get by w) 'participants') ~)
  ;:  weld
    (expect-eq !>(2) !>((lent ps)))
    (expect !>((lien ps |=(x=row:orr =('c' id.x)))))
    (expect !>(!(lien ps |=(x=row:orr =('a' id.x)))))
  ==
++  test-status-and-timeline
  =/  a  (r 'a' (mk 'location' s+'Route 9' t0))
  =/  b  (r 'b' (mk 'location' s+'shop' (add t0 ~h4)))
  =/  c  (r 'c' (mk 'status' s+'stranded' t0))
  =.  until.obs.c  `(add t0 ~h2)
  =/  d  (r 'd' (mk 'mood' s+'grim' t0))
  =.  retracted.obs.d  &
  =/  when  (add t0 ~d1)
  =/  w  (fold:orr ~[a b c d] ~ when)
  =/  tl  (timeline:orr ~[a b c d] w when)
  =/  st
    |=  id=@ta
    ^-  @tas
    =/  f  (skim tl |=(x=[r=row:orr status=@tas] =(id id.r.x)))
    ?~(f %none status.i.f)
  ;:  weld
    (expect-eq !>(%superseded) !>((st 'a')))
    (expect-eq !>(%live) !>((st 'b')))
    (expect-eq !>(%expired) !>((st 'c')))
    (expect-eq !>(%retracted) !>((st 'd')))
    (expect-eq !>('b') !>(?~(tl '' id.r.i.tl)))
  ==
::
::  ==  involved and resolve
::
++  test-involved
  =/  multi=(set @t)  (sy ~['participants'])
  =/  sit-open
    %-  fold:orr
    :+  ~[(r 'a' (mk 'participants' (jo '{"ref":"person/sarah"}') t0)) (r 'b' (mk 'status' s+'open' t0))]
      multi
    (add t0 ~d1)
  =/  sit-closed
    %-  fold:orr
    :+  ~[(r 'c' (mk 'participants' (jo '{"ref":"person/sarah"}') t0)) (r 'd' (mk 'status' s+'closed' t0))]
      multi
    (add t0 ~d1)
  =/  sits=(list [id=bid:orr winners=(map @t (list row:orr))])
    ~[['situation/one' sit-open] ['situation/two' sit-closed]]
  ;:  weld
    (expect-eq !>(`(list bid:orr)`~['situation/one']) !>((involved:orr 'person/sarah' sits)))
    (expect-eq !>(`(list bid:orr)`~) !>((involved:orr 'person/me' sits)))
  ==
++  test-resolve
  =/  bodies=(list [id=bid:orr =body:orr])
    :~  ['person/sarah' [%person 'Sarah' (sy ~['wife']) t0]]
        ['place/johns-machine-shop' [%place 'John\'s Machine Shop' (sy ~['John\'s' 'the shop']) t0]]
        ['thing/subaru' [%thing 'The Subaru' (sy ~['the car']) t0]]
    ==
  =/  ids
    |=  q=@t
    ^-  (list bid:orr)
    (turn (resolve:orr q bodies) |=(h=[id=bid:orr =body:orr match=@tas] id.h))
  ;:  weld
    (expect-eq !>(`(list bid:orr)`~['person/sarah']) !>((ids 'sarah')))
    (expect-eq !>(`(list bid:orr)`~['person/sarah']) !>((ids 'WIFE')))
    (expect-eq !>(`(list bid:orr)`~['place/johns-machine-shop']) !>((ids 'john\'s')))
    (expect-eq !>(`(list bid:orr)`~['thing/subaru']) !>((ids 'the c')))
    (expect-eq !>(`(list bid:orr)`~) !>((ids 'zzz')))
    (expect-eq !>(`(list bid:orr)`~) !>((ids '')))
  ==
::
::  ==  actions, policy, encoders
::
++  test-action-rules
  =/  auto  (auto-of:orr starter-policy:orr)
  ;:  weld
    (expect !>((transition-ok:orr %proposed %approved)))
    (expect !>((transition-ok:orr %approved %done)))
    (expect !>(!(transition-ok:orr %proposed %done)))
    (expect !>(!(transition-ok:orr %done %approved)))
    (expect-eq !>(%approved) !>((initial-status:orr %task auto)))
    (expect-eq !>(%proposed) !>((initial-status:orr %message auto)))
    (expect-eq !>(365) !>((retention-of:orr starter-policy:orr)))
    (expect !>((push-of:orr starter-policy:orr)))
    (expect !>((~(has in (multi-of:orr starter-schema:orr)) 'participants')))
  ==
++  test-encoders-roundtrip
  =/  j=json  (en-obs:orr (r 'x' o1) %live)
  =/  back  (de-obs:orr j t0 'http')
  ?.  ?=(%& -.back)  (expect !>(|))
  ;:  weld
    (expect-eq !>(subject:o1) !>(subject.p.back))
    (expect-eq !>(value:o1) !>(value.p.back))
    (expect-eq !>(at:o1) !>(at.p.back))
    (expect-eq !>('live') !>((gs:orr j 'status')))
    (expect-eq !>('Sarah') !>((gs:orr (en-body:orr 'person/sarah' [%person 'Sarah' ~ t0]) 'name')))
  ==
```

- [ ] **Step 2: Run the tests and watch the new ones fail**

Copy the test file, commit, run (recipe under "Working with the dev ship"). Expected: a build failure naming an unknown arm such as `fold` (`-find.fold`), because the library lacks part two. The 18 arms from Task 2 do not run either; that is expected, the file does not compile.

- [ ] **Step 3: Append the arms to the library**

Insert before the final `--` of `code/lib/orrery.hoon`:

```hoon
::  ==  encoders
::
++  en-source
  |=  s=source
  ^-  json
  (pairs:enjs:format ~[['kind' s+kind.s] ['id' s+id.s]])
++  en-time  |=(d=@da ^-(json s+(en-iso d)))
++  en-maybe-time  |=(d=(unit @da) ^-(json ?~(d ~ (en-time u.d))))
++  en-body
  |=  [id=bid b=body]
  ^-  json
  %-  pairs:enjs:format
  :~  ['id' s+id]
      ['kind' s+kind.b]
      ['name' s+name.b]
      ['aliases' a+(turn ~(tap in aliases.b) |=(t=@t `json`s+t))]
      ['created' (en-time created.b)]
  ==
++  en-obs
  |=  [r=row status=@tas]
  ^-  json
  =/  o=obs  obs.r
  %-  pairs:enjs:format
  :~  ['id' s+id.r]
      ['subject' s+subject.o]
      ['attr' s+attr.o]
      ['value' value.o]
      ['at' (en-time at.o)]
      ['until' (en-maybe-time until.o)]
      ['conf' (numb:enjs:format conf.o)]
      ['source' (en-source source.o)]
      ['by' s+by.o]
      ['seen' (en-time seen.o)]
      ['status' s+status]
      ['note' s+note.o]
  ==
++  en-action
  |=  [id=@ta a=action]
  ^-  json
  %-  pairs:enjs:format
  :~  ['id' s+id]
      ['kind' s+kind.a]
      ['title' s+title.a]
      ['payload' payload.a]
      ['about' a+(turn ~(tap in about.a) |=(t=@t `json`s+t))]
      ['due' (en-maybe-time due.a)]
      ['by' s+by.a]
      ['proposed' (en-time proposed.a)]
      ['status' s+status.a]
      ['note' s+note.a]
  ==
::  ==  the fold: live observations to current attributes
::
::  +is-live: not retracted, already true at when, not yet expired
::
++  is-live
  |=  [o=obs when=@da]
  ^-  ?
  ?&  !retracted.o
      (lte at.o when)
      ?~(until.o & (gth u.until.o when))
  ==
::  +later: a wins over b: the later at, then the later seen
::
++  later
  |=  [a=row b=row]
  ^-  ?
  ?:  =(at.obs.a at.obs.b)  (gth seen.obs.a seen.obs.b)
  (gth at.obs.a at.obs.b)
++  find-value
  |=  [rs=(list row) v=json]
  ^-  (unit row)
  ?~  rs  ~
  ?:  =(value.obs.i.rs v)  `i.rs
  $(rs t.rs)
::  +fold: attr to its winners. A single-valued attr keeps the latest
::  row; a multi-valued one (named in multi) keeps the latest row per
::  distinct value. A null value on a multi attr contributes nothing.
::
++  fold
  |=  [rows=(list row) multi=(set @t) when=@da]
  ^-  (map @t (list row))
  =/  live=(list row)  (skim rows |=(r=row (is-live obs.r when)))
  %+  roll  live
  |=  [r=row acc=(map @t (list row))]
  =/  attr=@t  attr.obs.r
  =/  cur=(list row)  (fall (~(get by acc) attr) ~)
  ?.  (~(has in multi) attr)
    ?~  cur  (~(put by acc) attr ~[r])
    ?:  (later r i.cur)  (~(put by acc) attr ~[r])
    acc
  ?~  value.obs.r  acc
  =/  same=(unit row)  (find-value cur value.obs.r)
  ?~  same  (~(put by acc) attr [r cur])
  ?.  (later r u.same)  acc
  =/  rest=(list row)  (skip cur |=(x=row =(value.obs.x value.obs.r)))
  (~(put by acc) attr [r rest])
::  +status-of: what a row is, seen from when, given the winners
::
++  status-of
  |=  [r=row winners=(map @t (list row)) when=@da]
  ^-  @tas
  ?:  retracted.obs.r  %retracted
  ?:  ?&(?=(^ until.obs.r) (lte u.until.obs.r when))  %expired
  ?:  (gth at.obs.r when)  %future
  =/  w=(list row)  (fall (~(get by winners) attr.obs.r) ~)
  ?:  (lien w |=(x=row =(id.x id.r)))  %live
  %superseded
::  +timeline: every row newest first, each with its status
::
++  timeline
  |=  [rows=(list row) winners=(map @t (list row)) when=@da]
  ^-  (list [r=row status=@tas])
  =/  sorted=(list row)  (sort rows later)
  (turn sorted |=(r=row [r (status-of r winners when)]))
::  ==  reverse references
::
::  +ref-of: the body a {"ref"} value names, or ~
::
++  ref-of
  |=  v=json
  ^-  (unit bid)
  =/  r=@t  (gs v 'ref')
  ?:(=('' r) ~ `r)
++  refs-in
  |=  rs=(list row)
  ^-  (list bid)
  (murn rs |=(r=row (ref-of value.obs.r)))
::  +is-closed: a situation is closed only when its status is "closed"
::
++  is-closed
  |=  winners=(map @t (list row))
  ^-  ?
  =/  w=(list row)  (fall (~(get by winners) 'status') ~)
  ?~  w  |
  =(value.obs.i.w [%s 'closed'])
::  +involved: the open situations whose participants name target
::
++  involved
  |=  [target=bid sits=(list [id=bid winners=(map @t (list row))])]
  ^-  (list bid)
  %+  murn  sits
  |=  [id=bid winners=(map @t (list row))]
  ^-  (unit bid)
  ?:  (is-closed winners)  ~
  =/  ps=(list row)  (fall (~(get by winners) 'participants') ~)
  ?.  (lien (refs-in ps) |=(b=bid =(b target)))  ~
  `id
::  ==  resolve
::
++  lower  |=(t=@t ^-(@t (crip (cass (trip t)))))
::  +resolve: bodies whose name or alias equals q, then those where one
::  starts with q, case-insensitive, at most 20
::
++  resolve
  |=  [q=@t bodies=(list [id=bid =body])]
  ^-  (list [id=bid =body match=@tas])
  =/  lq=@t  (lower q)
  ?:  =('' lq)  ~
  =/  hit
    |=  [id=bid b=body]
    ^-  (unit [id=bid =body match=@tas])
    =/  names=(list @t)  (turn `(list @t)`[name.b ~(tap in aliases.b)] lower)
    ?:  (lien names |=(n=@t =(n lq)))  `[id b %exact]
    ?:  (lien names |=(n=@t =(lq (end [3 (met 3 lq)] n))))  `[id b %prefix]
    ~
  =/  hits=(list [id=bid =body match=@tas])  (murn bodies hit)
  =/  exact  (skim hits |=(h=[id=bid =body match=@tas] =(%exact match.h)))
  =/  pref   (skim hits |=(h=[id=bid =body match=@tas] =(%prefix match.h)))
  (scag 20 (weld exact pref))
::  ==  actions
::
++  is-open  |=(a=action ^-(? |(=(%proposed status.a) =(%approved status.a))))
::  +transition-ok: proposed to approved or dismissed; approved to done,
::  failed or dismissed. Nothing leaves done, failed or dismissed.
::
++  transition-ok
  |=  [cur=@tas want=@tas]
  ^-  ?
  ?+  cur  |
    %proposed  |(=(%approved want) =(%dismissed want))
    %approved  |(=(%done want) =(%failed want) =(%dismissed want))
  ==
++  initial-status
  |=  [kind=@tas auto=(set @t)]
  ^-  @tas
  ?:((~(has in auto) `@t`kind) %approved %proposed)
::  ==  schema and policy
::
++  multi-of      |=(schema=json ^-((set @t) (sy (strings (ga schema 'multi')))))
++  auto-of       |=(policy=json ^-((set @t) (sy (strings (ga policy 'auto')))))
++  retention-of  |=(policy=json ^-(@ud (fall (gn policy 'retention_days') 365)))
++  push-of       |=(policy=json ^-(? =([%b &] (gj policy 'push'))))
++  starter-policy
  ^-  json
  %-  pairs:enjs:format
  :~  ['auto' a+~[s+'task' s+'note']]
      ['push' b+&]
      ['retention_days' (numb:enjs:format 365)]
  ==
++  starter-schema
  ^-  json
  =/  kind
    |=  attrs=(list @t)
    ^-  json
    (pairs:enjs:format ~[['attrs' a+(turn attrs |=(t=@t `json`s+t))]])
  %-  pairs:enjs:format
  :~  :-  'kinds'
      %-  pairs:enjs:format
      :~  ['person' (kind ~['status' 'location' 'phone' 'email' 'ship' 'birthday' 'relationship' 'employer' 'timezone' 'likes' 'dislikes'])]
          ['place' (kind ~['type' 'address' 'phone' 'hours' 'geo'])]
          ['thing' (kind ~['type' 'status' 'location' 'owner' 'make' 'model' 'plate' 'last-service' 'warranty-until'])]
          ['org' (kind ~['type' 'phone' 'email' 'website' 'contact' 'address'])]
          ['situation' (kind ~['status' 'participants' 'location' 'started' 'ended' 'summary'])]
          ['note' (kind ~['text'])]
      ==
      ['multi' a+(turn ~['participants' 'likes' 'dislikes' 'household' 'vehicles' 'children' 'owners' 'members' 'aware-of'] |=(t=@t `json`s+t))]
      ['actions' a+(turn ~['task' 'note' 'message' 'calendar'] |=(t=@t `json`s+t))]
  ==
```

- [ ] **Step 4: Run the tests and watch them pass**

Copy both files, commit, run (recipe under "Working with the dev ship"). Expected: 29 `OK` lines, no `FAILED`, no `CRASHED`, `ok=%.y`. Fix and rerun until green.

- [ ] **Step 5: Commit**

```bash
git add code/lib/orrery.hoon tests/lib/orrery.hoon
git commit -m "The model library: encoders, the fold, timelines, involved, resolve and the action rules, with tests"
```

### Task 4: The nexus: tree, writer, HTTP, and the install on the dev ship

**Files:**
- Create: `code/nex/orrery/app.hoon`
- Create: `code/nex/orrery/icon.svg` (a copy of `code/icon.svg`; the nexus imports the one beside it)

**Interfaces:**
- Consumes: the library from Tasks 2 and 3, the marcs and manifest from Task 1.
- Produces: the writer ops `ensure-me`, `observe`, `upsert-body` (JSON pokes at `/main.sig` carrying `"op"`); the routes `GET /apps/orrery/api/state` and `POST /apps/orrery/api/observe`; the helper arms Task 5 extends: `rf`, `rv`, `body-dir`, `obs-dir`, `srv`, `read-json`, `load-bodies`, `loaded`, `en-attrs`, `when-arg`, `send-json`, `send-err`, `note`, `refuse`, `bump-beacon`, `write-body`, `ensure-dirs`, `handle-request`, `apply`.

- [ ] **Step 1: Write the nexus**

```bash
cp code/icon.svg code/nex/orrery/icon.svg
```

`code/nex/orrery/app.hoon`:

```hoon
::  orrery: a model of the user's world. docs/superpowers/specs/2026-09-16-orrery-design.md
::
::  The tree this nexus owns (every persistent path has a row in +on-load):
::    /main.sig                        the writer: every mutation goes through it
::    /web.sig                         binds /apps/orrery; one fiber per request
::    /requests/<id>                   the ephemeral request fibers
::    /bodies/<kind>/<slug>/body       [/orrery %body]
::    /bodies/<kind>/<slug>/obs/<oid>  [/orrery %obs]
::    /actions/<aid>                   [/orrery %action]
::    /schema.json  /policy.json       seeded once; edits survive a reload
::    /beacon/rev                      the change beacon, nested so it streams
::    /tr/last                         the last writer outcome, as json
::
::  ROADS ARE NEXUS-RELATIVE. A desk-installed app cannot learn its own
::  absolute path, so every road is [%| up lane], where up is the number
::  of steps from the calling fiber to the nexus root: 0 for the writer
::  and the binder, 1 for a request fiber at /requests/<id>.
::
::  THE WRITER MUST NOT CRASH. +rise-wait restarts a failed process by
::  consuming the next poke without processing it, so every refusal is a
::  branch that returns cleanly and writes /tr/last.
::
/<  orr   /lib/orrery.hoon
/&  icon  icon.svg
=<  ^-  nexus:nexus
    |%
    ++  on-load
      |=  =ball:tarball
      ^-  bole:tarball
      =/  tile=json
        %-  pairs:enjs:format
        :~  title+s+'Orrery'
            info+s+'What is going on in your world'
            color+s+'#101541'
            image+s+'/grubbery/tiles/icon/orrery'
            href+s+'/apps/orrery'
        ==
      =/  link=json
        (pairs:enjs:format ~[['name' s+'orrery'] ['description' s+'A model of your world']])
      %+  spin:loader  ball
      :~  (manifest:loader 0)
          [%over %& [/ %'tile.json'] [[/ %json] tile]]
          [%over %& [/ %'link.json'] [[/ %json] link]]
          [%over %& [/ %'weir.json'] [[/ %json] weir-json]]
          [%over %& [/ %'icon.svg'] [[/ %mime] icon]]
          [%fall %& [/ %'main.sig'] [[/ %sig] ~]]
          [%fall %& [/ %'web.sig'] [[/ %sig] ~]]
          [%fall %| /requests empty-dir:loader]
          [%fall %| /bodies empty-dir:loader]
          [%fall %| /actions empty-dir:loader]
          [%fall %| /tr empty-dir:loader]
          [%fall %| /beacon empty-dir:loader]
          [%fall %& [/ %'schema.json'] [[/ %json] starter-schema:orr]]
          [%fall %& [/ %'policy.json'] [[/ %json] starter-policy:orr]]
          [%fall %& [/beacon %rev] [[/ %json] (numb:enjs:format 0)]]
          [%fall %& [/tr %last] [[/ %json] [%o ~]]]
      ==
    ::
    ++  on-file
      |=  [=rail:tarball =blot:tarball]
      ^-  spool:fiber:nexus
      |=  =prod:fiber:nexus
      =/  m  (fiber:fiber:nexus ,~)
      ^-  process:fiber:nexus
      ?+    rail  stay:m
          ::  the writer. It reaches nothing at rise: a jailed install
          ::  (weir not yet approved) would have every bowl poke vetoed,
          ::  and a crashed writer waits for the next poke before it
          ::  runs again. person/me is laid by the first request instead.
          [~ %'main.sig']
        ;<  ~  bind:m  (rise-wait:io prod "%orrery writer: failed")
        |-
        ;<  [=from:fiber:nexus =sage:tarball]  bind:m  take-poke-from:io
        ;<  changed=?  bind:m  (apply from sage)
        ;<  ~  bind:m  ?.(changed (pure:m ~) bump-beacon)
        $
          ::  the HTTP binder. bind-http-self is veto-tolerant: jailed,
          ::  it logs and waits; the approval reload binds for real.
          [~ %'web.sig']
        ;<  ~  bind:m  (rise-wait:io prod "%orrery web: failed")
        ;<  ~  bind:m  (bind-http-self:io [~ /apps/orrery])
        (http-dispatch:io %orrery)
          ::  one ephemeral fiber per in-flight request
          [[%requests ~] @]
        ;<  ~  bind:m  (rise-wait:io prod "%orrery request: failed")
        (handle-request name.rail)
      ==
    --
|%
::  ==  roads
::
++  rf  |=([up=@ud p=path n=@ta] ^-(road:tarball [%| up [%& p n]]))
++  rv  |=([up=@ud p=path] ^-(road:tarball [%| up [%| p]]))
++  body-dir  |=([kind=@tas slug=@ta] ^-(path /bodies/[kind]/[slug]))
++  obs-dir   |=([kind=@tas slug=@ta] ^-(path /bodies/[kind]/[slug]/obs))
++  srv  ~(. http-res:io [%| 1 %& ~ %'web.sig'])
::  ==  the ask
::
++  weir-json
  ^-  json
  =/  line  |=([r=@t w=@t] `json`(pairs:enjs:format ~[['road' s+r] ['why' s+w]]))
  %-  pairs:enjs:format
  :~  :-  'poke'
      :-  %a
      :~  (line '/sys/bowl.sig' 'read the current time and our ship')
          (line '/sys/eyre/' 'bind /apps/orrery and answer requests')
          (line '/sys/push/' 'notify you when the assistant proposes or files an action. Refuse this and proposals wait silently in the inbox')
      ==
      :-  'peek'
      :-  %a
      :~  (line '/sys/link/' 'find where this app is installed, so the page can address its own writer')
      ==
      ['make' [%a ~]]
  ==
::  ==  the writer
::
::  +apply: one op from a poke. Answers whether the tree changed.
::
++  apply
  |=  [=from:fiber:nexus =sage:tarball]
  =/  m  (fiber:fiber:nexus ,?)
  ^-  form:m
  ?.  =([/ %json] p.sage)  (pure:m |)
  ;<  our=@p  bind:m  get-our:io
  ::  +get-poke-src reads the ship off the transport. ~ is a fiber
  ::  inside this nexus; our own ship arrives named through the
  ::  agent-facing surface. Anything else is refused.
  =/  src=(unit @p)  (get-poke-src:io from)
  ?.  ?|(?=(~ src) =(our u.src))
    (refuse 'poke' 'a foreign ship may not write here')
  =/  jon=json  (fall (mole |.(!<(json q.sage))) ~)
  =/  op=@t  (gs:orr jon 'op')
  ?:  =('ensure-me' op)  ensure-me
  ?:  =('observe' op)  (do-observe jon)
  ?:  =('upsert-body' op)  (do-upsert-body jon)
  (refuse op 'unknown op')
::  +refuse: a refusal that leaves the writer standing
::
++  refuse
  |=  [op=@t why=@t]
  =/  m  (fiber:fiber:nexus ,?)
  ^-  form:m
  ;<  ~  bind:m  (note op | why)
  (pure:m |)
::  +note: the last writer outcome, at /tr/last. Fiber prints reach only
::  the raw console; a grub is readable by every tool.
::
++  note
  |=  [op=@t ok=? why=@t]
  =/  m  (fiber:fiber:nexus ,~)
  ^-  form:m
  ;<  now=@da  bind:m  get-time:io
  %+  over:io  (rf 0 /tr %last)
  :-  [/ %json]
  ^-  json
  (pairs:enjs:format ~[['op' s+op] ['ok' b+ok] ['why' s+why] ['at' (en-time:orr now)]])
::  +bump-beacon: the change beacon moves once per op that changed the
::  tree, never on a refusal or a no-op
::
++  bump-beacon
  =/  m  (fiber:fiber:nexus ,~)
  ^-  form:m
  ;<  now=@da  bind:m  get-time:io
  (over:io (rf 0 /beacon %rev) [[/ %json] (numb:enjs:format `@ud`now)])
::  +ensure-me: person/me, named "me", with the aliases me, I and our @p
::
++  ensure-me
  =/  m  (fiber:fiber:nexus ,?)
  ^-  form:m
  ;<  ex=?  bind:m  (peek-exists:io (rf 0 (body-dir %person %me) %body))
  ?:  ex  (pure:m |)
  ;<  our=@p  bind:m  get-our:io
  ;<  now=@da  bind:m  get-time:io
  =/  b=body:orr  [%person 'me' (sy `(list @t)`~['me' 'I' (scot %p our)]) now]
  (write-body 0 %person %me b)
::  +ensure-dirs: make each directory along base/segs, in order
::
++  ensure-dirs
  |=  [up=@ud base=path segs=(list @ta)]
  =/  m  (fiber:fiber:nexus ,~)
  ^-  form:m
  ?~  segs  (pure:m ~)
  =/  dir=path  (weld base /[i.segs])
  ;<  ex=?  bind:m  (peek-exists:io (rv up dir))
  ;<  ~  bind:m
    ?:  ex  (pure:(fiber:fiber:nexus ,~) ~)
    ;<  *  bind:(fiber:fiber:nexus ,~)  (make-soft:io (rv up dir) &+empty-dir:loader)
    (pure:(fiber:fiber:nexus ,~) ~)
  (ensure-dirs up dir t.segs)
::  +write-body: create a body with retention on, or merge onto the one
::  there: the name and aliases move, the created stamp stays. Answers
::  whether anything changed.
::
++  write-body
  |=  [up=@ud kind=@tas slug=@ta new=body:orr]
  =/  m  (fiber:fiber:nexus ,?)
  ^-  form:m
  ;<  ~  bind:m  (ensure-dirs up / `(list @ta)`~[%bodies kind slug %obs])
  =/  road=road:tarball  (rf up (body-dir kind slug) %body)
  =/  fresh=body:orr  new(name (fresh-name:orr slug name.new))
  ;<  cur=view:nexus  bind:m  (peek:io road ~)
  ?.  ?=([%file *] cur)
    ;<  *  bind:m  (make-gained-soft:io road |+[[[/orrery %body] `stored-body:orr`[%1 fresh]] ~])
    (pure:m &)
  =/  old=(unit body:orr)  (read-body:orr (sang-noun:tarball sang.cur))
  ?~  old
    ;<  ~  bind:m  (over:io road [[/orrery %body] `stored-body:orr`[%1 fresh]])
    (pure:m &)
  =/  merged=body:orr  (merge-body:orr u.old new)
  ?:  =(merged u.old)  (pure:m |)
  ;<  ~  bind:m  (over:io road [[/orrery %body] `stored-body:orr`[%1 merged]])
  (pure:m &)
::  +do-observe: bodies first, then observations. Items that failed to
::  decode are skipped here; the caller already reported them.
::
++  do-observe
  |=  jon=json
  =/  m  (fiber:fiber:nexus ,?)
  ^-  form:m
  ;<  now=@da  bind:m  get-time:io
  =/  prep  (prep-observe:orr jon now 'writer')
  ;<  c1=?  bind:m  (write-bodies bodies.prep |)
  ;<  c2=?  bind:m  (write-obs obs.prep |)
  ;<  ~  bind:m  (note 'observe' & '')
  (pure:m |(c1 c2))
++  write-bodies
  |=  [items=(list (each [id=bid:orr =body:orr] @t)) changed=?]
  =/  m  (fiber:fiber:nexus ,?)
  ^-  form:m
  ?~  items  (pure:m changed)
  ?:  ?=(%| -.i.items)  (write-bodies t.items changed)
  =/  pk  (parse-bid:orr id.p.i.items)
  ?~  pk  (write-bodies t.items changed)
  ;<  c=?  bind:m  (write-body 0 kind.u.pk slug.u.pk body.p.i.items)
  (write-bodies t.items |(changed c))
::  +write-obs: one grub per observation, under its subject. An unknown
::  subject is noted and skipped; an existing id is a no-op.
::
++  write-obs
  |=  [items=(list (each obs:orr @t)) changed=?]
  =/  m  (fiber:fiber:nexus ,?)
  ^-  form:m
  ?~  items  (pure:m changed)
  ?:  ?=(%| -.i.items)  (write-obs t.items changed)
  =/  o=obs:orr  p.i.items
  =/  pk  (parse-bid:orr subject.o)
  ?~  pk  (write-obs t.items changed)
  ;<  has=?  bind:m  (peek-exists:io (rf 0 (body-dir kind.u.pk slug.u.pk) %body))
  ?.  has
    ;<  ~  bind:m  (note 'observe' | (cat 3 'unknown subject ' subject.o))
    (write-obs t.items changed)
  =/  road=road:tarball  (rf 0 (obs-dir kind.u.pk slug.u.pk) (obs-id:orr o))
  ;<  ex=?  bind:m  (peek-exists:io road)
  ?:  ex  (write-obs t.items changed)
  ;<  *  bind:m  (make-soft:io road |+[[[/orrery %obs] `stored-obs:orr`[%1 o]] ~])
  (write-obs t.items &)
++  do-upsert-body
  |=  jon=json
  =/  m  (fiber:fiber:nexus ,?)
  ^-  form:m
  ;<  now=@da  bind:m  get-time:io
  =/  got  (de-body:orr (gj:orr jon 'body') now)
  ?:  ?=(%| -.got)  (refuse 'upsert-body' p.got)
  =/  pk  (parse-bid:orr id.p.got)
  ?~  pk  (refuse 'upsert-body' 'id: bad')
  ;<  changed=?  bind:m  (write-body 0 kind.u.pk slug.u.pk body.p.got)
  ;<  ~  bind:m  (note 'upsert-body' & '')
  (pure:m changed)
::  ==  reads: walking the tree
::
++  read-json
  |=  road=road:tarball
  =/  m  (fiber:fiber:nexus ,json)
  ^-  form:m
  ;<  vw=view:nexus  bind:m  (peek:io road ~)
  ?.  ?=([%file *] vw)  (pure:m [%o ~])
  (pure:m (fall (mole |.(!<(json (need-vase:tarball sang.vw)))) [%o ~]))
+$  loaded  [id=bid:orr =body:orr rows=(list row:orr)]
::  +load-bodies: every body under /bodies with its observation rows
::
++  load-bodies
  |=  up=@ud
  =/  m  (fiber:fiber:nexus ,(list loaded))
  ^-  form:m
  ;<  vw=view:nexus  bind:m  (peek:io (rv up /bodies) ~)
  ?.  ?=([%ball *] vw)  (pure:m ~)
  (pure:m (bodies-in ball.vw))
++  bodies-in
  |=  b=ball:tarball
  ^-  (list loaded)
  %-  zing
  %+  turn  ~(tap by dir.b)
  |=  [kind=@ta kb=ball:tarball]
  ^-  (list loaded)
  %+  murn  ~(tap by dir.kb)
  |=  [slug=@ta sb=ball:tarball]
  ^-  (unit loaded)
  =/  bf=(unit body:orr)  (body-in sb)
  ?~  bf  ~
  `[(rap 3 kind '/' slug ~) u.bf (rows-in sb)]
++  body-in
  |=  sb=ball:tarball
  ^-  (unit body:orr)
  ?~  fil.sb  ~
  =/  got  (~(get by contents.u.fil.sb) %body)
  ?~  got  ~
  (read-body:orr (sang-noun:tarball sang.u.got))
++  rows-in
  |=  sb=ball:tarball
  ^-  (list row:orr)
  =/  ob=(unit ball:tarball)  (~(get by dir.sb) %obs)
  ?~  ob  ~
  ?~  fil.u.ob  ~
  %+  murn  ~(tap by contents.u.fil.u.ob)
  |=  [nam=@ta c=[=sang:tarball gain=? bang=(unit tang)]]
  ^-  (unit row:orr)
  =/  o=(unit obs:orr)  (read-obs:orr (sang-noun:tarball sang.c))
  ?~  o  ~
  `[nam u.o]
::  +en-attr-row, +en-attrs: a body's current attributes as JSON. A
::  single-valued attr is one object; a multi-valued one an array; a
::  cleared attr (null winner) is absent.
::
++  en-attr-row
  |=  r=row:orr
  ^-  json
  %-  pairs:enjs:format
  :~  ['value' value.obs.r]
      ['at' (en-time:orr at.obs.r)]
      ['until' (en-maybe-time:orr until.obs.r)]
      ['conf' (numb:enjs:format conf.obs.r)]
      ['source' (en-source:orr source.obs.r)]
      ['by' s+by.obs.r]
      ['obs' s+id.r]
  ==
++  en-attrs
  |=  [winners=(map @t (list row:orr)) multi=(set @t)]
  ^-  json
  :-  %o
  %-  ~(gas by *(map @t json))
  %+  murn  ~(tap by winners)
  |=  [attr=@t rs=(list row:orr)]
  ^-  (unit [@t json])
  ?:  (~(has in multi) attr)  `[attr a+(turn rs en-attr-row)]
  ?~  rs  ~
  ?~  value.obs.i.rs  ~
  `[attr (en-attr-row i.rs)]
::  ==  HTTP
::
++  send-json
  |=  [eyre-id=@ta code=@ud jon=json]
  =/  m  (fiber:fiber:nexus ,~)
  ^-  form:m
  =/  bod=octs  (as-octs:mimes:html (en:json:html jon))
  (send-simple:srv eyre-id [[code ['content-type' 'application/json'] ~] `bod])
++  send-err
  |=  [eyre-id=@ta code=@ud msg=@t]
  =/  m  (fiber:fiber:nexus ,~)
  ^-  form:m
  (send-json eyre-id code (pairs:enjs:format ~[['error' s+msg]]))
::  +when-arg: ?at=<iso>, or now. ~ when given and unreadable.
::
++  when-arg
  |=  [args=quay:eyre now=@da]
  ^-  (unit @da)
  =/  v=(unit @t)  (get-key:kv:html-utils 'at' args)
  ?~  v  `now
  (de-iso:orr u.v)
::  +ensure-me-from-request: person/me is laid by the writer on the
::  first request after consent, since the writer itself reaches
::  nothing at rise
::
++  ensure-me-from-request
  =/  m  (fiber:fiber:nexus ,~)
  ^-  form:m
  ;<  ex=?  bind:m  (peek-exists:io (rf 1 (body-dir %person %me) %body))
  ?:  ex  (pure:m ~)
  ;<  *  bind:m
    (poke-soft:io (rf 1 / %'main.sig') [[/ %json] (pairs:enjs:format ~[['op' s+'ensure-me']])])
  (pure:m ~)
::  +handle-request: one HTTP request, on its own ephemeral fiber.
::  Owner only: eyre's authenticated flag and src equal to our.
::
++  handle-request
  |=  eyre-id=@ta
  =/  m  (fiber:fiber:nexus ,~)
  ^-  form:m
  ;<  [src=@p req=inbound-request:eyre]  bind:m
    (get-state-as:io ,[src=@p inbound-request:eyre])
  ;<  our=@p  bind:m  get-our:io
  =/  parsed  (parse-url:http-utils url.request.req)
  ::  drop /apps/orrery; a trailing slash parses as a trailing empty knot
  =/  suffix=path  (slag 2 site.parsed)
  =/  suffix=path
    ?:  &(?=(^ suffix) =('' (rear `path`suffix)))  (snip `path`suffix)
    suffix
  =/  meth=@t  method.request.req
  ?.  &(authenticated.req =(src our))
    (send-err eyre-id 403 'forbidden')
  ;<  ~  bind:m  ensure-me-from-request
  =/  jon=json
    (fall (de:json:html ?~(body.request.req '' q.u.body.request.req)) ~)
  ?:  &(=('GET' meth) ?=([%api %state ~] suffix))
    (serve-state eyre-id args.parsed)
  ?:  &(=('POST' meth) ?=([%api %observe ~] suffix))
    (serve-observe eyre-id jon)
  (send-err eyre-id 404 'no such route')
::  +serve-state: every body with its current attributes, the open
::  situations, the open actions and the schema, as of ?at
::
++  serve-state
  |=  [eyre-id=@ta args=quay:eyre]
  =/  m  (fiber:fiber:nexus ,~)
  ^-  form:m
  ;<  now=@da  bind:m  get-time:io
  =/  when=(unit @da)  (when-arg args now)
  ?~  when  (send-err eyre-id 400 'at: expected an ISO 8601 UTC time')
  =/  kind=@t  (fall (get-key:kv:html-utils 'kind' args) '')
  ;<  schema=json  bind:m  (read-json (rf 1 / %'schema.json'))
  ;<  rev=json  bind:m  (read-json (rf 1 /beacon %rev))
  ;<  all=(list loaded)  bind:m  (load-bodies 1)
  =/  multi=(set @t)  (multi-of:orr schema)
  =/  folded=(list [id=bid:orr =body:orr winners=(map @t (list row:orr))])
    (turn all |=(l=loaded [id.l body.l (fold:orr rows.l multi u.when)]))
  =/  sits=(list [id=bid:orr winners=(map @t (list row:orr))])
    %+  murn  folded
    |=  [id=bid:orr =body:orr winners=(map @t (list row:orr))]
    ?:(=(%situation kind.body) `[id winners] ~)
  =/  shown
    ?:  =('' kind)  folded
    (skim folded |=(f=[id=bid:orr =body:orr winners=(map @t (list row:orr))] =(kind `@t`kind.body.f)))
  =/  bodies-json=json
    :-  %a
    %+  turn  shown
    |=  [id=bid:orr =body:orr winners=(map @t (list row:orr))]
    ^-  json
    =/  base=json  (en-body:orr id body)
    ?.  ?=([%o *] base)  base
    :-  %o
    %-  ~(gas by p.base)
    :~  ['attrs' (en-attrs winners multi)]
        ['involved' a+(turn (involved:orr id sits) |=(b=bid:orr `json`s+b))]
    ==
  %^  send-json  eyre-id  200
  %-  pairs:enjs:format
  :~  ['rev' rev]
      ['at' (en-time:orr u.when)]
      ['me' s+'person/me']
      ['bodies' bodies-json]
      ['situations' a+(turn sits |=([id=bid:orr *] `json`s+id))]
      ['actions' [%a ~]]
      ['schema' schema]
  ==
::  +serve-observe: decode, answer per item, hand the stamped request to
::  the writer. The ids reported here are the ids the writer makes,
::  because at and by are stamped before either side decodes.
::
++  serve-observe
  |=  [eyre-id=@ta jon=json]
  =/  m  (fiber:fiber:nexus ,~)
  ^-  form:m
  ?.  ?=([%o *] jon)  (send-err eyre-id 400 'a JSON object is required')
  ?:  (gth (lent (ga:orr jon 'bodies')) max-bodies:orr)
    (send-err eyre-id 400 'bodies: over 50')
  ?:  (gth (lent (ga:orr jon 'observations')) max-obs:orr)
    (send-err eyre-id 400 'observations: over 200')
  ;<  now=@da  bind:m  get-time:io
  =/  stamped=json
    %-  pairs:enjs:format
    :~  ['op' s+'observe']
        ['bodies' a+(ga:orr jon 'bodies')]
        ['observations' a+(turn (ga:orr jon 'observations') |=(j=json (fill-obs:orr j now 'http')))]
    ==
  =/  prep  (prep-observe:orr stamped now 'http')
  ;<  bodies-res=(list json)  bind:m  (body-results bodies.prep ~)
  =/  known=(set bid:orr)
    %-  sy
    %+  murn  bodies.prep
    |=(e=(each [id=bid:orr =body:orr] @t) ?:(?=(%& -.e) `id.p.e ~))
  ;<  obs-res=(list json)  bind:m  (obs-results obs.prep known ~)
  ;<  err=(unit tang)  bind:m  (poke-soft:io (rf 1 / %'main.sig') [[/ %json] stamped])
  ?^  err  (send-err eyre-id 500 'the writer refused the poke')
  ;<  rev=json  bind:m  (read-json (rf 1 /beacon %rev))
  %^  send-json  eyre-id  200
  (pairs:enjs:format ~[['rev' rev] ['bodies' a+bodies-res] ['observations' a+obs-res]])
++  body-results
  |=  [items=(list (each [id=bid:orr =body:orr] @t)) acc=(list json)]
  =/  m  (fiber:fiber:nexus ,(list json))
  ^-  form:m
  ?~  items  (pure:m (flop acc))
  ?:  ?=(%| -.i.items)
    (body-results t.items [(pairs:enjs:format ~[['ok' b+|] ['error' s+p.i.items]]) acc])
  =/  pk  (parse-bid:orr id.p.i.items)
  ?~  pk
    (body-results t.items [(pairs:enjs:format ~[['ok' b+|] ['error' s+'id: bad']]) acc])
  ;<  ex=?  bind:m  (peek-exists:io (rf 1 (body-dir kind.u.pk slug.u.pk) %body))
  %+  body-results  t.items
  [(pairs:enjs:format ~[['id' s+id.p.i.items] ['ok' b+&] ['existing' b+ex]]) acc]
++  obs-results
  |=  [items=(list (each obs:orr @t)) known=(set bid:orr) acc=(list json)]
  =/  m  (fiber:fiber:nexus ,(list json))
  ^-  form:m
  ?~  items  (pure:m (flop acc))
  ?:  ?=(%| -.i.items)
    (obs-results t.items known [(pairs:enjs:format ~[['ok' b+|] ['error' s+p.i.items]]) acc])
  =/  o=obs:orr  p.i.items
  =/  pk  (parse-bid:orr subject.o)
  ?~  pk
    (obs-results t.items known [(pairs:enjs:format ~[['ok' b+|] ['error' s+'subject: bad']]) acc])
  ;<  has=?  bind:m
    ?:  (~(has in known) subject.o)  (pure:(fiber:fiber:nexus ,?) &)
    (peek-exists:io (rf 1 (body-dir kind.u.pk slug.u.pk) %body))
  ?.  has
    =/  why=@t  (cat 3 'unknown subject ' subject.o)
    (obs-results t.items known [(pairs:enjs:format ~[['ok' b+|] ['error' s+why]]) acc])
  =/  id=@ta  (obs-id:orr o)
  ;<  ex=?  bind:m  (peek-exists:io (rf 1 (obs-dir kind.u.pk slug.u.pk) id))
  %^  obs-results  t.items  known
  [(pairs:enjs:format ~[['id' s+id] ['ok' b+&] ['existing' b+ex]]) acc]
--
```

- [ ] **Step 2: Commit and push, so the forge can mirror the repo**

```bash
git add code/nex
git commit -m "The nexus: the tree, the writer with observe and upsert-body, and the state and observe routes"
git push origin main
```

- [ ] **Step 3: Mirror the repo on the dev ship and install the desk**

Log in first (recipe under "Working with the dev ship"). Then:

```bash
W=$SHIP; CK=$JAR
curl -s -b $CK -X POST -H 'content-type: application/json' \
  -d '{"name":"orrery","repo":"nisfeb/orrery","ref":"main"}' $W/grubbery/forge/api/add
# expected: created   (409 "a repo by that name already exists" means a previous attempt; continue)
```

Wait for the pull, checking every 10 seconds for at most 3 minutes:

```bash
curl -s -b $CK "$W/grubbery/ball/apps/forge.git_forge/repos/orrery.git_repo/data/tree/code/version.json?raw=1"
# expected, once pulled: {"version": 1}
```

If nothing arrives in 3 minutes, STOP and report; do not retry blindly. Then the desk:

```bash
curl -s -b $CK -X POST -H 'content-type: application/json' \
  -d '{"name":"orrery","code":"/apps/forge.git_forge/repos/orrery.git_repo/data/tree/code"}' $W/apps/grubbery/desks/add
# expected: created
```

- [ ] **Step 4: Wait for the instance and read its bang**

Check every 15 seconds for at most 3 minutes:

```bash
I="$W/grubbery/ball/apps/shell.shell/desks/orrery.desk/desk/data/orrery.orrery_app"
curl -s -b $CK "$I?info=1" | python3 -c 'import sys,json; d=json.load(sys.stdin); print("bang:", d.get("bang")); print("children:", [c["name"] for c in d.get("children",[])])'
```

Expected: `bang: None` and children including `main.sig`, `web.sig`, `bodies`, `actions`, `schema.json`, `policy.json`, `beacon`, `tr`, `requests`. A `bang` string is the compile error with its line and column: fix `code/nex/orrery/app.hoon` in the repo, then use the fast loop (write-text, reload-nexus, read the bang again) until it is `None`. Commit each fix with a message naming what the compiler said.

- [ ] **Step 5: Approve the ask and reload**

```bash
APP=/apps/shell.shell/desks/orrery.desk/desk/data/orrery.orrery_app
curl -s -b $CK -X POST -H 'content-type: application/json' -d "{\"action\":\"approve-weir\",\"app\":\"$APP\",\"granted\":{\"poke\":[\"/sys/bowl.sig\",\"/sys/eyre/\",\"/sys/push/\"],\"peek\":[\"/sys/link/\"],\"make\":[]}}" $W/apps/grubbery/permits
# expected: ok. The granted object is required: the shell treats a missing one as an empty grant and sands an empty weir, answering ok both times and leaving the app jailed.
curl -s -b $CK -X POST -H 'content-type: application/json' -d "{\"app\":\"$APP\"}" $W/apps/grubbery/permits/reload
# expected: ok
sleep 15
curl -s -b $CK "$I?info=1" | python3 -c 'import sys,json; d=json.load(sys.stdin); print(d["weir"])'
# expected: poke lists /sys/bowl.sig, /sys/eyre/, /sys/push/; read lists /sys/link/
```

- [ ] **Step 6: The first request**

```bash
curl -s -m 30 -b $CK $W/apps/orrery/api/state | python3 -m json.tool | head -40
```

Expected: HTTP 200 with `"me": "person/me"`, a `bodies` array holding one body `person/me` named `me` with aliases `me`, `I` and its own @p, empty `attrs`, `situations: []`, `actions: []`, and the starter schema. The first call lays `person/me`; if the body is missing on the first answer, call again once. A hang past 30 seconds means the route is bound to a dead instance: read the bang. A 403 means the cookie is stale: log in again. Unauthenticated check:

```bash
curl -s -o /dev/null -w '%{http_code}\n' $W/apps/orrery/api/state
# expected: 403
```

- [ ] **Step 7: The first observation**

```bash
curl -s -b $CK -X POST -H 'content-type: application/json' $W/apps/orrery/api/observe -d '{
  "bodies": [{"id":"thing/subaru","name":"The Subaru","aliases":["the car","subaru"]}],
  "observations": [
    {"subject":"thing/subaru","attr":"status","value":"broken down","at":"2026-09-16T12:00:00Z","conf":90,"source":{"kind":"phone-dm","id":"m1"},"by":"phone/triage"},
    {"subject":"thing/nothing","attr":"status","value":"x","source":{"kind":"user","id":""}}
  ]}' | python3 -m json.tool
```

Expected: `bodies[0]` is `{"id": "thing/subaru", "ok": true, "existing": false}`; `observations[0]` has an `id` of the form `1789560000-xxxxxxxx`, `ok: true`, `existing: false`; `observations[1]` is `{"ok": false, "error": "unknown subject thing/nothing"}`. The observation is dated at noon UTC, in the ship's past: a state read folds at the ship's now, and an observation dated in the future is `%future`, not live. Then:

```bash
curl -s -b $CK $W/apps/orrery/api/state | python3 -c 'import sys,json; d=json.load(sys.stdin); b=[x for x in d["bodies"] if x["id"]=="thing/subaru"][0]; print(b["attrs"])'
```

Expected: `status` with value `broken down`, `at` `2026-09-16T12:00:00Z`, `conf` 90, `source` `{kind: phone-dm, id: m1}`, `by` `phone/triage`, and `obs` equal to the id answered above. Re-POST the same request: `existing: true` on the body and the first observation. Read the writer's last note:

```bash
curl -s -b $CK "$I/tr/last?raw=1"
# expected: {"op":"observe","ok":true,"why":"","at":"..."}  (the last op applied; the unknown subject was noted during it and then overwritten by the success note)
```

- [ ] **Step 8: Commit**

```bash
git add code
git commit -m "Installed on the dev ship: the first observation lands and reads back"
git push origin main
```

### Task 5: The rest of the API: bodies, retract, actions, policy, schema, compaction, push

**Files:**
- Modify: `code/nex/orrery/app.hoon`

**Interfaces:**
- Consumes: Task 4's arms.
- Produces: the writer ops `retract`, `delete-body`, `act`, `set-action`, `set-schema`, `set-policy`; the routes `GET /api/body/<kind>/<slug>`, `DELETE /api/body/<kind>/<slug>`, `GET /api/resolve`, `POST /api/retract`, `POST /api/bodies`, `POST /api/act`, `GET /api/actions`, `POST /api/actions/<id>`, `GET` and `PUT /api/schema` and `/api/policy`; `actions` filled in the state view; compaction on write; a push on every new action when policy says so.

- [ ] **Step 1: Replace `+apply` with the full op table**

```hoon
::  +apply: one op from a poke. Answers whether the tree changed.
::
++  apply
  |=  [=from:fiber:nexus =sage:tarball]
  =/  m  (fiber:fiber:nexus ,?)
  ^-  form:m
  ?.  =([/ %json] p.sage)  (pure:m |)
  ;<  our=@p  bind:m  get-our:io
  ::  +get-poke-src reads the ship off the transport. ~ is a fiber
  ::  inside this nexus; our own ship arrives named through the
  ::  agent-facing surface. Anything else is refused.
  =/  src=(unit @p)  (get-poke-src:io from)
  ?.  ?|(?=(~ src) =(our u.src))
    (refuse 'poke' 'a foreign ship may not write here')
  =/  jon=json  (fall (mole |.(!<(json q.sage))) ~)
  =/  op=@t  (gs:orr jon 'op')
  ?:  =('ensure-me' op)  ensure-me
  ?:  =('observe' op)  (do-observe jon)
  ?:  =('upsert-body' op)  (do-upsert-body jon)
  ?:  =('delete-body' op)  (do-delete-body jon)
  ?:  =('retract' op)  (do-retract jon)
  ?:  =('act' op)  (do-act jon)
  ?:  =('set-action' op)  (do-set-action jon)
  ?:  =('set-schema' op)  (do-set-doc %'schema.json' 'set-schema' jon)
  ?:  =('set-policy' op)  (do-set-doc %'policy.json' 'set-policy' jon)
  (refuse op 'unknown op')
```

- [ ] **Step 2: Replace `+do-observe` so a write compacts the bodies it touched**

```hoon
::  +do-observe: bodies first, then observations, then compaction of
::  every subject written. Items that failed to decode are skipped
::  here; the caller already reported them.
::
++  do-observe
  |=  jon=json
  =/  m  (fiber:fiber:nexus ,?)
  ^-  form:m
  ;<  now=@da  bind:m  get-time:io
  =/  prep  (prep-observe:orr jon now 'writer')
  ;<  c1=?  bind:m  (write-bodies bodies.prep |)
  ;<  c2=?  bind:m  (write-obs obs.prep |)
  =/  subjects=(list bid:orr)
    %~  tap  in
    %-  sy
    %+  murn  obs.prep
    |=(e=(each obs:orr @t) ?:(?=(%& -.e) `subject.p.e ~))
  ;<  ~  bind:m  (compact-each subjects)
  ;<  ~  bind:m  (note 'observe' & '')
  (pure:m |(c1 c2))
```

- [ ] **Step 3: Append the new writer arms before the closing `--`**

```hoon
::  +find-obs: the body holding an observation id, by a sweep
::
++  find-obs
  |=  [up=@ud id=@ta]
  =/  m  (fiber:fiber:nexus ,(unit [kind=@tas slug=@ta r=row:orr]))
  ^-  form:m
  ;<  all=(list loaded)  bind:m  (load-bodies up)
  %-  pure:m
  |-
  ?~  all  ~
  =/  hit=(unit row:orr)  (find-row rows.i.all id)
  ?~  hit  $(all t.all)
  =/  pk  (parse-bid:orr id.i.all)
  ?~  pk  $(all t.all)
  `[kind.u.pk slug.u.pk u.hit]
++  find-row
  |=  [rs=(list row:orr) id=@ta]
  ^-  (unit row:orr)
  ?~  rs  ~
  ?:  =(id.i.rs id)  `i.rs
  $(rs t.rs)
++  find-loaded
  |=  [all=(list loaded) id=bid:orr]
  ^-  (unit loaded)
  ?~  all  ~
  ?:  =(id.i.all id)  `i.all
  $(all t.all)
::  +do-retract: the retracted flag and its note. The grub stays.
::
++  do-retract
  |=  jon=json
  =/  m  (fiber:fiber:nexus ,?)
  ^-  form:m
  =/  id=@t  (gs:orr jon 'id')
  =/  why=@t  (gs:orr jon 'note')
  ?:  (gth (met 3 why) max-note:orr)  (refuse 'retract' 'note: over 500 bytes')
  ;<  hit=(unit [kind=@tas slug=@ta r=row:orr])  bind:m  (find-obs 0 `@ta`id)
  ?~  hit  (refuse 'retract' (cat 3 'no observation ' id))
  ?:  retracted.obs.r.u.hit  (pure:m |)
  =/  o=obs:orr  obs.r.u.hit(retracted &, note why)
  ;<  ~  bind:m
    %+  over:io  (rf 0 (obs-dir kind.u.hit slug.u.hit) id.r.u.hit)
    [[/orrery %obs] `stored-obs:orr`[%1 o]]
  ;<  ~  bind:m  (note 'retract' & '')
  (pure:m &)
++  do-delete-body
  |=  jon=json
  =/  m  (fiber:fiber:nexus ,?)
  ^-  form:m
  =/  pk  (parse-bid:orr (gs:orr jon 'id'))
  ?~  pk  (refuse 'delete-body' 'id: expected <kind>/<slug>')
  ;<  ex=?  bind:m  (peek-exists:io (rv 0 (body-dir kind.u.pk slug.u.pk)))
  ?.  ex  (refuse 'delete-body' 'no such body')
  ;<  *  bind:m  (cull-soft:io (rv 0 (body-dir kind.u.pk slug.u.pk)))
  ;<  ~  bind:m  (note 'delete-body' & '')
  (pure:m &)
::  +load-actions: every action grub
::
++  load-actions
  |=  up=@ud
  =/  m  (fiber:fiber:nexus ,(list [id=@ta a=action:orr]))
  ^-  form:m
  ;<  vw=view:nexus  bind:m  (peek:io (rv up /actions) ~)
  ?.  ?=([%ball *] vw)  (pure:m ~)
  ?~  fil.ball.vw  (pure:m ~)
  %-  pure:m
  %+  murn  ~(tap by contents.u.fil.ball.vw)
  |=  [nam=@ta c=[=sang:tarball gain=? bang=(unit tang)]]
  ^-  (unit [id=@ta a=action:orr])
  =/  a=(unit action:orr)  (read-action:orr (sang-noun:tarball sang.c))
  ?~  a  ~
  `[nam u.a]
::  +first-missing: the first body id in the list that does not exist
::
++  first-missing
  |=  [up=@ud ids=(list bid:orr)]
  =/  m  (fiber:fiber:nexus ,(unit bid:orr))
  ^-  form:m
  ?~  ids  (pure:m ~)
  =/  pk  (parse-bid:orr i.ids)
  ?~  pk  (pure:m `i.ids)
  ;<  ex=?  bind:m  (peek-exists:io (rf up (body-dir kind.u.pk slug.u.pk) %body))
  ?.  ex  (pure:m `i.ids)
  (first-missing up t.ids)
::  +open-twin: an open action with this kind and title, if any
::
++  open-twin
  |=  [all=(list [id=@ta a=action:orr]) kind=@tas title=@t]
  ^-  (unit [id=@ta a=action:orr])
  ?~  all  ~
  ?:  &((is-open:orr a.i.all) =(kind.a.i.all kind) =(title.a.i.all title))  `i.all
  $(all t.all)
::  +do-act: a proposal. Its about bodies must exist; an open twin
::  answers nothing new; policy decides the initial status; a new
::  action is pushed when policy says so.
::
++  do-act
  |=  jon=json
  =/  m  (fiber:fiber:nexus ,?)
  ^-  form:m
  ;<  now=@da  bind:m  get-time:io
  =/  got  (de-action:orr (gj:orr jon 'action') now 'writer')
  ?:  ?=(%| -.got)  (refuse 'act' p.got)
  ;<  missing=(unit bid:orr)  bind:m  (first-missing 0 ~(tap in about.p.got))
  ?^  missing  (refuse 'act' (cat 3 'about: no such body ' u.missing))
  ;<  policy=json  bind:m  (read-json (rf 0 / %'policy.json'))
  ;<  all=(list [id=@ta a=action:orr])  bind:m  (load-actions 0)
  ?^  (open-twin all kind.p.got title.p.got)  (pure:m |)
  =/  a=action:orr  p.got(status (initial-status:orr kind.p.got (auto-of:orr policy)))
  =/  id=@ta  (act-id:orr a)
  ;<  ex=?  bind:m  (peek-exists:io (rf 0 /actions id))
  ?:  ex  (pure:m |)
  ;<  *  bind:m
    (make-gained-soft:io (rf 0 /actions id) |+[[[/orrery %action] `stored-action:orr`[%1 a]] ~])
  ;<  ~  bind:m
    ?.  (push-of:orr policy)  (pure:(fiber:fiber:nexus ,~) ~)
    (push-soft a id)
  ;<  ~  bind:m  (note 'act' & '')
  (pure:m &)
::  +push-soft: a notification through /sys/push. Soft, so a refused
::  road never fails the writer.
::
++  push-soft
  |=  [a=action:orr id=@ta]
  =/  m  (fiber:fiber:nexus ,~)
  ^-  form:m
  ;<  eny=@uvJ  bind:m  get-entropy:io
  =/  title=@t  ?:(=(%approved status.a) 'Orrery filed' 'Orrery proposes')
  =/  tag=@t  (cat 3 'orrery-' id)
  ;<  *  bind:m
    %+  poke-soft:io  push-road:io
    [[/ %push-action] `push-action:nexus`[%send [~ ~ ~ [title title.a ~ `'/apps/orrery' `tag]] eny]]
  (pure:m ~)
++  do-set-action
  |=  jon=json
  =/  m  (fiber:fiber:nexus ,?)
  ^-  form:m
  =/  id=@t  (gs:orr jon 'id')
  =/  want=@t  (gs:orr jon 'status')
  =/  why=@t  (gs:orr jon 'note')
  ?:  (gth (met 3 why) max-note:orr)  (refuse 'set-action' 'note: over 500 bytes')
  =/  road=road:tarball  (rf 0 /actions `@ta`id)
  ;<  cur=view:nexus  bind:m  (peek:io road ~)
  ?.  ?=([%file *] cur)  (refuse 'set-action' (cat 3 'no action ' id))
  =/  a=(unit action:orr)  (read-action:orr (sang-noun:tarball sang.cur))
  ?~  a  (refuse 'set-action' 'unreadable action')
  ?.  (transition-ok:orr status.u.a `@tas`want)
    (refuse 'set-action' (rap 3 'cannot go from ' status.u.a ' to ' want ~))
  =/  next=action:orr  u.a(status `@tas`want, note why)
  ;<  ~  bind:m  (over:io road [[/orrery %action] `stored-action:orr`[%1 next]])
  ;<  ~  bind:m  (note 'set-action' & '')
  (pure:m &)
++  do-set-doc
  |=  [name=@ta op=@t jon=json]
  =/  m  (fiber:fiber:nexus ,?)
  ^-  form:m
  =/  doc=json  (gj:orr jon 'doc')
  ?.  ?=([%o *] doc)  (refuse op 'doc: an object is required')
  ;<  ~  bind:m  (over:io (rf 0 / name) [[/ %json] doc])
  ;<  ~  bind:m  (note op & '')
  (pure:m &)
::  +compact: cull a body's observations that are superseded, expired
::  or retracted and older than the retention. A live one never goes.
::
++  compact
  |=  [kind=@tas slug=@ta]
  =/  m  (fiber:fiber:nexus ,~)
  ^-  form:m
  ;<  now=@da  bind:m  get-time:io
  ;<  policy=json  bind:m  (read-json (rf 0 / %'policy.json'))
  ;<  schema=json  bind:m  (read-json (rf 0 / %'schema.json'))
  =/  span=@dr  (mul (retention-of:orr policy) ~d1)
  =/  horizon=@da  ?:((lth now span) ~1970.1.1 (sub now span))
  ;<  vw=view:nexus  bind:m  (peek:io (rv 0 (body-dir kind slug)) ~)
  ?.  ?=([%ball *] vw)  (pure:m ~)
  =/  rows=(list row:orr)  (rows-in ball.vw)
  =/  winners  (fold:orr rows (multi-of:orr schema) now)
  =/  dead=(list @ta)
    %+  murn  rows
    |=  r=row:orr
    ^-  (unit @ta)
    ?:  (gte at.obs.r horizon)  ~
    =/  st=@tas  (status-of:orr r winners now)
    ?:(?=(?(%superseded %expired %retracted) st) `id.r ~)
  (cull-each 0 (obs-dir kind slug) dead)
++  cull-each
  |=  [up=@ud dir=path names=(list @ta)]
  =/  m  (fiber:fiber:nexus ,~)
  ^-  form:m
  ?~  names  (pure:m ~)
  ;<  *  bind:m  (cull-soft:io (rf up dir i.names))
  (cull-each up dir t.names)
++  compact-each
  |=  ids=(list bid:orr)
  =/  m  (fiber:fiber:nexus ,~)
  ^-  form:m
  ?~  ids  (pure:m ~)
  =/  pk  (parse-bid:orr i.ids)
  ;<  ~  bind:m
    ?~  pk  (pure:(fiber:fiber:nexus ,~) ~)
    (compact kind.u.pk slug.u.pk)
  (compact-each t.ids)
```

- [ ] **Step 4: Replace `+handle-request` with the full route table**

The two path segments after `/api/body` and the one after `/api/actions` are pulled out before the route tests, so no branch depends on `?=` narrowing inside an `&()`.

```hoon
::  +handle-request: one HTTP request, on its own ephemeral fiber.
::  Owner only: eyre's authenticated flag and src equal to our.
::
++  handle-request
  |=  eyre-id=@ta
  =/  m  (fiber:fiber:nexus ,~)
  ^-  form:m
  ;<  [src=@p req=inbound-request:eyre]  bind:m
    (get-state-as:io ,[src=@p inbound-request:eyre])
  ;<  our=@p  bind:m  get-our:io
  =/  parsed  (parse-url:http-utils url.request.req)
  ::  drop /apps/orrery; a trailing slash parses as a trailing empty knot
  =/  suffix=path  (slag 2 site.parsed)
  =/  suffix=path
    ?:  &(?=(^ suffix) =('' (rear `path`suffix)))  (snip `path`suffix)
    suffix
  =/  meth=@t  method.request.req
  ?.  &(authenticated.req =(src our))
    (send-err eyre-id 403 'forbidden')
  ;<  ~  bind:m  ensure-me-from-request
  =/  jon=json
    (fall (de:json:html ?~(body.request.req '' q.u.body.request.req)) ~)
  =/  s2=@ta  ?:(?=([@ @ @ *] suffix) i.t.t.suffix %$)
  =/  s3=@ta  ?:(?=([@ @ @ @ *] suffix) i.t.t.t.suffix %$)
  =/  args=quay:eyre  args.parsed
  ?:  &(=('GET' meth) ?=([%api %state ~] suffix))       (serve-state eyre-id args)
  ?:  &(=('GET' meth) ?=([%api %body @ @ ~] suffix))    (serve-body eyre-id s2 s3 args)
  ?:  &(=('DELETE' meth) ?=([%api %body @ @ ~] suffix))  (serve-delete-body eyre-id s2 s3)
  ?:  &(=('GET' meth) ?=([%api %resolve ~] suffix))     (serve-resolve eyre-id args)
  ?:  &(=('POST' meth) ?=([%api %observe ~] suffix))    (serve-observe eyre-id jon)
  ?:  &(=('POST' meth) ?=([%api %retract ~] suffix))    (serve-retract eyre-id jon)
  ?:  &(=('POST' meth) ?=([%api %bodies ~] suffix))     (serve-bodies eyre-id jon)
  ?:  &(=('POST' meth) ?=([%api %act ~] suffix))        (serve-act eyre-id jon)
  ?:  &(=('GET' meth) ?=([%api %actions ~] suffix))     (serve-actions eyre-id args)
  ?:  &(=('POST' meth) ?=([%api %actions @ ~] suffix))  (serve-set-action eyre-id s2 jon)
  ?:  &(=('GET' meth) ?=([%api %schema ~] suffix))      (serve-doc eyre-id %'schema.json')
  ?:  &(=('PUT' meth) ?=([%api %schema ~] suffix))      (serve-set-doc eyre-id 'set-schema' jon)
  ?:  &(=('GET' meth) ?=([%api %policy ~] suffix))      (serve-doc eyre-id %'policy.json')
  ?:  &(=('PUT' meth) ?=([%api %policy ~] suffix))      (serve-set-doc eyre-id 'set-policy' jon)
  (send-err eyre-id 404 'no such route')
```

- [ ] **Step 5: Fill `actions` in the state view, and publish only the open situations**

In `+serve-state`, after the line `;<  all=(list loaded)  bind:m  (load-bodies 1)` add:

```hoon
  ;<  acts=(list [id=@ta a=action:orr])  bind:m  (load-actions 1)
```

Task 4's review found that `situations` published every situation, closed ones included, while the spec says the open ones. `sits` stays unfiltered because `involved` filters for itself; the published list is filtered. After the `=/  sits=...` binding add:

```hoon
  =/  open-sits=(list [id=bid:orr winners=(map @t (list row:orr))])
    (skim sits |=([* winners=(map @t (list row:orr))] !(is-closed:orr winners)))
```

Replace the row `['situations' a+(turn sits |=([id=bid:orr *] `json`s+id))]` with:

```hoon
      ['situations' a+(turn open-sits |=([id=bid:orr *] `json`s+id))]
```

and replace the row `['actions' [%a ~]]` with:

```hoon
      ['actions' a+(murn acts |=([id=@ta a=action:orr] ?.((is-open:orr a) ~ `(en-action:orr id a))))]
```

- [ ] **Step 6: Append the new route arms before the closing `--`**

```hoon
::  +serve-body: one body with its attributes, its situations, the open
::  actions about it, and its full timeline newest first
::
++  serve-body
  |=  [eyre-id=@ta kind=@ta slug=@ta args=quay:eyre]
  =/  m  (fiber:fiber:nexus ,~)
  ^-  form:m
  ;<  now=@da  bind:m  get-time:io
  =/  when=(unit @da)  (when-arg args now)
  ?~  when  (send-err eyre-id 400 'at: expected an ISO 8601 UTC time')
  =/  id=bid:orr  (rap 3 kind '/' slug ~)
  ?~  (parse-bid:orr id)  (send-err eyre-id 400 'expected <kind>/<slug>')
  ;<  schema=json  bind:m  (read-json (rf 1 / %'schema.json'))
  =/  multi=(set @t)  (multi-of:orr schema)
  ;<  all=(list loaded)  bind:m  (load-bodies 1)
  =/  mine=(unit loaded)  (find-loaded all id)
  ?~  mine  (send-err eyre-id 404 'no such body')
  =/  winners  (fold:orr rows.u.mine multi u.when)
  =/  sits=(list [id=bid:orr winners=(map @t (list row:orr))])
    %+  murn  all
    |=  l=loaded
    ?.(=(%situation kind.body.l) ~ `[id.l (fold:orr rows.l multi u.when)])
  ;<  acts=(list [id=@ta a=action:orr])  bind:m  (load-actions 1)
  =/  about-me=(list json)
    %+  murn  acts
    |=  [aid=@ta a=action:orr]
    ?.(&((is-open:orr a) (~(has in about.a) id)) ~ `(en-action:orr aid a))
  =/  base=json  (en-body:orr id body.u.mine)
  ?.  ?=([%o *] base)  (send-err eyre-id 500 'encoder')
  %^  send-json  eyre-id  200
  :-  %o
  %-  ~(gas by p.base)
  :~  ['attrs' (en-attrs winners multi)]
      ['involved' a+(turn (involved:orr id sits) |=(b=bid:orr `json`s+b))]
      ['actions' a+about-me]
      :-  'observations'
      :-  %a
      %+  turn  (timeline:orr rows.u.mine winners u.when)
      |=([r=row:orr status=@tas] (en-obs:orr r status))
  ==
++  serve-delete-body
  |=  [eyre-id=@ta kind=@ta slug=@ta]
  =/  m  (fiber:fiber:nexus ,~)
  ^-  form:m
  =/  id=bid:orr  (rap 3 kind '/' slug ~)
  ?~  (parse-bid:orr id)  (send-err eyre-id 400 'expected <kind>/<slug>')
  ;<  ex=?  bind:m  (peek-exists:io (rv 1 /bodies/[kind]/[slug]))
  ?.  ex  (send-err eyre-id 404 'no such body')
  =/  op=json  (pairs:enjs:format ~[['op' s+'delete-body'] ['id' s+id]])
  ;<  err=(unit tang)  bind:m  (poke-soft:io (rf 1 / %'main.sig') [[/ %json] op])
  ?^  err  (send-err eyre-id 500 'the writer refused the poke')
  (send-json eyre-id 200 (pairs:enjs:format ~[['id' s+id] ['ok' b+&]]))
++  serve-resolve
  |=  [eyre-id=@ta args=quay:eyre]
  =/  m  (fiber:fiber:nexus ,~)
  ^-  form:m
  =/  q=@t  (fall (get-key:kv:html-utils 'q' args) '')
  ;<  all=(list loaded)  bind:m  (load-bodies 1)
  =/  bodies=(list [id=bid:orr =body:orr])  (turn all |=(l=loaded [id.l body.l]))
  %^  send-json  eyre-id  200
  :-  %a
  %+  turn  (resolve:orr q bodies)
  |=  [id=bid:orr =body:orr match=@tas]
  ^-  json
  (pairs:enjs:format ~[['id' s+id] ['kind' s+kind.body] ['name' s+name.body] ['match' s+match]])
++  serve-retract
  |=  [eyre-id=@ta jon=json]
  =/  m  (fiber:fiber:nexus ,~)
  ^-  form:m
  =/  id=@t  (gs:orr jon 'id')
  ?:  =('' id)  (send-err eyre-id 400 'id: required')
  ;<  hit=(unit [kind=@tas slug=@ta r=row:orr])  bind:m  (find-obs 1 `@ta`id)
  ?~  hit  (send-err eyre-id 404 'no such observation')
  =/  op=json
    (pairs:enjs:format ~[['op' s+'retract'] ['id' s+id] ['note' s+(gs:orr jon 'note')]])
  ;<  err=(unit tang)  bind:m  (poke-soft:io (rf 1 / %'main.sig') [[/ %json] op])
  ?^  err  (send-err eyre-id 500 'the writer refused the poke')
  (send-json eyre-id 200 (pairs:enjs:format ~[['id' s+id] ['ok' b+&]]))
++  serve-bodies
  |=  [eyre-id=@ta jon=json]
  =/  m  (fiber:fiber:nexus ,~)
  ^-  form:m
  ;<  now=@da  bind:m  get-time:io
  =/  got  (de-body:orr jon now)
  ?:  ?=(%| -.got)  (send-err eyre-id 400 p.got)
  =/  pk  (parse-bid:orr id.p.got)
  ?~  pk  (send-err eyre-id 400 'id: bad')
  ;<  ex=?  bind:m  (peek-exists:io (rf 1 (body-dir kind.u.pk slug.u.pk) %body))
  =/  op=json  (pairs:enjs:format ~[['op' s+'upsert-body'] ['body' jon]])
  ;<  err=(unit tang)  bind:m  (poke-soft:io (rf 1 / %'main.sig') [[/ %json] op])
  ?^  err  (send-err eyre-id 500 'the writer refused the poke')
  (send-json eyre-id 200 (pairs:enjs:format ~[['id' s+id.p.got] ['ok' b+&] ['existing' b+ex]]))
::  +serve-act: a proposal. The request stamps proposed and by, decodes
::  once for its answer, and the writer decodes the same JSON, so both
::  compute the same id. An open twin answers the existing action.
::
++  serve-act
  |=  [eyre-id=@ta jon=json]
  =/  m  (fiber:fiber:nexus ,~)
  ^-  form:m
  ;<  now=@da  bind:m  get-time:io
  =/  stamped=json  (fill-act:orr jon now 'http')
  =/  got  (de-action:orr stamped now 'http')
  ?:  ?=(%| -.got)  (send-err eyre-id 400 p.got)
  ;<  missing=(unit bid:orr)  bind:m  (first-missing 1 ~(tap in about.p.got))
  ?^  missing  (send-err eyre-id 400 (cat 3 'about: no such body ' u.missing))
  ;<  policy=json  bind:m  (read-json (rf 1 / %'policy.json'))
  ;<  all=(list [id=@ta a=action:orr])  bind:m  (load-actions 1)
  =/  twin=(unit [id=@ta a=action:orr])  (open-twin all kind.p.got title.p.got)
  ?^  twin
    %^  send-json  eyre-id  200
    (pairs:enjs:format ~[['id' s+id.u.twin] ['status' s+status.a.u.twin] ['existing' b+&]])
  =/  a=action:orr  p.got(status (initial-status:orr kind.p.got (auto-of:orr policy)))
  =/  op=json  (pairs:enjs:format ~[['op' s+'act'] ['action' stamped]])
  ;<  err=(unit tang)  bind:m  (poke-soft:io (rf 1 / %'main.sig') [[/ %json] op])
  ?^  err  (send-err eyre-id 500 'the writer refused the poke')
  %^  send-json  eyre-id  200
  (pairs:enjs:format ~[['id' s+(act-id:orr a)] ['status' s+status.a] ['existing' b+|]])
::  +serve-actions: ?status=open (the default: proposed and approved),
::  all, or one status; newest first
::
++  serve-actions
  |=  [eyre-id=@ta args=quay:eyre]
  =/  m  (fiber:fiber:nexus ,~)
  ^-  form:m
  =/  want=@t  (fall (get-key:kv:html-utils 'status' args) 'open')
  ;<  all=(list [id=@ta a=action:orr])  bind:m  (load-actions 1)
  =/  keep
    |=  [id=@ta a=action:orr]
    ^-  ?
    ?:  =('all' want)  &
    ?:  =('open' want)  (is-open:orr a)
    =(want `@t`status.a)
  =/  shown=(list [id=@ta a=action:orr])
    %+  sort  (skim all keep)
    |=([x=[id=@ta a=action:orr] y=[id=@ta a=action:orr]] (gth proposed.a.x proposed.a.y))
  (send-json eyre-id 200 a+(turn shown |=([id=@ta a=action:orr] (en-action:orr id a))))
++  serve-set-action
  |=  [eyre-id=@ta id=@ta jon=json]
  =/  m  (fiber:fiber:nexus ,~)
  ^-  form:m
  =/  want=@t  (gs:orr jon 'status')
  ;<  cur=view:nexus  bind:m  (peek:io (rf 1 /actions id) ~)
  ?.  ?=([%file *] cur)  (send-err eyre-id 404 'no such action')
  =/  a=(unit action:orr)  (read-action:orr (sang-noun:tarball sang.cur))
  ?~  a  (send-err eyre-id 500 'unreadable action')
  ?.  (transition-ok:orr status.u.a `@tas`want)
    (send-err eyre-id 409 (rap 3 'cannot go from ' status.u.a ' to ' want ~))
  =/  op=json
    %-  pairs:enjs:format
    ~[['op' s+'set-action'] ['id' s+id] ['status' s+want] ['note' s+(gs:orr jon 'note')]]
  ;<  err=(unit tang)  bind:m  (poke-soft:io (rf 1 / %'main.sig') [[/ %json] op])
  ?^  err  (send-err eyre-id 500 'the writer refused the poke')
  (send-json eyre-id 200 (pairs:enjs:format ~[['id' s+id] ['status' s+want] ['ok' b+&]]))
++  serve-doc
  |=  [eyre-id=@ta name=@ta]
  =/  m  (fiber:fiber:nexus ,~)
  ^-  form:m
  ;<  doc=json  bind:m  (read-json (rf 1 / name))
  (send-json eyre-id 200 doc)
++  serve-set-doc
  |=  [eyre-id=@ta op=@t jon=json]
  =/  m  (fiber:fiber:nexus ,~)
  ^-  form:m
  ?.  ?=([%o *] jon)  (send-err eyre-id 400 'a JSON object is required')
  =/  pk=json  (pairs:enjs:format ~[['op' s+op] ['doc' jon]])
  ;<  err=(unit tang)  bind:m  (poke-soft:io (rf 1 / %'main.sig') [[/ %json] pk])
  ?^  err  (send-err eyre-id 500 'the writer refused the poke')
  (send-json eyre-id 200 (pairs:enjs:format ~[['ok' b+&]]))
```

- [ ] **Step 6b: The beacon in milliseconds, and no rev in a write answer**

Task 4 found two things on the ship: a raw `@da` in `/beacon/rev` is a 128-bit number, past what a browser's `JSON.parse` keeps exactly, and the `rev` a write answer reads right after its poke is the rev before the writer applied. So the beacon carries milliseconds since 1970, and write answers carry no `rev`; the state view keeps it.

Replace `+bump-beacon` with:

```hoon
::  +bump-beacon: the change beacon moves once per op that changed the
::  tree, never on a refusal or a no-op. Milliseconds since 1970, so a
::  browser keeps it exact.
::
++  bump-beacon
  =/  m  (fiber:fiber:nexus ,~)
  ^-  form:m
  ;<  now=@da  bind:m  get-time:io
  =/  ms=@ud  (div (sub now ~1970.1.1) (div ~s1 1.000))
  (over:io (rf 0 /beacon %rev) [[/ %json] (numb:enjs:format ms)])
```

In `+serve-observe`, delete the line `;<  rev=json  bind:m  (read-json (rf 1 /beacon %rev))` and drop `['rev' rev]` from the final `pairs` list, which becomes `~[['bodies' a+bodies-res] ['observations' a+obs-res]]`.

- [ ] **Step 7: Deploy with the fast loop and read the bang**

```bash
W=$SHIP; CK=$JAR
D=$W/grubbery/ball/apps/shell.shell/desks/orrery.desk/desk
I="$D/data/orrery.orrery_app"
curl -s -b $CK -X POST --data-urlencode action=write-text --data-urlencode content@code/nex/orrery/app.hoon "$D/code/nex/orrery/app.hoon"
curl -s -b $CK -X POST --data-urlencode action=reload-nexus "$I" -o /dev/null
sleep 25; curl -s -b $CK "$I?info=1" | python3 -c 'import sys,json; print(json.load(sys.stdin)["bang"])'
```

Expected: `None`. Otherwise fix the named line, write again, reload again.

- [ ] **Step 8: Smoke every new route by hand**

Run each and compare to the expectation. Fix the nexus and redeploy on any mismatch before moving on.

```bash
A=$W/apps/orrery/api
J='-H content-type:application/json'
curl -s -b $CK -X POST $J $A/bodies -d '{"id":"person/sarah","name":"Sarah","aliases":["wife"]}'
#   {"id":"person/sarah","ok":true,"existing":false}
curl -s -b $CK "$A/resolve?q=wife"
#   [{"id":"person/sarah","kind":"person","name":"Sarah","match":"exact"}]
curl -s -b $CK -X POST $J $A/observe -d '{"observations":[{"subject":"person/sarah","attr":"status","value":"at work","source":{"kind":"user","id":""}}]}'
#   observations[0].ok true; note its id as OID
curl -s -b $CK $A/body/person/sarah | python3 -m json.tool | head -30
#   attrs.status.value "at work"; observations[0].status "live"
curl -s -b $CK -X POST $J $A/retract -d '{"id":"OID","note":"wrong person"}'
#   {"id":"OID","ok":true}
curl -s -b $CK $A/body/person/sarah | python3 -c 'import sys,json; d=json.load(sys.stdin); print(d["attrs"], [o["status"] for o in d["observations"]])'
#   {} ['retracted']
curl -s -b $CK -X POST $J $A/act -d '{"kind":"task","title":"Call Sarah back","about":["person/sarah"]}'
#   {"id":"...","status":"approved","existing":false}     (policy auto-approves task)
curl -s -b $CK -X POST $J $A/act -d '{"kind":"task","title":"Call Sarah back"}'
#   the same id, "existing": true
curl -s -b $CK -X POST $J $A/act -d '{"kind":"message","title":"Tell Sarah","payload":{"to":"~sampel"}}'
#   "status":"proposed"
curl -s -b $CK "$A/actions"
#   both actions, newest first
curl -s -b $CK -X POST $J $A/actions/AID -d '{"status":"done"}'
#   {"id":"AID","status":"done","ok":true}   for the task; a second POST with done answers 409
curl -s -b $CK "$A/actions?status=done"
#   the task only
curl -s -b $CK $A/policy
#   {"auto":["task","note"],"push":true,"retention_days":365}
curl -s -b $CK -X PUT $J $A/policy -d '{"auto":[],"push":false,"retention_days":365}'
#   {"ok":true}; then a new task proposal answers "proposed"
curl -s -b $CK -X PUT $J $A/policy -d '{"auto":["task","note"],"push":true,"retention_days":365}'
curl -s -b $CK -X DELETE $A/body/person/sarah
#   {"id":"person/sarah","ok":true}; GET /body/person/sarah then answers 404
curl -s -b $CK "$I/tr/last?raw=1"
#   the last op, ok true
```

The push: with `push: true` the `act` calls above poke `/sys/push`. On the dev ship nothing subscribes, so nothing arrives, and that is fine. What matters is that the writer survived: `/tr/last` reads `{"op":"act","ok":true,...}` after the task proposal.

- [ ] **Step 9: Commit and push**

```bash
git add code/nex/orrery/app.hoon
git commit -m "The rest of the API: bodies, retract, actions under policy, schema and policy documents, compaction, push"
git push origin main
```

### Task 6: The gate: spec section 8 as a script

**Files:**
- Create: `scripts/api-matrix.py`

**Interfaces:**
- Consumes: every route from Tasks 4 and 5.
- Produces: the phase 1 gate. `python3 scripts/api-matrix.py $SHIP $JAR` exits 0 and prints `ALL OK`.

The scenario's times are computed from the ship's present (the breakdown is twelve hours ago), because a fold at "now" would read fixed future dates as not yet true. Source ids carry a `matrix-` prefix so a rerun can retract what an earlier run wrote.

- [ ] **Step 1: Write the script**

`scripts/api-matrix.py`:

```python
#!/usr/bin/env python3
"""api-matrix.py HOST JAR
The HTTP gate for orrery: spec section 8, the stranded car, against a
fake ship. HOST like $SHIP; JAR a curl cookie jar from
POST /~/login. Exits 1 on any failure. Safe to rerun: it deletes,
retracts and dismisses what an earlier run left."""
import json, subprocess, sys
from datetime import datetime, timedelta, timezone

HOST, JAR = sys.argv[1:3]
API = HOST + '/apps/orrery/api'
INSTANCE = HOST + '/grubbery/ball/apps/shell.shell/desks/orrery.desk/desk/data/orrery.orrery_app'
fails = []


def curl(method, url, body=None, jar=JAR, timeout=60):
    cmd = ['curl', '-s', '-m', str(timeout), '-X', method, '-w', '\n%{http_code}', url]
    if jar:
        cmd += ['-b', jar]
    if body is not None:
        cmd += ['-H', 'content-type: application/json', '-d', json.dumps(body)]
    out = subprocess.run(cmd, capture_output=True, text=True).stdout
    text, _, code = out.rpartition('\n')
    try:
        data = json.loads(text) if text else None
    except json.JSONDecodeError:
        data = text
    return int(code or 0), data


def check(label, cond, detail=''):
    print(('  ok   ' if cond else '  FAIL ') + label + ('' if cond else '   ' + str(detail)[:300]))
    if not cond:
        fails.append(label)


def iso(dt):
    return dt.replace(microsecond=0).strftime('%Y-%m-%dT%H:%M:%SZ')


now = datetime.now(timezone.utc).replace(microsecond=0)
T0 = now - timedelta(hours=12)                       # the breakdown
M2 = T0 + timedelta(hours=1, minutes=35)             # the tow arrives
M3 = T0 + timedelta(hours=4, minutes=5)              # home, car at the shop
UNTIL = T0 + timedelta(hours=4)
DUE = T0 + timedelta(hours=15)
SIT = 'situation/' + T0.strftime('%Y-%m-%d') + '-breakdown'
SHOP = 'place/johns-machine-shop'
TITLE = "Call John's Machine Shop about the Subaru"
USER = {'kind': 'user', 'id': 'matrix-setup'}


def src(i):
    return {'kind': 'phone-dm', 'id': 'matrix-' + i}


def ref(b):
    return {'ref': b}


def state(at=None):
    code, d = curl('GET', API + '/state' + (f'?at={at}' if at else ''))
    check(f'GET /state {at or ""} answers 200', code == 200, (code, d))
    return d if code == 200 else {'bodies': [], 'situations': [], 'actions': []}


def body(bid, at=None):
    return curl('GET', API + f'/body/{bid}' + (f'?at={at}' if at else ''))


def attrs(d, bid):
    for b in d.get('bodies', []):
        if b['id'] == bid:
            return b['attrs']
    return None


def val(d, bid, attr):
    a = attrs(d, bid)
    return None if not a or attr not in a else a[attr]['value']


def observe(bodies, observations):
    return curl('POST', API + '/observe', {'bodies': bodies, 'observations': observations})


def obs(subject, attr, value, at, source, until=None, conf=100):
    o = {'subject': subject, 'attr': attr, 'value': value, 'at': iso(at),
         'conf': conf, 'source': source, 'by': 'api-matrix'}
    if until is not None:
        o['until'] = iso(until)
    return o


def dictish(x):
    return x if isinstance(x, dict) else {}


def all_ok(d, key, n):
    items = dictish(d).get(key, [])
    return len(items) == n and all(x.get('ok') for x in items)


# ── 0. a clean slate ────────────────────────────────────────────────
print('0. clean slate')
for b in ['person/sarah', 'thing/subaru', 'place/home', SHOP, SIT]:
    curl('DELETE', API + '/body/' + b)
code, me = body('person/me')
check('person/me exists', code == 200, (code, me))
for o in dictish(me).get('observations', []):
    if o['source']['id'].startswith('matrix-') and o['status'] != 'retracted':
        curl('POST', API + '/retract', {'id': o['id'], 'note': 'matrix rerun'})
code, acts = curl('GET', API + '/actions?status=open')
for a in (acts if isinstance(acts, list) else []):
    if a['title'] == TITLE:
        curl('POST', API + f'/actions/{a["id"]}', {'status': 'dismissed', 'note': 'matrix rerun'})
curl('PUT', API + '/policy', {'auto': ['task', 'note'], 'push': True, 'retention_days': 365})

# ── 1. setup ────────────────────────────────────────────────────────
print('1. setup')
code, d = observe(
    [{'id': 'person/sarah', 'name': 'Sarah', 'aliases': ['Sarah', 'wife']},
     {'id': 'thing/subaru', 'name': 'The Subaru', 'aliases': ['the car', 'subaru']},
     {'id': 'place/home', 'name': 'Home'}],
    [obs('person/me', 'spouse', ref('person/sarah'), T0 - timedelta(days=1), USER),
     obs('person/me', 'home', ref('place/home'), T0 - timedelta(days=1), USER),
     obs('thing/subaru', 'owner', ref('person/me'), T0 - timedelta(days=1), USER)])
check('setup answers 200', code == 200, (code, d))
check('setup bodies all ok', all_ok(d, 'bodies', 3), d)
check('setup observations all ok', all_ok(d, 'observations', 3), d)
s = state()
check('me.spouse is sarah, read back at once', val(s, 'person/me', 'spouse') == ref('person/sarah'), attrs(s, 'person/me'))
check('me.home is home', val(s, 'person/me', 'home') == ref('place/home'), attrs(s, 'person/me'))
check('the subaru is mine', val(s, 'thing/subaru', 'owner') == ref('person/me'), attrs(s, 'thing/subaru'))

# ── 2. message 1 ────────────────────────────────────────────────────
print('2. message 1: "car died on route 9, stranded waiting for a tow"')
code, d = observe(
    [{'id': SIT, 'name': 'Breakdown on Route 9'}],
    [obs('person/me', 'status', 'stranded, waiting for a tow', T0, src('m1'), UNTIL, 90),
     obs('person/me', 'location', 'Route 9', T0, src('m1'), None, 90),
     obs('thing/subaru', 'status', 'broken down', T0, src('m1'), None, 90),
     obs('thing/subaru', 'location', 'Route 9', T0, src('m1'), None, 90),
     obs(SIT, 'status', 'open', T0, src('m1')),
     obs(SIT, 'participants', ref('person/me'), T0, src('m1')),
     obs(SIT, 'participants', ref('person/sarah'), T0, src('m1')),
     obs(SIT, 'participants', ref('thing/subaru'), T0, src('m1')),
     obs(SIT, 'location', 'Route 9', T0, src('m1')),
     obs(SIT, 'started', iso(T0), T0, src('m1'))])
check('message 1 lands', code == 200 and all_ok(d, 'observations', 10), d)
s = state(iso(T0 + timedelta(minutes=5)))   # spec: the state view at 22:05, inside the until
check('me.status is stranded', val(s, 'person/me', 'status') == 'stranded, waiting for a tow', attrs(s, 'person/me'))
check('me on Route 9', val(s, 'person/me', 'location') == 'Route 9', attrs(s, 'person/me'))
check('subaru on Route 9', val(s, 'thing/subaru', 'location') == 'Route 9', attrs(s, 'thing/subaru'))
check('subaru is broken down', val(s, 'thing/subaru', 'status') == 'broken down', attrs(s, 'thing/subaru'))
parts = (attrs(s, SIT) or {}).get('participants')
check('situation has three participants', isinstance(parts, list) and len(parts) == 3, parts)
check('the situation is on Route 9', val(s, SIT, 'location') == 'Route 9', attrs(s, SIT))
check('the situation started at the breakdown', val(s, SIT, 'started') == iso(T0), attrs(s, SIT))
check('situation is open', SIT in s['situations'], s['situations'])
sarah = [b for b in s['bodies'] if b['id'] == 'person/sarah']
check("sarah's state names the situation", bool(sarah) and SIT in sarah[0]['involved'], sarah)

# ── 3. message 2 ────────────────────────────────────────────────────
print('3. message 2: "tow guy is here, taking it to john\'s machine shop"')
code, r = curl('GET', API + '/resolve?q=john%27s%20machine%20shop')
check('resolve finds no shop yet', code == 200 and r == [], (code, r))
code, d = observe(
    [{'id': SHOP, 'name': "John's Machine Shop", 'aliases': ["John's", 'the shop']}],
    [obs('thing/subaru', 'status', "being towed to John's Machine Shop", M2, src('m2'), None, 90),
     obs('person/me', 'status', 'riding with the tow', M2, src('m2'), UNTIL, 80)])
check('message 2 lands', code == 200 and all_ok(d, 'observations', 2), d)
RIDING = d['observations'][1].get('id', '') if code == 200 and len(dictish(d).get('observations', [])) > 1 else ''
s = state()
check('subaru is being towed', val(s, 'thing/subaru', 'status') == "being towed to John's Machine Shop", attrs(s, 'thing/subaru'))
code, r = curl('GET', API + '/resolve?q=the%20shop')
check('resolve finds the shop by alias', code == 200 and [x['id'] for x in r] == [SHOP], r)

# ── 4. message 3 ────────────────────────────────────────────────────
print('4. message 3: "home. left the car at john\'s overnight"')
batch = [obs('thing/subaru', 'location', ref(SHOP), M3, src('m3'), None, 95),
         obs('thing/subaru', 'status', 'at the shop, awaiting diagnosis', M3, src('m3'), None, 90),
         obs('person/me', 'location', ref('place/home'), M3, src('m3'), None, 95),
         obs('person/me', 'status', None, M3, src('m3')),
         obs(SIT, 'status', 'car at shop, awaiting diagnosis', M3, src('m3'))]
code, d = observe([], batch)
check('message 3 lands', code == 200 and all_ok(d, 'observations', 5), d)
s = state()
check("subaru at John's", val(s, 'thing/subaru', 'location') == ref(SHOP), attrs(s, 'thing/subaru'))
check('subaru awaits diagnosis', val(s, 'thing/subaru', 'status') == 'at the shop, awaiting diagnosis', attrs(s, 'thing/subaru'))
check('me at home', val(s, 'person/me', 'location') == ref('place/home'), attrs(s, 'person/me'))
check('me has no status', 'status' not in (attrs(s, 'person/me') or {}), attrs(s, 'person/me'))
check('situation still open', SIT in s['situations'], s['situations'])
past = state(iso(T0 + timedelta(hours=1)))
check('an hour in, the subaru was still on Route 9', val(past, 'thing/subaru', 'location') == 'Route 9', attrs(past, 'thing/subaru'))
check('an hour in, me was stranded', val(past, 'person/me', 'status') == 'stranded, waiting for a tow', attrs(past, 'person/me'))
code, d = observe([], batch)
check('resubmitting message 3 changes nothing',
      code == 200 and len(d['observations']) == 5 and all(o['ok'] and o['existing'] for o in d['observations']), d)

# ── 5. the analyst ──────────────────────────────────────────────────
print('5. the analyst proposes a task')
s = state()
check('no open action yet', not any(a['title'] == TITLE for a in s['actions']), s['actions'])
prop = {'kind': 'task', 'title': TITLE, 'about': ['thing/subaru', SHOP], 'due': iso(DUE), 'by': 'api-matrix'}
code, a = curl('POST', API + '/act', prop)
check('proposal answers 200', code == 200, (code, a))
check('policy auto-approves a task', code == 200 and a['status'] == 'approved' and not a['existing'], a)
AID = a['id'] if code == 200 else ''
code, acts = curl('GET', API + '/actions')
check('the task is on the open list', code == 200 and any(x['id'] == AID for x in acts), acts)
code, a2 = curl('POST', API + '/act', prop)
check('a second identical proposal answers the same id', code == 200 and a2['id'] == AID and a2['existing'], a2)
code, last = curl('GET', INSTANCE + '/tr/last?raw=1')
check('the writer noted the act', code == 200 and isinstance(last, dict) and last.get('op') == 'act' and last.get('ok') is True, last)
code, bs = body('thing/subaru')
check('the subaru view lists the open task', code == 200 and any(x['id'] == AID for x in bs['actions']), bs.get('actions') if code == 200 else bs)

# ── 6. retract, done, compact ───────────────────────────────────────
print('6. retract, done, compact')
code, d = curl('POST', API + '/retract', {'id': RIDING, 'note': 'never rode along'})
check('retract answers 200', code == 200, (code, d))
code, me = body('person/me')
riding = [o for o in dictish(me).get('observations', []) if o['id'] == RIDING]
check('the timeline labels it retracted', bool(riding) and riding[0]['status'] == 'retracted', riding)
code, d = curl('POST', API + f'/actions/{AID}', {'status': 'done'})
check('the task is marked done', code == 200 and d['status'] == 'done', (code, d))
code, acts = curl('GET', API + '/actions')
check('it left the open list', code == 200 and not any(x['id'] == AID for x in acts), acts)
code, d = curl('POST', API + f'/actions/{AID}', {'status': 'approved'})
check('done is terminal', code == 409, (code, d))
curl('PUT', API + '/policy', {'auto': ['task', 'note'], 'push': True, 'retention_days': 0})
code, d = observe([], [obs('thing/subaru', 'plate', 'ABC 123', now - timedelta(minutes=1), USER)])
check('a write with retention 0 lands', code == 200 and all_ok(d, 'observations', 1), (code, d))
code, bs = body('thing/subaru')
statuses = {o['id']: o['status'] for o in bs.get('observations', [])} if code == 200 else {}
check('superseded observations were culled', code == 200 and 'superseded' not in statuses.values(), statuses)
check('live observations remain', code == 200 and bs['attrs']['location']['value'] == ref(SHOP) and bs['attrs']['plate']['value'] == 'ABC 123', bs.get('attrs') if code == 200 else bs)
curl('PUT', API + '/policy', {'auto': ['task', 'note'], 'push': True, 'retention_days': 365})

# ── 7. refusals ─────────────────────────────────────────────────────
print('7. refusals')
code, d = curl('GET', API + '/state', jar=None)
check('no cookie is 403', code == 403, (code, d))
code, d = observe([{'id': f'place/p{i}'} for i in range(51)], [])
check('51 bodies is 400 naming bodies', code == 400 and dictish(d).get('error') == 'bodies: over 50', (code, d))
code, d = observe([], [obs('thing/subaru', 'plate', 'x', now - timedelta(minutes=1), USER)] * 201)
check('201 observations is 400 naming observations', code == 400 and dictish(d).get('error') == 'observations: over 200', (code, d))
code, d = observe([], [{'subject': 'thing/subaru', 'attr': 'status', 'value': 'x', 'at': 'yesterday', 'source': USER}])
check('a bad at is refused per item', code == 200 and not d['observations'][0]['ok'] and d['observations'][0]['error'].startswith('at:'), d)
code, d = curl('GET', API + '/state?at=yesterday')
check('a bad ?at is 400', code == 400, (code, d))
code, d = curl('POST', API + '/act', {'kind': 'task', 'title': 'x', 'about': ['thing/nothing']})
check('an unknown about body is 400', code == 400 and str(d.get('error', '')).startswith('about: no such body'), (code, d))
code, d = curl('GET', API + '/nothing')
check('an unknown route is 404', code == 404, (code, d))

print()
print('FAILED: ' + ', '.join(fails) if fails else 'ALL OK')
sys.exit(1 if fails else 0)
```

- [ ] **Step 2: Run the gate**

```bash
chmod +x scripts/api-matrix.py
python3 scripts/api-matrix.py $SHIP $JAR
```

Expected: every line `ok`, then `ALL OK`, exit 0. A `FAIL` line carries the answer that disagreed. Decide whether the script or the nexus is wrong by reading the spec section 8 sentence the check comes from: the spec is the authority, the script transcribes it, the nexus implements it. Fix the wrong one, redeploy the nexus with the fast loop when it changed, rerun until `ALL OK`. Run it twice in a row: the second run must also pass, which proves the clean-slate step.

- [ ] **Step 3: Commit and push**

```bash
git add scripts/api-matrix.py code
git commit -m "The gate: spec section 8 as scripts/api-matrix.py, green on the dev ship"
git push origin main
```

### Task 7: Hermeticity, docs, and the release path rehearsed

**Files:**
- Create: `scripts/code-closure.py` (from auspex)
- Create: `docs/releasing.md` (from calendar, names changed)
- Modify: `README.md`, `code/version.json`

**Interfaces:**
- Consumes: everything.
- Produces: a desk that syncs from GitHub through the forge by a version bump, which is the production path, and the docs the next phase reads.

- [ ] **Step 1: The closure check**

```bash
cp ../auspex/scripts/code-closure.py scripts/code-closure.py
python3 scripts/code-closure.py code
```

Expected: it reports nothing missing. If it names a missing marc or lib, vendor it from `<the grubbery checkout>/desk/gub/mar` or `gub/lib` into `code/mar` or `code/lib` (it can do that itself with `--fill <the grubbery checkout>/desk`), and rerun until closed. Then redeploy any new file with the fast loop (`create-file` then `write-text`) and confirm the bang stays `None`.

- [ ] **Step 2: The releasing doc**

```bash
sed -e 's/calendar\.desk/orrery.desk/g' -e 's/calendar\.git_repo/orrery.git_repo/g' \
    -e 's/calendar\.calendar_app/orrery.orrery_app/g' -e 's#nisfeb/calendar#nisfeb/orrery#g' \
    -e 's#/apps/calendar#/apps/orrery#g' -e 's#nex/calendar/app\.hoon#nex/orrery/app.hoon#g' \
    -e 's/Releasing calendar/Releasing orrery/' -e 's/^Calendar is a/Orrery is a/' \
    ../calendar/docs/releasing.md > docs/releasing.md
grep -n -i calendar docs/releasing.md
```

Read every remaining `calendar` mention the grep prints and decide: a sentence about the mechanism that names calendar as the example stays true and stays; a sentence that describes calendar's own files is rewritten for orrery. The two paragraphs on "what makes the live ship update" and "verifying a release actually landed" are the ones the next phase needs. Then append this section at the end:

```markdown
##  8. Orrery's own release checklist

1. `code/version.json` bumped, the number one higher than the last release.
2. `python3 scripts/code-closure.py code` reports nothing missing.
3. Unit tests green on the dev ship: `-test /~sampel-sipnym/grubbery/<rev>/tests/lib/orrery ~`.
4. `python3 scripts/api-matrix.py $SHIP $JAR` prints `ALL OK`, twice in a row.
5. `git push origin main`, then on the dev ship: `POST /grubbery/forge/api/run {"repo":"orrery.git_repo","command":"pull"}`, and within a minute the desk's root `version.json` reads the new number and the instance's `bang` is `null`.
6. The live ship's steps are the owner's: the catalog line, the kernel commit, the sync, the consent, the publish.
```

- [ ] **Step 3: The README**

Replace the "Design, under review" bullet in `README.md` with these bullets:

```markdown
- Design: `docs/superpowers/specs/2026-09-16-orrery-design.md`. Phase 1 plan: `docs/superpowers/plans/2026-09-16-orrery-phase-1.md`.
- `code/` is the desk: the nexus at `code/nex/orrery/app.hoon`, the model in `code/lib/orrery.hoon`, the marcs under `code/mar`. `code/version.json` is what replicates.
- The HTTP API lives under `/apps/orrery/api`: `state`, `body/<kind>/<slug>`, `resolve`, `observe`, `retract`, `bodies`, `act`, `actions`, `schema`, `policy`. Owner only. Spec section 6 has the table.
- Gates, against the dev ship: `tests/lib/orrery.hoon` with `-test`, and `scripts/api-matrix.py`. Releasing: `docs/releasing.md`.
```

- [ ] **Step 4: Rehearse the release path**

Bump the version and let the desk sync from GitHub through the forge, which proves the repo and the ship agree after all the fast-loop writes:

```bash
python3 - <<'EOF'
import json; json.dump({"version": 2}, open('code/version.json', 'w')); print(open('code/version.json').read())
EOF
git add code/version.json docs/releasing.md README.md scripts/code-closure.py code
git commit -m "Version 2: closure check, releasing doc, README; the first release through the forge"
git push origin main
W=$SHIP; CK=$JAR
curl -s -b $CK -X POST -H 'content-type: application/json' -d '{"repo":"orrery.git_repo","command":"pull"}' $W/grubbery/forge/api/run
# expected: ok
```

Then, checking every 15 seconds for at most 3 minutes:

```bash
curl -s -b $CK "$W/grubbery/ball/apps/shell.shell/desks/orrery.desk/version.json?raw=1"
# expected, once synced: {"version": 2}
curl -s -b $CK "$W/grubbery/ball/apps/shell.shell/desks/orrery.desk/desk/data/orrery.orrery_app?info=1" | python3 -c 'import sys,json; print(json.load(sys.stdin)["bang"])'
# expected: None
python3 scripts/api-matrix.py $SHIP $JAR
# expected: ALL OK
```

If the version syncs but the bang is not `None`, a file on the ship differed from the repo (a fast-loop write that never made it into git, or the reverse). The bang names the line; fix the repo, bump to 3, push, pull, and check again. If the version never changes, `POST /grubbery/desk/orrery/fetch-latest` pulls without the version gate (releasing.md section 5a).

- [ ] **Step 5: Report**

Phase 1 is done when: 29 unit tests green with the revision pinned, `api-matrix.py` green twice, the desk at version 2 synced through the forge with a null bang, and `main` pushed. Report those four facts with the numbers you saw, and the dev ship's desk revision the tests ran at. Do not touch the live ship.

### Task 8: The product-review amendments: a ship on a body, the self-reference guard, action history, push modes, the audit log

Added 2026-09-16 after the spec was amended (spec sections 2, 3, 5 and 14). Stored shapes change, so the readers get a ladder: a `%1` body or action still loads and is lifted; new writes are `%2`.

**Files:**
- Modify: `code/lib/orrery.hoon`
- Modify: `tests/lib/orrery.hoon`
- Modify: `code/nex/orrery/app.hoon`
- Modify: `scripts/api-matrix.py`
- Modify: `code/version.json` (3)

**Interfaces:**
- Consumes: everything from Tasks 2 to 7.
- Produces: `body` with `ship=(unit @p)`; `step`, `action` with `history=(list step)`; `body-1`, `action-1`, `stored-body-1`, `stored-action-1`; `stored-body` and `stored-action` now `%2`; `transition`, `push-mode-of`, `should-push`, `ring`, `en-step`; `push-of` removed; the writer op `set-action` carries `by`; the tree gains `/tr/log`; the API emits `ship` on bodies and `history` on actions.

- [ ] **Step 1: Append the failing tests**

Insert before the final `--` of `tests/lib/orrery.hoon`:

```hoon
::
::  ==  amendments: ship, history, push modes, the ring
::
++  test-de-body-ship
  =/  got  (de-body:orr (jo '{"id":"person/sarah","ship":"~sampel-palnet"}') t0)
  =/  bad  (de-body:orr (jo '{"id":"person/sarah","ship":"sarah"}') t0)
  ;:  weld
    (expect-eq !>(`(unit @p)`[~ ~sampel-palnet]) !>(?:(?=(%& -.got) ship.body.p.got ~)))
    (expect-eq !>('ship: expected an @p such as ~sampel-palnet') !>(?:(?=(%| -.bad) p.bad 'accepted')))
  ==
++  test-de-obs-self-ref
  =/  got  (de-obs:orr (jo '{"subject":"thing/subaru","attr":"location","value":{"ref":"thing/subaru"},"source":{"kind":"user"}}') t0 'http')
  (expect-eq !>('value.ref: a body cannot refer to itself') !>(?:(?=(%| -.got) p.got 'accepted')))
++  test-transition
  =/  a=action:orr  [%task 'x' ~ ~ ~ 'mcp' t0 %proposed '' ~[[t0 %proposed 'mcp']]]
  =/  b=action:orr  (transition:orr a %approved 'policy' '' (add t0 ~s1))
  =/  c=action:orr  (transition:orr b %done 'user' 'called them' (add t0 ~h1))
  ;:  weld
    (expect-eq !>(%approved) !>(status.b))
    (expect-eq !>(2) !>((lent history.b)))
    (expect-eq !>(`step:orr`[(add t0 ~h1) %done 'user']) !>((rear history.c)))
    (expect-eq !>('called them') !>(note.c))
    (expect-eq !>(3) !>((lent history.c)))
  ==
++  test-push-modes
  ;:  weld
    (expect-eq !>('proposed') !>((push-mode-of:orr starter-policy:orr)))
    (expect-eq !>('none') !>((push-mode-of:orr (jo '{"push":"none"}'))))
    (expect !>((should-push:orr 'all' %approved)))
    (expect !>((should-push:orr 'proposed' %proposed)))
    (expect !>(!(should-push:orr 'proposed' %approved)))
    (expect !>(!(should-push:orr 'none' %proposed)))
    (expect !>((should-push:orr 'bogus' %proposed)))
    (expect !>(!(should-push:orr 'bogus' %approved)))
  ==
++  test-ring
  =/  one=json  (ring:orr [%a ~] (jo '{"n":1}') 2)
  =/  two=json  (ring:orr one (jo '{"n":2}') 2)
  =/  three=json  (ring:orr two (jo '{"n":3}') 2)
  =/  fresh=json  (ring:orr [%o ~] (jo '{"n":9}') 5)
  ;:  weld
    (expect-eq !>(1) !>((lent ?:(?=([%a *] one) p.one ~))))
    (expect-eq !>(2) !>((lent ?:(?=([%a *] three) p.three ~))))
    (expect-eq !>(`json`(jo '{"n":2}')) !>(?:(?=([%a *] three) (snag 0 p.three) ~)))
    (expect-eq !>(1) !>((lent ?:(?=([%a *] fresh) p.fresh ~))))
  ==
++  test-readers-lift
  =/  old-body  [%1 [%person 'Sarah' (sy ~['Sarah']) t0]]
  =/  old-act   [%1 [%task 'x' ~ ~ ~ 'mcp' t0 %approved '']]
  ;:  weld
    (expect-eq !>(`(unit body:orr)`[~ [%person 'Sarah' (sy ~['Sarah']) t0 ~]]) !>((read-body:orr old-body)))
    (expect-eq !>(`(unit (list step:orr))`[~ ~[[t0 %approved 'mcp']]]) !>((bind (read-action:orr old-act) |=(a=action:orr history.a))))
    (expect-eq !>(`(unit body:orr)`~) !>((read-body:orr [%3 'nope'])))
  ==
```

Then update these existing tests in the same file, because `body` and `action` literals gain a field:

- In `test-act-id-shape` the action literal becomes `[%task 'Call the shop' ~ (sy ~['thing/subaru']) ~ 'mcp' t0 %proposed '' ~]`.
- In `test-de-body-ok` add the line `(expect-eq !>(`(unit @p)`~) !>(ship.body.p.got))` inside the `;:  weld`.
- In `test-de-action-ok` add `(expect-eq !>(`(list step:orr)`~[[~2026.9.17..3.00.00 %proposed 'mcp']]) !>(history.p.got))` inside the `;:  weld`.
- In `test-readers` the body literal becomes `[%person 'Sarah' (sy ~['Sarah']) t0 ~]` and the stored form under test becomes `[%2 b]`; the `[%2 'nope']` refusal case becomes `[%3 'nope']`.
- In `test-merge-body` both literals gain a trailing `~` for `ship`, and add inside the `;:  weld`: `(expect-eq !>(`(unit @p)`[~ ~sampel-palnet]) !>(ship:(merge-body:orr old new(ship `~sampel-palnet))))` and `(expect-eq !>(`(unit @p)`[~ ~sampel-palnet]) !>(ship:(merge-body:orr old(ship `~sampel-palnet) new)))`.
- In `test-resolve` the three body literals gain a `ship`: sarah `` `~sampel-palnet ``, the other two `~`; add `(expect-eq !>(`(list bid:orr)`~['person/sarah']) !>((ids '~sampel-palnet')))` inside the `;:  weld`.
- In `test-encoders-roundtrip` the body literal becomes `[%person 'Sarah' ~ t0 ~]`.
- In `test-action-rules` replace the line `(expect !>((push-of:orr starter-policy:orr)))` with `(expect-eq !>('proposed') !>((push-mode-of:orr starter-policy:orr)))`.

- [ ] **Step 2: Run the tests and watch the new ones fail**

Copy the test file, commit, run (recipe under "Working with the dev ship"). Expected: a build failure naming an unknown arm such as `transition` or `step`.

- [ ] **Step 3: Change the library**

In `code/lib/orrery.hoon`:

Replace the `body` and `action` types and the stored shapes with:

```hoon
+$  bid     @t                                  ::  "<kind>/<slug>"
+$  body    [kind=@tas name=@t aliases=(set @t) created=@da ship=(unit @p)]
+$  body-1  [kind=@tas name=@t aliases=(set @t) created=@da]
+$  source  [kind=@t id=@t]
+$  obs
  $:  subject=bid
      attr=@t
      value=json
      at=@da                                    ::  when it became true
      until=(unit @da)                          ::  expected end
      conf=@ud                                  ::  0 to 100
      =source
      by=@t
      seen=@da                                  ::  when the ship recorded it
      retracted=?
      note=@t                                   ::  why it was retracted
  ==
::  one status an action has held, and who set it
+$  step    [at=@da status=@tas by=@t]
+$  action
  $:  kind=@tas
      title=@t
      payload=json
      about=(set bid)
      due=(unit @da)
      by=@t
      proposed=@da
      status=@tas
      note=@t
      history=(list step)
  ==
+$  action-1
  $:  kind=@tas
      title=@t
      payload=json
      about=(set bid)
      due=(unit @da)
      by=@t
      proposed=@da
      status=@tas
      note=@t
  ==
::  what the grubs hold: a version head in front of each shape, so a
::  later shape is told apart by the reader instead of clamming by luck.
::  %1 bodies and actions are lifted by the readers; new writes are %2.
::
+$  stored-body      [%2 =body]
+$  stored-body-1    [%1 =body-1]
+$  stored-obs       [%1 =obs]
+$  stored-action    [%2 =action]
+$  stored-action-1  [%1 =action-1]
```

In `+de-body`, replace the final line `[%& id [kind.u.pk name (sy als) now]]` with:

```hoon
  =/  sj=json  (gj jon 'ship')
  =/  ship=(unit @p)  ?:(?=([%s *] sj) (slaw %p p.sj) ~)
  ?:  &(?=([%s *] sj) ?=(~ ship))  [%| 'ship: expected an @p such as ~sampel-palnet']
  [%& id [kind.u.pk name (sy als) now ship]]
```

In `+de-obs`, after the `value.ref: expected <kind>/<slug>` refusal add:

```hoon
  ?:  &(?=([%o *] value) =(subject (gs value 'ref')))
    [%| 'value.ref: a body cannot refer to itself']
```

In `+de-action`, replace the final line with:

```hoon
  [%& `@tas`kind title payload (sy about) due by u.proposed %proposed '' ~[[u.proposed %proposed by]]]
```

Replace `+read-body` and `+read-action` with the ladders:

```hoon
++  read-body
  |=  n=*
  ^-  (unit body)
  =/  r2  (mule |.(;;(stored-body n)))
  ?:  ?=(%& -.r2)  `body.p.r2
  =/  r1  (mule |.(;;(stored-body-1 n)))
  ?.  ?=(%& -.r1)  ~
  =/  b=body-1  body-1.p.r1
  `[kind.b name.b aliases.b created.b ~]
++  read-action
  |=  n=*
  ^-  (unit action)
  =/  r2  (mule |.(;;(stored-action n)))
  ?:  ?=(%& -.r2)  `action.p.r2
  =/  r1  (mule |.(;;(stored-action-1 n)))
  ?.  ?=(%& -.r1)  ~
  =/  a=action-1  action-1.p.r1
  `[kind.a title.a payload.a about.a due.a by.a proposed.a status.a note.a ~[[proposed.a status.a by.a]]]
```

Replace `+merge-body` with:

```hoon
++  merge-body
  |=  [old=body new=body]
  ^-  body
  :*  kind.old
      ?:(=('' name.new) name.old name.new)
      (~(uni in aliases.old) aliases.new)
      created.old
      ?~(ship.new ship.old ship.new)
  ==
```

In `+en-body` add the row `['ship' `json`?~(ship.b ~ s+(scot %p u.ship.b))]` after `created`. In `+en-action` add the row `['history' a+(turn history.a en-step)]` after `note`, and add above `+en-action`:

```hoon
++  en-step
  |=  st=step
  ^-  json
  (pairs:enjs:format ~[['at' (en-time at.st)] ['status' s+status.st] ['by' s+by.st]])
```

In `+resolve`, inside `hit`, before the `names` line add a ship match:

```hoon
    =/  sh=@t  ?~(ship.b '' (scot %p u.ship.b))
    ?:  &(!=('' sh) =(sh lq))  `[id b %exact]
```

Replace `+push-of` with these three arms, and change `starter-policy`'s row to `['push' s+'proposed']`:

```hoon
::  +push-mode-of: proposed (the default), all, or none
::
++  push-mode-of
  |=  policy=json
  ^-  @t
  =/  m=@t  (gs policy 'push')
  ?:(=('' m) 'proposed' m)
::  +should-push: all pushes every new action; none pushes nothing;
::  proposed, the default and what an unknown mode means, pushes only
::  an action that needs a human
::
++  should-push
  |=  [mode=@t status=@tas]
  ^-  ?
  ?:  =('all' mode)  &
  ?:  =('none' mode)  |
  =(%proposed status)
::  +transition: a new status with its note, appended to the history
::
++  transition
  |=  [a=action want=@tas by=@t why=@t at=@da]
  ^-  action
  a(status want, note why, history (snoc history.a [at want by]))
::  +ring: append to a JSON array and keep the last max entries
::
++  ring
  |=  [log=json entry=json max=@ud]
  ^-  json
  =/  cur=(list json)  ?:(?=([%a *] log) p.log ~)
  =/  all=(list json)  (snoc cur entry)
  =/  n=@ud  (lent all)
  [%a ?:((gth n max) (slag (sub n max) all) all)]
```

- [ ] **Step 4: Run the tests and watch them pass**

Copy both files, commit, run. Expected: 35 `OK` lines (the 29 from before, `test-de-body-ship`, `test-de-obs-self-ref`, `test-transition`, `test-push-modes`, `test-ring`, `test-readers-lift`), no `FAILED`, no `CRASHED`, `ok=%.y`.

- [ ] **Step 5: Change the nexus**

In `code/nex/orrery/app.hoon`:

In `+on-load` add the row `[%fall %& [/tr %log] [[/ %json] [%a ~]]]` after the `/tr/last` row.

Replace `+note` with a pair that also feeds the audit ring:

```hoon
::  +note: the last writer outcome at /tr/last, and the audit ring at
::  /tr/log (the last 500). Fiber prints reach only the raw console; a
::  grub is readable by every tool.
::
++  note
  |=  [op=@t ok=? why=@t]
  =/  m  (fiber:fiber:nexus ,~)
  ^-  form:m
  (note-by op ok why '')
++  note-by
  |=  [op=@t ok=? why=@t by=@t]
  =/  m  (fiber:fiber:nexus ,~)
  ^-  form:m
  ;<  now=@da  bind:m  get-time:io
  =/  entry=json
    %-  pairs:enjs:format
    ~[['op' s+op] ['ok' b+ok] ['why' s+why] ['by' s+by] ['at' (en-time:orr now)]]
  ;<  ~  bind:m  (over:io (rf 0 /tr %last) [[/ %json] entry])
  ;<  log=json  bind:m  (read-json (rf 0 /tr %log))
  (over:io (rf 0 /tr %log) [[/ %json] (ring:orr log entry 500)])
```

In `+ensure-me` the body becomes `[%person 'me' (sy `(list @t)`~['me' 'I']) now `our]`.

In `+write-body` every `` `stored-body:orr`[%1 fresh] `` and `` `stored-body:orr`[%1 merged] `` becomes `%2`. In `+do-act` the make writes `` `stored-action:orr`[%2 a] ``; in `+do-set-action` the overwrite writes `` `stored-action:orr`[%2 next] ``.

In `+do-act`, replace everything from the line `=/  a=action:orr  p.got(status (initial-status:orr kind.p.got (auto-of:orr policy)))` to the end of the arm with:

```hoon
  =/  auto=?  =(%approved (initial-status:orr kind.p.got (auto-of:orr policy)))
  =/  a=action:orr  ?.(auto p.got (transition:orr p.got %approved 'policy' '' now))
  =/  id=@ta  (act-id:orr a)
  ;<  ex=?  bind:m  (peek-exists:io (rf 0 /actions id))
  ?:  ex  (pure:m |)
  ;<  *  bind:m
    (make-gained-soft:io (rf 0 /actions id) |+[[[/orrery %action] `stored-action:orr`[%2 a]] ~])
  ;<  ~  bind:m
    ?.  (should-push:orr (push-mode-of:orr policy) status.a)  (pure:(fiber:fiber:nexus ,~) ~)
    (push-soft a id)
  ;<  ~  bind:m  (note-by 'act' & '' by.a)
  (pure:m &)
```

Replace `+do-set-action` with:

```hoon
++  do-set-action
  |=  jon=json
  =/  m  (fiber:fiber:nexus ,?)
  ^-  form:m
  =/  id=@t  (gs:orr jon 'id')
  =/  want=@t  (gs:orr jon 'status')
  =/  why=@t  (gs:orr jon 'note')
  =/  by=@t  =/(b (gs:orr jon 'by') ?:(=('' b) 'user' b))
  ?:  (gth (met 3 why) max-note:orr)  (refuse 'set-action' 'note: over 500 bytes')
  =/  road=road:tarball  (rf 0 /actions `@ta`id)
  ;<  cur=view:nexus  bind:m  (peek:io road ~)
  ?.  ?=([%file *] cur)  (refuse 'set-action' (cat 3 'no action ' id))
  =/  a=(unit action:orr)  (read-action:orr (sang-noun:tarball sang.cur))
  ?~  a  (refuse 'set-action' 'unreadable action')
  ?.  (transition-ok:orr status.u.a `@tas`want)
    (refuse 'set-action' (rap 3 'cannot go from ' status.u.a ' to ' want ~))
  ;<  now=@da  bind:m  get-time:io
  =/  next=action:orr  (transition:orr u.a `@tas`want by why now)
  ;<  ~  bind:m  (over:io road [[/orrery %action] `stored-action:orr`[%2 next]])
  ;<  ~  bind:m  (note-by 'set-action' & '' by)
  (pure:m &)
```

In `+serve-set-action` the op gains the actor: the `pairs` list becomes `~[['op' s+'set-action'] ['id' s+id] ['status' s+want] ['note' s+(gs:orr jon 'note')] ['by' s+(gs:orr jon 'by')]]`.

- [ ] **Step 5b: Polish the Task 5 review asked for**

Four small things, all in `code/nex/orrery/app.hoon`:

1. In `+bump-beacon` guard the subtraction like `+compact` does: `=/  ms=@ud  ?:((lth now ~1970.1.1) 0 (div (sub now ~1970.1.1) (div ~s1 1.000)))`.
2. The writer's no-op branches leave no trace in `/tr/last`. In `+do-act`, the twin branch `?^  (open-twin all kind.p.got title.p.got)  (pure:m |)` becomes `?^  (open-twin all kind.p.got title.p.got)  (note-then-no 'act' 'an open action with this kind and title exists')`, and the id-collision branch `?:  ex  (pure:m |)` becomes `?:  ex  (note-then-no 'act' 'an action with this id exists')`. In `+do-retract`, `?:  retracted.obs.r.u.hit  (pure:m |)` becomes `?:  retracted.obs.r.u.hit  (note-then-no 'retract' 'already retracted')`. Add the helper beside `+refuse`:

```hoon
::  +note-then-no: a no-op that still leaves its reason in /tr/last
::
++  note-then-no
  |=  [op=@t why=@t]
  =/  m  (fiber:fiber:nexus ,?)
  ^-  form:m
  ;<  ~  bind:m  (note op & why)
  (pure:m |)
```

3. `+do-set-doc` bumps the beacon on an unchanged document. Before its `over`, read the current one and answer no change when equal:

```hoon
  ;<  cur=json  bind:m  (read-json (rf 0 / name))
  ?:  =(cur doc)  (note-then-no op 'unchanged')
```

4. `+do-retract` writes a body's observation and must compact like `+do-observe` does. After its `over` add `;<  ~  bind:m  (compact kind.u.hit slug.u.hit)`.
5. A push leaves no trace of its own. In `+push-soft`, after the poke, add `;<  ~  bind:m  (note-by 'push' & title.a by.a)` so the audit log shows every notification attempt; the act's own note follows it and stays the last outcome.

Deploy with the fast loop (write-text, reload-nexus, bang `None`). Bodies and actions written by earlier tasks are `%1` grubs: after the reload, `GET /api/state` must still list them (the ladder lifts them), and `GET /api/body/person/me` shows `"ship": "~sampel-sipnym"` only after the next write to it, so upsert it once: `POST /api/bodies {"id":"person/me","ship":"~sampel-sipnym"}`.

- [ ] **Step 6: Extend the gate**

In `scripts/api-matrix.py`:

- Every policy `PUT` body uses `'push': 'proposed'` instead of `'push': True`.
- In section 0 after the `person/me exists` check add: `curl('POST', API + '/bodies', {'id': 'person/me', 'ship': '~sampel-sipnym'})`.
- In section 1 after `me.spouse is sarah` add:

```python
code, r = curl('GET', API + '/resolve?q=%7Ewex')
check('resolve finds me by ship', code == 200 and [x['id'] for x in r] == ['person/me'], r)
code, d = curl('POST', API + '/bodies', {'id': 'person/sarah', 'ship': 'sarah'})
check('a bad ship is 400', code == 400 and d.get('error', '').startswith('ship:'), (code, d))
code, d = observe([], [obs('thing/subaru', 'location', ref('thing/subaru'), T0, USER)])
check('a self-reference is refused per item', code == 200 and not d['observations'][0]['ok'] and 'itself' in d['observations'][0]['error'], d)
```

- In section 5 after `the task is on the open list` add:

```python
mine = [x for x in acts if x['id'] == AID]
check('the history shows proposed then approved by policy', bool(mine) and [(h['status'], h['by']) for h in mine[0]['history']] == [('proposed', 'api-matrix'), ('approved', 'policy')], mine)
```

- In section 6 after `it left the open list` add:

```python
code, allacts = curl('GET', API + '/actions?status=done')
done = [x for x in allacts if x['id'] == AID]
check('done is in the history with the actor', bool(done) and done[0]['history'][-1]['status'] == 'done' and done[0]['history'][-1]['by'] == 'user', done)
code, log = curl('GET', INSTANCE + '/tr/log?raw=1')
check('the audit log ends with the set-action', code == 200 and isinstance(log, list) and log[-1]['op'] == 'set-action' and log[-1]['by'] == 'user', log[-3:] if isinstance(log, list) else log)
```

Run it twice: `ALL OK` both times.

- [ ] **Step 7: Version 3 through the forge, commit, push**

Set `code/version.json` to `{"version": 3}`, commit, push, pull on the forge, and confirm the desk root version reads 3 with a null bang, as in Task 7 step 4.

```bash
git add code tests scripts
git commit -m "A ship on a body, the self-reference guard, action history, push modes and the audit log; version 3"
git push origin main
```

---

## Self-review

**Spec coverage.** Section 3 bodies, observations, actions and the fold: Tasks 2 and 3, tested. `person/me` seeded: Task 4 (`ensure-me`, laid on the first request rather than at rise, see the note in `on-file`). Upsert semantics, no merge: Tasks 4 and 5. Observation ids and idempotence: Task 2, checked live in Task 4 step 7 and Task 6. Retraction with a note: Task 5. Derived views, `?at`, multi, null, expiry, involved: Task 3 and the routes in Tasks 4 and 5. `schema.json` and `policy.json` seeded and editable: Tasks 3, 4 and 5. Compaction on write: Task 5. Section 5 tree and writer: Task 4 (every persistent path has a row; `/beacon/rev` nested; `/tr/last`; retention on for bodies and actions through `make-gained-soft`). Section 6 HTTP routes and per-item observe answers: Tasks 4 and 5. Owner gate: Task 4. Caps: Task 2 and the batch caps in Task 4. Section 7 ask: Task 4 `weir-json`. Section 8 scenario: Task 6. Section 9 constraints: the Global Constraints block and the code. Section 10 tests: Tasks 2, 3 and 6. Section 12 release mechanics: Task 7.

**Not in this plan, by the spec's phasing.** The MCP tools and the discovery patch (phase 2), the page (phase 3), the catalog line and the live ship's release (phase 4). Keep-SSE on the beacon is grubbery's route and needs no code here; phase 3 wires the page to it.

**Two things to verify on the ship that the plan assumes.** First, that `make-gained-soft` keeps a body's versions (spec: history on). The instance answers `?info=1` without a version list, so this is not asserted by the gate; if phase 3 wants a body's history it reads it with `born:io`. Second, that a request fiber's answer follows the writer's apply: the gate's "read back at once" checks catch a race if there is one, and the fix would be a reply grub per request, as the spec allows.

**Type consistency.** `row` is `[id=@ta =obs]` everywhere; `loaded` is `[id=bid =body rows=(list row)]`; actions travel as `[id=@ta a=action]`; every decoder answers `(each shape @t)`; every writer op answers `?`; every route arm answers `form:(fiber ,~)`. Op names between the routes and `+apply`: `ensure-me`, `observe`, `upsert-body`, `delete-body`, `retract`, `act`, `set-action`, `set-schema`, `set-policy`.

