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
  ?:  =('delete-body' op)  (do-delete-body jon)
  ?:  =('retract' op)  (do-retract jon)
  ?:  =('act' op)  (do-act jon)
  ?:  =('set-action' op)  (do-set-action jon)
  ?:  =('set-schema' op)  (do-set-doc %'schema.json' 'set-schema' jon)
  ?:  =('set-policy' op)  (do-set-doc %'policy.json' 'set-policy' jon)
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
::  tree, never on a refusal or a no-op. Milliseconds since 1970, so a
::  browser keeps it exact.
::
++  bump-beacon
  =/  m  (fiber:fiber:nexus ,~)
  ^-  form:m
  ;<  now=@da  bind:m  get-time:io
  =/  ms=@ud  (div (sub now ~1970.1.1) (div ~s1 1.000))
  (over:io (rf 0 /beacon %rev) [[/ %json] (numb:enjs:format ms)])
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
  =/  s2=@ta  ?:(?=([@ @ @ *] suffix) i.t.t.suffix %$)
  =/  s3=@ta  ?:(?=([@ @ @ @ *] suffix) i.t.t.t.suffix %$)
  =/  args=quay:eyre  args.parsed
  ?:  &(=('GET' meth) ?=([%api %state ~] suffix))        (serve-state eyre-id args)
  ?:  &(=('GET' meth) ?=([%api %body @ @ ~] suffix))     (serve-body eyre-id s2 s3 args)
  ?:  &(=('DELETE' meth) ?=([%api %body @ @ ~] suffix))  (serve-delete-body eyre-id s2 s3)
  ?:  &(=('GET' meth) ?=([%api %resolve ~] suffix))      (serve-resolve eyre-id args)
  ?:  &(=('POST' meth) ?=([%api %observe ~] suffix))     (serve-observe eyre-id jon)
  ?:  &(=('POST' meth) ?=([%api %retract ~] suffix))     (serve-retract eyre-id jon)
  ?:  &(=('POST' meth) ?=([%api %bodies ~] suffix))      (serve-bodies eyre-id jon)
  ?:  &(=('POST' meth) ?=([%api %act ~] suffix))         (serve-act eyre-id jon)
  ?:  &(=('GET' meth) ?=([%api %actions ~] suffix))      (serve-actions eyre-id args)
  ?:  &(=('POST' meth) ?=([%api %actions @ ~] suffix))   (serve-set-action eyre-id s2 jon)
  ?:  &(=('GET' meth) ?=([%api %schema ~] suffix))       (serve-doc eyre-id %'schema.json')
  ?:  &(=('PUT' meth) ?=([%api %schema ~] suffix))       (serve-set-doc eyre-id 'set-schema' jon)
  ?:  &(=('GET' meth) ?=([%api %policy ~] suffix))       (serve-doc eyre-id %'policy.json')
  ?:  &(=('PUT' meth) ?=([%api %policy ~] suffix))       (serve-set-doc eyre-id 'set-policy' jon)
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
  ;<  acts=(list [id=@ta a=action:orr])  bind:m  (load-actions 1)
  =/  multi=(set @t)  (multi-of:orr schema)
  =/  folded=(list [id=bid:orr =body:orr winners=(map @t (list row:orr))])
    (turn all |=(l=loaded [id.l body.l (fold:orr rows.l multi u.when)]))
  =/  sits=(list [id=bid:orr winners=(map @t (list row:orr))])
    %+  murn  folded
    |=  [id=bid:orr =body:orr winners=(map @t (list row:orr))]
    ?:(=(%situation kind.body) `[id winners] ~)
  =/  open-sits=(list [id=bid:orr winners=(map @t (list row:orr))])
    (skim sits |=([* winners=(map @t (list row:orr))] !(is-closed:orr winners)))
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
      ['situations' a+(turn open-sits |=([id=bid:orr *] `json`s+id))]
      ['actions' a+(murn acts |=([id=@ta a=action:orr] ?.((is-open:orr a) ~ `(en-action:orr id a))))]
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
  %^  send-json  eyre-id  200
  (pairs:enjs:format ~[['bodies' a+bodies-res] ['observations' a+obs-res]])
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
--
