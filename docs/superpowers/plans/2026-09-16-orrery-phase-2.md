# Orrery Phase 2 Implementation Plan: cross-ship sharing

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** A body shared from one ship lands on another, keeps current, takes edits back in edit mode, and stops on revoke, proven by a two-ship gate with `~wex` as host and `~feb` as peer.

**Architecture:** The shared unit is a body's directory. The host records shares in `shares.json`, grants the peer a peek on that directory through one usergroup per shared body, and pokes an offer at the peer's public inbox `shares.sig`. The peer records accepted offers in `ship-remotes.json` and runs one follower fiber, `sync.sig`, that every five minutes (and on a prod) deep-peeks each host's body directory over `/sys/ames/ships/`, rewrites the observations onto the local target body (`person/me` when the shared body's ship is our own) and hands them to the writer as an ordinary observe op with the host as asserter and source; in edit mode it also pokes the host's inbox with the local observations not yet pushed. Every mechanism is lifted from calendar's ship sharing, which runs on this same grubbery.

**Tech Stack:** Hoon at zuse 408 on grubbery, `~wex` (host, `http://localhost:8080`, dojo tmux `0:2.0`, mount `~/software/wex/grubbery`) and `~feb` (peer, `http://localhost:8081`, dojo tmux `0:0.0`), Python 3 with `curl` for the gate.

**Spec:** `docs/superpowers/specs/2026-09-16-orrery-design.md`, section 11, "Phase 2: cross-ship sharing, the minimal protocol", which binds; sections 3, 5 and 6 for the model and routes it builds on.

## Global Constraints

- Prose rules for every doc, comment and commit message: no em-dashes, no hard-wrapped markdown, simple sentences. Hoon comments follow grubbery's `style-guide.md`: `::  +arm: lowercase headline`, a bare `::` line below, plain ASCII, `::  ==  title` dividers.
- No AI attribution anywhere. Commits go to `nisfeb/orrery` as nisfeb, one at the end of every task with the message given; push where a step says push.
- Never touch `~ricsul-bilwyt`; never boot, kill or restart a pier; tmux window `0:3` is an ssh session to ricsul, never send keys there. Dojo discipline: one line, verify its echo, STOP after 2 minutes of waiting or 30 seconds without an echo.
- Never run two gates against the same ship at once.
- Every persistent path has a covering `%fall` row in `on-load`; every blot laid has a marc in `code/mar`; marcs are noun passthroughs; long-lived fibers use nexus-relative roads (`rf`/`rv`, depth 0 at the root, 1 under `/requests`); no `$` with arguments inside a `;<` continuation; the writer and the inbox never crash on input; the library stays import-free.
- The sender of a cross-ship poke is read from the transport (`get-poke-src:io`), never from the payload. A peer may write only about a body shared with it in edit mode. An offer or revoke is accepted from any ship and only records or marks; nothing a foreign ship sends reaches the writer without the inbox rewriting `by` and `source`.
- A remote poke's timeout is not a failure (grubbery's remote acks are unobservable): the answer `notified` is advisory. Only a veto or a nack is a failure.
- Hoon under zuse 408: colon form for wing-of-expression; `%=` and dot wings on legs, not arms; widen a `?~`-narrowed list before `levy`/`roll`/`turn`; bind computed tapes to a `=/  x=tape` face before interpolation.

---

## Working with two ships

Everything from phase 1's "Working with `~wex`" section still applies (login, the fast loop, the tree browser, the dojo recipe for `-test`, the stop rules; see `docs/superpowers/plans/2026-09-16-orrery-phase-1.md`). Phase 2 adds `~feb`.

**Ships.** `~wex` is the host: `W=http://localhost:8080`, cookie jar `/tmp/wex.cookies`, dojo pane `0:2.0`, `+code` `novwel-tamfes-daplex-misdem`. `~feb` is the peer: `F=http://localhost:8081`, cookie jar `/tmp/feb.cookies`, dojo pane `0:0.0`. Read feb's code once with the dojo recipe (`tmux send-keys -t 0:0.0 -l '+code'; tmux send-keys -t 0:0.0 Enter; sleep 3; tmux capture-pane -p -t 0:0.0 | tail -3`), log in with it, and never write it into the repo or a report.

**Two instance paths, one shape.** Both ships install the desk at `/apps/shell.shell/desks/orrery.desk/desk/data/orrery.orrery_app`. The offer still carries the host's path, because a peer must not assume it.

**The fast loop on the peer** is the same `write-text` and `reload-nexus` sequence against `F`; the desk on feb follows wex's desk over ames (Task 1), so a version bump on wex reaches feb on its own, but during development each ship's code tree is written directly and both must be kept identical to the repo file.

**Unit tests** run on `~wex` only, as in phase 1.

---

## File Structure

| file | responsibility |
|---|---|
| `code/lib/orrery.hoon` | gains the pure share helpers: keys, the target mapping, observation rewriting for mirror and push, the safe group name, the row and offer codecs |
| `tests/lib/orrery.hoon` | gains their tests |
| `code/nex/orrery/app.hoon` | gains the tree rows, the ask roads, the usergroup and registry helpers, the inbox fiber, the sync fiber, the share routes, the remote poke and peek with timeouts |
| `code/mar/gall-poke.hoon`, `timer-set.hoon`, `timer-rest.hoon`, `timer-wake.hoon`, `ships.hoon`, `weir.hoon`, `poke-ack.hoon`, `usergroups/registry-action.hoon` | kernel marcs the new pokes and grubs use, vendored |
| `scripts/ship-share-matrix.py` | the two-ship gate |
| `docs/sharing.md` | how sharing works for a person, and the routes |

---

### Task 1: The peer ship: `~feb` installs orrery from `~wex`

The production path for every subscriber is a desk whose source is the distributor's desk over ames. Rehearsing it on feb proves the path phase 5 will rely on, and gives the gate its second ship.

**Files:** none in the repo. Ship state only.

- [ ] **Step 1: Log in to both ships**

```bash
W=http://localhost:8080; CK=/tmp/wex.cookies
curl -s -c $CK -o /dev/null -w '%{http_code}\n' -X POST $W/~/login --data 'password=novwel-tamfes-daplex-misdem'   # 200
tmux send-keys -t 0:0.0 -l '+code'; tmux send-keys -t 0:0.0 Enter; sleep 3; tmux capture-pane -p -t 0:0.0 | grep -v '^\s*$' | tail -3
F=http://localhost:8081; FK=/tmp/feb.cookies
curl -s -c $FK -o /dev/null -w '%{http_code}\n' -X POST $F/~/login --data 'password=<the code the pane printed>'   # 200
```

- [ ] **Step 2: Open wex's desk to subscribers**

The distributor must open a desk to a usergroup before a subscriber can mirror it (the shell's `+published` comment: "without the grant a subscriber gets a desk that mirrors nothing"). The `/public` group is what calendar used on wex:

```bash
curl -s -b $CK -X POST -H 'content-type: application/json' -d '{"add":"/public"}' \
  "$W/grubbery/api/poke/apps/shell.shell/desks/orrery.desk/share.usergroups?blot=/json"
# expected: an ack (an empty or ok body, no error text)
curl -s -b $CK "$W/grubbery/ball/apps/shell.shell/desks/orrery.desk/share.usergroups?info=1" | python3 -c 'import sys,json; print(json.load(sys.stdin).get("text"))'
# expected: {/public}   (the node's mark is /usergroups, so ?raw=1 answers jam bytes, not text)
```

- [ ] **Step 3: Install the desk on feb, following wex**

```bash
curl -s -b $FK -X POST -H 'content-type: application/json' \
  -d '{"name":"orrery","code":"~wex/apps/shell.shell/desks/orrery.desk/desk/code"}' $F/apps/grubbery/desks/add
# expected: created
```

Poll every 15 seconds for at most 3 minutes:

```bash
curl -s -b $FK "$F/grubbery/ball/apps/shell.shell/desks/orrery.desk/version.json?raw=1"     # {"version": 3}
I2="$F/grubbery/ball/apps/shell.shell/desks/orrery.desk/desk/data/orrery.orrery_app"
curl -s -b $FK "$I2?info=1" | python3 -c 'import sys,json; d=json.load(sys.stdin); print(d["bang"], [c["name"] for c in d["children"]])'
# expected: None, and the children phase 1 lays
```

If the version stays `null` past 3 minutes, `POST $F/grubbery/desk/orrery/fetch-latest` pulls without the version gate; if that also does nothing in 3 minutes, STOP and report what the desk's `source.json` and feb's console show. A cross-ship read of wex's desk needs wex to answer feb over ames; both fake ships share this machine and did this for calendar on 2026-09-14.

- [ ] **Step 4: Approve the ask on feb and confirm both APIs**

```bash
APP=/apps/shell.shell/desks/orrery.desk/desk/data/orrery.orrery_app
curl -s -b $FK -X POST -H 'content-type: application/json' -d "{\"action\":\"approve-weir\",\"app\":\"$APP\",\"granted\":{\"poke\":[\"/sys/bowl.sig\",\"/sys/eyre/\",\"/sys/push/\"],\"peek\":[\"/sys/link/\"],\"make\":[]}}" $F/apps/grubbery/permits   # ok
curl -s -b $FK -X POST -H 'content-type: application/json' -d "{\"app\":\"$APP\"}" $F/apps/grubbery/permits/reload   # ok
sleep 15
curl -s -b $FK $F/apps/orrery/api/state | python3 -c 'import sys,json; d=json.load(sys.stdin); print(d["me"], [b["id"] for b in d["bodies"]])'
# expected: person/me ['person/me']
curl -s -b $FK -X POST -H 'content-type: application/json' $F/apps/orrery/api/bodies -d '{"id":"person/me","ship":"~feb"}'
# expected: {"id":"person/me","ok":true,"existing":true}
curl -s -b $CK $W/apps/orrery/api/state | python3 -c 'import sys,json; print(json.load(sys.stdin)["me"])'   # person/me
```

- [ ] **Step 5: Report**

No commit. Report feb's desk version, the bang, and the two state answers, in the task report.

### Task 2: The library: share keys, the target mapping, carried observations

**Files:**
- Modify: `code/lib/orrery.hoon` (append before the closing `--`)
- Modify: `tests/lib/orrery.hoon` (append before the closing `--`)

**Interfaces:**
- Produces: `share-key`, `mirror-target`, `group-name`, `carry-obs`, `receive-obs`, `is-local`, `from-ship`. Signatures in the code.

- [ ] **Step 1: Append the failing tests**

```hoon
::
::  ==  sharing
::
++  test-share-helpers
  ;:  weld
    (expect-eq !>('~wex/person/sarah') !>((share-key:orr ~wex 'person/sarah')))
    (expect-eq !>('person/me') !>((mirror-target:orr ~feb `~feb 'person/sarah')))
    (expect-eq !>('person/sarah') !>((mirror-target:orr ~feb `~wex 'person/sarah')))
    (expect-eq !>('person/sarah') !>((mirror-target:orr ~feb ~ 'person/sarah')))
    (expect-eq !>('orrery-person-sarah') !>((group-name:orr %person %sarah)))
  ==
::  a carried observation names the other side's body and carries the
::  sender's grub name; the receiver sets by and source from the ship
::  it heard it from, so a decode on the receiving side reads as the
::  sender's claim
++  test-carry-and-receive
  =/  r=row:orr  ['1789596300-abcdef01' o1]
  =/  j=json  (receive-obs:orr ~wex (carry-obs:orr 'person/me' r))
  =/  back  (de-obs:orr j t0 'x')
  ?.  ?=(%& -.back)  (expect !>(|))
  ;:  weld
    (expect-eq !>('person/me') !>(subject.p.back))
    (expect-eq !>('~wex') !>(by.p.back))
    (expect-eq !>(`source:orr`['ship' '~wex/1789596300-abcdef01']) !>(source.p.back))
    (expect-eq !>(value:o1) !>(value.p.back))
    (expect-eq !>(at:o1) !>(at.p.back))
    (expect-eq !>(90) !>(conf.p.back))
    (expect-eq !>(`json`b+|) !>((gj:orr j 'retracted')))
    (expect !>(!(is-local:orr p.back)))
    (expect !>((is-local:orr o1)))
    (expect !>((from-ship:orr p.back ~wex)))
    (expect !>(!(from-ship:orr p.back ~feb)))
    (expect !>(!(from-ship:orr o1 ~wex)))
  ==
```

- [ ] **Step 2: Run the tests and watch the new ones fail**

Copy the test file to the wex mount, commit, run (phase 1's recipe). Expected: a build failure naming an unknown arm such as `share-key`.

- [ ] **Step 3: Append the arms**

```hoon
::  ==  sharing (spec section 11)
::
::  +share-key: how a peer keys what one host sent it about one body
::
++  share-key
  |=  [host=@p id=bid]
  ^-  @t
  (rap 3 (scot %p host) '/' id ~)
::  +mirror-target: where a shared body lands on the peer: our own
::  person/me when the body's ship is us, else its own id
::
++  mirror-target
  |=  [our=@p ship=(unit @p) id=bid]
  ^-  bid
  ?:  &(?=(^ ship) =(our u.ship))  'person/me'
  id
::  +group-name: the usergroup that may read one shared body
::
++  group-name
  |=  [kind=@tas slug=@ta]
  ^-  @t
  (rap 3 'orrery-' kind '-' slug ~)
::  +carry-obs: an observation as one ship sends it to another: the
::  other side's body id as subject, the sender's grub name as oid, and
::  whether the sender retracted it. by and source are deliberately
::  absent: the receiver sets them from the transport, never from here.
::
++  carry-obs
  |=  [subject=bid r=row]
  ^-  json
  =/  o=obs  obs.r
  %-  pairs:enjs:format
  :~  ['subject' s+subject]
      ['attr' s+attr.o]
      ['value' value.o]
      ['at' (en-time at.o)]
      ['until' (en-maybe-time until.o)]
      ['conf' (numb:enjs:format conf.o)]
      ['oid' s+id.r]
      ['retracted' b+retracted.o]
  ==
::  +receive-obs: a carried observation as the receiver stores it: the
::  sender ship is the asserter, and the source is the sender and the
::  sender's grub name
::
++  receive-obs
  |=  [sender=@p j=json]
  ^-  json
  ?.  ?=([%o *] j)  j
  =/  sid=@t  (rap 3 (scot %p sender) '/' (gs j 'oid') ~)
  =/  src=json  (pairs:enjs:format ~[['kind' s+'ship'] ['id' s+sid]])
  [%o (~(gas by p.j) ~[['by' s+(scot %p sender)] ['source' src]])]
::  +is-local: made here, not mirrored from a ship
::
++  is-local  |=(o=obs ^-(? !=('ship' kind.source.o)))
::  +from-ship: mirrored from this ship (its source id starts "~ship/")
::
++  from-ship
  |=  [o=obs who=@p]
  ^-  ?
  ?.  =('ship' kind.source.o)  |
  =/  pre=@t  (rap 3 (scot %p who) '/' ~)
  =(pre (end [3 (met 3 pre)] id.source.o))
```

- [ ] **Step 4: Run the tests and watch them pass**

Copy both files, commit, run. Expected: 37 `OK`, no `FAILED`, no `CRASHED`, `ok=%.y`.

- [ ] **Step 5: Commit**

```bash
git add code/lib/orrery.hoon tests/lib/orrery.hoon
git commit -m "Share helpers: keys, the target mapping, carried observations, with tests"
```

### Task 3: The nexus: the share records, the grant, the inbox, and the share routes

**Files:**
- Modify: `code/nex/orrery/app.hoon`
- Create: `code/mar/gall-poke.hoon`, `code/mar/timer-set.hoon`, `code/mar/timer-rest.hoon`, `code/mar/timer-wake.hoon`, `code/mar/ships.hoon`, `code/mar/weir.hoon`, `code/mar/poke-ack.hoon`, `code/mar/usergroups/registry-action.hoon` (copied byte for byte from `/home/sneagan/software/groundwire/grubbery/desk/gub/mar/`)

**Interfaces:**
- Consumes: Task 2's helpers; phase 1's `rf`, `rv`, `body-dir`, `read-json`, `rows-in`, `note-by`, `send-json`, `send-err`, `handle-request`.
- Produces, for Task 4: `orrery-instance`, `self-base`, `ug-set`, `ug-read-weir`, `lay-inbox-road`, `set-share-group`, `remote-poke-wait`, `peek-remote-wait`, the tree rows and the inbox fiber; `apply-carried`, `poke-writer`, `observe-fresh`, `retract-each`; the routes `POST /api/share`, `DELETE /api/share/<kind>/<slug>/<ship>`, `GET /api/shares`, `POST /api/accept`, `POST /api/decline`, `POST /api/sync` (the last lays the inbox road and pokes `sync.sig`, which Task 4 gives a process).

- [ ] **Step 1: Vendor the eight marcs**

```bash
K=/home/sneagan/software/groundwire/grubbery/desk/gub/mar
mkdir -p code/mar/usergroups
for f in gall-poke timer-set timer-rest timer-wake ships weir poke-ack; do cp $K/$f.hoon code/mar/$f.hoon; done
cp $K/usergroups/registry-action.hoon code/mar/usergroups/registry-action.hoon
python3 scripts/code-closure.py code    # expected: nothing missing after Step 3, rerun then
```

- [ ] **Step 2: The tree and the ask**

In `+on-load`, after the `/tr/log` row, add:

```hoon
          ::  sharing (spec section 11). shares.json: body id to the ships
          ::  it is shared with and the mode. shares.sig: the inbox other
          ::  ships poke offers, revokes and edits into. share-offers.json:
          ::  what was offered to us. ship-remotes.json: what we accepted.
          ::  sync.sig: the follower that pulls and pushes.
          [%fall %& [/ %'shares.json'] [[/ %json] [%o ~]]]
          [%fall %& [/ %'shares.sig'] [[/ %sig] ~]]
          [%fall %& [/ %'share-offers.json'] [[/ %json] [%o ~]]]
          [%fall %& [/ %'ship-remotes.json'] [[/ %json] [%o ~]]]
          [%fall %& [/ %'sync.sig'] [[/ %sig] ~]]
```

Replace `+weir-json` with:

```hoon
++  weir-json
  ^-  json
  =/  line  |=([r=@t w=@t] `json`(pairs:enjs:format ~[['road' s+r] ['why' s+w]]))
  %-  pairs:enjs:format
  :~  :-  'poke'
      :-  %a
      :~  (line '/sys/bowl.sig' 'read the current time and our ship')
          (line '/sys/eyre/' 'bind /apps/orrery and answer requests')
          (line '/sys/push/' 'notify you when the assistant proposes or files an action. Refuse this and proposals wait silently in the inbox')
          (line '/sys/gall/' 'tell another ship you shared a body with it, revoke that, and send it your observations on a body it shared with you in edit mode. Refuse this and sharing with ships is unavailable; everything else works')
          (line '/sys/behn/' 'the follower ticks every five minutes to pull what other ships shared with you, and a message to another ship gives up after thirty seconds')
          (line '/sys/ames/registry' 'let the ships you share a body with read it. Refuse this and sharing with ships is unavailable')
          (line '/sys/ames/usergroups/' 'keep one group per shared body: the ships that may read it')
      ==
      :-  'peek'
      :-  %a
      :~  (line '/sys/link/' 'find where this app is installed, so the page can address its own writer and an offer can say where to read')
          (line '/sys/ames/usergroups/' 'see which ships a body is shared with')
          (line '/sys/ames/ships/' 'read a body another ship shared with you, and keep it current. Refuse this and bodies shared with you are unavailable')
      ==
      :-  'make'
      :-  %a
      :~  (line '/sys/ames/usergroups/' 'make the group for a body the first time it is shared')
      ==
  ==
```

- [ ] **Step 3: The inbox fiber**

In `+on-file`, before the `[[%requests ~] @]` case, add:

```hoon
          ::  the inbox: other ships poke offers, revokes, and observations
          ::  on bodies shared with them in edit mode. The sender is the
          ::  transport's; the payload is data; nothing reaches the writer
          ::  without by and source rewritten here. A local poke is ignored.
          [~ %'shares.sig']
        ;<  ~  bind:m  (rise-wait:io prod "%orrery inbox: failed")
        |-
        ;<  [=from:fiber:nexus =sage:tarball]  bind:m  take-poke-from:io
        =/  src=(unit @p)  (get-poke-src:io from)
        ;<  our=@p  bind:m  get-our:io
        ;<  ~  bind:m
          ?:  |(?=(~ src) =(our (fall src our)))  (pure:m ~)
          (take-inbox (fall src our) sage)
        $
```

- [ ] **Step 4: Append the helper arms before the closing `--`**

```hoon
::  ==  sharing: where things are
::
++  orrery-instance  `path`/apps/'shell.shell'/desks/'orrery.desk'/desk/data/'orrery.orrery_app'
++  ug-base     `path`/sys/ames/usergroups
++  public-grp  `path`/sys/ames/usergroups/'public.grp'
::  +self-base: where this instance lives, from the shell's link registry
::  (/sys/link/orrery/dest.lanes: every instance claiming the name, ours
::  among them). ~ when the road is refused or the registry has no row.
::
++  self-base
  =/  m  (fiber:fiber:nexus ,(unit path))
  ^-  form:m
  ;<  vw=(unit view:nexus)  bind:m  (peek-soft:io [%& %& /sys/link/orrery %'dest.lanes'] ~)
  ?.  ?=([~ %file *] vw)  (pure:m ~)
  =/  ls=(unit (set lane:tarball))
    (mole |.(!<((set lane:tarball) (need-vase:tarball sang.u.vw))))
  ?~  ls  (pure:m ~)
  =/  dirs=(list path)
    (murn ~(tap in u.ls) |=(=lane:tarball ?:(?=(%| -.lane) `p.lane ~)))
  ?~  dirs  (pure:m ~)
  (pure:m `i.dirs)
::  +ug-read-weir, +ug-set: a usergroup's how and who, read and written
::  whole, the way calendar keeps its share groups
::
++  ug-read-weir
  |=  gdir=path
  =/  m  (fiber:fiber:nexus ,weir:nexus)
  ^-  form:m
  ;<  hv=(unit view:nexus)  bind:m  (peek-soft:io [%& %& gdir %'how.weir'] ~)
  ?~  hv  (pure:m *weir:nexus)
  ?.  ?=([%file *] u.hv)  (pure:m *weir:nexus)
  (pure:m (fall (mole |.(;;(weir:nexus (sang-noun:tarball sang.u.hv)))) *weir:nexus))
++  ug-set
  |=  [gname=@t ships=(set @p) pk=(set road:tarball) pok=(set road:tarball)]
  =/  m  (fiber:fiber:nexus ,~)
  ^-  form:m
  =/  gdir=path  (snoc ug-base (crip (weld (trip gname) ".grp")))
  ;<  old=weir:nexus  bind:m  (ug-read-weir gdir)
  =/  =weir:nexus  [make.old pok pk]
  ;<  ~  bind:m  (over:io [%& %& gdir %'who.ships'] [[/ %ships] ships])
  ;<  ~  bind:m  (over:io [%& %& gdir %'how.weir'] [[/ %weir] weir])
  (pure:m ~)
::  +set-share-group: the ships a body is shared with may peek its
::  directory. Edit mode adds nothing here: any ship may poke the inbox,
::  and the inbox checks the share record before it applies an edit.
::
++  set-share-group
  |=  [base=path kind=@tas slug=@ta mine=(map @t json)]
  =/  m  (fiber:fiber:nexus ,~)
  ^-  form:m
  =/  ships=(set @p)
    %-  ~(gas in *(set @p))
    (murn ~(tap by mine) |=([s=@t *] (slaw %p s)))
  =/  dir=road:tarball  [%& %| (weld base /bodies/[kind]/[slug])]
  (ug-set (group-name:orr kind slug) ships (sy ~[dir]) ~)
::  +lay-inbox-road: our shares.sig takes pokes from any ship, through
::  the /public group's weir. Quiet when the roads are refused: sharing
::  is optional.
::
++  lay-inbox-road
  =/  m  (fiber:fiber:nexus ,~)
  ^-  form:m
  ;<  base=(unit path)  bind:m  self-base
  ?~  base  (pure:m ~)
  ;<  old=weir:nexus  bind:m  (ug-read-weir public-grp)
  =/  road=road:tarball  [%& %& u.base %'shares.sig']
  ?:  (~(has in poke.old) road)  (pure:m ~)
  ;<  reg=(unit tang)  bind:m  (reg-register-at-soft:io [u.base %'shares.sig'])
  ?^  reg  (pure:m ~)
  ;<  err=(unit tang)  bind:m  (reg-how-soft:io /public [~ (sy road ~) ~])
  (pure:m ~)
::  +remote-poke-wait: a poke to another ship's grubbery, answered or
::  timed out (a peer that is down must not park the fiber). A timeout
::  is not a failure: the poke usually landed.
::
++  remote-poke-wait
  |=  [target=@p =lane:tarball jon=json]
  =/  m  (fiber:fiber:nexus ,?)
  ^-  form:m
  ;<  now=@da  bind:m  get-time:io
  =/  req=load:remo:nexus  [[/share-poke lane] %poke [[/ %json] jon]]
  ;<  w=wire  bind:m  (nonce:io /share-poke)
  ;<  ~  bind:m
    %-  send-dart:io
    [%node w &+&+[/sys/gall %'main.sig'] %poke [[/ %gall-poke] [[target %grubbery] grubbery-load+req]]]
  ;<  ~  bind:m  (set-timer:io /remote (add now ~s30))
  ;<  ok=?  bind:m
    |=  input:fiber:nexus
    :+  ~  q.state
    ?+  in  [%skip ~]
        ~  [%wait ~]
        [~ %veto %node * * *]
      ?.(=(w wire.dart.u.in) [%skip ~] [%done %.n])
        [~ %pack * *]
      ?.  =(w wire.u.in)  [%skip ~]
      ?~(err.u.in [%wait ~] [%done %.n])
        [~ %poke * *]
      ?:  =([/ %timer-wake] p.sage.u.in)
        ?.(?=([%remote *] !<(path q.sage.u.in)) [%skip ~] [%done %.n])
      ?.  =([/ %poke-ack] p.sage.u.in)  [%skip ~]
      =/  [aw=wire err=(unit tang)]  !<([wire (unit tang)] q.sage.u.in)
      ?.  =(w aw)  [%skip ~]
      [%done ?=(~ err)]
    ==
  ;<  ~  bind:m  (cancel-timer:io /remote)
  (pure:m ok)
::  +peek-remote-wait: a deep peek of another ship's file or directory,
::  ~ on veto, miss or timeout
::
++  peek-remote-wait
  |=  [target=@p road=road:tarball]
  =/  m  (fiber:fiber:nexus ,(unit view:nexus))
  ^-  form:m
  ;<  now=@da  bind:m  get-time:io
  =/  until=@da  (add now ~s30)
  ;<  pw=wire  bind:m  (nonce:io /peek)
  =/  rr=road:tarball
    ?-  -.road
      %|  road
      %&
        =/  prefix=path  /sys/ames/ships/[(scot %p target)]/root
        ?-  -.p.road
          %&  [%& %& (weld prefix path.p.p.road) name.p.p.road]
          %|  [%& %| (weld prefix p.p.road)]
        ==
    ==
  ;<  ~  bind:m  (send-dart:io %node pw rr %peek ~ ~ %.y)
  ;<  ~  bind:m  (set-timer:io /remote until)
  ;<  got=(unit view:nexus)  bind:m
    |=  input:fiber:nexus
    :+  ~  q.state
    ?+  in  [%skip ~]
        ~  [%wait ~]
        [~ %veto %node * * *]
      ?.(=(pw wire.dart.u.in) [%skip ~] [%done ~])
        [~ %peek * *]
      ?.(=(pw wire.u.in) [%skip ~] [%done `view.u.in])
        [~ %poke * *]
      ?.  =([/ %timer-wake] p.sage.u.in)  [%skip ~]
      ?.(?=([%remote *] !<(path q.sage.u.in)) [%skip ~] [%done ~])
    ==
  ;<  ~  bind:m  (cancel-timer:io /remote)
  (pure:m got)
::  ==  the inbox
::
::  +take-inbox: one poke from another ship: an offer, a revoke, or
::  observations on a body we shared with it in edit mode
::
++  take-inbox
  |=  [src=@p =sage:tarball]
  =/  m  (fiber:fiber:nexus ,~)
  ^-  form:m
  =/  jon=json  (fall (mole |.(!<(json q.sage))) ~)
  =/  act=@t  (gs:orr jon 'action')
  =/  id=@t  (gs:orr jon 'id')
  ?:  =(~ (parse-bid:orr id))
    (note-by 'inbox' | 'id: expected <kind>/<slug>' (scot %p src))
  =/  key=@t  (share-key:orr src id)
  ?:  =('offer' act)  (take-offer src key id jon)
  ?:  =('revoke' act)  (take-revoke src key)
  ?:  =('observe' act)  (take-edit src id jon)
  (note-by 'inbox' | (cat 3 'unknown action ' act) (scot %p src))
::  +take-offer: a host offers a body. An offer for a share already
::  accepted only updates the row's mode: no second offer.
::
++  take-offer
  |=  [src=@p key=@t id=bid:orr jon=json]
  =/  m  (fiber:fiber:nexus ,~)
  ^-  form:m
  ;<  now=@da  bind:m  get-time:io
  =/  mode=@t  ?:(=('edit' (gs:orr jon 'mode')) 'edit' 'read')
  ;<  rows=json  bind:m  (read-json (rf 0 / %'ship-remotes.json'))
  =/  rm=(map @t json)  ?:(?=([%o *] rows) p.rows ~)
  ?:  (~(has by rm) key)
    =/  row=json  (fall (~(get by rm) key) ~)
    ?.  ?=([%o *] row)  (pure:m ~)
    =/  next=json  [%o (~(put by p.row) 'mode' s+mode)]
    ;<  ~  bind:m  (over:io (rf 0 / %'ship-remotes.json') [[/ %json] [%o (~(put by rm) key next)]])
    (note-by 'offer' & 'mode updated' (scot %p src))
  ;<  offers=json  bind:m  (read-json (rf 0 / %'share-offers.json'))
  =/  cur=(map @t json)  ?:(?=([%o *] offers) p.offers ~)
  ::  a full inbox drops new offers; 200 is far past what a person gets
  ?:  &((gte ~(wyt by cur) 200) !(~(has by cur) key))
    (note-by 'offer' | 'inbox full' (scot %p src))
  =/  offer=json
    %-  pairs:enjs:format
    :~  ['host' s+(scot %p src)]
        ['id' s+id]
        ['ship' s+(gs:orr jon 'ship')]
        ['name' s+(gs:orr jon 'name')]
        ['mode' s+mode]
        ['base' s+(gs:orr jon 'base')]
        ['at' (en-time:orr now)]
    ==
  ;<  ~  bind:m  (over:io (rf 0 / %'share-offers.json') [[/ %json] [%o (~(put by cur) key offer)]])
  (note-by 'offer' & key (scot %p src))
::  +take-revoke: the offer and the accepted row go; the mirrored
::  observations stay, with the host still named as their source
::
++  take-revoke
  |=  [src=@p key=@t]
  =/  m  (fiber:fiber:nexus ,~)
  ^-  form:m
  ;<  offers=json  bind:m  (read-json (rf 0 / %'share-offers.json'))
  =/  cur=(map @t json)  ?:(?=([%o *] offers) p.offers ~)
  ;<  ~  bind:m  (over:io (rf 0 / %'share-offers.json') [[/ %json] [%o (~(del by cur) key)]])
  ;<  rows=json  bind:m  (read-json (rf 0 / %'ship-remotes.json'))
  =/  rm=(map @t json)  ?:(?=([%o *] rows) p.rows ~)
  ;<  ~  bind:m  (over:io (rf 0 / %'ship-remotes.json') [[/ %json] [%o (~(del by rm) key)]])
  (note-by 'revoke' & key (scot %p src))
::  +take-edit: a peer's observations on a body we shared with it in
::  edit mode. The share record decides; every row must name the shared
::  body; by and source become the sender before the writer sees them.
::
++  take-edit
  |=  [src=@p id=bid:orr jon=json]
  =/  m  (fiber:fiber:nexus ,~)
  ^-  form:m
  ;<  shares=json  bind:m  (read-json (rf 0 / %'shares.json'))
  =/  mode=@t  (gs:orr (gj:orr shares id) (scot %p src))
  ?.  =('edit' mode)  (note-by 'edit' | 'not shared in edit mode' (scot %p src))
  =/  rows=(list json)
    %+  skim  (scag max-obs:orr (ga:orr jon 'observations'))
    |=(j=json &(?=([%o *] j) =(id (gs:orr j 'subject'))))
  ?~  rows  (note-by 'edit' | 'nothing about the shared body' (scot %p src))
  ;<  n=@ud  bind:m  (apply-carried 0 src `(list json)`rows)
  (note-by 'edit' & (scot %ud n) (scot %p src))
::  ==  carried rows: what another ship sent, or what we read from it
::
::  +apply-carried: rows from one ship about one of our bodies (the
::  subject is ours already). A row we do not hold becomes an
::  observation from that ship, through the writer; a row we hold that
::  the ship retracted since is retracted here. Answers the number of
::  writer pokes.
::
++  apply-carried
  |=  [up=@ud src=@p rows=(list json)]
  =/  m  (fiber:fiber:nexus ,@ud)
  ^-  form:m
  ?~  rows  (pure:m 0)
  =/  subject=bid:orr  (gs:orr i.rows 'subject')
  =/  pk  (parse-bid:orr subject)
  ?~  pk  (pure:m 0)
  ;<  vw=view:nexus  bind:m  (peek:io (rv up (body-dir kind.u.pk slug.u.pk)) ~)
  ?.  ?=([%ball *] vw)  (pure:m 0)
  =/  pre=@t  (rap 3 (scot %p src) '/' ~)
  ::  what we hold from this ship, by the sender's grub name
  =/  held=(map @t [oid=@ta retracted=?])
    %-  ~(gas by *(map @t [oid=@ta retracted=?]))
    %+  murn  (rows-in ball.vw)
    |=  r=row:orr
    ^-  (unit [@t [@ta ?]])
    ?.  (from-ship:orr obs.r src)  ~
    `[(rsh [3 (met 3 pre)] id.source.obs.r) id.r retracted.obs.r]
  =/  all=(list json)  `(list json)`rows
  =/  fresh=(list json)
    %+  murn  all
    |=  j=json
    ^-  (unit json)
    ?.  =(subject (gs:orr j 'subject'))  ~
    ?:  (~(has by held) (gs:orr j 'oid'))  ~
    ?:  =(`json`b+& (gj:orr j 'retracted'))  ~
    `(receive-obs:orr src j)
  =/  gone=(list @ta)
    %+  murn  all
    |=  j=json
    ^-  (unit @ta)
    =/  h=(unit [oid=@ta retracted=?])  (~(get by held) (gs:orr j 'oid'))
    ?~  h  ~
    ?.  &(=(`json`b+& (gj:orr j 'retracted')) !retracted.u.h)  ~
    `oid.u.h
  ;<  ~  bind:m  (observe-fresh up fresh)
  ;<  ~  bind:m  (retract-each up src gone)
  (pure:m (add ?~(fresh 0 1) (lent gone)))
::  +poke-writer: one op to our writer, soft (a refusal is noted there)
::
++  poke-writer
  |=  [up=@ud op=json]
  =/  m  (fiber:fiber:nexus ,~)
  ^-  form:m
  ;<  *  bind:m  (poke-soft:io (rf up / %'main.sig') [[/ %json] op])
  (pure:m ~)
::  +observe-fresh: the rows we do not hold yet, as one observe op
::
++  observe-fresh
  |=  [up=@ud fresh=(list json)]
  =/  m  (fiber:fiber:nexus ,~)
  ^-  form:m
  ?~  fresh  (pure:m ~)
  %+  poke-writer  up
  %-  pairs:enjs:format
  :~  ['op' s+'observe']
      ['bodies' [%a ~]]
      ['observations' a+(scag max-obs:orr `(list json)`fresh)]
  ==
::  +retract-each: retractions carried from a ship, one writer poke each
::
++  retract-each
  |=  [up=@ud src=@p oids=(list @ta)]
  =/  m  (fiber:fiber:nexus ,~)
  ^-  form:m
  ?~  oids  (pure:m ~)
  =/  why=@t  (rap 3 'retracted on ' (scot %p src) ~)
  ;<  ~  bind:m
    (poke-writer up (pairs:enjs:format ~[['op' s+'retract'] ['id' s+i.oids] ['note' s+why]]))
  (retract-each up src t.oids)
::  ==  the share routes, on request fibers
::
::  +serve-share: share a body with a ship: the record, the grant, the
::  offer to the peer's inbox
::
++  serve-share
  |=  [eyre-id=@ta jon=json]
  =/  m  (fiber:fiber:nexus ,~)
  ^-  form:m
  =/  id=@t  (gs:orr jon 'id')
  =/  pk  (parse-bid:orr id)
  ?~  pk  (send-err eyre-id 400 'id: expected <kind>/<slug>')
  =/  shp=(unit @p)  (slaw %p (gs:orr jon 'ship'))
  ?~  shp  (send-err eyre-id 400 'ship: expected an @p')
  ;<  our=@p  bind:m  get-our:io
  ?:  =(u.shp our)  (send-err eyre-id 400 'ship: that is this ship')
  =/  mode=@t  ?:(=('edit' (gs:orr jon 'mode')) 'edit' 'read')
  ;<  cur=view:nexus  bind:m  (peek:io (rf 1 (body-dir kind.u.pk slug.u.pk) %body) ~)
  ?.  ?=([%file *] cur)  (send-err eyre-id 404 'no such body')
  =/  b=(unit body:orr)  (read-body:orr (sang-noun:tarball sang.cur))
  ?~  b  (send-err eyre-id 500 'unreadable body')
  ;<  base=(unit path)  bind:m  self-base
  ?~  base  (send-err eyre-id 500 'cannot find where this app is installed')
  ;<  shares=json  bind:m  (read-json (rf 1 / %'shares.json'))
  =/  all=(map @t json)  ?:(?=([%o *] shares) p.shares ~)
  =/  mine=(map @t json)  =/(j (~(get by all) id) ?:(?=([~ %o *] j) p.u.j ~))
  =.  mine  (~(put by mine) (scot %p u.shp) s+mode)
  ;<  ~  bind:m  (over:io (rf 1 / %'shares.json') [[/ %json] [%o (~(put by all) id [%o mine])]])
  ;<  ~  bind:m  (set-share-group u.base kind.u.pk slug.u.pk mine)
  ;<  told=?  bind:m
    %^  remote-poke-wait  u.shp  [%& orrery-instance %'shares.sig']
    %-  pairs:enjs:format
    :~  ['action' s+'offer']
        ['id' s+id]
        ['ship' `json`?~(ship.u.b ~ s+(scot %p u.ship.u.b))]
        ['name' s+name.u.b]
        ['mode' s+mode]
        ['base' s+(spat u.base)]
    ==
  (send-json eyre-id 200 (pairs:enjs:format ~[['ok' b+&] ['notified' b+told]]))
::  +serve-revoke: the ship leaves the record and the group, and is told
::
++  serve-revoke
  |=  [eyre-id=@ta kind=@ta slug=@ta ship=@ta]
  =/  m  (fiber:fiber:nexus ,~)
  ^-  form:m
  =/  id=bid:orr  (rap 3 kind '/' slug ~)
  =/  pk  (parse-bid:orr id)
  ?~  pk  (send-err eyre-id 400 'expected <kind>/<slug>')
  =/  shp=(unit @p)  (slaw %p ship)
  ?~  shp  (send-err eyre-id 400 'ship: expected an @p')
  ;<  base=(unit path)  bind:m  self-base
  ?~  base  (send-err eyre-id 500 'cannot find where this app is installed')
  ;<  shares=json  bind:m  (read-json (rf 1 / %'shares.json'))
  =/  all=(map @t json)  ?:(?=([%o *] shares) p.shares ~)
  =/  mine=(map @t json)  =/(j (~(get by all) id) ?:(?=([~ %o *] j) p.u.j ~))
  ?.  (~(has by mine) (scot %p u.shp))  (send-err eyre-id 404 'not shared with that ship')
  =.  mine  (~(del by mine) (scot %p u.shp))
  ;<  ~  bind:m
    (over:io (rf 1 / %'shares.json') [[/ %json] [%o ?:(=(~ mine) (~(del by all) id) (~(put by all) id [%o mine]))]])
  ;<  ~  bind:m  (set-share-group u.base kind.u.pk slug.u.pk mine)
  ;<  *  bind:m
    %^  remote-poke-wait  u.shp  [%& orrery-instance %'shares.sig']
    (pairs:enjs:format ~[['action' s+'revoke'] ['id' s+id]])
  (send-json eyre-id 200 (pairs:enjs:format ~[['ok' b+&]]))
::  +serve-shares: what we share, what was offered to us, what we accepted
::
++  serve-shares
  |=  eyre-id=@ta
  =/  m  (fiber:fiber:nexus ,~)
  ^-  form:m
  ;<  shares=json  bind:m  (read-json (rf 1 / %'shares.json'))
  ;<  offers=json  bind:m  (read-json (rf 1 / %'share-offers.json'))
  ;<  rows=json  bind:m  (read-json (rf 1 / %'ship-remotes.json'))
  (send-json eyre-id 200 (pairs:enjs:format ~[['shares' shares] ['offers' offers] ['accepted' rows]]))
::  +serve-accept: an offered body becomes ours to follow. The target is
::  person/me when the body's ship is us, else the body's own id, laid
::  through the writer if absent; the row is written and the follower
::  prodded.
::
++  serve-accept
  |=  [eyre-id=@ta jon=json]
  =/  m  (fiber:fiber:nexus ,~)
  ^-  form:m
  =/  host=(unit @p)  (slaw %p (gs:orr jon 'host'))
  ?~  host  (send-err eyre-id 400 'host: expected an @p')
  =/  id=@t  (gs:orr jon 'id')
  =/  key=@t  (share-key:orr u.host id)
  ;<  offers=json  bind:m  (read-json (rf 1 / %'share-offers.json'))
  =/  cur=(map @t json)  ?:(?=([%o *] offers) p.offers ~)
  =/  offer=(unit json)  (~(get by cur) key)
  ?~  offer  (send-err eyre-id 404 'no such offer')
  ;<  our=@p  bind:m  get-our:io
  =/  oship=(unit @p)  (slaw %p (gs:orr u.offer 'ship'))
  =/  target=bid:orr  (mirror-target:orr our oship id)
  ?~  (parse-bid:orr target)  (send-err eyre-id 400 'id: bad')
  =/  body-j=json
    ?:  =('person/me' target)  (pairs:enjs:format ~[['id' s+target]])
    %-  pairs:enjs:format
    :~  ['id' s+target]
        ['name' s+(gs:orr u.offer 'name')]
        ['ship' `json`?~(oship ~ s+(scot %p u.oship))]
    ==
  ;<  *  bind:m
    (poke-soft:io (rf 1 / %'main.sig') [[/ %json] (pairs:enjs:format ~[['op' s+'upsert-body'] ['body' body-j]])])
  =/  row=json
    %-  pairs:enjs:format
    :~  ['host' s+(scot %p u.host)]
        ['id' s+id]
        ['target' s+target]
        ['mode' s+(gs:orr u.offer 'mode')]
        ['base' s+(gs:orr u.offer 'base')]
        ['pushed' [%o ~]]
        ['last' s+'']
        ['error' s+'']
    ==
  ;<  rows=json  bind:m  (read-json (rf 1 / %'ship-remotes.json'))
  =/  rm=(map @t json)  ?:(?=([%o *] rows) p.rows ~)
  ;<  ~  bind:m  (over:io (rf 1 / %'ship-remotes.json') [[/ %json] [%o (~(put by rm) key row)]])
  ;<  ~  bind:m  (over:io (rf 1 / %'share-offers.json') [[/ %json] [%o (~(del by cur) key)]])
  ;<  *  bind:m  (poke-soft:io (rf 1 / %'sync.sig') [[/ %sig] ~])
  (send-json eyre-id 200 (pairs:enjs:format ~[['ok' b+&] ['target' s+target]]))
++  serve-decline
  |=  [eyre-id=@ta jon=json]
  =/  m  (fiber:fiber:nexus ,~)
  ^-  form:m
  =/  host=(unit @p)  (slaw %p (gs:orr jon 'host'))
  ?~  host  (send-err eyre-id 400 'host: expected an @p')
  =/  key=@t  (share-key:orr u.host (gs:orr jon 'id'))
  ;<  offers=json  bind:m  (read-json (rf 1 / %'share-offers.json'))
  =/  cur=(map @t json)  ?:(?=([%o *] offers) p.offers ~)
  ;<  ~  bind:m  (over:io (rf 1 / %'share-offers.json') [[/ %json] [%o (~(del by cur) key)]])
  (send-json eyre-id 200 (pairs:enjs:format ~[['ok' b+&]]))
++  serve-sync
  |=  eyre-id=@ta
  =/  m  (fiber:fiber:nexus ,~)
  ^-  form:m
  ;<  ~  bind:m  lay-inbox-road
  ;<  *  bind:m  (poke-soft:io (rf 1 / %'sync.sig') [[/ %sig] ~])
  (send-json eyre-id 200 (pairs:enjs:format ~[['ok' b+&]]))
```

- [ ] **Step 5: The routes**

In `+handle-request`, after the `s3` line add `=/  s4=@ta  ?:(?=([@ @ @ @ @ *] suffix) i.t.t.t.t.suffix %$)`, and before the 404 line add:

```hoon
  ?:  &(=('POST' meth) ?=([%api %share ~] suffix))          (serve-share eyre-id jon)
  ?:  &(=('DELETE' meth) ?=([%api %share @ @ @ ~] suffix))  (serve-revoke eyre-id s2 s3 s4)
  ?:  &(=('GET' meth) ?=([%api %shares ~] suffix))          (serve-shares eyre-id)
  ?:  &(=('POST' meth) ?=([%api %accept ~] suffix))         (serve-accept eyre-id jon)
  ?:  &(=('POST' meth) ?=([%api %decline ~] suffix))        (serve-decline eyre-id jon)
  ?:  &(=('POST' meth) ?=([%api %sync ~] suffix))           (serve-sync eyre-id)
```

- [ ] **Step 6: Deploy to both ships and re-approve the grown ask**

The fast loop on wex (`W`, `/tmp/wex.cookies`) and on feb (`F`, `/tmp/feb.cookies`): create each new marc file (`create-file` on `$D/code/mar`, and `$D/code/mar/usergroups` after a `create-folder` with `foldername=usergroups` on `$D/code/mar`), write every new or changed file, reload, bang `None` on both. Then approve the grown ask on both, since the shell replaces the weir with exactly what is granted:

```bash
GR='{"poke":["/sys/bowl.sig","/sys/eyre/","/sys/push/","/sys/gall/","/sys/behn/","/sys/ames/registry","/sys/ames/usergroups/"],"peek":["/sys/link/","/sys/ames/usergroups/","/sys/ames/ships/"],"make":["/sys/ames/usergroups/"]}'
for pair in "$W $CK" "$F $FK"; do set -- $pair
  curl -s -b $2 -X POST -H 'content-type: application/json' -d "{\"action\":\"approve-weir\",\"app\":\"$APP\",\"granted\":$GR}" $1/apps/grubbery/permits
  curl -s -b $2 -X POST -H 'content-type: application/json' -d "{\"app\":\"$APP\"}" $1/apps/grubbery/permits/reload
done
sleep 20
curl -s -b $CK "$W/grubbery/ball$APP?info=1" | python3 -c 'import sys,json; d=json.load(sys.stdin); print(d["bang"], d["weir"])'
# expected on both: None, and a weir listing the eleven roads
```

- [ ] **Step 7: Smoke the offer path by hand**

```bash
A=$W/apps/orrery/api; B=$F/apps/orrery/api; J='-H content-type:application/json'
curl -s -b $CK -X POST $J $A/bodies -d '{"id":"person/sarah","name":"Sarah","ship":"~feb"}'
curl -s -b $CK -X POST $J $A/share -d '{"id":"person/sarah","ship":"~feb","mode":"read"}'
#   {"ok":true,"notified":true}   (notified false means the ack did not come back in 30 s; check feb anyway)
curl -s -b $CK "$W/grubbery/ball/sys/ames/usergroups/orrery-person-sarah.grp?info=1"
#   the group exists, with who.ships and how.weir as children
sleep 5; curl -s -b $FK $B/shares | python3 -m json.tool
#   offers has the key "~wex/person/sarah" with host, id, ship "~feb", name "Sarah", mode "read", base "/apps/shell.shell/desks/orrery.desk/desk/data/orrery.orrery_app"
curl -s -b $FK -X POST $J $B/accept -d '{"host":"~wex","id":"person/sarah"}'
#   {"ok":true,"target":"person/me"}
curl -s -b $FK $B/shares | python3 -c 'import sys,json; d=json.load(sys.stdin); print(list(d["accepted"].keys()), d["offers"])'
#   ['~wex/person/sarah'] {}
curl -s -b $CK -X DELETE "$A/share/person/sarah/~feb"
#   {"ok":true}; then feb's accepted is {} within a few seconds, and the group's who.ships on wex is empty
curl -s -b $FK "$F/grubbery/ball$APP/tr/last?raw=1"
#   {"op":"revoke","ok":true,...,"by":"~wex"}
```

If `notified` is false and no offer reaches feb, read `/tr/last` on feb (the inbox notes every poke it refuses) and wex's console pane for a veto line. The two usual causes: a missing `/sys/gall/` grant on wex, or feb's inbox road not laid yet. `lay-inbox-road` runs on every `POST /api/sync` (and on every follower tick once Task 4 lands), so run `curl -s -b $FK -X POST $B/sync` on feb once before the share and confirm `GET $F/grubbery/ball/sys/ames/usergroups/public.grp/how.weir?info=1` answers (the group exists) before retrying.

- [ ] **Step 8: Commit and push**

```bash
git add code/nex/orrery/app.hoon code/mar
git commit -m "Sharing: the records, the grant, the inbox, and the share routes"
git push origin main
```

### Task 4: The follower: mirror what was shared with us, carry ours back

**Files:**
- Modify: `code/nex/orrery/app.hoon`

**Interfaces:**
- Consumes: Task 2's `carry-obs`, `is-local`, `mirror-target`; Task 3's `orrery-instance`, `lay-inbox-road`, `remote-poke-wait`, `peek-remote-wait`, `apply-carried`, `read-json`, `rows-in`, `body-dir`, `rf`, `rv`.
- Produces: the `sync.sig` process, `sync-pass`, `sync-rows`, `sync-one`, `mirror-pass`, `push-pass`. The row shape in `ship-remotes.json`: `{host, id, target, mode, base, pushed: {<our oid>: <retracted flag the host holds>}, last: <iso or "">, error: <text or "">}`.

- [ ] **Step 1: The process**

In `+on-file`, after the `[~ %'shares.sig']` case, add:

```hoon
          ::  the follower: every five minutes, and whenever prodded (an
          ::  accept, a sync request), pull every body another ship shared
          ::  with us and push our own observations back on the ones shared
          ::  in edit mode. A grant approved after the rise lands the inbox
          ::  road here too.
          [~ %'sync.sig']
        ;<  ~  bind:m  (rise-wait:io prod "%orrery sync: failed")
        |-
        ;<  ~  bind:m  lay-inbox-road
        ;<  ~  bind:m  sync-pass
        ;<  now=@da  bind:m  get-time:io
        ;<  ~  bind:m  (set-timer:io /tick (add now ~m5))
        ;<  *  bind:m  take-poke-from:io
        ;<  ~  bind:m  (cancel-timer:io /tick)
        $
```

The timer wake is itself a poke, so one `take-poke-from` waits for the tick or a prod, whichever comes first; the cancel after a wake is harmless.

- [ ] **Step 2: The pass**

Append before the closing `--`:

```hoon
::  ==  the follower: what other ships shared with us
::
::  +sync-pass: every accepted share: mirror the host's rows, push ours
::  back in edit mode, and record the pass on the row
::
++  sync-pass
  =/  m  (fiber:fiber:nexus ,~)
  ^-  form:m
  ;<  rows-j=json  bind:m  (read-json (rf 0 / %'ship-remotes.json'))
  =/  rows=(list [key=@t row=json])  ?:(?=([%o *] rows-j) ~(tap by p.rows-j) ~)
  (sync-rows rows ~)
::  +sync-rows: one row at a time; the file is re-read before the write
::  so an accept or a revoke that landed during the pass is kept
::
++  sync-rows
  |=  [rows=(list [key=@t row=json]) done=(map @t json)]
  =/  m  (fiber:fiber:nexus ,~)
  ^-  form:m
  ?~  rows
    ?:  =(~ done)  (pure:m ~)
    ;<  fresh=json  bind:m  (read-json (rf 0 / %'ship-remotes.json'))
    =/  cur=(map @t json)  ?:(?=([%o *] fresh) p.fresh ~)
    =/  merged=(map @t json)
      %+  roll  ~(tap by done)
      |=  [[key=@t row=json] acc=_cur]
      ?.((~(has by acc) key) acc (~(put by acc) key row))
    (over:io (rf 0 / %'ship-remotes.json') [[/ %json] [%o merged]])
  ;<  next=json  bind:m  (sync-one row.i.rows)
  (sync-rows t.rows (~(put by done) key.i.rows next))
::  +sync-one: one accepted share, answering the row with last, error
::  and pushed brought up to date
::
++  sync-one
  |=  row=json
  =/  m  (fiber:fiber:nexus ,json)
  ^-  form:m
  ?.  ?=([%o *] row)  (pure:m row)
  ;<  now=@da  bind:m  get-time:io
  =/  host=(unit @p)  (slaw %p (gs:orr row 'host'))
  ?~  host  (pure:m [%o (~(put by p.row) 'error' s+'host: expected an @p')])
  =/  id=bid:orr  (gs:orr row 'id')
  =/  target=bid:orr  (gs:orr row 'target')
  =/  base=path  (fall (mole |.((stab (gs:orr row 'base')))) orrery-instance)
  ;<  err=(unit @t)  bind:m  (mirror-pass u.host id target base)
  =/  pushed=(map @t json)  =/(p (gj:orr row 'pushed') ?:(?=([%o *] p) p.p ~))
  ;<  push=[ok=? pushed=(map @t json)]  bind:m
    (push-pass u.host id target base pushed =('edit' (gs:orr row 'mode')))
  =/  msg=@t
    ?:  ?=(^ err)  u.err
    ?.  ok.push  'the host did not take our observations (down, or the share is read only now)'
    ''
  %-  pure:m
  :-  %o
  %-  ~(gas by p.row)
  :~  ['last' (en-time:orr now)]
      ['error' s+msg]
      ['pushed' [%o pushed.push]]
  ==
::  +mirror-pass: the host's body directory, read whole; its own rows
::  (not ones it mirrored from elsewhere: one hop) land here as
::  observations from the host, through +apply-carried. ~ when fine,
::  else the error for the row.
::
++  mirror-pass
  |=  [host=@p id=bid:orr target=bid:orr base=path]
  =/  m  (fiber:fiber:nexus ,(unit @t))
  ^-  form:m
  =/  pk  (parse-bid:orr id)
  ?~  pk  (pure:m `'id: expected <kind>/<slug>')
  ;<  vw=(unit view:nexus)  bind:m
    (peek-remote-wait host [%& %| (weld base (body-dir kind.u.pk slug.u.pk))])
  ?~  vw  (pure:m `'the host did not answer (down, or the share was revoked)')
  ?.  ?=([%ball *] u.vw)  (pure:m `'the host no longer shares this body')
  =/  rows=(list row:orr)  (skim (rows-in ball.u.vw) |=(r=row:orr (is-local:orr obs.r)))
  ;<  *  bind:m  (apply-carried 0 host (turn rows |=(r=row:orr (carry-obs:orr target r))))
  (pure:m ~)
::  +push-pass: in edit mode, our own rows on the target body that the
::  host has not taken yet (or whose retraction it has not), sent to its
::  inbox. pushed maps our grub name to the retracted flag it holds.
::
++  push-pass
  |=  [host=@p id=bid:orr target=bid:orr base=path pushed=(map @t json) run=?]
  =/  m  (fiber:fiber:nexus ,[ok=? pushed=(map @t json)])
  ^-  form:m
  ?.  run  (pure:m [& pushed])
  =/  pk  (parse-bid:orr target)
  ?~  pk  (pure:m [& pushed])
  ;<  vw=view:nexus  bind:m  (peek:io (rv 0 (body-dir kind.u.pk slug.u.pk)) ~)
  ?.  ?=([%ball *] vw)  (pure:m [& pushed])
  =/  todo=(list row:orr)
    %+  skim  (rows-in ball.vw)
    |=  r=row:orr
    ?.  (is-local:orr obs.r)  |
    =/  was=(unit json)  (~(get by pushed) id.r)
    ?~  was  &
    !=(`json`b+retracted.obs.r u.was)
  ?~  todo  (pure:m [& pushed])
  =/  batch=(list row:orr)  (scag max-obs:orr `(list row:orr)`todo)
  ;<  ok=?  bind:m
    %^  remote-poke-wait  host  [%& base %'shares.sig']
    %-  pairs:enjs:format
    :~  ['action' s+'observe']
        ['id' s+id]
        ['observations' a+(turn batch |=(r=row:orr (carry-obs:orr id r)))]
    ==
  ?.  ok  (pure:m [| pushed])
  =/  next=(map @t json)
    (roll batch |=([r=row:orr acc=_pushed] (~(put by acc) id.r b+retracted.obs.r)))
  (pure:m [& next])
```

Two limits to keep, both by design: one hop (a row the host itself mirrored from a third ship is not carried on, so nothing is relabeled as the host's claim), and refs travel verbatim (a `{"ref"}` value names the host's body ids; one that collides with the receiver's subject is refused by the writer's self-reference guard and noted, nothing else is remapped).

- [ ] **Step 3: Deploy to both ships and watch one round trip**

Write `app.hoon` to wex and feb with the fast loop, reload both instances, bang `None` on both. Then, with the bodies and the share from Task 3 Step 7 in place (re-share if the smoke ended with a revoke):

```bash
A=$W/apps/orrery/api; B=$F/apps/orrery/api; J='-H content-type:application/json'
NOW=$(date -u -d '1 hour ago' +%Y-%m-%dT%H:%M:%SZ)
curl -s -b $CK -X POST $J $A/observe -d "{\"bodies\":[],\"observations\":[{\"subject\":\"person/sarah\",\"attr\":\"location\",\"value\":\"at the lake house\",\"at\":\"$NOW\",\"source\":{\"kind\":\"smoke\",\"id\":\"1\"}}]}"
curl -s -b $FK -X POST $B/sync; sleep 8
curl -s -b $FK $B/body/person/me | python3 -c 'import sys,json; print(json.load(sys.stdin)["attrs"].get("location"))'
#   {'value': 'at the lake house', ..., 'source': {'kind': 'ship', 'id': '~wex/<oid>'}, 'by': '~wex', 'obs': '<local oid>'}
curl -s -b $FK "$F/grubbery/ball$APP/ship-remotes.json?raw=1"
#   the row shows last set and error ""
```

If `error` reads "the host did not answer", the peek was vetoed: on wex, `GET $W/grubbery/ball/sys/ames/usergroups/orrery-person-sarah.grp/how.weir?info=1` must show the peek road on the body directory and `who.ships` must hold `~feb`; a missing `/sys/ames/ships/` peek grant on feb shows as a veto line in feb's console pane. Then share in edit mode, observe `mood` on feb's `person/me`, `POST $B/sync`, and read `mood` on wex's `person/sarah`: `by` is `~feb`, the source id starts `~feb/`.

- [ ] **Step 4: Commit and push**

```bash
git add code/nex/orrery/app.hoon
git commit -m "The follower: mirror what other ships shared, carry our rows back in edit mode"
git push origin main
```

### Task 5: The two-ship gate

**Files:**
- Create: `scripts/ship-share-matrix.py`

**Interfaces:**
- Consumes: the routes from Task 3, the follower from Task 4, phase 1's `POST /api/bodies`, `POST /api/observe`, `POST /api/retract`, `GET /api/body/<kind>/<slug>` (attribute rows carry `value`, `at`, `until`, `conf`, `source`, `by`, `obs`).

- [ ] **Step 1: Write the script**

```python
#!/usr/bin/env python3
"""ship-share-matrix.py HOST HJAR PEER PJAR
The sharing gate for orrery (spec section 11) against two fake ships:
HOST (~wex) shares person/sarah with PEER (~feb), whose person/me it is.
Read mode mirrors the host's observations and retractions; edit mode
carries the peer's back; revoke keeps the data; a re-share works.
HOST and PEER like http://localhost:8080; the jars from POST /~/login.
Exits 1 on any failure. Safe to rerun: it revokes, declines and retracts
what an earlier run left."""
import json, subprocess, sys, time
from datetime import datetime, timedelta, timezone

HOST, HJAR, PEER, PJAR = sys.argv[1:5]
HOSTNAME, PEERNAME = '~wex', '~feb'
fails = []
count = [0]


def curl(base, jar, method, path, body=None, timeout=60):
    cmd = ['curl', '-s', '-m', str(timeout), '-X', method, '-w', '\n%{http_code}',
           '-b', jar, base + '/apps/orrery/api' + path]
    if body is not None:
        cmd += ['-H', 'content-type: application/json', '-d', json.dumps(body)]
    out = subprocess.run(cmd, capture_output=True, text=True).stdout
    text, _, code = out.rpartition('\n')
    try:
        data = json.loads(text) if text else None
    except json.JSONDecodeError:
        data = text
    return int(code or 0), data


def host(method, path, body=None):
    return curl(HOST, HJAR, method, path, body)


def peer(method, path, body=None):
    return curl(PEER, PJAR, method, path, body)


def check(label, cond, detail=''):
    count[0] += 1
    print(('  ok   ' if cond else '  FAIL ') + label + ('' if cond else '   ' + str(detail)[:300]))
    if not cond:
        fails.append(label)


def wait(label, fn, secs):
    """poll fn every 2 s until it answers truthy; check the result"""
    deadline = time.time() + secs
    got = None
    while time.time() < deadline:
        got = fn()
        if got:
            break
        time.sleep(2)
    check(label, bool(got), 'timed out after %ds' % secs)
    return got


def dictish(x):
    return x if isinstance(x, dict) else {}


def iso(dt):
    return dt.replace(microsecond=0).strftime('%Y-%m-%dT%H:%M:%SZ')


def attr(side, bid, name):
    """the current row of one attribute, or None"""
    code, d = side('GET', '/body/' + bid)
    if code != 200:
        return None
    return dictish(dictish(d).get('attrs')).get(name)


def source_id(row):
    return str(dictish(dictish(row).get('source')).get('id'))


def observe(side, subject, name, value, at, sid):
    return side('POST', '/observe', {'bodies': [], 'observations': [
        {'subject': subject, 'attr': name, 'value': value, 'at': iso(at),
         'source': {'kind': 'matrix', 'id': sid}, 'by': 'ship-share-matrix'}]})


def retract(side, row):
    return side('POST', '/retract', {'id': dictish(row).get('obs', ''), 'note': 'gate'})


def shares(side):
    return dictish(side('GET', '/shares')[1])


def clean():
    host('DELETE', '/share/person/sarah/' + PEERNAME)
    for key in list(dictish(shares(peer).get('offers'))):
        h, _, i = key.partition('/')
        peer('POST', '/decline', {'host': h, 'id': i})
    for side, bid in ((host, 'person/sarah'), (peer, 'person/me')):
        for n in ('location', 'mood', 'plan'):
            row = attr(side, bid, n)
            if row:
                retract(side, row)


T0 = datetime.now(timezone.utc) - timedelta(hours=1)
KEY = HOSTNAME + '/person/sarah'
print('== setup')
clean()
code, d = peer('POST', '/bodies', {'id': 'person/me', 'ship': PEERNAME})
check('peer person/me carries its ship', code == 200, d)
code, d = host('POST', '/bodies', {'id': 'person/sarah', 'name': 'Sarah', 'ship': PEERNAME})
check('host person/sarah carries the peer ship', code == 200, d)
code, d = observe(host, 'person/sarah', 'location', 'at the lake house', T0, 'share-1')
check('host observes location', code == 200 and all(dictish(r).get('ok') for r in dictish(d).get('observations', [])) and len(dictish(d).get('observations', [])) == 1, d)

print('== share in read mode')
code, d = host('POST', '/share', {'id': 'person/sarah', 'ship': PEERNAME, 'mode': 'read'})
check('share answers ok', code == 200 and dictish(d).get('ok') is True, d)
offer = dictish(wait('the offer reaches the peer', lambda: dictish(shares(peer).get('offers')).get(KEY), 30))
check('the offer names the body, its ship and the mode', offer.get('ship') == PEERNAME and offer.get('name') == 'Sarah' and offer.get('mode') == 'read', offer)
code, d = peer('POST', '/accept', {'host': HOSTNAME, 'id': 'person/sarah'})
check('accept lands on person/me', code == 200 and dictish(d).get('target') == 'person/me', d)
s = shares(peer)
check('the offer is gone and the row is kept', KEY in dictish(s.get('accepted')) and KEY not in dictish(s.get('offers')), s)
row = dictish(wait('the location mirrors onto person/me', lambda: attr(peer, 'person/me', 'location'), 90))
check('the mirrored row is the host claim', row.get('by') == HOSTNAME and dictish(row.get('source')).get('kind') == 'ship' and source_id(row).startswith(HOSTNAME + '/') and row.get('value') == 'at the lake house', row)
hrow = dictish(attr(host, 'person/sarah', 'location'))
check('the source names the host grub', source_id(row) == HOSTNAME + '/' + str(hrow.get('obs')), (row, hrow))
srow = dictish(dictish(shares(peer).get('accepted')).get(KEY))
check('the row records the pass', srow.get('last') and srow.get('error') == '', srow)

print('== a retraction on the host follows')
code, d = retract(host, hrow)
check('host retracts', code == 200, d)
peer('POST', '/sync')
wait('the mirrored location goes', lambda: attr(peer, 'person/me', 'location') is None, 90)

print('== read mode carries nothing back')
code, d = observe(peer, 'person/me', 'mood', 'tired', T0, 'share-2')
check('peer observes mood', code == 200, d)
peer('POST', '/sync')
time.sleep(10)
check('the host does not see the peer mood in read mode', attr(host, 'person/sarah', 'mood') is None, attr(host, 'person/sarah', 'mood'))

print('== edit mode carries it back')
code, d = host('POST', '/share', {'id': 'person/sarah', 'ship': PEERNAME, 'mode': 'edit'})
check('re-share in edit mode answers ok', code == 200 and dictish(d).get('ok') is True, d)
wait('the peer row turns to edit', lambda: dictish(dictish(shares(peer).get('accepted')).get(KEY)).get('mode') == 'edit', 30)
check('no second offer', KEY not in dictish(shares(peer).get('offers')), shares(peer))
peer('POST', '/sync')
hrow = dictish(wait('the mood reaches the host', lambda: attr(host, 'person/sarah', 'mood'), 90))
check('the host row is the peer claim', hrow.get('by') == PEERNAME and dictish(hrow.get('source')).get('kind') == 'ship' and source_id(hrow).startswith(PEERNAME + '/') and hrow.get('value') == 'tired', hrow)
prow = dictish(attr(peer, 'person/me', 'mood'))
check('the host source names the peer grub', source_id(hrow) == PEERNAME + '/' + str(prow.get('obs')), (hrow, prow))
peer('POST', '/sync')
time.sleep(10)
check('nothing echoes back onto the peer', dictish(attr(peer, 'person/me', 'mood')).get('by') == 'ship-share-matrix', attr(peer, 'person/me', 'mood'))
code, d = retract(peer, prow)
check('peer retracts mood', code == 200, d)
peer('POST', '/sync')
wait('the retraction reaches the host', lambda: attr(host, 'person/sarah', 'mood') is None, 90)

print('== revoke keeps the data')
code, d = observe(host, 'person/sarah', 'plan', 'dinner at seven', T0, 'share-3')
check('host observes plan', code == 200, d)
peer('POST', '/sync')
wait('the plan mirrors', lambda: attr(peer, 'person/me', 'plan'), 90)
code, d = host('DELETE', '/share/person/sarah/' + PEERNAME)
check('revoke answers ok', code == 200, d)
wait('the peer row goes', lambda: KEY not in dictish(shares(peer).get('accepted')), 30)
check('the mirrored plan stays', dictish(attr(peer, 'person/me', 'plan')).get('value') == 'dinner at seven', attr(peer, 'person/me', 'plan'))
check('the host no longer lists the share', PEERNAME not in dictish(dictish(shares(host).get('shares')).get('person/sarah')), shares(host))

print('== a re-share works')
code, d = host('POST', '/share', {'id': 'person/sarah', 'ship': PEERNAME, 'mode': 'read'})
check('share again', code == 200, d)
wait('a fresh offer', lambda: dictish(shares(peer).get('offers')).get(KEY), 30)
code, d = peer('POST', '/accept', {'host': HOSTNAME, 'id': 'person/sarah'})
check('accept again', code == 200, d)

print('== refusals')
code, d = host('POST', '/share', {'id': 'nope', 'ship': PEERNAME})
check('share refuses a bad id', code == 400, d)
code, d = host('POST', '/share', {'id': 'person/sarah', 'ship': 'sarah'})
check('share refuses a bad ship', code == 400, d)
code, d = host('POST', '/share', {'id': 'person/sarah', 'ship': HOSTNAME})
check('share refuses this ship', code == 400, d)
code, d = host('POST', '/share', {'id': 'person/nobody', 'ship': PEERNAME})
check('share refuses an unknown body', code == 404, d)
code, d = host('DELETE', '/share/person/sarah/~zod')
check('revoke refuses a ship not shared with', code == 404, d)
code, d = peer('POST', '/accept', {'host': HOSTNAME, 'id': 'person/nobody'})
check('accept refuses an unknown offer', code == 404, d)
code, d = peer('POST', '/accept', {'host': 'nobody', 'id': 'person/sarah'})
check('accept refuses a bad host', code == 400, d)

print('== cleanup')
clean()
if fails:
    print('FAILED: ' + ', '.join(fails))
    sys.exit(1)
print('ALL OK (%d checks)' % count[0])
```

- [ ] **Step 2: Run it twice**

```bash
python3 scripts/ship-share-matrix.py $W $CK $F $FK
python3 scripts/ship-share-matrix.py $W $CK $F $FK
```

Expected: `ALL OK (38 checks)` both times. A `timed out` on the first mirror check means the follower did not run or the peek was vetoed: read `ship-remotes.json` on feb (`?raw=1`) for the row's `error`, then Task 4 Step 3's notes. A second run must pass too: it proves the cleanup and the re-share leave both ships usable.

- [ ] **Step 3: Rerun the phase 1 gate on wex**

```bash
python3 scripts/api-matrix.py $W $CK
```

Expected: `ALL OK`. Sharing added rows and routes, and the phase 1 behaviour must stand.

- [ ] **Step 4: Commit and push**

```bash
git add scripts/ship-share-matrix.py
git commit -m "The two-ship gate: share, mirror, retract, edit back, revoke, re-share"
git push origin main
```

### Task 6: Docs, hermeticity, version 4

**Files:**
- Create: `docs/sharing.md`
- Modify: `README.md`, `code/version.json`, `docs/superpowers/specs/2026-09-16-orrery-design.md` (section 11, only if the code deviated), `docs/releasing.md` (section 8 gains the two-ship gate)

- [ ] **Step 1: Hermeticity**

```bash
python3 scripts/code-closure.py code
```

Expected: nothing missing. If it names a marc, vendor it from `/home/sneagan/software/groundwire/grubbery/desk/gub/mar/` byte for byte and rerun.

- [ ] **Step 2: `docs/sharing.md`**

```markdown
# Sharing a body with another ship

A body and its observations can be shared with another ship: read mode mirrors what you know onto their ship, edit mode also carries what they observe back onto yours. The unit is one body. Nothing else on the ship is visible to them.

## How it works

- `POST /apps/orrery/api/share` with `{"id": "person/sarah", "ship": "~feb", "mode": "read"}` (or `"edit"`) records the share in `shares.json`, lets `~feb` read the body's directory (a usergroup named `orrery-person-sarah` with one peek grant), and pokes an offer into `~feb`'s inbox. The answer's `notified` says whether the offer was acknowledged within thirty seconds; a false is worth a look at the other ship, not a retry.
- On `~feb`, `GET /apps/orrery/api/shares` lists `offers`, `accepted` and `shares` (what this ship shares out). `POST /api/accept` with `{"host": "~wex", "id": "person/sarah"}` takes an offer. When the shared body's `ship` is `~feb` itself, it lands on `person/me`; otherwise on a body with the same id, created with the offered name and ship if absent. `POST /api/decline` drops an offer.
- The follower runs every five minutes, on every accept and on `POST /api/sync`. It reads each accepted body whole from the host and submits the host's own observations to the local writer with `by` set to the host and `source` `{"kind": "ship", "id": "~wex/<host observation id>"}`. A row the host retracts is retracted here. A row the host itself mirrored from a third ship is not carried on: one hop.
- In edit mode the follower also sends the local observations on that body (the ones not mirrored from a ship) to the host's inbox, where they land with `by` set to the sender and the same source shape. Retractions travel the same way. The host's inbox checks the share record before it applies anything; the sender is the transport's, never the payload's.
- `DELETE /apps/orrery/api/share/person/sarah/~feb` removes the ship from the record and the group and tells the other ship, which drops the accepted row. Mirrored observations stay on both sides, still naming their source.

## What to know

- The ask grows by poke on `/sys/gall/`, `/sys/behn/`, `/sys/ames/registry` and `/sys/ames/usergroups/`, peek on `/sys/ames/usergroups/` and `/sys/ames/ships/`, make on `/sys/ames/usergroups/`. Refuse them and everything else keeps working; sharing is off.
- `{"ref"}` values travel verbatim. They name bodies on the ship that observed them. One that names the receiving body itself is refused by the writer and noted in the audit log.
- The name, aliases and ship of a shared body are copied once, at accept. Later changes to them do not follow; observations do.
- Every accepted row carries `last` (the last pass) and `error` (empty, or why the host could not be read or would not take the edits).
- A ship that is down does not stall the follower: a peek or a poke gives up after thirty seconds and the row records it.
```

- [ ] **Step 3: README and the release doc**

In `README.md`, add `docs/sharing.md` to the docs line, add the six share routes to the API line, and name `scripts/ship-share-matrix.py` (two ships: `~wex` and `~feb`) beside the other gates. In `docs/releasing.md` section 8 (orrery's checklist), add the two-ship gate as a step after the phase 1 gate: `python3 scripts/ship-share-matrix.py http://localhost:8080 /tmp/wex.cookies http://localhost:8081 /tmp/feb.cookies` must print `ALL OK`.

- [ ] **Step 4: The spec, only where the code deviated**

Read section 11 of the spec against what landed: the row shape (`pushed` is an object), `POST /api/sync` laying the inbox road, one hop, refs verbatim, the mode update on an already accepted share. Where the spec says otherwise, change the spec sentence to match, one line per paragraph, no em-dashes. Do not add new promises.

- [ ] **Step 5: Version 4 through the forge, and feb follows**

```bash
python3 - <<'PY'
import json; p='code/version.json'; json.dump({'version': 4}, open(p,'w')); print(open(p).read())
PY
git add code/version.json docs README.md
git commit -m "Sharing with ships: docs, the two-ship gate in the checklist, version 4"
git push origin main
curl -s -b $CK -X POST -H 'content-type: application/json' -d '{"repo":"orrery","command":"pull"}' $W/grubbery/forge/api/run
sleep 30; curl -s -b $CK "$W/grubbery/ball/apps/shell.shell/desks/orrery.desk/desk/code/version.json?raw=1"
#   {"version": 4}
sleep 60; curl -s -b $FK "$F/grubbery/ball/apps/shell.shell/desks/orrery.desk/desk/code/version.json?raw=1"
#   {"version": 4}; feb polls wex, allow up to five minutes
for pair in "$W $CK" "$F $FK"; do set -- $pair; curl -s -b $2 "$1/grubbery/ball$APP?info=1" | python3 -c 'import sys,json; d=json.load(sys.stdin); print(d["bang"], len(d.get("weir",{}).get("poke",[])))'; done
#   None 7 on both. A shorter weir means the sync replaced the consent: re-approve with Task 3 Step 6's granted object on that ship.
python3 scripts/ship-share-matrix.py $W $CK $F $FK
#   ALL OK, on the synced code
```

- [ ] **Step 6: Commit anything the sync changed**

Nothing should be left; `git status` is clean. If the spec edits of Step 4 were made after the commit in Step 5, commit them: `git commit -am "Spec section 11 matches what landed"` and push.

---

## Self-review

**Spec coverage (section 11, as amended).** Shares record: Task 3 (`shares.json`, `POST /api/share`, `DELETE`). Usergroup per body with a peek grant: Task 3 (`set-share-group`). Offer to the public `shares.sig` inbox: Task 3 (`serve-share`, `take-offer`, `lay-inbox-road`). Accept and the @p mapping onto `person/me`: Task 2 (`mirror-target`) and Task 3 (`serve-accept`). Follower with the five-minute poll: Task 4. Edit mode pokes back with `by` from the transport: Task 2 (`carry-obs` carries no `by`), Task 3 (`take-edit`, `receive-obs`), Task 4 (`push-pass`). Revoke: Task 3 (`serve-revoke`, `take-revoke`). The ask growing by the five roads: Task 3 Step 2 and Step 6. Two ships in the loop: Task 1. Gate: Task 5. Docs and version: Task 6.

**Placeholders.** None: every step carries its code or its exact command. Step 4 of Task 6 asks the implementer to compare the spec with the code and edit sentences, which is judgment, not a placeholder.

**Type consistency.** `share-key` takes `[@p bid]` in Task 2 and is called `(share-key:orr src id)` and `(share-key:orr u.host id)` in Task 3. `carry-obs` takes `[bid row]` and is called with `(carry-obs:orr target r)` and `(carry-obs:orr id r)` in Task 4, and `(carry-obs:orr 'person/me' r)` in the test. `receive-obs` takes `[@p json]`. `apply-carried` takes `[@ud @p (list json)]` and is called `(apply-carried 0 host ...)` in Task 4 and `(apply-carried 0 src ...)` in Task 3. `remote-poke-wait` takes `[@p lane json]`, called with `[%& orrery-instance %'shares.sig']` in Task 3 and `[%& base %'shares.sig']` in Task 4; `peek-remote-wait` takes `[@p road]`. `push-pass` takes six arguments and `sync-one` passes six. The row shape written by `serve-accept` (`pushed` `[%o ~]`, `last`, `error`) is what `sync-one` reads and rewrites.

**Known limits, all recorded in `docs/sharing.md`.** One hop; refs verbatim; name and aliases copied once at accept; a refused edit still acknowledges (the row cannot tell a refusal from success until the mode changes on its side); the offer's `base` is trusted as the path to peek, but the peek goes only where the host's own grant allows.

