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
::  +act-id: "<unix seconds of proposed>-<hex8>", an observation id's
::  shape over a proposal
::
::    The hash covers kind, title, payload and by, and must ignore
::    status and history. The request fiber hashes an action it decoded
::    itself, while the writer's copy may already carry the policy's
::    approval step, and the two ids have to agree.
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
::  +de-body: {"id","name","aliases","ship"}. A name '' means "not
::  given"; a ship names the body's own urbit.
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
  =/  sj=json  (gj jon 'ship')
  =/  ship=(unit @p)  ?:(?=([%s *] sj) (slaw %p p.sj) ~)
  ?:  &(?=([%s *] sj) ?=(~ ship))  [%| 'ship: expected an @p such as ~sampel-palnet']
  [%& id [kind.u.pk name (sy als) now ship]]
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
  ?:  &(?=([%o *] value) =(subject (gs value 'ref')))
    [%| 'value.ref: a body cannot refer to itself']
  =/  at=(unit @da)  ?.((has-key jon 'at') `now (gt jon 'at'))
  ?~  at  [%| 'at: expected an ISO 8601 UTC time such as 2026-09-16T22:05:00Z']
  =/  until=(unit @da)  (gt jon 'until')
  ?:  &(?=(~ until) !=(~ (gj jon 'until')))
    [%| 'until: expected an ISO 8601 UTC time, or null']
  ?:  ?&(?=(^ until) (lte u.until u.at))  [%| 'until: must be after at']
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
  [%& `@tas`kind title payload (sy about) due by u.proposed %proposed '' ~[[u.proposed %proposed by]]]
::  +with-default: set a key on an object only when it is absent
::
++  with-default
  |=  [j=json k=@t v=json]
  ^-  json
  ?.  ?=([%o *] j)  j
  ?:  (~(has by p.j) k)  j
  [%o (~(put by p.j) k v)]
::  +with-string: set a key on an object unless it already holds a
::  non-empty string
::
::    An explicit "" or a non-string would otherwise survive to both
::    decoders, where each falls back to its own default and the two
::    compute different ids. A string over the cap is left alone, so
::    the decoder still refuses it by name.
::
++  with-string
  |=  [j=json k=@t v=json]
  ^-  json
  ?.  ?=([%o *] j)  j
  =/  cur=json  (fall (~(get by p.j) k) ~)
  ?:  ?&(?=([%s *] cur) !=('' p.cur))  j
  [%o (~(put by p.j) k v)]
::  +fill-obs, +fill-act: stamp at (or proposed) and by into a request
::  before it goes to the writer, so the id a caller reports and the id
::  the writer makes agree
::
++  fill-obs
  |=  [j=json now=@da by=@t]
  ^-  json
  (with-string (with-default j 'at' s+(en-iso now)) 'by' s+by)
++  fill-act
  |=  [j=json now=@da by=@t]
  ^-  json
  (with-string (with-default j 'proposed' s+(en-iso now)) 'by' s+by)
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
  =/  r2  (mule |.(;;(stored-body n)))
  ?:  ?=(%& -.r2)  `body.p.r2
  =/  r1  (mule |.(;;(stored-body-1 n)))
  ?.  ?=(%& -.r1)  ~
  =/  b=body-1  body-1.p.r1
  `[kind.b name.b aliases.b created.b ~]
++  read-obs
  |=  n=*
  ^-  (unit obs)
  =/  r  (mule |.(;;(stored-obs n)))
  ?:(?=(%& -.r) `obs.p.r ~)
++  read-action
  |=  n=*
  ^-  (unit action)
  =/  r2  (mule |.(;;(stored-action n)))
  ?:  ?=(%& -.r2)  `action.p.r2
  =/  r1  (mule |.(;;(stored-action-1 n)))
  ?.  ?=(%& -.r1)  ~
  =/  a=action-1  action-1.p.r1
  `[kind.a title.a payload.a about.a due.a by.a proposed.a status.a note.a ~[[proposed.a status.a by.a]]]
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
      ?~(ship.new ship.old ship.new)
  ==
::  +fresh-name: a new body with no name is named after its slug
::
++  fresh-name
  |=  [slug=@ta name=@t]
  ^-  @t
  ?:(=('' name) `@t`slug name)
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
      ['ship' `json`?~(ship.b ~ s+(scot %p u.ship.b))]
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
::  +en-step: one step of an action's history as JSON
::
++  en-step
  |=  st=step
  ^-  json
  (pairs:enjs:format ~[['at' (en-time at.st)] ['status' s+status.st] ['by' s+by.st]])
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
      ['history' a+(turn history.a en-step)]
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
    =/  sh=@t  ?~(ship.b '' (scot %p u.ship.b))
    ?:  &(!=('' sh) =(sh lq))  `[id b %exact]
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
++  starter-policy
  ^-  json
  %-  pairs:enjs:format
  :~  ['auto' a+~[s+'task' s+'note']]
      ['push' s+'proposed']
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
::  ==  sharing (spec section 11)
::
::  +share-key: how a peer keys what one host sent it about one body
::
++  share-key
  |=  [host=@p id=bid]
  ^-  @t
  (rap 3 (scot %p host) '/' id ~)
::  +mirror-target: where a shared body lands on the peer when no local
::  body already carries its ship: our own person/me when the body's
::  ship is us; the host's own person/me becomes person/<host> here (a
::  ship's self is never our self); any other body keeps its id
::
++  mirror-target
  |=  [our=@p host=@p ship=(unit @p) id=bid]
  ^-  bid
  ?:  &(?=(^ ship) =(our u.ship))  'person/me'
  ?.  =('person/me' id)  id
  (rap 3 'person/' (rsh [3 1] (scot %p host)) ~)
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
--
