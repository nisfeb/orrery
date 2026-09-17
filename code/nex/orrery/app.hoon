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
::    /tr/log                          the audit ring, the last 500 ops
::    /tr/inbox                        ship traffic, its own ring of 500
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
/&  page-html  orrery.html
/&  page-css   orrery.css
/&  page-js    orrery.js
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
          [%over %& [/ %'orrery.html'] [[/ %mime] page-html]]
          [%over %& [/ %'orrery.css'] [[/ %mime] page-css]]
          [%over %& [/ %'orrery.js'] [[/ %mime] page-js]]
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
          [%fall %& [/tr %log] [[/ %json] [%a ~]]]
          [%fall %& [/tr %inbox] [[/ %json] [%a ~]]]
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
          ::  clients.json: the minted keys, each a salted hash of its
          ::  secret with a name, an identity and a scope (spec section 11,
          ::  phase 3)
          [%fall %& [/ %'clients.json'] [[/ %json] [%o ~]]]
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
          ::  the inbox: other ships poke offers, revokes, and observations
          ::  on bodies shared with them in edit mode. The sender is the
          ::  transport's; the payload is data; nothing reaches the writer
          ::  without by and source rewritten here. A local poke is ignored.
          [~ %'shares.sig']
        ;<  ~  bind:m  (rise-wait:io prod "%orrery inbox: failed")
        ::  the road any ship pokes is laid from here: the registry keys a
        ::  grant to the poking fiber's own rail and scopes it to that
        ::  fiber's directory, so only a fiber at the root can grant a
        ::  road at the root. A request fiber's grant is refused.
        ;<  ~  bind:m  lay-inbox-road
        |-
        ;<  [=from:fiber:nexus =sage:tarball]  bind:m  take-poke-from:io
        =/  src=(unit @p)  (get-poke-src:io from)
        ;<  our=@p  bind:m  get-our:io
        ;<  ~  bind:m
          ?:  |(?=(~ src) =(our (fall src our)))  (pure:m ~)
          (take-inbox (fall src our) sage)
        $
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
          (line '/sys/gall/' 'tell another ship you shared a body with it, revoke that, and send it your observations on a body it shared with you in edit mode. Refuse this and sharing with ships is unavailable; everything else works')
          (line '/sys/behn/' 'the follower ticks every five minutes to pull what other ships shared with you, and a message to another ship gives up after thirty seconds. Refuse this and sharing with ships is unavailable')
          (line '/sys/ames/registry' 'let other ships poke your inbox with an offer, a revoke, or edits on a body you shared with them. Refuse this and sharing with ships is unavailable')
      ==
      :-  'peek'
      :-  %a
      :~  (line '/sys/link/' 'find where this app is installed, so the page can address its own writer and an offer can say where to read')
          (line '/sys/ames/usergroups/' 'read a share group before rewriting it')
          (line '/sys/ames/ships/' 'read a body another ship shared with you, and keep it current. Refuse this and bodies shared with you are unavailable')
      ==
      :-  'make'
      :-  %a
      :~  (line '/sys/ames/usergroups/' 'make and rewrite the group for a shared body: the ships that may read it')
      ==
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
  ?:  =('add-client' op)  (do-add-client jon)
  ?:  =('drop-client' op)  (do-drop-client jon)
  ?:  =('touch-client' op)  (do-touch-client jon)
  (refuse op 'unknown op')
::  +refuse: a refusal that leaves the writer standing
::
++  refuse
  |=  [op=@t why=@t]
  =/  m  (fiber:fiber:nexus ,?)
  ^-  form:m
  ;<  ~  bind:m  (note op | why)
  (pure:m |)
::  +note-then-no: a no-op that still leaves its reason in /tr/last
::
++  note-then-no
  |=  [op=@t why=@t]
  =/  m  (fiber:fiber:nexus ,?)
  ^-  form:m
  ;<  ~  bind:m  (note op & why)
  (pure:m |)
::  +note: the last writer outcome at /tr/last, and the audit ring at
::  /tr/log (the last 500). Fiber prints reach only the raw console; a
::  grub is readable by every tool.
::
++  note
  |=  [op=@t ok=? why=@t]
  =/  m  (fiber:fiber:nexus ,~)
  ^-  form:m
  (note-by op ok why '')
::  +note-by: the same outcome with the actor who caused it named
::
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
::  +note-inbox: an outcome of ship traffic, in its own ring (500), so a
::  stranger's pokes never evict the owner's audit log or /tr/last
::
++  note-inbox
  |=  [op=@t ok=? why=@t by=@t]
  =/  m  (fiber:fiber:nexus ,~)
  ^-  form:m
  (note-inbox-at 0 op ok why by)
::  +note-inbox-at: the same ring from a fiber that is not the nexus
::  root, which a request fiber is
::
++  note-inbox-at
  |=  [up=@ud op=@t ok=? why=@t by=@t]
  =/  m  (fiber:fiber:nexus ,~)
  ^-  form:m
  ;<  now=@da  bind:m  get-time:io
  =/  entry=json
    %-  pairs:enjs:format
    ~[['op' s+op] ['ok' b+ok] ['why' s+why] ['by' s+by] ['at' (en-time:orr now)]]
  ;<  log=json  bind:m  (read-json (rf up /tr %inbox))
  (over:io (rf up /tr %inbox) [[/ %json] (ring:orr log entry 500)])
::  +note-refusals: one ship-traffic note per refusal, for the rows a
::  ship sent or holds that the decoder would not take
::
++  note-refusals
  |=  [op=@t by=@t bad=(list [oid=@t why=@t])]
  =/  m  (fiber:fiber:nexus ,~)
  ^-  form:m
  ?~  bad  (pure:m ~)
  ::  the oid is a peer's text: keep it to 64 bytes so the ring holds
  ::  notes rather than one ship's essay
  =/  why=@t  (rap 3 (end [3 64] oid.i.bad) ': ' why.i.bad ~)
  ;<  ~  bind:m  (note-inbox op | why by)
  (note-refusals op by t.bad)
::  +bump-beacon: the change beacon moves once per op that changed the
::  tree, never on a refusal or a no-op. Milliseconds since 1970, so a
::  browser keeps it exact.
::
++  bump-beacon
  =/  m  (fiber:fiber:nexus ,~)
  ^-  form:m
  ;<  now=@da  bind:m  get-time:io
  =/  ms=@ud  ?:((lth now ~1970.1.1) 0 (div (sub now ~1970.1.1) (div ~s1 1.000)))
  (over:io (rf 0 /beacon %rev) [[/ %json] (numb:enjs:format ms)])
::  +ensure-me: person/me, named "me", aliased me and I, on our ship
::
++  ensure-me
  =/  m  (fiber:fiber:nexus ,?)
  ^-  form:m
  ;<  ex=?  bind:m  (peek-exists:io (rf 0 (body-dir %person %me) %body))
  ?:  ex  (pure:m |)
  ;<  our=@p  bind:m  get-our:io
  ;<  now=@da  bind:m  get-time:io
  =/  b=body:orr  [%person 'me' (sy `(list @t)`~['me' 'I']) now `our]
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
    ::  a vetoed make wrote nothing: the beacon must not move for it
    ;<  err=(unit tang)  bind:m
      (make-gained-soft:io road |+[[[/orrery %body] `stored-body:orr`[%2 fresh]] ~])
    (pure:m ?=(~ err))
  =/  old=(unit body:orr)  (read-body:orr (sang-noun:tarball sang.cur))
  ::  a grub this build cannot read is left where it is: overwriting it
  ::  would throw away a body a later shape may still understand
  ?~  old
    ;<  ~  bind:m  (note 'write-body' | 'unreadable body')
    (pure:m |)
  =/  merged=body:orr  (merge-body:orr u.old new)
  ?:  =(merged u.old)  (pure:m |)
  ;<  ~  bind:m  (over:io road [[/orrery %body] `stored-body:orr`[%2 merged]])
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
  ::  a batch carried from a shared peer belongs in the ship-traffic
  ::  ring, not in the owner's audit log
  =/  who=@t
    =/  os=(list json)  (ga:orr jon 'observations')
    ?~(os '' (gs:orr i.os 'by'))
  ;<  ~  bind:m
    ?:  =('ship' (gs:orr jon 'via'))  (note-inbox 'observe' & '' who)
    (note 'observe' & '')
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
  ;<  err=(unit tang)  bind:m
    (make-soft:io road |+[[[/orrery %obs] `stored-obs:orr`[%1 o]] ~])
  (write-obs t.items |(changed ?=(~ err)))
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
::  +load-bodies: every body under /bodies with its observation rows
::
++  load-bodies
  |=  up=@ud
  =/  m  (fiber:fiber:nexus ,(list loaded:orr))
  ^-  form:m
  ;<  vw=view:nexus  bind:m  (peek:io (rv up /bodies) ~)
  ?.  ?=([%ball *] vw)  (pure:m ~)
  (pure:m (bodies-in ball.vw))
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
::  Who is asking is settled by +identify: the owner (eyre's
::  authenticated flag and src equal to our) or a minted key. The
::  scoped routes take the actor and apply its scope themselves; every
::  other route is wrapped in +own, the owner alone.
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
  ;<  who=(unit actor)  bind:m  (identify req src our)
  ?~  who  (send-err eyre-id 403 'forbidden')
  =/  act=actor  u.who
  ::  +own: a route the owner alone may take
  =/  own  |=(f=form:m ^-(form:m ?:(owner.act f (send-err eyre-id 403 'owner only'))))
  ::  a body is read as JSON, so a request carrying one says it is JSON.
  ::  The gates and the page all send the header.
  =/  ctype=@t
    =/  raw=tape
      (cass (trip (fall (get-header:http 'content-type' header-list.request.req) '')))
    (crip raw)
  ?:  ?&  |(=('POST' meth) =('PUT' meth))
          ?=(^ body.request.req)
          !=('application/json' (end [3 16] ctype))
      ==
    (send-err eyre-id 415 'content-type: application/json required')
  ;<  ~  bind:m  ensure-me-from-request
  =/  jon=json
    (fall (de:json:html ?~(body.request.req '' q.u.body.request.req)) ~)
  =/  s2=@ta  ?:(?=([@ @ @ *] suffix) i.t.t.suffix %$)
  =/  s3=@ta  ?:(?=([@ @ @ @ *] suffix) i.t.t.t.suffix %$)
  =/  s4=@ta  ?:(?=([@ @ @ @ @ *] suffix) i.t.t.t.t.suffix %$)
  =/  args=quay:eyre  args.parsed
  ?:  &(=('GET' meth) ?=(~ suffix))                          (own (serve-file eyre-id %'orrery.html'))
  ?:  &(=('GET' meth) ?=([%'orrery.css' ~] suffix))          (own (serve-file eyre-id %'orrery.css'))
  ?:  &(=('GET' meth) ?=([%'orrery.js' ~] suffix))           (own (serve-file eyre-id %'orrery.js'))
  ?:  &(=('GET' meth) ?=([%api %state ~] suffix))           (serve-state eyre-id args act)
  ?:  &(=('GET' meth) ?=([%api %body @ @ ~] suffix))        (serve-body eyre-id s2 s3 args act)
  ?:  &(=('DELETE' meth) ?=([%api %body @ @ ~] suffix))     (own (serve-delete-body eyre-id s2 s3))
  ?:  &(=('GET' meth) ?=([%api %resolve ~] suffix))         (serve-resolve eyre-id args act)
  ?:  &(=('POST' meth) ?=([%api %observe ~] suffix))        (serve-observe eyre-id jon act)
  ?:  &(=('POST' meth) ?=([%api %retract ~] suffix))        (serve-retract eyre-id jon act)
  ?:  &(=('POST' meth) ?=([%api %bodies ~] suffix))         (serve-bodies eyre-id jon act)
  ?:  &(=('POST' meth) ?=([%api %act ~] suffix))            (serve-act eyre-id jon act)
  ?:  &(=('GET' meth) ?=([%api %actions ~] suffix))         (serve-actions eyre-id args act)
  ?:  &(=('POST' meth) ?=([%api %actions @ ~] suffix))      (serve-set-action eyre-id s2 jon act)
  ?:  &(=('GET' meth) ?=([%api %schema ~] suffix))          (own (serve-doc eyre-id %'schema.json'))
  ?:  &(=('PUT' meth) ?=([%api %schema ~] suffix))          (own (serve-set-doc eyre-id 'set-schema' jon))
  ?:  &(=('GET' meth) ?=([%api %policy ~] suffix))          (own (serve-doc eyre-id %'policy.json'))
  ?:  &(=('PUT' meth) ?=([%api %policy ~] suffix))          (own (serve-set-doc eyre-id 'set-policy' jon))
  ?:  &(=('POST' meth) ?=([%api %share ~] suffix))          (own (serve-share eyre-id jon))
  ?:  &(=('DELETE' meth) ?=([%api %share @ @ @ ~] suffix))  (own (serve-revoke eyre-id s2 s3 s4))
  ?:  &(=('GET' meth) ?=([%api %shares ~] suffix))          (own (serve-shares eyre-id))
  ?:  &(=('POST' meth) ?=([%api %accept ~] suffix))         (own (serve-accept eyre-id jon))
  ?:  &(=('POST' meth) ?=([%api %decline ~] suffix))        (own (serve-decline eyre-id jon))
  ?:  &(=('POST' meth) ?=([%api %sync ~] suffix))           (own (serve-sync eyre-id))
  ?:  &(=('POST' meth) ?=([%api %clients ~] suffix))        (own (serve-mint eyre-id jon))
  ?:  &(=('GET' meth) ?=([%api %clients ~] suffix))         (own (serve-clients eyre-id))
  ?:  &(=('DELETE' meth) ?=([%api %clients @ ~] suffix))    (own (serve-drop-client eyre-id s2))
  (send-err eyre-id 404 'no such route')
::  +serve-state: every body with its current attributes, the open
::  situations, the open actions and the schema, as of ?at
::
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
  ;<  all0=(list loaded:orr)  bind:m  (load-bodies 1)
  ;<  acts0=(list [id=@ta a=action:orr])  bind:m  (load-actions 1)
  =/  seen  (view-of act all0 acts0 (hidden-for act policy))
  =/  all=(list loaded:orr)  all.seen
  =/  acts=(list [id=@ta a=action:orr])  acts.seen
  ::  a key gets the schema trimmed to its scope: GET /schema is the
  ::  owner's, so the state view must not hand the whole document over
  =/  shown-schema=json
    ?~  scope.act  schema
    (scope-schema:orr schema u.scope.act (hidden-for act policy))
  =/  multi=(set @t)  (multi-of:orr schema)
  (send-json eyre-id 200 (state-json:orr all acts multi u.when kind rev shown-schema))
::  +serve-observe: decode, answer per item, hand the stamped request to
::  the writer. The ids reported here are the ids the writer makes,
::  because at and by are stamped before either side decodes.
::
++  serve-observe
  |=  [eyre-id=@ta jon=json act=actor]
  =/  m  (fiber:fiber:nexus ,~)
  ^-  form:m
  ?.  ?=([%o *] jon)  (send-err eyre-id 400 'a JSON object is required')
  =/  obs-j=json  (gj:orr jon 'observations')
  ?.  |(?=(~ obs-j) ?=([%a *] obs-j))
    (send-err eyre-id 400 'observations: expected an array')
  =/  bodies-j=json  (gj:orr jon 'bodies')
  ?.  |(?=(~ bodies-j) ?=([%a *] bodies-j))
    (send-err eyre-id 400 'bodies: expected an array')
  ?:  (gth (lent (ga:orr jon 'bodies')) max-bodies:orr)
    (send-err eyre-id 400 'bodies: over 50')
  ?:  (gth (lent (ga:orr jon 'observations')) max-obs:orr)
    (send-err eyre-id 400 'observations: over 200')
  ;<  policy=json  bind:m  (read-json (rf 1 / %'policy.json'))
  =/  denied=(unit @t)  (deny-observe act jon policy)
  ?^  denied  (send-err eyre-id 403 u.denied)
  ;<  now=@da  bind:m  get-time:io
  =/  stamp
    |=  j=json
    ^-  json
    ?:(owner.act (fill-obs:orr j now 'http') (fill-obs-as:orr j now by.act))
  =/  all-obs=(list json)  (turn (ga:orr jon 'observations') stamp)
  ::  a ship source is the inbox's to set, from the transport: a local
  ::  client sending one would be forging another ship's claim, so the
  ::  item is answered refused and never reaches the writer
  =/  stamped=json
    %-  pairs:enjs:format
    :~  ['op' s+'observe']
        ['bodies' a+(ga:orr jon 'bodies')]
        ['observations' a+(skip all-obs ship-source:orr)]
    ==
  =/  shown=json
    %-  pairs:enjs:format
    :~  ['op' s+'observe']
        ['bodies' a+(ga:orr jon 'bodies')]
        ['observations' a+all-obs]
    ==
  =/  prep  (prep-observe:orr shown now by.act)
  =/  items=(list (each obs:orr @t))  (mark-reserved:orr all-obs obs.prep)
  ;<  bodies-res=(list json)  bind:m  (body-results bodies.prep ~ ~)
  =/  known=(set bid:orr)
    %-  sy
    :-  'person/me'
    %+  murn  bodies.prep
    |=(e=(each [id=bid:orr =body:orr] @t) ?:(?=(%& -.e) `id.p.e ~))
  ;<  obs-res=(list json)  bind:m  (obs-results items known ~ ~)
  ;<  err=(unit tang)  bind:m  (poke-soft:io (rf 1 / %'main.sig') [[/ %json] stamped])
  ?^  err  (send-err eyre-id 500 'the writer refused the poke')
  %^  send-json  eyre-id  200
  (pairs:enjs:format ~[['bodies' a+bodies-res] ['observations' a+obs-res]])
::  seen carries the ids already answered in this batch, so the second
::  copy of one item answers existing rather than claiming a fresh write
::
++  body-results
  |=  [items=(list (each [id=bid:orr =body:orr] @t)) seen=(set bid:orr) acc=(list json)]
  =/  m  (fiber:fiber:nexus ,(list json))
  ^-  form:m
  ?~  items  (pure:m (flop acc))
  ?:  ?=(%| -.i.items)
    %^  body-results  t.items  seen
    [(pairs:enjs:format ~[['ok' b+|] ['error' s+p.i.items]]) acc]
  =/  pk  (parse-bid:orr id.p.i.items)
  ?~  pk
    %^  body-results  t.items  seen
    [(pairs:enjs:format ~[['ok' b+|] ['error' s+'id: bad']]) acc]
  =/  bd=bid:orr  id.p.i.items
  ;<  ex=?  bind:m  (peek-exists:io (rf 1 (body-dir kind.u.pk slug.u.pk) %body))
  =/  entry=json
    (pairs:enjs:format ~[['id' s+bd] ['ok' b+&] ['existing' b+|(ex (~(has in seen) bd))]])
  %^  body-results  t.items  (~(put in seen) bd)  [entry acc]
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
    =/  entry=json  (pairs:enjs:format ~[['ok' b+|] ['error' s+p.i.items]])
    (obs-results t.items known seen [entry acc])
  =/  o=obs:orr  p.i.items
  =/  pk  (parse-bid:orr subject.o)
  ?~  pk
    =/  entry=json  (pairs:enjs:format ~[['ok' b+|] ['error' s+'subject: bad']])
    (obs-results t.items known seen [entry acc])
  ;<  has=?  bind:m
    ?:  (~(has in known) subject.o)  (pure:(fiber:fiber:nexus ,?) &)
    (peek-exists:io (rf 1 (body-dir kind.u.pk slug.u.pk) %body))
  ?.  has
    =/  why=@t  (cat 3 'unknown subject ' subject.o)
    =/  entry=json  (pairs:enjs:format ~[['ok' b+|] ['error' s+why]])
    (obs-results t.items known seen [entry acc])
  =/  id=@ta  (obs-id:orr o)
  ;<  ex=?  bind:m  (peek-exists:io (rf 1 (obs-dir kind.u.pk slug.u.pk) id))
  =/  entry=json
    (pairs:enjs:format ~[['id' s+id] ['ok' b+&] ['existing' b+|(ex (~(has in seen) id))]])
  (obs-results t.items known (~(put in seen) id) [entry acc])
::  +find-obs: the body holding an observation id, by a sweep
::
++  find-obs
  |=  [up=@ud id=@ta]
  =/  m  (fiber:fiber:nexus ,(unit [kind=@tas slug=@ta r=row:orr]))
  ^-  form:m
  ;<  all=(list loaded:orr)  bind:m  (load-bodies up)
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
  |=  [all=(list loaded:orr) id=bid:orr]
  ^-  (unit loaded:orr)
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
  ?:  retracted.obs.r.u.hit  (note-then-no 'retract' 'already retracted')
  =/  o=obs:orr  obs.r.u.hit(retracted &, note why)
  ;<  ~  bind:m
    %+  over:io  (rf 0 (obs-dir kind.u.hit slug.u.hit) id.r.u.hit)
    [[/orrery %obs] `stored-obs:orr`[%1 o]]
  ;<  ~  bind:m  (compact kind.u.hit slug.u.hit)
  =/  who=@t  (gs:orr jon 'by')
  ;<  ~  bind:m
    ?:  =('ship' (gs:orr jon 'via'))  (note-inbox 'retract' & why who)
    (note-by 'retract' & why who)
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
  ::  person/me always exists by the time the writer reads this: the
  ::  request queued +ensure-me ahead of its own poke
  ?:  =('person/me' i.ids)  (first-missing up t.ids)
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
  ?^  (open-twin all kind.p.got title.p.got)  (note-then-no 'act' 'an open action with this kind and title exists')
  =/  auto=?  =(%approved (initial-status:orr kind.p.got (auto-of:orr policy)))
  =/  a=action:orr  ?.(auto p.got (transition:orr p.got %approved 'policy' '' now))
  =/  id=@ta  (act-id:orr a)
  ;<  ex=?  bind:m  (peek-exists:io (rf 0 /actions id))
  ?:  ex  (note-then-no 'act' 'an action with this id exists')
  ;<  *  bind:m
    (make-gained-soft:io (rf 0 /actions id) |+[[[/orrery %action] `stored-action:orr`[%2 a]] ~])
  ;<  ~  bind:m
    ?.  (should-push:orr (push-mode-of:orr policy) status.a)  (pure:(fiber:fiber:nexus ,~) ~)
    (push-soft a id)
  ;<  ~  bind:m  (note-by 'act' & '' by.a)
  (pure:m &)
::  +push-soft: a notification through /sys/push. Soft, so a refused
::  road never fails the writer, and the audit note says which it was.
::
++  push-soft
  |=  [a=action:orr id=@ta]
  =/  m  (fiber:fiber:nexus ,~)
  ^-  form:m
  ;<  eny=@uvJ  bind:m  get-entropy:io
  =/  title=@t  ?:(=(%approved status.a) 'Orrery filed' 'Orrery proposes')
  =/  tag=@t  (cat 3 'orrery-' id)
  ;<  err=(unit tang)  bind:m
    %+  poke-soft:io  push-road:io
    [[/ %push-action] `push-action:nexus`[%send [~ ~ ~ [title title.a ~ `'/apps/orrery' `tag]] eny]]
  =/  sent=?  ?=(~ err)
  ;<  ~  bind:m  (note-by 'push' sent ?:(sent title.a 'push refused') by.a)
  (pure:m ~)
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
++  do-set-doc
  |=  [name=@ta op=@t jon=json]
  =/  m  (fiber:fiber:nexus ,?)
  ^-  form:m
  =/  doc=json  (gj:orr jon 'doc')
  ?.  ?=([%o *] doc)  (refuse op 'doc: an object is required')
  ;<  cur=json  bind:m  (read-json (rf 0 / name))
  ?:  =(cur doc)  (note-then-no op 'unchanged')
  ;<  ~  bind:m  (over:io (rf 0 / name) [[/ %json] doc])
  ;<  ~  bind:m  (note op & '')
  (pure:m &)
::  +compact: cull a body's observations that are superseded, expired
::  or retracted and older than the retention. A live one never goes.
::
::    A row ages by the later of when it became true and when the ship
::    recorded it, so a fact learned today about five years ago is kept
::    for the retention from today, not culled the moment it is
::    superseded.
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
    ?:  (gte (max at.obs.r seen.obs.r) horizon)  ~
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
  ;<  all0=(list loaded:orr)  bind:m  (load-bodies 1)
  ;<  acts0=(list [id=@ta a=action:orr])  bind:m  (load-actions 1)
  =/  seen  (view-of act all0 acts0 (hidden-for act policy))
  =/  all=(list loaded:orr)  all.seen
  =/  acts=(list [id=@ta a=action:orr])  acts.seen
  =/  mine=(unit loaded:orr)  (find-loaded all id)
  ?~  mine  (send-err eyre-id 404 'no such body')
  =/  multi=(set @t)  (multi-of:orr schema)
  (send-json eyre-id 200 (body-json:orr u.mine (situations:orr all multi u.when) acts multi u.when))
++  serve-delete-body
  |=  [eyre-id=@ta kind=@ta slug=@ta]
  =/  m  (fiber:fiber:nexus ,~)
  ^-  form:m
  =/  id=bid:orr  (rap 3 kind '/' slug ~)
  =/  pk  (parse-bid:orr id)
  ?~  pk  (send-err eyre-id 400 'expected <kind>/<slug>')
  ;<  ex=?  bind:m  (peek-exists:io (rv 1 /bodies/[kind]/[slug]))
  ?.  ex  (send-err eyre-id 404 'no such body')
  =/  op=json  (pairs:enjs:format ~[['op' s+'delete-body'] ['id' s+id]])
  ;<  err=(unit tang)  bind:m  (poke-soft:io (rf 1 / %'main.sig') [[/ %json] op])
  ?^  err  (send-err eyre-id 500 'the writer refused the poke')
  ;<  ~  bind:m  (drop-share kind.u.pk slug.u.pk id)
  (send-json eyre-id 200 (pairs:enjs:format ~[['id' s+id] ['ok' b+&]]))
::  +drop-share: a deleted body is shared with nobody. The record goes
::  and the group is rewritten with no ships, so the peek grant that
::  outlives the body goes with it.
::
++  drop-share
  |=  [kind=@tas slug=@ta id=bid:orr]
  =/  m  (fiber:fiber:nexus ,~)
  ^-  form:m
  ;<  shares=json  bind:m  (read-json (rf 1 / %'shares.json'))
  =/  all=(map @t json)  ?:(?=([%o *] shares) p.shares ~)
  ?.  (~(has by all) id)  (pure:m ~)
  ;<  ~  bind:m  (over:io (rf 1 / %'shares.json') [[/ %json] [%o (~(del by all) id)]])
  ;<  base=(unit path)  bind:m  self-base
  ?~  base
    (note-inbox-at 1 'delete-body' | 'cannot find where this app is installed' '')
  (set-share-group u.base kind slug ~)
++  serve-resolve
  |=  [eyre-id=@ta args=quay:eyre act=actor]
  =/  m  (fiber:fiber:nexus ,~)
  ^-  form:m
  =/  q=@t  (fall (get-key:kv:html-utils 'q' args) '')
  ;<  all0=(list loaded:orr)  bind:m  (load-bodies 1)
  =/  all=(list loaded:orr)  all:(view-of act all0 ~ ~)
  =/  bodies=(list [id=bid:orr =body:orr])  (turn all |=(l=loaded:orr [id.l body.l]))
  %^  send-json  eyre-id  200
  :-  %a
  %+  turn  (resolve:orr q bodies)
  |=  [id=bid:orr =body:orr match=@tas]
  ^-  json
  (pairs:enjs:format ~[['id' s+id] ['kind' s+kind.body] ['name' s+name.body] ['match' s+match]])
++  serve-retract
  |=  [eyre-id=@ta jon=json act=actor]
  =/  m  (fiber:fiber:nexus ,~)
  ^-  form:m
  =/  id=@t  (gs:orr jon 'id')
  ?:  =('' id)  (send-err eyre-id 400 'id: required')
  =/  why=@t  (gs:orr jon 'note')
  ?:  (gth (met 3 why) max-note:orr)  (send-err eyre-id 400 'note: over 500 bytes')
  ;<  hit=(unit [kind=@tas slug=@ta r=row:orr])  bind:m  (find-obs 1 `@ta`id)
  ?~  hit  (send-err eyre-id 404 'no such observation')
  ;<  policy=json  bind:m  (read-json (rf 1 / %'policy.json'))
  ::  a row whose value points at a body outside the key's kinds is
  ::  veiled on every view: retracting its real id would confirm the
  ::  hidden body the veil refuses to name
  =/  ref-ok=?
    ?~  scope.act  &
    =/  target=(unit bid:orr)  (ref-of:orr value.obs.r.u.hit)
    ?~  target  &
    =/  tk  (parse-bid:orr u.target)
    ?~  tk  &
    (kind-in-scope:orr u.scope.act kind.u.tk)
  =/  visible=?
    ?~  scope.act  &
    ?&  (kind-in-scope:orr u.scope.act kind.u.hit)
        !(~(has in (hidden-for act policy)) attr.obs.r.u.hit)
        ref-ok
    ==
  ?.  visible  (send-err eyre-id 404 'no such observation')
  ?:  &(?=(^ scope.act) !write.u.scope.act)  (send-err eyre-id 403 'read only key')
  =/  who=@t  ?:(owner.act ?:(=('' (gs:orr jon 'by')) 'http' (gs:orr jon 'by')) by.act)
  =/  op=json
    (pairs:enjs:format ~[['op' s+'retract'] ['id' s+id] ['note' s+why] ['by' s+who]])
  ;<  err=(unit tang)  bind:m  (poke-soft:io (rf 1 / %'main.sig') [[/ %json] op])
  ?^  err  (send-err eyre-id 500 'the writer refused the poke')
  (send-json eyre-id 200 (pairs:enjs:format ~[['id' s+id] ['ok' b+&]]))
++  serve-bodies
  |=  [eyre-id=@ta jon=json act=actor]
  =/  m  (fiber:fiber:nexus ,~)
  ^-  form:m
  ;<  now=@da  bind:m  get-time:io
  =/  got  (de-body:orr jon now)
  ?:  ?=(%| -.got)  (send-err eyre-id 400 p.got)
  =/  pk  (parse-bid:orr id.p.got)
  ?~  pk  (send-err eyre-id 400 'id: bad')
  =/  denied=(unit @t)  (deny-write act kind.u.pk)
  ?^  denied  (send-err eyre-id 403 u.denied)
  ::  identity is the owner's to assign: a key never sends a ship
  ?:  &(?=(^ scope.act) ?=(^ (gj:orr jon 'ship')))
    (send-err eyre-id 403 'not in scope: ship')
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
  |=  [eyre-id=@ta jon=json act=actor]
  =/  m  (fiber:fiber:nexus ,~)
  ^-  form:m
  ;<  now=@da  bind:m  get-time:io
  =/  stamped=json  ?:(owner.act (fill-act:orr jon now 'http') (fill-act-as:orr jon now by.act))
  =/  got  (de-action:orr stamped now by.act)
  ?:  ?=(%| -.got)  (send-err eyre-id 400 p.got)
  ::  403 here: the key sent the kind itself; a stored id it may not see is a 404
  ?:  &(?=(^ scope.act) !(action-in-scope:orr u.scope.act kind.p.got))
    (send-err eyre-id 403 (cat 3 'not in scope: ' kind.p.got))
  =/  outside=(unit bid:orr)
    ?~  scope.act  ~
    =/  s=scope:orr  u.scope.act
    %+  roll  ~(tap in about.p.got)
    |=  [b=bid:orr acc=(unit bid:orr)]
    ^-  (unit bid:orr)
    ?^  acc  acc
    =/  pk  (parse-bid:orr b)
    ?~  pk  ~
    ?:((kind-in-scope:orr s kind.u.pk) ~ `b)
  ?^  outside  (send-err eyre-id 400 (cat 3 'about: no such body ' u.outside))
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
  |=  [eyre-id=@ta args=quay:eyre act=actor]
  =/  m  (fiber:fiber:nexus ,~)
  ^-  form:m
  =/  want=@t  (fall (get-key:kv:html-utils 'status' args) 'open')
  ;<  all0=(list [id=@ta a=action:orr])  bind:m  (load-actions 1)
  =/  all=(list [id=@ta a=action:orr])  acts:(view-of act ~ all0 ~)
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
  |=  [eyre-id=@ta id=@ta jon=json act=actor]
  =/  m  (fiber:fiber:nexus ,~)
  ^-  form:m
  ?.  ?=([%o *] jon)  (send-err eyre-id 400 'expected an object')
  =/  want=@t  (gs:orr jon 'status')
  =/  why=@t  (gs:orr jon 'note')
  ?:  (gth (met 3 why) max-note:orr)  (send-err eyre-id 400 'note: over 500 bytes')
  ;<  cur=view:nexus  bind:m  (peek:io (rf 1 /actions id) ~)
  ?.  ?=([%file *] cur)  (send-err eyre-id 404 'no such action')
  =/  a=(unit action:orr)  (read-action:orr (sang-noun:tarball sang.cur))
  ?~  a  (send-err eyre-id 500 'unreadable action')
  ?:  &(?=(^ scope.act) !(action-in-scope:orr u.scope.act kind.u.a))
    (send-err eyre-id 404 'no such action')
  ?:  &(?=(^ scope.act) !write.u.scope.act)  (send-err eyre-id 403 'read only key')
  ?.  (transition-ok:orr status.u.a `@tas`want)
    (send-err eyre-id 409 (rap 3 'cannot go from ' status.u.a ' to ' want ~))
  =/  op=json
    %-  pairs:enjs:format
    ~[['op' s+'set-action'] ['id' s+id] ['status' s+want] ['note' s+why] ['by' s+?:(owner.act (gs:orr jon 'by') by.act)]]
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
::  ==  sharing: where things are
::
++  orrery-instance  `path`/apps/'shell.shell'/desks/'orrery.desk'/desk/data/'orrery.orrery_app'
::  +ug-base: where this ship keeps its usergroups
::
++  ug-base     `path`/sys/ames/usergroups
::  +public-grp: the group every ship is in, whose weir carries the road
::  to our inbox
::
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
::  +ug-read-weir: a usergroup's how, read whole, the way calendar reads
::  its share groups
::
++  ug-read-weir
  |=  gdir=path
  =/  m  (fiber:fiber:nexus ,weir:nexus)
  ^-  form:m
  ;<  hv=(unit view:nexus)  bind:m  (peek-soft:io [%& %& gdir %'how.weir'] ~)
  ?~  hv  (pure:m *weir:nexus)
  ?.  ?=([%file *] u.hv)  (pure:m *weir:nexus)
  (pure:m (fall (mole |.(;;(weir:nexus (sang-noun:tarball sang.u.hv)))) *weir:nexus))
::  +ug-set: a usergroup's who and how, written whole: the ships in it
::  and the roads they reach through it
::
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
::  timed out (a peer that is down must not park the fiber). A timer
::  wake answers yes: grubbery's remote acks are unobservable and the
::  poke usually landed. A veto or a nack answers no.
::
++  remote-poke-wait
  |=  [target=@p =lane:tarball jon=json]
  =/  m  (fiber:fiber:nexus ,?)
  ^-  form:m
  ;<  now=@da  bind:m  get-time:io
  ;<  tw=wire  bind:m  (nonce:io /remote)
  =/  req=load:remo:nexus  [[/share-poke lane] %poke [[/ %json] jon]]
  ;<  w=wire  bind:m  (nonce:io /share-poke)
  ;<  ~  bind:m
    %-  send-dart:io
    [%node w &+&+[/sys/gall %'main.sig'] %poke [[/ %gall-poke] [[target %grubbery] grubbery-load+req]]]
  ;<  ~  bind:m  (set-timer:io tw (add now ~s30))
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
        ?.(=(tw !<(path q.sage.u.in)) [%skip ~] [%done %.y])
      ?.  =([/ %poke-ack] p.sage.u.in)  [%skip ~]
      =/  [aw=wire err=(unit tang)]  !<([wire (unit tang)] q.sage.u.in)
      ?.  =(w aw)  [%skip ~]
      [%done ?=(~ err)]
    ==
  ;<  ~  bind:m  (cancel-timer:io tw)
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
  ;<  tw=wire  bind:m  (nonce:io /remote)
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
  ;<  ~  bind:m  (set-timer:io tw until)
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
      ?.(=(tw !<(path q.sage.u.in)) [%skip ~] [%done ~])
    ==
  ;<  ~  bind:m  (cancel-timer:io tw)
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
    (note-inbox 'inbox' | 'id: expected <kind>/<slug>' (scot %p src))
  =/  key=@t  (share-key:orr src id)
  ?:  =('offer' act)  (take-offer src key id jon)
  ?:  =('revoke' act)  (take-revoke src key)
  ?:  =('observe' act)  (take-edit src id jon)
  (note-inbox 'inbox' | 'unknown action' (scot %p src))
::  +take-offer: a host offers a body. An offer for a share already
::  accepted narrows its mode in place; a wider one waits for an accept.
::
++  take-offer
  |=  [src=@p key=@t id=bid:orr jon=json]
  =/  m  (fiber:fiber:nexus ,~)
  ^-  form:m
  ;<  now=@da  bind:m  get-time:io
  =/  mode=@t  ?:(=('edit' (gs:orr jon 'mode')) 'edit' 'read')
  =/  oship=@t  (gs:orr jon 'ship')
  ?:  &(!=('' oship) ?=(~ (slaw %p oship)))  (note-inbox 'offer' | 'ship: expected an @p' (scot %p src))
  ?:  (gth (met 3 (gs:orr jon 'name')) max-name:orr)  (note-inbox 'offer' | 'name: over 200 bytes' (scot %p src))
  ?:  (gth (met 3 (gs:orr jon 'base')) 200)  (note-inbox 'offer' | 'base: over 200 bytes' (scot %p src))
  ;<  rows=json  bind:m  (read-json (rf 0 / %'ship-remotes.json'))
  =/  rm=(map @t json)  ?:(?=([%o *] rows) p.rows ~)
  ?:  (~(has by rm) key)
    =/  row=json  (fall (~(get by rm) key) ~)
    ?.  ?=([%o *] row)  (note-inbox 'offer' | 'accepted row unreadable' (scot %p src))
    ::  a share we accepted: a narrower mode applies at once, a wider
    ::  one is a new offer, since it would change what we send the host
    ?:  &(=('edit' mode) !=('edit' (gs:orr row 'mode')))
      (file-offer src key id mode now jon)
    =/  next=json  [%o (~(put by p.row) 'mode' s+mode)]
    ;<  ~  bind:m  (over:io (rf 0 / %'ship-remotes.json') [[/ %json] [%o (~(put by rm) key next)]])
    ::  a wider offer filed earlier goes with the narrowing, so it can
    ::  no longer be accepted after the host changed its mind
    ;<  offers=json  bind:m  (read-json (rf 0 / %'share-offers.json'))
    =/  cur=(map @t json)  ?:(?=([%o *] offers) p.offers ~)
    ;<  ~  bind:m
      ?.  (~(has by cur) key)  (pure:(fiber:fiber:nexus ,~) ~)
      (over:io (rf 0 / %'share-offers.json') [[/ %json] [%o (~(del by cur) key)]])
    (note-inbox 'offer' & 'mode updated' (scot %p src))
  (file-offer src key id mode now jon)
::  +file-offer: the offer waits in share-offers.json for an accept
::
++  file-offer
  |=  [src=@p key=@t id=bid:orr mode=@t now=@da jon=json]
  =/  m  (fiber:fiber:nexus ,~)
  ^-  form:m
  ;<  offers=json  bind:m  (read-json (rf 0 / %'share-offers.json'))
  =/  cur=(map @t json)  ?:(?=([%o *] offers) p.offers ~)
  ::  a full inbox drops new offers; 200 is far past what a person gets
  ?:  &((gte ~(wyt by cur) 200) !(~(has by cur) key))
    (note-inbox 'offer' | 'inbox full' (scot %p src))
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
  (note-inbox 'offer' & key (scot %p src))
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
  (note-inbox 'revoke' & key (scot %p src))
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
  ?.  =('edit' mode)  (note-inbox 'edit' | 'not shared in edit mode' (scot %p src))
  ::  the body may have been deleted since the share was recorded
  =/  pk  (parse-bid:orr id)
  ?~  pk  (note-inbox 'edit' | 'no such body here' (scot %p src))
  ;<  here=?  bind:m  (peek-exists:io (rf 0 (body-dir kind.u.pk slug.u.pk) %body))
  ?.  here  (note-inbox 'edit' | 'no such body here' (scot %p src))
  =/  got=(list json)  (ga:orr jon 'observations')
  ?:  (gth (lent got) max-obs:orr)  (note-inbox 'edit' | 'observations: over 200' (scot %p src))
  =/  rows=(list json)
    %+  skim  got
    |=(j=json &(?=([%o *] j) =(id (gs:orr j 'subject'))))
  ?~  rows  (note-inbox 'edit' | 'nothing about the shared body' (scot %p src))
  ;<  r=[pokes=@ud refused=(list [oid=@t why=@t])]  bind:m
    (apply-carried 0 src `(list json)`rows)
  =/  bad=(list [oid=@t why=@t])  refused.r
  =/  head=@t
    (rap 3 (scot %ud (lent rows)) ' rows, ' (scot %ud pokes.r) ' pokes' ~)
  =/  why=@t
    ?~  bad  head
    (rap 3 head ', ' (scot %ud (lent bad)) ' refused: ' why.i.bad ~)
  (note-inbox 'edit' & why (scot %p src))
::  ==  carried rows: what another ship sent, or what we read from it
::
::  +apply-carried: rows from one ship about one of our bodies (the
::  subject is ours already). A row we do not hold becomes an
::  observation from that ship, through the writer; a row we hold that
::  the ship retracted since is retracted here. Every received row is
::  decoded here first, so a row the writer would refuse is answered
::  instead of vanishing. Answers the writer pokes and the refusals.
::
++  apply-carried
  |=  [up=@ud src=@p rows=(list json)]
  =/  m  (fiber:fiber:nexus ,[pokes=@ud refused=(list [oid=@t why=@t])])
  ^-  form:m
  ?~  rows  (pure:m [0 ~])
  =/  subject=bid:orr  (gs:orr i.rows 'subject')
  =/  pk  (parse-bid:orr subject)
  ?~  pk  (pure:m [0 ~])
  ;<  vw=view:nexus  bind:m  (peek:io (rv up (body-dir kind.u.pk slug.u.pk)) ~)
  ?.  ?=([%ball *] vw)  (pure:m [0 ~])
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
  ;<  now=@da  bind:m  get-time:io
  =/  received=(list [oid=@t j=json])
    %+  murn  all
    |=  j=json
    ^-  (unit [@t json])
    ?.  =(subject (gs:orr j 'subject'))  ~
    ?:  (~(has by held) (gs:orr j 'oid'))  ~
    ?:  =(`json`b+& (gj:orr j 'retracted'))  ~
    `[(gs:orr j 'oid') (receive-obs:orr src j)]
  =/  split=[ok=(list json) bad=(list [oid=@t why=@t])]
    %+  roll  received
    |=  [[oid=@t j=json] acc=[ok=(list json) bad=(list [oid=@t why=@t])]]
    =/  d  (de-obs:orr j now (scot %p src))
    ?:  ?=(%& -.d)  acc(ok [j ok.acc])
    acc(bad [[oid p.d] bad.acc])
  =/  fresh=(list json)  (flop ok.split)
  =/  gone=(list @ta)
    %+  murn  all
    |=  j=json
    ^-  (unit @ta)
    ?.  =(subject (gs:orr j 'subject'))  ~
    =/  h=(unit [oid=@ta retracted=?])  (~(get by held) (gs:orr j 'oid'))
    ?~  h  ~
    ?.  &(=(`json`b+& (gj:orr j 'retracted')) !retracted.u.h)  ~
    `oid.u.h
  ;<  ~  bind:m  (observe-fresh up fresh)
  ;<  ~  bind:m  (retract-each up src (scag max-obs:orr gone))
  (pure:m [(add ?~(fresh 0 1) (lent gone)) (flop bad.split)])
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
      ['via' s+'ship']
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
    %+  poke-writer  up
    %-  pairs:enjs:format
    :~  ['op' s+'retract']
        ['via' s+'ship']
        ['id' s+i.oids]
        ['note' s+why]
        ['by' s+(scot %p src)]
    ==
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
  ::  the grant goes first: a crash between the two leaves a record
  ::  claiming a share that cannot be read, never a grant with no record
  ;<  ~  bind:m  (set-share-group u.base kind.u.pk slug.u.pk mine)
  ;<  ~  bind:m
    (over:io (rf 1 / %'shares.json') [[/ %json] [%o ?:(=(~ mine) (~(del by all) id) (~(put by all) id [%o mine]))]])
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
::  a local body that already carries the offered ship, else where
::  +mirror-target puts it; the body is laid through the writer only
::  when the target is absent, so an accept never renames or re-ships a
::  body of ours. The row is written and the follower prodded.
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
  ::  a ship is an identity: a local body already carrying the offered
  ::  ship is the body the offer is about, whatever either side calls it
  ;<  all=(list loaded:orr)  bind:m  (load-bodies 1)
  =/  same-ship=(unit bid:orr)
    ?~  oship  ~
    =/  hits=(list loaded:orr)  (skim all |=(l=loaded:orr =(oship ship.body.l)))
    ?~(hits ~ `id.i.hits)
  =/  target=bid:orr  (fall same-ship (mirror-target:orr our u.host oship id))
  =/  tpk  (parse-bid:orr target)
  ?~  tpk  (send-err eyre-id 400 'id: bad')
  ::  person/me counts as existing the way +first-missing counts it: the
  ::  request queued +ensure-me ahead of this, and an upsert would
  ::  rename our own self to whatever the host calls us
  ;<  ex=?  bind:m  (peek-exists:io (rf 1 (body-dir kind.u.tpk slug.u.tpk) %body))
  ;<  ~  bind:m
    ?:  |(ex =('person/me' target))  (pure:(fiber:fiber:nexus ,~) ~)
    %+  poke-writer  1
    %-  pairs:enjs:format
    :~  ['op' s+'upsert-body']
        :-  'body'
        %-  pairs:enjs:format
        :~  ['id' s+target]
            ['name' s+(gs:orr u.offer 'name')]
            ['ship' `json`?~(oship ~ s+(scot %p u.oship))]
        ==
    ==
  ;<  rows=json  bind:m  (read-json (rf 1 / %'ship-remotes.json'))
  =/  rm=(map @t json)  ?:(?=([%o *] rows) p.rows ~)
  =/  old=json  (fall (~(get by rm) key) [%o ~])
  ::  what we already pushed counts only if we were pushing: a row that
  ::  was read mode until now has sent the host nothing
  =/  kept=json
    ?.  =('edit' (gs:orr old 'mode'))  [%o ~]
    =/(p (gj:orr old 'pushed') ?:(?=([%o *] p) p [%o ~]))
  =/  row=json
    %-  pairs:enjs:format
    :~  ['host' s+(scot %p u.host)]
        ['id' s+id]
        ['target' s+target]
        ['mode' s+(gs:orr u.offer 'mode')]
        ['base' s+(gs:orr u.offer 'base')]
        ['pushed' kept]
        ['last' s+'']
        ['error' s+'']
    ==
  ;<  ~  bind:m  (over:io (rf 1 / %'ship-remotes.json') [[/ %json] [%o (~(put by rm) key row)]])
  ;<  ~  bind:m  (over:io (rf 1 / %'share-offers.json') [[/ %json] [%o (~(del by cur) key)]])
  ;<  *  bind:m  (poke-soft:io (rf 1 / %'sync.sig') [[/ %sig] ~])
  (send-json eyre-id 200 (pairs:enjs:format ~[['ok' b+&] ['target' s+target]]))
::  +serve-decline: an offer we do not want leaves the inbox. Nothing is
::  told to the host: an offer is not a claim on us
::
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
::  +serve-sync: prod the follower to make a pass now
::
++  serve-sync
  |=  eyre-id=@ta
  =/  m  (fiber:fiber:nexus ,~)
  ^-  form:m
  ;<  *  bind:m  (poke-soft:io (rf 1 / %'sync.sig') [[/ %sig] ~])
  (send-json eyre-id 200 (pairs:enjs:format ~[['ok' b+&]]))
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
      =/  live=(unit json)  (~(get by acc) key)
      ?~  live  acc
      ?.  &(?=([%o *] u.live) ?=([%o *] row))  acc
      =/  keep=(list [@t json])
        :~  ['last' (gj:orr row 'last')]
            ['error' (gj:orr row 'error')]
            ['pushed' (gj:orr row 'pushed')]
            ['refused' (gj:orr row 'refused')]
        ==
      (~(put by acc) key [%o (~(gas by p.u.live) keep)])
    (over:io (rf 0 / %'ship-remotes.json') [[/ %json] [%o merged]])
  ;<  next=json  bind:m  (sync-one row.i.rows)
  (sync-rows t.rows (~(put by done) key.i.rows next))
::  +sync-one: one accepted share, answering the row with last, error,
::  pushed and refused brought up to date. A row the host holds that our
::  decoder will not take is noted in /tr/inbox once, not every pass.
::
++  sync-one
  |=  row=json
  =/  m  (fiber:fiber:nexus ,json)
  ^-  form:m
  ?.  ?=([%o *] row)  (pure:m row)
  ;<  now=@da  bind:m  get-time:io
  ;<  policy=json  bind:m  (read-json (rf 0 / %'policy.json'))
  =/  hide=(set @t)  (sensitive-of:orr policy)
  =/  host=(unit @p)  (slaw %p (gs:orr row 'host'))
  ?~  host  (pure:m [%o (~(put by p.row) 'error' s+'host: expected an @p')])
  =/  id=bid:orr  (gs:orr row 'id')
  =/  target=bid:orr  (gs:orr row 'target')
  =/  base=path  (fall (mole |.((stab (gs:orr row 'base')))) orrery-instance)
  ;<  mir=[err=(unit @t) refused=(list [oid=@t why=@t])]  bind:m
    (mirror-pass u.host id target base)
  =/  err=(unit @t)  err.mir
  =/  bad=(list [oid=@t why=@t])  refused.mir
  ::  a refusal is noted once: the same host row is refused every pass
  ::  the key is a peer's text, capped at 64 bytes the way the notes are
  =/  seen=(map @t json)  =/(p (gj:orr row 'refused') ?:(?=([%o *] p) p.p ~))
  ;<  ~  bind:m
    %^  note-refusals  'mirror'  (scot %p u.host)
    (skim bad |=([o=@t *] !(~(has by seen) (end [3 64] o))))
  =/  all-ref=(map @t json)
    (~(gas by seen) (turn bad |=([o=@t w=@t] [(end [3 64] o) `json`s+w])))
  =/  refused=(map @t json)
    ?:  (lte ~(wyt by all-ref) max-obs:orr)  all-ref
    (~(gas by *(map @t json)) (scag max-obs:orr ~(tap by all-ref)))
  =/  pushed=(map @t json)  =/(p (gj:orr row 'pushed') ?:(?=([%o *] p) p.p ~))
  ::  only an untroubled read earns a push: a transport ack from a host
  ::  that refused the rows must not count them as landed
  =/  run=?  &(?=(~ err) =('edit' (gs:orr row 'mode')))
  ;<  push=[ok=? pushed=(map @t json)]  bind:m
    (push-pass u.host id target base pushed run hide)
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
      ['refused' [%o refused]]
  ==
::  +mirror-pass: the host's body directory, read whole; its own rows
::  (not ones it mirrored from elsewhere: one hop) land here as
::  observations from the host, through +apply-carried. The error for
::  the row, ~ when fine, and the host rows our decoder would not take.
::
++  mirror-pass
  |=  [host=@p id=bid:orr target=bid:orr base=path]
  =/  m  (fiber:fiber:nexus ,[err=(unit @t) refused=(list [oid=@t why=@t])])
  ^-  form:m
  =/  pk  (parse-bid:orr id)
  ?~  pk  (pure:m [[~ 'id: expected <kind>/<slug>'] ~])
  ::  a body deleted here takes its mirror with it: +apply-carried would
  ::  answer no pokes and no refusals, which reads as a clean pass
  =/  tpk  (parse-bid:orr target)
  ?~  tpk  (pure:m [[~ 'target: expected <kind>/<slug>'] ~])
  ;<  here=?  bind:m  (peek-exists:io (rf 0 (body-dir kind.u.tpk slug.u.tpk) %body))
  ?.  here
    (pure:m [[~ 'the shared body does not exist here any more'] ~])
  ;<  vw=(unit view:nexus)  bind:m
    (peek-remote-wait host [%& %| (weld base (body-dir kind.u.pk slug.u.pk))])
  ?~  vw
    (pure:m [[~ 'the host did not answer (down, or the share was revoked)'] ~])
  ?.  ?=([%ball *] u.vw)
    (pure:m [[~ 'the host no longer shares this body'] ~])
  =/  rows=(list row:orr)  (skim (rows-in ball.u.vw) |=(r=row:orr (is-local:orr obs.r)))
  ;<  got=[pokes=@ud refused=(list [oid=@t why=@t])]  bind:m
    (apply-carried 0 host (turn rows |=(r=row:orr (carry-obs:orr target r))))
  (pure:m [~ refused.got])
::  +push-pass: in edit mode, our own rows on the target body that the
::  host has not taken yet (or whose retraction it has not), sent to its
::  inbox. pushed maps our grub name to the retracted flag it holds.
::
::    An attribute named in policy.sensitive is never pushed. The read
::    grant cannot filter by attribute, so a body with facts the owner
::    would not share is not a body to share (docs/sharing.md); this
::    stops the one direction that can be filtered.
::
++  push-pass
  |=  $:  host=@p
          id=bid:orr
          target=bid:orr
          base=path
          pushed=(map @t json)
          run=?
          hide=(set @t)
      ==
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
    ?:  (~(has in hide) attr.obs.r)  |
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
::  +serve-drop-client: a key revoked by id
::
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
::  hidden attributes dropped, and the actions in its action kinds. A
::  value that refs a body outside the kinds reads as cleared on a row
::  with a synthetic id, and an about naming one is trimmed away: a key
::  never learns such a body exists. The owner sees everything.
::
++  view-of
  |=  [act=actor all=(list loaded:orr) acts=(list [id=@ta a=action:orr]) hide=(set @t)]
  ^-  [all=(list loaded:orr) acts=(list [id=@ta a=action:orr])]
  ?~  scope.act  [all acts]
  =/  s=scope:orr  u.scope.act
  :-  %+  murn  all
      |=  l=loaded:orr
      ^-  (unit loaded:orr)
      ?.  (kind-in-scope:orr s kind.body.l)  ~
      `l(rows (veil-refs:orr (drop-attrs:orr rows.l hide) kinds.s))
  %+  turn  (skim acts |=([* a=action:orr] (action-in-scope:orr s kind.a)))
  |=([id=@ta a=action:orr] [id (scope-about:orr a kinds.s)])
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
--
