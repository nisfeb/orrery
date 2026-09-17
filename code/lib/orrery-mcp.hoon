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
