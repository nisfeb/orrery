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
::  a named zone: how far from UTC its clock stands, in minutes, in
::  winter and in summer, and which summer rule it keeps. west is the
::  side of UTC the clock is on.
::
+$  zone  [west=? std=@ud dst=@ud rule=?(%us %uk %none)]
::  +zones: the zones the ship can render a local clock for. The owner's
::  timezone is a name from the generator's config, and any name not
::  here leaves the time in UTC.
::
++  zones
  ^-  (map @t zone)
  %-  ~(gas by *(map @t zone))
  ^-  (list [@t zone])
  :~  ['America/New_York' & 300 240 %us]
      ['America/Chicago' & 360 300 %us]
      ['America/Denver' & 420 360 %us]
      ['America/Phoenix' & 420 420 %none]
      ['America/Los_Angeles' & 480 420 %us]
      ['America/Anchorage' & 540 480 %us]
      ['Pacific/Honolulu' & 600 600 %none]
      ['Europe/London' | 0 60 %uk]
  ==
::  +dow: the day of the week of a date, 0 for Sunday (Sakamoto's)
::
++  dow
  |=  [y=@ud m=@ud d=@ud]
  ^-  @ud
  =/  t=(list @ud)  ~[0 3 2 5 0 3 5 1 4 6 2 4]
  =/  yy=@ud  ?:((lth m 3) (dec y) y)
  =/  n=@ud  :(add yy (div yy 4) (div yy 400) (snag (dec m) t) d)
  (mod (sub n (div yy 100)) 7)
::  +first-sunday: the day of the month of a month's first Sunday
::
++  first-sunday
  |=  [y=@ud m=@ud]
  ^-  @ud
  (add 1 (mod (sub 7 (dow y m 1)) 7))
::  +last-sunday: the day of the month of the last Sunday, given the
::  month's last day
::
++  last-sunday
  |=  [y=@ud m=@ud last=@ud]
  ^-  @ud
  (sub last (dow y m last))
::  +in-dst: whether a moment falls in a zone's summer. The US rule runs
::  from the second Sunday of March to the first Sunday of November and
::  is judged on the standard clock; the UK rule runs from the last
::  Sunday of March to the last Sunday of October, both at 01:00 UTC.
::
++  in-dst
  |=  [z=zone when=@da]
  ^-  ?
  ?:  ?=(%none rule.z)  |
  =/  t=@da  ?:(?=(%us rule.z) (sub when (mul std.z ~m1)) when)
  =/  [[* y=@ud] *]  (yore t)
  =/  [start=@da end=@da]
    ?:  ?=(%us rule.z)
      :-  (year [[& y] 3 (add 7 (first-sunday y 3)) 2 0 0 ~])
      (year [[& y] 11 (first-sunday y 11) 1 0 0 ~])
    :-  (year [[& y] 3 (last-sunday y 3 31) 1 0 0 ~])
    (year [[& y] 10 (last-sunday y 10 31) 1 0 0 ~])
  &((gte t start) (lth t end))
::  +local-iso: an ISO UTC time as a named zone's clock reads it, with
::  its offset: 2026-09-17T16:00:00Z in America/New_York is
::  2026-09-17T12:00:00-04:00. A message says "until 11:30" against the
::  clock it was written on, and the model can only read that if it sees
::  the clock. An unknown zone, or a time that will not parse, stays as
::  it was.
::
++  local-iso
  |=  [at=@t tz=@t]
  ^-  @t
  =/  when=(unit @da)  (de-iso at)
  ?~  when  at
  =/  z=(unit zone)  (~(get by zones) tz)
  ?~  z  (en-iso u.when)
  =/  mins=@ud  ?:((in-dst u.z u.when) dst.u.z std.u.z)
  =/  shift=@dr  (mul mins ~m1)
  =/  local=@da  ?:(west.u.z (sub u.when shift) (add u.when shift))
  %+  rap  3
  :~  (end [3 19] (en-iso local))
      ?:(west.u.z '-' '+')
      (crip ((d-co:co 2) (div mins 60)))
      ':'
      (crip ((d-co:co 2) (mod mins 60)))
  ==
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
++  set-key                                     ::  a key set on an object
  |=  [jon=json k=@t v=json]
  ^-  json
  ?.  ?=([%o *] jon)  [%o (~(gas by *(map @t json)) ~[[k v]])]
  [%o (~(put by p.jon) k v)]
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
    ;:  weld
      (fall (~(get by winners) 'email') ~)
      (fall (~(get by winners) 'phone') ~)
      (fall (~(get by winners) 'telegram') ~)
    ==
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
            ~['status' 'location' 'phone' 'email' 'telegram' 'ship' 'birthday' 'relationship' 'employer' 'timezone' 'likes' 'dislikes' 'health' 'income']
          :~  ['status' 'what the person is doing or dealing with right now, in plain words, as an observer would put it: on jury duty, stranded waiting for a tow, travelling, sick; never a feeling, a quote or a wish']
              ['location' 'where the person is: a place body as a ref when the ship has one, else a short place name; null when they have left and the new place is unknown']
              ['telegram' 'the Telegram chat id the ship reaches this person at, a number as text; identity, like phone']
              ['relationship' 'how they relate to the owner: wife, son, boss, neighbour']
              ['health' 'a medical fact about the person; kept from client keys by policy']
              ['income' 'a money fact about the person; kept from client keys by policy']
          ==
          :-  'place'
          %+  kind
            ~['type' 'address' 'phone' 'hours' 'geo']
          :~  ['geo' 'where the place is, "lat,lon" or {"lat", "lon"}: what lets a phone say the owner is at this place rather than at its coordinates']
          ==
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
      ['actions' a+(turn ~['task' 'note' 'message' 'home' 'calendar'] |=(t=@t `json`s+t))]
      :-  'payloads'
      =/  shape
        |=  keys=(list [@t @t])
        ^-  json
        (pairs:enjs:format (turn keys |=([k=@t t=@t] [k `json`s+t])))
      %-  pairs:enjs:format
      :~  ['task' (shape ~[['notes' 'optional: what to do, in a sentence']])]
          ['note' (shape ~[['text' 'required: the note for the owner']])]
          :-  'message'
          %-  shape
          :~  ['via' 'required: one of telegram, mail, chat; the channel the conversation is on']
              ['to' 'required: the body id of the person, e.g. person/andrea']
              ['text' 'required: the message, short, in the owner\'s own voice']
          ==
          :-  'home'
          %-  shape
          :~  ['service' 'required: a Home Assistant service, e.g. light.turn_on']
              ['entity_id' 'required: the entity, e.g. light.porch']
              ['data' 'optional: service data, an object']
          ==
          :-  'calendar'
          %-  shape
          :~  ['title' 'required']
              ['starts' 'required: ISO 8601 UTC']
              ['ends' 'optional: ISO 8601 UTC']
              ['location' 'optional']
          ==
      ==
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
    |=  [id=@ta a=action]
    =/  base=@t  (rap 3 '  ' status.a ' | ' kind.a ' | ' title.a ~)
    ?:(=('' note.a) base (rap 3 base ' | ' (end [3 200] (squeeze note.a)) ~))
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
      ::  the two limits that keep the bill bounded whatever the state
      ::  does: no two model calls closer than cooldown minutes (changes
      ::  meanwhile coalesce into one pass at its end), and no more than
      ::  max-daily calls in a UTC day
      cooldown=@ud
      max-daily=@ud
      ::  urgent passes a day: a reader that judged a message needs help
      ::  within the hour asks for one past the cooldown, under this cap
      max-urgent=@ud
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
      (fall (gn j 'cooldown_minutes') 60)
      (fall (gn j 'max_daily') 24)
      (fall (gn j 'max_urgent') 5)
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
      ['cooldown_minutes' (numb:enjs:format cooldown.c)]
      ['max_daily' (numb:enjs:format max-daily.c)]
      ['max_urgent' (numb:enjs:format max-urgent.c)]
  ==
::  +urgent-held: whether today's urgent passes are spent
::
++  urgent-held
  |=  [c=config last=json now=@da]
  ^-  ?
  =/  day=@t  (end [3 10] (en-iso now))
  =/  today=@ud  ?:(=(day (gs last 'day')) (fall (gn last 'urgent_today') 0) 0)
  (gte today max-urgent.c)
::  +urgent-parts: the prompt with the urgent line before the clock, so
::  the cached prefix is untouched and the model reads it last
::
++  urgent-parts
  |=  [parts=(list @t) about=(list @t)]
  ^-  (list @t)
  =/  line=@t
    %+  rap  3
    :~  'Urgent: a reader that just wrote these facts judged that the owner may need help within the hour'
        ?~(about '' (cat 3 ', about ' (join-cords ', ' about)))
        '. Propose first what helps in the next hour: who to call, what to bring, who to tell. The usual rules hold.'
    ==
  ?~  parts  ~[line]
  (snoc (snoc (snip `(list @t)`parts) line) (rear parts))
::  +micro-of: a JSON number cord as micro-units, for summing a model's
::  cost (a fraction of a dollar, sometimes in exponent form) in an
::  atom: 0.0229 is 22900, 2.29e-05 is 22
::
++  micro-of
  |=  n=@ta
  ^-  @ud
  =/  t=tape  (trip n)
  =/  parts  (split-char 'e' (turn t |=(c=@ ?:(=(c 'E') 'e' c))))
  =/  mant=tape  ?~(parts "0" i.parts)
  =/  expo=@sd
    ?~  parts  --0
    ?~  t.parts  --0
    =/  e=tape  i.t.parts
    ?~  e  --0
    ?:  =('-' i.e)  (new:si | (fall (rush (crip t.e) dem) 0))
    (new:si & (fall (rush (crip ?:(=('+' i.e) t.e e)) dem) 0))
  =/  halves  (split-char '.' mant)
  =/  whole=@ud  ?~(halves 0 (fall (rush (crip i.halves) dem) 0))
  =/  frac=tape  ?~(halves "" ?~(t.halves "" i.t.halves))
  ::  six decimals of the fraction, padded
  =/  six=tape  (scag 6 (weld frac "000000"))
  =/  micro=@ud  (add (mul whole 1.000.000) (fall (rush (crip six) dem) 0))
  =/  e=@sd  expo
  |-
  ?:  =(--0 e)  micro
  ?:  (syn:si e)  $(micro (mul micro 10), e (dif:si e --1))
  $(micro (div micro 10), e (sum:si e --1))
::  +held-until: when the next model call may happen, given the last
::  record and the limits, or ~ when it may happen now. calls-today
::  counts the calls made on the UTC day the record names.
::
++  held-until
  |=  [c=config last=json now=@da]
  ^-  (unit @da)
  =/  called=(unit @da)  (de-iso (gs last 'called'))
  =/  day=@t  (end [3 10] (en-iso now))
  =/  today=@ud  ?:(=(day (gs last 'day')) (fall (gn last 'calls_today') 0) 0)
  ?:  (gte today max-daily.c)
    ::  the first moment of tomorrow, UTC
    =/  d=@da  (add (sub now (mod now ~d1)) ~d1)
    `d
  ?~  called  ~
  =/  next=@da  (add u.called (mul cooldown.c ~m1))
  ?:((gte now next) ~ `next)
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
  (chat-body-with c system-prompt parts)
::  +chat-body-with: the request under any system text: the generator's
::  prompt above, the analyst's for the telegram reader
::
++  chat-body-with
  |=  [c=config system-text=@t parts=(list @t)]
  ^-  json
  =/  blocks=(list json)
    =/  n=@ud  0
    |-
    ?~  parts  ~
    [(block i.parts (lth n 3)) $(parts t.parts, n +(n))]
  =/  on=?  (reasoning-on reasoning.c)
  =/  system=json  [%o (my ~[['role' s+'system'] ['content' a+~[(block system-text &)]]])]
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
::  +decider-url: the decisions route at the model host: the origin of
::  the chat url (scheme, host, port) with openrouter's path, so a stub
::  standing in for the model answers the decider too
::
++  decider-url
  |=  url=@t
  ^-  @t
  =/  t=tape  (trip url)
  =/  origin=tape
    =/  scheme=(unit @ud)  (find "://" t)
    ?~  scheme  t
    =/  rest=tape  (slag (add 3 u.scheme) t)
    =/  slash=(unit @ud)  (find "/" rest)
    ?~  slash  t
    (scag (add 3 (add u.scheme u.slash)) t)
  (crip (weld origin "/api/alpha/decisions"))
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
  Only what the owner would want done and has not done: a call to make, a thing to buy or bring, a message to send someone, a reminder ahead of a deadline, a follow-up on something that stalled. An open situation with nothing being done about it, a person whose status calls for a reply, a delivery that never arrived.
  An event on the calendar is already known: never propose a task for attending it, and never restate it as a todo. Propose what an event needs beyond showing up, and only when the state gives a reason: a birthday with no gift task, an appointment with a form to bring, a rehearsal with no ride. For the first occurrence of an activity (one with no last), propose one task whose payload "notes" carries a checklist of the equipment and paperwork such an activity usually calls for: what a first sailing session, ballet class or rehearsal needs. When two events are close together or overlap, propose one task to sort out the overlap, naming both. A situation that is over or closed needs nothing.
  Few and good. Zero is a fine answer. Never propose more than the limit given.
  An action's kind is one of the kinds the schema lists. Its payload follows the shape the schema gives for that kind, exactly; a message names who it is for as a body id and says what to send in the owner's own voice, short; a home action names a Home Assistant service and entity. A task needs only a title and, when there is one, a due time.
  "about" names the bodies the action concerns, by id, at most a few. "due" is ISO 8601 UTC, only when the timing matters.
  Respect what the facts say about time: an occurrence in the past is over; a situation that is upcoming has not happened; "last" is the most recent occurrence and "next" the nearest one ahead.
  Do not invent facts, people, places or events. Do not propose things the owner cannot act on. Do not moralise.
  Common sense, always: no todo for attending an event or a routine activity; no message telling someone what they just said; nothing the owner is already doing; nothing a decision already covered; no reminder for what happens on its own.
  A dismissed action may carry the owner's reason after its title. Those reasons are the owner's taste, and they generalise: one "just the event" means every todo for attending is unwanted, one "I always do this" means routine chores are unwanted. Read them before proposing.

  Answer with one JSON object and nothing else:
  {"actions": [{"kind": "task", "title": "...", "about": ["kind/slug"], "due": "...", "payload": {...}, "why": "one sentence"}],
   "notes": ["anything you noticed that is not an action: a fact that looks wrong, a duplicate, a missing piece"]}
  "why" is for the owner's eyes on the page; keep it to one sentence. Notes are optional and short.
  '''
::  +attend-words: what a title adds when it only says to go to an event
::
++  attend-words
  ^-  (set @t)
  (sy ~['go' 'to' 'the' 'a' 'an' 'at' 'on' 'for' 'of' 'attend' 'be' 's' 'remember' 'show' 'up' 'dont' 'forget' 'today' 'tomorrow'])
::  +restates: a title that is a todo for an event: every word of the
::  event's name, and nothing else but attendance words
::
++  restates
  |=  [title=@t event=@t]
  ^-  ?
  =/  kt=(set @t)  (sy (norm-words title))
  =/  ke=(set @t)  (sy (norm-words event))
  ?:  =(~ ke)  |
  ?.  =(~ (~(dif in ke) kt))  |
  =(~ (~(dif in (~(dif in kt) ke)) attend-words))
::  +find-first: the first element a gate accepts
::
++  find-first
  |=  [xs=(list @t) f=$-(@t ?)]
  ^-  (unit @t)
  ?~  xs  ~
  ?:((f i.xs) `i.xs $(xs t.xs))
::  +cass-cord: a cord lowercased
::
++  cass-cord  |=(t=@t ^-(@t (crip (cass (trip t)))))
::  +validate: what the answer keeps. A kind the schema lists (task and
::  note when it lists none), a title, not a rewording of anything open
::  or decided, not a todo for an event the calendar already holds (a
::  title that reads as an open situation's or an activity's name),
::  every about body known, every required payload key present, a due
::  that parses, the why in the payload for the page; at
::  most limit, looking at twice that. Notes name what was dropped and
::  carry the model's own notes. Each kept action is the JSON an act op
::  takes, before fill-act-as stamps proposed and by.
::
++  validate
  |=  [answer=json known=(set @t) taken=(list @t) events=(list @t) schema=json limit=@ud]
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
  =/  restated=(unit @t)  (find-first events |=(e=@t (restates title e)))
  ?^  restated
    $(todo t.todo, notes [(rap 3 'dropped as a todo for an event on the calendar: ' title ' (' u.restated ')' ~) notes])
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
::  ==  retire: closing what is over (reconcile.py retire, on-ship
::  2026-09-19). The ship's open list goes by status, and a calendar
::  event is written with its end and no status, so what is over would
::  sit in the open list until something writes closed. This is that
::  something, twice a day.
::
::  +plan-retire: the situations to close and when. One whose end has
::  passed closes at its end; a trip with no end a week after it
::  started; one with a start but no end that began more than stale
::  ago with nothing seen since closes at its newest observation. The
::  close time lands one second past a later live status row, so a
::  reminder that said "open" after the event does not win the fold.
::
++  retire-trip   ~d7
++  is-trip
  |=  id=bid
  ^-  ?
  ?&  =(25 (met 3 id))
      =('situation/' (end [3 10] id))
      =('-trip' (rsh [3 20] id))
  ==
++  plan-retire
  |=  [all=(list loaded) multi=(set @t) now=@da stale=@dr]
  ^-  (list [id=bid at=@da why=@t])
  =/  cutoff=@da  (sub now stale)
  %+  murn  all
  |=  l=loaded
  ^-  (unit [id=bid at=@da why=@t])
  ?.  =(%situation kind.body.l)  ~
  =/  winners=(map @t (list row))  (fold rows.l multi now)
  ?:  (is-closed winners)  ~
  =/  status-at=(unit @da)
    =/  w=(list row)  (fall (~(get by winners) 'status') ~)
    ?~(w ~ `at.obs.i.w)
  =/  after
    |=  at=@da
    ^-  @da
    ?~  status-at  at
    ?:((gte u.status-at at) (add u.status-at ~s1) at)
  =/  end=(unit @da)
    =/  e=@t  (winner-text winners 'ended')
    (de-iso ?:(=('' e) (winner-text winners 'ends') e))
  =/  start=(unit @da)
    =/  s=@t  (winner-text winners 'started')
    (de-iso ?:(=('' s) (winner-text winners 'starts') s))
  ?^  end
    ?.  (lth u.end now)  ~
    `[id.l (after u.end) (cat 3 'ended ' (en-iso u.end))]
  ?~  start  ~
  ?:  &((is-trip id.l) (lth (add u.start retire-trip) now))
    =/  e=@da  (add u.start retire-trip)
    `[id.l (after e) (rap 3 'a trip started ' (en-iso u.start) ' with no end' ~)]
  =/  latest=@da
    %+  roll  rows.l
    |=  [r=row acc=@da]
    ?:(retracted.obs.r acc (max seen.obs.r acc))
  =.  latest  (max latest u.start)
  ?.  &((lth u.start cutoff) (lth latest cutoff))  ~
  `[id.l (after latest) (rap 3 'started ' (en-iso u.start) ', nothing since ' (en-iso latest) ~)]
::  +retire-ops: the plans as observe ops for the writer, each a status
::  closed row at its close time, signed retire
::
++  retire-ops
  |=  plans=(list [id=bid at=@da why=@t])
  ^-  (list json)
  %+  observe-ops  ~
  %+  turn  plans
  |=  [id=bid at=@da why=@t]
  (obs-row id 'status' s+'closed' at ~ 90 ['retire' (cat 3 'retire/' id)] 'retire')
::  ==  reconcile: associating what the readers left apart (the passes of
::  reconcile.py, on-ship 2026-09-20). Each planner is pure over the
::  loaded bodies and answers the writer ops to file, in order.
::
::  the writer ops
::
++  obs-row
  |=  [subject=bid attr=@t value=json at=@da until=(unit @da) conf=@ud src=source by=@t]
  ^-  json
  %-  pairs:enjs:format
  %-  zing
  :~  :~  ['subject' s+subject]
          ['attr' s+attr]
          ['value' value]
          ['at' s+(en-iso at)]
          ['conf' (numb:enjs:format conf)]
          ['by' s+by]
          ['source' (pairs:enjs:format ~[['kind' s+kind.src] ['id' s+id.src]])]
      ==
      ?~(until ~ ~[['until' s+(en-iso u.until)]])
  ==
::  +observe-ops: bodies then rows, in the route's batches of 50 and 200
::
++  observe-ops
  |=  [bodies=(list json) rows=(list json)]
  ^-  (list json)
  ?:  &(?=(~ bodies) ?=(~ rows))  ~
  :-  %-  pairs:enjs:format
      :~  ['op' s+'observe']
          ['bodies' a+(scag 50 bodies)]
          ['observations' a+(scag 200 rows)]
      ==
  $(bodies (slag 50 bodies), rows (slag 200 rows))
++  retract-op
  |=  [id=@ta why=@t]
  ^-  json
  (pairs:enjs:format ~[['op' s+'retract'] ['id' s+id] ['note' s+why] ['by' s+'reconcile']])
++  delete-op
  |=  id=bid
  ^-  json
  (pairs:enjs:format ~[['op' s+'delete-body'] ['id' s+id]])
++  merge-op
  |=  [from=bid into=bid]
  ^-  json
  (pairs:enjs:format ~[['op' s+'merge'] ['from' s+from] ['into' s+into]])
++  set-action-op
  |=  [id=@ta status=@t why=@t]
  ^-  json
  (pairs:enjs:format ~[['op' s+'set-action'] ['id' s+id] ['status' s+status] ['note' s+why] ['by' s+'reconcile']])
::  the settings, under policy.reconcile
::
++  reconcile-of
  |=  policy=json
  ^-  [min=@ud stale=@ud prune=@ud]
  =/  r=json  (gj policy 'reconcile')
  :+  (fall (gn r 'min_occurrences') 3)
    (fall (gn r 'stale_days') 30)
  (fall (gn r 'prune_days') 0)
::  tapes
::
++  is-letter  |=(c=@ ^-(? |(&((gte c 'a') (lte c 'z')) &((gte c 'A') (lte c 'Z')))))
++  is-digit   |=(c=@ ^-(? &((gte c '0') (lte c '9'))))
++  is-alnum   |=(c=@ ^-(? |((is-letter c) (is-digit c) =(c '_'))))
++  is-digits  |=(t=tape ^-(? ?~(t | (levy `tape`t is-digit))))
++  is-alpha   |=(t=tape ^-(? ?~(t | (levy `tape`t |=(c=@ &((gte c 'a') (lte c 'z')))))))
++  skip-spaces
  |=  t=tape
  ^-  tape
  ?:  &(?=(^ t) |(=(' ' i.t) =(9 i.t) =(10 i.t) =(13 i.t)))  $(t t.t)
  t
++  trim-tape  |=(t=tape ^-(tape (flop (skip-spaces (flop (skip-spaces t))))))
++  trim-cord  |=(t=@t ^-(@t (crip (trim-tape (trip t)))))
::  +split-char: the non-empty runs between one separator
::
++  split-char
  |=  [sep=@ t=tape]
  ^-  (list tape)
  =|  cur=tape
  =|  out=(list tape)
  |-
  ?~  t  (flop ?:(=(~ cur) out [(flop cur) out]))
  ?:  =(sep i.t)  $(t t.t, cur ~, out ?:(=(~ cur) out [(flop cur) out]))
  $(t t.t, cur [i.t cur])
++  split-ws
  |=  t=tape
  ^-  (list tape)
  (split-char ' ' (turn t |=(c=@ ?:(|(=(c 9) =(c 10) =(c 13)) ' ' c))))
::  +strip-noise: a leading Reminder:, Fwd:, Re: and the like, with the
::  colon and the spaces around it, gone; case-insensitive
::
++  noise-prefixes
  ^-  (list tape)
  ~["updated invitation" "invitation" "notification" "reminder" "fwd" "fw" "re"]
++  strip-noise
  |=  t=tape
  ^-  tape
  =/  low=tape  (cass t)
  =/  ps=(list tape)  noise-prefixes
  |-
  ?~  ps  t
  =/  n=@ud  (lent i.ps)
  ?.  =(i.ps (scag n low))  $(ps t.ps)
  =/  after=tape  (skip-spaces (slag n t))
  ?.  &(?=(^ after) =(':' i.after))  $(ps t.ps)
  (skip-spaces t.after)
::  +strip-punct-tail: a token without its trailing , . ;
::
++  strip-punct-tail
  |=  t=tape
  ^-  tape
  =/  r=tape  (flop t)
  |-
  ?:  &(?=(^ r) |(=(',' i.r) =('.' i.r) =(';' i.r)))  $(r t.r)
  (flop r)
++  weekday-heads  ^-((list tape) ~["mon" "tue" "wed" "thu" "fri" "sat" "sun"])
++  month-heads    ^-((list tape) ~["jan" "feb" "mar" "apr" "may" "jun" "jul" "aug" "sep" "oct" "nov" "dec"])
++  has-head
  |=  [t=tape heads=(list tape)]
  ^-  ?
  &((is-alpha t) (lien heads |=(h=tape =(h (scag 3 t)))))
::  +is-clock: 6, 12, 6:00, 12:30
::
++  is-clock
  |=  t=tape
  ^-  ?
  =/  n=@ud  (lent t)
  ?:  &((gte n 1) (lte n 2))  (is-digits t)
  ?.  &((gte n 4) (lte n 5))  |
  ?&  (is-digits (scag (sub n 3) t))
      =(':' (snag (sub n 3) t))
      (is-digits (slag (sub n 2) t))
  ==
++  is-time-token
  |=  t=tape
  ^-  ?
  =/  n=@ud  (lent t)
  ?:  (lth n 3)  |
  =/  tail=tape  (slag (sub n 2) t)
  &(|(=("am" tail) =("pm" tail)) (is-clock (scag (sub n 2) t)))
++  is-iso-date
  |=  t=tape
  ^-  ?
  ?.  =(10 (lent t))  |
  ?&  (is-digits (scag 4 t))
      =('-' (snag 4 t))
      (is-digits (scag 2 (slag 5 t)))
      =('-' (snag 7 t))
      (is-digits (slag 8 t))
  ==
++  is-slash-date
  |=  t=tape
  ^-  ?
  =/  parts=(list tape)  (split-char '/' t)
  ?.  |(=(2 (lent parts)) =(3 (lent parts)))  |
  ?.  &((is-digits (snag 0 parts)) (lte (lent (snag 0 parts)) 2))  |
  ?.  &((is-digits (snag 1 parts)) (lte (lent (snag 1 parts)) 2))  |
  ?:  =(2 (lent parts))  &
  =/  y=tape  (snag 2 parts)
  &((is-digits y) (gte (lent y) 2) (lte (lent y) 4))
::  +drop-dateish: the tokens with weekdays, times, dates and month-day
::  pairs taken out, lower-cased
::
++  drop-dateish
  |=  toks=(list tape)
  ^-  (list tape)
  =|  out=(list tape)
  |-
  ?~  toks  (flop out)
  =/  t=tape  (cass (strip-punct-tail i.toks))
  =/  nx=tape  ?~(t.toks ~ (cass (strip-punct-tail i.t.toks)))
  ?:  (has-head t weekday-heads)  $(toks t.toks)
  ?:  (is-time-token t)  $(toks t.toks)
  ?:  (is-iso-date t)  $(toks t.toks)
  ?:  (is-slash-date t)  $(toks t.toks)
  ?:  &((is-clock t) |(=("am" nx) =("pm" nx)))  $(toks (slag 2 `(list tape)`toks))
  ?:  &((has-head t month-heads) (is-digits nx) (lte (lent nx) 2))
    =/  rest=(list tape)  (slag 2 `(list tape)`toks)
    ?~  rest  $(toks rest)
    =/  yr=tape  (strip-punct-tail i.rest)
    $(toks ?:(&((is-digits yr) =(4 (lent yr))) t.rest `(list tape)`rest))
  $(toks t.toks, out [t out])
::  +normalize-title: a title with its noise stripped: prefixes like
::  Reminder:, dates, times and weekdays, punctuation and case.
::  "Reminder: Pottery @ Thu May 14, 6:00pm" and "Pottery" normalise
::  alike; "Robin- Pottery/Wheel" stays its own.
::
++  normalize-title
  |=  t=@t
  ^-  @t
  =/  s=tape  (strip-noise (strip-noise (trim-tape (trip t))))
  =/  kept=tape  (join-tapes " " (drop-dateish (split-ws s)))
  =/  clean=tape
    %+  turn  (cass kept)
    |=(c=@ ?:(|(&((gte c 'a') (lte c 'z')) (is-digit c) =(c '/')) c ' '))
  (crip (join-tapes " " (split-char ' ' clean)))
::  +strict-key: a title with only its prefix noise and case removed
::
++  strict-key
  |=  t=@t
  ^-  @t
  (crip (join-tapes " " (split-ws (cass (strip-noise (trim-tape (trip t)))))))
::  +slug: a body slug: lowercase letters, digits and hyphens
::
++  slug
  |=  t=@t
  ^-  @t
  =/  d=tape
    %+  turn  (cass (trip t))
    |=(c=@ ?:(|(&((gte c 'a') (lte c 'z')) (is-digit c)) c '-'))
  =/  s=tape  (scag max-slug (join-tapes "-" (split-char '-' d)))
  =/  r=tape  (flop s)
  =.  r  |-(?:(&(?=(^ r) =('-' i.r)) $(r t.r) r))
  ?~(r 'x' (crip (flop r)))
::  people
::
++  role-words
  ^-  (set @t)
  %-  sy
  ^-  (list @t)
  :~  'me'  'i'  'wife'  'husband'  'mom'  'mum'  'dad'  'mother'  'father'  'son'
      'daughter'  'brother'  'sister'  'boss'  'friend'  'partner'  'mr'  'mrs'  'ms'
      'dr'  'the'
  ==
++  org-words
  ^-  (set @t)
  %-  sy
  ^-  (list @t)
  :~  'inc'  'llc'  'ltd'  'co'  'corp'  'company'  'bank'  'club'  'church'  'school'
      'storage'  'support'  'services'  'service'  'group'  'team'  'billing'  'insurance'
      'store'  'shop'  'market'  'office'  'dept'  'department'  'associates'  'partners'
      'clinic'  'center'  'centre'
  ==
++  person-key
  |=  n=@t
  ^-  (set @t)
  =/  ks=(set @t)  (sy (tokens n))
  (~(dif in ks) role-words)
::  +same-person: every word of the shorter name is in the longer one,
::  and a one-word name is a first name, not a role: "dana" and "dana
::  quill" are one person, "dana" and "daniel quill" are not, and "wife"
::  names nobody
::
++  same-person
  |=  [a=@t b=@t]
  ^-  ?
  =/  ka=(set @t)  (person-key a)
  =/  kb=(set @t)  (person-key b)
  ?:  |(=(~ ka) =(~ kb))  |
  =/  a-short=?  (lte ~(wyt in ka) ~(wyt in kb))
  =/  short=(set @t)  ?:(a-short ka kb)
  =/  long=(set @t)  ?:(a-short kb ka)
  ?.  =(~ (~(dif in short) long))  |
  ?.  =(1 ~(wyt in short))  &
  =/  first=(list @t)  (skip (tokens ?:(a-short a b)) |=(w=@t (~(has in role-words) w)))
  =/  other=(list @t)  (skip (tokens ?:(a-short b a)) |=(w=@t (~(has in role-words) w)))
  ?:  |(?=(~ first) ?=(~ other))  |
  =(i.first i.other)
::  +name-words: the words of a name, letters with ' . - inside
::
++  name-words
  |=  t=tape
  ^-  (list tape)
  =|  out=(list tape)
  |-
  ?~  t  (flop out)
  ?.  (is-letter i.t)  $(t t.t)
  =/  w=tape  ~[i.t]
  =/  r=tape  t.t
  |-
  ?:  &(?=(^ r) |((is-letter i.r) =('\'' i.r) =('.' i.r) =('-' i.r)))
    $(r t.r, w [i.r w])
  ^$(t r, out [(flop w) out])
::  +person-named: a person, or an org whose name reads like a person's
::
++  person-named
  |=  b=body
  ^-  ?
  ?:  =(%person kind.b)  &
  ?.  =(%org kind.b)  |
  =/  words=(list tape)  (name-words (trip name.b))
  =/  n=@ud  (lent words)
  ?.  &((gte n 2) (lte n 3))  |
  ?.  (levy words |=(w=tape &((gte (snag 0 w) 'A') (lte (snag 0 w) 'Z'))))  |
  !(lien words |=(w=tape (~(has in org-words) (crip (cass w)))))
::  +capword: a leading Capitalised word and the rest, when the title
::  starts with one and a word boundary follows
::
++  capword
  |=  t=tape
  ^-  (unit [word=tape rest=tape])
  ?~  t  ~
  ?.  &((gte i.t 'A') (lte i.t 'Z'))  ~
  =/  rest=tape  t.t
  =|  acc=tape
  |-
  ?:  &(?=(^ rest) (gte i.rest 'a') (lte i.rest 'z'))  $(rest t.rest, acc [i.rest acc])
  ?~  acc  ~
  ?:  &(?=(^ rest) (is-alnum i.rest))  ~
  `[[i.t (flop acc)] rest]
::  +names-in: the names a title is certain about, and a leading first
::  name to check against the people the ship knows. "Mira- Ballet/Tap"
::  is certain of Mira, "Theo and Juno- Opti Sail" of both, "Felix
::  Birthday" of Felix; "Felix Fencing Lesson" only says Felix if the
::  ship already has a Felix.
::
++  names-in
  |=  title=@t
  ^-  [sure=(list @t) lead=(unit @t)]
  =/  t=tape  (trim-tape (trip title))
  =/  first=(unit [word=tape rest=tape])  (capword t)
  ?~  first  [~ ~]
  =/  w1=@t  (crip word.u.first)
  =/  rest=tape  rest.u.first
  =/  dash=(unit (list @t))
    =/  r2=tape  ?:(&(?=(^ rest) =(',' i.rest)) t.rest rest)
    =/  second=(unit [word=tape rest=tape])
      ?.  =(" and " (scag 5 r2))  ~
      (capword (slag 5 r2))
    =/  names=(list @t)  ?~(second ~[w1] ~[w1 (crip word.u.second)])
    =/  r3=tape  (skip-spaces ?~(second rest rest.u.second))
    ?.  &(?=(^ r3) =('-' i.r3))  ~
    =/  r4=tape  t.r3
    ?.  &(?=(^ r4) |(=(' ' i.r4) =(9 i.r4)))  ~
    ?~  (skip-spaces r4)  ~
    `names
  ?^  dash  [u.dash ~]
  =/  bday=?
    =/  r=tape  ?:(=("'s" (scag 2 rest)) (slag 2 rest) rest)
    ?.  &(?=(^ r) |(=(' ' i.r) =(9 i.r)))  |
    =/  r2=tape  (skip-spaces r)
    ?.  =("birthday" (cass (scag 8 r2)))  |
    =/  r3=tape  (slag 8 r2)
    |(?=(~ r3) !(is-alnum i.r3))
  ?:  bday  [~[w1] ~]
  [~ `w1]
::  +cal-uid: the calendar uid an occurrence id carries
::  (situation/cal-<...><uuid>[-suffix]), or ~
::
++  is-hex  |=(c=@ ^-(? |((is-digit c) &((gte c 'a') (lte c 'f')))))
++  is-uuid
  |=  t=tape
  ^-  ?
  ?.  =(36 (lent t))  |
  =/  i=@ud  0
  |-
  ?~  t  &
  ?:  |(=(i 8) =(i 13) =(i 18) =(i 23))
    &(=('-' i.t) $(t t.t, i +(i)))
  &((is-hex i.t) $(t t.t, i +(i)))
++  cal-uid
  |=  id=bid
  ^-  (unit @t)
  =/  t=tape  (trip id)
  ?.  =("situation/cal-" (scag 14 t))  ~
  =/  rest=tape  (slag 10 t)
  =/  n=@ud  (lent rest)
  =/  i=@ud  4
  |-
  ?:  (gth (add i 36) n)  ~
  ?.  (is-uuid (scag 36 (slag i rest)))  $(i +(i))
  =/  tail=tape  (slag (add i 36) rest)
  ?.  |(?=(~ tail) =('-' i.tail))  $(i +(i))
  `(crip (scag (add i 36) rest))
::  +common-title: the title most of a group carries, ties to the shortest
::
++  common-title
  |=  names=(list @t)
  ^-  @t
  =/  counts=(map @t @ud)
    %+  roll  names
    |=  [n=@t acc=(map @t @ud)]
    ?:  =('' n)  acc
    (~(put by acc) n +((fall (~(get by acc) n) 0)))
  =/  ranked=(list [n=@t c=@ud])
    %+  sort  ~(tap by counts)
    |=  [a=[n=@t c=@ud] b=[n=@t c=@ud]]
    ?:  =(c.a c.b)  (lth (met 3 n.a) (met 3 n.b))
    (gth c.a c.b)
  ?~(ranked '' n.i.ranked)
++  status-word  |=(t=@t ^-(? |(=('open' t) =('closed' t) =('cancelled' t))))
::  +timed: a situation's started or ended (or starts, ends) as a time:
::  the winner, else the timeline's row when the fold hides a future one
::
++  timed
  |=  [l=loaded winners=(map @t (list row)) attr=@t]
  ^-  (unit @da)
  =/  v=@t  (winner-text winners attr)
  ?.  =('' v)  (de-iso v)
  =/  rs=(list row)
    (skim rows.l |=(r=row &(!retracted.obs.r =(attr attr.obs.r) ?=([%s *] value.obs.r))))
  ?~  rs  ~
  ?.  ?=([%s *] value.obs.i.rs)  ~
  (de-iso p.value.obs.i.rs)
::  ==  the passes
::
::  +plan-times: the schedule is not the fact. A future started or ended
::  becomes starts or ends, dated when it was learned; a starts or ends
::  dated in the future is re-dated now; a situation status that is not
::  open, closed or cancelled goes; an activity's next that has passed
::  goes, and the nearest occurrence still ahead takes its place.
::
++  plan-times
  |=  [all=(list loaded) now=@da]
  ^-  (list json)
  =|  retracts=(list json)
  =|  writes=(list json)
  =/  rest=(list loaded)  all
  |-
  ?~  rest  (weld (flop retracts) (observe-ops ~ (flop writes)))
  =/  l=loaded  i.rest
  =/  live=(list row)  (skip rows.l |=(r=row retracted.obs.r))
  ?:  =(%activity kind.body.l)
    =/  ahead=(list @da)
      %+  sort
        %+  murn  live
        |=  r=row
        ^-  (unit @da)
        ?.  &(=('last' attr.obs.r) ?=([%s *] value.obs.r))  ~
        =/  v=(unit @da)  (de-iso p.value.obs.r)
        ?~  v  ~
        ?:((gth u.v now) v ~)
      lth
    =/  stale=(list row)
      %+  skim  live
      |=  r=row
      ?.  &(=('next' attr.obs.r) ?=([%s *] value.obs.r))  |
      =/  v=(unit @da)  (de-iso p.value.obs.r)
      ?~(v | (lte u.v now))
    =/  rs=(list json)
      (turn stale |=(r=row (retract-op id.r 'reconcile: this occurrence has passed')))
    =/  ws=(list json)
      ?~  ahead  ~
      %+  turn  stale
      |=  r=row
      (obs-row id.l 'next' s+(en-iso i.ahead) now `(add i.ahead ~d1) 90 ['reconcile' (cat 3 'times/' id.r)] 'reconcile')
    $(rest t.rest, retracts (weld (flop rs) retracts), writes (weld (flop ws) writes))
  ?.  =(%situation kind.body.l)  $(rest t.rest)
  =/  got=[rs=(list json) ws=(list json)]
    %+  roll  live
    |=  [r=row acc=[rs=(list json) ws=(list json)]]
    =/  learned=@da  ?:((lte at.obs.r now) at.obs.r now)
    =/  a=@t  attr.obs.r
    =/  src=source  ['reconcile' (cat 3 'times/' id.r)]
    =/  sv=(unit @da)  ?.(?=([%s *] value.obs.r) ~ (de-iso p.value.obs.r))
    ?:  &(|(=('started' a) =('ended' a)) ?=(^ sv) (gth u.sv now))
      :-  [(retract-op id.r 'reconcile: a future time is a schedule, not a fact') rs.acc]
      [(obs-row id.l ?:(=('started' a) 'starts' 'ends') s+(en-iso u.sv) learned ~ conf.obs.r src 'reconcile') ws.acc]
    ?:  &(|(=('starts' a) =('ends' a)) ?=([%s *] value.obs.r) (gth at.obs.r now))
      :-  [(retract-op id.r 'reconcile: a schedule is known when it was learned') rs.acc]
      [(obs-row id.l a value.obs.r now ~ conf.obs.r src 'reconcile') ws.acc]
    ?:  &(=('status' a) ?=([%s *] value.obs.r) !(status-word (lower p.value.obs.r)))
      [[(retract-op id.r 'reconcile: a situation is open, closed or cancelled; the times say the rest') rs.acc] ws.acc]
    acc
  $(rest t.rest, retracts (weld rs.got retracts), writes (weld ws.got writes))
::  +plan-activities: situations that are occurrences of one repeating
::  event become one activity each, with an observation per occurrence
::  (its started, or its starts when it is still ahead, as the calendar
::  pipe writes it), and the occurrences are deleted. A calendar uid groups occurrences
::  whatever they were called; without one, only identical titles group;
::  groups whose common title normalises alike are one activity.
::
++  plan-activities
  |=  [all=(list loaded) multi=(set @t) now=@da min=@ud]
  ^-  [ops=(list json) made=(list bid)]
  =/  ids=(set @t)  (sy (turn all |=(l=loaded id.l)))
  =/  cands=(list loaded)
    (skim all |=(l=loaded &(=(%situation kind.body.l) !(is-trip id.l))))
  =/  groups=(map @t (list loaded))
    %+  roll  cands
    |=  [l=loaded acc=(map @t (list loaded))]
    =/  key=@t
      =/  uid=(unit @t)  (cal-uid id.l)
      ?^  uid  (cat 3 'uid:' u.uid)
      (cat 3 'title:' (strict-key name.body.l))
    (~(put by acc) key (snoc (fall (~(get by acc) key) ~) l))
  =/  by-title=(map @t (list loaded))
    %+  roll  ~(tap by groups)
    |=  [[key=@t members=(list loaded)] acc=(map @t (list loaded))]
    =/  t=@t  (normalize-title (common-title (turn members |=(l=loaded (trim-cord name.body.l)))))
    (~(put by acc) t (weld (fall (~(get by acc) t) ~) members))
  =/  titles=(list [t=@t members=(list loaded)])
    (sort ~(tap by by-title) |=([a=[t=@t *] b=[t=@t *]] (aor t.a t.b)))
  %+  roll  titles
  |=  [[t=@t members=(list loaded)] acc=[ops=(list json) made=(list bid)]]
  ?:  |(=('' t) (lth (lent members) (max 1 min)))  acc
  =/  plan  (activity-plan t members ids multi now)
  [(weld ops.acc ops.plan) (snoc made.acc aid.plan)]
++  activity-plan
  |=  [t=@t members=(list loaded) ids=(set @t) multi=(set @t) now=@da]
  ^-  [ops=(list json) aid=bid]
  =.  members  (sort members |=([a=loaded b=loaded] (aor id.a id.b)))
  =/  names=(list @t)  (turn members |=(l=loaded (trim-cord name.body.l)))
  =/  name=@t  (common-title names)
  =/  other-set=(set @t)  (sy (skip names |=(n=@t |(=('' n) =(n name)))))
  =/  others=(list @t)  (sort ~(tap in other-set) aor)
  =/  uid-set=(set @t)  (sy (murn members |=(l=loaded (cal-uid id.l))))
  =/  uids=(list @t)  (sort ~(tap in uid-set) aor)
  =/  aid=bid  (cat 3 'activity/' (slug t))
  =/  aliases=(list @t)  (scag max-aliases (weld others uids))
  =/  bod=json
    %-  pairs:enjs:format
    %-  zing
    :~  ~[['id' s+aid] ['name' s+name]]
        ?~(aliases ~ ~[['aliases' a+(turn aliases |=(a=@t `json`s+a))]])
    ==
  =/  occ=(list [l=loaded start=(unit @da) end=(unit @da) w=(map @t (list row))])
    %+  turn  members
    |=  l=loaded
    =/  w=(map @t (list row))  (fold rows.l multi now)
    =/  st=(unit @da)  (timed l w 'started')
    =/  en=(unit @da)  (timed l w 'ended')
    [l ?^(st st (timed l w 'starts')) ?^(en en (timed l w 'ends')) w]
  =/  starts=(list @da)
    (sort (murn occ |=(o=[l=loaded start=(unit @da) *] start.o)) lth)
  =/  base=@da  ?~(starts now i.starts)
  =/  src0=source  ['reconcile' ?~(members '' id.i.members)]
  =/  last-rows=(list json)
    %+  murn  occ
    |=  o=[l=loaded start=(unit @da) end=(unit @da) w=*]
    ^-  (unit json)
    ?~  start.o  ~
    `(obs-row aid 'last' s+(en-iso u.start.o) u.start.o ~ 90 ['reconcile' (cat 3 'reconcile/' id.l.o)] 'reconcile')
  =/  ahead=(list [at=@da end=(unit @da) src=@t])
    %+  sort
      %+  murn  occ
      |=  o=[l=loaded start=(unit @da) end=(unit @da) w=*]
      ^-  (unit [at=@da end=(unit @da) src=@t])
      ?~  start.o  ~
      ?.  (gth u.start.o now)  ~
      `[u.start.o end.o (cat 3 'reconcile/' id.l.o)]
    |=([a=[at=@da *] b=[at=@da *]] (lth at.a at.b))
  =/  next-rows=(list json)
    ?~  ahead  ~
    :_  ~
    %-  obs-row
    :*  aid  'next'  s+(en-iso at.i.ahead)  now
        `(fall end.i.ahead (add at.i.ahead ~d1))  90
        ['reconcile' src.i.ahead]  'reconcile'
    ==
  =/  location=@t
    =/  ls=(list @t)
      %+  skip  (turn occ |=(o=[* * * w=(map @t (list row))] (winner-text w.o 'location')))
      |=(x=@t =('' x))
    ?~(ls '' i.ls)
  =/  parts=(list bid)
    =/  raw=(list bid)
      %-  zing
      %+  turn  occ
      |=(o=[* * * w=(map @t (list row))] (refs-in (fall (~(get by w.o) 'participants') ~)))
    =|  seen=(set bid)
    =|  out=(list bid)
    |-
    ?~  raw  (flop out)
    ?:  (~(has in seen) i.raw)  $(raw t.raw)
    $(raw t.raw, seen (~(put in seen) i.raw), out [i.raw out])
  =/  rows=(list json)
    %-  zing
    :~  ~[(obs-row aid 'status' s+'active' base ~ 90 src0 'reconcile')]
        last-rows
        next-rows
        ?:(=('' location) ~ ~[(obs-row aid 'location' s+location base ~ 90 src0 'reconcile')])
        %+  turn  parts
        |=(p=bid (obs-row aid 'participants' (pairs:enjs:format ~[['ref' s+p]]) base ~ 90 src0 'reconcile'))
    ==
  :_  aid
  %+  weld  (observe-ops ?:((~(has in ids) aid) ~ ~[bod]) rows)
  (turn members |=(l=loaded (delete-op id.l)))
::  +plan-participants: people the titles of activities and situations
::  name, the person bodies to create for the ones the ship lacks, and
::  the participants rows to write on each titled body
::
++  plan-participants
  |=  [all=(list loaded) multi=(set @t) now=@da]
  ^-  [ops=(list json) made=@ud rows=@ud]
  =/  people=(list loaded)  (skim all |=(l=loaded =(%person kind.body.l)))
  =/  titled=(list loaded)  (skim all |=(l=loaded ?=(?(%activity %situation) kind.body.l)))
  =/  words=(list [word=@t id=bid])
    %-  zing
    %+  turn  people
    |=(l=loaded (turn [name.body.l ~(tap in aliases.body.l)] |=(w=@t [w id.l])))
  =/  known=(map @t bid)
    %+  roll  words
    |=  [[word=@t id=bid] acc=(map @t bid)]
    =/  k=(set @t)  (person-key word)
    ?:  =(1 ~(wyt in k))
      =/  w=@t  (snag 0 `(list @t)`~(tap in k))
      ?:((~(has by acc) w) acc (~(put by acc) w id))
    ?:  =(~ k)  acc
    =/  firsts=(list @t)  (skip (tokens word) |=(w=@t (~(has in role-words) w)))
    ?~  firsts  acc
    ?:((~(has by acc) i.firsts) acc (~(put by acc) i.firsts id))
  =/  sure-names=(list @t)  (zing (turn titled |=(l=loaded sure:(names-in name.body.l))))
  =/  certain=(map @t @t)
    %+  roll  sure-names
    |=  [n=@t acc=(map @t @t)]
    =/  low=@t  (lower n)
    ?:((~(has by acc) low) acc (~(put by acc) low n))
  =/  todo=(list [low=@t n=@t])
    (sort ~(tap by certain) |=([a=[low=@t *] b=[low=@t *]] (aor low.a low.b)))
  =|  creates=(list json)
  |-
  ?^  todo
    ?:  (~(has by known) low.i.todo)  $(todo t.todo)
    =/  pid=bid  (cat 3 'person/' (slug n.i.todo))
    %=  $
      todo     t.todo
      known    (~(put by known) low.i.todo pid)
      creates  (snoc creates (pairs:enjs:format ~[['id' s+pid] ['name' s+n.i.todo]]))
    ==
  =/  rows=(list json)
    %-  zing
    %+  turn  titled
    |=  l=loaded
    ^-  (list json)
    =/  ni  (names-in name.body.l)
    =/  who=(list bid)
      ?^  sure.ni  (murn sure.ni |=(n=@t (~(get by known) (lower n))))
      ?~  lead.ni  ~
      (drop (~(get by known) (lower u.lead.ni)))
    =/  have=(set bid)
      (sy (refs-in (fall (~(get by (fold rows.l multi now)) 'participants') ~)))
    %+  murn  who
    |=  pid=bid
    ^-  (unit json)
    ?:  (~(has in have) pid)  ~
    :-  ~
    %-  obs-row
    :*  id.l  'participants'  (pairs:enjs:format ~[['ref' s+pid]])
        created.body.l  ~  85  ['reconcile' (cat 3 'title/' id.l)]  'reconcile'
    ==
  [(observe-ops creates rows) (lent creates) (lent rows)]
::  +plan-people: merge proposals, (from, into, why), the surer body as
::  into: a person wins over an org, an older body over a newer one,
::  and person/me is never merged away
::
++  plan-people
  |=  [all=(list loaded) multi=(set @t) now=@da]
  ^-  (list [from=bid into=bid why=@t])
  =/  people=(list [l=loaded ids=(set @t)])
    %+  murn  all
    |=  l=loaded
    ^-  (unit [l=loaded ids=(set @t)])
    ?.  (person-named body.l)  ~
    `[l (sy (identity-values (fold rows.l multi now)))]
  =|  seen=(set [@t @t])
  =|  out=(list [from=bid into=bid why=@t])
  =/  rest=(list [l=loaded ids=(set @t)])  people
  |-
  ?~  rest  (flop out)
  =/  a  i.rest
  =/  others  t.rest
  |-
  ?~  others  ^$(rest t.rest)
  =/  b  i.others
  =/  shared=(set @t)  (~(int in ids.a) ids.b)
  =/  na=@t  name.body.l.a
  =/  nb=@t  name.body.l.b
  =/  why=@t
    ?.  =(~ shared)
      (cat 3 'same ' (join-cords ', ' (sort ~(tap in shared) aor)))
    ?:  ?|  (same-person na nb)
            (lien ~(tap in aliases.body.l.b) |=(x=@t (same-person na x)))
            (lien ~(tap in aliases.body.l.a) |=(x=@t (same-person nb x)))
        ==
      (rap 3 'the names match: ' na ' and ' nb ~)
    ''
  ?:  =('' why)  $(others t.others)
  =/  swap=?
    ?:  &(!=(%person kind.body.l.a) =(%person kind.body.l.b))  &
    &(=(kind.body.l.a kind.body.l.b) (lth created.body.l.b created.body.l.a))
  =/  pair=[from=loaded into=loaded]  ?:(swap [l.a l.b] [l.b l.a])
  =?  pair  =('person/me' id.from.pair)  [into.pair from.pair]
  =/  key=[@t @t]  [id.from.pair id.into.pair]
  ?:  (~(has in seen) key)  $(others t.others)
  %=  $
    others  t.others
    seen    (~(put in seen) key)
    out     [[id.from.pair id.into.pair why] out]
  ==
::  +merge-decided: what the owner already decided about each merge
::  pair: done, dismissed, open or failed, a merge that ran winning and
::  a dismissal sticking over an open re-proposal. A dismissal reconcile
::  made itself (a body in the pair was gone) is nobody's decision.
::
++  merge-decided
  |=  acts=(list [id=@ta a=action])
  ^-  (map (set @t) @t)
  =/  seen=(map (set @t) (set @t))
    %+  roll  acts
    |=  [[id=@ta a=action] acc=(map (set @t) (set @t))]
    ?.  =(%merge kind.a)  acc
    =/  key=(set @t)  (sy `(list @t)`~[(gs payload.a 'from') (gs payload.a 'into')])
    =/  last-by=@t  ?~(history.a '' by:(rear history.a))
    =/  st=@t
      ?:  (is-open a)  'open'
      ?:  &(=(%dismissed status.a) =('reconcile' last-by))  'stale'
      status.a
    (~(put by acc) key (~(put in (fall (~(get by acc) key) ~)) st))
  %-  ~(run by seen)
  |=  sts=(set @t)
  ^-  @t
  ?:  (~(has in sts) 'done')  'done'
  ?:  (~(has in sts) 'dismissed')  'dismissed'
  ?:  (~(has in sts) 'open')  'open'
  'failed'
::  +people-ops: the ops for the proposals: a pair dismissed before is
::  left alone (and any open re-proposal dismissed), a pair merged before
::  is merged again at once (a reader recreated the duplicate), a pair
::  already open waits, and the rest are filed as merge actions. Open
::  merge actions about a body that is gone are dismissed.
::
++  people-ops
  |=  [props=(list [from=bid into=bid why=@t]) acts=(list [id=@ta a=action]) now=@da]
  ^-  [ops=(list json) proposed=@ud]
  =/  past=(map (set @t) @t)  (merge-decided acts)
  =/  open=(list [id=@ta a=action])  (skim acts |=([* a=action] &(=(%merge kind.a) (is-open a))))
  =/  dismiss-open
    |=  [key=(set @t) why=@t]
    ^-  (list json)
    %+  murn  open
    |=  [id=@ta a=action]
    ^-  (unit json)
    ?.  =(key (sy `(list @t)`~[(gs payload.a 'from') (gs payload.a 'into')]))  ~
    `(set-action-op id 'dismissed' why)
  %+  roll  props
  |=  [[from=bid into=bid why=@t] acc=[ops=(list json) proposed=@ud]]
  =/  key=(set @t)  (sy `(list @t)`~[from into])
  =/  was=@t  (fall (~(get by past) key) '')
  ?:  =('dismissed' was)
    [(weld ops.acc (dismiss-open key 'reconcile: dismissed before')) proposed.acc]
  ?:  =('done' was)
    :_  proposed.acc
    (weld ops.acc [(merge-op from into) (dismiss-open key 'reconcile: merged again as approved before')])
  ?:  =('open' was)  acc
  =/  act=json
    %-  pairs:enjs:format
    :~  ['kind' s+'merge']
        ['title' s+(rap 3 'Merge ' from ' into ' into ~)]
        ['about' a+`(list json)`~[s+from s+into]]
        ['payload' (pairs:enjs:format ~[['from' s+from] ['into' s+into] ['why' s+why]])]
    ==
  =/  op=json
    (pairs:enjs:format ~[['op' s+'act'] ['action' (fill-act-as act now 'reconcile')]])
  [(snoc ops.acc op) +(proposed.acc)]
::  +people-pass: the stale dismissals, then the proposals' ops
::
++  people-pass
  |=  [all=(list loaded) acts=(list [id=@ta a=action]) multi=(set @t) now=@da]
  ^-  [ops=(list json) proposed=@ud]
  =/  ids=(set @t)  (sy (turn all |=(l=loaded id.l)))
  =/  stale=(list json)
    %+  murn  (skim acts |=([* a=action] &(=(%merge kind.a) (is-open a))))
    |=  [id=@ta a=action]
    ^-  (unit json)
    ?:  &((~(has in ids) (gs payload.a 'from')) (~(has in ids) (gs payload.a 'into')))  ~
    `(set-action-op id 'dismissed' 'reconcile: a body in this pair is gone')
  =/  got  (people-ops (plan-people all multi now) acts now)
  [(weld stale ops.got) proposed.got]
::  +approved-merges: the merge actions the owner approved, for the
::  fiber to claim, run and report
::
++  approved-merges
  |=  acts=(list [id=@ta a=action])
  ^-  (list [id=@ta from=bid into=bid])
  %+  murn  acts
  |=  [id=@ta a=action]
  ^-  (unit [id=@ta from=bid into=bid])
  ?.  &(=(%merge kind.a) ?=(?(%approved %claimed) status.a))  ~
  `[id (gs payload.a 'from') (gs payload.a 'into')]
::  +plan-prune: closed situations that ended more than days ago, to
::  delete; off while days is 0
::
++  plan-prune
  |=  [all=(list loaded) multi=(set @t) now=@da days=@ud]
  ^-  (list bid)
  ?:  =(0 days)  ~
  =/  cut=@da  (sub now (mul days ~d1))
  %+  murn  all
  |=  l=loaded
  ^-  (unit bid)
  ?.  =(%situation kind.body.l)  ~
  =/  w=(map @t (list row))  (fold rows.l multi now)
  ?.  =('closed' (winner-text w 'status'))  ~
  =/  end=(unit @da)
    =/  e=(unit @da)  (timed l w 'ended')
    ?^(e e (timed l w 'ends'))
  =/  latest=@da
    %+  roll  rows.l
    |=([r=row acc=@da] ?:(retracted.obs.r acc (max seen.obs.r acc)))
  =/  when=@da  ?^(end u.end (max latest created.body.l))
  ?:((lth when cut) `id.l ~)
::  +analyst-prompt: orrery-utils/common/analyst-prompt.md, word for
::  word; scripts/prompt-drift.py holds it there. Edit the file, not this.
::
++  analyst-prompt
  ^-  @t
  '''
  You turn messages into facts for orrery, a model of one person's world.
  Three shapes exist.
  A body is something that exists: a person, place, thing, org, situation, activity or note. Its id is kind/slug, lowercase letters, digits and hyphens, for example person/sarah, place/johns-machine-shop, thing/subaru, situation/2026-09-16-breakdown.
  An observation is one claim about one body: subject.attr = value, with when it became true. Values are a short string, a number, true or false, null (which clears the attribute), or {"ref": "kind/slug"} pointing at another body.
  An action is something to do: a task with a title, the bodies it is about, and an optional due time; or, when a message fixes a plan in time ("dinner Friday at 8", "dentist on the 3rd at 2:30"), a calendar event, kind "calendar", with a payload of title, starts and, when the message says, ends and location, the times ISO 8601 with the message's offset. The situation body records the plan as a fact; the calendar action asks the owner to put it on the calendar; when a message fixes a time, write both, and when it does not, write neither. Or a message to send, kind "message", when the conversation asks the owner something they would answer, or someone should be told what the messages just settled: payload via (the channel the conversation is on, one of the values the schema lists, unless the message says to use another), to (the person's body id) and text, short, in the owner's own voice. Never a message telling someone what they just said, and never one the owner already sent. Propose only the action kinds listed for you, with the payload shape given.
  Rules.
  Only state what the messages say or clearly imply. Never invent. When unsure, leave it out or lower the confidence.
  Use the existing bodies by id whenever a message refers to one of them, by name or alias. When a message calls an existing body by a name the list does not have ("next door" for place/neighbors, "the Hendersons"), repeat that body in "bodies" with the new name under "aliases", so the ship learns the word. Create a new body only for a named person, place, thing or org, or for a situation (an event with participants) the messages describe.
  Use only the attribute names listed for that kind; an observation on any other name is dropped. When a kind has no attributes listed, use a short lowercase name. A health fact goes on "health" and a money fact on "income", never on a name of your own.
  Read the notes given with the attribute names: they say what each one means. A person's "status" is what they are doing or dealing with right now, in plain words, as an observer would put it: "on jury duty", "stranded, waiting for a tow", "travelling", "sick". It is never a feeling, a quote or a wish. A feeling goes under "mood", which the reader throws away, so that it never lands on status. A status is specific enough that someone who reads only it knows what is going on: "training for the Chicago marathon", not "on a strict regimen"; "in meetings", not "busy". When the messages do not say what it is, write no status. A status that ends at a stated time carries "until".
  Worked examples. "jury duty makes me want to scream", from Sarah: person/sarah.status = "on jury duty" (conf 80), person/sarah.mood = "frustrated" (conf 60, discarded). "car died on route 9, stranded waiting for a tow": status = "stranded, waiting for a tow", location = "Route 9", thing/subaru.status = "broken down". "stuck in meetings till 11:30", from Sarah at 2026-08-19T10:03:00-04:00: person/sarah.status = "in meetings", until = "2026-08-19T11:30:00-04:00". "ugh, Mondays": nothing.
  A situation body carries participants (one observation per participant, value {"ref": ...}), location, and its times: "starts" and "ends" are the schedule (a meeting on December 5 has starts and ends on December 5, even today), "started" and "ended" are facts about what happened, written only once it has. Its status is "open" or "closed" (or "cancelled"), nothing else: never "upcoming", "under way" or "over", which are read off the times. A situation happens once: a breakdown, a birthday, a delivery.
  An activity is something that repeats: a class, a practice, a standing appointment, a weekly meeting. It is one body of kind activity, with schedule ("Mon/Wed 18:00"), cadence ("weekly"), location, participants and organizer. An occurrence of an activity is never a new body: write the activity's "last" = the start of that occurrence, with "at" = that start, and "next" = the start of the following one when the message says it. A calendar reminder or notification for a repeating event is an occurrence of an activity, not a situation.
  Any part of an event can name a person: its title ("Mira- Ballet/Tap", "Theo and Juno- Opti Sail", "Felix Birthday"), its description ("bring Juno's helmet"), its attendee list, its organizer ("Coach Pat"), a note. Every person an event names is a participant of the activity or situation, and its organizer is its organizer. Resolve each name against the people listed; when nobody by that name exists, create the person, the first name (or the full name when the event gives it) as the body's name. A production, a team or a place is not a person: "Swan Lake rehearsal" and "Hornets practice" name no one.
  A person is never an org. A payment request, a reminder or a note from a person names a person body; reuse the existing person when the name or the address matches, even when only the first name is on record.
  "at" is when the fact became true, ISO 8601 with the offset the message times carry (they are in the owner's time zone), and defaults to the message's time; set it only when the message says otherwise. "until" is when it will stop being true, when the message says so.
  "conf" is 0 to 100: 90 for a plain statement, 60 for an inference, 40 for a guess.
  Each observation and action names the "message" id it comes from.
  Messages marked as earlier context are there so you understand the new ones: a reply, a pronoun, a mood that carries over. Write facts only from the new messages; anything you write from a context message is thrown away.
  Answer with one JSON object and nothing else:
  {"bodies": [{"id": "kind/slug", "name": "...", "aliases": ["..."]}],
   "observations": [{"subject": "kind/slug", "attr": "...", "value": ..., "at": "...", "until": "...", "conf": 90, "message": "..."}],
   "actions": [{"kind": "task", "title": "...", "about": ["kind/slug"], "due": "...", "message": "..."},
               {"kind": "calendar", "title": "...", "about": ["kind/slug"], "payload": {"title": "...", "starts": "...", "ends": "...", "location": "..."}, "message": "..."},
               {"kind": "message", "title": "...", "about": ["person/slug"], "payload": {"via": "...", "to": "person/slug", "text": "..."}, "message": "..."}]}
  Empty lists are fine. Small talk, greetings and things already known produce nothing.
  '''
::  ==  telegram reader (version 29): the settings, the update, the window
::
::  gate and escalate are thresholds in hundredths, since a JSON 0.3 is a
::  cord the ship would otherwise have to parse as a fraction
+$  tg-config
  $:  enabled=?
      token=@t
      secret=@t
      api-url=@t
      public-url=@t
      model=@t
      max-tokens=@ud
      chats=(set @t)
      people=(map @t @t)
      gate=@ud
      escalate=@ud
      max-daily=@ud
  ==
::  +hundredths: a JSON number (0.3, "0.6", 1) as hundredths, 0 to 100.
::  A value at or above 1 is already hundredths, so 30 stays 30 and the
::  page can read a threshold back and write it again unchanged; 0.3 is
::  a fraction and becomes 30. 1 is one hundredth: a caller who means
::  always sends 100.
::
++  hundredths
  |=  [j=json default=@ud]
  ^-  @ud
  =/  t=@t
    ?:  ?=([%n *] j)  p.j
    ?:  ?=([%s *] j)  p.j
    ''
  ?:  =('' t)  default
  =/  micro=@ud  (micro-of t)
  ?:  (gte micro 1.000.000)  (min 100 (div micro 1.000.000))
  (min 100 (div micro 10.000))
::  +de-tg-config: the stored telegram.json as the reader's settings. A
::  chat id arrives as a number or a string and is kept as text either
::  way, since a chat id is a name, not a quantity.
::
++  de-tg-config
  |=  j=json
  ^-  tg-config
  =/  chats=(set @t)
    %-  sy
    ^-  (list @t)
    %+  turn  (ga j 'chats')
    |=  c=json
    ^-  @t
    ?:  ?=([%s *] c)  p.c
    ?:  ?=([%n *] c)  p.c
    ''
  =/  people=(map @t @t)
    =/  p=json  (gj j 'people')
    ?.  ?=([%o *] p)  ~
    %-  ~(gas by *(map @t @t))
    ^-  (list [@t @t])
    %+  murn  ~(tap by p.p)
    |=  [k=@t v=json]
    ^-  (unit [@t @t])
    ?.(?=([%s *] v) ~ `[k p.v])
  :*  =/(e (gj j 'enabled') ?:(?=([%b *] e) p.e |))
      (gs j 'token')
      (gs j 'secret')
      =/(u (gs j 'api_url') ?:(=('' u) 'https://api.telegram.org' u))
      (gs j 'public_url')
      =/(m (gs j 'model') ?:(=('' m) 'deepseek/deepseek-v4-flash' m))
      (fall (gn j 'max_tokens') 4.000)
      (~(del in chats) '')
      people
      (hundredths (gj j 'gate') 30)
      (hundredths (gj j 'escalate') 60)
      (fall (gn j 'max_daily_messages') 500)
  ==
::  +en-tg-config-masked: what the owner reads back. The bot token and
::  the webhook secret are written once and never served again: only
::  whether each is set.
::
++  en-tg-config-masked
  |=  c=tg-config
  ^-  json
  %-  pairs:enjs:format
  :~  ['enabled' b+enabled.c]
      ['token_set' b+!=('' token.c)]
      ['secret_set' b+!=('' secret.c)]
      ['api_url' s+api-url.c]
      ['public_url' s+public-url.c]
      ['model' s+model.c]
      ['max_tokens' (numb:enjs:format max-tokens.c)]
      ['chats' a+(turn ~(tap in chats.c) |=(c=@t `json`s+c))]
      ['people' [%o (~(run by people.c) |=(v=@t `json`s+v))]]
      ['gate' (numb:enjs:format gate.c)]
      ['escalate' (numb:enjs:format escalate.c)]
      ['max_daily_messages' (numb:enjs:format max-daily.c)]
  ==
::  the update, as far as the reader reads it
+$  tg-msg  [chat=@t from=@t text=@t at=@da mid=@t business=@t]
++  tg-message
  |=  update=json
  ^-  (unit tg-msg)
  =/  biz=json  (gj update 'business_message')
  =/  msg=json  ?:(?=([%o *] biz) biz (gj update 'message'))
  ?.  ?=([%o *] msg)  ~
  =/  num
    |=  j=json
    ^-  @t
    ?:  ?=([%n *] j)  p.j
    ?:  ?=([%s *] j)  p.j
    ''
  =/  chat=@t  (num (gj (gj msg 'chat') 'id'))
  =/  from=@t  (num (gj (gj msg 'from') 'id'))
  ?:  |(=('' chat) =('' from))  ~
  =/  secs=@ud  (fall (gn msg 'date') 0)
  :-  ~
  :*  chat
      from
      (crip (trim-tape (trip (gs msg 'text'))))
      (add ~1970.1.1 (mul secs ~s1))
      (num (gj msg 'message_id'))
      ?:(?=([%o *] biz) (gs msg 'business_connection_id') '')
  ==
++  tg-source
  |=  m=tg-msg
  ^-  source
  ['chat' (rap 3 'telegram/' chat.m '/' mid.m ~)]
::  +tg-window: a chat's last free-text messages, oldest first, as the
::  analyst's context rows
++  tg-window
  |=  [recent=json chat=@t]
  ^-  (list [id=@t at=@t who=@t text=@t])
  %+  murn  (ga recent chat)
  |=  r=json
  ^-  (unit [id=@t at=@t who=@t text=@t])
  =/  id=@t  (gs r 'id')
  ?:(=('' id) ~ `[id (gs r 'at') (gs r 'who') (gs r 'text')])
::  +tg-remember: the window with this message appended: commands and
::  empty text never go in, five per chat, nothing older than a day
++  tg-remember
  |=  [recent=json m=tg-msg who=@t now=@da]
  ^-  json
  =/  base=(map @t json)  ?:(?=([%o *] recent) p.recent ~)
  ?:  |(=('' text.m) =('/' (end [3 1] text.m)))  [%o base]
  =/  cutoff=@da  (sub now ~d1)
  =/  kept=(list json)
    %+  skip  (ga recent chat.m)
    |=  r=json
    =/  at=(unit @da)  (de-iso (gs r 'at'))
    ?~(at & (lth u.at cutoff))
  =/  row=json
    %-  pairs:enjs:format
    :~  ['id' s+id:(tg-source m)]
        ['at' s+(en-iso at.m)]
        ['who' s+who]
        ['text' s+(end [3 2.000] text.m)]
    ==
  =/  all=(list json)  (snoc kept row)
  =/  n=@ud  (lent all)
  [%o (~(put by base) chat.m a+(slag (sub n (min n 5)) all))]
::  what one message says: bodies and observation rows for the writer,
::  action rows, notes to answer with, and, when the analyst calls for
::  it, the ids for an urgent pass (~ means no escalation)
+$  tg-facts
  $:  bodies=(list json)
      obs=(list json)
      acts=(list json)
      notes=(list @t)
      escalate=(unit (list @t))
  ==
::  +urgent-ids: analyze.urgent_ids: what the urgent pass looks at
::  first: the situations the kept facts are about (the bodies made in
::  the same batch count), else the things, places and orgs they are
::  about, since a situation the model titled in its own words does not
::  survive grounding; unique, in order, at most five. Empty is fine:
::  the pass still runs.
::
++  urgent-ids
  |=  facts=tg-facts
  ^-  (list @t)
  =/  subjects=(list @t)
    %+  weld  (turn obs.facts |=(o=json (gs o 'subject')))
    (turn bodies.facts |=(b=json (gs b 'id')))
  =/  sits=(list @t)  (dedupe (skim subjects |=(s=@t =('situation' (kind-of s)))))
  ?.  =(~ sits)  (scag 5 sits)
  %+  scag  5
  (dedupe (skim subjects |=(s=@t ?=(?(%thing %place %org) (kind-of s)))))
::  +tg-obs: one observation row in the writer's shape, signed telegram
::
++  tg-obs
  |=  [m=tg-msg subject=@t attr=@t value=json conf=@ud]
  ^-  json
  (obs-row subject attr value at.m ~ conf (tg-source m) 'telegram')
::  +parse-value: a command's value: a body id becomes a ref, "-" and
::  "null" become null, else the text
::
++  parse-value
  |=  t=@t
  ^-  json
  ?:  |(=('-' t) =('null' t))  ~
  ?^  (parse-bid t)  (pairs:enjs:format ~[['ref' s+t]])
  s+t
::  +tg-command: the slash grammar, as the bot has it; ~ for free text.
::  A trailing @botname on the command word is ignored, so /at@orrbot
::  works in a group. Unlike the bot, /obs takes a body id for its
::  subject: the writer would drop a name it cannot resolve.
::
++  tg-command
  |=  [m=tg-msg who=@t]
  ^-  (unit tg-facts)
  ?.  =('/' (end [3 1] text.m))  ~
  =/  ws=(list tape)  (split-ws (trip text.m))
  ?~  ws  ~
  =/  cmd=@t  (crip (cass (scag (fall (find "@" i.ws) (lent i.ws)) i.ws)))
  =/  rest=@t  (crip (join-tapes " " t.ws))
  =/  usage  |=(u=@t ^-((unit tg-facts) `[~ ~ ~ ~[u] ~]))
  ?:  =('/at' cmd)
    ?:  =('' rest)  (usage 'usage: /at <place>')
    `[~ ~[(tg-obs m who 'location' (parse-value rest) 100)] ~ ~ ~]
  ?:  =('/status' cmd)
    ?:  =('' rest)  (usage 'usage: /status <text>, or /status - to clear')
    `[~ ~[(tg-obs m who 'status' ?:(=('-' rest) ~ s+rest) 100)] ~ ~ ~]
  ?:  =('/obs' cmd)
    =/  parts=(list tape)  t.ws
    ?:  (lth (lent parts) 3)  (usage 'usage: /obs <subject> <attr> <value>')
    =/  subject=@t  (crip (snag 0 parts))
    ?~  (parse-bid subject)
      (usage 'usage: /obs <kind>/<slug> <attr> <value>')
    =/  attr=@t  (crip (cass (snag 1 parts)))
    ?.  (ok-attr attr)  (usage 'attr must be lowercase letters, digits and hyphens')
    =/  value=@t  (crip (join-tapes " " (slag 2 parts)))
    `[~ ~[(tg-obs m subject attr (parse-value value) 100)] ~ ~ ~]
  ?:  =('/task' cmd)
    ?:  =('' rest)  (usage 'usage: /task <title> [due YYYY-MM-DD]')
    =/  parts=(list tape)  t.ws
    =/  n=@ud  (lent parts)
    =/  due=(unit @t)
      ?.  (gte n 3)  ~
      ?.  =("due" (cass (snag (sub n 2) parts)))  ~
      =/  d=tape  (snag (dec n) parts)
      ?.  =(10 (lent d))  ~
      =/  full=@t  (crip (weld d "T00:00:00Z"))
      ?~((de-iso full) ~ `full)
    =/  title=@t
      ?~  due  rest
      (crip (join-tapes " " (scag (sub n 2) parts)))
    =/  act=json
      %-  pairs:enjs:format
      %-  zing
      :~  ~[['kind' s+'task'] ['title' s+(end [3 200] title)]]
          ?~(due ~ ~[['due' s+u.due]])
      ==
    `[~ ~ ~[act] ~ ~]
  (usage 'commands: /at, /status, /obs, /task')
::  ==  the reader's context and prompt
::
::  what the model is told the ship already knows: a body per line, the
::  schema's attribute names and what they mean, the owner, and the
::  action kinds it may propose with their payload shapes
::
+$  ctx-body  [id=@t name=@t aliases=(list @t)]
+$  reader-ctx
  $:  bodies=(list ctx-body)
      attrs=(map @t (list @t))
      notes=(map @t (map @t @t))
      me=@t
      kinds=(list @t)
      payloads=(map @t json)
  ==
::  one message in the prompt's window; context marks an earlier one,
::  shown for sense but not to be written from
::
+$  window-row  [id=@t at=@t who=@t text=@t context=?]
::  +reader-kinds: what a message may propose, in the order the prompt
::  names them. Home actions are the generator's.
::
++  reader-kinds  `(list @t)`~['task' 'calendar' 'message']
::  +reader-context: the context block from the loaded bodies and the
::  schema
::
++  reader-context
  |=  [all=(list loaded) schema=json now=@da]
  ^-  reader-ctx
  =/  multi=(set @t)  (multi-of schema)
  =/  cutoff=@da  (sub now ~d30)
  =/  bodies=(list ctx-body)
    %-  scag  :-  300
    %+  murn  all
    |=  l=loaded
    ^-  (unit ctx-body)
    ?:  &(=(%situation kind.body.l) (closed-before l multi cutoff now))  ~
    `[id.l name.body.l (sort ~(tap in aliases.body.l) aor)]
  =/  kinds-j=json  (gj schema 'kinds')
  =/  attrs=(map @t (list @t))
    ?.  ?=([%o *] kinds-j)  ~
    %-  ~(run by p.kinds-j)
    |=(spec=json (strings (ga spec 'attrs')))
  =/  notes=(map @t (map @t @t))
    ?.  ?=([%o *] kinds-j)  ~
    %-  ~(gas by *(map @t (map @t @t)))
    %+  murn  ~(tap by p.kinds-j)
    |=  [k=@t spec=json]
    ^-  (unit [@t (map @t @t)])
    =/  n=json  (gj spec 'notes')
    ?.  ?=([%o *] n)  ~
    :-  ~
    :-  k
    %-  ~(gas by *(map @t @t))
    ^-  (list [@t @t])
    (murn ~(tap by p.n) |=([a=@t v=json] ?.(?=([%s *] v) ~ `[a p.v])))
  =/  listed=(set @t)  (sy (strings (ga schema 'actions')))
  =/  kinds=(list @t)
    =/  k=(list @t)  (skim reader-kinds |=(x=@t (~(has in listed) x)))
    ?~(k ~['task'] k)
  =/  payloads=(map @t json)
    =/  p=json  (gj schema 'payloads')
    ?.  ?=([%o *] p)  ~
    %-  ~(gas by *(map @t json))
    (skim ~(tap by p.p) |=([k=@t v=json] &(?=([%o *] v) (lien kinds |=(x=@t =(x k))))))
  [bodies attrs notes 'person/me' kinds payloads]
::  +closed-before: a situation closed, with its end before the cutoff.
::  A new message does not refer to something long over.
::
++  closed-before
  |=  [l=loaded multi=(set @t) cutoff=@da now=@da]
  ^-  ?
  =/  w=(map @t (list row))  (fold rows.l multi now)
  ?.  =('closed' (winner-text w 'status'))  |
  =/  e=(unit @da)  (timed l w 'ended')
  =/  end=(unit @da)  ?^(e e (timed l w 'ends'))
  ?~(end (lth created.body.l cutoff) (lth u.end cutoff))
::  +reader-prompt: the user prompt, line for line as analyze.prompt
::  writes it
::
++  reader-prompt
  |=  [rows=(list window-row) ctx=reader-ctx tz=@t]
  ^-  @t
  =/  head=(list @t)
    :~  'Channel: telegram'
        (cat 3 'The owner is ' (cat 3 me.ctx '.'))
    ==
  =/  attr-lines=(list @t)
    ?:  =(~ attrs.ctx)  ~
    :-  'Attribute names by kind:'
    %+  turn  (sort ~(tap by attrs.ctx) |=([a=[@t *] b=[@t *]] (aor -.a -.b)))
    |=([k=@t names=(list @t)] (rap 3 '  ' k ': ' (join-cords ', ' names) ~))
  =/  note-lines=(list @t)
    ?:  =(~ notes.ctx)  ~
    :-  'What the attributes mean:'
    %-  zing
    %+  turn  (sort ~(tap by notes.ctx) |=([a=[@t *] b=[@t *]] (aor -.a -.b)))
    |=  [k=@t ns=(map @t @t)]
    ^-  (list @t)
    %+  turn  (sort ~(tap by ns) |=([a=[@t *] b=[@t *]] (aor -.a -.b)))
    |=([a=@t t=@t] (rap 3 '  ' k '.' a ': ' t ~))
  =/  kind-lines=(list @t)
    :-  (cat 3 'Action kinds you may propose: ' (join-cords ', ' kinds.ctx))
    %+  turn  (sort ~(tap by payloads.ctx) |=([a=[@t *] b=[@t *]] (aor -.a -.b)))
    |=([k=@t shape=json] (rap 3 '  ' k ' payload: ' (en:json:html shape) ~))
  =/  body-lines=(list @t)
    :-  'Existing bodies (id | name | aliases):'
    ?~  bodies.ctx  `(list @t)`~['  (none known)']
    %+  turn  bodies.ctx
    |=(b=ctx-body (rap 3 '  ' id.b ' | ' name.b ' | ' (join-cords ', ' aliases.b) ~))
  =/  earlier=(list window-row)  (skim rows |=(r=window-row context.r))
  =/  fresh=(list window-row)  (skip rows |=(r=window-row context.r))
  =/  line
    |=  [r=window-row tag=@t]
    ^-  @t
    (rap 3 '--- ' tag ' ' id.r ' | ' (local-iso at.r tz) ' | from ' who.r ~)
  =/  msg-lines=(list @t)
    %-  zing
    ^-  (list (list @t))
    :~  ?~  earlier  `(list @t)`~['Messages, oldest first:']
        :-  'Earlier messages, context only, oldest first (write no facts from these):'
        %-  zing
        (turn earlier |=(r=window-row `(list @t)`~[(line r 'context') (end [3 8.000] text.r)]))
      ::
        ?~(earlier `(list @t)`~ `(list @t)`~['New messages, oldest first:'])
      ::
        %-  zing
        (turn fresh |=(r=window-row `(list @t)`~[(line r 'message') (end [3 8.000] text.r)]))
      ::
        `(list @t)`~['---' 'Answer with the JSON object.']
    ==
  %+  join-cords  nl
  ;:  weld  head  attr-lines  note-lines  kind-lines  body-lines  `(list @t)`~['']  msg-lines  ==
::  ==  the reader's validation: the model's answer as facts the ship
::  will take, with notes on what was dropped (analyze.validate)
::
++  sink-attrs       `(set @t)`(sy `(list @t)`~['mood' 'feeling' 'feelings' 'emotion'])
++  sensitive-attrs  `(set @t)`(sy `(list @t)`~['health' 'income'])
++  body-kinds       `(set @t)`(sy `(list @t)`~['person' 'place' 'thing' 'org' 'situation' 'note' 'activity'])
::  +kind-of: the kind half of a body id, '' when it has no slash
::
++  kind-of  |=(id=@t ^-(@t (end [3 (fall (find "/" (trip id)) 0)] id)))
::  +canon-id: a body id as the fold of duplicate bodies renamed it
::
++  canon-id  |=([alias=(map @t @t) id=@t] ^-(@t (fall (~(get by alias) id) id)))
::  +only-ref: an object whose one key is ref
::
++  only-ref
  |=  v=json
  ^-  ?
  ?.  ?=([%o *] v)  |
  =/  ks=(list @t)  ~(tap in ~(key by p.v))
  ?~  ks  |
  ?.  ?=(~ t.ks)  |
  =('ref' i.ks)
++  ref-cord  |=(v=json ^-(@t (ref-or-text (gj v 'ref'))))
::  +dedupe: a list with its later repeats gone, order kept
::
++  dedupe
  |=  xs=(list @t)
  ^-  (list @t)
  =|  seen=(set @t)
  =|  out=(list @t)
  |-
  ?~  xs  (flop out)
  ?:  (~(has in seen) i.xs)  $(xs t.xs)
  $(xs t.xs, seen (~(put in seen) i.xs), out [i.xs out])
::  +filled: a payload key python would call truthy
::
++  filled
  |=  u=(unit json)
  ^-  ?
  ?~  u  |
  =/  v=json  u.u
  ?~  v  |
  ?-  -.v
    %s  !=('' p.v)
    %n  !=('0' p.v)
    %b  p.v
    %a  ?=(^ p.v)
    %o  !=(~ p.v)
  ==
::  +no-seconds: a YYYY-MM-DDTHH:MM head with nothing but a zone after it
::
++  no-seconds
  |=  s=tape
  ^-  ?
  ?.  (gte (lent s) 16)  |
  ?:  =(16 (lent s))  &
  =/  c=@tD  (snag 16 s)
  |(=('+' c) =('-' c) =('Z' c) =('z' c))
::  +de-iso-any: analyze.iso_or_none's parse: a bare date, a naive time,
::  a Z time or one with a +HH:MM offset, as a @da in UTC. A time with
::  no seconds gets :00, which is how python's fromisoformat reads it.
::
++  de-iso-any
  |=  t=@t
  ^-  (unit @da)
  =/  s=tape  (trim-tape (trip t))
  ?:  (is-iso-date s)  (de-iso (crip (weld s "T00:00:00Z")))
  =?  s  (no-seconds s)  (weld `tape`(scag 16 s) (weld ":00" `tape`(slag 16 s)))
  ?.  (gte (lent s) 19)  ~
  =/  when=(unit @da)  (de-iso (crip (weld `tape`(scag 19 s) "Z")))
  ?~  when  ~
  =/  zone=tape
    =/  r=tape  (slag 19 s)
    |-  ^-  tape
    ?~  r  ~
    ?:  |(=('.' i.r) (is-digit i.r))  $(r t.r)
    r
  ?~  zone  when
  ?:  |(=('Z' i.zone) =('z' i.zone))  when
  ?.  |(=('+' i.zone) =('-' i.zone))  ~
  =/  digits=tape  (skip `tape`t.zone |=(c=@tD =(':' c)))
  ?.  (is-digits digits)  ~
  ?.  |(=(2 (lent digits)) =(4 (lent digits)))  ~
  =/  hh=@ud  (rash (crip (scag 2 digits)) dem)
  =/  mm=@ud  ?:(=(2 (lent digits)) 0 (rash (crip (slag 2 digits)) dem))
  =/  off=@dr  `@dr`(add (mul hh ~h1) (mul mm ~m1))
  ?:  =('-' i.zone)  `(add u.when off)
  ?:((lth u.when off) ~ `(sub u.when off))
::  +iso-or-none: a JSON string as orrery writes a time, or ~
::
++  iso-or-none
  |=  j=json
  ^-  (unit @t)
  ?.  ?=([%s *] j)  ~
  =/  d=(unit @da)  (de-iso-any p.j)
  ?~(d ~ `(en-iso u.d))
::  +clean-value: analyze.clean_value: a value orrery accepts, or why
::  it is refused
::
++  clean-value
  |=  v=json
  ^-  (each json @t)
  ?~  v  [%& ~]
  ?-  -.v
      %b  [%& v]
      %n  [%& v]
      %s  [%& `json`s+(end [3 2.000] (trim-cord p.v))]
      %a
    ?:  (lte (met 3 (en:json:html v)) 2.000)  [%& v]
    [%| 'value over 2000 bytes']
      %o
    ?:  (only-ref v)
      =/  r=@t  (ref-cord v)
      ?~  (parse-bid r)  [%| (cat 3 'ref is not a body id: ' r)]
      [%& (pairs:enjs:format ~[['ref' s+r]])]
    ?:  (lte (met 3 (en:json:html v)) 2.000)  [%& v]
    [%| 'value over 2000 bytes']
  ==
::  +one-of: the values a payload key admits, read off its schema line
::  ("required: one of telegram, mail, chat"), or ~ when it is free
::
++  one-of
  |=  shape=@t
  ^-  (list @t)
  =/  s=tape  (trip shape)
  =/  at=(unit @ud)  (find "one of" s)
  ?~  at  ~
  =/  rest=tape  (slag (add u.at 6) s)
  %+  murn  (split-ws (turn rest |=(c=@tD ^-(@tD ?:(=(',' c) ' ' c)))))
  |=(w=tape ^-((unit @t) ?:(|(?=(~ w) =("or" w)) ~ `(crip w))))
::  +fixes-a-time: a day, a date or an hour in the words
::  (analyze.FIXES_A_TIME)
::
++  fixes-a-time
  |=  text=@t
  ^-  ?
  =/  clean=(list tape)  (turn (split-ws (cass (trip text))) strip-punct-tail)
  =/  words=(set @t)  (sy (turn clean crip))
  ?:  (lien `(list @t)`~['noon' 'midnight' 'tonight' 'tomorrow' 'today'] |=(w=@t (~(has in words) w)))  &
  =/  days=(list tape)
    :~  "mon"  "monday"  "tue"  "tues"  "tuesday"  "wed"  "wednes"  "wednesday"
        "thu"  "thurs"  "thursday"  "fri"  "friday"  "sat"  "satur"  "saturday"
        "sun"  "sunday"
    ==
  ?:  (lien clean |=(t=tape (lien days |=(d=tape =(d t)))))  &
  ?:  (lien clean |=(t=tape |((is-time-token t) (is-slash-date t))))  &
  ?:  (lien clean |=(t=tape &((gte (lent t) 4) (is-clock t))))  &
  =/  ordinal
    |=  t=tape
    ^-  ?
    ?.  &((gte (lent t) 3) (lte (lent t) 4))  |
    ?.  (is-digits (scag (sub (lent t) 2) t))  |
    (lien `(list tape)`~["st" "nd" "rd" "th"] |=(s=tape =(s (slag (sub (lent t) 2) t))))
  ?:  (lien clean ordinal)  &
  =/  rest=(list tape)  clean
  |-
  ?~  rest  |
  ?~  t.rest  |
  =/  a=tape  i.rest
  =/  b=tape  i.t.rest
  ?:  &(=("at" a) (is-clock b))  &
  ?:  &((has-head a month-heads) (is-digits b) (lte (lent b) 2))  &
  ?:  &((is-clock a) |(=("am" b) =("pm" b)))  &
  $(rest t.rest)
::  +plan-problem: analyze.plan_problem: why a calendar action does not
::  stand against its message, or ~; ends and location are pruned by
::  +hold-plan once the plan stands
::
++  plan-problem
  |=  [payload=(map @t json) text=@t at=@t]
  ^-  (unit @t)
  ?.  (fixes-a-time text)  `'the message fixes no time'
  =/  words=(set @t)  (sy (skim (tokens text) |=(w=@t (gte (met 3 w) 3))))
  =/  title=json  (fall (~(get by payload) 'title') `json`~)
  =/  title-words=(list @t)  (skim (tokens (ref-or-text title)) |=(w=@t (gte (met 3 w) 3)))
  ?.  (lien title-words |=(w=@t (~(has in words) w)))
    `'the title is not in the message\'s words'
  =/  start=(unit @da)  (de-iso-any (ref-or-text (fall (~(get by payload) 'starts') `json`~)))
  ?~  start  `'starts is not a time'
  =/  when=@da  (fall (de-iso-any at) u.start)
  ?:  |((lth u.start (sub when ~h6)) (gth u.start (add when ~d366)))
    `'starts is not within the year ahead of the message'
  ~
::  +hold-plan: the payload with ends and location kept only as the
::  rules allow: an end after the start and within a fortnight, a place
::  the message says
::
++  hold-plan
  |=  [payload=(map @t json) text=@t]
  ^-  (map @t json)
  =/  start=(unit @da)  (de-iso-any (ref-or-text (fall (~(get by payload) 'starts') `json`~)))
  =/  end=(unit @da)  (de-iso-any (ref-or-text (fall (~(get by payload) 'ends') `json`~)))
  =.  payload
    ?:  ?&  ?=(^ start)  ?=(^ end)
            (gth u.end u.start)
            (lte u.end (add u.start ~d14))
        ==
      payload
    (~(del by payload) 'ends')
  =/  loc=@t  (ref-or-text (fall (~(get by payload) 'location') `json`~))
  ?:  &(!=('' loc) ?=(^ (find (trip (lower loc)) (trip (lower text)))))  payload
  (~(del by payload) 'location')
::  +find-ctx: a context body by id
::
++  find-ctx
  |=  [bodies=(list ctx-body) id=@t]
  ^-  (unit ctx-body)
  ?~  bodies  ~
  ?:(=(id id.i.bodies) `i.bodies $(bodies t.bodies))
::  +existing-for: analyze.existing_for: a situation or activity with
::  the same normalised title, or the one person the same words name
::
++  existing-for
  |=  [b=ctx-body pool=(list ctx-body) made=(list ctx-body)]
  ^-  (unit @t)
  =/  all=(list ctx-body)  (weld pool made)
  =/  kind=@t  (kind-of id.b)
  ?:  |(=('situation' kind) =('activity' kind))
    =/  key=@t  (normalize-title name.b)
    ?:  =('' key)  ~
    =/  hit=(list ctx-body)
      %+  skim  all
      |=  x=ctx-body
      =/  k=@t  (kind-of id.x)
      &(|(=('situation' k) =('activity' k)) =(key (normalize-title name.x)))
    ?~(hit ~ `id.i.hit)
  ?.  =('person' kind)  ~
  =/  hits=(list ctx-body)
    %+  skim  all
    |=  x=ctx-body
    ?.  =('person/' (end [3 7] id.x))  |
    ?|  (same-person name.b name.x)
        (lien aliases.x |=(a=@t (same-person name.b a)))
    ==
  ?~  hits  ~
  ?:  =(1 (lent `(list ctx-body)`hits))  `id.i.hits
  =/  flat  |=(n=@t ^-(@t (crip (join-tapes " " (split-ws (cass (trip n)))))))
  =/  exact=(list ctx-body)
    %+  skim  `(list ctx-body)`hits
    |=  x=ctx-body
    |(=((flat name.x) (flat name.b)) (lien aliases.x |=(a=@t =((flat a) (flat name.b)))))
  ?~  exact  ~
  ?:(=(1 (lent `(list ctx-body)`exact)) `id.i.exact ~)
::  +validate-bodies: the bodies an answer proposes, with the ids a
::  duplicate folds into. known and the fold grow as bodies are taken,
::  so the observations and actions that follow see them
::
++  validate-bodies
  |=  [raw=(list json) ctx=reader-ctx known=(set @t)]
  ^-  [bodies=(list json) known=(set @t) alias=(map @t @t) notes=(list @t)]
  =|  out=(list json)
  =|  alias=(map @t @t)
  =|  notes=(list @t)
  =/  made=(list ctx-body)  ~
  |-
  ?~  raw  [(flop out) known alias (flop notes)]
  =/  b=json  i.raw
  ?.  ?=([%o *] b)  $(raw t.raw)
  =/  bid=@t  (lower (trim-cord (gs b 'id')))
  =/  pk  (parse-bid bid)
  ?~  pk  $(raw t.raw, notes [(cat 3 'dropped body with a bad id: ' bid) notes])
  ?.  (~(has in body-kinds) `@t`kind.u.pk)
    $(raw t.raw, notes [(cat 3 'dropped body of an unknown kind: ' bid) notes])
  =/  aliases=(list @t)
    %+  scag  32
    %+  murn  (ga b 'aliases')
    |=  a=json
    ^-  (unit @t)
    ?.  ?=([%s *] a)  ~
    =/  t=@t  (trim-cord p.a)
    ?:(=('' t) ~ `(end [3 100] t))
  ?:  (~(has in known) bid)
    =/  have=(set @t)
      =/  hit=(unit ctx-body)  (find-ctx bodies.ctx bid)
      ?~(hit ~ (~(put in (sy aliases.u.hit)) name.u.hit))
    =/  fresh=(list @t)  (skip aliases |=(a=@t (~(has in have) a)))
    ?~  fresh  $(raw t.raw)
    =/  row=json
      %-  pairs:enjs:format
      :~  ['id' s+bid]
          ['aliases' a+(turn `(list @t)`fresh |=(a=@t `json`s+a))]
      ==
    $(raw t.raw, out [row out])
  =/  name=@t
    =/  n=@t  (trim-cord (gs b 'name'))
    ?.  =('' n)  (end [3 200] n)
    (crip (turn (trip `@t`slug.u.pk) |=(c=@tD ^-(@tD ?:(=('-' c) ' ' c)))))
  =/  cb=ctx-body  [bid name aliases]
  =/  twin=(unit @t)  (existing-for cb bodies.ctx made)
  ?^  twin
    %=  $
      raw    t.raw
      alias  (~(put by alias) bid u.twin)
      notes  [(rap 3 bid ' is ' u.twin ~) notes]
    ==
  =/  row=json
    %-  pairs:enjs:format
    %-  zing
    :~  ~[['id' s+bid] ['name' s+name]]
        ?~(aliases ~ ~[['aliases' a+(turn `(list @t)`aliases |=(a=@t `json`s+a))]])
    ==
  %=  $
    raw    t.raw
    out    [row out]
    known  (~(put in known) bid)
    made   (snoc made cb)
  ==
::  +validate-obs: the observations an answer proposes, in the writer's
::  shape, with a note for each one dropped
::
++  validate-obs
  |=  $:  raw=(list json)
          ctx=reader-ctx
          known=(set @t)
          alias=(map @t @t)
          ids=(list @t)
          context-ids=(set @t)
          at-of=(map @t @t)
          last=@t
      ==
  ^-  [obs=(list json) notes=(list @t)]
  =/  new-ids=(set @t)  (sy ids)
  =|  out=(list json)
  =|  notes=(list @t)
  |-
  ?~  raw  [(flop out) (flop notes)]
  =/  o=json  i.raw
  ?.  ?=([%o *] o)  $(raw t.raw)
  =/  subject=@t  (canon-id alias (lower (trim-cord (gs o 'subject'))))
  =/  attr=@t  (lower (trim-cord (gs o 'attr')))
  =/  value=json
    =/  v=json  (gj o 'value')
    ?.  (only-ref v)  v
    (pairs:enjs:format ~[['ref' s+(canon-id alias (lower (trim-cord (ref-cord v))))]])
  ?.  (~(has in known) subject)
    $(raw t.raw, notes [(cat 3 'dropped observation on an unknown body: ' subject) notes])
  ?.  (ok-attr attr)
    $(raw t.raw, notes [(cat 3 'dropped observation with a bad attr: ' attr) notes])
  ?:  ?&  =('situation/' (end [3 10] subject))
          =('status' attr)
          !(lien `(list @t)`~['open' 'closed' 'cancelled'] |=(s=@t =(s (lower (ref-or-text value)))))
      ==
    =/  why=@t
      %+  rap  3
      :~  'dropped '  subject  '.status = '  (ref-or-text value)
          ': a situation is open, closed or cancelled; the times say the rest'
      ==
    $(raw t.raw, notes [why notes])
  ?:  (~(has in sink-attrs) attr)  $(raw t.raw)
  =/  msg-raw=@t  (gs o 'message')
  ?:  (~(has in context-ids) msg-raw)  $(raw t.raw)
  =/  kind=@t  (kind-of subject)
  =/  listed=(list @t)  (fall (~(get by attrs.ctx) kind) `(list @t)`~)
  ?:  &(?=(^ listed) !(lien `(list @t)`listed |=(a=@t =(a attr))))
    =/  why=@t
      ?:  (~(has in sensitive-attrs) attr)  'the owner\'s policy keeps it from keys'
      (cat 3 'not an attribute of ' kind)
    $(raw t.raw, notes [(rap 3 'dropped ' subject '.' attr ': ' why ~) notes])
  =/  clean=(each json @t)  (clean-value value)
  ?:  ?=([%| *] clean)
    $(raw t.raw, notes [(rap 3 'dropped ' subject '.' attr ': ' p.clean ~) notes])
  =/  msg=@t  ?:((~(has in new-ids) msg-raw) msg-raw last)
  =/  at=@t
    =/  given=(unit @t)  (iso-or-none (gj o 'at'))
    ?^(given u.given (fall (~(get by at-of) msg) ''))
  =/  conf=@ud
    =/  n=(unit @ud)  (gn o 'conf')
    ?^  n  (min 100 u.n)
    ::  python's int() reads "80" and 80.5 as numbers, where gn reads
    ::  neither: a string and a fraction are still a confidence
    =/  v=json  (gj o 'conf')
    =/  t=@t
      ?:  ?=([%s *] v)  (trim-cord p.v)
      ?:  ?=([%n *] v)  p.v
      ''
    ?.  &(!=('' t) (is-digit (end [3 1] t)))  70
    (min 100 (div (micro-of t) 1.000.000))
  =/  until=(unit @t)  (iso-or-none (gj o 'until'))
  =/  row=json
    %-  pairs:enjs:format
    %-  zing
    :~  :~  ['subject' s+subject]
            ['attr' s+attr]
            ['value' p.clean]
            ['at' s+at]
            ['conf' (numb:enjs:format conf)]
            ['message' s+msg]
        ==
        ?~(until ~ ~[['until' s+u.until]])
    ==
  $(raw t.raw, out [row out])
::  +hold-payload: a payload held to its kind's shape: times as ISO
::  8601 UTC, the required keys present, a key fixed to a list holding
::  one of its words, and a recipient that is a body the ship has
::
++  hold-payload
  |=  [pay=(map @t json) shape=json known=(set @t) alias=(map @t @t)]
  ^-  (each (map @t json) @t)
  =/  spec=(list [k=@t v=json])
    %+  sort  ~(tap by ?:(?=([%o *] shape) p.shape ~))
    |=([a=[@t json] b=[@t json]] (aor -.a -.b))
  =/  iso-done=(map @t json)
    =/  rest=(list [k=@t v=json])  spec
    =/  acc=(map @t json)  pay
    |-  ^-  (map @t json)
    ?~  rest  acc
    =/  v=json  v.i.rest
    ?.  ?&  ?=([%s *] v)
            ?=(^ (find "ISO 8601" (trip p.v)))
            (filled (~(get by acc) k.i.rest))
        ==
      $(rest t.rest)
    =/  n=(unit @t)  (iso-or-none (fall (~(get by acc) k.i.rest) `json`~))
    ?~  n  $(rest t.rest)
    $(rest t.rest, acc (~(put by acc) k.i.rest s+u.n))
  =/  missing=(list @t)
    %+  murn  spec
    |=  [k=@t v=json]
    ^-  (unit @t)
    ?.  ?=([%s *] v)  ~
    ?.  =('required' (end [3 8] p.v))  ~
    ?:((filled (~(get by iso-done) k)) ~ `k)
  ?^  missing  [%| (cat 3 'payload lacks ' (join-cords ', ' missing))]
  =/  left=(list [k=@t v=json])  spec
  =/  held=(map @t json)  iso-done
  =|  bad=(unit @t)
  |-
  ?~  left  ?^(bad [%| u.bad] [%& held])
  =/  k=@t  k.i.left
  =/  v=json  v.i.left
  =/  cur=(unit json)  (~(get by held) k)
  =/  allowed=(list @t)  ?:(?=([%s *] v) (one-of p.v) ~)
  ?:  &(?=(^ allowed) (filled cur))
    =/  lv=@t  (lower (trim-cord (ref-or-text (need cur))))
    ?:  (lien `(list @t)`allowed |=(x=@t =(x lv)))
      $(left t.left, held (~(put by held) k s+lv))
    %=  $
      left  t.left
      held  (~(put by held) k s+lv)
      bad   `(rap 3 k ' is ' lv ', not one of ' (join-cords ', ' `(list @t)`allowed) ~)
    ==
  ?:  ?&  =('to' k)
          ?=([%s *] v)
          ?=(^ (find "body id" (trip p.v)))
          (filled cur)
      ==
    =/  cv=@t  (canon-id alias (lower (trim-cord (ref-or-text (need cur)))))
    ?:  (~(has in known) cv)
      $(left t.left, held (~(put by held) k s+cv))
    %=  $
      left  t.left
      held  (~(put by held) k s+cv)
      bad   `(cat 3 'to names a body that does not exist: ' cv)
    ==
  $(left t.left)
::  +validate-acts: the actions an answer proposes, with a note for
::  each one dropped. A calendar action must stand against its own
::  message, and only one plan comes from one message
::
++  validate-acts
  |=  $:  raw=(list json)
          ctx=reader-ctx
          known=(set @t)
          alias=(map @t @t)
          ids=(list @t)
          context-ids=(set @t)
          at-of=(map @t @t)
          text-of=(map @t @t)
          last=@t
      ==
  ^-  [acts=(list json) notes=(list @t)]
  =/  new-ids=(set @t)  (sy ids)
  =/  kind-list=(list @t)  ?~(kinds.ctx ~['task'] kinds.ctx)
  =/  kinds=(set @t)  (sy kind-list)
  =|  out=(list json)
  =|  notes=(list @t)
  =|  planned=(set @t)
  |-
  ?~  raw  [(flop out) (flop notes)]
  =/  a=json  i.raw
  ?.  ?=([%o *] a)  $(raw t.raw)
  =/  kind=@t
    =/  k=@t  (lower (trim-cord (gs a 'kind')))
    ?:(=('' k) 'task' k)
  =/  title=@t  (end [3 200] (trim-cord (gs a 'title')))
  =/  msg-raw=@t  (gs a 'message')
  ?:  (~(has in context-ids) msg-raw)  $(raw t.raw)
  ?:  |(!(~(has in kinds) kind) =('' title))
    =/  shown=@t  ?:(=('' title) '(no title)' title)
    $(raw t.raw, notes [(cat 3 'dropped action: ' shown) notes])
  =/  about=(list @t)
    %+  scag  20
    %-  dedupe
    %+  skim
      %+  turn  (ga a 'about')
      |=(x=json ^-(@t (canon-id alias (lower (trim-cord (ref-or-text x))))))
    |=(x=@t (~(has in known) x))
  =/  msg=@t  ?:((~(has in new-ids) msg-raw) msg-raw last)
  =/  due=(unit @t)  (iso-or-none (gj a 'due'))
  =/  pay=(map @t json)
    =/  p=json  (gj a 'payload')
    ?:(?=([%o *] p) p.p ~)
  =/  got=(each (map @t json) @t)
    (hold-payload pay (fall (~(get by payloads.ctx) kind) `json`~) known alias)
  ?:  ?=([%| *] got)
    $(raw t.raw, notes [(rap 3 'dropped action ' title ': ' p.got ~) notes])
  =/  payload=(map @t json)  p.got
  =/  text=@t  (fall (~(get by text-of) msg) '')
  =/  cal-why=@t
    ?.  =('calendar' kind)  ''
    =/  why=(unit @t)  (plan-problem payload text (fall (~(get by at-of) msg) ''))
    ?^  why  u.why
    ?:((~(has in planned) msg) 'a second plan from one message' '')
  ?.  =('' cal-why)
    $(raw t.raw, notes [(rap 3 'dropped action ' title ': ' cal-why ~) notes])
  =.  payload  ?.(=('calendar' kind) payload (hold-plan payload text))
  =/  row=json
    %-  pairs:enjs:format
    %-  zing
    :~  :~  ['kind' s+kind]
            ['title' s+title]
            ['about' a+(turn about |=(x=@t `json`s+x))]
            ['message' s+msg]
        ==
        ?~(due ~ ~[['due' s+u.due]])
        ?:(=(~ payload) ~ ~[['payload' [%o payload]]])
    ==
  %=  $
    raw      t.raw
    out      [row out]
    planned  ?:(=('calendar' kind) (~(put in planned) msg) planned)
  ==
::  +validate-reader: analyze.validate: the model's answer as the facts
::  orrery will take, with notes on what was dropped. Escalation is the
::  analyst's call, not the validator's, so it is left empty here
::
++  validate-reader
  |=  [answer=json rows=(list window-row) ctx=reader-ctx]
  ^-  tg-facts
  =/  known=(set @t)  (sy (turn bodies.ctx |=(b=ctx-body id.b)))
  =/  ids=(list @t)  (turn (skip rows |=(r=window-row context.r)) |=(r=window-row id.r))
  =/  context-ids=(set @t)
    (sy (turn (skim rows |=(r=window-row context.r)) |=(r=window-row id.r)))
  =/  at-of=(map @t @t)  (~(gas by *(map @t @t)) (turn rows |=(r=window-row [id.r at.r])))
  =/  text-of=(map @t @t)  (~(gas by *(map @t @t)) (turn rows |=(r=window-row [id.r text.r])))
  =/  last=@t  ?~(ids '' (rear `(list @t)`ids))
  =/  vb  (validate-bodies (ga answer 'bodies') ctx known)
  =/  vo  (validate-obs (ga answer 'observations') ctx known.vb alias.vb ids context-ids at-of last)
  =/  va
    (validate-acts (ga answer 'actions') ctx known.vb alias.vb ids context-ids at-of text-of last)
  [bodies.vb obs.vo acts.va :(weld notes.vb notes.vo notes.va) ~]
::  ==  the reader's grounding: the facts a message bears out (bot.grounded)
::
::  a small model writes what it remembers as readily as what it read, so
::  a chat fact has to be traceable to its message. Words that put a
::  message in its author's mouth, and words that point at someone else:
::  a message with the second and none of the first is about someone
::  else, whoever sent it ("grandpa's flight got cancelled", from Sarah)
::
++  first-person
  `(set @t)`(sy `(list @t)`~['i' 'i\'m' 'im' 'i\'ve' 'i\'ll' 'i\'d' 'me' 'my' 'mine' 'myself' 'we' 'we\'re' 'we\'ve' 'we\'ll' 'us' 'our' 'ours'])
++  someone-else
  `(set @t)`(sy `(list @t)`~['he' 'he\'s' 'him' 'his' 'she' 'she\'s' 'her' 'hers' 'they' 'they\'re' 'them' 'their' 'grandma' 'grandpa' 'granny' 'nana' 'mom' 'mum' 'mother' 'dad' 'father' 'wife' 'husband' 'son' 'daughter' 'brother' 'sister' 'aunt' 'uncle' 'cousin' 'baby' 'kids' 'boss' 'friend'])
::  a status naming a diagnosis is a medical fact, which goes under
::  health, out of every key's sight, and nowhere else: moved there when
::  the key's schema lists health, dropped when it does not
::
++  medical-words
  `(set @t)`(sy `(list @t)`~['covid' 'flu' 'cancer' 'positive' 'diagnosed' 'diagnosis' 'infection' 'fever' 'surgery' 'chemo' 'pregnant' 'hospital' 'hospitalized' 'medication'])
::  attributes whose value is a paraphrase by design, held to sharing a
::  word with what was said rather than to being quoted from it
::
++  paraphrased  `(set @t)`(sy `(list @t)`~['status' 'health'])
::  +word-list: the [a-z0-9']+ runs of a text, lower-cased
::
++  word-list
  |=  t=@t
  ^-  (list @t)
  =/  low=tape  (cass (trip t))
  %+  turn  (split-char ' ' (turn low |=(c=@ ?:(|(&((gte c 'a') (lte c 'z')) (is-digit c) =(c '\'')) c ' '))))
  |=(w=tape ^-(@t (crip w)))
::  +words: a text as its words, one space between and one at each end,
::  so a name matches only on whole words
::
++  words
  |=  t=@t
  ^-  @t
  (rap 3 ' ' (join-cords ' ' (word-list t)) ' ' ~)
::  +named-in: bot.named_in: the ids of the bodies a text names, by a
::  name or an alias as whole words, or a person's first name; three
::  letters at least, so "me" names nobody
::
++  named-in
  |=  [text=@t bodies=(list ctx-body)]
  ^-  (set @t)
  =/  said=@t  (words text)
  %-  ~(gas in *(set @t))
  ^-  (list @t)
  %+  murn  bodies
  |=  b=ctx-body
  ^-  (unit @t)
  =/  names=(list @t)  [name.b aliases.b]
  =?  names  =('person/' (end [3 7] id.b))
    =/  first=(list tape)  (split-char ' ' (trip name.b))
    ?~(first names (snoc names (crip i.first)))
  ?.  %+  lien  names
      |=  n=@t
      ^-  ?
      =/  w=@t  (words n)
      ?:  (lth (met 3 (trim-cord n)) 3)  |
      ?:  =('' (trim-cord w))  |
      ?=(^ (find (trip w) (trip said)))
    ~
  `id.b
::  +shares-a-word: whether a paraphrase could be of this text: a word
::  of four letters or more in common
::
++  shares-a-word
  |=  [value=@t text=@t]
  ^-  ?
  =/  vs=(list @t)  (word-list value)
  =/  long=(set @t)  (~(gas in *(set @t)) (skim vs |=(w=@t (gte (met 3 w) 4))))
  =/  ts=(list @t)  (word-list text)
  (lien ts |=(w=@t (~(has in long) w)))
::  +ground: bot.grounded. The model's facts that its messages bear
::  out: about the author, when the message is theirs to speak for, or
::  a body the message names; a value other than a status or health
::  found in the message's words; a status or health not read from the
::  earlier messages instead; a status naming a diagnosis moved to
::  health; nothing from a question. The rest is dropped with a note,
::  and so is a new body no fact kept is about.
::
++  ground
  |=  [facts=tg-facts rows=(list window-row) ctx=reader-ctx]
  ^-  tg-facts
  =/  by-id=(map @t window-row)
    (~(gas by *(map @t window-row)) (turn rows |=(r=window-row [id.r r])))
  =/  earlier=(list @t)
    (turn (skim rows |=(r=window-row context.r)) |=(r=window-row text.r))
  =/  pool=(list ctx-body)
    %+  weld  bodies.ctx
    %+  turn  bodies.facts
    |=(b=json ^-(ctx-body [(gs b 'id') (gs b 'name') (strings (ga b 'aliases'))]))
  =|  keep=(list json)
  =|  notes=(list @t)
  =/  rest=(list json)  obs.facts
  |-
  ^-  tg-facts
  ?~  rest
    =/  kept=(list json)  (flop keep)
    ::  a body a kept fact is about: its subject, its ref, an action's about
    =/  subjects=(list @t)  (turn kept |=(o=json (gs o 'subject')))
    =/  refs=(list @t)
      %+  murn  kept
      |=  o=json
      ^-  (unit @t)
      =/  r=@t  (gs (gj o 'value') 'ref')
      ?:(=('' r) ~ `r)
    =/  abouts=(list @t)
      %+  roll  acts.facts
      |=  [a=json acc=(list @t)]
      ^-  (list @t)
      (weld acc `(list @t)`(strings (ga a 'about')))
    =/  used=(set @t)  (~(gas in *(set @t)) subjects)
    =.  used  (~(gas in used) refs)
    =.  used  (~(gas in used) abouts)
    =/  known=(set @t)
      (~(gas in *(set @t)) (turn bodies.ctx |=(b=ctx-body id.b)))
    =/  said=@t
      %-  words
      %+  join-cords  ' '
      (turn (skip rows |=(r=window-row context.r)) |=(r=window-row text.r))
    =/  bout=[bodies-out=(list json) body-notes=(list @t)]
      %+  roll  bodies.facts
      |=  [b=json acc=[bodies-out=(list json) body-notes=(list @t)]]
      ^-  [bodies-out=(list json) body-notes=(list @t)]
      =/  id=@t  (gs b 'id')
      ?:  (~(has in known) id)
        ::  new names for a body the ship has: only words the messages use
        =/  als=(list @t)
          %+  skim  `(list @t)`(strings (ga b 'aliases'))
          |=  a=@t
          ^-  ?
          =/  w=@t  (words a)
          &(!=('' (trim-cord w)) ?=(^ (find (trip w) (trip said))))
        ?~  als
          :-  bodies-out.acc
          [(rap 3 'dropped new names for ' id ': not in the message' ~) body-notes.acc]
        =/  fresh=(list json)  (turn `(list @t)`als |=(a=@t `json`s+a))
        [(snoc bodies-out.acc (set-key b 'aliases' a+fresh)) body-notes.acc]
      ?:  (~(has in used) id)  [(snoc bodies-out.acc b) body-notes.acc]
      :-  bodies-out.acc
      [(rap 3 'dropped body ' id ': no fact is about it' ~) body-notes.acc]
    :*  bodies-out.bout
        kept
        acts.facts
        :(weld notes.facts (flop notes) (flop body-notes.bout))
        escalate.facts
    ==
  =/  o=json  i.rest
  =/  m=window-row  (fall (~(get by by-id) (gs o 'message')) *window-row)
  =/  text=@t  text.m
  ::  a possessive points as surely as the word: "grandpa's flight" is grandpa's
  =/  said=(set @t)
    =/  ws=(list @t)  (word-list text)
    =/  stems=(list @t)
      %+  murn  ws
      |=  w=@t
      ^-  (unit @t)
      =/  n=@ud  (met 3 w)
      ?.  &((gte n 2) =('\'s' (rsh [3 (sub n 2)] w)))  ~
      `(end [3 (sub n 2)] w)
    (~(gas in *(set @t)) (weld ws stems))
  =/  named=(set @t)  (named-in text pool)
  =/  persons=(list @t)
    (skim `(list @t)`~(tap in named) |=(n=@t =('person/' (end [3 7] n))))
  =/  others=(set @t)  (~(del in (~(gas in *(set @t)) persons)) who.m)
  =/  subject=@t  (gs o 'subject')
  =/  attr=@t  (gs o 'attr')
  =/  value=json  (gj o 'value')
  =/  vtext=@t  (ref-or-text value)
  =/  medical=?
    ?.  =('status' attr)  |
    ?.  ?=([%s *] value)  |
    (lien `(list @t)`(word-list p.value) |=(w=@t (~(has in medical-words) w)))
  =/  listed=(list @t)  (fall (~(get by attrs.ctx) (kind-of subject)) `(list @t)`~)
  =/  why=@t
    =/  tt=@t  (trim-cord text)
    ?:  &(!=('' tt) =('?' (rsh [3 (dec (met 3 tt))] tt)))
      'a question states nothing'
    ?:  &(!=(subject who.m) !(~(has in named) subject))
      'not the author and not named in the message'
    ?:  ?&  =(subject who.m)
            !(~(has in named) subject)
            |(!=(~ (~(int in said) someone-else)) !=(~ others))
            =(~ (~(int in said) first-person))
        ==
      'the message is about someone else'
    ?:  &(medical !(lien listed |=(a=@t =('health' a))))
      'a medical fact goes under health, which this key may not write'
    ?:  ?&  !(~(has in paraphrased) attr)
            ?=([%o *] value)
            !(~(has in named) (gs value 'ref'))
        ==
      (cat 3 'the message does not name ' (gs value 'ref'))
    ?:  ?&  !(~(has in paraphrased) attr)
            |(?=([%s *] value) ?=([%n *] value))
            ?=(~ (find (trip (lower vtext)) (trip (lower text))))
        ==
      'the value is not in the message'
    ?:  ?&  (~(has in paraphrased) attr)
            ?=([%s *] value)
            !(shares-a-word vtext text)
            (lien earlier |=(e=@t (shares-a-word vtext e)))
        ==
      'read from the earlier messages'
    ''
  ?.  =('' why)
    $(rest t.rest, notes [(rap 3 'dropped ' subject '.' attr ': ' why ~) notes])
  =/  fixed=json
    ::  a chat fact is true from its message, not from midnight: a bare
    ::  date would lose the fold to anything said earlier that day
    =/  at=@t  (gs o 'at')
    =/  stamped=json
      ?.  &(=('T00:00:00Z' (rsh [3 10] at)) =((end [3 10] at) (end [3 10] at.m)))
        o
      (set-key o 'at' s+at.m)
    ?.  medical  stamped
    (set-key stamped 'attr' s+'health')
  =?  notes  medical
    [(rap 3 'moved ' subject '.status to health: a medical fact' ~) notes]
  $(rest t.rest, keep [fixed keep])
::  ==  the decider: the questions the reader puts to the decision model
::  (analyze.gate_state, gate, escalate, status_check), as request bodies
::
::  +known-line: analyze.known_line: a body as "id | name | alias, alias"
::
++  known-line
  |=  b=ctx-body
  ^-  @t
  (rap 3 id.b ' | ' name.b ?~(aliases.b '' (cat 3 ' | ' (join-cords ', ' aliases.b))) ~)
::  +rank-bodies: analyze.rank_bodies: the bodies the window names first,
::  then people, then activities, places and orgs, then situations, then
::  things; at most a thousand
::
++  rank-bodies
  |=  [bodies=(list ctx-body) rows=(list window-row)]
  ^-  (list ctx-body)
  =/  text=@t  (join-cords ' ' (turn rows |=(r=window-row text.r)))
  =/  named=(set @t)  (named-in text bodies)
  =/  rank
    |=  b=ctx-body
    ^-  @ud
    ?:  (~(has in named) id.b)  0
    ?+  (kind-of id.b)  5
      %person  1
      %activity  2
      %place  2
      %org  2
      %situation  3
      %thing  4
    ==
  %+  scag  1.000
  %+  sort  bodies
  |=([a=ctx-body b=ctx-body] ?:(=((rank a) (rank b)) (aor id.a id.b) (lth (rank a) (rank b))))
::  +gate-state: analyze.gate_state: the newest message, the earlier ones,
::  and every known body by name, ranked
::
++  gate-state
  |=  [rows=(list window-row) ctx=reader-ctx]
  ^-  json
  =/  new=(list window-row)  (skip rows |=(r=window-row context.r))
  =/  earlier=(list window-row)  (skim rows |=(r=window-row context.r))
  %-  pairs:enjs:format
  :~  ['message' s+?~(new '' text:(rear new))]
      ['from' s+?~(new '' who:(rear new))]
      ['earlier' a+(turn earlier |=(r=window-row `json`s+text.r))]
      ['known_bodies' a+(turn (rank-bodies bodies.ctx rows) |=(b=ctx-body `json`s+(known-line b)))]
      ['rule' s+'a status is a circumstance, never a feeling; only facts about people, things, places and plans are recorded']
  ==
::  +noul-question: a yes-or-no question with its criteria
::
++  noul-question
  |=  [instructions=@t yes=@t no=@t]
  ^-  json
  (pairs:enjs:format ~[['type' s+'noul'] ['instructions' s+instructions] ['criteria' (pairs:enjs:format ~[['true' s+yes] ['false' s+no]])]])
::  +gate-body: analyze.GATE_QUESTION over the gate state: whether the
::  newest message carries a fact the analyst should read
::
++  gate-body
  |=  [rows=(list window-row) ctx=reader-ctx]
  ^-  json
  %-  pairs:enjs:format
  :~  ['state' (gate-state rows ctx)]
      :-  'questions'
      %-  pairs:enjs:format
      :_  ~
      :-  'worth_reading'
      %^  noul-question
        'Does the new message state a fact worth recording about a person, thing, place, or a plan, that the analyst should read?'
        'it says where someone is, what they are dealing with, what happened, or what will happen, to whom and when'
      'chatter, greetings, feelings, jokes, a question, or a request that carries no fact about anyone'
  ==
::  +escalate-body: analyze.ESCALATE_QUESTION over the gate state and the
::  facts just kept: whether someone needs help within the hour
::
++  escalate-body
  |=  [rows=(list window-row) ctx=reader-ctx facts=(list json)]
  ^-  json
  =/  st=json  (gate-state rows ctx)
  =/  facts-j=json
    :-  %a
    %+  turn  (scag 40 facts)
    |=(o=json (pairs:enjs:format ~[['subject' s+(gs o 'subject')] ['attr' s+(gs o 'attr')] ['value' s+(ref-or-text (gj o 'value'))]]))
  =.  st  (set-key st 'facts' facts-j)
  =.  st  (set-key st 'rule' s+'help within the hour means someone must act now; a plan or an update is not that')
  %-  pairs:enjs:format
  :~  ['state' st]
      :-  'questions'
      %-  pairs:enjs:format
      :_  ~
      :-  'needs_help_now'
      %^  noul-question
        'Does the new message describe a situation in which the owner, or someone close to them, needs help within the hour?'
        'a breakdown, an accident, an injury or sudden illness, being stranded, locked out or without power, a child who must be picked up now, a missed or cancelled flight today, an emergency at home or at work'
      'a plan, news, a routine update, a feeling, a complaint, or anything that can wait until tomorrow'
  ==
::  +status-body: analyze.status_check's request: each status proposed
::  for a person, numbered by its place in the observations, put as a
::  choice question naming its own proposal
::
++  status-body
  |=  [rows=(list window-row) obs=(list json)]
  ^-  json
  =/  new=(list window-row)  (skip rows |=(r=window-row context.r))
  =/  asked=(list [i=@ud o=json])
    =/  n=@ud  0
    |-  ^-  (list [i=@ud o=json])
    ?~  obs  ~
    =/  rest  $(obs t.obs, n +(n))
    ?:  &(=('status' (gs i.obs 'attr')) =('person/' (end [3 7] (gs i.obs 'subject'))))  [[n i.obs] rest]
    rest
  %-  pairs:enjs:format
  :~  :-  'state'
      %-  pairs:enjs:format
      :~  ['message' s+?~(new '' text:(rear new))]
          ['from' s+?~(new '' who:(rear new))]
          ['proposals' a+(turn asked |=([i=@ud o=json] (pairs:enjs:format ~[['n' (numb:enjs:format i)] ['subject' s+(gs o 'subject')] ['value' s+(ref-or-text (gj o 'value'))]])))]
          ['rule' s+'status on a person is what they are doing or dealing with right now, in plain words; never a feeling, a quote or a wish']
      ==
      :-  'questions'
      %-  pairs:enjs:format
      %+  turn  asked
      |=  [i=@ud o=json]
      :-  (crip "status_{(a-co:co i)}")
      %-  pairs:enjs:format
      :~  ['type' s+'choice']
          ['instructions' s+(rap 3 'Is this proposed status for the person a circumstance or a feeling? The proposal is n=' (crip (a-co:co i)) ': "' (ref-or-text (gj o 'value')) '".' ~)]
          :-  'criteria'
          %-  pairs:enjs:format
          :~  ['circumstance' s+'what the person is doing or dealing with right now, as an observer would put it: on jury duty, stranded waiting for a tow, travelling, sick, home with the kids']
              ['feeling' s+'an emotion, a mood, a quote or a wish: want to scream, exhausted, so happy, wishes it were friday']
              ['neither' s+'not a status at all: a plan, a location, an event, a thing']
          ==
      ==
  ==
::  +noul-of: a noul answer's probability in hundredths, 0 when absent
::
++  noul-of
  |=  [answers=json key=@t]
  ^-  @ud
  =/  n=json  (gj (gj answers key) 'noul')
  ?.  ?=([%n *] n)  0
  (min 100 (div (micro-of p.n) 10.000))
::  +choice-of: a choice answer and its probability in hundredths;
::  ['' 0] when there is none
::
++  choice-of
  |=  [answers=json key=@t]
  ^-  [choice=@t p=@ud]
  =/  a=json  (gj answers key)
  =/  c=@t  (gs a 'choice')
  ?:  =('' c)  ['' 0]
  =/  p=json  (gj (gj a 'probabilities') c)
  [c ?.(?=([%n *] p) 0 (min 100 (div (micro-of p.p) 10.000)))]
--
