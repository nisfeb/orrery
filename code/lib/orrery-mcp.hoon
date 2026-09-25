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
::  +exists: a file grub in the instance; ~ when the peek was refused,
::  so a grant that narrowed does not read as an absent body
::
++  exists
  |=  [p=path n=@ta]
  =/  m  (fiber:fiber:nexus ,(unit ?))
  ^-  form:m
  ;<  vw=(unit view:nexus)  bind:m  (peek-soft:io [%& %& (weld base p) n] ~)
  ?~  vw  (pure:m ~)
  (pure:m `?=([%file *] u.vw))
::  +poke-writer: one op to orrery's writer; the error when refused
::
++  poke-writer
  |=  op=json
  =/  m  (fiber:fiber:nexus ,(unit tang))
  ^-  form:m
  (poke-soft:io [%& %& base %'main.sig'] [[/ %json] op])
::  +ensure-me: person/me is laid by the writer on first use; | when the
::  peek was refused, so a caller that needs a read can say so
::
++  ensure-me
  =/  m  (fiber:fiber:nexus ,?)
  ^-  form:m
  ;<  ex=(unit ?)  bind:m  (exists (body-dir %person %me) %body)
  ?~  ex  (pure:m |)
  ?:  u.ex  (pure:m &)
  ;<  *  bind:m  (poke-writer (pairs:enjs:format ~[['op' s+'ensure-me']]))
  (pure:m &)
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
::  +find-obs: the body holding an observation id, by a sweep
::
++  find-obs
  |=  [all=(list loaded:orr) id=@ta]
  ^-  (unit [=bid:orr r=row:orr])
  ?~  all  ~
  =/  hit=(list row:orr)  (skim rows.i.all |=(r=row:orr =(id.r id)))
  ?^  hit  `[id.i.all i.hit]
  $(all t.all)
::  +first-missing: the first id with no body, or the refusal that
::  stopped the walk
::
++  first-missing
  |=  ids=(list bid:orr)
  =/  m  (fiber:fiber:nexus ,(each (unit bid:orr) @t))
  ^-  form:m
  ?~  ids  (pure:m [%& ~])
  ?:  =('person/me' i.ids)  (first-missing t.ids)
  =/  pk  (parse-bid:orr i.ids)
  ?~  pk  (pure:m [%& `i.ids])
  ;<  ex=(unit ?)  bind:m  (exists (body-dir kind.u.pk slug.u.pk) %body)
  ?~  ex  (pure:m [%| 'orrery: peek refused'])
  ?.  u.ex  (pure:m [%& `i.ids])
  (first-missing t.ids)
++  open-twin  open-twin:orr
::  ==  per-item answers for an observe batch, as the HTTP route gives them
::
::  seen carries the ids already answered in this batch, so the second
::  copy of one item answers existing rather than claiming a fresh write
::
++  body-results
  |=  [items=(list (each [id=bid:orr =body:orr] @t)) seen=(set bid:orr) acc=(list json)]
  =/  m  (fiber:fiber:nexus ,(list json))
  ^-  form:m
  ?~  items  (pure:m (flop acc))
  ?:  ?=(%| -.i.items)
    =/  entry=json  (err-entry:orr p.i.items)
    (body-results t.items seen [entry acc])
  =/  pk  (parse-bid:orr id.p.i.items)
  ?~  pk
    =/  entry=json  (err-entry:orr 'id: bad')
    (body-results t.items seen [entry acc])
  =/  bd=bid:orr  id.p.i.items
  ;<  ex=(unit ?)  bind:m  (exists (body-dir kind.u.pk slug.u.pk) %body)
  ?~  ex
    =/  entry=json  (err-entry:orr 'orrery: peek refused')
    (body-results t.items seen [entry acc])
  =/  entry=json
    (pairs:enjs:format ~[['id' s+bd] ['ok' b+&] ['existing' b+|(u.ex (~(has in seen) bd))]])
  (body-results t.items (~(put in seen) bd) [entry acc])
++  obs-results
  |=  $:  items=(list (each obs:orr @t))
          known=(set bid:orr)
          seen=(set @ta)
          acc=(list json)
      ==
  =/  m  (fiber:fiber:nexus ,(list json))
  ^-  form:m
  ?~  items  (pure:m (flop acc))
  ?:  ?=(%| -.i.items)
    =/  entry=json  (err-entry:orr p.i.items)
    (obs-results t.items known seen [entry acc])
  =/  o=obs:orr  p.i.items
  =/  pk  (parse-bid:orr subject.o)
  ?~  pk
    =/  entry=json  (err-entry:orr 'subject: bad')
    (obs-results t.items known seen [entry acc])
  ;<  has=(unit ?)  bind:m
    ?:  (~(has in known) subject.o)  (pure:(fiber:fiber:nexus ,(unit ?)) `&)
    (exists (body-dir kind.u.pk slug.u.pk) %body)
  ?~  has
    =/  entry=json  (err-entry:orr 'orrery: peek refused')
    (obs-results t.items known seen [entry acc])
  ?.  u.has
    =/  why=@t  (cat 3 'unknown subject ' subject.o)
    =/  entry=json  (err-entry:orr why)
    (obs-results t.items known seen [entry acc])
  =/  id=@ta  (obs-id:orr o)
  ;<  ex=(unit ?)  bind:m  (exists (obs-dir kind.u.pk slug.u.pk) id)
  ?~  ex
    =/  entry=json  (err-entry:orr 'orrery: peek refused')
    (obs-results t.items known seen [entry acc])
  =/  entry=json
    (pairs:enjs:format ~[['id' s+id] ['ok' b+&] ['existing' b+|(u.ex (~(has in seen) id))]])
  (obs-results t.items known (~(put in seen) id) [entry acc])
--
