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
::    A day the month does not have is refused rather than rolled over:
::    +year turns 2026-02-30 into March, so the date is re-encoded and
::    compared with the ten characters the caller sent.
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
  =/  when=@da  (year [[& y] mo d h mi s ~])
  ?.  =((end [3 10] (en-iso when)) (end [3 10] t))  ~
  `when
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
::  +ship-source: an observation claiming a ship source. Only the inbox
::  sets that kind, from the transport; a local client that sent it
::  would be forging a ship's claim.
::
++  ship-source  |=(j=json ^-(? =('ship' (gs (gj j 'source') 'kind'))))
::  +mark-reserved: a decoded batch with each item whose source kind is
::  ship refused in place, so the answer keeps the caller's order while
::  the item itself never reaches the writer
::
++  mark-reserved
  |=  [raw=(list json) items=(list (each obs @t))]
  ^-  (list (each obs @t))
  ?~  items  ~
  ?~  raw  items
  :-  ?:((ship-source i.raw) [%| 'source.kind: reserved for the inbox'] i.items)
  $(raw t.raw, items t.items)
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
  ?|  =(value.obs.i.w [%s 'closed'])
      =(value.obs.i.w [%s 'cancelled'])
  ==
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
::  +tokens: a phrase as lowercase words, split on every byte that is
::  neither a letter nor a digit
::
++  tokens
  |=  t=@t
  ^-  (list @t)
  =/  st=[cur=tape acc=(list @t)]
    %+  roll  (trip (lower t))
    |=  [c=@tD s=[cur=tape acc=(list @t)]]
    ^-  [cur=tape acc=(list @t)]
    ?:  |(&((gte c 'a') (lte c 'z')) &((gte c '0') (lte c '9')))
      [[c cur.s] acc.s]
    ?:  =(~ cur.s)  s
    [~ [(crip (flop cur.s)) acc.s]]
  =/  out=(list @t)
    ?:(=(~ cur.st) acc.st [(crip (flop cur.st)) acc.st])
  (flop out)
::  +token-hit: the shorter side's tokens all appear in the longer
::  side's, and the shorter side has at least one token. "andrea" hits
::  "Andrea Egan" in both directions; "andrea" never hits "Andrew Egan".
::
++  token-hit
  |=  [a=(list @t) b=(list @t)]
  ^-  ?
  =/  flip=?  (gth (lent a) (lent b))
  =/  short=(list @t)  ?:(flip b a)
  =/  long=(list @t)   ?:(flip a b)
  ?~  short  |
  %+  levy  `(list @t)`short
  |=(x=@t (lien `(list @t)`long |=(y=@t =(x y))))
::  +identity-values: the live email and phone values of one body, as
::  lowercase strings. An identity is not spelling: a query equal to one
::  of these names the body exactly.
::
++  identity-values
  |=  winners=(map @t (list row))
  ^-  (list @t)
  =/  rs=(list row)
    %+  weld  (fall (~(get by winners) 'email') ~)
    (fall (~(get by winners) 'phone') ~)
  %+  turn
    %+  murn  rs
    |=(r=row ^-((unit @t) ?:(?=([%s *] value.obs.r) `p.value.obs.r ~)))
  lower
::  +resolve: bodies whose ship, name, alias, email or phone equals q,
::  then those whose name or alias shares every token with it, then
::  those where one starts with q, case-insensitive, at most 20
::
++  resolve
  |=  [q=@t bodies=(list [id=bid =body winners=(map @t (list row))])]
  ^-  (list [id=bid =body match=@tas])
  =/  lq=@t  (lower q)
  ?:  =('' lq)  ~
  =/  qt=(list @t)  (tokens q)
  =/  hit
    |=  [id=bid b=body winners=(map @t (list row))]
    ^-  (unit [id=bid =body match=@tas])
    =/  sh=@t  ?~(ship.b '' (scot %p u.ship.b))
    ?:  &(!=('' sh) =(sh lq))  `[id b %exact]
    =/  names=(list @t)  (turn `(list @t)`[name.b ~(tap in aliases.b)] lower)
    ?:  (lien names |=(n=@t =(n lq)))  `[id b %exact]
    ?:  (lien (identity-values winners) |=(v=@t =(v lq)))  `[id b %exact]
    ?:  (lien names |=(n=@t (token-hit qt (tokens n))))  `[id b %token]
    ?:  (lien names |=(n=@t =(lq (end [3 (met 3 lq)] n))))  `[id b %prefix]
    ~
  =/  hits=(list [id=bid =body match=@tas])  (murn bodies hit)
  =/  exact  (skim hits |=(h=[id=bid =body match=@tas] =(%exact match.h)))
  =/  toks   (skim hits |=(h=[id=bid =body match=@tas] =(%token match.h)))
  =/  pref   (skim hits |=(h=[id=bid =body match=@tas] =(%prefix match.h)))
  (scag 20 :(weld exact toks pref))
::  ==  merge: folding one body into another
::
::  +resubject: one observation row copied onto another body. Everything
::  but the subject stays, seen included (the copy is not a new fact),
::  and the id is recomputed from the new subject.
::
++  resubject
  |=  [r=row new=bid]
  ^-  row
  =/  o=obs  obs.r(subject new)
  [(obs-id o) o]
::  +repoint: a live row whose value named one body, re-pointed at
::  another: a fresh row beside the old one, seen now
::
++  repoint
  |=  [r=row into=bid now=@da]
  ^-  row
  =/  o=obs  obs.r
  =/  v=json  (pairs:enjs:format ~[['ref' s+into]])
  =/  next=obs  o(value v, seen now, retracted |, note '')
  [(obs-id next) next]
::  +absorb: into with from's aliases unioned in and from's name added
::  as an alias. The name, ship and created stamp stay into's.
::
++  absorb
  |=  [into=body from=body]
  ^-  body
  =/  als=(set @t)  (~(uni in aliases.into) aliases.from)
  =.  als  ?:(=('' name.from) als (~(put in als) name.from))
  into(aliases als)
::  +move-rows: from's rows re-subjected onto into, those into does not
::  already hold. A copy with an id already there is left as it is.
::
++  move-rows
  |=  [src=(list row) dst=(list row) into=bid]
  ^-  (list row)
  =/  held=(set @ta)  (sy (turn dst |=(r=row id.r)))
  %+  skim  (turn src |=(r=row (resubject r into)))
  |=(r=row !(~(has in held) id.r))
::  +ref-rows: every live row on any body but from whose value points at
::  from, each with the body that holds it
::
++  ref-rows
  |=  [all=(list loaded) from=bid when=@da]
  ^-  (list [id=bid r=row])
  %-  zing
  %+  turn  all
  |=  l=loaded
  ^-  (list [id=bid r=row])
  ?:  =(id.l from)  ~
  %+  turn
    %+  skim  rows.l
    |=  r=row
    ^-  ?
    ?.  (is-live obs.r when)  |
    =/  t=(unit bid)  (ref-of value.obs.r)
    ?~(t | =(u.t from))
  |=(r=row [id.l r])
::  ==  actions
::
++  is-open
  |=  a=action
  ^-  ?
  |(=(%proposed status.a) =(%approved status.a) =(%claimed status.a))
::  +transition-ok: proposed to approved or dismissed; approved to
::  claimed, done, failed or dismissed; claimed to done, failed,
::  dismissed or claimed again. Nothing leaves done, failed or dismissed.
::
++  transition-ok
  |=  [cur=@tas want=@tas]
  ^-  ?
  ?+  cur  |
    %proposed  |(=(%approved want) =(%dismissed want))
    %approved  |(=(%claimed want) =(%done want) =(%failed want) =(%dismissed want))
    %claimed   |(=(%claimed want) =(%done want) =(%failed want) =(%dismissed want))
  ==
::  +claim-lease: how long one actor's claim holds an action
::
++  claim-lease  ~m10
::  +claimant: the by of the last claimed step, '' when there is none
::
++  claimant
  |=  a=action
  ^-  @t
  =/  back=(list step)  (flop history.a)
  |-  ^-  @t
  ?~  back  ''
  ?:  =(%claimed status.i.back)  by.i.back
  $(back t.back)
::  +claimed-at: when the last claimed step was taken, or proposed when
::  there is none
::
++  claimed-at
  |=  a=action
  ^-  @da
  =/  back=(list step)  (flop history.a)
  |-  ^-  @da
  ?~  back  proposed.a
  ?:  =(%claimed status.i.back)  at.i.back
  $(back t.back)
::  +move-refusal: why this actor cannot move this action now, or ~.
::  The table first, then the claim: while the lease is live the action
::  is held against another actor, and done or failed is the claimant's
::  to report. A clock earlier than the claim is inside the lease.
::
++  move-refusal
  |=  [a=action want=@tas who=@t now=@da]
  ^-  (unit @t)
  ?.  (transition-ok status.a want)
    =/  no=@t  (rap 3 'cannot go from ' status.a ' to ' want ~)
    `no
  ?.  =(%claimed status.a)  ~
  =/  hold=@t  (claimant a)
  =/  at=@da  (claimed-at a)
  =/  live=?  |((lte now at) (lth (sub now at) claim-lease))
  =/  no=@t  (rap 3 'claimed by ' hold ~)
  ?:  =(%claimed want)  ?:(live `no ~)
  ?.  |(=(%done want) =(%failed want))  ~
  ?:(=(who hold) ~ `no)
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
      ['sensitive' a+~[s+'health' s+'income']]
  ==
++  starter-schema
  ^-  json
  =/  kind
    |=  [attrs=(list @t) notes=(list [@t @t])]
    ^-  json
    =/  names=json  a+(turn attrs |=(t=@t `json`s+t))
    ?~  notes  (pairs:enjs:format ~[['attrs' names]])
    =/  said=json  (pairs:enjs:format (turn `(list [@t @t])`notes |=([a=@t t=@t] [a `json`s+t])))
    (pairs:enjs:format ~[['attrs' names] ['notes' said]])
  %-  pairs:enjs:format
  :~  :-  'kinds'
      %-  pairs:enjs:format
      :~  :-  'person'
          %+  kind
            ~['status' 'location' 'phone' 'email' 'ship' 'birthday' 'relationship' 'employer' 'timezone' 'likes' 'dislikes' 'health' 'income']
          :~  ['status' 'what the person is doing or dealing with right now, in plain words, as an observer would put it: on jury duty, stranded waiting for a tow, travelling, sick; never a feeling, a quote or a wish']
              ['location' 'where the person is: a place body as a ref when the ship has one, else a short place name; null when they have left and the new place is unknown']
              ['relationship' 'how they relate to the owner: wife, son, boss, neighbour']
              ['health' 'a medical fact about the person; kept from client keys by policy']
              ['income' 'a money fact about the person; kept from client keys by policy']
          ==
          ['place' (kind ~['type' 'address' 'phone' 'hours' 'geo'] ~)]
          :-  'thing'
          %+  kind
            ~['type' 'status' 'location' 'owner' 'make' 'model' 'plate' 'last-service' 'warranty-until']
          :~  ['status' 'the state the thing is in right now: broken down, at the shop, shipped, delivered']
              ['location' 'where the thing is: a place body as a ref or a short place name; null when unknown']
          ==
          ['org' (kind ~['type' 'phone' 'email' 'website' 'contact' 'address'] ~)]
          :-  'situation'
          %+  kind
            ~['status' 'participants' 'location' 'starts' 'ends' 'started' 'ended' 'summary']
          :~  ['status' 'open or closed, or cancelled; nothing else. Whether it is upcoming, under way or over is read off starts, ends, started and ended']
              ['starts' 'when it is scheduled to begin, ISO 8601 UTC; may be in the future']
              ['ends' 'when it is scheduled to end, ISO 8601 UTC; may be in the future']
              ['started' 'when it actually began, ISO 8601 UTC, written once it has']
              ['ended' 'when it actually ended, ISO 8601 UTC, written once it has']
              ['participants' 'one observation per body involved, each a ref']
          ==
          :-  'activity'
          %+  kind
            ~['status' 'schedule' 'cadence' 'location' 'participants' 'organizer' 'last' 'next']
          :~  ['last' 'the start of the most recent occurrence, ISO 8601 UTC, with at set to that start']
              ['next' 'the start of the nearest upcoming occurrence, ISO 8601 UTC']
              ['schedule' 'when it recurs, in words: Tue/Thu 16:45, first Saturday of the month']
              ['cadence' 'weekly, twice a week, monthly']
          ==
          ['note' (kind ~['text'] ~)]
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
::    Kind and slug are joined with a dot, which neither may contain, so
::    two bodies never share a group. A hyphen would let "per-son/me"
::    and "per/son-me" collide, and the second share would silently
::    replace the first one's grant.
::
++  group-name
  |=  [kind=@tas slug=@ta]
  ^-  @t
  (rap 3 'orrery-' kind '.' slug ~)
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
::  the action kinds it may propose, whether it may write at all, and
::  whether it may observe the attributes the policy marks sensitive,
::  which every view goes on hiding from it
::
+$  scope  [kinds=(set @tas) actions=(set @tas) write=? sensitive=?]
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
::  caps
::
++  max-clients      50
++  max-scope-kinds  24
::  +de-scope: {"kinds": [...], "actions": [...], "write": bool,
::  "sensitive": "none" | "write"}. Absent lists are empty, absent write
::  is false, and a missing or unknown sensitive reads as "none", so a
::  row stored before version 13 parses. Every name must be a kind.
::
++  de-scope
  |=  j=json
  ^-  (each scope @t)
  ?.  ?=([%o *] j)  [%| 'scope: expected an object']
  =/  ks=(list json)  (ga j 'kinds')
  =/  as=(list json)  (ga j 'actions')
  =/  over=@t  (rap 3 ': over ' (scot %ud max-scope-kinds) ~)
  ?:  (gth (lent ks) max-scope-kinds)  [%| (cat 3 'scope.kinds' over)]
  ?:  (gth (lent as) max-scope-kinds)  [%| (cat 3 'scope.actions' over)]
  =/  kinds=(unit (set @tas))  (de-kinds ks)
  ?~  kinds  [%| 'scope.kinds: each a kind name']
  =/  actions=(unit (set @tas))  (de-kinds as)
  ?~  actions  [%| 'scope.actions: each a kind name']
  =/  w=json  (gj j 'write')
  ?.  ?|(?=(~ w) ?=([%b *] w))  [%| 'scope.write: expected true or false']
  =/  write=?  ?:(?=([%b *] w) p.w |)
  =/  sensitive=?  =('write' (gs j 'sensitive'))
  ?:  &(sensitive !write)  [%| 'sensitive: write needs write']
  [%& u.kinds u.actions write sensitive]
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
::  +en-scope: a scope as JSON
::
++  en-scope
  |=  s=scope
  ^-  json
  %-  pairs:enjs:format
  :~  ['kinds' a+(turn ~(tap in kinds.s) |=(k=@tas `json`s+k))]
      ['actions' a+(turn ~(tap in actions.s) |=(k=@tas `json`s+k))]
      ['write' b+write.s]
      ['sensitive' s+`@t`?:(sensitive.s 'write' 'none')]
  ==
++  kind-in-scope    |=([s=scope k=@tas] ^-(? (~(has in kinds.s) k)))
++  action-in-scope  |=([s=scope k=@tas] ^-(? (~(has in actions.s) k)))
::  +de-client, +en-client-row, +en-client-view: a stored row (with the
::  salt and the hash) and what the owner sees of it (without them). A
::  row without a scope is refused, never read as an empty scope: a
::  stored row always has one.
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
::  +secret-of, +id-of: base-32 text from entropy, dots stripped and
::  zero-padded to a floor, since scot drops leading zero digits: a
::  secret is 20 to 24 characters, an id 6 to 8. Callers feed each a
::  disjoint slice of the entropy; neither derives from the other.
::
++  secret-of
  |=  eny=@
  ^-  @t
  (pad-left (skip (slag 2 (trip (scot %uv (end [3 15] eny)))) |=(c=@t =('.' c))) 20)
++  id-of
  |=  eny=@
  ^-  @t
  (pad-left (skip (slag 2 (trip (scot %uv (end [3 5] eny)))) |=(c=@t =('.' c))) 6)
::  +pad-left: zeros in front, up to a floor
::
++  pad-left
  |=  [t=tape n=@ud]
  ^-  @t
  =/  len=@ud  (lent t)
  ?:  (gte len n)  (crip t)
  (crip (weld (reap (sub n len) '0') t))
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
  =/  tok=tape
    =/  raw=tape  (slag 7 t)
    |-  ?:(?=([%' ' *] raw) $(raw t.raw) raw)
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
::  +veil-refs: a row whose value points at a body of a kind outside
::  the given kinds keeps its place with a null value and a synthetic
::  id, so the fold shows the attribute as cleared rather than falling
::  back to an older value the key may see, and nothing on the row
::  commits to the hidden body (the real id is a hash over the value)
::
++  veil-refs
  |=  [rows=(list row) kinds=(set @tas)]
  ^-  (list row)
  =|  n=@ud
  |-
  ^-  (list row)
  ?~  rows  ~
  =/  r=row  i.rows
  =/  target=(unit bid)  (ref-of value.obs.r)
  =/  hide=?
    ?~  target  |
    =/  pk  (parse-bid u.target)
    ?~  pk  |
    !(~(has in kinds) kind.u.pk)
  ?.  hide  [r $(rows t.rows)]
  :-  r(id (cat 3 'veiled-' (scot %ud n)), value.obs ~)
  $(rows t.rows, n +(n))
::  +scope-schema: the schema as a key may see it: its kinds only, the
::  hidden attribute names dropped from every attrs list and from
::  multi, and an actions list (when present) trimmed to its action
::  kinds
::
++  scope-schema
  |=  [schema=json s=scope hide=(set @t)]
  ^-  json
  ?.  ?=([%o *] schema)  schema
  =/  kinds=json  (gj schema 'kinds')
  =/  kept=json
    ?.  ?=([%o *] kinds)  [%o ~]
    :-  %o
    %-  ~(gas by *(map @t json))
    %+  murn  ~(tap by p.kinds)
    |=  [k=@t v=json]
    ^-  (unit [@t json])
    ?.  (~(has in kinds.s) `@tas`k)  ~
    ?.  ?=([%o *] v)  `[k v]
    `[k [%o (~(put by p.v) 'attrs' (drop-names (gj v 'attrs') hide))]]
  =/  out=(map @t json)  (~(put by p.schema) 'kinds' kept)
  =?  out  (~(has by out) 'multi')
    (~(put by out) 'multi' (drop-names (gj schema 'multi') hide))
  =?  out  (~(has by out) 'actions')
    =/  acts=json  (gj schema 'actions')
    %+  ~(put by out)  'actions'
    :-  %a
    %+  skim  ?:(?=([%a *] acts) p.acts ~)
    |=(j=json ?:(?=([%s *] j) (~(has in actions.s) `@tas`p.j) |))
  [%o out]
::  +drop-names: a JSON list of names without the hidden ones
::
++  drop-names
  |=  [names=json hide=(set @t)]
  ^-  json
  :-  %a
  %+  skip  ?:(?=([%a *] names) p.names ~)
  |=(j=json ?:(?=([%s *] j) (~(has in hide) p.j) |))
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
::  +out-of-scope: the first body id, subject, attribute or ref in an
::  observe batch that a scope may not write, or ~. An id that does not
::  parse is left for the decoders to refuse. A key may never send a
::  body's ship, and may only relate what it can see: a value pointing
::  at a body outside its kinds is refused, so the key cannot confirm
::  that body through an existing answer. The caller checks write
::  first; this names what a writing key may not touch.
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
    ?:  ?=(^ (gj j 'ship'))  `'ship'
    ?:((kind-in-scope s kind.u.pk) ~ `(gs j 'id'))
  ?^  bad-body  bad-body
  %+  roll  (ga jon 'observations')
  |=  [j=json acc=(unit @t)]
  ?^  acc  acc
  =/  pk  (parse-bid (gs j 'subject'))
  ?~  pk  ~
  ?.  (kind-in-scope s kind.u.pk)  `(gs j 'subject')
  ?:  (~(has in hide) (gs j 'attr'))  `(gs j 'attr')
  =/  target=(unit bid)  (ref-of (gj j 'value'))
  ?~  target  ~
  =/  tk  (parse-bid u.target)
  ?~  tk  ~
  ?:  (kind-in-scope s kind.u.tk)  ~
  `u.target
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
::
::  ==  the on-ship generator, the pure half (spec: docs/superpowers/plans/
::  2026-09-19-hoon-generator.md). The prompt from the state, the digest
::  that says whether anything the model would see has changed, the
::  request and the answer as OpenRouter speaks them, and the validator
::  that keeps only what the schema and the ship allow. orrery-utils/
::  generator/run.py is the reference, arm for arm; the nexus does the
::  asking and the filing. Here rather than a lib of its own because the
::  ball imports libs with /< and clay with /+, and one file cannot say
::  both.
::
++  nl  `@t`10
::  +winner-text: the current string value of an attribute, or ''
::
++  winner-text
  |=  [winners=(map @t (list row)) name=@t]
  ^-  @t
  =/  w=(list row)  (fall (~(get by winners) name) ~)
  ?~  w  ''
  ?:(?=([%s *] value.obs.i.w) p.value.obs.i.w '')
::  +phase: a situation's phase from its times: closed or cancelled when
::  status says so, over once its end has passed, under way once its
::  start has, upcoming while its start is ahead, else its status or open
::
++  phase
  |=  [winners=(map @t (list row)) now=@da]
  ^-  @t
  =/  st=@t  (winner-text winners 'status')
  ?:  |(=('closed' st) =('cancelled' st))  st
  =/  end=@t  =/(e (winner-text winners 'ended') ?:(=('' e) (winner-text winners 'ends') e))
  =/  start=@t  =/(s (winner-text winners 'started') ?:(=('' s) (winner-text winners 'starts') s))
  =/  now-iso=@t  (en-iso now)
  ?:  &(!=('' end) (lte-iso end now-iso))  'over'
  ?:  &(!=('' start) (lte-iso start now-iso))  'under way'
  ?:  !=('' start)  'upcoming'
  ?:(=('' st) 'open' st)
::  +lte-iso: ISO 8601 UTC strings of one shape compare as text
::
++  lte-iso  |=([a=@t b=@t] ^-(? !(gth-cord a b)))
++  gth-cord
  |=  [a=@t b=@t]
  ^-  ?
  =/  ta=tape  (trip a)
  =/  tb=tape  (trip b)
  |-
  ?~  ta  |
  ?~  tb  &
  ?:  =(i.ta i.tb)  $(ta t.ta, tb t.tb)
  (gth i.ta i.tb)
::  +norm-words: a title as lowercase words, punctuation gone
::
++  norm-words
  |=  t=@t
  ^-  (list @t)
  =/  low=tape  (cass (trip t))
  =/  clean=tape
    %+  turn  low
    |=(c=@ ?:(|(&((gte c 'a') (lte c 'z')) &((gte c '0') (lte c '9'))) c ' '))
  (turn (split-spaces clean) crip)
::  +split-spaces: the non-empty runs between spaces
::
++  split-spaces
  |=  t=tape
  ^-  (list tape)
  =|  cur=tape
  =|  out=(list tape)
  |-
  ?~  t  (flop ?:(=(~ cur) out [(flop cur) out]))
  ?:  =(' ' i.t)  $(t t.t, cur ~, out ?:(=(~ cur) out [(flop cur) out]))
  $(t t.t, cur [i.t cur])
::  +same-title: the same words, or four fifths of the shorter title's
::  words (at least two) in the longer
::
++  same-title
  |=  [a=@t b=@t]
  ^-  ?
  =/  ka=(set @t)  (sy (norm-words a))
  =/  kb=(set @t)  (sy (norm-words b))
  ?:  |(=(~ ka) =(~ kb))  |
  ?:  =(ka kb)  &
  =/  both=@ud  ~(wyt in (~(int in ka) kb))
  =/  short=@ud  (min ~(wyt in ka) ~(wyt in kb))
  (gte both (max 2 (div (mul 8 short) 10)))
::  the pieces of the user prompt and the count of decided actions shown
++  recent      60
++  prompt-bodies  300
::  +ref-or-text: a value as one token: a ref's id, a string, or its JSON
::
++  ref-or-text
  |=  v=json
  ^-  @t
  ?:  ?=([%o *] v)
    =/  r=(unit json)  (~(get by p.v) 'ref')
    ?:(?=([~ %s *] r) p.u.r (en:json:html v))
  ?:(?=([%s *] v) p.v (en:json:html v))
::  +join-cords: cords with a separator between
::
++  join-cords
  |=  [sep=@t xs=(list @t)]
  ^-  @t
  ?~  xs  ''
  (roll t.xs |=([x=@t acc=_i.xs] (rap 3 acc sep x ~)))
::  +squeeze: runs of whitespace as one space
::
++  squeeze
  |=  t=@t
  ^-  @t
  =/  flat=tape  (turn (trip t) |=(c=@ ?:(|(=(c 10) =(c 9) =(c 13)) ' ' c)))
  (crip (join-tapes " " (split-spaces flat)))
++  join-tapes
  |=  [sep=tape xs=(list tape)]
  ^-  tape
  ?~  xs  ""
  (roll t.xs |=([x=tape acc=_i.xs] (weld acc (weld sep x))))
::  +line: one body on one line: id | name (| phase for a situation) |
::  attr=value; ... with every attribute sorted, a multi as a list
::
++  line
  |=  [l=loaded multi=(set @t) now=@da]
  ^-  @t
  =/  winners=(map @t (list row))  (fold rows.l multi now)
  =/  bits=(list @t)
    %+  murn  (sort ~(tap by winners) |=([[a=@t *] [b=@t *]] (aor a b)))
    |=  [k=@t w=(list row)]
    ^-  (unit @t)
    ?~  w  ~
    ::  the head is tested on a copy: testing i.w narrows w into a
    ::  shape +turn will not take
    =/  first=row  i.w
    ?:  ?=(~ value.obs.first)  ~
    =/  shown=@t
      ?.  (~(has in multi) k)  (ref-or-text value.obs.first)
      (join-cords ', ' (turn w |=(r=row (ref-or-text value.obs.r))))
    `(rap 3 k '=' (end [3 120] (squeeze shown)) ~)
  =/  head=@t  (rap 3 id.l ' | ' name.body.l ~)
  =?  head  =(%situation kind.body.l)  (rap 3 head ' | ' (phase winners now) ~)
  ?~(bits head (rap 3 head ' | ' (join-cords '; ' bits) ~))
::  +build-parts: the five pieces, the least changing first and the
::  clock last, so the first four are the same text from one pass to the
::  next while nothing changed. decided are the done, dismissed and
::  failed actions, oldest first; the last +recent are shown.
::
++  build-parts
  |=  $:  all=(list loaded)
          acts=(list [id=@ta a=action])
          decided=(list [id=@ta a=action])
          schema=json
          now=@da
          tz=@t
          limit=@ud
      ==
  ^-  (list @t)
  =/  multi=(set @t)  (multi-of schema)
  =/  shown=(list loaded)  (scag prompt-bodies all)
  =/  hidden=(set @t)
    %-  sy
    %+  murn  shown
    |=  l=loaded
    ^-  (unit @t)
    ?.  =(%situation kind.body.l)  ~
    =/  ph=@t  (phase (fold rows.l multi now) now)
    ?:(|(=('closed' ph) =('cancelled' ph) =('over' ph)) `id.l ~)
  =/  section
    |=  kinds=(list @tas)
    ^-  (list @t)
    %-  zing
    %+  turn  kinds
    |=  k=@tas
    ^-  (list @t)
    =/  rows=(list loaded)
      (skim shown |=(l=loaded &(=(k kind.body.l) !(~(has in hidden) id.l))))
    ?~  rows  ~
    :-  (cat 3 ?:(=(%activity k) 'activities' (cat 3 k 's')) ':')
    (turn rows |=(l=loaded (cat 3 '  ' (line l multi now))))
  =/  kinds-line=@t
    =/  a=(list @t)  (strings (ga schema 'actions'))
    (cat 3 'Action kinds: ' (join-cords ', ' ?~(a ~['task' 'note'] a)))
  =/  head=(list @t)
    :~  (rap 3 'The owner is person/me. Propose at most ' (scot %ud limit) ' actions.' ~)
        kinds-line
    ==
  =/  payloads=json  (gj schema 'payloads')
  =?  head  ?=([%o *] payloads)
    %+  weld  head
    :-  'Payload shapes:'
    %+  turn  ~(tap by p.payloads)
    |=([k=@t v=json] (rap 3 '  ' k ': ' (en:json:html v) ~))
  =/  p0=@t  (join-cords nl (weld head (section ~[%thing %place %org %note])))
  =/  p1=@t  (join-cords nl (section ~[%person %activity]))
  =/  p2=@t  (join-cords nl (section ~[%situation]))
  =/  open=(list @t)
    :-  'Open actions (proposed or approved, do not duplicate):'
    %+  murn  acts
    |=  [id=@ta a=action]
    ^-  (unit @t)
    ?.  (is-open a)  ~
    `(rap 3 '  ' kind.a ' | ' title.a ' | about ' (join-cords ', ' ~(tap in about.a)) ~)
  =/  done=(list @t)
    :-  'Recent decisions (do not propose these again):'
    %+  turn  (slag (sub (lent decided) (min recent (lent decided))) decided)
    |=([id=@ta a=action] (rap 3 '  ' status.a ' | ' kind.a ' | ' title.a ~))
  =/  p3=@t  (join-cords nl (weld open done))
  =/  p4=@t
    (rap 3 'Now: ' (en-iso now) ', timezone ' ?:(=('' tz) 'unknown' tz) '. Answer with the JSON object.' ~)
  ~[p0 p1 p2 p3 p4]
::  +digest: a hash of everything but the clock
::
++  digest
  |=  parts=(list @t)
  ^-  @ux
  `@ux`(sham (join-cords nl (scag 4 parts)))
::  +$  config: generator.json as the nexus reads it. Off until the owner
::  turns it on and gives a key. The key is read here and nowhere else.
::
+$  config
  $:  enabled=?
      url=@t
      model=@t
      api-key=@t
      reasoning=json
      max-tokens=@ud
      max-actions=@ud
      timezone=@t
  ==
++  de-config
  |=  j=json
  ^-  config
  :*  =/(e (gj j 'enabled') ?:(?=([%b *] e) p.e |))
      =/(u (gs j 'url') ?:(=('' u) 'https://openrouter.ai/api/v1' u))
      =/(m (gs j 'model') ?:(=('' m) 'moonshotai/kimi-k3' m))
      (gs j 'api_key')
      =/(r (gj j 'reasoning') ?:(?=(~ r) [%o (my ~[['effort' s+'high']])] r))
      (fall (gn j 'max_tokens') 8.000)
      (fall (gn j 'max_actions') 5)
      (gs j 'timezone')
  ==
::  +en-config-masked: what the owner reads back: everything but the key
::
++  en-config-masked
  |=  c=config
  ^-  json
  %-  pairs:enjs:format
  :~  ['enabled' b+enabled.c]
      ['url' s+url.c]
      ['model' s+model.c]
      ['api_key_set' b+!=('' api-key.c)]
      ['reasoning' reasoning.c]
      ['max_tokens' (numb:enjs:format max-tokens.c)]
      ['max_actions' (numb:enjs:format max-actions.c)]
      ['timezone' s+timezone.c]
  ==
::  +reasoning-on: any reasoning object but {"enabled": false}
::
++  reasoning-on
  |=  r=json
  ^-  ?
  ?.  ?=([%o *] r)  |
  !?=([~ %b %.n] (~(get by p.r) 'enabled'))
::  +block: one content block, with a cache mark when asked
::
++  block
  |=  [t=@t marked=?]
  ^-  json
  =/  base=(list [@t json])  ~[['type' s+'text'] ['text' s+t]]
  =/  mark=(list [@t json])  ~[['cache_control' [%o (my ~[['type' s+'ephemeral']])]]]
  [%o (~(gas by *(map @t json)) ?:(marked (weld base mark) base))]
::  +chat-body: the request. Every piece of the user prompt is a content
::  block; the system block and the first three user blocks carry a
::  cache mark, so a call minutes after another reads every piece up to
::  the first changed one from the cache. No temperature when the model
::  reasons; the router reports the cost with the usage.
::
++  chat-body
  |=  [c=config parts=(list @t)]
  ^-  json
  =/  blocks=(list json)
    =/  n=@ud  0
    |-
    ?~  parts  ~
    [(block i.parts (lth n 3)) $(parts t.parts, n +(n))]
  =/  on=?  (reasoning-on reasoning.c)
  =/  system=json  [%o (my ~[['role' s+'system'] ['content' a+~[(block system-prompt &)]]])]
  =/  user=json  [%o (my ~[['role' s+'user'] ['content' a+blocks]])]
  %-  pairs:enjs:format
  %-  zing
  :~  :~  ['model' s+model.c]
          ['max_tokens' (numb:enjs:format max-tokens.c)]
          ['messages' a+~[system user]]
          ['provider' [%o (my ~[['zdr' b+&]])]]
          ['usage' [%o (my ~[['include' b+&]])]]
      ==
      ?:(on ~[['reasoning' reasoning.c]] ~[['temperature' (numb:enjs:format 0)]])
  ==
::  +answer-of: the model's text and the usage out of a chat completion,
::  or why there is none
::
++  answer-of
  |=  resp=json
  ^-  (each [text=@t usage=json] @t)
  =/  choices=(list json)  (ga resp 'choices')
  ?~  choices
    =/  err=@t  (gs (gj resp 'error') 'message')
    [%| ?:(=('' err) 'the model answered without choices' err)]
  =/  content=@t  (gs (gj i.choices 'message') 'content')
  ?:  =('' content)
    :-  %|
    ?:  =('length' (gs i.choices 'finish_reason'))
      'the model ran out of tokens before answering'
    'the model answered without content'
  [%& content (gj resp 'usage')]
::  +parse-answer: the first JSON object in the text, fences and chatter
::  ignored: from the first brace, shortening the tail until it parses
::
++  parse-answer
  |=  text=@t
  ^-  (unit json)
  =/  t=tape  (trip text)
  =/  start=(unit @ud)  (find "\{" t)
  ?~  start  ~
  =/  from=tape  (slag u.start t)
  =/  end=@ud  (lent from)
  |-
  ?:  =(0 end)  ~
  ?.  =('}' (snag (dec end) from))  $(end (dec end))
  =/  got=(unit json)  (de:json:html (crip (scag end from)))
  ?^  got  got
  $(end (dec end))
::  +system-prompt: orrery-utils/common/generator-prompt.md, verbatim
::
++  system-prompt
  ^-  @t
  '''
  You are the analyst for orrery, a model of one person's world kept on their own ship. You read the state and propose what should be done about it. You never write facts; other clients do that. You propose actions, and the owner approves or dismisses each one.

  What you are given.
  The state: every body with its current attributes (people with status, location and relationships; things; places; orgs; situations with their times and participants; activities with their schedule, last and next occurrence), the open situations, the open actions, and the schema with its notes and the payload shapes for each action kind.
  The recent decisions: actions done, dismissed or failed lately, with their titles. Do not propose these again, or a rewording of them. A dismissal is the owner saying no.
  The time now, and the owner's timezone.

  What to propose.
  Only what the owner would want done and has not done: a call to make, a thing to buy or bring, a message to send someone, a reminder ahead of a deadline, a preparation for something upcoming, a follow-up on something that stalled. An open situation with nothing being done about it, an activity whose next occurrence needs something, a person whose status calls for a reply, a delivery that never arrived.
  Few and good. Zero is a fine answer. Never propose more than the limit given.
  An action's kind is one of the kinds the schema lists. Its payload follows the shape the schema gives for that kind, exactly; a message names who it is for as a body id and says what to send in the owner's own voice, short; a home action names a Home Assistant service and entity. A task needs only a title and, when there is one, a due time.
  "about" names the bodies the action concerns, by id, at most a few. "due" is ISO 8601 UTC, only when the timing matters.
  Respect what the facts say about time: an occurrence in the past is over; a situation that is upcoming has not happened; "last" is the most recent occurrence and "next" the nearest one ahead.
  Do not invent facts, people, places or events. Do not propose things the owner cannot act on. Do not moralise.

  Answer with one JSON object and nothing else:
  {"actions": [{"kind": "task", "title": "...", "about": ["kind/slug"], "due": "...", "payload": {...}, "why": "one sentence"}],
   "notes": ["anything you noticed that is not an action: a fact that looks wrong, a duplicate, a missing piece"]}
  "why" is for the owner's eyes on the page; keep it to one sentence. Notes are optional and short.
  '''
::  +cass-cord: a cord lowercased
::
++  cass-cord  |=(t=@t ^-(@t (crip (cass (trip t)))))
::  +validate: what the answer keeps. A kind the schema lists (task and
::  note when it lists none), a title, not a rewording of anything open
::  or decided, every about body known, every required payload key
::  present, a due that parses, the why in the payload for the page; at
::  most limit, looking at twice that. Notes name what was dropped and
::  carry the model's own notes. Each kept action is the JSON an act op
::  takes, before fill-act-as stamps proposed and by.
::
++  validate
  |=  [answer=json known=(set @t) taken=(list @t) schema=json limit=@ud]
  ^-  [acts=(list json) notes=(list @t)]
  =/  kinds=(set @t)
    =/  a=(list @t)  (strings (ga schema 'actions'))
    (sy ?~(a ~['task' 'note'] a))
  =/  payloads=json  (gj schema 'payloads')
  =/  todo=(list json)  (scag (mul 2 limit) (ga answer 'actions'))
  =/  said=(list @t)
    %+  turn  (scag 10 (ga answer 'notes'))
    |=(n=json (cat 3 'model note: ' (end [3 200] (ref-or-text n))))
  =|  acts=(list json)
  =|  notes=(list @t)
  |-
  ?:  |(?=(~ todo) (gte (lent acts) limit))
    [(flop acts) (weld (flop notes) said)]
  =/  a=json  i.todo
  ?.  ?=([%o *] a)  $(todo t.todo)
  =/  kind=@t  =/(k (cass-cord (gs a 'kind')) ?:(=('' k) 'task' k))
  =/  title=@t  (end [3 200] (gs a 'title'))
  ?:  |(!(~(has in kinds) kind) =('' title))
    $(todo t.todo, notes [(rap 3 'dropped: kind ' kind ' or no title (' (end [3 40] title) ')' ~) notes])
  ?:  (lien taken |=(t=@t (same-title title t)))
    $(todo t.todo, notes [(cat 3 'dropped as already open or decided: ' title) notes])
  =/  about=(list @t)  (turn (strings (ga a 'about')) cass-cord)
  =/  bad=(list @t)  (skip about |=(b=@t (~(has in known) b)))
  ?^  bad
    $(todo t.todo, notes [(rap 3 'dropped ' title ': names bodies that do not exist: ' (join-cords ', ' bad) ~) notes])
  =/  payload=(map @t json)
    =/  p=json  (gj a 'payload')
    ?:(?=([%o *] p) p.p ~)
  =/  shape=json  (gj payloads kind)
  =/  missing=(list @t)
    ?.  ?=([%o *] shape)  ~
    %+  murn  ~(tap by p.shape)
    |=  [k=@t v=json]
    ^-  (unit @t)
    ?.  ?=([%s *] v)  ~
    ?.  =('required' (end [3 8] p.v))  ~
    ?:((~(has by payload) k) ~ `k)
  ?^  missing
    $(todo t.todo, notes [(rap 3 'dropped ' title ': payload lacks ' (join-cords ', ' missing) ~) notes])
  =/  why=@t  (end [3 300] (gs a 'why'))
  =?  payload  !=('' why)  (~(put by payload) 'why' s+why)
  =/  due=(unit @da)  (de-iso (gs a 'due'))
  =/  row=json
    %-  pairs:enjs:format
    %-  zing
    :~  :~  ['kind' s+kind]
            ['title' s+title]
            ['about' a+(turn (scag 20 about) |=(b=@t `json`s+b))]
            ['payload' [%o payload]]
        ==
        ?~(due ~ ~[['due' (en-time u.due)]])
    ==
  $(todo t.todo, acts [row acts], taken [title taken])
--
