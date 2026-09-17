# Orrery Phase 3: Scoped Client Keys Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** A client that does not run a ship (Talon, a todo app, a Claude Code session) gets a token bound to an identity and a scope, and sees and writes exactly what that scope allows; the owner cookie keeps everything, and attributes the owner marks sensitive never leave the ship over a key.

**Architecture:** Keys are checked in-app, never by eyre, the way calendar checks CalDAV passwords: `clients.json` holds one row per key with a salted sha-256 of the secret, and every request without the owner cookie is identified from its `Authorization: Bearer <id>.<secret>` header before any route runs. The scope rides on the request as an actor (`owner`, `by`, `scope`) and each view or write arm applies it: bodies outside the scope's kinds are filtered or 404, observations and bodies outside them are refused whole, proposals outside the scope's action kinds are 403, `by` is forced to the key's identity, and the policy's `sensitive` attributes are dropped from every row a key can see. Minting and revoking are owner-only routes that go through the writer, so the file has one author.

**Tech Stack:** Hoon under zuse 408 (grubbery nexus, fibers, the import-free library), Python 3 for the gate, the `~wex` and `~feb` dev ships.

**Spec:** `docs/superpowers/specs/2026-09-16-orrery-design.md`, section 11 phase 3, section 6 (the surfaces it scopes), section 3 (`policy.json`).

## Global Constraints

- Prose rules for every doc, comment and commit message: no em-dashes, no hard-wrapped markdown, simple sentences. Hoon comments follow grubbery's style: `::  +arm: lowercase headline`, a bare `::` line below, plain ASCII, `::  ==  title` dividers.
- No AI attribution anywhere. Commits go to `nisfeb/orrery` as nisfeb, one at the end of every task with the message given; push where a step says push.
- Never touch `~ricsul-bilwyt`; never boot, kill or restart a pier; tmux window `0:3` is an ssh session to ricsul, never send keys there. Dojo discipline: one line, verify its echo, STOP after 2 minutes of waiting or 30 seconds without an echo.
- Never run two gates against the same ship at once.
- Every persistent path has a covering `%fall` row in `on-load`; long-lived fibers use nexus-relative roads (`rf`/`rv`, depth 0 at the root, 1 under `/requests`); the writer never crashes on input; the library stays import-free.
- The owner cookie keeps full access on every route. A key never sees a sensitive attribute, whatever its scope, on any view (state, body, timeline, resolve) and cannot write one. A key never learns that a body outside its kinds exists: an out-of-scope body answers exactly what a missing body answers. Every write a key makes carries the key's identity as `by`, whatever the payload said.
- The secret is shown once, at minting, and stored only as a salted hash. Tokens never go into the repo, a report, or a log.
- Hoon under zuse 408: colon form for wing-of-expression; `%=` and dot wings on legs, not arms; widen a `?~`-narrowed list before `levy`/`roll`/`turn`; bind computed tapes to a `=/  x=tape` face before interpolation.
- Caps: 50 clients; scope lists of at most 24 kinds each; name 1 to 200 bytes; `by` 1 to 64 bytes.

---

## Working with the ships

Everything from phase 1's "Working with `~wex`" section still applies (login, the fast loop, the tree browser, the dojo recipe for `-test`, the stop rules; see `docs/superpowers/plans/2026-09-16-orrery-phase-1.md`), and phase 2's "Working with two ships" (`~feb` at http://localhost:8081, jar `/tmp/feb.cookies`, dojo pane `0:0.0`; the library must be written to a ship's code tree too when it changes; see `docs/superpowers/plans/2026-09-16-orrery-phase-2.md`).

Development in this phase happens on `~wex` alone; `~feb` gets the code at the version bump in the last task, since keys are a single-ship feature. The two-ship gate is rerun at the end because the request path changed for every route.

A key is used with `curl -H 'Authorization: Bearer <token>'` and no cookie jar. The owner path is unchanged: the jar, no header.

---

## File Structure

| file | responsibility |
|---|---|
| `code/lib/orrery.hoon` | gains the pure key model: `scope`, `client`, their JSON codecs, the bearer parser, the secret and hash arms, the forcing fills, the sensitive filter, the batch scope check |
| `tests/lib/orrery.hoon` | gains their tests |
| `code/nex/orrery/app.hoon` | gains the `clients.json` row, the writer ops (`add-client`, `drop-client`, `touch-client`), `identify` and the actor, the client routes, and the scope applied in every view and write arm |
| `scripts/key-matrix.py` | the key gate: two keys with different scopes against `~wex`, plus the refusals |
| `docs/keys.md` | how keys work for a person, and the routes |

---

### Task 1: The library: scope, client, bearer, secret, hash, the sensitive filter

**Files:**
- Modify: `code/lib/orrery.hoon` (append before the closing `--`)
- Modify: `tests/lib/orrery.hoon` (append before the closing `--`)

**Interfaces:**
- Consumes: `ok-kind`, `parse-bid`, `gj`, `gs`, `ga`, `de-iso`, `en-iso`, `en-time`, `en-maybe-time`, `with-default`, `row`, `obs`, `max-name`, `max-by`.
- Produces: `scope`, `client`, `max-clients`, `max-scope-kinds`, `de-scope`, `de-kinds`, `en-scope`, `kind-in-scope`, `action-in-scope`, `de-client`, `en-client-row`, `en-client-view`, `secret-of`, `id-of`, `hash-token`, `parse-bearer`, `client-ok`, `sensitive-of`, `drop-attrs`, `force-string`, `fill-obs-as`, `fill-act-as`, `out-of-scope`.

- [ ] **Step 1: Append the failing tests**

```hoon
::
::  ==  scoped client keys
::
++  test-de-scope
  =/  full=json
    %-  pairs:enjs:format
    :~  ['kinds' a+~[s+'person' s+'thing']]
        ['actions' a+~[s+'task']]
        ['write' b+&]
    ==
  =/  got  (de-scope:orr full)
  =/  bad-kind  (de-scope:orr (pairs:enjs:format ~[['kinds' a+~[s+'Person']]]))
  =/  bad-write  (de-scope:orr (pairs:enjs:format ~[['write' s+'yes']]))
  =/  empty  (de-scope:orr [%o ~])
  ;:  weld
    (expect !>(?=(%& -.got)))
    (expect-eq !>((sy ~['person' 'thing'])) !>(?:(?=(%& -.got) kinds.p.got ~)))
    (expect-eq !>((sy ~['task'])) !>(?:(?=(%& -.got) actions.p.got ~)))
    (expect-eq !>(&) !>(?:(?=(%& -.got) write.p.got |)))
    (expect-eq !>([%| 'scope.kinds: each a kind name']) !>(bad-kind))
    (expect-eq !>([%| 'scope.write: expected true or false']) !>(bad-write))
    (expect !>(?=(%& -.empty)))
    (expect-eq !>(|) !>(?:(?=(%& -.empty) write.p.empty &)))
    (expect-eq !>([%| 'scope: expected an object']) !>((de-scope:orr s+'x')))
    (expect !>((kind-in-scope:orr [(sy ~[%person]) ~ |] %person)))
    (expect !>(!(kind-in-scope:orr [(sy ~[%person]) ~ |] %place)))
    (expect !>((action-in-scope:orr [~ (sy ~[%task]) &] %task)))
    (expect !>(!(action-in-scope:orr [~ (sy ~[%task]) &] %note)))
  ==
++  test-parse-bearer
  ;:  weld
    (expect-eq !>(`['abc' 'def']) !>((parse-bearer:orr 'Bearer abc.def')))
    (expect-eq !>(`['abc' 'de.f']) !>((parse-bearer:orr 'bearer abc.de.f')))
    (expect-eq !>(~) !>((parse-bearer:orr 'Basic abc.def')))
    (expect-eq !>(~) !>((parse-bearer:orr 'Bearer abcdef')))
    (expect-eq !>(~) !>((parse-bearer:orr 'Bearer abc.')))
    (expect-eq !>(~) !>((parse-bearer:orr 'Bearer .def')))
    (expect-eq !>(~) !>((parse-bearer:orr '')))
  ==
++  test-secret-and-hash
  =/  eny=@  (shax 'a fixed seed')
  =/  s=@t  (secret-of:orr eny)
  =/  i=@t  (id-of:orr eny)
  =/  n=@ud  (met 3 s)
  ;:  weld
    (expect !>(&((gte n 20) (lte n 24))))
    (expect !>(=(~ (find "." (trip s)))))
    (expect !>(=(~ (find "." (trip i)))))
    (expect !>(&((gte (met 3 i) 6) (lte (met 3 i) 8))))
    (expect-eq !>((hash-token:orr 'salt' s)) !>((hash-token:orr 'salt' s)))
    (expect !>(!=((hash-token:orr 'salt' s) (hash-token:orr 'pepper' s))))
    (expect !>(!=((hash-token:orr 'salt' s) (hash-token:orr 'salt' 'other'))))
  ==
++  test-client-roundtrip
  =/  sc=scope:orr  [(sy ~[%person]) (sy ~[%task]) &]
  =/  c=client:orr  ['abc' 'talon' 'talon' sc 'salt' (hash-token:orr 'salt' 'secret') t0 ~]
  =/  back=(unit client:orr)  (de-client:orr (en-client-row:orr c))
  =/  view=json  (en-client-view:orr c)
  ;:  weld
    (expect-eq !>(`c) !>(back))
    (expect !>((client-ok:orr c 'secret')))
    (expect !>(!(client-ok:orr c 'wrong')))
    (expect-eq !>(~) !>((gj:orr view 'hash')))
    (expect-eq !>(~) !>((gj:orr view 'salt')))
    (expect-eq !>(`json`s+'abc') !>((gj:orr view 'id')))
    (expect-eq !>(~) !>((de-client:orr s+'x')))
  ==
++  test-sensitive-and-drop
  =/  policy=json  (pairs:enjs:format ~[['sensitive' a+~[s+'health' s+'income']]])
  =/  hide=(set @t)  (sensitive-of:orr policy)
  =/  base=obs:orr  o1
  =/  r1=row:orr  ['1' base]
  =/  r2=row:orr  ['2' base(attr 'health')]
  =/  kept=(list row:orr)  (drop-attrs:orr ~[r1 r2] hide)
  ;:  weld
    (expect-eq !>((sy ~['health' 'income'])) !>(hide))
    (expect-eq !>(~) !>((sensitive-of:orr [%o ~])))
    (expect-eq !>(1) !>((lent kept)))
    (expect-eq !>('location') !>(?~(kept '' attr.obs.i.kept)))
    (expect-eq !>(2) !>((lent (drop-attrs:orr ~[r1 r2] ~))))
  ==
++  test-fill-as-forces-by
  =/  j=json  (pairs:enjs:format ~[['by' s+'liar'] ['subject' s+'person/me']])
  ;:  weld
    (expect-eq !>(`json`s+'talon') !>((gj:orr (fill-obs-as:orr j t0 'talon') 'by')))
    (expect-eq !>(`json`s+'talon') !>((gj:orr (fill-act-as:orr j t0 'talon') 'by')))
    (expect-eq !>(`json`s+(en-iso:orr t0)) !>((gj:orr (fill-obs-as:orr j t0 'talon') 'at')))
  ==
++  test-out-of-scope
  =/  sc=scope:orr  [(sy ~[%person]) ~ &]
  =/  hide=(set @t)  (sy ~['health'])
  =/  ok=json
    %-  pairs:enjs:format
    :~  ['bodies' a+~[(pairs:enjs:format ~[['id' s+'person/sam']])]]
        ['observations' a+~[(pairs:enjs:format ~[['subject' s+'person/me'] ['attr' s+'status']])]]
    ==
  =/  bad-body=json
    (pairs:enjs:format ~[['bodies' a+~[(pairs:enjs:format ~[['id' s+'place/home']])]]])
  =/  bad-subject=json
    (pairs:enjs:format ~[['observations' a+~[(pairs:enjs:format ~[['subject' s+'thing/car'] ['attr' s+'x']])]]])
  =/  bad-attr=json
    (pairs:enjs:format ~[['observations' a+~[(pairs:enjs:format ~[['subject' s+'person/me'] ['attr' s+'health']])]]])
  =/  unparsed=json
    (pairs:enjs:format ~[['observations' a+~[(pairs:enjs:format ~[['subject' s+'nope'] ['attr' s+'x']])]]])
  ;:  weld
    (expect-eq !>(~) !>((out-of-scope:orr ok sc hide)))
    (expect-eq !>(`'place/home') !>((out-of-scope:orr bad-body sc hide)))
    (expect-eq !>(`'thing/car') !>((out-of-scope:orr bad-subject sc hide)))
    (expect-eq !>(`'health') !>((out-of-scope:orr bad-attr sc hide)))
    (expect-eq !>(~) !>((out-of-scope:orr unparsed sc hide)))
  ==
```

- [ ] **Step 2: Run the tests and watch the new ones fail**

Copy both files to the wex mount, commit, run (phase 1's recipe). Expected: a build failure naming an unknown arm such as `de-scope`.

- [ ] **Step 3: Append the arms**

```hoon
::  ==  scoped client keys (spec section 11, phase 3)
::
::  a scope: the body kinds a key may read (and, with write, observe),
::  the action kinds it may propose, and whether it may write at all
::
+$  scope  [kinds=(set @tas) actions=(set @tas) write=?]
::  a client: one minted key. The secret is never stored, only a salted
::  sha-256 of it; used is the last use, at most hourly.
::
+$  client
  $:  id=@t
      name=@t
      by=@t
      =scope
      salt=@t
      hash=@t
      made=@da
      used=(unit @da)
  ==
++  max-clients      50
++  max-scope-kinds  24
::  +de-scope: {"kinds": [...], "actions": [...], "write": bool}. Absent
::  lists are empty, absent write is false. Every name must be a kind.
::
++  de-scope
  |=  j=json
  ^-  (each scope @t)
  ?.  ?=([%o *] j)  [%| 'scope: expected an object']
  =/  ks=(list json)  (ga j 'kinds')
  =/  as=(list json)  (ga j 'actions')
  ?:  (gth (lent ks) max-scope-kinds)  [%| 'scope.kinds: over 24']
  ?:  (gth (lent as) max-scope-kinds)  [%| 'scope.actions: over 24']
  =/  kinds=(unit (set @tas))  (de-kinds ks)
  ?~  kinds  [%| 'scope.kinds: each a kind name']
  =/  actions=(unit (set @tas))  (de-kinds as)
  ?~  actions  [%| 'scope.actions: each a kind name']
  =/  w=json  (gj j 'write')
  ?.  ?|(?=(~ w) ?=([%b *] w))  [%| 'scope.write: expected true or false']
  [%& u.kinds u.actions ?:(?=([%b *] w) p.w |)]
::  +de-kinds: kind names as a set, ~ when one is not a kind
::
++  de-kinds
  |=  ks=(list json)
  ^-  (unit (set @tas))
  =|  acc=(set @tas)
  |-
  ?~  ks  `acc
  ?.  ?=([%s *] i.ks)  ~
  ?.  (ok-kind p.i.ks)  ~
  $(ks t.ks, acc (~(put in acc) `@tas`p.i.ks))
++  en-scope
  |=  s=scope
  ^-  json
  %-  pairs:enjs:format
  :~  ['kinds' a+(turn ~(tap in kinds.s) |=(k=@tas `json`s+k))]
      ['actions' a+(turn ~(tap in actions.s) |=(k=@tas `json`s+k))]
      ['write' b+write.s]
  ==
++  kind-in-scope    |=([s=scope k=@tas] ^-(? (~(has in kinds.s) k)))
++  action-in-scope  |=([s=scope k=@tas] ^-(? (~(has in actions.s) k)))
::  +de-client, +en-client-row, +en-client-view: a stored row (with the
::  salt and the hash) and what the owner sees of it (without them)
::
++  de-client
  |=  j=json
  ^-  (unit client)
  ?.  ?=([%o *] j)  ~
  =/  sc  (de-scope (gj j 'scope'))
  ?.  ?=(%& -.sc)  ~
  =/  made=(unit @da)  (de-iso (gs j 'made'))
  ?~  made  ~
  ?:  =('' (gs j 'id'))  ~
  :-  ~
  :*  (gs j 'id')
      (gs j 'name')
      (gs j 'by')
      p.sc
      (gs j 'salt')
      (gs j 'hash')
      u.made
      (de-iso (gs j 'used'))
  ==
++  en-client-view
  |=  c=client
  ^-  json
  %-  pairs:enjs:format
  :~  ['id' s+id.c]
      ['name' s+name.c]
      ['by' s+by.c]
      ['scope' (en-scope scope.c)]
      ['made' (en-time made.c)]
      ['used' (en-maybe-time used.c)]
  ==
++  en-client-row
  |=  c=client
  ^-  json
  =/  view=json  (en-client-view c)
  ?.  ?=([%o *] view)  view
  [%o (~(gas by p.view) ~[['salt' s+salt.c] ['hash' s+hash.c]])]
::  +secret-of, +id-of: base-32 text from entropy, dots stripped. scot
::  drops leading zero digits, so a secret is 20 to 24 characters and an
::  id 6 to 8.
::
++  secret-of
  |=  eny=@
  ^-  @t
  =/  raw=tape  (trip (scot %uv (end [3 15] eny)))
  (crip (skip (slag 2 raw) |=(c=@t =('.' c))))
++  id-of
  |=  eny=@
  ^-  @t
  =/  raw=tape  (trip (scot %uv (end [3 5] eny)))
  =/  body=tape  (skip (slag 2 raw) |=(c=@t =('.' c)))
  ?:  (lth (lent body) 6)  (crip (weld "0k" body))
  (crip body)
::  +hash-token: a salted sha-256 as text
::
++  hash-token
  |=  [salt=@t secret=@t]
  ^-  @t
  (scot %ux (shax (rap 3 salt ':' secret ~)))
::  +parse-bearer: "Bearer <id>.<secret>" to the pair, or ~. The scheme
::  is case-insensitive; the id ends at the first dot.
::
++  parse-bearer
  |=  h=@t
  ^-  (unit [id=@t secret=@t])
  =/  t=tape  (trip h)
  ?.  (gte (lent t) 8)  ~
  ?.  =("bearer " (cass (scag 7 t)))  ~
  =/  tok=tape  (slag 7 t)
  =/  at=(unit @ud)  (find "." tok)
  ?~  at  ~
  =/  id=tape  (scag u.at tok)
  =/  secret=tape  (slag +(u.at) tok)
  ?:  |(=(0 (lent id)) =(0 (lent secret)))  ~
  `[(crip id) (crip secret)]
::  +client-ok: the presented secret against the stored salt and hash
::
++  client-ok
  |=  [c=client secret=@t]
  ^-  ?
  =(hash.c (hash-token salt.c secret))
::  +sensitive-of: policy.sensitive as a set of attribute names
::
++  sensitive-of
  |=  policy=json
  ^-  (set @t)
  (sy (murn (ga policy 'sensitive') |=(j=json ^-((unit @t) ?:(?=([%s *] j) `p.j ~)))))
::  +drop-attrs: the rows whose attribute is not hidden
::
++  drop-attrs
  |=  [rows=(list row) hide=(set @t)]
  ^-  (list row)
  ?:  =(~ hide)  rows
  (skip rows |=(r=row (~(has in hide) attr.obs.r)))
::  +force-string, +fill-obs-as, +fill-act-as: the key's identity
::  replaces whatever by the payload carried
::
++  force-string
  |=  [j=json k=@t v=json]
  ^-  json
  ?.  ?=([%o *] j)  j
  [%o (~(put by p.j) k v)]
++  fill-obs-as
  |=  [j=json now=@da by=@t]
  ^-  json
  (force-string (with-default j 'at' s+(en-iso now)) 'by' s+by)
++  fill-act-as
  |=  [j=json now=@da by=@t]
  ^-  json
  (force-string (with-default j 'proposed' s+(en-iso now)) 'by' s+by)
::  +out-of-scope: the first body id, subject or attribute in an observe
::  batch that a scope may not write, or ~. An id that does not parse is
::  left for the decoders to refuse.
::
++  out-of-scope
  |=  [jon=json s=scope hide=(set @t)]
  ^-  (unit @t)
  =/  bad-body=(unit @t)
    %+  roll  (ga jon 'bodies')
    |=  [j=json acc=(unit @t)]
    ?^  acc  acc
    =/  pk  (parse-bid (gs j 'id'))
    ?~  pk  ~
    ?:((kind-in-scope s kind.u.pk) ~ `(gs j 'id'))
  ?^  bad-body  bad-body
  %+  roll  (ga jon 'observations')
  |=  [j=json acc=(unit @t)]
  ?^  acc  acc
  =/  pk  (parse-bid (gs j 'subject'))
  ?~  pk  ~
  ?.  (kind-in-scope s kind.u.pk)  `(gs j 'subject')
  ?:  (~(has in hide) (gs j 'attr'))  `(gs j 'attr')
  ~
```

- [ ] **Step 4: Run the tests and watch them pass**

Copy both files, commit, run. Expected: 48 `OK` (41 plus these 7), no `FAILED`, no `CRASHED`, `ok=%.y`.

- [ ] **Step 5: Commit**

```bash
git add code/lib/orrery.hoon tests/lib/orrery.hoon
git commit -m "Key model: scope, client, bearer, secret and hash, the sensitive filter, with tests"
```

### Task 2: The nexus: the client rows, the writer ops, who is asking, the client routes

**Files:**
- Modify: `code/nex/orrery/app.hoon`

**Interfaces:**
- Consumes: Task 1's `client`, `scope`, `de-client`, `en-client-row`, `en-client-view`, `de-scope`, `en-scope`, `id-of`, `secret-of`, `hash-token`, `parse-bearer`, `client-ok`, `max-clients`; phase 1's `read-json`, `refuse`, `note`, `send-json`, `send-err`, `rf`; phase 2's `poke-writer`.
- Produces: the `clients.json` row; the writer ops `add-client`, `drop-client`, `touch-client`; `actor` and `identify`; `own` (the owner-only wrapper in `handle-request`); the routes `POST /api/clients`, `GET /api/clients`, `DELETE /api/clients/<id>`. After this task every existing route is owner-only; Task 3 opens the scoped ones to keys.

- [ ] **Step 1: The tree row**

In `+on-load`, after the `sync.sig` row, add:

```hoon
          ::  clients.json: the minted keys, each a salted hash of its
          ::  secret with a name, an identity and a scope (spec section 11,
          ::  phase 3)
          [%fall %& [/ %'clients.json'] [[/ %json] [%o ~]]]
```

- [ ] **Step 2: The writer ops**

In `+apply`, before the `(refuse op 'unknown op')` line, add:

```hoon
  ?:  =('add-client' op)  (do-add-client jon)
  ?:  =('drop-client' op)  (do-drop-client jon)
  ?:  =('touch-client' op)  (do-touch-client jon)
```

Append before the closing `--`:

```hoon
::  ==  the writer: keys
::
::  +do-add-client: one minted key, refused when the id is taken or the
::  table is full. The row arrives hashed; the writer never sees a
::  secret. Keys are not model state, so no beacon bump.
::
++  do-add-client
  |=  jon=json
  =/  m  (fiber:fiber:nexus ,?)
  ^-  form:m
  =/  c=(unit client:orr)  (de-client:orr (gj:orr jon 'client'))
  ?~  c  (refuse 'add-client' 'client: bad')
  ;<  clients=json  bind:m  (read-json (rf 0 / %'clients.json'))
  =/  cm=(map @t json)  ?:(?=([%o *] clients) p.clients ~)
  ?:  (~(has by cm) id.u.c)  (refuse 'add-client' 'id: taken')
  ?:  (gte ~(wyt by cm) max-clients:orr)  (refuse 'add-client' 'clients: over 50')
  ;<  ~  bind:m
    (over:io (rf 0 / %'clients.json') [[/ %json] [%o (~(put by cm) id.u.c (en-client-row:orr u.c))]])
  ;<  ~  bind:m  (note 'add-client' & name.u.c)
  (pure:m |)
::  +do-drop-client: a revoked key is gone; nothing else changes
::
++  do-drop-client
  |=  jon=json
  =/  m  (fiber:fiber:nexus ,?)
  ^-  form:m
  =/  id=@t  (gs:orr jon 'id')
  ;<  clients=json  bind:m  (read-json (rf 0 / %'clients.json'))
  =/  cm=(map @t json)  ?:(?=([%o *] clients) p.clients ~)
  ?.  (~(has by cm) id)  (refuse 'drop-client' 'no such client')
  ;<  ~  bind:m  (over:io (rf 0 / %'clients.json') [[/ %json] [%o (~(del by cm) id)]])
  ;<  ~  bind:m  (note 'drop-client' & id)
  (pure:m |)
::  +do-touch-client: last use, stamped by the writer's clock. No note:
::  one an hour per key would only fill the ring.
::
++  do-touch-client
  |=  jon=json
  =/  m  (fiber:fiber:nexus ,?)
  ^-  form:m
  =/  id=@t  (gs:orr jon 'id')
  ;<  clients=json  bind:m  (read-json (rf 0 / %'clients.json'))
  =/  cm=(map @t json)  ?:(?=([%o *] clients) p.clients ~)
  =/  row=json  (fall (~(get by cm) id) ~)
  ?.  ?=([%o *] row)  (pure:m |)
  ;<  now=@da  bind:m  get-time:io
  =/  next=json  [%o (~(put by p.row) 'used' (en-time:orr now))]
  ;<  ~  bind:m  (over:io (rf 0 / %'clients.json') [[/ %json] [%o (~(put by cm) id next)]])
  (pure:m |)
```

- [ ] **Step 3: Who is asking**

Append before the closing `--`:

```hoon
::  ==  who is asking
::
::  an actor: the owner (the cookie, writing as "http"), or a key with
::  its identity and its scope
::
+$  actor  [owner=? by=@t scope=(unit scope:orr)]
::  +identify: the owner cookie, else a valid bearer token, else ~. A
::  key's last use is stamped through the writer at most hourly.
::
++  identify
  |=  [req=inbound-request:eyre src=@p our=@p]
  =/  m  (fiber:fiber:nexus ,(unit actor))
  ^-  form:m
  ?:  &(authenticated.req =(src our))  (pure:m `[& 'http' ~])
  =/  au=(unit @t)  (get-header:http 'authorization' header-list.request.req)
  ?~  au  (pure:m ~)
  =/  tok=(unit [id=@t secret=@t])  (parse-bearer:orr u.au)
  ?~  tok  (pure:m ~)
  ;<  clients=json  bind:m  (read-json (rf 1 / %'clients.json'))
  =/  c=(unit client:orr)  (de-client:orr (gj:orr clients id.u.tok))
  ?~  c  (pure:m ~)
  ?.  (client-ok:orr u.c secret.u.tok)  (pure:m ~)
  ;<  now=@da  bind:m  get-time:io
  ;<  ~  bind:m
    ?:  &(?=(^ used.u.c) (lth now (add u.used.u.c ~h1)))  (pure:(fiber:fiber:nexus ,~) ~)
    (poke-writer 1 (pairs:enjs:format ~[['op' s+'touch-client'] ['id' s+id.u.c]]))
  (pure:m `[| by.u.c `scope.u.c])
```

In `+handle-request`, replace

```hoon
  ?.  &(authenticated.req =(src our))
    (send-err eyre-id 403 'forbidden')
```

with

```hoon
  ;<  who=(unit actor)  bind:m  (identify req src our)
  ?~  who  (send-err eyre-id 403 'forbidden')
  =/  act=actor  u.who
  ::  +own: a route the owner alone may take
  =/  own  |=(f=form:m ^-(form:m ?:(owner.act f (send-err eyre-id 403 'owner only'))))
```

and wrap every existing route's answer in `own`, so the table reads `(own (serve-state eyre-id args))`, `(own (serve-body eyre-id s2 s3 args))`, and so on for all twenty rows. Then add the three client routes before the 404 line:

```hoon
  ?:  &(=('POST' meth) ?=([%api %clients ~] suffix))        (own (serve-mint eyre-id jon))
  ?:  &(=('GET' meth) ?=([%api %clients ~] suffix))         (own (serve-clients eyre-id))
  ?:  &(=('DELETE' meth) ?=([%api %clients @ ~] suffix))    (own (serve-drop-client eyre-id s2))
```

- [ ] **Step 4: The client routes**

Append before the closing `--`:

```hoon
::  ==  keys: the client routes, owner only
::
::  +serve-mint: a new key. The secret is answered once and stored only
::  as a salted hash; the row goes through the writer. The id and the
::  cap are checked here too, so the answer is honest without a read
::  back.
::
++  serve-mint
  |=  [eyre-id=@ta jon=json]
  =/  m  (fiber:fiber:nexus ,~)
  ^-  form:m
  ?.  ?=([%o *] jon)  (send-err eyre-id 400 'a JSON object is required')
  =/  name=@t  (gs:orr jon 'name')
  ?:  |(=('' name) (gth (met 3 name) max-name:orr))  (send-err eyre-id 400 'name: 1 to 200 bytes')
  ::  who, not by: a leg named by would shadow the map door used below
  =/  who=@t  (gs:orr jon 'by')
  ?:  |(=('' who) (gth (met 3 who) max-by:orr))  (send-err eyre-id 400 'by: 1 to 64 bytes')
  =/  sc  (de-scope:orr (gj:orr jon 'scope'))
  ?:  ?=(%| -.sc)  (send-err eyre-id 400 p.sc)
  ;<  clients=json  bind:m  (read-json (rf 1 / %'clients.json'))
  =/  cm=(map @t json)  ?:(?=([%o *] clients) p.clients ~)
  ?:  (gte ~(wyt by cm) max-clients:orr)  (send-err eyre-id 409 'clients: over 50')
  ;<  eny=@uvJ  bind:m  get-entropy:io
  ;<  now=@da  bind:m  get-time:io
  =/  id=@t  (id-of:orr eny)
  ?:  (~(has by cm) id)  (send-err eyre-id 409 'id: taken, try again')
  =/  salt=@t  (scot %uv (end [3 10] (rsh [3 5] eny)))
  =/  secret=@t  (secret-of:orr (rsh [3 15] eny))
  =/  c=client:orr  [id name who p.sc salt (hash-token:orr salt secret) now ~]
  =/  op=json  (pairs:enjs:format ~[['op' s+'add-client'] ['client' (en-client-row:orr c)]])
  ;<  err=(unit tang)  bind:m  (poke-soft:io (rf 1 / %'main.sig') [[/ %json] op])
  ?^  err  (send-err eyre-id 500 'the writer refused the poke')
  %^  send-json  eyre-id  200
  %-  pairs:enjs:format
  :~  ['id' s+id]
      ['name' s+name]
      ['by' s+who]
      ['scope' (en-scope:orr p.sc)]
      ['token' s+(rap 3 id '.' secret ~)]
      ['made' (en-time:orr now)]
  ==
::  +serve-clients: the keys as the owner sees them: no salt, no hash
::
++  serve-clients
  |=  eyre-id=@ta
  =/  m  (fiber:fiber:nexus ,~)
  ^-  form:m
  ;<  clients=json  bind:m  (read-json (rf 1 / %'clients.json'))
  =/  cm=(map @t json)  ?:(?=([%o *] clients) p.clients ~)
  =/  rows=(list json)
    %+  murn  ~(tap by cm)
    |=  [id=@t j=json]
    ^-  (unit json)
    =/  c=(unit client:orr)  (de-client:orr j)
    ?~(c ~ `(en-client-view:orr u.c))
  (send-json eyre-id 200 a+rows)
++  serve-drop-client
  |=  [eyre-id=@ta id=@ta]
  =/  m  (fiber:fiber:nexus ,~)
  ^-  form:m
  ;<  clients=json  bind:m  (read-json (rf 1 / %'clients.json'))
  ?~  (gj:orr clients id)  (send-err eyre-id 404 'no such client')
  =/  op=json  (pairs:enjs:format ~[['op' s+'drop-client'] ['id' s+id]])
  ;<  err=(unit tang)  bind:m  (poke-soft:io (rf 1 / %'main.sig') [[/ %json] op])
  ?^  err  (send-err eyre-id 500 'the writer refused the poke')
  (send-json eyre-id 200 (pairs:enjs:format ~[['id' s+id] ['ok' b+&]]))
```

- [ ] **Step 5: Deploy to wex and smoke by hand**

Write `code/lib/orrery.hoon` and `code/nex/orrery/app.hoon` to wex with the fast loop, reload, `bang` `None`. Then:

```bash
A=$W/apps/orrery/api; J='-H content-type:application/json'
curl -s -b $CK -X POST $J $A/clients -d '{"name":"smoke","by":"smoke","scope":{"kinds":["person"],"actions":["task"],"write":true}}'
#   {"id":"<6 to 8 chars>","name":"smoke","by":"smoke","scope":{...},"token":"<id>.<20 to 24 chars>","made":"..."}
T=<the token>
curl -s -H "Authorization: Bearer $T" $A/state
#   {"error":"owner only"}   (every route is owner-only until Task 3)
curl -s -H "Authorization: Bearer ${T}x" $A/state
#   {"error":"forbidden"}
curl -s $A/state
#   {"error":"forbidden"}
curl -s -b $CK $A/clients
#   [{"id":..., "name":"smoke", ..., "used":"<a time>"}]   (the first use stamped it; no hash, no salt)
curl -s -b $CK -X DELETE $A/clients/<id>
#   {"id":"<id>","ok":true}
curl -s -H "Authorization: Bearer $T" $A/state
#   {"error":"forbidden"}
python3 scripts/api-matrix.py $W $CK
#   ALL OK   (the owner path is unchanged)
```

- [ ] **Step 6: Commit**

```bash
git add code/nex/orrery/app.hoon
git commit -m "Client keys: the rows, the writer ops, who is asking, the client routes"
```

### Task 3: The scope applied to every view and write

**Files:**
- Modify: `code/nex/orrery/app.hoon`

**Interfaces:**
- Consumes: Task 2's `actor`, `own`; Task 1's `kind-in-scope`, `action-in-scope`, `drop-attrs`, `sensitive-of`, `fill-obs-as`, `fill-act-as`, `out-of-scope`.
- Produces: `hidden-for`, `view-of`, `deny-observe`, `deny-write`; the scoped signatures `serve-state [eyre-id args act]`, `serve-body [eyre-id kind slug args act]`, `serve-resolve [eyre-id args act]`, `serve-observe [eyre-id jon act]`, `serve-bodies [eyre-id jon act]`, `serve-retract [eyre-id jon act]`, `serve-act [eyre-id jon act]`, `serve-actions [eyre-id args act]`, `serve-set-action [eyre-id id jon act]`.

- [ ] **Step 1: The helpers**

Append before the closing `--`:

```hoon
::  ==  the scope, applied
::
::  +hidden-for: the attributes an actor never sees: none for the
::  owner, policy.sensitive for a key
::
++  hidden-for
  |=  [act=actor policy=json]
  ^-  (set @t)
  ?:(owner.act ~ (sensitive-of:orr policy))
::  +view-of: what an actor may see: the bodies in its kinds with the
::  hidden attributes dropped, and the actions in its action kinds. The
::  owner sees everything.
::
++  view-of
  |=  [act=actor all=(list loaded) acts=(list [id=@ta a=action:orr]) hide=(set @t)]
  ^-  [all=(list loaded) acts=(list [id=@ta a=action:orr])]
  ?~  scope.act  [all acts]
  =/  s=scope:orr  u.scope.act
  :-  %+  murn  all
      |=  l=loaded
      ^-  (unit loaded)
      ?.  (kind-in-scope:orr s kind.body.l)  ~
      `l(rows (drop-attrs:orr rows.l hide))
  (skim acts |=([* a=action:orr] (action-in-scope:orr s kind.a)))
::  +deny-observe: why a key may not send this batch, or ~. The owner is
::  never denied. A batch with one item outside the scope is refused
::  whole, naming the first offender (which the key itself sent).
::
++  deny-observe
  |=  [act=actor jon=json policy=json]
  ^-  (unit @t)
  ?~  scope.act  ~
  ?.  write.u.scope.act  `'read only key'
  =/  bad=(unit @t)  (out-of-scope:orr jon u.scope.act (sensitive-of:orr policy))
  ?~  bad  ~
  `(cat 3 'not in scope: ' u.bad)
::  +deny-write: why a key may not write a body of this kind, or ~
::
++  deny-write
  |=  [act=actor kind=@tas]
  ^-  (unit @t)
  ?~  scope.act  ~
  ?.  write.u.scope.act  `'read only key'
  ?.  (kind-in-scope:orr u.scope.act kind)  `(cat 3 'not in scope: ' kind)
  ~
```

- [ ] **Step 2: The views**

`+serve-state` takes `act` and reads the policy; the bodies and actions it works from are the actor's view. Its head becomes:

```hoon
++  serve-state
  |=  [eyre-id=@ta args=quay:eyre act=actor]
  =/  m  (fiber:fiber:nexus ,~)
  ^-  form:m
  ;<  now=@da  bind:m  get-time:io
  =/  when=(unit @da)  (when-arg args now)
  ?~  when  (send-err eyre-id 400 'at: expected an ISO 8601 UTC time')
  =/  kind=@t  (fall (get-key:kv:html-utils 'kind' args) '')
  ;<  schema=json  bind:m  (read-json (rf 1 / %'schema.json'))
  ;<  policy=json  bind:m  (read-json (rf 1 / %'policy.json'))
  ;<  rev=json  bind:m  (read-json (rf 1 /beacon %rev))
  ;<  all0=(list loaded)  bind:m  (load-bodies 1)
  ;<  acts0=(list [id=@ta a=action:orr])  bind:m  (load-actions 1)
  =/  seen  (view-of act all0 acts0 (hidden-for act policy))
  =/  all=(list loaded)  all.seen
  =/  acts=(list [id=@ta a=action:orr])  acts.seen
```

and the rest of the arm is unchanged (it reads `all` and `acts`).

`+serve-body` takes `act`; a body outside the key's kinds is not in its view, so it answers exactly what a missing body answers. Its head becomes:

```hoon
++  serve-body
  |=  [eyre-id=@ta kind=@ta slug=@ta args=quay:eyre act=actor]
  =/  m  (fiber:fiber:nexus ,~)
  ^-  form:m
  ;<  now=@da  bind:m  get-time:io
  =/  when=(unit @da)  (when-arg args now)
  ?~  when  (send-err eyre-id 400 'at: expected an ISO 8601 UTC time')
  =/  id=bid:orr  (rap 3 kind '/' slug ~)
  ?~  (parse-bid:orr id)  (send-err eyre-id 400 'expected <kind>/<slug>')
  ;<  schema=json  bind:m  (read-json (rf 1 / %'schema.json'))
  ;<  policy=json  bind:m  (read-json (rf 1 / %'policy.json'))
  =/  multi=(set @t)  (multi-of:orr schema)
  ;<  all0=(list loaded)  bind:m  (load-bodies 1)
  ;<  acts0=(list [id=@ta a=action:orr])  bind:m  (load-actions 1)
  =/  seen  (view-of act all0 acts0 (hidden-for act policy))
  =/  all=(list loaded)  all.seen
  =/  acts=(list [id=@ta a=action:orr])  acts.seen
  =/  mine=(unit loaded)  (find-loaded all id)
  ?~  mine  (send-err eyre-id 404 'no such body')
```

Remove the later `;<  acts=(list [id=@ta a=action:orr])  bind:m  (load-actions 1)` line (the actions are loaded above now); the rest is unchanged.

`+serve-resolve` takes `act` and resolves over the actor's bodies:

```hoon
++  serve-resolve
  |=  [eyre-id=@ta args=quay:eyre act=actor]
  =/  m  (fiber:fiber:nexus ,~)
  ^-  form:m
  =/  q=@t  (fall (get-key:kv:html-utils 'q' args) '')
  ;<  all0=(list loaded)  bind:m  (load-bodies 1)
  =/  all=(list loaded)  all:(view-of act all0 ~ ~)
  =/  bodies=(list [id=bid:orr =body:orr])  (turn all |=(l=loaded [id.l body.l]))
```

and the rest unchanged.

`+serve-actions` takes `act` and lists the actor's action kinds:

```hoon
++  serve-actions
  |=  [eyre-id=@ta args=quay:eyre act=actor]
  =/  m  (fiber:fiber:nexus ,~)
  ^-  form:m
  =/  want=@t  (fall (get-key:kv:html-utils 'status' args) 'open')
  ;<  all0=(list [id=@ta a=action:orr])  bind:m  (load-actions 1)
  =/  all=(list [id=@ta a=action:orr])  acts:(view-of act ~ all0 ~)
```

and the rest unchanged.

- [ ] **Step 3: The writes**

`+serve-observe` takes `act`. After the two cap checks and before `now`, add the policy read and the denial; the stamp becomes the actor's:

```hoon
  ;<  policy=json  bind:m  (read-json (rf 1 / %'policy.json'))
  =/  denied=(unit @t)  (deny-observe act jon policy)
  ?^  denied  (send-err eyre-id 403 u.denied)
  ;<  now=@da  bind:m  get-time:io
  =/  stamp
    |=  j=json
    ^-  json
    ?:(owner.act (fill-obs:orr j now 'http') (fill-obs-as:orr j now by.act))
  =/  stamped=json
    %-  pairs:enjs:format
    :~  ['op' s+'observe']
        ['bodies' a+(ga:orr jon 'bodies')]
        ['observations' a+(turn (ga:orr jon 'observations') stamp)]
    ==
  =/  prep  (prep-observe:orr stamped now by.act)
```

(the signature line becomes `|=  [eyre-id=@ta jon=json act=actor]`; everything after `prep` is unchanged).

`+serve-bodies` takes `act`; after `pk` is parsed:

```hoon
  =/  denied=(unit @t)  (deny-write act kind.u.pk)
  ?^  denied  (send-err eyre-id 403 u.denied)
```

`+serve-retract` takes `act`; after `hit` is found, the observation must be in the actor's view (else it reads as missing) and the key must write:

```hoon
  ;<  policy=json  bind:m  (read-json (rf 1 / %'policy.json'))
  =/  visible=?
    ?~  scope.act  &
    ?&  (kind-in-scope:orr u.scope.act kind.u.hit)
        !(~(has in (sensitive-of:orr policy)) attr.obs.r.u.hit)
    ==
  ?.  visible  (send-err eyre-id 404 'no such observation')
  ?:  &(?=(^ scope.act) !write.u.scope.act)  (send-err eyre-id 403 'read only key')
```

`+serve-act` takes `act`. The stamp is the actor's, the action kind must be in scope, and an `about` outside the key's kinds reads as a missing body (no existence oracle):

```hoon
++  serve-act
  |=  [eyre-id=@ta jon=json act=actor]
  =/  m  (fiber:fiber:nexus ,~)
  ^-  form:m
  ;<  now=@da  bind:m  get-time:io
  =/  stamped=json  ?:(owner.act (fill-act:orr jon now 'http') (fill-act-as:orr jon now by.act))
  =/  got  (de-action:orr stamped now by.act)
  ?:  ?=(%| -.got)  (send-err eyre-id 400 p.got)
  ?:  &(?=(^ scope.act) !(action-in-scope:orr u.scope.act kind.p.got))
    (send-err eyre-id 403 (cat 3 'not in scope: ' kind.p.got))
  =/  outside=(unit bid:orr)
    ?~  scope.act  ~
    =/  s=scope:orr  u.scope.act
    %+  roll  ~(tap in about.p.got)
    |=  [b=bid:orr acc=(unit bid:orr)]
    ?^  acc  acc
    =/  pk  (parse-bid:orr b)
    ?~  pk  ~
    ?:((kind-in-scope:orr s kind.u.pk) ~ `b)
  ?^  outside  (send-err eyre-id 400 (cat 3 'about: no such body ' u.outside))
```

and from `;<  missing=(unit bid:orr)  bind:m  (first-missing 1 ...)` on, unchanged.

`+serve-set-action` takes `act`. After the action is read and before the transition check, it must be in the actor's view and the key must write; the op's `by` is the actor's:

```hoon
  ?:  &(?=(^ scope.act) !(action-in-scope:orr u.scope.act kind.u.a))
    (send-err eyre-id 404 'no such action')
  ?:  &(?=(^ scope.act) !write.u.scope.act)  (send-err eyre-id 403 'read only key')
```

and in the op, `['by' s+?:(owner.act (gs:orr jon 'by') by.act)]`.

- [ ] **Step 3b: Carried from the Task 3 review: refs and about stay in scope, a retraction names its actor**

Two constraints did not hold: an attribute value `{"ref": "place/home"}` named a body outside a key's kinds, and a key's retraction reached the audit ring with no `by`. Exact code:

In `code/lib/orrery.hoon`, after `drop-attrs`:

```hoon
::  +veil-refs: a row whose value points at a body of a kind outside
::  the given kinds keeps its place with a null value, so the fold
::  shows the attribute as cleared rather than falling back to an
::  older value the key may see, and the key never learns the body
::
++  veil-refs
  |=  [rows=(list row) kinds=(set @tas)]
  ^-  (list row)
  %+  turn  rows
  |=  r=row
  =/  target=(unit bid)  (ref-of value.obs.r)
  ?~  target  r
  =/  pk  (parse-bid u.target)
  ?~  pk  r
  ?:  (~(has in kinds) kind.u.pk)  r
  r(value.obs ~)
::  +scope-about: an action's about trimmed to the given kinds
::
++  scope-about
  |=  [a=action kinds=(set @tas)]
  ^-  action
  %=  a
    about  %-  ~(gas in *(set bid))
           %+  skim  ~(tap in about.a)
           |=  b=bid
           =/  pk  (parse-bid b)
           ?~(pk | (~(has in kinds) kind.u.pk))
  ==
```

In `tests/lib/orrery.hoon`, after `test-out-of-scope`:

```hoon
++  test-veil-refs-and-scope-about
  =/  base=obs:orr  o1
  =/  r-place=row:orr  ['1' base(value (pairs:enjs:format ~[['ref' s+'place/home']]))]
  =/  r-person=row:orr  ['2' base(value (pairs:enjs:format ~[['ref' s+'person/sarah']]))]
  =/  r-plain=row:orr  ['3' base]
  =/  kept=(list row:orr)  (veil-refs:orr ~[r-place r-person r-plain] (sy ~[%person]))
  =/  a=action:orr
    [%task 'Call the shop' ~ (sy ~['thing/subaru' 'person/sarah']) ~ 'mcp' t0 %proposed '' ~]
  =/  trimmed=action:orr  (scope-about:orr a (sy ~[%person]))
  ;:  weld
    (expect-eq !>(~['1' '2' '3']) !>((turn kept |=(r=row:orr id.r))))
    (expect-eq !>(`json`~) !>(?~(kept ~ value.obs.i.kept)))
    (expect-eq !>(`json`(pairs:enjs:format ~[['ref' s+'person/sarah']])) !>(value.obs:(snag 1 `(list row:orr)`kept)))
    (expect-eq !>(`json`(pairs:enjs:format ~[['ref' s+'place/home']])) !>(value.obs:(snag 0 (veil-refs:orr ~[r-place] (sy ~[%person %place])))))
    (expect-eq !>((sy ~['person/sarah'])) !>(about.trimmed))
    (expect-eq !>(~) !>(about:(scope-about:orr a ~)))
  ==
```

In `code/nex/orrery/app.hoon`, `+view-of` applies both: the body branch becomes `` `l(rows (veil-refs:orr (drop-attrs:orr rows.l hide) kinds.s)) `` and the actions branch becomes

```hoon
  %+  turn  (skim acts |=([* a=action:orr] (action-in-scope:orr s kind.a)))
  |=([id=@ta a=action:orr] [id (scope-about:orr a kinds.s)])
```

with the headline saying a ref outside the kinds reads as cleared and an about is trimmed. In `+serve-retract` the op gains `['by' s+by.act]`; in `+do-retract` the note becomes `(note-by 'retract' & why (gs:orr jon 'by'))` so the ring names the actor and carries the note; in `+retract-each` (phase 2, the follower's carried retractions) the op gains `['by' s+(scot %p src)]`. Above `serve-act`'s action-kind refusal add one comment line: `::  403 here: the key sent the kind itself; a stored id it may not see is a 404`.

- [ ] **Step 4: The route table**

In `+handle-request`, the scoped routes drop their `own` and pass `act`:

```hoon
  ?:  &(=('GET' meth) ?=([%api %state ~] suffix))        (serve-state eyre-id args act)
  ?:  &(=('GET' meth) ?=([%api %body @ @ ~] suffix))     (serve-body eyre-id s2 s3 args act)
  ?:  &(=('DELETE' meth) ?=([%api %body @ @ ~] suffix))  (own (serve-delete-body eyre-id s2 s3))
  ?:  &(=('GET' meth) ?=([%api %resolve ~] suffix))      (serve-resolve eyre-id args act)
  ?:  &(=('POST' meth) ?=([%api %observe ~] suffix))     (serve-observe eyre-id jon act)
  ?:  &(=('POST' meth) ?=([%api %retract ~] suffix))     (serve-retract eyre-id jon act)
  ?:  &(=('POST' meth) ?=([%api %bodies ~] suffix))      (serve-bodies eyre-id jon act)
  ?:  &(=('POST' meth) ?=([%api %act ~] suffix))         (serve-act eyre-id jon act)
  ?:  &(=('GET' meth) ?=([%api %actions ~] suffix))      (serve-actions eyre-id args act)
  ?:  &(=('POST' meth) ?=([%api %actions @ ~] suffix))   (serve-set-action eyre-id s2 jon act)
```

Everything else (delete body, schema, policy, share, revoke, shares, accept, decline, sync, clients) stays wrapped in `own`.

- [ ] **Step 5: Deploy to wex and smoke by hand**

Write `app.hoon` to wex, reload, `bang` `None`. Mint a triage key (`kinds` person, thing, place, situation; no actions; write) and a todo key (no kinds; `actions` task; write); as the owner, `PUT /api/policy` with the starter policy plus `"sensitive": ["health"]` and observe `person/me.health` and `person/me.status`. Then read `GET /api/state` and `GET /api/body/person/me` with the triage token: `status` present, `health` absent from `attrs` and from `observations`; with the todo token: `bodies` empty, `person/me` a 404. Observe `thing/subaru.status` with the triage token and read it as the owner: `by` is the key's identity. Propose a task with the todo token: approved, and it lists it with `by` the key's; propose a note with it: 403. `GET /api/clients` with either token: 403 `owner only`. Then `python3 scripts/api-matrix.py $W $CK`: `ALL OK`. Paste every read in the report; Task 4 automates them.

- [ ] **Step 6: Commit and push**

```bash
git add code/nex/orrery/app.hoon
git commit -m "Keys see and write their scope: bodies by kind, sensitive attributes hidden, actions by kind, by forced"
git push origin main
```

### Task 4: The key gate

**Files:**
- Create: `scripts/key-matrix.py`

**Interfaces:**
- Consumes: the routes of Tasks 2 and 3; phase 1's `POST /api/bodies`, `POST /api/observe`, `POST /api/retract`, `POST /api/act`, `GET /api/actions`, `POST /api/actions/<id>`, `PUT /api/policy`, `GET /api/body/<kind>/<slug>`, `GET /api/state`, `GET /api/resolve`.

- [ ] **Step 1: Write the script**

```python
#!/usr/bin/env python3
"""key-matrix.py HOST JAR
The key gate for orrery (spec section 11, phase 3) against a fake ship.
The owner (JAR, from POST /~/login) marks health sensitive, mints a
triage key, a todo key and a read-only key, and the keys then see and
write exactly their scope and nothing sensitive. Exits 1 on any
failure. Safe to rerun: it revokes what it minted, retracts what it
observed and restores the starter policy."""
import json, subprocess, sys, time
from datetime import datetime, timedelta, timezone

HOST, JAR = sys.argv[1:3]
API = HOST + '/apps/orrery/api'
STARTER = {'auto': ['task', 'note'], 'push': 'proposed', 'retention_days': 365}
fails = []
count = [0]


def curl(method, path, body=None, jar=None, token=None, timeout=60):
    cmd = ['curl', '-s', '-m', str(timeout), '-X', method, '-w', '\n%{http_code}', API + path]
    if jar:
        cmd += ['-b', jar]
    if token:
        cmd += ['-H', 'Authorization: Bearer ' + token]
    if body is not None:
        cmd += ['-H', 'content-type: application/json', '-d', json.dumps(body)]
    out = subprocess.run(cmd, capture_output=True, text=True).stdout
    text, _, code = out.rpartition('\n')
    try:
        data = json.loads(text) if text else None
    except json.JSONDecodeError:
        data = text
    return int(code or 0), data


def owner(method, path, body=None):
    return curl(method, path, body, jar=JAR)


def as_key(token):
    return lambda method, path, body=None: curl(method, path, body, token=token)


def check(label, cond, detail=''):
    count[0] += 1
    print(('  ok   ' if cond else '  FAIL ') + label + ('' if cond else '   ' + str(detail)[:300]))
    if not cond:
        fails.append(label)


def dictish(x):
    return x if isinstance(x, dict) else {}


def listish(x):
    return x if isinstance(x, list) else []


def iso(dt):
    return dt.replace(microsecond=0).strftime('%Y-%m-%dT%H:%M:%SZ')


def obs(subject, attr, value, at, sid):
    """every payload lies about by, so a forced by is visible"""
    return {'subject': subject, 'attr': attr, 'value': value, 'at': iso(at),
            'source': {'kind': 'matrix', 'id': sid}, 'by': 'liar'}


def attrs_of(side, bid):
    """(code, the attrs map) with the map None when the read failed"""
    code, d = side('GET', '/body/' + bid)
    return code, (dictish(dictish(d).get('attrs')) if code == 200 else None)


def state_ids(side):
    code, d = side('GET', '/state')
    if code != 200:
        return None
    return {b.get('id'): b for b in listish(dictish(d).get('bodies')) if isinstance(b, dict)}


def all_ok(d, key, n):
    items = listish(dictish(d).get(key))
    return len(items) == n and all(dictish(r).get('ok') is True for r in items)


def retract_all(bid, names):
    code, a = attrs_of(owner, bid)
    for n in names:
        row = dictish(dictish(a).get(n))
        if row.get('obs'):
            owner('POST', '/retract', {'id': row['obs'], 'note': 'key gate'})


def clean():
    code, d = owner('GET', '/clients')
    for c in listish(d):
        if isinstance(c, dict) and str(c.get('name', '')).startswith('key-gate '):
            owner('DELETE', '/clients/' + str(c.get('id')))
    retract_all('person/me', ('health', 'status', 'mood', 'spouse', 'home'))
    retract_all('thing/subaru', ('status',))
    owner('PUT', '/policy', STARTER)
    for a in listish(owner('GET', '/actions?status=open')[1]):
        if isinstance(a, dict) and str(a.get('title', '')).startswith('key gate'):
            owner('POST', '/actions/' + str(a.get('id')), {'status': 'dismissed', 'note': 'key gate'})
    owner('DELETE', '/body/place/lake-house')


T0 = datetime.now(timezone.utc) - timedelta(hours=1)
print('== setup')
clean()
code, d = owner('POST', '/bodies', {'id': 'thing/subaru', 'name': 'the Subaru'})
check('owner reaches thing/subaru', code == 200, d)
code, d = owner('PUT', '/policy', dict(STARTER, sensitive=['health']))
check('policy marks health sensitive', code == 200, d)
code, d = owner('POST', '/observe', {'bodies': [], 'observations': [
    obs('person/me', 'health', 'flu', T0, 'kg-1'), obs('person/me', 'status', 'working from bed', T0, 'kg-2')]})
check('owner observes health and status', code == 200 and all_ok(d, 'observations', 2), d)

print('== minting')
code, d = owner('POST', '/clients', {'name': 'key-gate triage', 'by': 'talon',
                                     'scope': {'kinds': ['person', 'thing', 'place', 'situation'], 'actions': [], 'write': True}})
check('mint the triage key', code == 200 and '.' in str(dictish(d).get('token', '')), d)
triage_id, triage_tok = dictish(d).get('id'), str(dictish(d).get('token', ''))
triage = as_key(triage_tok)
code, d = owner('POST', '/clients', {'name': 'key-gate todo', 'by': 'todo-app',
                                     'scope': {'kinds': [], 'actions': ['task'], 'write': True}})
check('mint the todo key', code == 200 and '.' in str(dictish(d).get('token', '')), d)
todo_id, todo_tok = dictish(d).get('id'), str(dictish(d).get('token', ''))
todo = as_key(todo_tok)
code, d = owner('POST', '/clients', {'name': 'key-gate reader', 'by': 'reader',
                                     'scope': {'kinds': ['person'], 'actions': [], 'write': False}})
check('mint the read-only key', code == 200 and '.' in str(dictish(d).get('token', '')), d)
reader_id, reader_tok = dictish(d).get('id'), str(dictish(d).get('token', ''))
reader = as_key(reader_tok)
code, d = owner('GET', '/clients')
rows = {c.get('id'): c for c in listish(d) if isinstance(c, dict)}
check('the owner lists the keys without secrets', code == 200 and triage_id in rows
      and not any(k in rows[triage_id] for k in ('hash', 'salt', 'token')), d)
check('a fresh key has no last use', triage_id in rows and rows[triage_id].get('used') is None, rows.get(triage_id))
code, d = owner('POST', '/clients', {'name': 'key-gate bad', 'by': 'x', 'scope': {'kinds': ['Nope']}})
check('a bad scope is 400', code == 400, d)
code, d = owner('POST', '/clients', {'name': '', 'by': 'x', 'scope': {}})
check('a missing name is 400', code == 400, d)

print('== the triage key sees its kinds and never the sensitive attribute')
ids = state_ids(triage)
check('the triage key reads the state', ids is not None and 'person/me' in ids, ids)
me = dictish(dictish(ids).get('person/me'))
check('the state hides health and shows status', 'health' not in dictish(me.get('attrs'))
      and dictish(dictish(me.get('attrs')).get('status')).get('value') == 'working from bed', me)
code, a = attrs_of(triage, 'person/me')
check('the body view hides health', code == 200 and a is not None and 'health' not in a and 'status' in a, a)
code, d = triage('GET', '/body/person/me')
tl = [o.get('attr') for o in listish(dictish(d).get('observations')) if isinstance(o, dict)]
check('the timeline hides health', code == 200 and 'health' not in tl and 'status' in tl, tl)
code, a = attrs_of(owner, 'person/me')
check('the owner still sees health', code == 200 and a is not None and 'health' in a, a)
code, d = triage('GET', '/resolve?q=subaru')
check('resolve answers a body in scope', code == 200 and any(dictish(r).get('id') == 'thing/subaru' for r in listish(d)), d)
ids = state_ids(todo)
check('the todo key sees no bodies', ids is not None and ids == {}, ids)
code, d = todo('GET', '/body/person/me')
check('a body outside the scope is 404 for the todo key', code == 404, d)
code, d = todo('GET', '/resolve?q=subaru')
check('resolve answers nothing to the todo key', code == 200 and d == [], d)

print('== writes carry the key identity and stay in scope')
code, d = triage('POST', '/observe', {'bodies': [], 'observations': [obs('thing/subaru', 'status', 'in the shop', T0, 'kg-3')]})
check('the triage key observes in scope', code == 200 and all_ok(d, 'observations', 1), d)
code, a = attrs_of(owner, 'thing/subaru')
check('by is the key identity, not the payload', dictish(dictish(a).get('status')).get('by') == 'talon', a)
code, d = triage('POST', '/observe', {'bodies': [], 'observations': [obs('person/me', 'health', 'better', T0, 'kg-4')]})
check('a sensitive attribute is 403 for a key', code == 403, d)
code, d = triage('POST', '/observe', {'bodies': [{'id': 'org/acme', 'name': 'Acme'}], 'observations': []})
check('a body outside the kinds is 403', code == 403, d)
code, d = triage('POST', '/observe', {'bodies': [], 'observations': [obs('org/acme', 'status', 'x', T0, 'kg-5')]})
check('a subject outside the kinds is 403', code == 403, d)
code, d = triage('POST', '/bodies', {'id': 'place/lake-house', 'name': 'the lake house'})
check('the triage key creates a body in scope', code == 200, d)
code, d = triage('POST', '/bodies', {'id': 'org/acme', 'name': 'Acme'})
check('a body outside the kinds is 403 on bodies too', code == 403, d)
code, d = reader('POST', '/observe', {'bodies': [], 'observations': [obs('person/me', 'mood', 'fine', T0, 'kg-6')]})
check('a read-only key cannot observe', code == 403, d)
code, a = attrs_of(reader, 'person/me')
check('the read-only key still reads its kinds', code == 200 and a is not None and 'status' in a and 'health' not in a, a)
code, d = owner('POST', '/observe', {'bodies': [], 'observations': [
    obs('person/me', 'spouse', {'ref': 'person/sarah'}, T0, 'kg-8'), obs('person/me', 'home', {'ref': 'place/home'}, T0, 'kg-9')]})
check('owner observes two refs', code == 200 and all_ok(d, 'observations', 2), d)
code, a = attrs_of(reader, 'person/me')
check('a ref inside the kinds shows and one outside does not', code == 200 and a is not None and 'spouse' in a and 'home' not in a, a)
code, d = reader('GET', '/body/person/me')
tl = [o.get('attr') for o in listish(dictish(d).get('observations')) if isinstance(o, dict)]
home_rows = [o for o in listish(dictish(d).get('observations')) if isinstance(o, dict) and o.get('attr') == 'home']
check('the timeline veils the outside ref as a cleared value', code == 200 and 'spouse' in tl and home_rows and all(o.get('value') is None for o in home_rows), home_rows)
code, d = triage('POST', '/observe', {'bodies': [], 'observations': [obs('person/me', 'mood', 'fine', T0, 'kg-7')]})
check('the triage key observes mood', code == 200 and all_ok(d, 'observations', 1), d)
code, a = attrs_of(owner, 'person/me')
mood_obs = str(dictish(dictish(a).get('mood')).get('obs', ''))
health_obs = str(dictish(dictish(a).get('health')).get('obs', ''))
check('the owner sees both rows to retract', bool(mood_obs) and bool(health_obs), a)
code, d = reader('POST', '/retract', {'id': mood_obs, 'note': 'key gate'})
check('a read-only key cannot retract', code == 403, d)
code, d = todo('POST', '/retract', {'id': mood_obs, 'note': 'key gate'})
check('a retract outside the kinds reads as no such observation', code == 404, d)
code, d = triage('POST', '/retract', {'id': health_obs, 'note': 'key gate'})
check('a sensitive observation reads as no such observation', code == 404, d)
code, d = triage('POST', '/retract', {'id': mood_obs, 'note': 'key gate'})
check('the triage key retracts its own observation', code == 200, d)

print('== actions by kind')
code, d = todo('POST', '/act', {'kind': 'task', 'title': 'key gate: call the shop', 'about': ['thing/subaru']})
check('an about outside the kinds reads as no such body', code == 400, d)
code, d = todo('POST', '/act', {'kind': 'task', 'title': 'key gate: call the shop', 'by': 'liar'})
check('the todo key proposes a task', code == 200 and dictish(d).get('status') == 'approved', d)
task_id = str(dictish(d).get('id', ''))
code, d = todo('GET', '/actions')
mine = [x for x in listish(d) if isinstance(x, dict) and x.get('id') == task_id]
check('the todo key lists its task with its identity as by', len(mine) == 1 and mine[0].get('by') == 'todo-app', mine)
code, d = todo('POST', '/act', {'kind': 'note', 'title': 'key gate: a note'})
check('an action kind outside the scope is 403', code == 403, d)
code, d = triage('POST', '/act', {'kind': 'task', 'title': 'key gate: another task'})
check('a key with no action kinds cannot propose', code == 403, d)
code, d = triage('GET', '/actions')
check('a key with no action kinds lists none', code == 200 and d == [], d)
code, d = owner('POST', '/clients', {'name': 'key-gate watcher', 'by': 'watcher',
                                     'scope': {'kinds': [], 'actions': ['task'], 'write': False}})
check('mint a read-only key that may see tasks', code == 200 and '.' in str(dictish(d).get('token', '')), d)
watcher = as_key(str(dictish(d).get('token', '')))
code, d = watcher('GET', '/actions')
check('the read-only key lists the task', code == 200 and any(isinstance(x, dict) and x.get('id') == task_id for x in listish(d)), d)
code, d = watcher('POST', '/actions/' + task_id, {'status': 'done'})
check('a read-only key cannot transition', code == 403, d)
code, d = todo('POST', '/actions/' + task_id, {'status': 'done', 'by': 'liar'})
check('the todo key completes its task', code == 200, d)
code, d = owner('GET', '/actions?status=done')
done = [x for x in listish(d) if isinstance(x, dict) and x.get('id') == task_id]
hist = listish(dictish(done[0] if done else {}).get('history'))
check('the transition carries the key identity', any(dictish(h).get('by') == 'todo-app' and dictish(h).get('status') == 'done' for h in hist), hist)
code, d = owner('POST', '/act', {'kind': 'note', 'title': 'key gate: owner note'})
note_id = str(dictish(d).get('id', ''))
code, d = todo('POST', '/actions/' + note_id, {'status': 'dismissed'})
check('an action outside the kinds reads as no such action', code == 404, d)
code, d = owner('POST', '/act', {'kind': 'task', 'title': 'key gate: owner task about the car', 'about': ['thing/subaru']})
about_id = str(dictish(d).get('id', ''))
code, d = todo('GET', '/actions')
about_rows = [x for x in listish(d) if isinstance(x, dict) and x.get('id') == about_id]
check('an about outside the kinds is trimmed from what the todo key lists', len(about_rows) == 1 and about_rows[0].get('about') == [], about_rows)
check('the todo key does not list an action of another kind', len(about_rows) == 1 and not any(isinstance(x, dict) and x.get('id') == note_id for x in listish(d)), d)
code, d = owner('GET', '/actions')
owner_rows = [x for x in listish(d) if isinstance(x, dict) and x.get('id') == about_id]
check('the owner still sees the about', len(owner_rows) == 1 and owner_rows[0].get('about') == ['thing/subaru'], owner_rows)

print('== owner only')
for label, fn in (('clients', lambda: triage('GET', '/clients')),
                  ('policy', lambda: triage('GET', '/policy')),
                  ('schema', lambda: triage('GET', '/schema')),
                  ('shares', lambda: triage('GET', '/shares')),
                  ('delete body', lambda: triage('DELETE', '/body/place/lake-house')),
                  ('share', lambda: triage('POST', '/share', {'id': 'person/me', 'ship': '~feb'}))):
    code, d = fn()
    check('a key may not reach ' + label, code == 403 and dictish(d).get('error') == 'owner only', (code, d))

print('== last use, revocation, bad tokens')
code, d = owner('GET', '/clients')
rows = {c.get('id'): c for c in listish(d) if isinstance(c, dict)}
check('a used key records its last use', code == 200 and isinstance(rows.get(triage_id, {}).get('used'), str)
      and rows[triage_id]['used'] != '', rows.get(triage_id))
code, d = curl('GET', '/state', token=triage_tok + 'x')
check('a wrong secret is 403', code == 403, d)
code, d = curl('GET', '/state', token='nope.' + triage_tok.split('.', 1)[1])
check('a wrong id is 403', code == 403, d)
code, d = curl('GET', '/state')
check('no credentials is 403', code == 403, d)
code, d = owner('DELETE', '/clients/' + str(todo_id))
check('the owner revokes the todo key', code == 200, d)
time.sleep(1)
code, d = todo('GET', '/state')
check('a revoked key is 403', code == 403, d)
code, d = owner('DELETE', '/clients/' + str(todo_id))
check('revoking twice is 404', code == 404, d)

print('== cleanup')
clean()
if fails:
    print('FAILED: ' + ', '.join(fails))
    sys.exit(1)
print('ALL OK (%d checks)' % count[0])
```

- [ ] **Step 2: Run it twice, then the other gates**

```bash
python3 scripts/key-matrix.py $W $CK
python3 scripts/key-matrix.py $W $CK
python3 scripts/api-matrix.py $W $CK
python3 scripts/ship-share-matrix.py $W $CK $F $FK
```

Expected: `ALL OK` with the check count printed, both times; then the phase 1 gate `ALL OK`; then the two-ship gate `ALL OK (68 checks)` (feb still runs version 4; the host side of every route is what changed, and the two-ship gate only uses the owner cookie). A failure in the key gate whose cause is the nexus code is reported, not patched around: the controller rules.

- [ ] **Step 3: Commit and push**

```bash
git add scripts/key-matrix.py
git commit -m "The key gate: scope, sensitive attributes, forced identity, revocation"
git push origin main
```

### Task 5: Docs, the spec, version 5

**Files:**
- Create: `docs/keys.md`
- Modify: `README.md`, `docs/releasing.md` (section 8), `docs/superpowers/specs/2026-09-16-orrery-design.md` (section 11 phase 3, only where the code deviated), `code/version.json`

- [ ] **Step 1: `docs/keys.md`**

```markdown
# Keys for clients that do not run a ship

A key is a token for one client: a name, the identity it writes as, and a scope. The owner mints it and sees the secret once. Requests carry it as `Authorization: Bearer <token>` with no cookie.

## Minting and revoking

- `POST /apps/orrery/api/clients` with `{"name": "Talon on the phone", "by": "talon", "scope": {"kinds": ["person", "thing", "place", "situation"], "actions": [], "write": true}}` answers the row and the `token` once. Store it in the client; the ship keeps only a salted hash.
- `GET /apps/orrery/api/clients` lists the keys with their scope, when they were made and last used (to the hour), never the secret.
- `DELETE /apps/orrery/api/clients/<id>` revokes one. The next request with it is refused.

## What a scope means

- `kinds`: the body kinds the key may see. The state, body and resolve views omit every other body, and a body outside them answers exactly what a missing body answers. With `write`, the key may observe those bodies and create them.
- `actions`: the action kinds the key may propose and list. With `write`, it may also approve, dismiss and complete them.
- `write`: false makes the key read-only: it cannot observe, create bodies, retract or transition an action. Proposing needs only the action kind, so a read-only key with `actions` can still file a proposal for the owner to approve.
- `by` on everything a key writes is the key's identity, whatever the payload said, so the audit trail names the client.
- A batch with one item outside the scope is refused whole, with the first offending id or attribute named.

## Sensitive attributes

`policy.json` may carry `"sensitive": ["health", "income"]`. A key never receives those attributes on any view, cannot observe them, and cannot retract them, whatever its scope. The owner cookie sees everything.

## What to know

- The owner cookie is never scoped. Keys are checked in the app, not by eyre, the way calendar checks CalDAV passwords.
- A key learns nothing about bodies outside its kinds: not their names, not that they exist, not through an action's `about` (trimmed to the key's kinds), not through an attribute whose value points at one (the key reads that attribute as cleared, never as an older value; a veiled row looks exactly like one the owner cleared). Only a top-level `{"ref"}` value is veiled; a body id written inside free-form JSON is not.
- Last use is recorded at most once an hour per key.
- At most 50 keys; scope lists of at most 24 kinds each.
```

- [ ] **Step 2: README and the release doc**

In `README.md`, add `docs/keys.md` to the docs line, add the three client routes to the API line and say the API is owner cookie or a minted key, and name `scripts/key-matrix.py` beside the other gates. In `docs/releasing.md` section 8, add the key gate as a step after the phase 1 gate: `python3 scripts/key-matrix.py http://localhost:8080 /tmp/wex.cookies` must print `ALL OK`.

- [ ] **Step 3: The spec, only where the code deviated**

Read section 11 phase 3 against what landed: the token is `<id>.<secret>`; a batch with one item outside the scope is refused whole with 403 naming the first offender; a body, observation or action outside the scope answers exactly what a missing one answers (404, or 400 `about: no such body` for an action's `about`); `write` false is a read-only key; last use is stamped at most hourly; the owner-only routes are the client routes, delete body, schema, policy and everything under sharing. Where the spec says otherwise, change the sentence to match, one line per paragraph, no em-dashes. Do not add new promises.

- [ ] **Step 4: Version 5 through the forge, and feb follows**

```bash
python3 - <<'PY'
import json; p='code/version.json'; json.dump({'version': 5}, open(p,'w')); print(open(p).read())
PY
git add code/version.json docs README.md
git commit -m "Scoped client keys: docs, the key gate in the checklist, version 5"
git push origin main
curl -s -b $CK -X POST -H 'content-type: application/json' -d '{"repo":"orrery.git_repo","command":"pull"}' $W/grubbery/forge/api/run
#   {"ok": true} within seconds
sleep 30; curl -s -b $CK "$W/grubbery/ball/apps/shell.shell/desks/orrery.desk/desk/code/version.json?raw=1"
#   {"version": 5}
sleep 60; curl -s -b $FK "$F/grubbery/ball/apps/shell.shell/desks/orrery.desk/desk/code/version.json?raw=1"
#   {"version": 5}; feb polls wex, allow up to five minutes
for pair in "$W $CK" "$F $FK"; do set -- $pair; curl -s -b $2 "$1/grubbery/ball$APP?info=1" | python3 -c 'import sys,json; d=json.load(sys.stdin); w=d.get("weir") or {}; print(d["bang"], [(k, len(v)) for k, v in w.items()])'; done
#   None [('poke', 6), ('read', 3), ('write', 1)] on both. A shorter weir means the sync replaced the consent: re-approve with phase 2's granted object on that ship.
python3 scripts/key-matrix.py $W $CK
python3 scripts/api-matrix.py $W $CK
python3 scripts/ship-share-matrix.py $W $CK $F $FK
#   ALL OK, ALL OK, ALL OK (68 checks), on the synced code
```

- [ ] **Step 5: Commit anything the spec edits left**

`git status` should be clean. If the spec edits of Step 3 were made after the commit in Step 4, commit them: `git commit -am "Spec phase 3 matches what landed"` and push.

### Final review fixes (after the whole-branch review)

Four findings from the whole-branch review landed as one fix round; the plan records them so it mirrors the code.

- A key may only relate what it can see: `out-of-scope` also checks a `{"ref"}` value's kind (refused as `not in scope: <ref>`), so a writing key can neither write refs to bodies outside its kinds nor probe `existing` for a veiled target.
- A veiled row commits to nothing: `veil-refs` gives it a synthetic id `veiled-<n>` from a per-list counter beside the null value, so the real id (a hash over the hidden value) never reaches a key and a retract of the synthetic id finds no grub.
- A key gets the schema trimmed to its scope: `scope-schema` keeps its kinds only, drops hidden attribute names from every `attrs` list and from `multi`, and trims an `actions` list to its action kinds; `serve-state` passes it for a key.
- Identity is the owner's to assign: a key never sends `ship`, refused as `not in scope: ship` in an observe batch's `bodies` and on `POST /bodies`.

The key gate gains seven checks for these (a mixed batch refused whole with the in-scope row unwritten, a read-only key with action kinds proposing, the ref-kind refusal and the `existing` probe refused, a veiled row that cannot be retracted, the trimmed schema, `involved` empty for a key that cannot see the situation, `ship` refused), `serve-retract` uses `hidden-for`, and `docs/keys.md` and spec section 6 say what the code does.

---

## Self-review

**Spec coverage (section 11 phase 3).** `clients.json` rows with name, id, salted hash, identity, scope, made and last used: Task 1 (`client`, the codecs) and Task 2 (the writer ops, `touch-client`). Mint with the token shown once, and revoke: Task 2 (`serve-mint`, `serve-drop-client`). The scope's `kinds`, `actions`, `write`: Task 1 (`scope`, `de-scope`) and Task 3 (`view-of`, `deny-observe`, `deny-write`, the action checks). Bearer requests: Task 2 (`identify`, `parse-bearer`). Views omit bodies outside `kinds`, a body outside them is a 404, an observation on one is a 403, a proposal outside `actions` is a 403, `by` forced: Task 3. `policy.json` `sensitive`: Task 1 (`sensitive-of`, `drop-attrs`) and Task 3 (`hidden-for`, the observe and retract checks). The owner cookie keeps full access; keys checked in-app: Task 2 (`identify` short-circuits on the cookie; `own`). Gate: Task 4. Docs and version: Task 5.

**Placeholders.** None: every step carries its code or its exact command. Task 5 Step 3 asks for judgment against the code, which is not a placeholder.

**Type consistency.** `actor` is `[owner=? by=@t scope=(unit scope:orr)]` in Task 2 and read as `owner.act`, `by.act`, `scope.act` in Task 3. `view-of` takes `[actor (list loaded) (list [id=@ta a=action:orr]) (set @t)]` and answers `[all acts]`; `serve-resolve` calls it with `~ ~` for the actions and the hidden set, `serve-actions` with `~` for the bodies. `deny-observe` answers `(unit @t)`; `deny-write` answers `(unit @t)`; both callers send 403. `out-of-scope` takes `[json scope (set @t)]` in Task 1 and is called so in `deny-observe`. `identify` takes `[req src our]` and `handle-request` binds `req` and `src` from `get-state-as` and `our` from `get-our`, as before. The gate's expectations match the arms: 403 `owner only` from `own`, 403 `forbidden` from the identify miss, 404 `no such body` and `no such observation` and `no such action` from the view filters, 400 `about: no such body` from `serve-act`.

**Known limits, all in `docs/keys.md` or the ledger.** Last use is hourly, through the writer, so a burst of requests in the first hour shows one stamp. A batch is refused whole rather than item by item. Timing side channels on the hash compare are not addressed (a local ship, one owner). The `sensitive` list applies to attribute names across every kind.


