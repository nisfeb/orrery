# Orrery Phase 4: MCP Tools and the Page Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** An analyst on the ship's MCP server (Claude Code today, Talon later) reads and writes orrery through eight tools that give the same views and take the same writes as the HTTP API, and the owner sees the model in a browser page that reloads on the beacon.

**Architecture:** The view assembly that the HTTP arms do after their reads (attributes, involved, actions, timeline, the state envelope) moves into the pure library, so the HTTP API, the MCP tools and the page share one encoder. The tools are `tool:tools` cores under `code/lib/tools`, each reading the instance by absolute peek and writing through the one poke road to the writer, with a small shared core `code/lib/orrery-mcp.hoon` for the walkers and the per-item answers; they are callable today by absolute path through the mcp nexus, and by name once the kernel's discovery walks the shell's desks, which this phase confirms and rehearses on `~wex` with a patch left for the dist branch. The page is three static grubs (html, css, js) served by the nexus to the owner, a reader with buttons over the same API, refreshed by the raw beacon stream the way lattice's page is.

**Tech Stack:** Hoon under zuse 408 (grubbery nexus, fibers, the import-free library, the kernel's `tools.hoon` vendored), plain JavaScript and CSS for the page (no framework, no build), Python 3 for the gates, node 26 for the page's render tests, the `~wex` and `~feb` dev ships.

**Spec:** `docs/superpowers/specs/2026-09-16-orrery-design.md`, section 6 (MCP tools, where the analyst runs, the page), section 8 (the scenario the MCP gate replays), section 5 (the beacon).

## Global Constraints

- Prose rules for every doc, comment and commit message: no em-dashes, no hard-wrapped markdown, simple sentences. Hoon comments follow grubbery's style: `::  +arm: lowercase headline`, a bare `::` line below, plain ASCII, `::  ==  title` dividers. JavaScript and CSS comments are plain ASCII too.
- No AI attribution anywhere. Commits go to `nisfeb/orrery` as nisfeb, one at the end of every task with the message given; push where a step says push. The grubbery kernel repo is never committed to by this plan: the kernel patch is a file in this repo and a rehearsal on the dev ship.
- Never touch `~ricsul-bilwyt`; never boot, kill or restart a pier; tmux window `0:3` is an ssh session to ricsul, never send keys there. Dojo discipline: one line, verify its echo, STOP after 2 minutes of waiting or 30 seconds without an echo. Only orrery's two library files ever go into the wex clay mount.
- Never run two gates against the same ship at once.
- Every persistent path has a covering `%fall` row in `on-load` (the page files are `%over` rows, laid fresh on every load); the writer never crashes on input; the library stays import-free; `code/lib/orrery-mcp.hoon` and the tools may import `/lib/orrery.hoon` and `/lib/tools.hoon` and nothing else; `scripts/code-closure.py code` stays clean, so `tools.hoon` is vendored byte for byte from the kernel.
- The tools act as the owner: no key scope, no sensitive filter (spec section 6, "what the analyst can see"). Every write a tool makes carries `by` from its `by` parameter, default `mcp`. The tools answer exactly the JSON the HTTP routes answer for the same request, so a client can switch transports without relearning shapes.
- The page is owner-only (it needs the owner cookie for the API anyway) and served with `cache-control: no-cache`, no inline secrets, no external resources.
- The HTTP API's answers do not change in this phase: the phase 1 gate, the two-ship gate and the key gate must stay green after the encoder move.
- Hoon under zuse 408: colon form for wing-of-expression; `%=` and dot wings on legs, not arms; widen a `?~`-narrowed list before `levy`/`roll`/`turn`/`scag`; bind computed tapes to a `=/  x=tape` face before interpolation; no `$` with arguments inside a `;<` continuation; a leg named `by` shadows the map door (name it `who`).

---

## Working with the ships and the MCP server

Everything from the earlier plans applies (phase 1's "Working with `~wex`", phase 2's two ships and the library deploy rule, phase 3's owner and key requests). Two new surfaces:

**The MCP server on `~wex`** answers JSON-RPC at `http://localhost:8080/grubbery/mcp` to the owner cookie (`src` equal to `our`; no OAuth for a curl with the jar). A tool call by absolute path, which works before any kernel change:

```bash
W=http://localhost:8080; CK=/tmp/wex.cookies; MCP=$W/grubbery/mcp
T=/apps/shell.shell/desks/orrery.desk/desk/code/lib/tools
curl -s -b $CK -X POST -H 'content-type: application/json' $MCP -d "{\"jsonrpc\":\"2.0\",\"id\":1,\"method\":\"tools/call\",\"params\":{\"name\":\"$T/orrery-state\",\"arguments\":{}}}"
#   {"jsonrpc":"2.0","id":1,"result":{"content":[{"type":"text","text":"{...the state view as a JSON string...}"}]}}
#   or {"jsonrpc":"2.0","id":1,"error":{"code":...,"message":"..."}} when the tool answered %error
curl -s -b $CK -X POST -H 'content-type: application/json' $MCP -d '{"jsonrpc":"2.0","id":2,"method":"tools/list","params":{}}' | python3 -c 'import sys,json; d=json.load(sys.stdin); print([t["name"] for t in d["result"]["tools"]][:40])'
#   the registry the kernel discovers; orrery's tools are absent until Task 3's patch is rehearsed
```

The tool runs on the mcp instance's `/tools` child nexus under that nexus's weir, which on `~wex` holds peek, poke and make on the whole ball. A tool that crashes prints `%mcp tool crashed` on the wex console pane (`tmux capture-pane -p -t 0:2.0`) and answers an error.

**The page** is at `http://localhost:8080/apps/orrery` with the owner cookie in a browser; a curl with the jar fetches the HTML, the JS and the CSS. The render logic runs under node for the tests (`node scripts/page-test.js`).

**Deploying tools.** A tool file is created in the desk code tree like any other file (`create-folder` `tools` under `$D/code/lib`, then `create-file` and `write-text` per tool); the mcp nexus compiles it on each call, so no reload is needed for a tool change. The library and the nexus still need the reload after a write.

---

## File Structure

| file | responsibility |
|---|---|
| `code/lib/orrery.hoon` | gains `loaded`, `en-attr-row`, `en-attrs`, `situations`, `body-json`, `state-json`: the view assembly the HTTP arms did inline, now shared |
| `code/nex/orrery/app.hoon` | `serve-state` and `serve-body` become reads plus one library call; gains the page rows and the static routes |
| `code/lib/tools.hoon` | the kernel's tool types, vendored byte for byte |
| `code/lib/orrery-mcp.hoon` | what the tools share: the instance base, argument readers, absolute peeks, the walkers, per-item answers, the writer poke |
| `code/lib/tools/orrery-state.hoon` and seven siblings | the eight tools |
| `code/nex/orrery/orrery.html`, `orrery.css`, `orrery.js` | the page, laid as mime grubs and served no-cache |
| `scripts/mcp-matrix.py` | the MCP gate: the scenario through the eight tools by absolute path |
| `scripts/page-smoke.py`, `scripts/page-test.js` | the page served right, and its render functions against fixtures |
| `docs/kernel/mcp-desk-tools.patch` | the kernel discovery patch for the dist branch, with its rehearsal recipe |
| `docs/mcp.md` | how to call the tools, by path today and by name after the patch |

---

### Task 1: One encoder for every surface

**Files:**
- Modify: `code/lib/orrery.hoon` (append before the closing `--`)
- Modify: `tests/lib/orrery.hoon` (append before the closing `--`)
- Modify: `code/nex/orrery/app.hoon` (`+$  loaded`, `en-attr-row`, `en-attrs` leave; `serve-state` and `serve-body` call the library)

**Interfaces:**
- Consumes: `fold`, `timeline`, `involved`, `is-closed`, `is-open`, `en-body`, `en-obs`, `en-action`, `en-time`, `row`, `body`, `action`, `bid`.
- Produces: `loaded [id=bid =body rows=(list row)]`, `en-attr-row row -> json`, `en-attrs [winners multi] -> json`, `situations [all multi when] -> (list [id=bid winners=(map @t (list row))])`, `body-json [l sits acts multi when] -> json`, `state-json [all acts multi when kind rev schema] -> json`. The nexus's `view-of` keeps answering `[all acts]` and feeds these.

- [ ] **Step 1: Append the failing tests**

```hoon
::
::  ==  the shared view encoders
::
++  test-state-and-body-json
  =/  base=obs:orr  o1
  =/  car=loaded:orr
    ['thing/subaru' [%thing 'the Subaru' ~['the car'] t0 ~] ~[['1' base]]]
  =/  me=loaded:orr
    :+  'person/me'  [%person 'me' ~ t0 `~wex]
    ~[['2' base(subject 'person/me', attr 'spouse', value (pairs:enjs:format ~[['ref' s+'person/sarah']]))]]
  =/  sit=loaded:orr
    :+  'situation/2026-09-16-breakdown'  [%situation 'breakdown' ~ t0 ~]
    :~  ['3' base(subject 'situation/2026-09-16-breakdown', attr 'status', value s+'open')]
        ['4' base(subject 'situation/2026-09-16-breakdown', attr 'participants', value (pairs:enjs:format ~[['ref' s+'thing/subaru']]))]
    ==
  =/  a=action:orr
    [%task 'Call the shop' ~ (sy ~['thing/subaru']) ~ 'mcp' t0 %approved '' ~]
  =/  all=(list loaded:orr)  ~[car me sit]
  =/  multi=(set @t)  (sy ~['participants'])
  =/  when=@da  (add t0 ~m1)
  =/  st=json  (state-json:orr all ~[['a1' a]] multi when '' (numb:enjs:format 7) [%o ~])
  =/  only-things=json  (state-json:orr all ~ multi when 'thing' (numb:enjs:format 7) [%o ~])
  =/  bj=json  (body-json:orr car (situations:orr all multi when) ~[['a1' a]] multi when)
  ;:  weld
    (expect-eq !>(3) !>((lent (ga:orr st 'bodies'))))
    (expect-eq !>(1) !>((lent (ga:orr only-things 'bodies'))))
    (expect-eq !>(`json`a+~[s+'situation/2026-09-16-breakdown']) !>((gj:orr st 'situations')))
    (expect-eq !>(1) !>((lent (ga:orr st 'actions'))))
    (expect-eq !>(`json`(numb:enjs:format 7)) !>((gj:orr st 'rev')))
    (expect-eq !>(`json`s+'thing/subaru') !>((gj:orr bj 'id')))
    (expect-eq !>(`json`s+'Route 9') !>((gj:orr (gj:orr (gj:orr bj 'attrs') 'location') 'value')))
    (expect-eq !>(`json`a+~[s+'situation/2026-09-16-breakdown']) !>((gj:orr bj 'involved')))
    (expect-eq !>(1) !>((lent (ga:orr bj 'actions'))))
    (expect-eq !>(1) !>((lent (ga:orr bj 'observations'))))
  ==
```

- [ ] **Step 2: Run the tests and watch the new one fail**

Copy both files to the wex mount, commit, run (phase 1's recipe). Expected: a build failure naming `loaded` or `state-json`.

- [ ] **Step 3: The library arms**

Append before the closing `--`:

```hoon
::  ==  the view encoders shared by the HTTP API, the tools and the page
::
::  a loaded body: its id, its record and every observation row
::
+$  loaded  [id=bid =body rows=(list row)]
::  +en-attr-row, +en-attrs: a body's current attributes as JSON. A
::  single-valued attr is one object; a multi-valued one an array; a
::  cleared attr (null winner) is absent.
::
++  en-attr-row
  |=  r=row
  ^-  json
  %-  pairs:enjs:format
  :~  ['value' value.obs.r]
      ['at' (en-time at.obs.r)]
      ['until' (en-maybe-time until.obs.r)]
      ['conf' (numb:enjs:format conf.obs.r)]
      ['source' (en-source source.obs.r)]
      ['by' s+by.obs.r]
      ['obs' s+id.r]
  ==
++  en-attrs
  |=  [winners=(map @t (list row)) multi=(set @t)]
  ^-  json
  :-  %o
  %-  ~(gas by *(map @t json))
  %+  murn  ~(tap by winners)
  |=  [attr=@t rs=(list row)]
  ^-  (unit [@t json])
  ?:  (~(has in multi) attr)  `[attr a+(turn rs en-attr-row)]
  ?~  rs  ~
  ?~  value.obs.i.rs  ~
  `[attr (en-attr-row i.rs)]
::  +situations: every situation body's winners, for involved
::
++  situations
  |=  [all=(list loaded) multi=(set @t) when=@da]
  ^-  (list [id=bid winners=(map @t (list row))])
  %+  murn  all
  |=  l=loaded
  ?.(=(%situation kind.body.l) ~ `[id.l (fold rows.l multi when)])
::  +body-json: one body's view: the record, its attributes, the
::  situations it is involved in, the open actions about it, and its
::  timeline
::
++  body-json
  |=  $:  l=loaded
          sits=(list [id=bid winners=(map @t (list row))])
          acts=(list [id=@ta a=action])
          multi=(set @t)
          when=@da
      ==
  ^-  json
  =/  winners=(map @t (list row))  (fold rows.l multi when)
  =/  about-me=(list json)
    %+  murn  acts
    |=  [aid=@ta a=action]
    ?.(&((is-open a) (~(has in about.a) id.l)) ~ `(en-action aid a))
  =/  base=json  (en-body id.l body.l)
  ?.  ?=([%o *] base)  base
  :-  %o
  %-  ~(gas by p.base)
  :~  ['attrs' (en-attrs winners multi)]
      ['involved' a+(turn (involved id.l sits) |=(b=bid `json`s+b))]
      ['actions' a+about-me]
      :-  'observations'
      :-  %a
      %+  turn  (timeline rows.l winners when)
      |=([r=row status=@tas] (en-obs r status))
  ==
::  +state-json: the state view: every body (or those of one kind) with
::  its attributes and involvements, the open situations, the open
::  actions, the beacon and the schema
::
++  state-json
  |=  $:  all=(list loaded)
          acts=(list [id=@ta a=action])
          multi=(set @t)
          when=@da
          kind=@t
          rev=json
          schema=json
      ==
  ^-  json
  =/  sits=(list [id=bid winners=(map @t (list row))])  (situations all multi when)
  =/  open-sits=(list [id=bid winners=(map @t (list row))])
    (skim sits |=([* winners=(map @t (list row))] !(is-closed winners)))
  =/  shown=(list loaded)
    ?:  =('' kind)  all
    (skim all |=(l=loaded =(kind `@t`kind.body.l)))
  =/  bodies=(list json)
    %+  turn  shown
    |=  l=loaded
    ^-  json
    =/  winners=(map @t (list row))  (fold rows.l multi when)
    =/  base=json  (en-body id.l body.l)
    ?.  ?=([%o *] base)  base
    :-  %o
    %-  ~(gas by p.base)
    :~  ['attrs' (en-attrs winners multi)]
        ['involved' a+(turn (involved id.l sits) |=(b=bid `json`s+b))]
    ==
  %-  pairs:enjs:format
  :~  ['rev' rev]
      ['at' (en-time when)]
      ['me' s+'person/me']
      ['bodies' a+bodies]
      ['situations' a+(turn open-sits |=([id=bid *] `json`s+id))]
      ['actions' a+(murn acts |=([id=@ta a=action] ?.((is-open a) ~ `(en-action id a))))]
      ['schema' schema]
  ==
```

- [ ] **Step 4: The nexus delegates**

In `code/nex/orrery/app.hoon`: delete `+$  loaded`, `+en-attr-row` and `+en-attrs` (the library's are reached as `loaded:orr`, `en-attrs:orr`; every remaining use of `loaded` in the nexus becomes `loaded:orr`). `+serve-state` keeps its reads and the actor's view and ends with one call:

```hoon
  =/  multi=(set @t)  (multi-of:orr schema)
  (send-json eyre-id 200 (state-json:orr all acts multi u.when kind rev schema))
```

(everything from the old `folded` binding to the old `send-json` goes). `+serve-body` keeps its reads, the actor's view and the `find-loaded` 404, and ends with:

```hoon
  =/  multi=(set @t)  (multi-of:orr schema)
  (send-json eyre-id 200 (body-json:orr u.mine (situations:orr all multi u.when) acts multi u.when))
```

(the old `winners`, `sits`, `about-me`, `base` bindings and the assembly go). The JSON answered must be byte-identical in shape to before: the three gates prove it.

- [ ] **Step 5: Tests green, deploy, gates**

Copy the two library files to the mount, commit, `-test`: 50 `OK`, `ok=%.y`. Write `code/lib/orrery.hoon` and `code/nex/orrery/app.hoon` to wex with the fast loop, reload, `bang` `None`. Then, one at a time: `python3 scripts/api-matrix.py $W $CK` (`ALL OK`), `python3 scripts/key-matrix.py $W $CK` (`ALL OK (65 checks)`), `python3 scripts/ship-share-matrix.py $W $CK $F $FK` (`ALL OK (68 checks)`; feb still runs version 5 and only the host side changed).

- [ ] **Step 6: Commit**

```bash
git add code/lib/orrery.hoon tests/lib/orrery.hoon code/nex/orrery/app.hoon
git commit -m "One view encoder for every surface: state-json and body-json in the library"
```

### Task 2: The eight MCP tools, callable by path

**Files:**
- Create: `code/lib/tools.hoon` (copied byte for byte from `/home/sneagan/software/groundwire/grubbery/desk/gub/lib/tools.hoon`)
- Create: `code/lib/orrery-mcp.hoon`
- Create: `code/lib/tools/orrery-state.hoon`, `orrery-body.hoon`, `orrery-resolve.hoon`, `orrery-observe.hoon`, `orrery-retract.hoon`, `orrery-act.hoon`, `orrery-actions.hoon`, `orrery-schema.hoon`
- Create: `scripts/mcp-matrix.py`

**Interfaces:**
- Consumes: Task 1's `loaded:orr`, `state-json:orr`, `body-json:orr`, `situations:orr`; the library's `parse-bid`, `de-iso`, `fill-obs`, `fill-act`, `prep-observe`, `de-action`, `obs-id`, `act-id`, `read-body`, `read-obs`, `read-action`, `resolve`, `is-open`, `transition-ok`, `initial-status`, `auto-of`, `multi-of`, `en-action`, `max-bodies`, `max-obs`, `max-note`; the kernel's `tool:tools`, `tool-state:tools`, `tool-result:tools`, `parameter-def:tools`, `tool-handler:tools`.
- Produces: `orrery-mcp.hoon`'s `base`, `arg`, `arg-json`, `text`, `fail`, `read-json`, `exists`, `ensure-me`, `load-bodies`, `load-actions`, `find-loaded`, `find-obs`, `first-missing`, `open-twin`, `body-results`, `obs-results`, `read-action-at`, `poke-writer`, `when-arg`; the eight tools; the gate.

- [ ] **Step 1: Vendor the tool types**

```bash
cp /home/sneagan/software/groundwire/grubbery/desk/gub/lib/tools.hoon code/lib/tools.hoon
cmp code/lib/tools.hoon /home/sneagan/software/groundwire/grubbery/desk/gub/lib/tools.hoon && echo identical
```

- [ ] **Step 2: The shared core**

`code/lib/orrery-mcp.hoon`:

```hoon
::  orrery-mcp: what the MCP tools share. Every road is absolute into
::  the instance, and every write is one soft poke to the writer, the
::  shape lattice's tools use. This core names kernel types, so it
::  compiles in the desk's code namespace only, unlike the pure library.
::
/<  orr  /lib/orrery.hoon
/<  tools  /lib/tools.hoon
|%
++  base  `path`/apps/'shell.shell'/desks/'orrery.desk'/desk/data/'orrery.orrery_app'
++  body-dir  |=([kind=@tas slug=@ta] ^-(path /bodies/[kind]/[slug]))
++  obs-dir   |=([kind=@tas slug=@ta] ^-(path /bodies/[kind]/[slug]/obs))
::  +arg, +arg-json: a string argument (~ when absent or not a string),
::  any argument (~ when absent)
::
++  arg
  |=  [args=(map @t json) key=@t]
  ^-  (unit @t)
  =/  v=(unit json)  (~(get by args) key)
  ?~  v  ~
  ?.  ?=([%s *] u.v)  ~
  `p.u.v
++  arg-json
  |=  [args=(map @t json) key=@t]
  ^-  json
  (fall (~(get by args) key) ~)
::  +text, +fail: a tool's two answers
::
++  text  |=(j=json ^-(tool-result:tools [%text (en:json:html j)]))
++  fail  |=(msg=@t ^-(tool-result:tools [%error msg]))
::  +when-arg: at, or now; ~ when given and unreadable
::
++  when-arg
  |=  [args=(map @t json) now=@da]
  ^-  (unit @da)
  =/  v=(unit @t)  (arg args 'at')
  ?~  v  `now
  (de-iso:orr u.v)
::  +read-json: a JSON grub in the instance, [%o ~] when absent
::
++  read-json
  |=  [p=path n=@ta]
  =/  m  (fiber:fiber:nexus ,json)
  ^-  form:m
  ;<  vw=(unit view:nexus)  bind:m  (peek-soft:io [%& %& (weld base p) n] ~)
  ?.  ?=([~ %file *] vw)  (pure:m [%o ~])
  (pure:m (fall (mole |.(!<(json (need-vase:tarball sang.u.vw)))) [%o ~]))
::  +exists: a file grub in the instance
::
++  exists
  |=  [p=path n=@ta]
  =/  m  (fiber:fiber:nexus ,?)
  ^-  form:m
  ;<  vw=(unit view:nexus)  bind:m  (peek-soft:io [%& %& (weld base p) n] ~)
  (pure:m ?=([~ %file *] vw))
::  +poke-writer: one op to orrery's writer; the error when refused
::
++  poke-writer
  |=  op=json
  =/  m  (fiber:fiber:nexus ,(unit tang))
  ^-  form:m
  (poke-soft:io [%& %& base %'main.sig'] [[/ %json] op])
::  +ensure-me: person/me is laid by the writer on first use
::
++  ensure-me
  =/  m  (fiber:fiber:nexus ,~)
  ^-  form:m
  ;<  ex=?  bind:m  (exists (body-dir %person %me) %body)
  ?:  ex  (pure:m ~)
  ;<  *  bind:m  (poke-writer (pairs:enjs:format ~[['op' s+'ensure-me']]))
  (pure:m ~)
::  ==  the walkers, the same shapes the nexus reads
::
++  load-bodies
  =/  m  (fiber:fiber:nexus ,(list loaded:orr))
  ^-  form:m
  ;<  vw=(unit view:nexus)  bind:m  (peek-soft:io [%& %| (weld base /bodies)] ~)
  ?.  ?=([~ %ball *] vw)  (pure:m ~)
  (pure:m (bodies-in ball.u.vw))
++  bodies-in
  |=  b=ball:tarball
  ^-  (list loaded:orr)
  %-  zing
  %+  turn  ~(tap by dir.b)
  |=  [kind=@ta kb=ball:tarball]
  ^-  (list loaded:orr)
  %+  murn  ~(tap by dir.kb)
  |=  [slug=@ta sb=ball:tarball]
  ^-  (unit loaded:orr)
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
++  load-actions
  =/  m  (fiber:fiber:nexus ,(list [id=@ta a=action:orr]))
  ^-  form:m
  ;<  vw=(unit view:nexus)  bind:m  (peek-soft:io [%& %| (weld base /actions)] ~)
  ?.  ?=([~ %ball *] vw)  (pure:m ~)
  ?~  fil.ball.u.vw  (pure:m ~)
  %-  pure:m
  %+  murn  ~(tap by contents.u.fil.ball.u.vw)
  |=  [nam=@ta c=[=sang:tarball gain=? bang=(unit tang)]]
  ^-  (unit [id=@ta a=action:orr])
  =/  a=(unit action:orr)  (read-action:orr (sang-noun:tarball sang.c))
  ?~(a ~ `[nam u.a])
++  read-action-at
  |=  id=@ta
  =/  m  (fiber:fiber:nexus ,(unit action:orr))
  ^-  form:m
  ;<  vw=(unit view:nexus)  bind:m  (peek-soft:io [%& %& (weld base /actions) id] ~)
  ?.  ?=([~ %file *] vw)  (pure:m ~)
  (pure:m (read-action:orr (sang-noun:tarball sang.u.vw)))
::  ==  lookups
::
++  find-loaded
  |=  [all=(list loaded:orr) id=bid:orr]
  ^-  (unit loaded:orr)
  ?~  all  ~
  ?:  =(id.i.all id)  `i.all
  $(all t.all)
::  +find-obs: the body holding an observation id, by a sweep
::
++  find-obs
  |=  [all=(list loaded:orr) id=@ta]
  ^-  (unit [=bid:orr r=row:orr])
  ?~  all  ~
  =/  hit=(list row:orr)  (skim rows.i.all |=(r=row:orr =(id.r id)))
  ?^  hit  `[id.i.all i.hit]
  $(all t.all)
++  first-missing
  |=  ids=(list bid:orr)
  =/  m  (fiber:fiber:nexus ,(unit bid:orr))
  ^-  form:m
  ?~  ids  (pure:m ~)
  ?:  =('person/me' i.ids)  (first-missing t.ids)
  =/  pk  (parse-bid:orr i.ids)
  ?~  pk  (pure:m `i.ids)
  ;<  ex=?  bind:m  (exists (body-dir kind.u.pk slug.u.pk) %body)
  ?.  ex  (pure:m `i.ids)
  (first-missing t.ids)
++  open-twin
  |=  [all=(list [id=@ta a=action:orr]) kind=@tas title=@t]
  ^-  (unit [id=@ta a=action:orr])
  ?~  all  ~
  ?:  &((is-open:orr a.i.all) =(kind.a.i.all kind) =(title.a.i.all title))  `i.all
  $(all t.all)
::  ==  per-item answers for an observe batch, as the HTTP route gives them
::
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
  ;<  ex=?  bind:m  (exists (body-dir kind.u.pk slug.u.pk) %body)
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
    (exists (body-dir kind.u.pk slug.u.pk) %body)
  ?.  has
    =/  why=@t  (cat 3 'unknown subject ' subject.o)
    (obs-results t.items known [(pairs:enjs:format ~[['ok' b+|] ['error' s+why]]) acc])
  =/  id=@ta  (obs-id:orr o)
  ;<  ex=?  bind:m  (exists (obs-dir kind.u.pk slug.u.pk) id)
  %^  obs-results  t.items  known
  [(pairs:enjs:format ~[['id' s+id] ['ok' b+&] ['existing' b+ex]]) acc]
--
```

- [ ] **Step 3: The eight tools**

Every file starts the same way and differs in its core. `code/lib/tools/orrery-state.hoon`:

```hoon
::  orrery-state: the state view, as GET /apps/orrery/api/state gives it
::
/<  tools  /lib/tools.hoon
/<  orr  /lib/orrery.hoon
/<  om  /lib/orrery-mcp.hoon
^-  tool:tools
|%
++  name  'orrery-state'
++  description
  'The state view of orrery: every body with its current attributes and the situations it is involved in, the open situations, the open actions, the beacon and the schema. Read this first.'
++  parameters
  ^-  (map @t parameter-def:tools)
  %-  ~(gas by *(map @t parameter-def:tools))
  :~  ['at' [%string 'ISO 8601 UTC time; the view as of then (default: now)']]
      ['kind' [%string 'only the bodies of this kind, e.g. "person"']]
  ==
++  required  *(list @t)
++  handler
  ^-  tool-handler:tools
  =/  m  (fiber:fiber:nexus ,tool-result:tools)
  ^-  form:m
  ;<  st=tool-state:tools  bind:m  (get-state-as:io ,tool-state:tools)
  ;<  now=@da  bind:m  get-time:io
  =/  when=(unit @da)  (when-arg:om args.st now)
  ?~  when  (pure:m (fail:om 'at: expected an ISO 8601 UTC time'))
  =/  kind=@t  (fall (arg:om args.st 'kind') '')
  ;<  schema=json  bind:m  (read-json:om / %'schema.json')
  ;<  rev=json  bind:m  (read-json:om /beacon %rev)
  ;<  all=(list loaded:orr)  bind:m  load-bodies:om
  ;<  acts=(list [id=@ta a=action:orr])  bind:m  load-actions:om
  (pure:m (text:om (state-json:orr all acts (multi-of:orr schema) u.when kind rev schema)))
--
```

`code/lib/tools/orrery-body.hoon`:

```hoon
::  orrery-body: one body's view, as GET /apps/orrery/api/body/<kind>/<slug>
::
/<  tools  /lib/tools.hoon
/<  orr  /lib/orrery.hoon
/<  om  /lib/orrery-mcp.hoon
^-  tool:tools
|%
++  name  'orrery-body'
++  description
  'One body: its record, current attributes, the situations it is involved in, the open actions about it, and its timeline of observations with source pointers.'
++  parameters
  ^-  (map @t parameter-def:tools)
  %-  ~(gas by *(map @t parameter-def:tools))
  :~  ['id' [%string 'the body id, <kind>/<slug>, e.g. "person/me"']]
      ['at' [%string 'ISO 8601 UTC time; the view as of then (default: now)']]
  ==
++  required  ~['id']
++  handler
  ^-  tool-handler:tools
  =/  m  (fiber:fiber:nexus ,tool-result:tools)
  ^-  form:m
  ;<  st=tool-state:tools  bind:m  (get-state-as:io ,tool-state:tools)
  =/  id=(unit @t)  (arg:om args.st 'id')
  ?~  id  (pure:m (fail:om 'id: required'))
  ?~  (parse-bid:orr u.id)  (pure:m (fail:om 'id: expected <kind>/<slug>'))
  ;<  now=@da  bind:m  get-time:io
  =/  when=(unit @da)  (when-arg:om args.st now)
  ?~  when  (pure:m (fail:om 'at: expected an ISO 8601 UTC time'))
  ;<  schema=json  bind:m  (read-json:om / %'schema.json')
  ;<  all=(list loaded:orr)  bind:m  load-bodies:om
  ;<  acts=(list [id=@ta a=action:orr])  bind:m  load-actions:om
  =/  mine=(unit loaded:orr)  (find-loaded:om all u.id)
  ?~  mine  (pure:m (fail:om 'no such body'))
  =/  multi=(set @t)  (multi-of:orr schema)
  (pure:m (text:om (body-json:orr u.mine (situations:orr all multi u.when) acts multi u.when)))
--
```

`code/lib/tools/orrery-resolve.hoon`:

```hoon
::  orrery-resolve: bodies by name or alias, as GET /apps/orrery/api/resolve?q=
::
/<  tools  /lib/tools.hoon
/<  orr  /lib/orrery.hoon
/<  om  /lib/orrery-mcp.hoon
^-  tool:tools
|%
++  name  'orrery-resolve'
++  description
  'Find bodies whose name or alias matches a phrase: exact matches first, then prefixes, case-insensitive, at most 20. Use it before observing about someone or something named in a message.'
++  parameters
  ^-  (map @t parameter-def:tools)
  %-  ~(gas by *(map @t parameter-def:tools))
  :~  ['q' [%string 'the name or alias to look up']]
  ==
++  required  ~['q']
++  handler
  ^-  tool-handler:tools
  =/  m  (fiber:fiber:nexus ,tool-result:tools)
  ^-  form:m
  ;<  st=tool-state:tools  bind:m  (get-state-as:io ,tool-state:tools)
  =/  q=@t  (fall (arg:om args.st 'q') '')
  ;<  all=(list loaded:orr)  bind:m  load-bodies:om
  =/  bodies=(list [id=bid:orr =body:orr])  (turn all |=(l=loaded:orr [id.l body.l]))
  %-  pure:m
  %-  text:om
  :-  %a
  %+  turn  (resolve:orr q bodies)
  |=  [id=bid:orr =body:orr match=@tas]
  ^-  json
  (pairs:enjs:format ~[['id' s+id] ['kind' s+kind.body] ['name' s+name.body] ['match' s+match]])
--
```

`code/lib/tools/orrery-observe.hoon`:

```hoon
::  orrery-observe: a batch of bodies and observations, as POST /apps/orrery/api/observe
::
/<  tools  /lib/tools.hoon
/<  orr  /lib/orrery.hoon
/<  om  /lib/orrery-mcp.hoon
^-  tool:tools
|%
++  name  'orrery-observe'
++  description
  'Submit observations, and the bodies they need, in one batch. Each observation: {subject, attr, value, at?, until?, conf?, source: {kind, id}}; each body: {id, name?, aliases?, ship?}. Answers one result per item, in order, with the observation id and whether it already existed. A batch is at most 50 bodies and 200 observations.'
++  parameters
  ^-  (map @t parameter-def:tools)
  %-  ~(gas by *(map @t parameter-def:tools))
  :~  ['bodies' [%array 'bodies to create or update before the observations, each {id, name, aliases, ship}']]
      ['observations' [%array 'observations, each {subject, attr, value, at, until, conf, source: {kind, id}}']]
      ['by' [%string 'who is observing (default "mcp")']]
  ==
++  required  ~['observations']
++  handler
  ^-  tool-handler:tools
  =/  m  (fiber:fiber:nexus ,tool-result:tools)
  ^-  form:m
  ;<  st=tool-state:tools  bind:m  (get-state-as:io ,tool-state:tools)
  =/  who=@t  (fall (arg:om args.st 'by') 'mcp')
  =/  bodies=json  (arg-json:om args.st 'bodies')
  =/  observations=json  (arg-json:om args.st 'observations')
  ?.  |(?=(~ bodies) ?=([%a *] bodies))  (pure:m (fail:om 'bodies: expected an array'))
  ?.  ?=([%a *] observations)  (pure:m (fail:om 'observations: expected an array'))
  =/  jon=json
    (pairs:enjs:format ~[['bodies' ?~(bodies [%a ~] bodies)] ['observations' observations]])
  ?:  (gth (lent (ga:orr jon 'bodies')) max-bodies:orr)  (pure:m (fail:om 'bodies: over 50'))
  ?:  (gth (lent (ga:orr jon 'observations')) max-obs:orr)  (pure:m (fail:om 'observations: over 200'))
  ;<  now=@da  bind:m  get-time:io
  =/  stamped=json
    %-  pairs:enjs:format
    :~  ['op' s+'observe']
        ['bodies' a+(ga:orr jon 'bodies')]
        ['observations' a+(turn (ga:orr jon 'observations') |=(j=json (fill-obs:orr j now who)))]
    ==
  =/  prep  (prep-observe:orr stamped now who)
  ;<  ~  bind:m  ensure-me:om
  ;<  bodies-res=(list json)  bind:m  (body-results:om bodies.prep ~)
  =/  known=(set bid:orr)
    %-  sy
    :-  'person/me'
    %+  murn  bodies.prep
    |=(e=(each [id=bid:orr =body:orr] @t) ?:(?=(%& -.e) `id.p.e ~))
  ;<  obs-res=(list json)  bind:m  (obs-results:om obs.prep known ~)
  ;<  err=(unit tang)  bind:m  (poke-writer:om stamped)
  ?^  err  (pure:m (fail:om 'the writer refused the poke'))
  (pure:m (text:om (pairs:enjs:format ~[['bodies' a+bodies-res] ['observations' a+obs-res]])))
--
```

`code/lib/tools/orrery-retract.hoon`:

```hoon
::  orrery-retract: withdraw one observation, as POST /apps/orrery/api/retract
::
/<  tools  /lib/tools.hoon
/<  orr  /lib/orrery.hoon
/<  om  /lib/orrery-mcp.hoon
^-  tool:tools
|%
++  name  'orrery-retract'
++  description
  'Retract one observation by id. The row stays on the timeline marked retracted with the note; the current state is recomputed without it.'
++  parameters
  ^-  (map @t parameter-def:tools)
  %-  ~(gas by *(map @t parameter-def:tools))
  :~  ['id' [%string 'the observation id, from a body view or an observe answer']]
      ['note' [%string 'why (at most 500 bytes)']]
      ['by' [%string 'who is retracting (default "mcp")']]
  ==
++  required  ~['id']
++  handler
  ^-  tool-handler:tools
  =/  m  (fiber:fiber:nexus ,tool-result:tools)
  ^-  form:m
  ;<  st=tool-state:tools  bind:m  (get-state-as:io ,tool-state:tools)
  =/  id=(unit @t)  (arg:om args.st 'id')
  ?~  id  (pure:m (fail:om 'id: required'))
  =/  why=@t  (fall (arg:om args.st 'note') '')
  ?:  (gth (met 3 why) max-note:orr)  (pure:m (fail:om 'note: over 500 bytes'))
  =/  who=@t  (fall (arg:om args.st 'by') 'mcp')
  ;<  all=(list loaded:orr)  bind:m  load-bodies:om
  ?~  (find-obs:om all `@ta`u.id)  (pure:m (fail:om 'no such observation'))
  =/  op=json
    (pairs:enjs:format ~[['op' s+'retract'] ['id' s+u.id] ['note' s+why] ['by' s+who]])
  ;<  err=(unit tang)  bind:m  (poke-writer:om op)
  ?^  err  (pure:m (fail:om 'the writer refused the poke'))
  (pure:m (text:om (pairs:enjs:format ~[['id' s+u.id] ['ok' b+&]])))
--
```

`code/lib/tools/orrery-act.hoon`:

```hoon
::  orrery-act: propose an action, as POST /apps/orrery/api/act
::
/<  tools  /lib/tools.hoon
/<  orr  /lib/orrery.hoon
/<  om  /lib/orrery-mcp.hoon
^-  tool:tools
|%
++  name  'orrery-act'
++  description
  'Propose an action about the state: a task, a note, a message, or another kind. Policy decides whether it is approved at once or waits in the inbox. An open action with the same kind and title answers the existing one.'
++  parameters
  ^-  (map @t parameter-def:tools)
  %-  ~(gas by *(map @t parameter-def:tools))
  :~  ['kind' [%string 'the action kind, e.g. "task"']]
      ['title' [%string 'what to do, at most 200 bytes']]
      ['payload' [%object 'anything the action needs, at most 4000 bytes serialized']]
      ['about' [%array 'body ids this action is about, at most 20']]
      ['due' [%string 'ISO 8601 UTC time the action is due']]
      ['by' [%string 'who is proposing (default "mcp")']]
  ==
++  required  ~['kind' 'title']
++  handler
  ^-  tool-handler:tools
  =/  m  (fiber:fiber:nexus ,tool-result:tools)
  ^-  form:m
  ;<  st=tool-state:tools  bind:m  (get-state-as:io ,tool-state:tools)
  =/  who=@t  (fall (arg:om args.st 'by') 'mcp')
  =/  jon=json
    :-  %o
    %-  ~(gas by *(map @t json))
    %+  murn  ~['kind' 'title' 'payload' 'about' 'due']
    |=  k=@t
    ^-  (unit [@t json])
    =/  v=json  (arg-json:om args.st k)
    ?~(v ~ `[k v])
  ;<  now=@da  bind:m  get-time:io
  =/  stamped=json  (fill-act:orr jon now who)
  =/  got  (de-action:orr stamped now who)
  ?:  ?=(%| -.got)  (pure:m (fail:om p.got))
  ;<  missing=(unit bid:orr)  bind:m  (first-missing:om ~(tap in about.p.got))
  ?^  missing  (pure:m (fail:om (cat 3 'about: no such body ' u.missing)))
  ;<  policy=json  bind:m  (read-json:om / %'policy.json')
  ;<  all=(list [id=@ta a=action:orr])  bind:m  load-actions:om
  =/  twin=(unit [id=@ta a=action:orr])  (open-twin:om all kind.p.got title.p.got)
  ?^  twin
    %-  pure:m
    %-  text:om
    (pairs:enjs:format ~[['id' s+id.u.twin] ['status' s+status.a.u.twin] ['existing' b+&]])
  =/  a=action:orr  p.got(status (initial-status:orr kind.p.got (auto-of:orr policy)))
  ;<  err=(unit tang)  bind:m
    (poke-writer:om (pairs:enjs:format ~[['op' s+'act'] ['action' stamped]]))
  ?^  err  (pure:m (fail:om 'the writer refused the poke'))
  %-  pure:m
  %-  text:om
  (pairs:enjs:format ~[['id' s+(act-id:orr a)] ['status' s+status.a] ['existing' b+|]])
--
```

`code/lib/tools/orrery-actions.hoon`:

```hoon
::  orrery-actions: list actions, or move one, as GET and POST /apps/orrery/api/actions
::
/<  tools  /lib/tools.hoon
/<  orr  /lib/orrery.hoon
/<  om  /lib/orrery-mcp.hoon
^-  tool:tools
|%
++  name  'orrery-actions'
++  description
  'Without an id: list actions, newest first, by status ("open" for proposed and approved, the default; "all"; or one status). With an id and a status: move that action to approved, dismissed, done or failed, with an optional note.'
++  parameters
  ^-  (map @t parameter-def:tools)
  %-  ~(gas by *(map @t parameter-def:tools))
  :~  ['status' [%string 'to list: open, all, or one status; to move: the new status']]
      ['id' [%string 'the action to move']]
      ['note' [%string 'why, when moving (at most 500 bytes)']]
      ['by' [%string 'who is moving it (default "mcp")']]
  ==
++  required  *(list @t)
++  handler
  ^-  tool-handler:tools
  =/  m  (fiber:fiber:nexus ,tool-result:tools)
  ^-  form:m
  ;<  st=tool-state:tools  bind:m  (get-state-as:io ,tool-state:tools)
  =/  id=(unit @t)  (arg:om args.st 'id')
  ?^  id  (move u.id args.st)
  =/  want=@t  (fall (arg:om args.st 'status') 'open')
  ;<  all=(list [id=@ta a=action:orr])  bind:m  load-actions:om
  =/  keep
    |=  [id=@ta a=action:orr]
    ^-  ?
    ?:  =('all' want)  &
    ?:  =('open' want)  (is-open:orr a)
    =(want `@t`status.a)
  =/  shown=(list [id=@ta a=action:orr])
    %+  sort  (skim all keep)
    |=([x=[id=@ta a=action:orr] y=[id=@ta a=action:orr]] (gth proposed.a.x proposed.a.y))
  (pure:m (text:om a+(turn shown |=([id=@ta a=action:orr] (en-action:orr id a)))))
::  +move: one transition through the writer
::
++  move
  |=  [id=@t args=(map @t json)]
  =/  m  (fiber:fiber:nexus ,tool-result:tools)
  ^-  form:m
  =/  want=@t  (fall (arg:om args 'status') '')
  ?:  =('' want)  (pure:m (fail:om 'status: required to move an action'))
  =/  why=@t  (fall (arg:om args 'note') '')
  ?:  (gth (met 3 why) max-note:orr)  (pure:m (fail:om 'note: over 500 bytes'))
  =/  who=@t  (fall (arg:om args 'by') 'mcp')
  ;<  a=(unit action:orr)  bind:m  (read-action-at:om `@ta`id)
  ?~  a  (pure:m (fail:om 'no such action'))
  ?.  (transition-ok:orr status.u.a `@tas`want)
    (pure:m (fail:om (rap 3 'cannot go from ' status.u.a ' to ' want ~)))
  =/  op=json
    %-  pairs:enjs:format
    ~[['op' s+'set-action'] ['id' s+id] ['status' s+want] ['note' s+why] ['by' s+who]]
  ;<  err=(unit tang)  bind:m  (poke-writer:om op)
  ?^  err  (pure:m (fail:om 'the writer refused the poke'))
  (pure:m (text:om (pairs:enjs:format ~[['id' s+id] ['status' s+want] ['ok' b+&]])))
--
```

`code/lib/tools/orrery-schema.hoon`:

```hoon
::  orrery-schema: read or replace schema.json, as GET and PUT /apps/orrery/api/schema
::
/<  tools  /lib/tools.hoon
/<  orr  /lib/orrery.hoon
/<  om  /lib/orrery-mcp.hoon
^-  tool:tools
|%
++  name  'orrery-schema'
++  description
  'Without arguments: the schema (the kinds and their attributes, which attributes are multi-valued). With schema: replace it whole.'
++  parameters
  ^-  (map @t parameter-def:tools)
  %-  ~(gas by *(map @t parameter-def:tools))
  :~  ['schema' [%object 'the whole schema document to store']]
  ==
++  required  *(list @t)
++  handler
  ^-  tool-handler:tools
  =/  m  (fiber:fiber:nexus ,tool-result:tools)
  ^-  form:m
  ;<  st=tool-state:tools  bind:m  (get-state-as:io ,tool-state:tools)
  =/  doc=json  (arg-json:om args.st 'schema')
  ?~  doc
    ;<  schema=json  bind:m  (read-json:om / %'schema.json')
    (pure:m (text:om schema))
  ?.  ?=([%o *] doc)  (pure:m (fail:om 'schema: expected an object'))
  ;<  err=(unit tang)  bind:m
    (poke-writer:om (pairs:enjs:format ~[['op' s+'set-schema'] ['doc' doc]]))
  ?^  err  (pure:m (fail:om 'the writer refused the poke'))
  (pure:m (text:om (pairs:enjs:format ~[['ok' b+&]])))
--
```

- [ ] **Step 4: Hermeticity and deploy**

```bash
python3 scripts/code-closure.py code    # expected: closed; tools.hoon, orrery-mcp.hoon and the eight tools all resolve inside code/
```

On wex: `create-folder` `tools` under `$D/code/lib`, `create-file` and `write-text` each of the eight tools, `create-file` and `write-text` `code/lib/tools.hoon` and `code/lib/orrery-mcp.hoon` (the library from Task 1 is on the ship already). No reload is needed for tools; reload anyway so the instance's own compile confirms nothing in `code/lib` broke (`bang` `None`). Then one call by path:

```bash
curl -s -b $CK -X POST -H 'content-type: application/json' $W/grubbery/mcp -d "{\"jsonrpc\":\"2.0\",\"id\":1,\"method\":\"tools/call\",\"params\":{\"name\":\"/apps/shell.shell/desks/orrery.desk/desk/code/lib/tools/orrery-state\",\"arguments\":{}}}" | python3 -c 'import sys,json; d=json.load(sys.stdin); t=json.loads(d["result"]["content"][0]["text"]); print(t["me"], len(t["bodies"]), sorted(t.keys()))'
#   person/me <n> ['actions', 'at', 'bodies', 'me', 'rev', 'schema', 'situations']
```

If the answer is an `error`, its `message` is the tool's refusal; if the request times out or the console prints `%mcp tool crashed`, read the pane and the trace (a compile error in a tool shows there as a `%mcp` line naming the file).

- [ ] **Step 5: The MCP gate**

`scripts/mcp-matrix.py`:

```python
#!/usr/bin/env python3
"""mcp-matrix.py HOST JAR
The MCP gate for orrery: the eight tools called by absolute path through
the ship's MCP server, replaying a slice of spec section 8, and checked
against the HTTP API's answers for the same reads. HOST like
http://localhost:8080; JAR a curl cookie jar from POST /~/login (the
MCP server answers JSON-RPC to the owner cookie). Exits 1 on any
failure. Safe to rerun: it retracts and deletes what it made."""
import json, subprocess, sys
from datetime import datetime, timedelta, timezone

HOST, JAR = sys.argv[1:3]
MCP = HOST + '/grubbery/mcp'
API = HOST + '/apps/orrery/api'
TOOLS = '/apps/shell.shell/desks/orrery.desk/desk/code/lib/tools/'
fails = []
count = [0]
seq = [0]


def post(url, body, timeout=120):
    cmd = ['curl', '-s', '-m', str(timeout), '-X', 'POST', '-w', '\n%{http_code}', '-b', JAR,
           '-H', 'content-type: application/json', '-d', json.dumps(body), url]
    out = subprocess.run(cmd, capture_output=True, text=True).stdout
    text, _, code = out.rpartition('\n')
    try:
        data = json.loads(text) if text else None
    except json.JSONDecodeError:
        data = text
    return int(code or 0), data


def http(method, path, body=None):
    cmd = ['curl', '-s', '-m', '60', '-X', method, '-w', '\n%{http_code}', '-b', JAR, API + path]
    if body is not None:
        cmd += ['-H', 'content-type: application/json', '-d', json.dumps(body)]
    out = subprocess.run(cmd, capture_output=True, text=True).stdout
    text, _, code = out.rpartition('\n')
    try:
        data = json.loads(text) if text else None
    except json.JSONDecodeError:
        data = text
    return int(code or 0), data


def call(tool, args):
    """(ok, payload): the tool's JSON answer parsed, or its error message"""
    seq[0] += 1
    body = {'jsonrpc': '2.0', 'id': seq[0], 'method': 'tools/call',
            'params': {'name': TOOLS + tool, 'arguments': args}}
    code, d = post(MCP, body)
    if code != 200 or not isinstance(d, dict):
        return False, 'http %s: %s' % (code, str(d)[:200])
    if 'error' in d:
        return False, str(dictish(d.get('error')).get('message'))
    content = listish(dictish(d.get('result')).get('content'))
    text = dictish(content[0] if content else {}).get('text', '')
    try:
        return True, json.loads(text)
    except (json.JSONDecodeError, TypeError):
        return True, text


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


def all_ok(d, key, n):
    items = listish(dictish(d).get(key))
    return len(items) == n and all(dictish(r).get('ok') is True for r in items)


def body_attrs(bid):
    ok, d = call('orrery-body', {'id': bid})
    return dictish(dictish(d).get('attrs')) if ok else None


def clean():
    a = body_attrs('person/me')
    for n in ('mood',):
        row = dictish(dictish(a).get(n))
        if row.get('obs'):
            call('orrery-retract', {'id': row['obs'], 'note': 'mcp gate'})
    http('DELETE', '/body/place/mcp-test')
    ok, d = call('orrery-actions', {'status': 'open'})
    for x in listish(d if ok else []):
        if isinstance(x, dict) and str(x.get('title', '')).startswith('mcp gate'):
            call('orrery-actions', {'id': str(x.get('id')), 'status': 'dismissed', 'note': 'mcp gate'})


T0 = datetime.now(timezone.utc) - timedelta(hours=1)
print('== setup')
clean()

print('== reads agree with the HTTP API')
ok, st = call('orrery-state', {})
check('state answers', ok and isinstance(st, dict), st)
check('state has the envelope', all(k in dictish(st) for k in ('rev', 'at', 'me', 'bodies', 'situations', 'actions', 'schema')), sorted(dictish(st).keys()))
code, hs = http('GET', '/state')
check('the same bodies as the HTTP state', code == 200 and sorted(b.get('id') for b in listish(dictish(st).get('bodies')) if isinstance(b, dict)) == sorted(b.get('id') for b in listish(dictish(hs).get('bodies')) if isinstance(b, dict)), (st, hs))
ok, sc = call('orrery-schema', {})
check('schema answers with kinds', ok and 'kinds' in dictish(sc), sc)
ok, st2 = call('orrery-state', {'kind': 'person'})
check('a kind filter narrows the state', ok and all(dictish(b).get('kind') == 'person' for b in listish(dictish(st2).get('bodies'))) and listish(dictish(st2).get('bodies')), st2)
ok, err = call('orrery-state', {'at': 'yesterday'})
check('a bad at is an error', not ok and 'at' in str(err), err)

print('== writes carry by and answer like the HTTP route')
ok, d = call('orrery-observe', {
    'bodies': [{'id': 'place/mcp-test', 'name': 'the MCP test place', 'aliases': ['mcp test']}],
    'observations': [{'subject': 'person/me', 'attr': 'mood', 'value': 'curious', 'at': iso(T0),
                      'source': {'kind': 'matrix', 'id': 'mcp-1'}}],
    'by': 'mcp-gate'})
check('observe answers one body and one observation, both ok', ok and all_ok(d, 'bodies', 1) and all_ok(d, 'observations', 1), d)
obs_id = str(dictish(listish(dictish(d).get('observations'))[0] if listish(dictish(d).get('observations')) else {}).get('id', ''))
a = body_attrs('person/me')
check('the body view shows the mood with by from the argument', a is not None and dictish(a.get('mood')).get('value') == 'curious' and dictish(a.get('mood')).get('by') == 'mcp-gate', a)
check('the observation id matches the view', bool(obs_id) and dictish(dictish(a).get('mood')).get('obs') == obs_id, (obs_id, a))
ok, d = call('orrery-observe', {'observations': [{'subject': 'person/me', 'attr': 'mood', 'value': 'curious', 'at': iso(T0), 'source': {'kind': 'matrix', 'id': 'mcp-1'}}], 'by': 'mcp-gate'})
check('a resubmit answers existing', ok and all_ok(d, 'observations', 1) and dictish(listish(dictish(d).get('observations'))[0]).get('existing') is True, d)
ok, d = call('orrery-observe', {'observations': [{'subject': 'org/nobody', 'attr': 'x', 'value': 1, 'source': {'kind': 'matrix', 'id': 'mcp-2'}}]})
check('an unknown subject is refused per item', ok and len(listish(dictish(d).get('observations'))) == 1 and dictish(listish(dictish(d).get('observations'))[0]).get('ok') is False, d)
ok, d = call('orrery-observe', {'observations': 'nope'})
check('a non-array batch is an error', not ok, d)
ok, d = call('orrery-resolve', {'q': 'mcp test'})
check('resolve finds the new place by alias', ok and any(dictish(r).get('id') == 'place/mcp-test' for r in listish(d)), d)
ok, d = call('orrery-body', {'id': 'place/mcp-test'})
check('the body tool answers the new place', ok and dictish(d).get('id') == 'place/mcp-test' and dictish(d).get('name') == 'the MCP test place', d)
ok, d = call('orrery-body', {'id': 'place/nowhere'})
check('a missing body is an error', not ok and 'no such body' in str(d), d)
ok, d = call('orrery-body', {'id': 'nope'})
check('a bad id is an error', not ok, d)

print('== actions')
ok, d = call('orrery-act', {'kind': 'task', 'title': 'mcp gate: call the shop', 'about': ['place/mcp-test'], 'by': 'mcp-gate'})
check('a task is proposed and approved by policy', ok and dictish(d).get('status') == 'approved' and dictish(d).get('existing') is False, d)
task_id = str(dictish(d).get('id', ''))
ok, d = call('orrery-act', {'kind': 'task', 'title': 'mcp gate: call the shop', 'by': 'mcp-gate'})
check('the same title answers the existing action', ok and dictish(d).get('id') == task_id and dictish(d).get('existing') is True, d)
ok, d = call('orrery-actions', {})
mine = [x for x in listish(d) if isinstance(x, dict) and x.get('id') == task_id]
check('the open list has it with by from the argument', ok and len(mine) == 1 and mine[0].get('by') == 'mcp-gate' and mine[0].get('about') == ['place/mcp-test'], mine)
code, hd = http('GET', '/actions?status=open')
check('the HTTP open list agrees', code == 200 and any(isinstance(x, dict) and x.get('id') == task_id for x in listish(hd)), hd)
ok, d = call('orrery-act', {'kind': 'task', 'title': 'mcp gate: about nobody', 'about': ['place/nowhere']})
check('an unknown about is an error', not ok and 'about' in str(d), d)
ok, d = call('orrery-act', {'title': 'no kind'})
check('a missing kind is an error', not ok, d)
ok, d = call('orrery-actions', {'id': task_id, 'status': 'done', 'note': 'mcp gate', 'by': 'mcp-gate'})
check('the task is moved to done', ok and dictish(d).get('status') == 'done', d)
ok, d = call('orrery-actions', {'status': 'done'})
done = [x for x in listish(d) if isinstance(x, dict) and x.get('id') == task_id]
check('the done list has it and the history names the actor', len(done) == 1 and any(dictish(h).get('by') == 'mcp-gate' and dictish(h).get('status') == 'done' for h in listish(done[0].get('history'))), done)
ok, d = call('orrery-actions', {'id': task_id, 'status': 'approved'})
check('a transition out of a terminal state is an error', not ok and 'cannot go' in str(d), d)
ok, d = call('orrery-actions', {'id': 'nope', 'status': 'done'})
check('an unknown action is an error', not ok, d)

print('== retract')
ok, d = call('orrery-retract', {'id': obs_id, 'note': 'mcp gate', 'by': 'mcp-gate'})
check('retract answers ok', ok and dictish(d).get('ok') is True, d)
a = body_attrs('person/me')
check('the mood is gone from the view', a is not None and 'mood' not in a, a)
ok, d = call('orrery-body', {'id': 'person/me'})
tl = [o for o in listish(dictish(d).get('observations')) if isinstance(o, dict) and o.get('id') == obs_id]
check('the timeline keeps the retracted row with its note', len(tl) == 1 and tl[0].get('status') == 'retracted' and tl[0].get('note') == 'mcp gate', tl)
ok, d = call('orrery-retract', {'id': 'nope'})
check('an unknown observation is an error', not ok, d)

print('== schema round trip')
ok, sc = call('orrery-schema', {})
ok2, d = call('orrery-schema', {'schema': sc})
check('replacing the schema with itself answers ok', ok and ok2 and dictish(d).get('ok') is True, d)
ok, d = call('orrery-schema', {'schema': 'nope'})
check('a non-object schema is an error', not ok, d)

print('== cleanup')
clean()
if fails:
    print('FAILED: ' + ', '.join(fails))
    sys.exit(1)
print('ALL OK (%d checks)' % count[0])
```

- [ ] **Step 6: Run it twice, then the other gates**

```bash
python3 scripts/mcp-matrix.py $W $CK
python3 scripts/mcp-matrix.py $W $CK
python3 scripts/api-matrix.py $W $CK
```

Expected: `ALL OK` with the check count printed, twice; then the phase 1 gate `ALL OK` (the tool's rows are retracted and its place deleted before it runs).

- [ ] **Step 7: Commit and push**

```bash
git add code/lib/tools.hoon code/lib/orrery-mcp.hoon code/lib/tools scripts/mcp-matrix.py
git commit -m "The eight MCP tools, callable by path, with the MCP gate"
git push origin main
```

### Task 3: The page

**Files:**
- Create: `code/nex/orrery/orrery.html`, `code/nex/orrery/orrery.css`, `code/nex/orrery/orrery.js`
- Modify: `code/nex/orrery/app.hoon` (imports, three `%over` rows, the static routes, `serve-file`)
- Create: `scripts/page-test.js`, `scripts/page-smoke.py`

**Interfaces:**
- Consumes: the HTTP API as it stands (`GET /api/state`, `GET /api/body/<kind>/<slug>`, `GET /api/actions?status=`, `POST /api/actions/<id>`, `POST /api/retract`, `GET` and `PUT /api/schema` and `/api/policy`), the keep stream at `/grubbery/api/keep/<instance>/beacon/rev`, Task 2's `own`.
- Produces: the page at `/apps/orrery`, the static files at `/apps/orrery/orrery.css` and `/apps/orrery/orrery.js`, `serve-file [eyre-id name]`, and `orrery.js`'s exported render functions `bodies(state)`, `body(view)`, `inbox(actions)`, `settings(schema, policy)`, `esc(s)`, `fmtValue(v)` for the node test.

- [ ] **Step 1: The render tests, failing**

`scripts/page-test.js`:

```javascript
#!/usr/bin/env node
// The page's render functions against fixtures: what the owner sees for
// a state view, a body view, the inbox and the settings. Run: node
// scripts/page-test.js. Exits 1 on the first failed assertion.
'use strict';
const assert = require('assert');
const path = require('path');
const render = require(path.join(__dirname, '..', 'code', 'nex', 'orrery', 'orrery.js'));

const state = {
  rev: 1789600000000, at: '2026-09-17T00:00:00Z', me: 'person/me',
  bodies: [
    { id: 'person/me', kind: 'person', name: 'me', aliases: [], ship: '~wex', attrs: { status: { value: 'home', at: '2026-09-16T22:00:00Z', by: 'talon', source: { kind: 'talon-dm', id: 'm1' }, obs: '1-a' } }, involved: ['situation/2026-09-16-breakdown'] },
    { id: 'thing/subaru', kind: 'thing', name: 'the <b>Subaru</b>', aliases: ['the car'], ship: null, attrs: {}, involved: [] },
    { id: 'situation/2026-09-16-breakdown', kind: 'situation', name: 'breakdown', aliases: [], ship: null, attrs: {}, involved: [] },
  ],
  situations: ['situation/2026-09-16-breakdown'],
  actions: [{ id: 'a1', kind: 'task', title: 'Call the shop', status: 'approved', proposed: '2026-09-17T02:10:00Z', by: 'mcp', about: ['thing/subaru'], history: [] }],
  schema: { kinds: {} },
};
const view = {
  id: 'thing/subaru', kind: 'thing', name: 'the Subaru', aliases: ['the car'], ship: null,
  attrs: { location: { value: { ref: 'place/johns-machine-shop' }, at: '2026-09-17T02:10:00Z', until: null, conf: 90, source: { kind: 'talon-dm', id: 'm3' }, by: 'talon', obs: '3-c' } },
  involved: ['situation/2026-09-16-breakdown'],
  actions: [{ id: 'a1', kind: 'task', title: 'Call the shop', status: 'approved', proposed: '2026-09-17T02:10:00Z', by: 'mcp', about: ['thing/subaru'], history: [] }],
  observations: [
    { id: '3-c', attr: 'location', value: { ref: 'place/johns-machine-shop' }, at: '2026-09-17T02:10:00Z', until: null, conf: 90, source: { kind: 'talon-dm', id: 'm3' }, by: 'talon', seen: '2026-09-17T02:10:05Z', status: 'live', retracted: false, note: '' },
    { id: '2-b', attr: 'location', value: 'Route 9', at: '2026-09-16T22:00:00Z', until: null, conf: 90, source: { kind: 'talon-dm', id: 'm1' }, by: 'talon', seen: '2026-09-16T22:00:05Z', status: 'superseded', retracted: false, note: '' },
    { id: '1-a', attr: 'status', value: 'broken down', at: '2026-09-16T22:00:00Z', until: null, conf: 90, source: { kind: 'talon-dm', id: 'm1' }, by: 'talon', seen: '2026-09-16T22:00:05Z', status: 'retracted', retracted: true, note: 'wrong car' },
  ],
};
const inbox = [
  { id: 'p1', kind: 'message', title: 'Tell Sarah the car is at the shop', status: 'proposed', proposed: '2026-09-17T02:11:00Z', by: 'mcp', about: ['person/sarah'], history: [] },
  { id: 'a1', kind: 'task', title: 'Call the shop', status: 'approved', proposed: '2026-09-17T02:10:00Z', by: 'mcp', about: ['thing/subaru'], history: [] },
];

let n = 0;
function ok(label, cond) { n += 1; assert.ok(cond, label); console.log('  ok   ' + label); }

const bodies = render.bodies(state);
ok('bodies are grouped by kind', bodies.indexOf('<h2>person</h2>') < bodies.indexOf('<h2>situation</h2>') && bodies.includes('<h2>thing</h2>'));
ok('every body links to its view', bodies.includes('href="#body/person/me"') && bodies.includes('href="#body/thing/subaru"'));
ok('names are escaped', !bodies.includes('<b>Subaru</b>') && bodies.includes('&lt;b&gt;Subaru&lt;/b&gt;'));
ok('open situations are listed', bodies.includes('situation/2026-09-16-breakdown'));

const body = render.body(view);
ok('the body view names the body', body.includes('the Subaru') && body.includes('thing/subaru'));
ok('a ref value is a link to that body', body.includes('href="#body/place/johns-machine-shop"'));
ok('the timeline shows every row with its status', body.includes('superseded') && body.includes('retracted') && body.includes('Route 9'));
ok('only a live row gets a retract button', (body.match(/data-retract="/g) || []).length === 1 && body.includes('data-retract="3-c"'));
ok('a source pointer is shown', body.includes('talon-dm') && body.includes('m3'));
ok('the retraction note is shown', body.includes('wrong car'));
ok('involved and actions are listed', body.includes('situation/2026-09-16-breakdown') && body.includes('Call the shop'));

const inboxHtml = render.inbox(inbox);
ok('a proposed action offers approve and dismiss', inboxHtml.includes('data-move="p1:approved"') && inboxHtml.includes('data-move="p1:dismissed"') && !inboxHtml.includes('data-move="p1:done"'));
ok('an approved action offers done, failed and dismiss', inboxHtml.includes('data-move="a1:done"') && inboxHtml.includes('data-move="a1:failed"') && inboxHtml.includes('data-move="a1:dismissed"') && !inboxHtml.includes('data-move="a1:approved"'));
ok('about ids link to bodies', inboxHtml.includes('href="#body/person/sarah"'));
ok('an empty inbox says so', render.inbox([]).includes('Nothing waiting'));

const settings = render.settings({ kinds: { person: { attrs: ['status'] } } }, { auto: ['task'], push: 'proposed', retention_days: 365, sensitive: ['health'] });
ok('the schema is editable JSON', settings.includes('id="schema"') && settings.includes('&quot;person&quot;'));
ok('the policy is editable JSON', settings.includes('id="policy"') && settings.includes('&quot;health&quot;'));

ok('esc handles the five characters', render.esc('<&>"\'') === '&lt;&amp;&gt;&quot;&#39;');
ok('fmtValue renders strings, refs and objects', render.fmtValue('x') === 'x' && render.fmtValue({ ref: 'a/b' }).includes('#body/a/b') && render.fmtValue({ n: 1 }) === '{&quot;n&quot;:1}');
console.log('ALL OK (' + n + ' checks)');
```

Run `node scripts/page-test.js`: expected to fail at the `require` (no such file).

- [ ] **Step 2: The page**

`code/nex/orrery/orrery.html`:

```html
<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>orrery</title>
<link rel="stylesheet" href="/apps/orrery/orrery.css">
</head>
<body>
<header>
  <a class="brand" href="#bodies">orrery</a>
  <nav>
    <a href="#bodies">Bodies</a>
    <a href="#inbox">Inbox <span id="inbox-count" class="count"></span></a>
    <a href="#settings">Settings</a>
  </nav>
  <span id="status" class="status"></span>
</header>
<main id="view"><p class="muted">Loading.</p></main>
<script src="/apps/orrery/orrery.js"></script>
</body>
</html>
```

`code/nex/orrery/orrery.css`:

```css
:root { --ink: #101541; --amber: #f9a804; --muted: #6b6f80; --line: #e2e4ec; --bg: #fbfbfd; --card: #ffffff; --bad: #b3261e; }
* { box-sizing: border-box; }
body { margin: 0; font: 15px/1.45 system-ui, -apple-system, "Segoe UI", sans-serif; color: var(--ink); background: var(--bg); }
header { display: flex; align-items: center; gap: 1.5rem; padding: .6rem 1rem; border-bottom: 2px solid var(--amber); background: var(--card); position: sticky; top: 0; }
header .brand { font-weight: 700; color: var(--ink); text-decoration: none; letter-spacing: .02em; }
header nav a { margin-right: 1rem; color: var(--ink); text-decoration: none; }
header nav a:hover { text-decoration: underline; }
.count:not(:empty) { display: inline-block; min-width: 1.4em; padding: 0 .4em; border-radius: 1em; background: var(--amber); color: var(--ink); font-size: .8em; text-align: center; }
.status { margin-left: auto; color: var(--muted); font-size: .85em; }
.status.bad { color: var(--bad); }
main { max-width: 1100px; margin: 0 auto; padding: 1rem; }
h1 { font-size: 1.4rem; margin: .2rem 0 .6rem; }
h2 { font-size: 1.05rem; margin: 1.2rem 0 .4rem; color: var(--muted); text-transform: uppercase; letter-spacing: .06em; }
.muted { color: var(--muted); }
.card { background: var(--card); border: 1px solid var(--line); border-radius: 8px; padding: .8rem 1rem; margin-bottom: 1rem; }
.bodies { display: grid; grid-template-columns: repeat(auto-fill, minmax(260px, 1fr)); gap: .5rem; }
.bodies a { display: block; padding: .5rem .7rem; border: 1px solid var(--line); border-radius: 6px; background: var(--card); color: var(--ink); text-decoration: none; }
.bodies a:hover { border-color: var(--amber); }
.bodies .id { display: block; color: var(--muted); font-size: .8em; }
table { width: 100%; border-collapse: collapse; font-size: .92em; }
th, td { text-align: left; padding: .35rem .5rem; border-bottom: 1px solid var(--line); vertical-align: top; }
th { color: var(--muted); font-weight: 600; }
tr.retracted td { color: var(--muted); text-decoration: line-through; }
tr.superseded td, tr.expired td, tr.future td { color: var(--muted); }
.badge { display: inline-block; padding: 0 .45em; border-radius: 4px; background: var(--line); font-size: .8em; }
.badge.live, .badge.approved { background: #e2f3e6; }
.badge.proposed { background: #fff2cc; }
.badge.failed, .badge.retracted { background: #f8dcda; }
button { font: inherit; padding: .25rem .6rem; border: 1px solid var(--line); border-radius: 5px; background: var(--card); color: var(--ink); cursor: pointer; margin-right: .3rem; }
button:hover { border-color: var(--amber); }
button.danger:hover { border-color: var(--bad); color: var(--bad); }
textarea { width: 100%; min-height: 14rem; font: 13px/1.4 ui-monospace, Menlo, Consolas, monospace; padding: .5rem; border: 1px solid var(--line); border-radius: 6px; }
.actions li { margin-bottom: .5rem; }
code { font-size: .9em; background: var(--line); padding: 0 .25em; border-radius: 3px; }
@media (max-width: 600px) { header { gap: .8rem; flex-wrap: wrap; } .status { margin-left: 0; width: 100%; } }
```

`code/nex/orrery/orrery.js`:

```javascript
// orrery's page: a reader with buttons over /apps/orrery/api. Pure render
// functions first (tested under node), then the app that wires them to
// the API and the beacon stream.
(function () {
  'use strict';
  var API = '/apps/orrery/api';
  var KEEP = '/grubbery/api/keep/apps/shell.shell/desks/orrery.desk/desk/data/orrery.orrery_app/beacon/rev';

  // ---- render, pure ----
  function esc(s) {
    return String(s).replace(/[<>&"']/g, function (c) {
      return { '<': '&lt;', '>': '&gt;', '&': '&amp;', '"': '&quot;', "'": '&#39;' }[c];
    });
  }
  function fmtValue(v) {
    if (v === null || v === undefined) return '<span class="muted">cleared</span>';
    if (typeof v === 'object' && !Array.isArray(v) && typeof v.ref === 'string') {
      return '<a href="#body/' + esc(v.ref) + '">' + esc(v.ref) + '</a>';
    }
    if (typeof v === 'string') return esc(v);
    return esc(JSON.stringify(v));
  }
  function fmtTime(t) { return t ? esc(String(t).replace('T', ' ').replace('Z', '')) : ''; }
  function source(s) { s = s || {}; return '<code>' + esc(s.kind || '') + '</code> ' + esc(s.id || ''); }
  function links(ids) { return (ids || []).map(function (b) { return '<a href="#body/' + esc(b) + '">' + esc(b) + '</a>'; }).join(', '); }
  function badge(s) { return '<span class="badge ' + esc(s) + '">' + esc(s) + '</span>'; }

  function bodies(state) {
    var byKind = {};
    (state.bodies || []).forEach(function (b) { (byKind[b.kind] = byKind[b.kind] || []).push(b); });
    var kinds = Object.keys(byKind).sort();
    var out = '<h1>Bodies</h1>';
    if (state.situations && state.situations.length) {
      out += '<div class="card"><strong>Open situations:</strong> ' + links(state.situations) + '</div>';
    }
    kinds.forEach(function (k) {
      out += '<h2>' + esc(k) + '</h2><div class="bodies">';
      byKind[k].sort(function (a, b) { return a.id < b.id ? -1 : 1; }).forEach(function (b) {
        var n = Object.keys(b.attrs || {}).length;
        out += '<a href="#body/' + esc(b.id) + '">' + esc(b.name || b.id) +
          (b.ship ? ' <span class="muted">' + esc(b.ship) + '</span>' : '') +
          '<span class="id">' + esc(b.id) + (n ? ' · ' + n + ' attr' + (n === 1 ? '' : 's') : '') + '</span></a>';
      });
      out += '</div>';
    });
    if (!kinds.length) out += '<p class="muted">Nothing observed yet.</p>';
    return out;
  }

  function body(v) {
    var out = '<h1>' + esc(v.name || v.id) + ' <span class="muted">' + esc(v.id) + '</span></h1>';
    out += '<p class="muted">' + esc(v.kind) + (v.ship ? ' · ' + esc(v.ship) : '') +
      (v.aliases && v.aliases.length ? ' · also ' + v.aliases.map(esc).join(', ') : '') + '</p>';
    var attrs = Object.keys(v.attrs || {}).sort();
    out += '<div class="card"><h2>Now</h2>';
    if (!attrs.length) out += '<p class="muted">No current attributes.</p>';
    else {
      out += '<table><tr><th>attribute</th><th>value</th><th>since</th><th>by</th><th>source</th></tr>';
      attrs.forEach(function (a) {
        var rows = v.attrs[a];
        (Array.isArray(rows) ? rows : [rows]).forEach(function (r) {
          out += '<tr><td>' + esc(a) + '</td><td>' + fmtValue(r.value) + '</td><td>' + fmtTime(r.at) +
            '</td><td>' + esc(r.by || '') + '</td><td>' + source(r.source) + '</td></tr>';
        });
      });
      out += '</table>';
    }
    out += '</div>';
    if (v.involved && v.involved.length) out += '<div class="card"><h2>Involved in</h2>' + links(v.involved) + '</div>';
    if (v.actions && v.actions.length) {
      out += '<div class="card"><h2>Open actions</h2><ul class="actions">';
      v.actions.forEach(function (a) { out += '<li>' + badge(a.status) + ' ' + esc(a.title) + ' <span class="muted">' + esc(a.kind) + '</span></li>'; });
      out += '</ul></div>';
    }
    out += '<div class="card"><h2>Timeline</h2>';
    if (!v.observations || !v.observations.length) out += '<p class="muted">No observations.</p>';
    else {
      out += '<table><tr><th>at</th><th>attribute</th><th>value</th><th>status</th><th>by</th><th>source</th><th></th></tr>';
      v.observations.forEach(function (o) {
        out += '<tr class="' + esc(o.status) + '"><td>' + fmtTime(o.at) + '</td><td>' + esc(o.attr) + '</td><td>' + fmtValue(o.value) +
          '</td><td>' + badge(o.status) + (o.note ? ' <span class="muted">' + esc(o.note) + '</span>' : '') +
          '</td><td>' + esc(o.by || '') + '</td><td>' + source(o.source) + '</td><td>' +
          (o.status === 'live' ? '<button class="danger" data-retract="' + esc(o.id) + '">retract</button>' : '') + '</td></tr>';
      });
      out += '</table>';
    }
    out += '</div>';
    return out;
  }

  var MOVES = { proposed: ['approved', 'dismissed'], approved: ['done', 'failed', 'dismissed'] };
  function inbox(actions) {
    var out = '<h1>Inbox</h1>';
    if (!actions || !actions.length) return out + '<p class="muted">Nothing waiting.</p>';
    out += '<ul class="actions">';
    actions.forEach(function (a) {
      out += '<li class="card">' + badge(a.status) + ' <strong>' + esc(a.title) + '</strong> <span class="muted">' + esc(a.kind) +
        ' · proposed ' + fmtTime(a.proposed) + ' by ' + esc(a.by || '') + (a.due ? ' · due ' + fmtTime(a.due) : '') + '</span>' +
        (a.about && a.about.length ? '<div>about ' + links(a.about) + '</div>' : '') + '<div>';
      (MOVES[a.status] || []).forEach(function (s) {
        out += '<button data-move="' + esc(a.id) + ':' + s + '"' + (s === 'dismissed' || s === 'failed' ? ' class="danger"' : '') + '>' + s + '</button>';
      });
      out += '</div></li>';
    });
    return out + '</ul>';
  }

  function settings(schema, policy) {
    return '<h1>Settings</h1>' +
      '<div class="card"><h2>schema.json</h2><textarea id="schema">' + esc(JSON.stringify(schema, null, 2)) + '</textarea>' +
      '<p><button data-save="schema">save schema</button></p></div>' +
      '<div class="card"><h2>policy.json</h2><textarea id="policy">' + esc(JSON.stringify(policy, null, 2)) + '</textarea>' +
      '<p><button data-save="policy">save policy</button></p></div>';
  }

  var render = { bodies: bodies, body: body, inbox: inbox, settings: settings, esc: esc, fmtValue: fmtValue };
  if (typeof module !== 'undefined' && module.exports) { module.exports = render; }
  if (typeof document === 'undefined') { return; }

  // ---- the app ----
  var view = document.getElementById('view');
  var statusEl = document.getElementById('status');
  var countEl = document.getElementById('inbox-count');
  var lastRev = null;

  function say(msg, bad) { statusEl.textContent = msg; statusEl.className = 'status' + (bad ? ' bad' : ''); }
  function api(path, opts) {
    return fetch(API + path, opts).then(function (r) {
      return r.json().catch(function () { return {}; }).then(function (d) {
        if (!r.ok) { throw new Error(d.error || ('http ' + r.status)); }
        return d;
      });
    });
  }
  function post(path, bodyObj, method) {
    return api(path, { method: method || 'POST', headers: { 'content-type': 'application/json' }, body: JSON.stringify(bodyObj) });
  }

  function route() {
    var h = location.hash.replace(/^#/, '') || 'bodies';
    if (h.indexOf('body/') === 0) return { name: 'body', id: h.slice(5) };
    return { name: h };
  }
  var refreshing = false, again = false;
  function refresh() {
    if (refreshing) { again = true; return; }
    refreshing = true;
    var r = route();
    var p;
    if (r.name === 'body') p = api('/body/' + r.id).then(function (v) { view.innerHTML = body(v); });
    else if (r.name === 'inbox') p = api('/actions?status=open').then(function (a) { view.innerHTML = inbox(a); });
    else if (r.name === 'settings') p = Promise.all([api('/schema'), api('/policy')]).then(function (d) { view.innerHTML = settings(d[0], d[1]); });
    else p = api('/state').then(function (s) { view.innerHTML = bodies(s); if (typeof s.rev === 'number') lastRev = String(s.rev); });
    p = p.then(function () { return api('/actions?status=proposed'); }).then(function (a) {
      countEl.textContent = a.length ? String(a.length) : '';
      say('');
    }).catch(function (e) { say(String(e.message || e), true); });
    p.then(function () { refreshing = false; if (again) { again = false; refresh(); } });
  }

  view.addEventListener('click', function (ev) {
    var b = ev.target.closest('button');
    if (!b) return;
    if (b.dataset.retract) {
      var note = prompt('Why retract this observation?') ;
      if (note === null) return;
      post('/retract', { id: b.dataset.retract, note: note }).then(refresh).catch(function (e) { say(e.message, true); });
    } else if (b.dataset.move) {
      var parts = b.dataset.move.split(':');
      post('/actions/' + parts[0], { status: parts[1], by: 'page' }).then(refresh).catch(function (e) { say(e.message, true); });
    } else if (b.dataset.save) {
      var which = b.dataset.save;
      var parsed;
      try { parsed = JSON.parse(document.getElementById(which).value); } catch (e) { say(which + ': ' + e.message, true); return; }
      post('/' + which, parsed, 'PUT').then(function () { say(which + ' saved'); }).catch(function (e) { say(e.message, true); });
    }
  });
  window.addEventListener('hashchange', refresh);
  document.addEventListener('visibilitychange', function () { if (!document.hidden) refresh(); });

  // ---- the beacon stream, read raw (the initial event is named "old
  // /rev", which EventSource cannot subscribe to; it carries the current
  // rev, so a bump missed while nobody watched shows as a difference) ----
  var timer = null;
  function bumped() { clearTimeout(timer); timer = setTimeout(refresh, 300); }
  async function stream() {
    for (;;) {
      if (document.hidden) { await new Promise(function (r) { setTimeout(r, 1000); }); continue; }
      try {
        var resp = await fetch(KEEP, { headers: { Accept: 'text/event-stream' } });
        var rd = resp.body.getReader();
        var dec = new TextDecoder();
        var buf = '';
        for (;;) {
          var chunk = await rd.read();
          if (chunk.done) break;
          buf += dec.decode(chunk.value, { stream: true });
          var evs = buf.split('\n\n');
          buf = evs.pop();
          evs.forEach(function (ev) {
            var name = '', data = '';
            ev.split('\n').forEach(function (ln) {
              if (ln.indexOf('event: ') === 0) name = ln.slice(7).trim();
              else if (ln.indexOf('data: ') === 0) data = ln.slice(6).trim();
            });
            if (!name || name.slice(-4) !== '/rev') return;
            if (name.indexOf('old') === 0) { if (lastRev !== null && data && data !== lastRev) bumped(); lastRev = data; return; }
            lastRev = data;
            bumped();
          });
        }
      } catch (e) { /* the stream severed: reconnect below */ }
      await new Promise(function (r) { setTimeout(r, 3000); });
    }
  }
  refresh();
  stream();
  setInterval(function () { if (!document.hidden) refresh(); }, 60000);
})();
```

Run `node scripts/page-test.js`: expected `ALL OK (19 checks)`. A failing assertion names the render function to fix.

- [ ] **Step 3: Serving**

In `code/nex/orrery/app.hoon`, next to the icon import add:

```hoon
/&  page-html  orrery.html
/&  page-css   orrery.css
/&  page-js    orrery.js
```

(the files sit beside `app.hoon` in `code/nex/orrery/`, as calendar's do). In `+on-load`, after the icon row:

```hoon
          [%over %& [/ %'orrery.html'] [[/ %mime] page-html]]
          [%over %& [/ %'orrery.css'] [[/ %mime] page-css]]
          [%over %& [/ %'orrery.js'] [[/ %mime] page-js]]
```

In `+handle-request`, before the first `/api` row:

```hoon
  ?:  &(=('GET' meth) ?=(~ suffix))                          (own (serve-file eyre-id %'orrery.html'))
  ?:  &(=('GET' meth) ?=([%'orrery.css' ~] suffix))          (own (serve-file eyre-id %'orrery.css'))
  ?:  &(=('GET' meth) ?=([%'orrery.js' ~] suffix))           (own (serve-file eyre-id %'orrery.js'))
```

Append before the closing `--`:

```hoon
::  ==  the page
::
::  +serve-file: one of the page's grubs, no-cache so an updated desk
::  shows at the next load
::
++  serve-file
  |=  [eyre-id=@ta name=@ta]
  =/  m  (fiber:fiber:nexus ,~)
  ^-  form:m
  =/  ct=(unit @t)
    ?+  name  ~
      %'orrery.html'  `'text/html; charset=utf-8'
      %'orrery.css'   `'text/css; charset=utf-8'
      %'orrery.js'    `'text/javascript; charset=utf-8'
    ==
  ?~  ct  (send-err eyre-id 404 'no such file')
  ;<  vw=view:nexus  bind:m  (peek:io (rf 1 / name) `[/ %mime])
  ?.  ?=([%file *] vw)  (send-err eyre-id 404 'no such file')
  =/  got=(unit mime)  (mole |.(!<(mime (need-vase:tarball sang.vw))))
  ?~  got  (send-err eyre-id 500 'unreadable file')
  (send-simple:srv eyre-id [[200 ~[['content-type' u.ct] ['cache-control' 'no-cache']]] `q.u.got])
```

- [ ] **Step 4: The page smoke**

`scripts/page-smoke.py`:

```python
#!/usr/bin/env python3
"""page-smoke.py HOST JAR
The page is served to the owner with the right types and no cache, and
refused without the cookie; then the render tests run under node.
Exits 1 on any failure."""
import subprocess, sys

HOST, JAR = sys.argv[1:3]
fails = []
count = [0]


def get(path, jar=True):
    cmd = ['curl', '-s', '-m', '30', '-D', '-', '-o', '/dev/stdout', HOST + path]
    if jar:
        cmd += ['-b', JAR]
    out = subprocess.run(cmd, capture_output=True, text=True).stdout
    head, _, body = out.partition('\r\n\r\n')
    if not _:
        head, _, body = out.partition('\n\n')
    code = int(head.split(' ')[1]) if head.startswith('HTTP/') else 0
    headers = {}
    for ln in head.split('\n')[1:]:
        k, _, v = ln.partition(':')
        headers[k.strip().lower()] = v.strip()
    return code, headers, body


def check(label, cond, detail=''):
    count[0] += 1
    print(('  ok   ' if cond else '  FAIL ') + label + ('' if cond else '   ' + str(detail)[:300]))
    if not cond:
        fails.append(label)


code, h, b = get('/apps/orrery')
check('the page answers 200 as html', code == 200 and h.get('content-type', '').startswith('text/html'), (code, h))
check('the page is not cached', 'no-cache' in h.get('cache-control', ''), h)
check('the page loads its script and style', 'orrery.js' in b and 'orrery.css' in b and 'id="view"' in b, b[:200])
code, h, b = get('/apps/orrery/orrery.js')
check('the script answers as javascript', code == 200 and 'javascript' in h.get('content-type', '') and 'orrery.js' not in b[:0] and '/apps/orrery/api' in b, (code, h))
code, h, b = get('/apps/orrery/orrery.css')
check('the style answers as css', code == 200 and h.get('content-type', '').startswith('text/css'), (code, h))
code, h, b = get('/apps/orrery/nope.txt')
check('an unknown file is 404', code == 404, (code, b[:100]))
code, h, b = get('/apps/orrery', jar=False)
check('the page is refused without the cookie', code == 403, (code, b[:100]))
r = subprocess.run(['node', 'scripts/page-test.js'], capture_output=True, text=True)
print(r.stdout.rstrip())
check('the render tests pass under node', r.returncode == 0 and 'ALL OK' in r.stdout, r.stderr[:300])
if fails:
    print('FAILED: ' + ', '.join(fails))
    sys.exit(1)
print('ALL OK (%d checks)' % count[0])
```

- [ ] **Step 5: Deploy, smoke, look**

Write `app.hoon` and the three page files to wex (`create-file` for each new file under `$D/code/nex/orrery`, then `write-text`), reload, `bang` `None`. Run `python3 scripts/page-smoke.py $W $CK`: `ALL OK (8 checks)`. Then read the page by hand once as a person would, through curl: `curl -s -b $CK $W/apps/orrery | head -20` shows the shell. The interactive behaviour (a click that retracts, the beacon refresh) is verified in the report by reading the JS against the API routes it calls; the owner tries it in a browser after the release. Then `python3 scripts/api-matrix.py $W $CK`: `ALL OK`.

- [ ] **Step 6: Commit and push**

```bash
git add code/nex/orrery/app.hoon code/nex/orrery/orrery.html code/nex/orrery/orrery.css code/nex/orrery/orrery.js scripts/page-test.js scripts/page-smoke.py
git commit -m "The page: bodies, a body with its timeline, the inbox, settings, refreshed by the beacon"
git push origin main
```

### Task 4: The kernel discovery gap, confirmed and rehearsed

**Files:**
- Create: `docs/kernel/mcp-desk-tools.patch` (a unified diff against `desk/gub/nex/mcp.hoon` of the grubbery repo), `docs/kernel/README.md` (what it is, how it was rehearsed, how to apply on the dist branch)

**Interfaces:**
- Consumes: the mcp nexus's `+get-app-mcp-paths` and the app-name derivation in its discovery loop (`nex/mcp.hoon` in `/home/sneagan/software/groundwire/grubbery/desk/gub/`); Task 2's tools on wex.
- Produces: the patch file; the rehearsal on `~wex` (the patched nexus written to the kernel's code tree there and the mcp instance reloaded); `tools/list` on wex advertising `apps/orrery.desk` with the eight tools.

- [ ] **Step 1: Confirm the gap**

```bash
curl -s -b $CK -X POST -H 'content-type: application/json' $W/grubbery/mcp -d '{"jsonrpc":"2.0","id":1,"method":"tools/list","params":{}}' | python3 -c 'import sys,json; d=json.load(sys.stdin); ns=[t["name"] for t in d["result"]["tools"]]; print(len(ns), [n for n in ns if "orrery" in n])'
#   <n> []    the kernel lists its own tools and none of orrery's
```

Paste the answer in the report: this is the gap the spec names.

- [ ] **Step 2: The patch**

Copy the upstream file to the scratchpad and edit the copy (never the grubbery working tree). Two hunks. `+get-app-mcp-paths` becomes:

```hoon
    ++  get-app-mcp-paths
      =/  m  (fiber:fiber:nexus ,(list path))
      ^-  form:m
      ;<  apps-view=view:nexus  bind:m
        (peek:io [%& %| /apps] ~)
      ?.  ?=([%ball *] apps-view)
        (pure:m ~)
      =/  apps=(list path)
        %+  turn  ~(tap by dir.ball.apps-view)
        |=  [nam=@ta *]
        (welp ~[%apps nam] /desk/code/lib/tools)
      ::  desks installed under the shell keep their code one level down
      ;<  desks-view=view:nexus  bind:m
        (peek:io [%& %| /apps/'shell.shell'/desks] ~)
      ?.  ?=([%ball *] desks-view)
        (pure:m apps)
      %-  pure:m
      %+  weld  apps
      %+  turn  ~(tap by dir.ball.desks-view)
      |=  [nam=@ta *]
      (welp ~[%apps %'shell.shell' %desks nam] /desk/code/lib/tools)
```

and the name derivation in the discovery loop (`=/  app-name=@ta  ?>  ?=([%apps @ *] i.app-paths)  i.t.i.app-paths`) becomes:

```hoon
      =/  app-name=@ta
        ?:  ?=([%apps %'shell.shell' %desks @ *] i.app-paths)
          i.t.t.t.i.app-paths
        ?>  ?=([%apps @ *] i.app-paths)
        i.t.i.app-paths
```

so a desk's tools are advertised under `apps/<desk>` (for orrery, `apps/orrery.desk`) and two desks never share a name. Write `docs/kernel/mcp-desk-tools.patch` with `diff -u` of the upstream file against the edited copy (paths `a/desk/gub/nex/mcp.hoon` and `b/desk/gub/nex/mcp.hoon`), and `docs/kernel/README.md`:

```markdown
# Kernel patch: MCP discovery walks the shell's desks

The mcp nexus discovers app tools by scanning `/apps/<app>/desk/code/lib/tools`, which predates desks living under the shell at `/apps/shell.shell/desks/<name>.desk/desk/code`. Orrery's tools are callable by absolute path without this patch; with it they are discovered and callable by name, advertised under `apps/orrery.desk`.

`mcp-desk-tools.patch` applies to `desk/gub/nex/mcp.hoon` in the grubbery repo: `git apply docs/kernel/mcp-desk-tools.patch` from the grubbery checkout, then release with the dist branch. It was rehearsed on `~wex` on <date> by writing the patched nexus into the kernel's code tree there and reloading the mcp instance; `tools/list` then advertised `apps/orrery.desk` with the eight tools and `tools/call` by name answered.

Calendar's and auspex's tools can leave the kernel's own bundle once this lands.
```

- [ ] **Step 3: Rehearse on wex, reversibly**

Find the kernel's mcp nexus source and instance on wex: `curl -s -b $CK "$W/grubbery/ball/code/nex?info=1"` lists the kernel's nexus files (expect `mcp.hoon` among them), and `curl -s -b $CK "$W/grubbery/ball/apps?info=1"` lists the instances (expect `mcp.mcp_app` or similar; confirm with `?info=1` on it that it is a nexus instance with a `bang`). Save the original: `curl -s -b $CK "$W/grubbery/ball/code/nex/mcp.hoon?raw=1" > $S/mcp.hoon.orig` (into the scratchpad; never into the repo) and `cmp` it against the upstream file to prove the ship runs the same source. Write the edited copy with `write-text` to `$W/grubbery/ball/code/nex/mcp.hoon`, `reload-nexus` on the mcp instance, twenty seconds, `bang` `None`. Then:

```bash
curl -s -b $CK -X POST -H 'content-type: application/json' $W/grubbery/mcp -d '{"jsonrpc":"2.0","id":1,"method":"tools/list","params":{}}' | python3 -c 'import sys,json; d=json.load(sys.stdin); ns=[t["name"] for t in d["result"]["tools"]]; print(len(ns), sorted(n for n in ns if "orrery" in n))'
#   <n plus 8> ['apps__orrery_desk__orrery_act', ...] or the names the registry derives; paste them
curl -s -b $CK -X POST -H 'content-type: application/json' $W/grubbery/mcp -d '{"jsonrpc":"2.0","id":2,"method":"tools/call","params":{"name":"<the state tool as listed>","arguments":{}}}' | python3 -c 'import sys,json; d=json.load(sys.stdin); print(sorted(json.loads(d["result"]["content"][0]["text"]).keys()))'
#   ['actions', 'at', 'bodies', 'me', 'rev', 'schema', 'situations']
```

If `bang` is not `None`, or `tools/list` no longer answers, or the kernel's own tools are missing from it: write `$S/mcp.hoon.orig` back with `write-text`, reload, confirm `tools/list` answers as before, and report BLOCKED with the bang. A rehearsal that passes stays in place on wex (it is the dev ship, and the user's own MCP client points at it: the patched registry is a superset).

Then `python3 scripts/mcp-matrix.py $W $CK` once more (by path, unchanged) and `python3 scripts/api-matrix.py $W $CK`: both `ALL OK`.

- [ ] **Step 4: Commit and push**

```bash
git add docs/kernel/mcp-desk-tools.patch docs/kernel/README.md
git commit -m "The kernel discovery patch for desk tools, rehearsed on wex"
git push origin main
```

### Task 5: Docs, the spec, version 6

**Files:**
- Create: `docs/mcp.md`
- Modify: `README.md`, `docs/releasing.md` (section 8), `docs/superpowers/specs/2026-09-16-orrery-design.md` (section 6, only where the code deviated), `code/version.json`

- [ ] **Step 1: `docs/mcp.md`**

```markdown
# The MCP tools

Orrery's eight tools give an analyst on the ship's MCP server the same views and writes as the HTTP API, as the owner. They live in `code/lib/tools` and run on the mcp nexus's tools child, reading the instance by absolute peek and writing through the one poke road to the writer.

## Calling them

- By path, today: `tools/call` with the name `/apps/shell.shell/desks/orrery.desk/desk/code/lib/tools/orrery-state` (and `orrery-body`, `orrery-resolve`, `orrery-observe`, `orrery-retract`, `orrery-act`, `orrery-actions`, `orrery-schema`). The kernel's `call_tool` meta tool takes the same path as its `tool_name`.
- By name, once the kernel discovery patch in `docs/kernel` is released: `tools/list` advertises them under `apps/orrery.desk`.
- `scripts/mcp-matrix.py` is the gate: the section 8 scenario through the tools, checked against the HTTP API.

## The tools

| tool | parameters | answers |
|---|---|---|
| `orrery-state` | `at`, `kind` | the state view: bodies with attributes and involvements, open situations, open actions, the beacon, the schema |
| `orrery-body` | `id`, `at` | one body: record, attributes, involved, open actions about it, the timeline |
| `orrery-resolve` | `q` | bodies whose name or alias matches, exact first |
| `orrery-observe` | `bodies`, `observations`, `by` | one result per item, with the observation id and whether it existed |
| `orrery-retract` | `id`, `note`, `by` | ok |
| `orrery-act` | `kind`, `title`, `payload`, `about`, `due`, `by` | the action id and its status, or the open twin |
| `orrery-actions` | `status`; or `id`, `status`, `note`, `by` | the list, or the transition |
| `orrery-schema` | `schema` | the schema, or ok after replacing it |

`by` defaults to `mcp`. A refusal is an MCP error with the same text the HTTP route would answer.

## What the analyst can see

Over MCP the analyst is the owner: every body, every attribute, sensitive ones included, and it can share and mint nothing (those stay HTTP, owner cookie). A client that should see less gets a scoped key (`docs/keys.md`) or a share (`docs/sharing.md`) instead.
```

- [ ] **Step 2: README, the release doc, the spec**

In `README.md`: the docs line gains `docs/mcp.md` and `docs/kernel/README.md`; a line says the page is at `/apps/orrery` (owner cookie); the gates line gains `scripts/mcp-matrix.py` and `scripts/page-smoke.py`. In `docs/releasing.md` section 8, after the key gate step add two steps: `python3 scripts/mcp-matrix.py http://localhost:8080 /tmp/wex.cookies` prints `ALL OK`, and `python3 scripts/page-smoke.py http://localhost:8080 /tmp/wex.cookies` prints `ALL OK`. In the spec's section 6: the MCP tools table gains `by` on `orrery-retract` and `orrery-actions` and `at` on `orrery-body`, matching the code; the kernel-gap paragraph says the patch exists in `docs/kernel` and was rehearsed on `~wex` on the date of Task 4; the page paragraph says the raw beacon stream is read the way lattice's page reads it. One line per paragraph, no em-dashes, no new promises.

- [ ] **Step 3: Version 6 through the forge, and feb follows**

```bash
python3 - <<'PY'
import json; p='code/version.json'; json.dump({'version': 6}, open(p,'w')); print(open(p).read())
PY
git add code/version.json docs README.md
git commit -m "MCP tools and the page: docs, the gates in the checklist, version 6"
git push origin main
curl -s -b $CK -X POST -H 'content-type: application/json' -d '{"repo":"orrery.git_repo","command":"pull"}' $W/grubbery/forge/api/run
#   {"ok": true} within seconds
sleep 30; curl -s -b $CK "$W/grubbery/ball/apps/shell.shell/desks/orrery.desk/desk/code/version.json?raw=1"
#   {"version": 6}
sleep 60; curl -s -b $FK "$F/grubbery/ball/apps/shell.shell/desks/orrery.desk/desk/code/version.json?raw=1"
#   {"version": 6}; feb polls wex, allow up to five minutes
for pair in "$W $CK" "$F $FK"; do set -- $pair; curl -s -b $2 "$1/grubbery/ball$APP?info=1" | python3 -c 'import sys,json; d=json.load(sys.stdin); w=d.get("weir") or {}; print(d["bang"], [(k, len(v)) for k, v in w.items()])'; done
#   None [('poke', 6), ('read', 3), ('write', 1)] on both; re-approve with phase 2's granted object if a weir shrank
python3 scripts/mcp-matrix.py $W $CK
python3 scripts/page-smoke.py $W $CK
python3 scripts/key-matrix.py $W $CK
python3 scripts/api-matrix.py $W $CK
python3 scripts/ship-share-matrix.py $W $CK $F $FK
#   ALL OK, five times, on the synced code
```

- [ ] **Step 4: Commit anything the spec edits left**

`git status` clean; otherwise `git commit -am "Spec section 6 matches what landed"` and push.

---

## Self-review

**Spec coverage (sections 5, 6, 8).** The eight tools with the spec's parameters: Task 2 (the table in section 6; `at` on the body tool and `by` on retract and actions are additions the spec gains in Task 5). Reads by absolute peek, writes by one poke road to `/main.sig`: Task 2 (`orrery-mcp.hoon`). Batches as array parameters with the object shape in the description: Task 2 (`orrery-observe`). Callable by location before discovery: Task 2 Step 4 and the gate. The kernel gap confirmed on wex before the patch, the patch rehearsed on wex and left for the dist branch: Task 4. The page's four views, reload on the beacon, a reader with buttons: Task 3. The beacon streaming through keep-SSE: Task 3 (the raw reader). The scenario replayed over MCP with the state matching: Task 2's gate compares the tool's reads with the HTTP reads.

**Placeholders.** None: every step carries its code or its exact command. Task 4 Step 3 asks the implementer to find two ship paths with `?info=1` and paste what it finds, which is discovery, not a placeholder; Task 5 Step 2's spec edits are judgment against the code.

**Type consistency.** `loaded` moves to the library with the same shape the nexus used; `state-json` takes `[all acts multi when kind rev schema]` in Task 1 and is called so by `serve-state` (Task 1) and `orrery-state` (Task 2); `body-json` takes `[l sits acts multi when]` and is called so by `serve-body` and `orrery-body`; `situations` takes `[all multi when]`. `orrery-mcp.hoon`'s `body-results`/`obs-results` mirror the nexus arms' signatures with `exists` in place of `peek-exists:io`. The page's render functions take the exact JSON the routes answer (`attrs` rows with `value/at/by/source/obs`, `observations` rows with `status` and `note`, actions with `status/title/kind/about/proposed/by/history`), and the node test's fixtures carry those keys.

**Known limits, in the docs.** The tools are owner-level (spec). The page has no create form (a v2 question per the spec). The kernel patch reaches production only through the dist branch, which is the user's. A tool call runs on the tools child nexus and needs the whole-ball grants wex has; a ship that narrowed them would see peek or poke vetoes as tool errors.


