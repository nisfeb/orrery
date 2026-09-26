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
++  num-cord                                    ::  a number or a string as text, or ''
  |=  j=json
  ^-  @t
  ?:  ?=([%n *] j)  p.j
  ?:  ?=([%s *] j)  p.j
  ''
++  err-entry                                   ::  a refused item's answer
  |=  msg=@t
  ^-  json
  (pairs:enjs:format ~[['ok' b+|] ['error' s+msg]])
++  err-json                                    ::  a refused request's body: the page reads error, a client note
  |=  msg=@t
  ^-  json
  (pairs:enjs:format ~[['error' s+msg] ['note' s+msg]])
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
  ::  a time is stored as UTC, so the fold and the phase, which compare
  ::  the text, compare instants
  =?  value  ?&  (~(has in time-attrs) attr)  ?=([%s *] value)  ?=(^ (de-iso-any p.value))  ==
    s+(en-iso (need (de-iso-any ?>(?=([%s *] value) p.value))))
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
  ::  each row is seen a moment after the one before it, so two rows
  ::  of one batch on one attribute at one time fold in request order
  =/  i=@ud  0
  =/  os=(list json)  (ga jon 'observations')
  |-  ^-  (list (each obs @t))
  ?~  os  ~
  :-  (de-obs i.os (add now (mul i ~s0..0001)) default-by)
  $(os t.os, i +(i))
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
::  +fallback-ids: the row the fold would fall back to for each
::  attribute (each value, for a multi-valued one) should its winner
::  be retracted or expire: the newest live row after the winner.
::  Compaction keeps these, so a retracted winner reverts to the old
::  value instead of leaving the attribute blank.
::
++  fallback-ids
  |=  [rows=(list row) multi=(set @t) when=@da]
  ^-  (set @ta)
  =/  live=(list row)  (sort (skim rows |=(r=row (is-live obs.r when))) later)
  =|  count=(map [@t json] @ud)
  =|  out=(set @ta)
  |-
  ?~  live  out
  =/  r=row  i.live
  =/  k=[@t json]  [attr.obs.r ?:((~(has in multi) attr.obs.r) value.obs.r ~)]
  =/  n=@ud  (fall (~(get by count) k) 0)
  =?  out  =(1 n)  (~(put in out) id.r)
  $(live t.live, count (~(put by count) k +(n)))
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
::  +involvement: every body's open situations, from one walk over the
::  situations rather than one per body, for the state view
::
++  involvement
  |=  sits=(list [id=bid winners=(map @t (list row))])
  ^-  (map bid (list bid))
  =/  acc=(map bid (list bid))
    %+  roll  sits
    |=  [[id=bid winners=(map @t (list row))] acc=(map bid (list bid))]
    ?:  (is-closed winners)  acc
    %+  roll  (refs-in (fall (~(get by winners) 'participants') ~))
    |=  [b=bid acc=_acc]
    =/  cur=(list bid)  (fall (~(get by acc) b) ~)
    ?:  &(?=(^ cur) =(i.cur id))  acc
    (~(put by acc) b [id cur])
  (~(run by acc) flop)
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
::  side's, and the shorter side has at least one token. "alice" hits
::  "Alice Baker" in both directions; "alice" never hits "Alicia Baker".
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
  ::  from's ship is kept when into has none: it is how the readers and
  ::  the executor find the person
  into(aliases als, ship ?~(ship.into ship.from ship.into))
::  +move-rows: from's rows re-subjected onto into, those into does not
::  already hold. A copy with an id already there is left as it is.
::
++  move-rows
  |=  [src=(list row) dst=(list row) into=bid]
  ^-  (list row)
  =/  held=(set @ta)  (sy (turn dst |=(r=row id.r)))
  %+  skim  (turn src |=(r=row (resubject r into)))
  |=(r=row &(!(~(has in held) id.r) !=(`into (ref-of value.obs.r))))
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
    ::  a future row is repointed too, or it names a culled body when
    ::  its time comes; a retracted one says nothing
    ?:  retracted.obs.r  |
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
::  +revise: the owner's note applied to a proposed action: the four
::  fields the note can change, replaced whole; the id, the status and
::  the history stay, with one step saying the owner revised it. The
::  status does not move, so the transition table has no say.
::
++  revise
  |=  [a=action title=@t payload=json about=(set bid) due=(unit @da) by=@t now=@da]
  ^-  action
  a(title title, payload payload, about about, due due, history (snoc history.a [now %revised by]))
::  +revise-action-op: the writer op that carries a revision's fields
::
++  revise-action-op
  |=  [id=@ta title=@t payload=json about=(list @t) due=(unit @da) by=@t]
  ^-  json
  %-  pairs:enjs:format
  %-  zing
  :~  :~  ['op' s+'revise-action']
          ['id' s+id]
          ['title' s+title]
          ['payload' payload]
          ['about' a+(turn about |=(x=@t `json`s+x))]
          ['by' s+by]
      ==
      ?~(due ~ ~[['due' s+(en-iso u.due)]])
  ==
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
            ~['status' 'schedule' 'cadence' 'location' 'participants' 'organizer' 'last' 'next' 'skipped']
          :~  ['status' 'active, or cancelled when the whole series has ended; one occurrence that is off goes under skipped']
              ['last' 'the start of the most recent occurrence, ISO 8601 UTC, with at set to that start']
              ['next' 'the start of the nearest upcoming occurrence, ISO 8601 UTC']
              ['schedule' 'when it recurs, in words: Tue/Thu 16:45, first Saturday of the month']
              ['cadence' 'weekly, twice a week, monthly']
              ['skipped' 'the start of one occurrence that is off, ISO 8601 UTC, one row per occurrence; the activity itself stays active']
          ==
          ['note' (kind ~['text'] ~)]
      ==
      ['multi' a+(turn ~['participants' 'likes' 'dislikes' 'household' 'vehicles' 'children' 'owners' 'members' 'aware-of' 'skipped'] |=(t=@t `json`s+t))]
      ['actions' a+(turn ~['task' 'note' 'message' 'home' 'calendar'] |=(t=@t `json`s+t))]
      ['style' s+'']
      ['preferences' a+~]
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
          :~  ['via' 'required: one of chat, telegram, mail; chat when the person has a ship, telegram only when they have none']
              ['to' 'required: the body id of the person, e.g. person/alice']
              ['channel' 'optional: for via chat, a group channel to post in instead of a DM, e.g. chat/~host/general']
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
              ['mode' 'optional: add (the default) or cancel']
              ['event' 'optional: the calendar id of the event to cancel']
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
::  +ship-of: a person's ship as the executor finds it: the ship
::  attribute, else the ship on the body's record
::
++  ship-of
  |=  [all=(list loaded) id=@t now=@da]
  ^-  @t
  =/  a=@t  (attr-text all ~ now id 'ship')
  ?.  =('' a)  a
  =/  hit=(unit loaded)  (loaded-of all id)
  ?~  hit  ''
  ?~(ship.body.u.hit '' (scot %p u.ship.body.u.hit))
::  +address-attrs: where the executor sends a person's messages. A
::  key writes them only with sensitive: write, since one that could
::  would redirect the owner's approved messages (version 60).
::
::  +time-attrs: the attributes whose value is an instant
::
++  time-attrs  `(set @t)`(sy `(list @t)`~['starts' 'ends' 'started' 'ended' 'next' 'last'])
++  address-attrs  `(set @t)`(sy `(list @t)`~['ship' 'telegram'])
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
  =/  inv=(map bid (list bid))  (involvement sits)
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
        ['involved' a+(turn (fall (~(get by inv) id.l) ~) |=(b=bid `json`s+b))]
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
  =/  start=(unit @da)
    (de-iso-any =/(s (winner-text winners 'started') ?:(=('' s) (winner-text winners 'starts') s)))
  =/  end=(unit @da)
    =/  got=(unit @da)  (de-iso-any =/(e (winner-text winners 'ended') ?:(=('' e) (winner-text winners 'ends') e)))
    ?:  &(?=(^ got) ?=(^ start) (gth u.start u.got))  ~
    got
  ?:  &(?=(^ end) (lte u.end now))  'over'
  ?:  &(?=(^ start) (lte u.start now))  'under way'
  ?:  ?=(^ start)  'upcoming'
  ?:(=('' st) 'open' st)
::  +lte-iso: ISO 8601 UTC strings of one shape compare as text
::
++  lte-iso  |=([a=@t b=@t] ^-(? (aor a b)))
::  +same-title: the same words, or four fifths of the shorter title's
::  words (at least two) in the longer
::
++  same-title
  |=  [a=@t b=@t]
  ^-  ?
  =/  ka=(set @t)  (sy (tokens a))
  =/  kb=(set @t)  (sy (tokens b))
  ?:  |(=(~ ka) =(~ kb))  |
  ?:  =(ka kb)  &
  =/  both=@ud  ~(wyt in (~(int in ka) kb))
  =/  short=@ud  (min ~(wyt in ka) ~(wyt in kb))
  ::  four fifths rounded up: a three- or four-word title needs every
  ::  word, so "Call the dentist" never stands for "Call the plumber"
  (gte both (max 2 (div (add (mul 8 short) 9) 10)))
::  the pieces of the user prompt and the count of decided actions shown
++  recent      60
++  prompt-bodies  300
::  +reasons-kept: the dismissals before the window whose reasons are
::  still shown
++  reasons-kept  40
::  +decision-lines: the last +recent decisions, each with the owner's
::  note, then the dismissals before them that carry a reason, the last
::  +reasons-kept of them. A reason is the owner's taste, and it
::  outlasts the window.
::
++  decision-lines
  |=  [head=@t decided=(list [id=@ta a=action])]
  ^-  (list @t)
  =/  cut=@ud  (sub (lent decided) (min recent (lent decided)))
  =/  one
    |=  [id=@ta a=action]
    ^-  @t
    =/  base=@t  (rap 3 '  ' status.a ' | ' kind.a ' | ' title.a ~)
    ?:(=('' note.a) base (rap 3 base ' | ' (end [3 200] (squeeze note.a)) ~))
  =/  older=(list [id=@ta a=action])
    (skim (scag cut decided) |=([* a=action] &(?=(%dismissed status.a) !=('' note.a))))
  =/  kept=(list @t)
    (turn (slag (sub (lent older) (min reasons-kept (lent older))) older) one)
  %+  weld  `(list @t)`[head (turn (slag cut decided) one)]
  ?~  kept  ~
  ['Earlier dismissals, with the owner\'s reasons:' kept]
::  +owner-lines: the owner's own words from the schema, for every
::  prompt: the style for text written in their voice, when the prompt
::  writes any, and their standing preferences
::
++  owner-lines
  |=  [schema=json style=?]
  ^-  (list @t)
  =/  said=@t  (end [3 1.000] (trim-cord (squeeze (gs schema 'style'))))
  =/  prefs=(list @t)
    %+  scag  30
    %+  skip  (turn (strings (ga schema 'preferences')) |=(p=@t (end [3 300] (trim-cord (squeeze p)))))
    |=(p=@t =('' p))
  %+  weld
    ^-  (list @t)
    ?:  |(!style =('' said))  ~
    ~[(cat 3 'The owner\'s style for text in their voice: ' said)]
  ?~  prefs  ~
  :-  'The owner\'s standing preferences:'
  (turn prefs |=(p=@t (cat 3 '  - ' p)))
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
  (crip (join-tapes " " (split-char ' ' flat)))
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
::  failed actions, oldest first, shown as +decision-lines has them.
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
  =/  hidden=(set @t)
    %-  sy
    %+  murn  all
    |=  l=loaded
    ^-  (unit @t)
    ?.  =(%situation kind.body.l)  ~
    =/  ph=@t  (phase (fold rows.l multi now) now)
    ?:(|(=('closed' ph) =('cancelled' ph) =('over' ph)) `id.l ~)
  ::  the cap keeps the bodies most recently told of, person/me always,
  ::  after the hidden are gone: a hash-order cut dropped open ones
  =/  shown=(list loaded)  (newest-bodies (skip all |=(l=loaded (~(has in hidden) id.l))) prompt-bodies)
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
  =/  p0=@t  (join-cords nl ;:(weld head (owner-lines schema &) (section ~[%thing %place %org %note])))
  =/  p1=@t  (join-cords nl (section ~[%person %activity]))
  =/  p2=@t  (join-cords nl (section ~[%situation]))
  =/  open=(list @t)
    :-  'Open actions (proposed or approved, do not duplicate):'
    %+  murn  (sort acts |=([a=[id=@ta *] b=[id=@ta *]] (aor id.a id.b)))
    |=  [id=@ta a=action]
    ^-  (unit @t)
    ?.  (is-open a)  ~
    `(rap 3 '  ' kind.a ' | ' title.a ' | about ' (join-cords ', ' ~(tap in about.a)) ~)
  =/  done=(list @t)  (decision-lines 'Recent decisions (do not propose these again):' decided)
  =/  p3=@t  (join-cords nl (weld open done))
  =/  p4=@t
    (rap 3 'Now: ' (en-iso now) ', timezone ' ?:(=('' tz) 'unknown' tz) '. Answer with the JSON object.' ~)
  ~[p0 p1 p2 p3 p4]
::  +newest-bodies: at most n bodies, person/me first, then by their
::  newest row
::
++  newest-bodies
  |=  [all=(list loaded) n=@ud]
  ^-  (list loaded)
  =/  newest  |=(l=loaded ^-(@da (roll rows.l |=([r=row acc=@da] ^-(@da (max acc seen.obs.r))))))
  %+  scag  n
  %+  sort  all
  |=  [a=loaded b=loaded]
  ?:  =('person/me' id.a)  &
  ?:  =('person/me' id.b)  |
  =/  na=@da  (newest a)
  =/  nb=@da  (newest b)
  ?:(=(na nb) (aor id.a id.b) (gth na nb))
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
  :*  =/(e (gj j 'enabled') ?:(?=([%b *] e) p.e &))
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
  ::  an exponent past thirty saturates: a model's 1e99999999 would
  ::  otherwise multiply a bignum a hundred million times
  ?:  (gth (abs:si e) 30)  ?:((syn:si e) (mul micro (pow 10 30)) 0)
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
  The recent decisions: actions done, dismissed or failed lately, with their titles. Do not propose these again, or a rewording of them. A dismissal is the owner saying no. Older dismissals that carry the owner's reason follow them.
  The owner's style and standing preferences, when they have written any.
  The time now, and the owner's timezone.

  What to propose.
  Only what the owner would want done and has not done: a call to make, a thing to buy or bring, a message to send someone, a reminder ahead of a deadline, a follow-up on something that stalled. An open situation with nothing being done about it, a person who asked the owner something and is still waiting, a delivery that never arrived. Someone telling the owner about their own day, trip or trouble is sharing news, not asking for anything, and needs no reply unless the state shows they asked or are waiting.
  An event on the calendar is already known: never propose a task for attending it, and never restate it as a todo. Propose what an event needs beyond showing up, and only when the state gives a reason: a birthday with no gift task, an appointment with a form to bring, a rehearsal with no ride. A first occurrence is not a fifth: something the state or a message says is new, a first lesson, a new team, a first visit, may call for something the owner does not yet have, equipment, paperwork, a plan, where a routine one calls for nothing; then one task with the likely list under payload "notes" is worth more than a reminder to attend. An activity with no last is new to the ship, not to the owner, who may have done it for years, and that alone makes nothing a first. Two events that overlap or leave no time between them matter only when one person must be in two places: the same participant at both, or the one person who can take both. There is no conflict when the events are at one place, when one is a call, when one is optional or tentative, or when another adult can take one. When there is one, propose one task to sort it out, naming both. A situation that is over or closed needs nothing.
  Few and good. Zero is a fine answer. Never propose more than the limit given.
  An action's kind is one of the kinds the schema lists. Its payload follows the shape the schema gives for that kind, exactly; a message names who it is for as a body id and says what to send in the owner's own voice, short and plain, in the owner's style when one is given. A home action names a Home Assistant service and entity. A task needs only a title and, when there is one, a due time.
  "about" names the bodies the action concerns, by id, at most a few. "due" is ISO 8601 UTC, only when the timing matters.
  Respect what the facts say about time: an occurrence in the past is over; a situation that is upcoming has not happened; "last" is the most recent occurrence and "next" the nearest one ahead.
  Do not invent facts, people, places or events. Do not propose things the owner cannot act on. Do not moralise.
  Common sense, always: no todo for attending an event or a routine activity; no message telling someone what they just said; nothing the owner is already doing; nothing a decision already covered; no reminder for what happens on its own.
  A dismissed action may carry the owner's reason after its title. Those reasons are the owner's taste, and they generalise: one "just the event" means every todo for attending is unwanted, one "I always do this" means routine chores are unwanted. Read them before proposing. The owner's standing preferences are the same taste written down once, and they hold over any single decision.

  Answer with one JSON object and nothing else:
  {"actions": [{"kind": "task", "title": "...", "about": ["kind/slug"], "due": "...", "payload": {...}, "why": "one sentence"}],
   "notes": ["what makes the state wrong or incomplete"]}
  "why" is for the owner's eyes on the page; keep it to one sentence. Notes are optional, short and few: only what makes the state wrong or incomplete in a way that matters, such as two bodies that are one thing, a person an event plainly involves who is missing, or a situation still open well after it ended. Never a detail one body lacks, and never that something in the past is over.
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
  =/  kt=(set @t)  (sy (tokens title))
  =/  ke=(set @t)  (sy (tokens event))
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
  =/  kind=@t  =/(k (lower (gs a 'kind')) ?:(=('' k) 'task' k))
  =/  title=@t  (end [3 200] (gs a 'title'))
  ?:  |(!(~(has in kinds) kind) =('' title))
    $(todo t.todo, notes [(rap 3 'dropped: kind ' kind ' or no title (' (end [3 40] title) ')' ~) notes])
  ?:  (lien taken |=(t=@t (same-title title t)))
    $(todo t.todo, notes [(cat 3 'dropped as already open or decided: ' title) notes])
  =/  restated=(unit @t)  (find-first events |=(e=@t (restates title e)))
  ?^  restated
    $(todo t.todo, notes [(rap 3 'dropped as a todo for an event on the calendar: ' title ' (' u.restated ')' ~) notes])
  =/  about=(list @t)  (turn (strings (ga a 'about')) lower)
  =/  bad=(list @t)  (skip about |=(b=@t (~(has in known) b)))
  ?^  bad
    $(todo t.todo, notes [(rap 3 'dropped ' title ': names bodies that do not exist: ' (join-cords ', ' bad) ~) notes])
  =/  payload=(map @t json)
    =/  p=json  (gj a 'payload')
    ?:(?=([%o *] p) p.p ~)
  ::  held to the kind's shape as the reader holds it: times to UTC, a
  ::  value from its list, a recipient that is a body; otherwise the
  ::  action would wait approved for ever with no way out
  =/  held  (hold-payload payload (gj payloads kind) known ~)
  ?:  ?=([%| *] held)
    $(todo t.todo, notes [(rap 3 'dropped ' title ': ' p.held ~) notes])
  =.  payload  p.held
  =/  why=@t  (end [3 300] (gs a 'why'))
  =?  payload  !=('' why)  (~(put by payload) 'why' s+why)
  =/  due=(unit @da)  (de-iso-any (gs a 'due'))
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
::  started; one scheduled (starts, never started) with no end six
::  hours after it starts, since a performance or an appointment with
::  no end given is over by then; one with a start but no end that
::  began more than stale ago with nothing seen since closes at its
::  newest observation. Times are read the way the readers write them,
::  a bare date included, so a trip that started on a date closes. The
::  close time lands one second past a later live status row, so a
::  reminder that said "open" after the event does not win the fold.
::
++  retire-trip       ~d7
++  retire-scheduled  ~h6
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
  =/  started=@t  (winner-text winners 'started')
  =/  start=(unit @da)
    (de-iso-any ?:(=('' started) (winner-text winners 'starts') started))
  ::  a plan moved later has a start past its old end: that end is not
  ::  the situation's any more
  =/  end=(unit @da)
    =/  e=@t  (winner-text winners 'ended')
    =/  got=(unit @da)  (de-iso-any ?:(=('' e) (winner-text winners 'ends') e))
    ?:  &(?=(^ got) ?=(^ start) (gth u.start u.got))  ~
    got
  ?^  end
    ?.  (lth u.end now)  ~
    `[id.l (after u.end) (cat 3 'ended ' (en-iso u.end))]
  ?~  start  ~
  ?:  &((is-trip id.l) (lth (add u.start retire-trip) now))
    =/  e=@da  (add u.start retire-trip)
    `[id.l (after e) (rap 3 'a trip started ' (en-iso u.start) ' with no end' ~)]
  ?:  &(=('' started) (lth (add u.start retire-scheduled) now))
    =/  e=@da  (add u.start retire-scheduled)
    `[id.l (after e) (rap 3 'scheduled for ' (en-iso u.start) ' with no end' ~)]
  =/  latest=@da
    %+  roll  rows.l
    |=  [r=row acc=@da]
    ?:(retracted.obs.r acc (max seen.obs.r acc))
  =.  latest  (max latest u.start)
  ?.  &((lth u.start cutoff) (lth latest cutoff))  ~
  `[id.l (after latest) (rap 3 'started ' (en-iso u.start) ', nothing since ' (en-iso latest) ~)]
::  +retire-ops, +expire-ops, +status-ops: the plans as observe ops for
::  the writer, each a status row at its time, signed retire
::
++  retire-ops  |=(plans=(list [id=bid at=@da why=@t]) (status-ops plans 'closed' 90))
++  expire-ops  |=(plans=(list [id=bid at=@da why=@t]) (status-ops plans 'delivered' 60))
++  status-ops
  |=  [plans=(list [id=bid at=@da why=@t]) status=@t conf=@ud]
  ^-  (list json)
  %+  observe-ops  ~
  %+  turn  plans
  |=  [id=bid at=@da why=@t]
  (obs-row id 'status' s+status at ~ conf ['retire' (cat 3 'retire/' id)] 'retire')
::  +plan-expire: a thing whose status is a stage of a delivery and has
::  stood past its grace is presumed delivered: out for delivery three
::  days on, shipped or in transit a fortnight on. The new row is dated
::  at the end of the grace, so it wins the fold, and carries conf 60
::  and the note, so a carrier's own word later supersedes it and the
::  trail says it was presumed.
::
++  expire-out      ~d3
++  expire-shipped  ~d14
++  plan-expire
  |=  [all=(list loaded) multi=(set @t) now=@da]
  ^-  (list [id=bid at=@da why=@t])
  %+  murn  all
  |=  l=loaded
  ^-  (unit [id=bid at=@da why=@t])
  ?.  =(%thing kind.body.l)  ~
  =/  winners=(map @t (list row))  (fold rows.l multi now)
  =/  w=(list row)  (fall (~(get by winners) 'status') ~)
  ?~  w  ~
  ?.  ?=([%s *] value.obs.i.w)  ~
  =/  st=@t  (lower p.value.obs.i.w)
  =/  grace=(unit @dr)
    ?:  =('out for delivery' st)  `expire-out
    ?:  ?|(=('shipped' st) =('in transit' st) =('dispatched' st))  `expire-shipped
    ~
  ?~  grace  ~
  =/  due=@da  (add at.obs.i.w u.grace)
  ?.  (lth due now)  ~
  `[id.l due (rap 3 st ' since ' (en-iso at.obs.i.w) ', presumed delivered' ~)]
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
  ::  more bodies than one batch holds go first, without rows: a row
  ::  filed before its body is dropped as on an unknown subject
  ?:  (gth (lent bodies) 50)
    :-  (pairs:enjs:format ~[['op' s+'observe'] ['bodies' a+(scag 50 bodies)] ['observations' a+~]])
    $(bodies (slag 50 bodies))
  :-  %-  pairs:enjs:format
      :~  ['op' s+'observe']
          ['bodies' a+(scag 50 bodies)]
          ['observations' a+(scag 200 rows)]
      ==
  $(bodies (slag 50 bodies), rows (slag 200 rows))
++  retract-op
  |=  [id=@ta why=@t by=@t]
  ^-  json
  (pairs:enjs:format ~[['op' s+'retract'] ['id' s+id] ['note' s+why] ['by' s+by]])
++  delete-op
  |=  id=bid
  ^-  json
  (pairs:enjs:format ~[['op' s+'delete-body'] ['id' s+id]])
++  merge-op
  |=  [from=bid into=bid]
  ^-  json
  (pairs:enjs:format ~[['op' s+'merge'] ['from' s+from] ['into' s+into]])
++  set-action-op
  |=  [id=@ta status=@t why=@t by=@t]
  ^-  json
  (pairs:enjs:format ~[['op' s+'set-action'] ['id' s+id] ['status' s+status] ['note' s+why] ['by' s+by]])
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
::  +is-weekday: a weekday's name or its short forms, a plural too:
::  "sunset" and "wedding" are not
::
++  is-weekday
  |=  t=tape
  ^-  ?
  =/  w=tape  t
  =?  w  &((gth (lent w) 3) =("s" (scag 1 (flop w))))  (scag (dec (lent w)) w)
  %-  ~(has in (sy `(list tape)`~["mon" "monday" "tue" "tues" "tuesday" "wed" "weds" "wednesday" "thu" "thur" "thurs" "thursday" "fri" "friday" "sat" "saturday" "sun" "sunday"]))
  w
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
  ?:  (is-weekday t)  $(toks t.toks)
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
::  +relation-words: the role words that name someone by who they are
::  to another
::
++  relation-words
  ^-  (set @t)
  %-  sy
  ^-  (list @t)
  :~  'wife'  'husband'  'mom'  'mum'  'dad'  'mother'  'father'  'son'
      'daughter'  'brother'  'sister'  'boss'  'friend'  'partner'
  ==
::  +person-key: the words a name is matched by. A relation beside a
::  name names someone else: "jackson wife" is Jackson's wife, not
::  Jackson, so it is matched by nothing.
::
++  person-key
  |=  n=@t
  ^-  (set @t)
  =/  ks=(set @t)  (sy (tokens n))
  ?:  !=(~ (~(int in ks) relation-words))  ~
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
    ::  the calendar convention attaches the dash to the name, "Mira-
    ::  Ballet"; "Flight - SFO to JFK" and "Dentist - cleaning" name no one
    =/  r3=tape  ?~(second rest rest.u.second)
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
      (turn stale |=(r=row (retract-op id.r 'reconcile: this occurrence has passed' 'reconcile')))
    =/  ws=(list json)
      ?~  ahead  ~
      %+  turn  stale
      |=  r=row
      (obs-row id.l 'next' s+(en-iso i.ahead) now `(add i.ahead ~d1) 90 ['reconcile' (cat 3 'times/' id.r)] 'reconcile')
    =/  skipped-stale=(list row)
      %+  skim  live
      |=  r=row
      ?.  &(=('skipped' attr.obs.r) ?=([%s *] value.obs.r))  |
      =/  v=(unit @da)  (de-iso-any p.value.obs.r)
      ?~(v | (lte u.v (sub now ~d1)))
    =/  skipped-rs=(list json)
      (turn skipped-stale |=(r=row (retract-op id.r 'reconcile: the occurrence has passed' 'reconcile')))
    $(rest t.rest, retracts (weld (flop (weld rs skipped-rs)) retracts), writes (weld (flop ws) writes))
  ?.  =(%situation kind.body.l)  $(rest t.rest)
  =/  got=[rs=(list json) ws=(list json)]
    %+  roll  live
    |=  [r=row acc=[rs=(list json) ws=(list json)]]
    =/  learned=@da  ?:((lte at.obs.r now) at.obs.r now)
    =/  a=@t  attr.obs.r
    =/  src=source  ['reconcile' (cat 3 'times/' id.r)]
    =/  sv=(unit @da)  ?.(?=([%s *] value.obs.r) ~ (de-iso p.value.obs.r))
    ?:  &(|(=('started' a) =('ended' a)) ?=(^ sv) (gth u.sv now))
      :-  [(retract-op id.r 'reconcile: a future time is a schedule, not a fact' 'reconcile') rs.acc]
      [(obs-row id.l ?:(=('started' a) 'starts' 'ends') s+(en-iso u.sv) learned ~ conf.obs.r src 'reconcile') ws.acc]
    ?:  &(|(=('starts' a) =('ends' a)) ?=([%s *] value.obs.r) (gth at.obs.r now))
      :-  [(retract-op id.r 'reconcile: a schedule is known when it was learned' 'reconcile') rs.acc]
      [(obs-row id.l a value.obs.r now ~ conf.obs.r src 'reconcile') ws.acc]
    ?:  &(=('status' a) ?=([%s *] value.obs.r) !(status-word (lower p.value.obs.r)))
      [[(retract-op id.r 'reconcile: a situation is open, closed or cancelled; the times say the rest' 'reconcile') rs.acc] ws.acc]
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
    %-  dedupe
    %-  zing
    %+  turn  occ
    |=(o=[* * * w=(map @t (list row))] (refs-in (fall (~(get by w.o) 'participants') ~)))
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
  =/  titled=(list loaded)  (skim all |=(l=loaded ?=(?(%activity %situation) kind.body.l)))
  =/  known=(map @t bid)  (known-people all)
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
::  +known-people: every person the ship knows, keyed by the words a
::  title would name them with: a one-word key as it is, a longer name
::  by its first name, role words dropped
::
++  known-people
  |=  all=(list loaded)
  ^-  (map @t bid)
  ::  the first to claim a word keeps it, and the owner claims first
  =/  people=(list loaded)
    =/  me  |=(l=loaded =('person/me' id.l))
    =/  ps=(list loaded)  (skim all |=(l=loaded =(%person kind.body.l)))
    (weld (skim ps me) (skip ps me))
  =/  words=(list [word=@t id=bid])
    %-  zing
    %+  turn  people
    |=(l=loaded (turn [name.body.l ~(tap in aliases.body.l)] |=(w=@t [w id.l])))
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
    `(set-action-op id 'dismissed' why 'reconcile')
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
    `(set-action-op id 'dismissed' 'reconcile: a body in this pair is gone' 'reconcile')
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
  An action is something to do: a task with a title, the bodies it is about, and an optional due time; or, when a message fixes a plan in time ("dinner Friday at 8", "dentist on the 3rd at 2:30"), a calendar event, kind "calendar", with a payload of title, starts and, when the message says, ends and location, the times ISO 8601 with the message's offset. The situation body records the plan as a fact; the calendar action asks the owner to put it on the calendar; when a message fixes a time, write both, and when it does not, write neither. Or a message to send, kind "message", when the conversation asks the owner something they would answer, or someone should be told what the messages just settled: payload via (the channel the conversation is on, one of the values the schema lists, unless the message says to use another), to (the person's body id) and text, short and plain, in the owner's own voice and in their style when one is given. Someone telling the owner about their own day, trip or trouble is not asking anything: propose a message only when they asked the owner something or are waiting on them, and never about a problem a later message says is solved. Never a message telling someone what they just said, and never one the owner already sent. When a message cancels something that is on the calendar and you were given the calendar's own id for that event, propose a calendar action with mode "cancel", event that id and, for a repeating event, starts the occurrence being dropped, keeping title and starts as an ordinary calendar action has them; the owner approves it, and the cancellation is written as a fact either way. Propose only the action kinds listed for you, with the payload shape given. A bill is a task only while the owner still has to pay it: an invoice, or a request with an amount due and no sign it is paid. A receipt, a charge already made, an autopay notice, a refund or a reimbursement is no task. The owner's standing preferences, when given, say what they want proposed and what not.
  Rules.
  Only state what the messages say or clearly imply. Never invent. When unsure, leave it out or lower the confidence.
  Use the existing bodies by id whenever a message refers to one of them, by name or alias. When a message calls an existing body by a name the list does not have ("next door" for place/neighbors, "the Hendersons"), repeat that body in "bodies" with the new name under "aliases", so the ship learns the word. Create a new body only for a named person, place, thing or org, or for a situation (an event with participants) the messages describe.
  Use only the attribute names listed for that kind; an observation on any other name is dropped. When a kind has no attributes listed, use a short lowercase name. A health fact goes on "health" and a money fact on "income", never on a name of your own.
  Read the notes given with the attribute names: they say what each one means. A person's "status" is what they are doing or dealing with right now, in plain words, as an observer would put it: "on jury duty", "stranded, waiting for a tow", "travelling", "sick". It is never a feeling, a quote or a wish. A feeling goes under "mood", which the reader throws away, so that it never lands on status. A status is specific enough that someone who reads only it knows what is going on: "training for the Chicago marathon", not "on a strict regimen"; "in meetings", not "busy". When the messages do not say what it is, write no status. A status that ends at a stated time carries "until".
  Worked examples. "jury duty makes me want to scream", from Sarah: person/sarah.status = "on jury duty" (conf 80), person/sarah.mood = "frustrated" (conf 60, discarded). "car died on route 9, stranded waiting for a tow": status = "stranded, waiting for a tow", location = "Route 9", thing/subaru.status = "broken down". "stuck in meetings till 11:30", from Sarah at 2026-08-19T10:03:00-04:00: person/sarah.status = "in meetings", until = "2026-08-19T11:30:00-04:00". "ugh, Mondays": nothing.
  A situation body carries participants (one observation per participant, value {"ref": ...}), location, and its times: "starts" and "ends" are the schedule (a meeting on December 5 has starts and ends on December 5, even today), "started" and "ended" are facts about what happened, written only once it has. Its status is "open" or "closed" (or "cancelled"), nothing else: never "upcoming", "under way" or "over", which are read off the times. A situation happens once: a breakdown, a birthday, a delivery.
  An activity is something that repeats: a class, a practice, a standing appointment, a weekly meeting. It is one body of kind activity, with schedule ("Mon/Wed 18:00"), cadence ("weekly"), location, participants and organizer. An occurrence of an activity is never a new body: write the activity's "last" = the start of that occurrence, with "at" = that start, and "next" = the start of the following one when the message says it. An occurrence that is called off is not a cancelled activity: write the activity's "skipped" = the start of that occurrence, one observation per occurrence, and never its "status", which means the whole series. A calendar reminder or notification for a repeating event is an occurrence of an activity, not a situation.
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
::  +merge-settings: a settings document merged over the stored one. A
::  JSON null clears a key, so the reader's default stands again; a
::  secret left blank keeps the stored value.
::
++  merge-settings
  |=  [base=(map @t json) doc=(map @t json) secrets=(set @t)]
  ^-  (map @t json)
  %+  roll  ~(tap by doc)
  |=  [[k=@t v=json] acc=_base]
  ?:  ?=(~ v)  (~(del by acc) k)
  ?:  &((~(has in secrets) k) ?=([%s *] v) =('' p.v))  acc
  (~(put by acc) k v)
::  +short-secret: a webhook secret under 16 bytes, which is refused;
::  a blank one is not a secret at all and keeps the stored one
::
++  short-secret
  |=  doc=json
  ^-  ?
  =/  s=@t  (gs doc 'secret')
  &(!=('' s) (lth (met 3 s) 16))
::  +hundredths: a JSON number (0.3, "0.6", 1) as hundredths, 0 to 100.
::  A value at or above 1 is already hundredths, so 30 stays 30 and the
::  page can read a threshold back and write it again unchanged; 0.3 is
::  a fraction and becomes 30. 1 is one hundredth: a caller who means
::  always sends 100.
::
++  hundredths
  |=  [j=json default=@ud]
  ^-  @ud
  =/  t=@t  (num-cord j)
  ?:  =('' t)  default
  =/  micro=@ud  (micro-of t)
  ?:  (gte micro 1.000.000)  (min 100 (div micro 1.000.000))
  (min 100 (div micro 10.000))
::  +$  reader-kind: what tells one reader's rows from another's: the
::  channel word the analyst reads, the signer on every fact, the
::  source-id prefix, and the reader's own window and record files.
::  The Telegram reader and the chat reader share every arm below
::  through it.
::
+$  reader-kind  [channel=@t by=@t prefix=@t recent=@ta last=@ta]
++  telegram-kind  ^-(reader-kind ['telegram' 'telegram' 'telegram/' %'telegram-recent.json' %'telegram-last.json'])
++  chat-kind      ^-(reader-kind ['chat' 'chat' 'chat/' %'chat-recent.json' %'chat-last.json'])
++  mail-kind      ^-(reader-kind ['mail' 'mail' 'mail/' %'mail-recent.json' %'mail-last.json'])
::  the read channel (version 59): text a client hands the ship to
::  read, a web page or a note, through POST /read; its settings are a
::  mail-config (poll and backfill unused), its source the page itself
++  read-kind      ^-(reader-kind ['web' 'web' 'web/' %'read-recent.json' %'read-last.json'])
::  ==  the mail reader (version 52): auspex's mail as facts, the way
::  the phone client's mail reader read it. The nexus walks auspex's
::  mail tree; these clam what it finds (auspex-chain's frozen
::  unsigned, its stored-msg and meta) and shape the reader's rows.
::
+$  mail-unsigned
  $:  from=@p  life=@ud  to=(set @p)  subj=@t  body=@t  body-mime=@t
      sent=@da  prev=(unit @uv)  attachments=(list [name=@t size=@ud mime=@t hash=@uv])
  ==
+$  mail-stored  [%2 msg=[u=mail-unsigned sig=@ux] verdict=?(%verified %unverified %forged)]
::  a thread's meta, whatever its version: every shape auspex has had
::  (%0 to %3) opens with the version, the read set and archived, and
::  archived is all the reader asks
+$  mail-meta    [ver=@ read=* archived=? rest=*]
::  one message as the reader sees it: its thread, its id (the sham of
::  the unsigned, as auspex names it), who, what, when, what it answers
::
+$  mail-msg  [tid=@t id=@t from=@p subj=@t body=@t sent=@da prev=(unit @uv) trusted=?]
++  mail-msg-of
  |=  [tid=@t st=mail-stored]
  ^-  mail-msg
  =/  u=mail-unsigned  u.msg.st
  ::  only a verified copy is the sender's: an unverified from (every
  ::  moon's and comet's) is anyone's claim, and a forged one a lie
  [tid (scot %uv (sham u)) from.u subj.u body.u sent.u prev.u =(%verified verdict.st)]
::  +mail-row: a message as the reader's row: the thread is the chat,
::  the subject heads the text
::
++  mail-row
  |=  m=mail-msg
  ^-  tg-msg
  =/  text=@t  ?:(=('' (trim-cord subj.m)) body.m (rap 3 subj.m nl nl body.m ~))
  [(cat 3 'mail:' tid.m) (scot %p from.m) text sent.m id.m '']
+$  mail-config
  $:  enabled=?  poll=@ud  backfill=@ud  gate=@ud  escalate=@ud  max-daily=@ud  model=@t
  ==
++  de-mail-config
  |=  j=json
  ^-  mail-config
  :*  =/(e (gj j 'enabled') ?:(?=([%b *] e) p.e &))
      (max 1 (min 1.440 (fall (gn j 'poll_minutes') 10)))
      (min 720 (fall (gn j 'backfill_hours') 720))
      (hundredths (gj j 'gate') 30)
      (hundredths (gj j 'escalate') 60)
      (fall (gn j 'max_daily_messages') 200)
      =/(m (gs j 'model') ?:(=('' m) 'deepseek/deepseek-v4-flash' m))
  ==
++  en-mail-config
  |=  c=mail-config
  ^-  json
  %-  pairs:enjs:format
  :~  ['enabled' b+enabled.c]
      ['poll_minutes' (numb:enjs:format poll.c)]
      ['backfill_hours' (numb:enjs:format backfill.c)]
      ['gate' (numb:enjs:format gate.c)]
      ['escalate' (numb:enjs:format escalate.c)]
      ['max_daily_messages' (numb:enjs:format max-daily.c)]
      ['model' s+model.c]
  ==
++  mail-as-tg
  |=  c=mail-config
  ^-  tg-config
  %*  .  *tg-config
    enabled     enabled.c
    model       model.c
    max-tokens  4.000
    gate        gate.c
    escalate    escalate.c
    max-daily   max-daily.c
  ==
::  +de-tg-config: the stored telegram.json as the reader's settings. A
::  chat id arrives as a number or a string and is kept as text either
::  way, since a chat id is a name, not a quantity.
::
++  de-tg-config
  |=  j=json
  ^-  tg-config
  =/  chats=(set @t)  (sy (turn (ga j 'chats') num-cord))
  =/  people=(map @t @t)
    =/  p=json  (gj j 'people')
    ?.  ?=([%o *] p)  ~
    %-  ~(gas by *(map @t @t))
    ^-  (list [@t @t])
    %+  murn  ~(tap by p.p)
    |=  [k=@t v=json]
    ^-  (unit [@t @t])
    ?.(?=([%s *] v) ~ `[k p.v])
  :*  =/(e (gj j 'enabled') ?:(?=([%b *] e) p.e &))
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
  =/  chat=@t  (num-cord (gj (gj msg 'chat') 'id'))
  =/  from=@t  (num-cord (gj (gj msg 'from') 'id'))
  ?:  |(=('' chat) =('' from))  ~
  =/  secs=@ud  (fall (gn msg 'date') 0)
  :-  ~
  :*  chat
      from
      (crip (trim-tape (trip (gs msg 'text'))))
      (add ~1970.1.1 (mul secs ~s1))
      (num-cord (gj msg 'message_id'))
      ?:(?=([%o *] biz) (gs msg 'business_connection_id') '')
  ==
++  tg-source
  |=  [m=tg-msg kind=reader-kind]
  ^-  source
  ::  a page read is its own source: the url, or what the client named
  ?:  =('web' channel.kind)  ['web' chat.m]
  ['chat' (rap 3 prefix.kind chat.m '/' mid.m ~)]
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
::  +tg-remember: the window with this message appended: a text starting
::  with a slash and an empty text never go in, five per chat, nothing
::  older than a day
++  tg-remember
  |=  [recent=json m=tg-msg who=@t now=@da kind=reader-kind]
  ^-  json
  =/  cutoff=@da  (sub now ~d1)
  ::  every chat's window drops what is older than a day, and a chat
  ::  left empty goes, so the file holds a day of text and no more
  =/  fresh-row
    |=  r=json
    ^-  ?
    =/  at=(unit @da)  (de-iso (gs r 'at'))
    ?~(at | (gte u.at cutoff))
  =/  base=(map @t json)
    ?.  ?=([%o *] recent)  ~
    %-  ~(gas by *(map @t json))
    %+  murn  ~(tap by p.recent)
    |=  [k=@t v=json]
    =/  kept=(list json)  (skim (ga recent k) fresh-row)
    ?~(kept ~ `[k a+kept])
  ?:  |(=('' text.m) =('/' (end [3 1] text.m)))  [%o base]
  =/  kept=(list json)  (ga [%o base] chat.m)
  =/  row=json
    %-  pairs:enjs:format
    :~  ['id' s+id:(tg-source m kind)]
        ['at' s+(en-iso at.m)]
        ['who' s+who]
        ['text' s+(end [3 2.000] text.m)]
    ==
  =/  all=(list json)  (snoc kept row)
  =/  n=@ud  (lent all)
  [%o (~(put by base) chat.m a+(slag (sub n (min n 5)) all))]
::  ==  the chat reader (version 39): Tlon's DMs, group DMs and the group
::  channels the owner picks, polled through two changes scries and read
::  through the same pipeline as Telegram
::
::  +$  chat-config: chat.json as the reader reads it. dms are whom
::  strings (~ship or 0v...), channels are nests (chat/~host/name),
::  people maps a ship to a body id and is merged over the ship
::  attributes of the person bodies each pass, settings winning.
::
+$  chat-config
  $:  enabled=?
      dms=(set @t)
      channels=(set @t)
      people=(map @t @t)
      read-own=?
      poll=@ud
      backfill=@ud
      gate=@ud
      escalate=@ud
      max-daily=@ud
      model=@t
      send-dms=?
  ==
::  +ship-key: a ship as the people map keys it: lower case, one sig
::
++  ship-key
  |=  k=@t
  ^-  @t
  =/  t=@t  (lower (trim-cord k))
  ?:  |(=('' t) =('~' (end [3 1] t)))  t
  (cat 3 '~' t)
::  +whom-key: a DM's whom as Tlon keys it: a club id as written, a
::  ship lower case with one sig
::
++  whom-key
  |=  k=@t
  ^-  @t
  =/  t=@t  (lower (trim-cord k))
  ?:(=('0v' (end [3 2] t)) t (ship-key t))
++  de-chat-config
  |=  j=json
  ^-  chat-config
  =/  names  |=([k=@t f=$-(@t @t)] ^-((set @t) (~(del in (sy (turn (strings (ga j k)) f))) '')))
  =/  people=(map @t @t)
    =/  p=json  (gj j 'people')
    ?.  ?=([%o *] p)  ~
    %-  ~(gas by *(map @t @t))
    %+  murn  ~(tap by p.p)
    |=  [k=@t v=json]
    ^-  (unit [@t @t])
    ?.(?=([%s *] v) ~ `[(ship-key k) p.v])
  :*  =/(e (gj j 'enabled') ?:(?=([%b *] e) p.e &))
      (names 'dms' whom-key)
      (names 'channels' |=(t=@t (lower (trim-cord t))))
      people
      =/(r (gj j 'read_own') ?:(?=([%b *] r) p.r |))
      (max 1 (min 1.440 (fall (gn j 'poll_minutes') 5)))
      (min 720 (fall (gn j 'backfill_hours') 24))
      (hundredths (gj j 'gate') 30)
      (hundredths (gj j 'escalate') 60)
      (fall (gn j 'max_daily_messages') 500)
      =/(m (gs j 'model') ?:(=('' m) 'deepseek/deepseek-v4-flash' m))
      =/(r (gj j 'send_dms') ?:(?=([%b *] r) p.r &))
  ==
++  en-chat-config
  |=  c=chat-config
  ^-  json
  =/  names  |=(xs=(set @t) ^-(json a+(turn (sort ~(tap in xs) aor) |=(x=@t `json`s+x))))
  %-  pairs:enjs:format
  :~  ['enabled' b+enabled.c]
      ['dms' (names dms.c)]
      ['channels' (names channels.c)]
      ['people' [%o (~(run by people.c) |=(v=@t `json`s+v))]]
      ['read_own' b+read-own.c]
      ['send_dms' b+send-dms.c]
      ['poll_minutes' (numb:enjs:format poll.c)]
      ['backfill_hours' (numb:enjs:format backfill.c)]
      ['gate' (numb:enjs:format gate.c)]
      ['escalate' (numb:enjs:format escalate.c)]
      ['max_daily_messages' (numb:enjs:format max-daily.c)]
      ['model' s+model.c]
  ==
::  +chat-as-tg: the chat settings as the shared reader arms take them
::
++  chat-as-tg
  |=  c=chat-config
  ^-  tg-config
  %*  .  *tg-config
    enabled     enabled.c
    model       model.c
    max-tokens  4.000
    people      people.c
    gate        gate.c
    escalate    escalate.c
    max-daily   max-daily.c
  ==
::  +story-text: a Tlon story (tlon-apps desk/lib/story-json.hoon,
::  +enjs: a story is an array of verses, each {inline: [...]} or
::  {block: ...}) as the text a reader reads: inline strings appended,
::  a break a newline, a ship its @p, bold, italics, strike and
::  blockquote their contents, a link its content, code and tags their
::  text; a block verse says nothing.
::
++  story-text
  |=  story=json
  ^-  @t
  %-  crip
  %-  zing
  %+  join  "\0a"
  %+  murn  ?:(?=([%a *] story) p.story ~)
  |=  v=json
  ^-  (unit tape)
  =/  inl=json  (gj v 'inline')
  ?.(?=([%a *] inl) ~ `(inlines-text p.inl))
++  inlines-text
  |=  xs=(list json)
  ^-  tape
  %-  zing
  %+  turn  xs
  |=  x=json
  ^-  tape
  ?:  ?=([%s *] x)  (trip p.x)
  ?.  ?=([%o *] x)  ""
  ?:  (~(has by p.x) 'break')  "\0a"
  =/  ship=json  (gj x 'ship')
  ?:  ?=([%s *] ship)  (trip p.ship)
  =/  nested=(unit (list json))
    =/  keys=(list @t)  ~['bold' 'italics' 'strike' 'blockquote']
    |-
    ?~  keys  ~
    =/  v=json  (gj x i.keys)
    ?:(?=([%a *] v) `p.v $(keys t.keys))
  ?^  nested  (inlines-text u.nested)
  =/  link=json  (gj x 'link')
  ?:  ?=([%o *] link)  (trip (gs link 'content'))
  =/  task=json  (gj x 'task')
  ?:  ?=([%o *] task)  (inlines-text (ga task 'content'))
  =/  plain=@t
    =/  keys=(list @t)  ~['inline-code' 'code' 'tag']
    |-
    ?~  keys  ''
    =/  t=@t  (gs x i.keys)
    ?:(!=('' t) t $(keys t.keys))
  (trip plain)
::  +chat-rows, +channel-rows: the reader's message rows from the chat
::  agent's changes answer (a map from whom to writs or null, tlon-apps
::  desk/mar/chat/changed-writs-1.hoon) and the channels agent's (a
::  map from nest to posts or null, desk/mar/channel/changed-posts-1.
::  hoon). A writ or post is {seal, essay, type} (chat-json v7 +writ,
::  channel-json v10 +post); a tombstone has no essay and is skipped;
::  a reply under seal.replies is {seal, reply-essay} and counts as a
::  message of its own. essay.sent is epoch milliseconds, essay.author
::  a ship string or {ship, nickname, avatar}. Only the conversations
::  the owner picked are read, only what was sent after floor (the
::  first pass's look-back; later passes take everything the scry
::  says changed, since a writ delivered late arrives once and the
::  seen ring drops repeats), and the owner's own words only when
::  read_own says so. In no order: the caller sorts the two lists
::  together.
::
++  chat-rows
  |=  [changes=json cfg=chat-config floor=@da our=@t]
  ^-  (list tg-msg)
  (conv-rows changes dms.cfg & cfg floor our)
++  channel-rows
  |=  [changes=json cfg=chat-config floor=@da our=@t]
  ^-  (list tg-msg)
  (conv-rows changes channels.cfg | cfg floor our)
++  conv-rows
  |=  [changes=json picked=(set @t) any=? cfg=chat-config floor=@da our=@t]
  ^-  (list tg-msg)
  ?.  ?=([%o *] changes)  ~
  %-  zing
  %+  turn  ~(tap by p.changes)
  |=  [whom=@t bag=json]
  ^-  (list tg-msg)
  ::  no DM picked means every DM (any); a channel is read only when
  ::  picked, since a group's channels are not the owner's own talk
  ?.  |(&(any =(~ picked)) (~(has in picked) whom))  ~
  ?.  ?=([%o *] bag)  ~
  %-  zing
  %+  turn  ~(tap by p.bag)
  |=  [k=@t w=json]
  ^-  (list tg-msg)
  =/  top=(list tg-msg)
    =/  t=(unit tg-msg)  (post-row whom w 'essay' cfg floor our)
    ?~(t ~ ~[u.t])
  =/  replies=json  (gj (gj w 'seal') 'replies')
  ?.  ?=([%o *] replies)  top
  %+  weld  top
  ^-  (list tg-msg)
  %+  murn  ~(tap by p.replies)
  |=  [k=@t r=json]
  (post-row whom r 'reply-essay' cfg floor our)
++  post-row
  |=  [whom=@t w=json key=@t cfg=chat-config floor=@da our=@t]
  ^-  (unit tg-msg)
  =/  essay=json  (gj w key)
  ?.  ?=([%o *] essay)  ~
  =/  sent=@da  (da-of-ms (fall (gn essay 'sent') 0))
  ?.  (gth sent floor)  ~
  =/  author=@t
    =/  a=json  (gj essay 'author')
    (ship-key ?:(?=([%s *] a) p.a (gs a 'ship')))
  ?:  &(!read-own.cfg =(author (ship-key our)))  ~
  =/  mid=@t  (num-cord (gj (gj w 'seal') 'id'))
  ?:  =('' mid)  ~
  `[whom author (trim-cord (story-text (gj essay 'content'))) sent mid '']
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
      owner=(list @t)
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
  [bodies attrs notes 'person/me' kinds payloads (owner-lines schema &)]
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
  |=  [rows=(list window-row) ctx=reader-ctx tz=@t kind=reader-kind]
  ^-  @t
  (reader-prompt-with rows ctx tz kind ~)
::  +reader-prompt-with: the reader's prompt with lines of the caller's
::  between the bodies and the messages (the brief's tagged actions)
::
++  reader-prompt-with
  |=  [rows=(list window-row) ctx=reader-ctx tz=@t kind=reader-kind extra=(list @t)]
  ^-  @t
  =/  head=(list @t)
    :~  (cat 3 'Channel: ' channel.kind)
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
  =/  shapes=(list @t)
    (ctx-lines ctx 'Action kinds you may propose: ' 'Existing bodies (id | name | aliases):')
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
  ;:  weld  head  owner.ctx  attr-lines  note-lines  shapes  extra  `(list @t)`~['']  msg-lines  ==
::  ==  the reader's validation: the model's answer as facts the ship
::  will take, with notes on what was dropped (analyze.validate)
::
::  +ctx-lines: the action kinds with their payload shapes and the bodies
::  the ship knows, as the reader and the refiner both list them
::
++  ctx-lines
  |=  [ctx=reader-ctx kinds-head=@t bodies-head=@t]
  ^-  (list @t)
  %+  weld
    :-  (cat 3 kinds-head (join-cords ', ' kinds.ctx))
    %+  turn  (sort ~(tap by payloads.ctx) |=([a=[@t *] b=[@t *]] (aor -.a -.b)))
    |=([k=@t shape=json] (rap 3 '  ' k ' payload: ' (en:json:html shape) ~))
  :-  bodies-head
  ?~  bodies.ctx  `(list @t)`~['  (none known)']
  %+  turn  bodies.ctx
  |=(b=ctx-body (rap 3 '  ' id.b ' | ' name.b ' | ' (join-cords ', ' aliases.b) ~))
::  +clean-aliases: an answer's alias strings, held to de-body's caps
::
++  clean-aliases
  |=  raw=(list json)
  ^-  (list @t)
  %+  scag  max-aliases
  %+  murn  raw
  |=  a=json
  ^-  (unit @t)
  ?.  ?=([%s *] a)  ~
  =/  t=@t  (trim-cord p.a)
  ?:(=('' t) ~ `(end [3 max-alias] t))
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
::  ("required: one of telegram, mail, chat"), or ~ when it is free.
::  The list ends at its clause: a note goes on after a semicolon or a
::  full stop to say when each value applies, and those words are not
::  values.
::
++  one-of
  |=  shape=@t
  ^-  (list @t)
  =/  s=tape  (trip shape)
  =/  at=(unit @ud)  (find "one of" s)
  ?~  at  ~
  =/  rest=tape
    =/  r=tape  (slag (add u.at 6) s)
    |-  ^-  tape
    ?~  r  ~
    ?:  |(=(';' i.r) =('.' i.r))  ~
    [i.r $(r t.r)]
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
  =/  aliases=(list @t)  (clean-aliases (ga b 'aliases'))
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
  ::  an array value is one observation per element: the writer holds
  ::  one value to a row
  =/  arr=json  (gj o 'value')
  ?:  ?=([%a *] arr)
    $(raw (weld (turn p.arr |=(e=json (set-key o 'value' e))) t.raw))
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
::  words too common to say which body a message is about
::
++  common-words
  %-  sy
  ^-  (list @t)
  :~  'with'  'from'  'that'  'this'  'have'  'will'  'about'  'they'  'them'  'then'
      'than'  'what'  'when'  'where'  'which'  'there'  'their'  'here'  'your'  'been'
      'were'  'just'  'like'  'some'  'more'  'also'  'into'  'over'  'after'  'before'
      'again'  'week'  'next'  'last'  'today'  'tomorrow'  'tonight'  'morning'
      'evening'  'night'  'time'  'plan'  'plans'  'trip'  'visit'  'going'  'come'
      'coming'  'back'  'home'  'thing'  'things'  'stuff'  'work'  'call'  'need'
      'want'  'good'  'okay'  'yeah'  'sure'  'know'  'think'  'still'  'maybe'
      'should'  'could'  'would'  'because'  'really'  'very'  'much'  'many'  'every'
      'each'  'other'  'only'  'even'  'make'  'made'  'take'  'took'  'said'  'says'
      'tell'  'told'  'meeting'  'dinner'  'lunch'  'party'  'weekend'  'holiday'
  ==
::  +distinct-word: whether a name and a message share a word that
::  says something: four letters or more, and not one of the common
::  ones, so "Trip to Lisbon" is named by "flying to lisbon" and "Trip
::  planning" is not named by "the trip with dana"
::
++  distinct-word
  |=  [name=@t said=(set @t)]
  ^-  ?
  %+  lien  (word-list name)
  |=(w=@t &((gte (met 3 w) 4) !(~(has in common-words) w) (~(has in said) w)))
::  +ground: bot.grounded. The model's facts that its messages bear
::  out: about the author, when the message is theirs to speak for, or
::  a body the message names (a body the batch itself makes, whose
::  name the model wrote, is named by a distinctive word of it); a
::  value other than a status, a health or a time found in the
::  message's words (a time is the model's reading of "the 12th",
::  never quoted); a status or health not read from the earlier
::  messages instead; a status naming a diagnosis moved to health;
::  nothing from a question. The rest is dropped with a note, and so
::  is a new body no fact kept is about.
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
  =/  known=(set @t)
    (~(gas in *(set @t)) (turn bodies.ctx |=(b=ctx-body id.b)))
  =/  made=(list [id=@t name=@t])
    %+  murn  bodies.facts
    |=  b=json
    ^-  (unit [id=@t name=@t])
    =/  id=@t  (gs b 'id')
    ?:((~(has in known) id) ~ `[id (gs b 'name')])
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
  =/  named=(set @t)
    %-  ~(gas in (named-in text pool))
    (murn made |=([id=@t name=@t] ?:((distinct-word name said) `id ~)))
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
            !=(who.m (gs value 'ref'))
        ==
      (cat 3 'the message does not name ' (gs value 'ref'))
    ?:  ?&  !(~(has in paraphrased) attr)
            |(?=([%s *] value) ?=([%n *] value))
            ?=(~ (de-iso-any vtext))
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
::  ==  refine: the owner's note under a proposed action, applied
::  through one model call (version 36). The checks are the reader's
::  where they apply: the payload shape, the bodies, the times.
::
::  the checked answer: the bodies the ship lacks, each observe-ready,
::  the four fields the revision rewrites, each extra as an act-ready
::  action, not yet stamped, and a note per extra dropped
::
+$  refined
  $:  bodies=(list json)
      title=@t
      payload=json
      about=(list @t)
      due=(unit @da)
      extras=(list json)
      notes=(list @t)
  ==
::  +refine-prompt: orrery-utils/common/refine-prompt.md, word for
::  word; scripts/prompt-drift.py holds it there. Edit the file, not this.
::
++  refine-prompt
  ^-  @t
  '''
  You refine one proposed action for orrery, a model of one person's world, from a note the owner typed while approving it.

  You are given the action as JSON, the shapes the schema allows for each action kind, the bodies the ship knows (id, name, aliases), the owner's clock, their style and standing preferences when they have written any, and the note. Answer with one JSON object and nothing else: {"bodies": [...], "action": {"title": ..., "payload": {...}, "about": [...], "due": ... or null}, "extras": [...], "refused": ""}.

  The action keeps its kind and its purpose; the note changes what it says. "Include Dana in this" adds a person the ship knows to a message's recipients or an event's participants and names them in the text or title; "make it 3pm" moves the time on the owner's clock; "shorter" or "friendlier" rewrites the text in the owner's own voice. "Send this as mail" sets via to mail, "as a DM" to chat, "over telegram" to telegram; the owner's word on the channel is final. Keep the action's about and due as they are unless the note changes them. Every body you name is an id from the list when the list has it, by name or alias. A person the note names whom the list does not have is new: put them in "bodies" as {"id": "person/<slug of the name>", "kind": "person", "name": "<the name as written>", "aliases": []} and use that id; the same for a place, a thing or an org the note names. The owner does not add every person they meet by hand. A time is ISO 8601 UTC; a bare clock time in the note is on the owner's clock.

  What the note asks for beyond this action goes in extras, each a complete new action with kind, title, payload in the schema's shape, about and due: "also add a todo the day before to go shopping" is a task due one day before the event's start. Never repeat the action itself as an extra.

  Every text and title you write is short and plain, and follows the owner's style when one is given.

  When the note asks for something no action kind can carry, answer {"refused": "<one plain sentence saying why>"} and change nothing.
  '''
::  +refine-user: the user prompt: the clock, the shapes, the bodies,
::  the action and the note, in that order, so the note is the last
::  thing the model reads.
::
++  refine-user
  |=  [a=action id=@ta ctx=reader-ctx text=@t now=@da tz=@t]
  ^-  @t
  %+  join-cords  nl
  ;:  weld
    `(list @t)`~[(rap 3 'The owner\'s clock reads ' (local-iso (en-iso now) tz) '.' ~)]
    owner.ctx
    (ctx-lines ctx 'Action kinds an extra may have: ' 'Bodies the ship knows (id | name | aliases):')
    `(list @t)`~[(cat 3 'The action: ' (en:json:html (en-action id a)))]
    `(list @t)`~[(cat 3 'The note: ' text)]
  ==
::  +hold-extra-plan: a calendar extra stands against the clock the way
::  rule 14 holds a plan to its message: a start ahead of now and
::  within the year, and an end, when given, after the start. An end
::  the model left null or empty is no end, and goes the way hold-plan
::  sends one, since de-action would refuse it.
::
++  hold-extra-plan
  |=  [payload=(map @t json) now=@da]
  ^-  (each (map @t json) @t)
  =/  start=(unit @da)  (de-iso-any (ref-or-text (fall (~(get by payload) 'starts') `json`~)))
  ?~  start  [%| 'starts is not a time']
  ?:  |((lth u.start now) (gth u.start (add now ~d365)))
    [%| 'starts is not within the year ahead']
  =/  raw=(unit json)  (~(get by payload) 'ends')
  ?.  (filled raw)  [%& (~(del by payload) 'ends')]
  =/  end=(unit @da)  (de-iso-any (ref-or-text (need raw)))
  ?~  end  [%| 'ends is not a time']
  ?.  (gth u.end u.start)  [%| 'ends is not after starts']
  [%& payload]
::  +clean-json-text: the prose rules' last line on a payload: an em
::  dash in its text becomes a comma before the payload is filed
::
++  clean-json-text
  |=  j=json
  ^-  json
  ?.  ?=([%o *] j)  j
  =/  t=(unit json)  (~(get by p.j) 'text')
  ?.  ?=([~ %s *] t)  j
  [%o (~(put by p.j) 'text' s+(clean-text p.u.t))]
::  +refine-check: the model's answer held to the ship: a refusal is
::  passed on; a new body has a well-formed id, a name, and one of the
::  four kinds a note may name (a situation or an activity is a
::  reader's to describe from messages, not a note's to conjure); every
::  about and the recipient name a body the ship has or the answer
::  creates; the payload keeps its kind's shape; a due that is written
::  but does not parse refuses, since clearing it would lose a time the
::  owner meant to keep; an extra that fails its checks is dropped,
::  since the revision stands alone
::
++  refine-check
  |=  [answer=json a=action id=@ta ctx=reader-ctx now=@da]
  ^-  (each refined @t)
  (refine-check-in answer a id ctx now ~ ~)
::  +refine-check-in: +refine-check knowing every body on the ship and
::  the kinds a key may reach (~ for the owner): a body the ship has is
::  a reference, never made again (which renamed it), and one outside
::  the key's kinds is neither made nor named
::
++  refine-check-in
  |=  [answer=json a=action id=@ta ctx=reader-ctx now=@da exists=(set @t) kinds=(unit (set @tas))]
  ^-  (each refined @t)
  =/  in-scope
    |=  b=@t
    ^-  ?
    ?~  kinds  &
    =/  pk  (parse-bid b)
    ?~(pk | (~(has in u.kinds) kind.u.pk))
  =/  refused=@t  (gs answer 'refused')
  ?.  =('' refused)  [%| refused]
  ::  the original's own links count as known: the context caps its
  ::  bodies and drops old closed situations, and the model echoes them
  =/  had=(set @t)
    (~(gas in (sy (turn bodies.ctx |=(b=ctx-body id.b)))) ~(tap in about.a))
  =/  made=(list json)
    %+  murn  (ga answer 'bodies')
    |=  b=json
    ^-  (unit json)
    ?.  ?=([%o *] b)  ~
    =/  bid=@t  (lower (trim-cord (gs b 'id')))
    =/  pk  (parse-bid bid)
    ?~  pk  ~
    ?:  (~(has in had) bid)  ~
    ?:  (~(has in exists) bid)  ~
    ?.  (in-scope bid)  ~
    ?.  ?=(?(%person %place %thing %org) kind.u.pk)  ~
    ?.  (~(has by attrs.ctx) `@t`kind.u.pk)  ~
    =/  name=@t  (end [3 120] (trim-cord (gs b 'name')))
    ?:  =('' name)  ~
    =/  aliases=(list @t)  (clean-aliases (ga b 'aliases'))
    :-  ~
    %-  pairs:enjs:format
    :~  ['id' s+bid]
        ['kind' s+`@t`kind.u.pk]
        ['name' s+name]
        ['aliases' a+(turn aliases |=(x=@t `json`s+x))]
    ==
  =/  known=(set @t)
    %-  ~(gas in had)
    (weld (turn made |=(b=json (gs b 'id'))) (skim ~(tap in exists) in-scope))
  ::  a name or an alias, lower-cased, stands for its id: the model may
  ::  write "dana" where the ship says person/dana-hill
  =/  alias=(map @t @t)
    %-  ~(gas by *(map @t @t))
    ^-  (list [@t @t])
    %-  zing
    ^-  (list (list [@t @t]))
    %+  weld
      %+  turn  bodies.ctx
      |=  b=ctx-body
      ^-  (list [@t @t])
      [[(lower name.b) id.b] (turn aliases.b |=(x=@t [(lower x) id.b]))]
    %+  turn  made
    |=(b=json ^-((list [@t @t]) ~[[(lower (gs b 'name')) (gs b 'id')]]))
  =/  resolve
    |=  x=json
    ^-  @t
    (canon-id alias (lower (trim-cord (ref-or-text x))))
  =/  act=json  (gj answer 'action')
  ?.  ?=([%o *] act)  [%| 'the model answered no action']
  =/  title=@t
    =/  t=@t  (end [3 200] (trim-cord (gs act 'title')))
    ?:(=('' t) title.a t)
  =/  about-raw=(list @t)
    ?.  (has-key act 'about')  ~(tap in about.a)
    (turn (ga act 'about') resolve)
  =/  bad=(list @t)  (skip about-raw |=(x=@t (~(has in known) x)))
  ?^  bad  [%| (rap 3 'no body named ' i.bad ' on the ship' ~)]
  =/  about=(list @t)  (scag 20 (dedupe about-raw))
  =/  pay=(map @t json)
    =/  p=json  (gj act 'payload')
    ?:(?=([%o *] p) p.p ~)
  =/  held  (hold-payload pay (fall (~(get by payloads.ctx) kind.a) `json`~) known alias)
  ?:  ?=([%| *] held)  [%| p.held]
  =/  due-s=@t  (gs act 'due')
  =/  due=(unit @da)
    ?.  (has-key act 'due')  due.a
    ?:(=('' due-s) ~ (de-iso-any due-s))
  ?:  &(!=('' due-s) ?=(~ due))  [%| 'due is not a time']
  ::  each extra as an act, or why it is dropped; the revision stands
  ::  whatever becomes of its extras, so a bad one is a note, not a refusal
  =/  extra-of
    |=  e=json
    ^-  (each json @t)
    ?.  ?=([%o *] e)  [%| 'not an object']
    =/  kind=@t  (lower (trim-cord (gs e 'kind')))
    ?.  (lien kinds.ctx |=(k=@t =(k kind)))
      [%| (cat 3 'an extra may not be a ' ?:(=('' kind) '(no kind)' kind))]
    =/  et=@t  (end [3 200] (trim-cord (gs e 'title')))
    ?:  =('' et)  [%| 'no title']
    =/  eabout=(list @t)
      (skim (turn (ga e 'about') resolve) |=(x=@t (~(has in known) x)))
    =/  epay=(map @t json)
      =/  p=json  (gj e 'payload')
      ?:(?=([%o *] p) p.p ~)
    =/  eheld  (hold-payload epay (fall (~(get by payloads.ctx) kind) `json`~) known alias)
    ?:  ?=([%| *] eheld)  [%| p.eheld]
    =/  planned  ?.(=('calendar' kind) eheld (hold-extra-plan p.eheld now))
    ?:  ?=([%| *] planned)  [%| p.planned]
    =/  edue-s=@t  (gs e 'due')
    =/  edue=(unit @da)  ?:(=('' edue-s) ~ (de-iso-any edue-s))
    ?:  &(!=('' edue-s) ?=(~ edue))  [%| 'due is not a time']
    =/  eabout-all=(list @t)  (scag 20 (dedupe (weld eabout ~(tap in about.a))))
    =/  epayload=json  (clean-json-text [%o (~(put by p.planned) 'refined_from' s+id)])
    :-  %&
    %-  pairs:enjs:format
    %-  zing
    :~  :~  ['kind' s+kind]
            ['title' s+et]
            ['payload' epayload]
            ['about' a+(turn eabout-all |=(x=@t `json`s+x))]
        ==
        ?~(edue ~ ~[['due' s+(en-iso u.edue)]])
    ==
  =/  sorted=[extras=(list json) notes=(list @t)]
    %+  roll  (ga answer 'extras')
    |=  [e=json acc=[extras=(list json) notes=(list @t)]]
    ^-  [extras=(list json) notes=(list @t)]
    =/  got  (extra-of e)
    ?:  ?=([%& *] got)  [(snoc extras.acc p.got) notes.acc]
    =/  shown=@t
      =/  t=@t  (trim-cord (gs e 'title'))
      ?:(=('' t) '(no title)' t)
    [extras.acc (snoc notes.acc (rap 3 'dropped extra ' shown ': ' p.got ~))]
  [%& made title (clean-json-text [%o p.held]) about due extras.sorted notes.sorted]
::  +refine-ops: the writer ops that file a checked answer: an observe
::  with the new bodies when there are any, the revision, then one act
::  per extra, each stamped by the same hand. The notes are the route's
::  to report, not the writer's.
::
++  refine-ops
  |=  [r=refined id=@ta by=@t now=@da]
  ^-  (list json)
  %+  weld
    ?~(bodies.r ~ (observe-ops bodies.r ~))
  :-  (revise-action-op id title.r payload.r about.r due.r by)
  %+  turn  extras.r
  |=  e=json
  (pairs:enjs:format ~[['op' s+'act'] ['action' (fill-act-as e now by)]])
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
  :~  ['message' s+(run-text new)]
      ['from' s+?~(new '' who:(rear new))]
      ['earlier' a+(turn earlier |=(r=window-row `json`s+text.r))]
      ['known_bodies' a+(turn (rank-bodies bodies.ctx rows) |=(b=ctx-body `json`s+(known-line b)))]
      ['rule' s+'a status is a circumstance, never a feeling; only facts about people, things, places and plans are recorded']
  ==
::  +scope-facts: what a key's handed-in text may file (version 60): the
::  bodies of its kinds, the observations it could have made itself
::  (+out-of-scope's rule, hidden attributes held back), the actions
::  of its action kinds about bodies of its kinds; the rest dropped
::  with a note
::
++  scope-facts
  |=  [f=tg-facts s=scope hide=(set @t)]
  ^-  tg-facts
  =/  in-kinds
    |=  b=@t
    ^-  ?
    =/  pk  (parse-bid b)
    ?~(pk | (kind-in-scope s kind.u.pk))
  =/  bodies=(list json)  (skim bodies.f |=(b=json (in-kinds (gs b 'id'))))
  =/  obs=(list json)
    %+  skim  obs.f
    |=(o=json ?=(~ (out-of-scope (pairs:enjs:format ~[['observations' a+~[o]]]) s hide)))
  =/  acts=(list json)
    %+  skim  acts.f
    |=  a=json
    ?.  (~(has in actions.s) `@tas`(gs a 'kind'))  |
    (levy (strings (ga a 'about')) in-kinds)
  =/  dropped=@ud
    :(add (sub (lent bodies.f) (lent bodies)) (sub (lent obs.f) (lent obs)) (sub (lent acts.f) (lent acts)))
  =/  said=(list @t)
    ?:  =(0 dropped)  ~
    ~[(rap 3 'dropped ' (crip (a-co:co dropped)) ' outside the key\'s scope' ~)]
  f(bodies bodies, obs obs, acts acts, notes (weld notes.f said))
::  +run-text: a run's new messages as the one message the decider
::  judges, oldest first, a line each: judging the last alone let "ugh"
::  after "car broke down" drop the whole run
::
++  run-text
  |=  new=(list window-row)
  ^-  @t
  (join-lines (turn new |=(r=window-row text.r)))
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
++  status-asked
  |=  obs=(list json)
  ^-  (list [i=@ud o=json])
  =/  n=@ud  0
  |-
  ?~  obs  ~
  =/  rest  $(obs t.obs, n +(n))
  ?:  &(=('status' (gs i.obs 'attr')) =('person/' (end [3 7] (gs i.obs 'subject'))))  [[n i.obs] rest]
  rest
++  status-body
  |=  [rows=(list window-row) obs=(list json)]
  ^-  json
  =/  new=(list window-row)  (skip rows |=(r=window-row context.r))
  =/  asked=(list [i=@ud o=json])  (status-asked obs)
  %-  pairs:enjs:format
  :~  :-  'state'
      %-  pairs:enjs:format
      :~  ['message' s+(run-text new)]
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
::  ==  executors (version 34): the ship carries out its own approved
::  actions. +plan-exec says what to do for each; the fiber does it.
::
::  +ms-of / +da-of-ms: epoch milliseconds, what the calendar takes. A
::  time before the epoch answers 0, since an underflow would crash the
::  fiber over one odd due.
::
++  ms-of
  |=  t=@da
  ^-  @ud
  ?:  (lth t ~1970.1.1)  0
  (div (mul 1.000 (sub t ~1970.1.1)) ~s1)
++  da-of-ms  |=(ms=@ud ^-(@da (add ~1970.1.1 (div (mul ms ~s1) 1.000))))
::  one action's way out: for telegram, to is the chat id and body the
::  sendMessage JSON; for mail, to is the ship and body holds subject
::  and text; for calendar and todo, body is the add-event JSON and to
::  is ''. A message whose person lacks the attribute its channel needs
::  keeps its target with to '' and says why in note.
::
+$  exec-plan
  $:  id=@ta
      kind=@tas
      target=?(%telegram %mail %chat %calendar %todo %uncalendar)
      to=@t
      body=json
      note=@t
  ==
::  +chat-of-people: the first Telegram user id the reader's people map
::  gives a body id, '' when none does
::
++  chat-of-people
  |=  [people=(map @t @t) who=@t]
  ^-  @t
  =/  hits=(list [uid=@t bid=@t])  (skim ~(tap by people) |=([uid=@t bid=@t] =(bid who)))
  ?~(hits '' uid.i.hits)
++  loaded-of
  |=  [all=(list loaded) id=@t]
  ^-  (unit loaded)
  ?~  all  ~
  ?:(=(id id.i.all) `i.all $(all t.all))
::  +attr-text: a body's live string attribute, '' when none
::
++  attr-text
  |=  [all=(list loaded) multi=(set @t) now=@da id=@t attr=@t]
  ^-  @t
  =/  hit=(unit loaded)  (loaded-of all id)
  ?~  hit  ''
  (winner-text (fold rows.u.hit multi now) attr)
::  +whole-days: a start and an end both at midnight UTC, at least a
::  day apart: an all-day event rather than a timed one
::
++  whole-days
  |=  [s=@da e=@da]
  ^-  ?
  &(=(0 (mod s ~d1)) =(0 (mod e ~d1)) (gte e (add s ~d1)))
::  +event-json: the calendar's add-event poke for a calendar or task
::  action. A task is a todo with its due; a calendar action is a
::  one-off (kind once) allday event when its times are whole days,
::  else a timed one from starts to ends (or an hour) in zone, the
::  calendar's default when zone is ''. ~ when a calendar action's
::  starts does not parse. The calendar keeps start_ms and end_ms as
::  the zone's own clock encoded as if it were UTC (its page builds
::  them with Date.UTC from the local fields), so both are shifted
::  into the zone's clock first; whole days are judged on that clock
::  too. A zone the ship cannot render is passed through unshifted.
::
++  wall-of
  |=  [at=@da tz=@t]
  ^-  @da
  =/  z=(unit zone)  (~(get by zones) tz)
  ?~  z  at
  =/  shift=@dr  (mul ?:((in-dst u.z at) dst.u.z std.u.z) ~m1)
  ?:(west.u.z (sub at shift) (add at shift))
++  event-json
  |=  [id=@ta a=action zone=@t]
  ^-  (unit json)
  =/  title=@t  =/(t (gs payload.a 'title') ?:(=('' t) title.a t))
  =/  meta-base=(list [@t json])
    :~  ['name' s+title]
        ['orrery' s+id]
        ['tags' a+~[s+'orrery']]
    ==
  ?:  =(%task kind.a)
    =/  note=@t  (gs payload.a 'notes')
    =/  meta=json
      (pairs:enjs:format ?:(=('' note) meta-base (snoc meta-base ['note' s+note])))
    :-  ~
    %-  pairs:enjs:format
    %+  weld
      ^-  (list [@t json])
      ~[['action' s+'add-event'] ['cat' s+'todo'] ['meta' meta]]
    ^-  (list [@t json])
    ?~(due.a ~ ~[['due_ms' (numb:enjs:format (ms-of u.due.a))]])
  =/  s=(unit @da)  (gt payload.a 'starts')
  ?~  s  ~
  ::  a zone the ship cannot render (or none) is sent as the UTC
  ::  instant under Etc/UTC, which the calendar knows; sent unshifted
  ::  under its own name the calendar would read UTC as the local clock
  =/  shift=?  (~(has by zones) zone)
  =.  zone  ?:(shift zone 'Etc/UTC')
  =/  start=@da  ?:(shift (wall-of u.s zone) u.s)
  =/  end=@da
    =/  e=@da  (fall (gt payload.a 'ends') (add u.s ~h1))
    ?:(shift (wall-of e zone) e)
  =/  loc=@t  (gs payload.a 'location')
  =/  meta=json
    (pairs:enjs:format ?:(=('' loc) meta-base (snoc meta-base ['location' s+loc])))
  =/  base=(list [@t json])
    :~  ['action' s+'add-event']
        ['meta' meta]
        ['kind' s+'once']
        ['start_ms' (numb:enjs:format (ms-of start))]
    ==
  :-  ~
  %-  pairs:enjs:format
  ?:  (whole-days start end)
    %+  weld  base
    ^-  (list [@t json])
    ~[['cat' s+'allday'] ['span_days' (numb:enjs:format (div (sub end start) ~d1))]]
  %+  weld  base
  %+  weld
    ^-  (list [@t json])
    ~[['cat' s+'timed'] ['fin' s+'to'] ['end_ms' (numb:enjs:format (ms-of end))]]
  ^-  (list [@t json])
  ~[['zone' s+zone]]
::  +plan-exec: what to do for each approved action. A message goes by
::  its via: telegram to the person's telegram chat id, mail to their
::  ship (with its ~); another via is not ours. The chat id is the
::  person's telegram attribute, or failing that the reader's people
::  map read backwards (the Telegram user id whose body is the person),
::  which is how the bot found it too. A calendar or task action whose
::  mode is add (the default) becomes an add-event in the owner's zone.
::  A calendar action whose mode is cancel becomes an uncalendar plan
::  naming the event and, when the payload carries starts, the
::  occurrence's epoch ms as body's start_ms, else an empty body. A
::  mode that is neither add nor cancel, or a cancel with no event, is
::  left approved and noted, the way a message with no address is.
::  Anything else, or an add with no start, yields nothing.
::
++  plan-exec
  |=  [acts=(list [id=@ta a=action]) all=(list loaded) multi=(set @t) people=(map @t @t) now=@da tz=@t]
  ^-  (list exec-plan)
  ::  person/me's timezone, else the one the generator was given
  =/  zone=@t  (owner-zone all multi now tz)
  %+  murn  acts
  |=  [id=@ta a=action]
  ^-  (unit exec-plan)
  ?.  =(%approved status.a)  ~
  ?:  =(%message kind.a)
    =/  via=@t  (lower (gs payload.a 'via'))
    =/  who=@t  (gs payload.a 'to')
    =/  text=@t  (gs payload.a 'text')
    ?:  =('telegram' via)
      =/  chat=@t  (attr-text all multi now who 'telegram')
      =?  chat  =('' chat)  (chat-of-people people who)
      =/  note=@t  ?.(=('' chat) '' (rap 3 who ' has no telegram attribute and is not in people' ~))
      :-  ~
      :*  id  kind.a  %telegram  chat
          (pairs:enjs:format ~[['chat_id' s+chat] ['text' s+text] ['who' s+who]])
          note
      ==
    ?:  |(=('mail' via) =('chat' via))
      ::  the ship attribute, else the ship on the body's record (which
      ::  is where the page and the chat reader keep it)
      =/  ship=@t
        =/  a=@t  (attr-text all multi now who 'ship')
        ?.  =('' a)  a
        =/  hit=(unit loaded)  (loaded-of all who)
        ?~  hit  ''
        ?~(ship.body.u.hit '' (scot %p u.ship.body.u.hit))
      =/  to=@t  ?:(|(=('' ship) =('~' (end [3 1] ship))) ship (cat 3 '~' ship))
      ::  a chat message with a channel is a post there, not a DM, and
      ::  needs no ship
      =/  nest=@t  ?:(=('chat' via) (trim-cord (gs payload.a 'channel')) '')
      =?  to  !=('' nest)  nest
      =/  note=@t  ?.(=('' to) '' (rap 3 who ' has no ship attribute' ~))
      :-  ~
      :*  id  kind.a  ?:(=('mail' via) %mail %chat)  to
          (pairs:enjs:format ~[['subject' s+title.a] ['text' s+text] ['channel' s+nest] ['who' s+who]])
          note
      ==
    ~
  ?:  =(%task kind.a)
    =/  ej=(unit json)  (event-json id a zone)
    ?~  ej  ~
    `[id kind.a %todo '' u.ej '']
  ?.  =(%calendar kind.a)  ~
  =/  raw-mode=@t  (lower (gs payload.a 'mode'))
  =/  mode=@t  ?:(=('' raw-mode) 'add' raw-mode)
  ?:  =('cancel' mode)
    =/  event=@t  (gs payload.a 'event')
    ?:  =('' event)
      `[id kind.a %calendar '' (pairs:enjs:format ~) 'cancel needs the event']
    =/  s=(unit @da)  (gt payload.a 'starts')
    =/  body=json
      ?~  s  (pairs:enjs:format ~)
      (pairs:enjs:format ~[['start_ms' (numb:enjs:format (ms-of u.s))]])
    `[id kind.a %uncalendar event body '']
  ?.  =('add' mode)
    `[id kind.a %calendar '' (pairs:enjs:format ~) 'mode must be add or cancel']
  =/  ej=(unit json)  (event-json id a zone)
  ?~  ej  ~
  `[id kind.a %calendar '' u.ej '']
::  +route-message: the owner's channel rule. A person with a ship is
::  reached on Urbit, so a message proposed for telegram or mail to
::  such a person is filed via chat, which Talon sends; telegram is for
::  a person with no ship. The note goes to the trail so the rewrite
::  is visible.
::
++  route-message
  |=  [a=action ship=@t]
  ^-  [a=action note=@t]
  ?.  =(%message kind.a)  [a '']
  ?:  =('' ship)  [a '']
  =/  via=@t  (lower (gs payload.a 'via'))
  ?.  |(=('telegram' via) =('mail' via))  [a '']
  :-  a(payload (set-key payload.a 'via' s+'chat'))
  (rap 3 'via rewritten to chat: ' (gs payload.a 'to') ' has a ship' ~)
::  +reroute-on-revise: the channel rule on a revision. A note that
::  names a new recipient and says nothing about the channel leaves
::  the channel as it was proposed, so the rule runs again for the new
::  person, the way it ran for the old one at filing. A note that sets
::  the channel is the owner's word and stands whoever the message is
::  to, so nothing reroutes when via changed.
::
++  reroute-on-revise
  |=  [old=action new=action ship=@t]
  ^-  [a=action note=@t]
  ?.  =(%message kind.new)  [new '']
  ?:  =((lower (gs payload.old 'to')) (lower (gs payload.new 'to')))  [new '']
  ?.  =((lower (gs payload.old 'via')) (lower (gs payload.new 'via')))  [new '']
  (route-message new ship)
::  +clean-text: the owner's first prose rule enforced on what leaves
::  the ship: an em dash becomes a comma, one space after it and none
::  before, whatever a model wrote. The rest of the rules are the
::  prompts' to keep.
::
++  skip-trailing-space
  |=  t=tape
  ^-  tape
  ?:  ?=([%' ' *] t)  $(t t.t)
  t
++  clean-text
  |=  t=@t
  ^-  @t
  =/  cs=tape  " ,"
  =/  s=tape  (trip t)
  =|  out=tape
  |-
  ?~  s  (crip (flop out))
  ::  the em dash is the three bytes e2 80 94; the accumulator is
  ::  reversed, so the comma and its space go on backwards
  ?.  ?=([%226 %128 %148 *] s)  $(s t.s, out [i.s out])
  =/  rest=tape  t.t.t.s
  =.  rest  ?:(?=([%' ' *] rest) t.rest rest)
  ::  a second dash right after the first adds nothing: the comma is
  ::  already there
  =/  trimmed=tape  (skip-trailing-space out)
  ?:  ?=([%',' *] trimmed)  $(s rest, out (weld cs t.trimmed))
  $(s rest, out (weld cs trimmed))
::  ==  the mirror: the calendar's todo list and the task actions kept
::  in step both ways. The fiber reads the store, +plan-mirror says
::  what each todo needs, and the fiber files it.
::
::  a todo as the mirror sees it: orrery is the action id its meta
::  carries, '' when the owner typed it by hand; meta is the whole meta
::  as read, so an edit can carry the keys the mirror does not know
::
+$  todo  [id=@t name=@t orrery=@t done=? due=(unit @da) note=@t meta=json]
::  one thing the mirror does: an op for the writer, or a poke body for
::  the calendar (its action key says which)
::
+$  mirror-op  $%([%writer json] [%calendar json])
::  +todos-of: the todos in the calendar's store as the ball serves it
::  as JSON: title, zone, calendars and events, each row with its id,
::  cat and meta, a todo also due_ms, done_ms and done. Rows of another
::  cat are not the mirror's.
::
++  todos-of
  |=  cal=json
  ^-  (list todo)
  %+  murn  (ga cal 'events')
  |=  e=json
  ^-  (unit todo)
  ?.  =('todo' (gs e 'cat'))  ~
  =/  meta=json  (gj e 'meta')
  :-  ~
  :*  (gs e 'id')
      (gs meta 'name')
      (gs meta 'orrery')
      ?=([%b %.y] (gj e 'done'))
      (bind (gn e 'due_ms') da-of-ms)
      (gs meta 'note')
      meta
  ==
::  +todo-meta: a todo's meta for edit-event, which replaces the event
::  whole through the calendar's parse-event (meta verbatim, only the
::  exceptions survive): the meta it had, with the name and note, the
::  action id and the orrery tag laid over it, so a color, a CalDAV
::  category or a tag the owner set survives the edit.
::
++  todo-meta
  |=  [t=todo act=@t]
  ^-  json
  =/  own=(map @t json)  ?:(?=([%o *] meta.t) p.meta.t *(map @t json))
  =/  tags=(list @t)  (strings (ga meta.t 'tags'))
  =?  tags  !(lien tags |=(x=@t =('orrery' x)))  (snoc tags 'orrery')
  =.  own  (~(put by own) 'name' s+name.t)
  =.  own  (~(put by own) 'orrery' s+act)
  =.  own  (~(put by own) 'tags' a+(turn tags |=(x=@t ^-(json s+x))))
  =.  own  ?:(=('' note.t) (~(del by own) 'note') (~(put by own) 'note' s+note.t))
  [%o own]
::  +edit-todo-op: the calendar poke that rewrites a todo with its
::  action id and a due
::
++  edit-todo-op
  |=  [t=todo act=@t due=(unit @da)]
  ^-  json
  %-  pairs:enjs:format
  %+  weld
    ^-  (list [@t json])
    :~  ['action' s+'edit-event']
        ['id' s+id.t]
        ['cat' s+'todo']
        ['meta' (todo-meta t act)]
    ==
  ^-  (list [@t json])
  ?~(due ~ ~[['due_ms' (numb:enjs:format (ms-of u.due))]])
::  +calendar-set-action: a status the calendar sets on an action
::
++  calendar-set-action
  |=  [id=@t status=@t why=@t]
  ^-  json
  (set-action-op `@ta`id status why 'calendar')
::  +adopt-ops: a todo the owner typed becomes a task on the ship. The
::  writer's act op files a proposal, so the approval is a second op
::  on the id the writer will assign (act-id of the stamped action, as
::  gen-pass computes it after filing); then the todo is rewritten with
::  that id, so the next pass reads it as the ship's own. A todo the
::  writer would refuse (a title over the cap) yields nothing.
::
++  adopt-ops
  |=  [t=todo now=@da]
  ^-  (list mirror-op)
  =/  raw=json
    %-  pairs:enjs:format
    %+  weld
      ^-  (list [@t json])
      ~[['kind' s+'task'] ['title' s+name.t] ['about' a+~]]
    %+  weld
      ^-  (list [@t json])
      ~[['payload' (pairs:enjs:format (weld `(list [@t json])`~[['todo' s+id.t]] `(list [@t json])`?:(=('' note.t) ~ ~[['notes' s+note.t]])))]]
    ^-  (list [@t json])
    ?~(due.t ~ ~[['due' s+(en-iso u.due.t)]])
  =/  stamped=json  (fill-act-as raw now 'calendar')
  =/  parsed=(each action @t)  (de-action stamped now 'calendar')
  ?:  ?=(%| -.parsed)  ~
  =/  act=@ta  (act-id p.parsed)
  :~  [%writer (pairs:enjs:format ~[['op' s+'act'] ['action' stamped]])]
      [%writer (calendar-set-action act 'approved' 'typed in the calendar')]
      [%calendar (edit-todo-op t act due.t)]
  ==
::  +plan-mirror: the todo list against the actions. A todo carrying an
::  action id follows its action: done on the ship ticks it, dismissed
::  or failed deletes it, a due that differs is moved to the action's
::  (the ship is the source of truth for what it made); ticked in the
::  calendar, it moves an approved or claimed action to done. A todo
::  with no action id and not done is the owner's own and is adopted.
::  A done todo nobody claims, and a todo whose action is not in the
::  list, are left alone.
::
++  plan-mirror
  |=  [todos=(list todo) acts=(list [id=@ta a=action]) now=@da]
  ^-  (list mirror-op)
  =/  by-id=(map @ta action)  (~(gas by *(map @ta action)) acts)
  =/  adopted=(set @t)
    (sy (murn acts |=([* a=action] =/(t (gs payload.a 'todo') ?:(=('' t) ~ `t)))))
  %-  zing
  %+  turn  todos
  |=  t=todo
  ^-  (list mirror-op)
  ?:  =('' orrery.t)
    ::  a todo adopted before whose mark never landed (a read-only
    ::  shared calendar drops the edit) is not adopted again
    ?:  |(done.t (~(has in adopted) id.t))  ~
    (adopt-ops t now)
  =/  hit=(unit action)  (~(get by by-id) `@ta`orrery.t)
  ?~  hit  ~
  =/  a=action  u.hit
  =/  live=?  |(=(%approved status.a) =(%claimed status.a))
  ?:  done.t
    ?.  live  ~
    [%writer (calendar-set-action orrery.t 'done' 'ticked in the calendar')]~
  ?:  =(%done status.a)
    :_  ~
    :-  %calendar
    (pairs:enjs:format ~[['action' s+'done-event'] ['id' s+id.t] ['done' (numb:enjs:format (ms-of now))]])
  ?:  |(=(%dismissed status.a) =(%failed status.a))
    [%calendar (pairs:enjs:format ~[['action' s+'del-event'] ['id' s+id.t]])]~
  ?.  live  ~
  ?:  =(due.t due.a)  ~
  ::  a todo the owner typed is theirs to reschedule: only a todo the
  ::  ship made follows its action's due
  ?:  =('calendar' by.a)  ~
  [%calendar (edit-todo-op t orrery.t due.a)]~
::  +version: what the desk's code/version.json says, for GET /version;
::  scripts/page-test.js holds the two together
::
++  version  59
::  ==  the calendar events reader (version 47): the calendar's timed,
::  all-day and dated events as situations and activities, the way the
::  phone client's calendar pipe wrote them (its OrreryCalendar), so
::  the pipe can be switched off. Pure: +events-of reads the store's
::  JSON, +occurrences reads the calendar's own order index (its
::  cache grub, every rule kind it knows inflated by its own code),
::  +plan-events answers the writer ops and what to remember.
::
::  +$  cal-event: one event of the store (calendar's +event-json): its
::  id (the uid a CalDAV client sees), its calendar, its cat (timed,
::  allday, date; a todo is the mirror's), the meta the owner reads,
::  and its rule's kind, the cadence word.
::
+$  cal-event
  $:  id=@t  cal=@t  cat=@t  name=@t  note=@t  location=@t  tags=(list @t)
      kind=@t
  ==
::  the calendar's cache grub as orrery clams it: the wall the index
::  was inflated through, and the order, each moment to the refs of
::  the spans that start then (calendar's +$ ref, +$ order, +$ cache)
::
+$  cal-ref    [id=@ta idx=@ud l=@da r=@da]
+$  cal-order  ((mop @da (set cal-ref)) lth)
+$  cal-cache  [thru=@da stops=(map @ta @da) order=cal-order]
++  on-cal-order  ((on @da (set cal-ref)) lth)
++  events-of
  |=  cal=json
  ^-  (list cal-event)
  (events-in cal |)
::  +events-in: the store's events, the ship's own placed ones kept
::  when own is set (the brief lists them; the reader must not read
::  back what the ship wrote)
::
++  events-in
  |=  [cal=json keep-own=?]
  ^-  (list cal-event)
  %+  murn  (ga cal 'events')
  |=  e=json
  ^-  (unit cal-event)
  ::  a todo is the mirror's, and orrery's own events are its actions
  =/  cat=@t  (gs e 'cat')
  ?.  ?=(?(%timed %allday %date) cat)  ~
  =/  meta=json  (gj e 'meta')
  =/  tags=(list @t)  (strings (ga meta 'tags'))
  =/  own=?
    ?|  !=('' (gs meta 'orrery'))
        =('orrery-' (end [3 7] (gs e 'id')))
        (lien tags |=(t=@t =('orrery' (lower t))))
    ==
  ?:  &(own !keep-own)  ~
  :-  ~
  :*  (gs e 'id')
      (gs e 'cal')
      cat
      (trim-cord (gs meta 'name'))
      (gs meta 'note')
      (trim-cord (gs meta 'location'))
      tags
      (cadence-of (gs e 'kind') cat (gj e 'args'))
  ==
::  +cadence-of: the word a rule's kind gives an activity's cadence:
::  the kind itself, a dated event's yearly, an imported RRULE's FREQ
::  (weekly for "FREQ=WEEKLY;BYDAY=TU"), rrule when it has none
::
++  cadence-of
  |=  [kind=@t cat=@t args=json]
  ^-  @t
  ?:  =('' kind)  ?:(=('date' cat) 'yearly' 'once')
  ?.  =('rrule' kind)  kind
  =/  parts=(list @t)  (turn (split-char ';' (trip (gs args 'rrule'))) crip)
  =/  freq=(list @t)  (skim parts |=(p=@t =('freq=' (end [3 5] (lower p)))))
  ?~  freq  'rrule'
  =/  f=@t  (lower (rsh [3 5] i.freq))
  ?:(=('' f) 'rrule' f)
::  +occurrences: an event's spans starting between from and to, from
::  the calendar's order, oldest first, one per index
::
++  occurrences
  |=  [id=@t order=cal-order from=@da to=@da]
  ^-  (list [idx=@ud l=@da r=@da])
  =/  lo=(unit @da)  [~ ?:(=(0 from) `@da`0 `@da`(dec from))]
  =/  hi=(unit @da)  [~ `@da`+(to)]
  =/  ents=(list [@da (set cal-ref)])  (tap:on-cal-order (lot:on-cal-order order lo hi))
  =|  seen=(set @ud)
  =|  out=(list [idx=@ud l=@da r=@da])
  |-
  ?~  ents  (flop out)
  =/  rs=(list cal-ref)
    (sort (skim ~(tap in +.i.ents) |=(r=cal-ref =(id id.r))) |=([a=cal-ref b=cal-ref] (lth idx.a idx.b)))
  |-
  ?~  rs  ^$(ents t.ents)
  ?:  (~(has in seen) idx.i.rs)  $(rs t.rs)
  $(rs t.rs, seen (~(put in seen) idx.i.rs), out [[idx.i.rs l.i.rs r.i.rs] out])
::  +people-named: the people a text names, by the words the ship knows
::  them by: a whole word, case aside
::
++  people-named
  |=  [text=@t known=(map @t bid)]
  ^-  (list bid)
  =/  words=(set @t)  (sy (tokens text))
  %-  dedupe
  %+  murn  ~(tap by known)
  |=([w=@t id=bid] ?:(&(!=('me' w) !=('i' w) (~(has in words) w)) `id ~))
::  +cast: everyone the event names: the title's certain names, made
::  as person bodies when the ship lacks them; its leading name only
::  when the ship knows it; and whoever the ship knows named in the
::  title or the note. person/me is never in ids; me says whether the
::  event names the owner.
::
++  cast
  |=  [ev=cal-event known=(map @t bid)]
  ^-  [ids=(list bid) made=(list json) me=?]
  =/  ni  (names-in name.ev)
  =/  sure=[ids=(list bid) made=(list json)]
    %+  roll  sure.ni
    |=  [n=@t acc=[ids=(list bid) made=(list json)]]
    =/  hit=(unit bid)  (~(get by known) (lower n))
    ?^  hit  acc(ids (snoc ids.acc u.hit))
    =/  pid=bid  (cat 3 'person/' (slug n))
    acc(ids (snoc ids.acc pid), made (snoc made.acc (pairs:enjs:format ~[['id' s+pid] ['name' s+n]])))
  =/  lead=(list bid)
    ?.  &(?=(~ sure.ni) ?=(^ lead.ni))  ~
    (drop (~(get by known) (lower u.lead.ni)))
  =/  named=(list bid)  (weld (people-named name.ev known) (people-named note.ev known))
  =/  every=(list bid)  (dedupe :(weld ids.sure lead named))
  :+  (skip every |=(b=bid =('person/me' b)))
    made.sure
  (lien every |=(b=bid =('person/me' b)))
::  +event-source: the source id every calendar row carries, the
::  phone client's <calendar>/<uid>, or the uid alone when the store's
::  JSON does not say which calendar (it does not, today)
::
++  event-source
  |=  ev=cal-event
  ^-  source
  ['calendar' ?:(=('' cal.ev) id.ev (rap 3 cal.ev '/' id.ev ~))]
++  event-row
  |=  [ev=cal-event id=bid attr=@t value=json at=@da until=(unit @da) conf=@ud]
  ^-  json
  (obs-row id attr value at until conf (event-source ev) 'calendar')
::  +same-event: the body the ship keeps for an event, or ~. The uid
::  is the event itself: a body with a calendar row from it is it (the
::  source id is the uid, or the client's <calendar>/<uid>). Failing
::  that, a series takes an activity by the same title, and a one-off
::  an open situation by the same title that starts within a day of
::  this occurrence; a closed one is a past occasion.
::
++  same-event
  |=  [ev=cal-event repeats=? start=@da all=(list loaded) multi=(set @t) now=@da]
  ^-  (unit loaded)
  =/  by-uid=(unit loaded)
    %-  find-first-loaded
    :-  all
    |=  l=loaded
    ?.  ?=(?(%activity %situation) kind.body.l)  |
    (lien rows.l |=(r=row (names-uid source.obs.r id.ev)))
  ?^  by-uid  by-uid
  =/  title=@t  (normalize-title name.ev)
  ?:  =('' title)  ~
  ?:  repeats
    %-  find-first-loaded
    :-  all
    |=(l=loaded &(=(%activity kind.body.l) =(title (normalize-title name.body.l))))
  %-  find-first-loaded
  :-  all
  |=  l=loaded
  ?.  &(=(%situation kind.body.l) =(title (normalize-title name.body.l)))  |
  =/  w=(map @t (list row))  (fold rows.l multi now)
  =/  st=@t  (winner-text w 'status')
  ?:  |(=('closed' st) =('cancelled' st))  |
  =/  s=(unit @da)  (de-iso =/(t (winner-text w 'starts') ?:(=('' t) (winner-text w 'started') t)))
  ?~  s  |
  ?:((gth u.s start) (lth (sub u.s start) ~d1) (lth (sub start u.s) ~d1))
::  +uid-of-source: the calendar uid a row's source names, '' when the
::  row is not the calendar's
::
++  uid-of-source
  |=  s=source
  ^-  @t
  ?.  =('calendar' kind.s)  ''
  =/  cut=(unit @ud)  (find "/" (trip id.s))
  ?~(cut id.s (rsh [3 +(u.cut)] id.s))
::  +names-uid: whether a calendar row's source is this event's: the
::  whole id (the store names no calendar today, so a uid with a slash
::  in it is stored whole) or the uid after <calendar>/
::
++  names-uid
  |=  [s=source uid=@t]
  ^-  ?
  &(=('calendar' kind.s) |(=(uid id.s) =(uid (uid-of-source s))))
++  find-first-loaded
  |=  [all=(list loaded) f=$-(loaded ?)]
  ^-  (unit loaded)
  ?~  all  ~
  ?:((f i.all) `i.all $(all t.all))
::  +prune-seen: the seen map without occurrences and nexts older than
::  sixty days (their keys end in the epoch ms), so it stops growing
::
++  prune-seen
  |=  [seen=(map @t @t) now=@da]
  ^-  (map @t @t)
  =/  floor=@ud  (ms-of (sub now ~d400))
  %-  ~(gas by *(map @t @t))
  %+  skip  ~(tap by seen)
  |=  [k=@t v=@t]
  ?.  |(=('occ/' (end [3 4] k)) =('next/' (end [3 5] k)))  |
  =/  segs=(list @t)  (turn (split-char '/' (trip k)) crip)
  ?~  segs  |
  =/  ms=(unit @ud)  (rush (rear segs) dem)
  ?~(ms | (lth u.ms floor))
::  +plan-events: what the store's events say, as the writer's ops and
::  what to remember. seen maps a key to a mark: occ/<cal>/<uid>/<start
::  ms> is an occurrence written, 's' while only its schedule was said
::  and 'f' once the past tense was; act/<cal>/<uid>/<digest> says an
::  activity's content stands as written; next/<cal>/<uid>/<ms> that
::  its next was said; gone/<uid> that a vanished one-off was
::  cancelled. A one-off (kind once, one occurrence) is a situation:
::  starts and ends while ahead, dated now; started and ended once
::  behind, dated at the event. A series is an activity: cadence,
::  schedule, location, participants and (on the ship's own calendar)
::  organizer, dated at the last occurrence behind; every occurrence
::  behind as last; the next as next, dated at the end of the one
::  before it, standing until its own end. A situation the calendar no
::  longer holds whose start is ahead is cancelled once. Bodies the
::  ship lacks are made, with no alias: the uid is on every row's
::  source, and as an alias it would answer a resolve of the ship it
::  ends with.
::
+$  event-plan
  $:  ops=(list json)  seen=(map @t @t)
      made=@ud  rows=@ud  cancelled=@ud
  ==
++  plan-events
  |=  [events=(list cal-event) order=cal-order all=(list loaded) multi=(set @t) now=@da seen=(map @t @t) tz=@t]
  ^-  event-plan
  =/  known=(map @t bid)  (known-people all)
  =/  from=@da  (sub now ~d30)
  =/  to=@da  (add now ~d90)
  =|  bodies=(list json)
  =|  rows=(list json)
  =|  made=@ud
  =|  drops=(list json)
  =/  ids=(set @t)  (sy (turn events |=(ev=cal-event id.ev)))
  =/  todo=(list cal-event)  events
  |-
  ?^  todo
    =/  ev=cal-event  i.todo
    ?:  =('' name.ev)  $(todo t.todo)
    =/  occs=(list [idx=@ud l=@da r=@da])  (occurrences id.ev order from to)
    =/  repeats=?  |(!=('once' kind.ev) ?=([* ^] occs))
    =/  start=@da  ?~(occs now l.i.occs)
    =/  hit=(unit loaded)  (same-event ev repeats start all multi now)
    ::  a body whose cadence stands at another word is corrected
    ::  whatever the seen map says: the ship's state is what counts
    =/  stale=?
      ?~  hit  |
      =/  cur=@t  (winner-text (fold rows.u.hit multi now) 'cadence')
      &(!=('' cur) !=(cur kind.ev))
    ::  nothing in the window says nothing (but a series held at the
    ::  wrong cadence is still corrected), and a cancel below sees
    ::  only a one-off the calendar has dropped altogether
    ?:  &(?=(~ occs) !&(repeats stale))  $(todo t.todo)
    =/  people  (cast ev known)
    ::  the owner's calendar is the owner's to organize, but they are
    ::  at an event only when it names them or names nobody else
    =/  with-me=?  |(me.people ?=(~ ids.people))
    ::  before version 60 the owner stood in every event; a row that
    ::  says so of an event that names others is retracted
    =/  unsaid=(list json)
      ?:  |(with-me ?=(~ hit))  ~
      %+  murn  rows.u.hit
      |=  r=row
      ^-  (unit json)
      ?.  ?&  =('participants' attr.obs.r)  !retracted.obs.r
              =('calendar' kind.source.obs.r)  ?=([%o *] value.obs.r)
              =('person/me' (ref-or-text value.obs.r))
          ==
        ~
      `(retract-op id.r 'calendar: the event does not name the owner' 'calendar')
    =.  drops  (weld drops unsaid)
    =.  bodies  (weld bodies made.people)
    ::  a person made here is known to the next event of the pass
    =.  known
      %+  roll  made.people
      |=([b=json acc=_known] (~(put by acc) (lower (gs b 'name')) (gs b 'id')))
    ?.  repeats
      ::  a one-off: one situation, one occurrence
      =/  occ=[idx=@ud l=@da r=@da]  ?~(occs [0 now now] i.occs)
      =/  id=bid
        ?^  hit  id.u.hit
        (rap 3 'situation/' (end [3 10] (local-iso (en-iso l.occ) tz)) '-' (slug name.ev) ~)
      =/  key=@t  (rap 3 'occ/' cal.ev '/' id.ev '/' (crip (a-co:co (ms-of l.occ))) ~)
      =/  mark=@t  (fall (~(get by seen) key) '')
      =/  behind=?  (lte r.occ now)
      ::  back: cancelled when it went (a CalDAV move deletes then puts
      ::  again), here again now, so it is reopened
      =/  gkey=@t  (cat 3 'gone/' id.ev)
      =/  back=?  &(?=(^ hit) (~(has by seen) gkey))
      ?:  &(!back |(=('f' mark) &(=('s' mark) !behind)))  $(todo t.todo)
      =?  bodies  ?=(~ hit)
        (snoc bodies (pairs:enjs:format ~[['id' s+id] ['name' s+name.ev]]))
      =?  made  ?=(~ hit)  +(made)
      =/  learned=@da  (min l.occ now)
      =/  fresh=(list json)
        %-  zing
        :~  ?:  (gth l.occ now)
              ~[(event-row ev id 'starts' s+(en-iso l.occ) now ~ 100)]
            ~[(event-row ev id 'started' s+(en-iso l.occ) l.occ ~ 100)]
            ?:  (gth r.occ now)
              ~[(event-row ev id 'ends' s+(en-iso r.occ) now ~ 100)]
            ~[(event-row ev id 'ended' s+(en-iso r.occ) r.occ ~ 100)]
            ?:  =('s' mark)  ~
            %-  zing
            :~  ?.  with-me  ~
                ~[(event-row ev id 'participants' (pairs:enjs:format ~[['ref' s+'person/me']]) learned ~ 100)]
                (turn ids.people |=(p=bid (event-row ev id 'participants' (pairs:enjs:format ~[['ref' s+p]]) learned ~ 85)))
                ?:(=('' location.ev) ~ ~[(event-row ev id 'location' s+location.ev learned ~ 100)])
            ==
        ==
      %=  $
        todo  t.todo
        rows  :(weld rows fresh `(list json)`?.(back ~ ~[(event-row ev id 'status' s+'open' now ~ 100)]))
        seen  (~(put by (~(del by seen) gkey)) key ?:(behind 'f' 's'))
      ==
    ::  a series: one activity, its content once, each occurrence
    ::  behind as last, the next as next
    =/  id=bid  ?^(hit id.u.hit (cat 3 'activity/' (slug name.ev)))
    =/  all-occs=(list [idx=@ud l=@da r=@da])  occs
    =/  behind=(list [idx=@ud l=@da r=@da])  (skim all-occs |=(o=[idx=@ud l=@da r=@da] (lte l.o now)))
    =/  ahead=(list [idx=@ud l=@da r=@da])  (skip all-occs |=(o=[idx=@ud l=@da r=@da] (lte l.o now)))
    ::  the content is dated at the last occurrence behind, else now:
    ::  a row dated at an anchor still ahead would not be live yet.
    ::  Content said again (its digest moved) is dated now, or the
    ::  earlier saying, dated later, would keep the fold
    =/  said-before=?
      =/  pre=@t  (rap 3 'act/' cal.ev '/' id.ev '/' ~)
      (lien ~(tap by seen) |=([k=@t *] =(pre (end [3 (met 3 pre)] k))))
    =/  as-of=@da  ?:(|(said-before stale) now ?~(behind now l:(rear behind)))
    =/  schedule=@t
      =/  tag=@t  ?~(tags.ev '' i.tags.ev)
      ?:(=('' tag) kind.ev (rap 3 kind.ev ', ' tag ~))
    =/  digest=@t
      (scot %ux (mug [kind.ev schedule location.ev ids.people cal.ev]))
    =/  ckey=@t  (rap 3 'act/' cal.ev '/' id.ev '/' digest ~)
    =?  bodies  ?=(~ hit)
      (snoc bodies (pairs:enjs:format ~[['id' s+id] ['name' s+name.ev]]))
    =?  made  ?=(~ hit)  +(made)
    =/  content=(list json)
      ?:  &((~(has by seen) ckey) !stale)  ~
      %-  zing
      :~  ~[(event-row ev id 'cadence' s+kind.ev as-of ~ 100)]
          ~[(event-row ev id 'schedule' s+schedule as-of ~ 100)]
          ?.  with-me  ~
          ~[(event-row ev id 'participants' (pairs:enjs:format ~[['ref' s+'person/me']]) as-of ~ 100)]
          (turn ids.people |=(p=bid (event-row ev id 'participants' (pairs:enjs:format ~[['ref' s+p]]) as-of ~ 85)))
          ~[(event-row ev id 'organizer' (pairs:enjs:format ~[['ref' s+'person/me']]) as-of ~ 100)]
          ?:(=('' location.ev) ~ ~[(event-row ev id 'location' s+location.ev as-of ~ 100)])
      ==
    =/  lasts=[rows=(list json) seen=(map @t @t)]
      =/  bs=_behind  behind
      =|  out=(list json)
      |-  ^-  [rows=(list json) seen=(map @t @t)]
      ?~  bs  [(flop out) seen]
      =/  key=@t  (rap 3 'occ/' cal.ev '/' id.ev '/' (crip (a-co:co (ms-of l.i.bs))) ~)
      ?:  (~(has by seen) key)  $(bs t.bs)
      %=  $
        bs    t.bs
        out   [(event-row ev id 'last' s+(en-iso l.i.bs) l.i.bs ~ 100) out]
        seen  (~(put by seen) key 'f')
      ==
    =/  nexts=[rows=(list json) seen=(map @t @t)]
      ?~  ahead  [~ seen.lasts]
      =/  n=[idx=@ud l=@da r=@da]  i.ahead
      =/  key=@t  (rap 3 'next/' cal.ev '/' id.ev '/' (crip (a-co:co (ms-of l.n))) ~)
      ?:  (~(has by seen.lasts) key)  [~ seen.lasts]
      =/  anchor=@da  ?~(behind (sub now (mod now ~d1)) r:(rear behind))
      :-  ~[(event-row ev id 'next' s+(en-iso l.n) anchor `r.n 100)]
      (~(put by seen.lasts) key 'x')
    %=  $
      todo  t.todo
      rows  :(weld rows content rows.lasts rows.nexts)
      seen  ?:(?=(~ content) seen.nexts (~(put by seen.nexts) ckey 'x'))
    ==
  ::  a one-off the calendar no longer holds, still ahead: cancelled once
  =/  gone=[rows=(list json) seen=(map @t @t) n=@ud]
    =/  ls=_all  all
    =|  out=(list json)
    =|  n=@ud
    |-  ^-  [rows=(list json) seen=(map @t @t) n=@ud]
    ?~  ls  [(flop out) seen n]
    =/  l=loaded  i.ls
    ?.  =(%situation kind.body.l)  $(ls t.ls)
    =/  srcs=(list source)
      %+  murn  rows.l
      |=(r=row ?:(=('calendar' kind.source.obs.r) `source.obs.r ~))
    ?~  srcs  $(ls t.ls)
    ::  every event the situation came from must be gone: two events of
    ::  one title on one day share it
    ?:  (lien `(list source)`srcs |=(s=source |((~(has in ids) id.s) (~(has in ids) (uid-of-source s)))))  $(ls t.ls)
    =/  uid=@t  (uid-of-source i.srcs)
    =/  gkey=@t  (cat 3 'gone/' uid)
    ?:  (~(has by seen) gkey)  $(ls t.ls)
    =/  w=(map @t (list row))  (fold rows.l multi now)
    =/  st=@t  (winner-text w 'status')
    ?:  |(=('closed' st) =('cancelled' st))  $(ls t.ls)
    =/  s=(unit @da)  (de-iso (winner-text w 'starts'))
    ?.  &(?=(^ s) (gth u.s now))  $(ls t.ls)
    %=  $
      ls    t.ls
      out   [(obs-row id.l 'status' s+'cancelled' now ~ 100 i.srcs 'calendar') out]
      seen  (~(put by seen) gkey 'x')
      n     +(n)
    ==
  =/  every=(list json)  (weld rows rows.gone)
  =/  undo=(list json)  (dedupe-json drops)
  :*  (weld (observe-ops bodies every) undo)
      seen.gone
      made
      (add (lent every) (lent undo))
      n.gone
  ==
::  ==  the daily brief (version 52): one mail each morning from the
::  owner to the owner, the way the phone client's brief was, and the
::  owner's reply read back once. Pure: +brief-render writes the mail,
::  +brief-user the analyst's prompt for its suggestions, +own-words
::  strips a reply to what the owner typed, +moves-of reads the
::  model's moves on the tagged actions, +brief-steps the statuses a
::  move walks. The fiber in the nexus sends, reads and files.
::
++  brief-prefix  'Daily brief '
++  brief-subject  |=(day=@t ^-(@t (cat 3 brief-prefix day)))
::  +brief-day-of: the day a brief's subject names, through any "Re:",
::  '' when it is not a brief
::
++  brief-day-of
  |=  subject=@t
  ^-  @t
  =/  t=tape  (trip subject)
  =/  at=(unit @ud)  (find (trip brief-prefix) t)
  ?~  at  ''
  =/  day=@t  (crip (scag 10 (slag (add u.at (lent (trip brief-prefix))) t)))
  ?:  ?=(^ (de-iso (cat 3 day 'T00:00:00Z')))  day  ''
::  +utc-of: a wall-clock moment of a zone as the UTC instant it names,
::  the inverse of +wall-of; +local-day: the owner's date of a moment;
::  +day-bounds: a local day as UTC instants, midnight to midnight
::
++  utc-of
  |=  [wall=@da tz=@t]
  ^-  @da
  =/  z=(unit zone)  (~(get by zones) tz)
  ?~  z  wall
  =/  shift=@dr  (mul ?:((in-dst u.z wall) dst.u.z std.u.z) ~m1)
  ?:(west.u.z (add wall shift) (sub wall shift))
++  local-day  |=([now=@da tz=@t] ^-(@t (end [3 10] (local-iso (en-iso now) tz))))
++  day-bounds
  |=  [day=@t tz=@t]
  ^-  [from=@da to=@da]
  =/  wall=@da  (fall (de-iso (cat 3 day 'T00:00:00Z')) ~2000.1.1)
  [(utc-of wall tz) (utc-of (add wall ~d1) tz)]
++  hhmm  |=([at=@da tz=@t] ^-(@t (cut 3 [11 5] (local-iso (en-iso at) tz))))
::  +seven-of: 07:00 on the owner's clock on a day, as an instant;
::  +day-after: the next day's date. Midnight plus seven hours is not
::  seven on a day the clocks change.
::
++  seven-of
  |=  [day=@t tz=@t]
  ^-  @da
  =/  wall=@da  (fall (de-iso (cat 3 day 'T00:00:00Z')) ~2000.1.1)
  (utc-of (add wall ~h7) tz)
++  day-after
  |=  day=@t
  ^-  @t
  =/  wall=@da  (fall (de-iso (cat 3 day 'T00:00:00Z')) ~2000.1.1)
  (end [3 10] (en-iso (add wall ~d1)))
++  weekday-names  `(list @t)`~['Sunday' 'Monday' 'Tuesday' 'Wednesday' 'Thursday' 'Friday' 'Saturday']
++  month-names
  ^-  (list @t)
  ~['January' 'February' 'March' 'April' 'May' 'June' 'July' 'August' 'September' 'October' 'November' 'December']
::  +brief-day-line: "Today, Wednesday 23 September"; +short-when: an
::  instant as "Thu 24 Sep 22:00" on the owner's clock
::
++  brief-day-line
  |=  day=@t
  ^-  @t
  =/  d=(unit @da)  (de-iso (cat 3 day 'T00:00:00Z'))
  ?~  d  (cat 3 'Today, ' day)
  =/  [[* y=@ud] mo=@ud [dd=@ud *]]  (yore u.d)
  (rap 3 'Today, ' (snag (dow y mo dd) weekday-names) ' ' (crip (a-co:co dd)) ' ' (snag (dec mo) month-names) ~)
++  short-when
  |=  [at=@da tz=@t]
  ^-  @t
  =/  local=@t  (local-iso (en-iso at) tz)
  =/  d=(unit @da)  (de-iso (cat 3 (end [3 19] local) 'Z'))
  ?~  d  (en-iso at)
  =/  [[* y=@ud] mo=@ud [dd=@ud *]]  (yore u.d)
  =/  wd=@t  (end [3 3] (snag (dow y mo dd) weekday-names))
  =/  mn=@t  (end [3 3] (snag (dec mo) month-names))
  (rap 3 wd ' ' (crip (a-co:co dd)) ' ' mn ' ' (cut 3 [11 5] local) ~)
::  +brief-today: the day's lines: the calendar's rows (all-day first,
::  then by start), what orrery expects that the calendar does not
::  show (a situation starting today, an activity's next today, by a
::  title the calendar lacks), then the todos due by tonight and the
::  first ten undated ones
::
++  brief-today
  |=  $:  events=(list cal-event)  order=cal-order  todos=(list todo)
          all=(list loaded)  multi=(set @t)  from=@da  to=@da  tz=@t
      ==
  ^-  (list @t)
  ::  an all-day or dated span, and a todo due on a date, are UTC days
  ::  in the calendar; the owner's day as such a day is d0 to d1
  =/  d0=@da  =/(w (wall-of from tz) (sub w (mod w ~d1)))
  =/  d1=@da  (add d0 ~d1)
  =/  rows=(list [all=? at=@da text=@t])
    %-  zing
    %+  turn  events
    |=  ev=cal-event
    ^-  (list [all=? at=@da text=@t])
    =/  text=@t  ?:(=('' location.ev) name.ev (rap 3 name.ev ', ' location.ev ~))
    =/  timed=?  =('timed' cat.ev)
    ::  a month back, so a span that began before the day is found
    %+  murn  (occurrences id.ev order (sub from ~d31) to)
    |=  [idx=@ud l=@da r=@da]
    ^-  (unit [all=? at=@da text=@t])
    ?:  timed
      ?:  |((lte r from) (gte l to))  ~
      `[&((lte l from) (gte r to)) l text]
    ?:  |((lte r d0) (gte l d1))  ~
    `[& l text]
  =/  titled=(set @t)  (sy (turn events |=(ev=cal-event (normalize-title name.ev))))
  =/  expected=(list [all=? at=@da text=@t])
    %+  murn  all
    |=  l=loaded
    ^-  (unit [all=? at=@da text=@t])
    ?:  (~(has in titled) (normalize-title name.body.l))  ~
    =/  w=(map @t (list row))  (fold rows.l multi to)
    =/  at=(unit @da)
      ?:  =(%situation kind.body.l)
        =/  st=@t  (winner-text w 'status')
        ?:  |(=('closed' st) =('cancelled' st))  ~
        (de-iso-any (winner-text w 'starts'))
      ?.  =(%activity kind.body.l)  ~
      =/  next=(unit @da)  (de-iso-any (winner-text w 'next'))
      ?~  next  ~
      =/  skipped=(list @t)
        (turn (fall (~(get by w) 'skipped') ~) |=(r=row (ref-or-text value.obs.r)))
      ?:((lien skipped |=(t=@t =((de-iso-any t) next))) ~ next)
    ?~  at  ~
    ?.  &((gte u.at from) (lth u.at to))  ~
    `[| u.at name.body.l]
  =/  slots=(list [all=? at=@da text=@t])
    %+  sort  (weld rows expected)
    |=  [a=[all=? at=@da text=@t] b=[all=? at=@da text=@t]]
    ?:  &(all.a !all.b)  &
    ?:  &(!all.a all.b)  |
    (lth at.a at.b)
  =/  slot-lines=(list @t)
    (turn slots |=([all=? at=@da text=@t] (rap 3 ?:(all 'All day' (hhmm at tz)) '  ' text ~)))
  =/  open=(list todo)  (skim todos |=(t=todo &(!done.t !=('' (trim-cord name.t)))))
  ::  a due at midnight UTC is a date: due today is not overdue today
  =/  on-date  |=(d=@da =(0 (mod d ~d1)))
  =/  dated=(list todo)
    %+  sort
      %+  skim  open
      |=(t=todo ?~(due.t | ?:((on-date u.due.t) (lth u.due.t d1) (lth u.due.t to))))
    |=([a=todo b=todo] (lth (fall due.a *@da) (fall due.b *@da)))
  =/  undated=(list todo)  (skim open |=(t=todo ?=(~ due.t)))
  =/  late
    |=  t=todo
    ^-  ?
    ?~  due.t  |
    ?:((on-date u.due.t) (lth u.due.t d0) (lth u.due.t from))
  =/  todo-lines=(list @t)
    %+  weld
      %+  turn  dated
      |=(t=todo (rap 3 'To do  ' name.t ?:((late t) ' (overdue)' '') ~))
    %+  weld  (turn (scag 10 undated) |=(t=todo (cat 3 'To do  ' name.t)))
    ?:  (lte (lent undated) 10)  ~
    ~[(rap 3 'and ' (crip (a-co:co (sub (lent undated) 10))) ' more to do' ~)]
  (weld slot-lines todo-lines)
::  +brief-waiting: every proposed action under a tag, A1 on: its
::  title, then its kind, whom it is about and its due, then why
::
++  brief-waiting
  |=  [acts=(list [id=@ta a=action]) all=(list loaded) tz=@t]
  ^-  [lines=(list @t) tags=(list [tag=@t id=@ta])]
  =/  names=(map @t @t)  (~(gas by *(map @t @t)) (turn all |=(l=loaded [id.l name.body.l])))
  =/  proposed=(list [id=@ta a=action])  (skim acts |=([* a=action] =(%proposed status.a)))
  =/  n=@ud  1
  =|  lines=(list @t)
  =|  tags=(list [tag=@t id=@ta])
  |-
  ?~  proposed  [(flop lines) (flop tags)]
  =/  tag=@t  (cat 3 'A' (crip (a-co:co n)))
  =/  a=action  a.i.proposed
  =/  about=@t
    (join-cords ', ' (turn ~(tap in about.a) |=(b=bid (fall (~(get by names) b) b))))
  =/  parts=(list @t)
    %-  zing
    :~  ~[kind.a]
        ?:(=('' about) ~ ~[(cat 3 'about ' about)])
        ?~(due.a ~ ~[(cat 3 'due ' (short-when u.due.a tz))])
    ==
  =/  why=@t  (trim-cord (gs payload.a 'why'))
  %=  $
    proposed  t.proposed
    n  +(n)
    tags  [[tag id.i.proposed] tags]
    lines
      %+  weld
        ?:(=('' why) ~ ~[(cat 3 '     Why: ' why)])
      [(rap 3 '     ' (join-cords ', ' parts) ~) (rap 3 '[' tag '] ' title.a ~) lines]
  ==
::  +brief-render: the mail's text
::
++  brief-render
  |=  [day=@t today=(list @t) waiting=(list @t) suggestions=@t]
  ^-  @t
  %-  join-lines
  %-  zing
  :~  ~[(brief-day-line day) '']
      ?~(today ~['Nothing on the calendar.'] today)
      ~['' 'Waiting on you']
      ?~(waiting ~['Nothing.'] waiting)
      ?~(waiting ~ ~['' 'Reply with "approve A1", "dismiss A2", "A3 done" or "A1 due friday".'])
      ~['' 'Suggestions' (trim-cord suggestions) '' 'Anything else you write back is recorded as a fact, in your words.']
  ==
::  +brief-prompt: orrery-utils/common/brief-prompt.md, word for word;
::  scripts/prompt-drift.py holds it there. Edit the file, not this.
::
++  brief-prompt
  ^-  @t
  '''
  You are the analyst for orrery, a model of one person's world kept on their own ship. Each morning you write the owner a few lines to read on their phone before the day starts.

  You are given the owner's standing preferences when they have written any, the state (every body with its current attributes, with situations that start more than two days out left out), today's schedule and todos, what is ahead in the coming week as titles and starts only, the actions waiting for the owner's answer, the recent decisions with the owner's reasons for dismissals, what yesterday's brief said, and the time now. The preferences and the reasons are the owner's taste: say nothing they rule out.

  The brief is about today. Tomorrow and the day after earn a line only when something must happen today to be ready for them: a first occurrence the state says is new, travel, something to bring or book. Anything later than that gets a line only when today is the last day to act on it. Nothing from the week ahead is worth a line for being on the calendar.

  Point out what the owner would want to know and might not see: two things today that need one person in two places at once, a fact that looks stale or wrong, something open with nothing being done about it, a decision waiting on them that matters today.

  Do not list the schedule or the waiting actions again; the mail already does. Do not propose actions; another pass does that. Do not repeat a line yesterday's brief already said unless what it said has changed.

  Respect what the facts say about time: an occurrence in the past is over, and a situation that is upcoming has not happened.

  Do not invent facts, people, places or events. Do not moralise.

  Plain text, no markdown. One to three short lines, one thing each; up to six only on a day that earns them. Fewer lines beat filler. When there is nothing worth saying, answer exactly: Nothing to add.
  '''
::  +brief-user: what the analyst reads before writing the brief: the
::  owner's preferences, the state (situations closed, over or more
::  than two days out left out), the decisions with their reasons,
::  today's lines, the waiting lines, the week
::  ahead as titles and starts, yesterday's brief, the clock
::
++  brief-user
  |=  $:  all=(list loaded)  schema=json  decided=(list [id=@ta a=action])
          today=(list @t)  waiting=(list @t)  said=@t  now=@da  tz=@t
      ==
  ^-  @t
  =/  multi=(set @t)  (multi-of schema)
  =/  near=@da  (add now ~d2)
  =/  week=@da  (add now ~d7)
  =/  shown=(list loaded)  (scag prompt-bodies all)
  =/  starts-of
    |=  l=loaded
    ^-  (unit @da)
    =/  w=(map @t (list row))  (fold rows.l multi now)
    ?:  =(%situation kind.body.l)
      =/  ph=@t  (phase w now)
      ?:  |(=('closed' ph) =('cancelled' ph) =('over' ph))  ~
      (de-iso-any =/(s (winner-text w 'started') ?:(=('' s) (winner-text w 'starts') s)))
    ?.  =(%activity kind.body.l)  ~
    (de-iso-any (winner-text w 'next'))
  =/  hidden=(set @t)
    %-  sy
    %+  murn  shown
    |=  l=loaded
    ^-  (unit @t)
    ?.  =(%situation kind.body.l)  ~
    =/  w=(map @t (list row))  (fold rows.l multi now)
    =/  ph=@t  (phase w now)
    ?:  |(=('closed' ph) =('cancelled' ph) =('over' ph))  `id.l
    =/  s=(unit @da)  (starts-of l)
    ?:(&(?=(^ s) (gth u.s near)) `id.l ~)
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
  =/  ahead=(list @t)
    %+  turn
      %+  sort
        %+  murn  all
        |=  l=loaded
        ^-  (unit [at=@da name=@t])
        ?.  ?=(?(%situation %activity) kind.body.l)  ~
        =/  s=(unit @da)  (starts-of l)
        ?~  s  ~
        ?.  &((gth u.s near) (lte u.s week))  ~
        `[u.s name.body.l]
      |=([a=[at=@da *] b=[at=@da *]] (lth at.a at.b))
    |=([at=@da name=@t] (rap 3 '  ' name ' | ' (en-iso at) ~))
  %+  join-cords  nl
  %-  zing
  :~  ~['The owner is person/me.']
      (owner-lines schema |)
      (section ~[%thing %place %org %note %person %activity %situation])
      (decision-lines 'Recent decisions:' decided)
      ~['Today\'s schedule and todos:']
      ?~(today ~['  nothing'] (turn today |=(t=@t (cat 3 '  ' t))))
      ~['Waiting on the owner:']
      ?~(waiting ~['  nothing'] (turn waiting |=(t=@t (cat 3 '  ' t))))
      ?:(=(~ ahead) `(list @t)`~ ['Ahead this week:' (scag 10 `(list @t)`ahead)])
      ?:(=('' (trim-cord said)) `(list @t)`~ ['Yesterday\'s brief said:' (turn (split-lines said) |=(t=@t (cat 3 '  ' t)))])
      ~[(rap 3 'Now: ' (en-iso now) ', timezone ' ?:(=('' tz) 'unknown' tz) '. Write the brief.' ~)]
  ==
++  split-lines  |=(t=@t ^-((list @t) (turn (split-char 10 (trip t)) crip)))
::  +join-lines: lines joined with newlines, blank ones kept (which
::  +join-cords drops)
::
++  join-lines  |=(ls=(list @t) ^-(@t (rap 3 (join nl ls))))
::  +own-words: what the owner typed in a reply: the quoted brief
::  ("On ... wrote:", "-----Original Message", "> " lines) and any
::  line the brief itself said are dropped
::
++  own-words
  |=  [reply=@t brief=@t]
  ^-  @t
  =/  said=(set @t)  (sy (skip (turn (split-lines brief) trim-cord) |=(t=@t =('' t))))
  =|  out=(list @t)
  =/  ls=(list @t)  (split-lines reply)
  |-
  ?~  ls  (trim-cord (join-cords nl (flop out)))
  =/  t=@t  (trim-cord i.ls)
  =/  n=@ud  (met 3 t)
  ?:  ?|  &((gte n 10) =('On ' (end [3 3] t)) =('wrote:' (rsh [3 (sub n 6)] t)))
          =('-----Original Message' (end [3 21] t))
      ==
    $(ls ~)
  ?:  |(=('>' (end [3 1] t)) (~(has in said) t))  $(ls t.ls)
  $(ls t.ls, out [i.ls out])
::  +reply-rules: what a reply to the brief adds to the analyst's
::  prompt (Talon's REPLY_RULES, word for word)
::
++  reply-rules
  ^-  @t
  '''
  This message is the owner's reply to their daily brief. It is the owner speaking about their own world, so a plain statement in it is conf 100.
  The brief listed actions waiting for the owner's answer, each under a tag such as A1; they are given below with what each one is. A sentence about a tagged action is a move on it, not a fact: answer it under "moves", one per action, with only what the owner changed: {"tag": "A1", "status": "dismissed", "due": "...", "about": ["kind/slug"], "reason": "..."}. The status is "approved" (approve, yes, go ahead), "dismissed" (dismiss, no, skip) or "done" (done, did it). A new due is ISO 8601 UTC, read in the owner's timezone from the time now. A new subject names existing bodies by id. When the owner says why ("dismiss A3, it's just the event"), put their own words under "reason"; when they give no reason, give none, and never make one up. Write no fact from a sentence that only moves an action.
  Everything else in the reply is facts, by the rules above. Something the owner asks to have done is an action.
  Answer with one JSON object and nothing else:
  {"moves": [...], "bodies": [...], "observations": [...], "actions": [...]}
  '''
::  +tag-lines: the brief's actions by tag, for the reply's prompt
::
++  tag-lines
  |=  [tags=(list [tag=@t id=@ta]) acts=(list [id=@ta a=action])]
  ^-  (list @t)
  :-  'Actions in the brief, by tag (tag | kind | title | about | due | status):'
  %+  murn  tags
  |=  [tag=@t id=@ta]
  ^-  (unit @t)
  =/  a=(unit action)  (act-by acts id)
  ?~  a  ~
  =/  about=@t  (join-cords ', ' ~(tap in about.u.a))
  =/  due=@t  ?~(due.u.a '' (en-iso u.due.u.a))
  `(rap 3 '  ' tag ' | ' kind.u.a ' | ' title.u.a ' | ' about ' | ' due ' | ' status.u.a ~)
++  act-by
  |=  [acts=(list [id=@ta a=action]) id=@ta]
  ^-  (unit action)
  ?~  acts  ~
  ?:(=(id id.i.acts) `a.i.acts $(acts t.acts))
::  a move the reply makes on a tagged action
::
+$  move  [tag=@t id=@ta status=@t due=(unit @da) about=(list @t) reason=@t]
::  +moves-of: the model's moves checked: a known tag, a status of
::  approved, dismissed or done, a due that parses, an about of known
::  bodies; one with none of the three is dropped; the reason is cut
::  to 500 bytes; two moves on one tag are one
::
++  moves-of
  |=  [answer=json tags=(list [tag=@t id=@ta]) known=(set @t)]
  ^-  (list move)
  =/  by-tag=(map @t @ta)  (~(gas by *(map @t @ta)) tags)
  =/  raw=(list move)
    %+  murn  (ga answer 'moves')
    |=  j=json
    ^-  (unit move)
    =/  tag=@t
      =/  t=@t  (crip (cuss (trip (trim-cord (gs j 'tag')))))
      =/  n=@ud  (met 3 t)
      ?:  &((gte n 2) =('[' (end [3 1] t)) =(']' (rsh [3 (dec n)] t)))  (cut 3 [1 (sub n 2)] t)
      t
    =/  id=(unit @ta)  (~(get by by-tag) tag)
    ?~  id  ~
    =/  status=@t  =/(st (lower (gs j 'status')) ?:(?=(?(%approved %dismissed %done) st) st ''))
    =/  due=(unit @da)  (de-iso-any (gs j 'due'))
    =/  about=(list @t)  (strings (ga j 'about'))
    =?  about  !(levy about |=(b=@t (~(has in known) b)))  ~
    ?:  &(=('' status) ?=(~ due) ?=(~ about))  ~
    `[tag u.id status due about (end [3 500] (gs j 'reason'))]
  %+  roll  raw
  |=  [m=move acc=(list move)]
  ?:  (lien acc |=(x=move =(tag.x tag.m)))
    %+  turn  acc
    |=  x=move
    ?.  =(tag.x tag.m)  x
    %=  x
      status  ?:(=('' status.m) status.x status.m)
      due     ?~(due.m due.x due.m)
      about   ?~(about.m about.x about.m)
      reason  ?:(=('' reason.m) reason.x reason.m)
    ==
  (snoc acc m)
::  +brief-steps: the statuses a move walks an action through: none
::  when it is settled or already there; proposed to done goes by way
::  of approved; a claimed one is left to its executor
::
++  brief-steps
  |=  [cur=@t want=@t]
  ^-  (list @t)
  ?:  |(=('' want) ?=(?(%done %dismissed %failed) cur) =(cur want))  ~
  ?:  &(=('proposed' cur) =('done' want))  ~['approved' 'done']
  ?:  &(=('claimed' cur) =('approved' want))  ~
  ~[want]
::  ==  the nexus's pure rules (version 60): moved here from the nexus
::  so the suites and the mutation runs reach them. The nexus keeps a
::  one-line alias for each, so no call site there changed.
::
::  +trail-entry: one audit row. Both rings carry the same five pairs,
::  so they are built in one place.
::
++  trail-entry
  |=  [op=@t ok=? why=@t by=@t now=@da]
  ^-  json
  %-  pairs:enjs:format
  ~[['op' s+op] ['ok' b+ok] ['why' s+why] ['by' s+by] ['at' (en-time now)]]
++  find-row
  |=  [rs=(list row) id=@ta]
  ^-  (unit row)
  ?~  rs  ~
  ?:  =(id.i.rs id)  `i.rs
  $(rs t.rs)
::  +open-twin: an open action with this kind and title, if any
::
++  open-twin
  |=  [all=(list [id=@ta a=action]) kind=@tas title=@t]
  ^-  (unit [id=@ta a=action])
  ?~  all  ~
  ?:  &((is-open a.i.all) =(kind.a.i.all kind) =(title.a.i.all title))  `i.all
  $(all t.all)
::  +seen-by: an action as an actor's view shows it: whole for the
::  owner, its about trimmed to the key's kinds, as +view-of trims the
::  action list
::
++  seen-by
  |=  [act=actor a=action]
  ^-  action
  ?~(scope.act a (scope-about a kinds.u.scope.act))
::  +settings-file, +settings-view: the document an op writes, and how
::  its GET shows it (the secrets masked)
::
++  settings-file
  |=  op=@t
  ^-  @ta
  ?+  op  %'policy.json'
    %'set-schema'     %'schema.json'
    %'set-generator'  %'generator.json'
    %'set-telegram'   %'telegram.json'
    %'set-chat'       %'chat.json'
    %'set-mail'       %'mail.json'
    %'set-read'       %'read.json'
  ==
++  settings-view
  |=  [op=@t doc=json]
  ^-  json
  ?+  op  doc
    %'set-generator'  (en-config-masked (de-config doc))
    %'set-telegram'   (en-tg-config-masked (de-tg-config doc))
    %'set-chat'       (en-chat-config (de-chat-config doc))
    %'set-mail'       (en-mail-config (de-mail-config doc))
    %'set-read'       (en-mail-config (de-mail-config doc))
  ==
++  list-json
  |=  [items=(list [id=@t name=@t]) note=@t]
  ^-  json
  %-  pairs:enjs:format
  :~  ['items' a+(turn items |=([id=@t name=@t] (pairs:enjs:format ~[['id' s+id] ['name' s+name]])))]
      ['note' s+note]
  ==
::  +people-of-ships: every person body with a ship, keyed by that ship
::  as the settings key one, so a person the owner named on the ship is
::  known to the reader without a row on the card. A ship alias (the
::  owner's old moon) keys its person too; a body's own ship wins over
::  an alias, and the owner over anyone.
::
++  people-of-ships
  |=  all=(list loaded)
  ^-  (map @t @t)
  =/  people=(list loaded)  (skim all |=(l=loaded =(%person kind.body.l)))
  =/  aliased=(list [@t @t])
    %-  zing
    %+  turn  people
    |=  l=loaded
    ^-  (list [@t @t])
    %+  murn  ~(tap in aliases.body.l)
    |=(a=@t ?.(=('~' (end [3 1] (trim-cord a))) ~ `[(ship-key a) `@t`id.l]))
  =/  own=(list [@t @t])
    %+  murn  people
    |=(l=loaded ?~(ship.body.l ~ `[(ship-key (scot %p u.ship.body.l)) `@t`id.l]))
  =/  mine=(list [@t @t])  (skim (weld aliased own) |=([* id=@t] =('person/me' id)))
  (~(gas by (~(gas by (~(gas by *(map @t @t)) aliased)) own)) mine)
++  dedupe-json
  |=  js=(list json)
  ^-  (list json)
  =|  seen=(set json)
  |-
  ?~  js  ~
  ?:  (~(has in seen) i.js)  $(js t.js)
  [i.js $(js t.js, seen (~(put in seen) i.js))]
::  +brief-texts, +brief-tags: every brief sent today (its text), and
::  the tags of the one whose text is given
::
++  brief-texts
  |=  bl=json
  ^-  (list @t)
  =/  today=(list @t)  (turn (ga bl 'today') |=(e=json (gs e 'text')))
  ?:(=('' (gs bl 'text')) today [(gs bl 'text') today])
++  brief-tags
  |=  [bl=json text=@t]
  ^-  (list [tag=@t id=@ta])
  =/  hits=(list json)  (skim (ga bl 'today') |=(e=json =(text (gs e 'text'))))
  =/  t=json  ?^(hits (gj i.hits 'tags') ?:(=(text (gs bl 'text')) (gj bl 'tags') ~))
  ?.  ?=([%o *] t)  ~
  (murn ~(tap by p.t) |=([k=@t v=json] ?:(?=([%s *] v) `[k `@ta`p.v] ~)))
::  +essay-of: a Tlon essay of one text: a story of one inline verse
::  per line, the author, the moment, the /chat kind, no meta or blob
::
++  essay-of
  |=  [text=@t our=@p now=@da]
  ^-  *
  =/  story=*
    %+  turn  (split-char 10 (trip text))
    |=(l=tape [%inline ~[(crip l)]])
  [[story our now] /chat ~ ~]
++  find-run
  |=  [runs=(list tg-run) chat=@t]
  ^-  (unit tg-run)
  ?~  runs  ~
  ?:(=(chat.i.runs chat) `i.runs $(runs t.runs))
::  +tg-final-row: a validated observation (subject, attr, value, at,
::  conf, message, until) as the writer's row: the source is the message
::  it came from (kind chat, or web for a page read), by the reader's
::  signer, the message key gone.
::
++  tg-final-row
  |=  [o=json signer=@t src=@t]
  ^-  json
  ?.  ?=([%o *] o)  o
  =/  msg=@t  (gs o 'message')
  ?:  =('' msg)  o
  :-  %o
  %-  ~(gas by (~(del by p.o) 'message'))
  :~  ['source' (pairs:enjs:format ~[['kind' s+src] ['id' s+msg]])]
      ['by' s+signer]
  ==
::  +tally-idle: a pass that moved nothing (a claim that was refused
::  does not count, nor a poke the calendar refused, so a refusal that
::  repeats does not run passes without end)
::
++  tally-idle
  |=  t=exec-tally
  ^-  ?
  ?&  =(0 :(add claimed.t sent.t placed.t ticked.t deleted.t moved.t closed.t adopted.t))
      ?=(~ failed.t)
  ==
::  +tang-head: a refusal's first line, as the note an action fails with
::
++  tang-head
  |=  t=tang
  ^-  @t
  ?~  t  'refused'
  (crip ~(ram re i.t))
::  +note-missing: a desk link does not know, named once in the tally
::
++  note-missing
  |=  [t=exec-tally name=@t]
  ^-  exec-tally
  ?:  (lien missing.t |=(x=@t =(x name)))  t
  t(missing (snoc missing.t name))
::  ==  the scope, applied
::
::  +hidden-for: the attributes an actor never sees: none for the
::  owner, policy.sensitive for a key
::
++  hidden-for
  |=  [act=actor policy=json]
  ^-  (set @t)
  ?:(owner.act ~ (sensitive-of policy))
::  +view-of: what an actor may see: the bodies in its kinds with the
::  hidden attributes dropped, and the actions in its action kinds. A
::  value that refs a body outside the kinds reads as cleared on a row
::  with a synthetic id, and an about naming one is trimmed away: a key
::  never learns such a body exists. The owner sees everything.
::
++  view-of
  |=  [act=actor all=(list loaded) acts=(list [id=@ta a=action]) hide=(set @t)]
  ^-  [all=(list loaded) acts=(list [id=@ta a=action])]
  ?~  scope.act  [all acts]
  =/  s=scope  u.scope.act
  :-  %+  murn  all
      |=  l=loaded
      ^-  (unit loaded)
      ?.  (kind-in-scope s kind.body.l)  ~
      `l(rows (veil-refs (drop-attrs rows.l hide) kinds.s))
  %+  turn  (skim acts |=([* a=action] (action-in-scope s kind.a)))
  |=([id=@ta a=action] [id (scope-about a kinds.s)])
::  +deny-observe: why a key may not send this batch, or ~. The owner is
::  never denied. A batch with one item outside the scope is refused
::  whole, naming the first offender (which the key itself sent). A key
::  whose scope says sensitive may observe the attributes the policy
::  marks sensitive; every view goes on hiding them from it.
::
++  deny-observe
  |=  [act=actor jon=json policy=json]
  ^-  (unit @t)
  ?~  scope.act  ~
  ?.  write.u.scope.act  `'read only key'
  =/  bad=(unit @t)  (out-of-scope jon u.scope.act (key-hide u.scope.act policy))
  ?~  bad  ~
  `(cat 3 'not in scope: ' u.bad)
::  +deny-write: why a key may not write a body of this kind, or ~
::
++  deny-write
  |=  [act=actor kind=@tas]
  ^-  (unit @t)
  ?~  scope.act  ~
  ?.  write.u.scope.act  `'read only key'
  ?.  (kind-in-scope u.scope.act kind)  `(cat 3 'not in scope: ' kind)
  ~
::  ==  who is asking
::
::  an actor: the owner (the cookie, writing as "http"), or a key with
::  its identity and its scope
::
+$  actor  [owner=? by=@t scope=(unit scope)]
::  +$  chat-tally: what one pass did
::
+$  chat-tally
  $:  read=@ud  filed=@ud  strangers=@ud  held=@ud
      changed=@ud  conversations=@ud  unpicked=@ud  own=@ud
      notes=(list @t)
  ==
::  +$  tg-run: one chat's updates that passed the filters, oldest first
::
+$  tg-item  [name=@ta uid=@ud msg=tg-msg who=@t]
+$  tg-run   [chat=@t items=(list tg-item)]
::  ==  the executor (version 34): the ship carries out its own approved
::  actions. docs/superpowers/specs/2026-09-21-executors-on-ship-design.md
::
::  The lib plans (+plan-exec, +plan-mirror); the fiber here files. One
::  pass is +exec-pass (the approved actions, each claimed, read back,
::  carried out and reported) then +todo-pass (the calendar's todo list
::  against the task actions), then the record.
::
::  what a pass did, for exec-last.json
::
+$  exec-tally
  $:  claimed=@ud                               ::  actions the ship claimed
      sent=@ud                                  ::  messages delivered
      placed=@ud                                ::  events and todos made
      failed=(list [id=@t title=@t note=@t])    ::  the newest first
      ticked=@ud                                ::  todos ticked for a done action
      deleted=@ud                               ::  todos deleted for a dismissed or failed one
      moved=@ud                                 ::  todos whose due followed the action's
      closed=@ud                                ::  actions done because their todo was ticked
      adopted=@ud                               ::  hand-typed todos made into tasks
      missing=(list @t)                         ::  desks link does not know
      notes=(list @t)
  ==
::  ==  the routes (version 60)
::
::  +inline-page: the page with its stylesheet and its script inside it,
::  so opening orrery is one request, not three (each request costs the
::  owner's ship about two seconds). A page without the two tags is
::  served as it is.
::
++  inline-page
  |=  [html=@t css=@t js=@t]
  ^-  @t
  =.  html
    (swap-once html '<link rel="stylesheet" href="/apps/orrery/orrery.css">' (rap 3 '<style>' css '</style>' ~))
  (swap-once html '<script src="/apps/orrery/orrery.js"></script>' (rap 3 '<script>' js '</script>' ~))
::  +swap-once: the first pin in hay replaced by new, hay when there is
::  none
::
++  swap-once
  |=  [hay=@t pin=@t new=@t]
  ^-  @t
  =/  at=(unit @ud)  (find (trip pin) (trip hay))
  ?~  at  hay
  (rap 3 (end [3 u.at] hay) new (rsh [3 (add u.at (met 3 pin))] hay) ~)
::  +route-path: the path under /apps/orrery a request names; a trailing
::  slash parses as a trailing empty knot and is dropped
::
++  route-path
  |=  site=path
  ^-  path
  =/  suffix0=path  (slag 2 site)
  ?:  &(?=(^ suffix0) =('' (rear `path`suffix0)))  (snip `path`suffix0)
  suffix0
::  +$  access: who may take a route: the owner alone, the owner or a
::  key with write (so a client that walks the owner through a setup
::  can finish it), or every actor (the route applies a key's scope
::  itself)
::
+$  access  ?(%own %writes %any)
::  +route-of: the route a request names and who may take it, or ~ for
::  no such route. The nexus dispatches on the tag.
::
++  route-of
  |=  [meth=@t suffix=path]
  ^-  (unit [tag=@tas =access])
  ?:  &(=('GET' meth) ?=(~ suffix))                             `[%get-page %own]
  ?:  &(=('GET' meth) ?=([%'orrery.css' ~] suffix))             `[%get-css %own]
  ?:  &(=('GET' meth) ?=([%'orrery.js' ~] suffix))              `[%get-js %own]
  ?:  &(=('GET' meth) ?=([%api %state ~] suffix))               `[%get-state %any]
  ?:  &(=('GET' meth) ?=([%api %body @ @ ~] suffix))            `[%get-body %any]
  ?:  &(=('DELETE' meth) ?=([%api %body @ @ ~] suffix))         `[%delete-body %own]
  ?:  &(=('GET' meth) ?=([%api %resolve ~] suffix))             `[%get-resolve %any]
  ?:  &(=('POST' meth) ?=([%api %observe ~] suffix))            `[%post-observe %any]
  ?:  &(=('POST' meth) ?=([%api %retract ~] suffix))            `[%post-retract %any]
  ?:  &(=('POST' meth) ?=([%api %bodies ~] suffix))             `[%post-bodies %any]
  ?:  &(=('POST' meth) ?=([%api %merge ~] suffix))              `[%post-merge %own]
  ?:  &(=('POST' meth) ?=([%api %act ~] suffix))                `[%post-act %any]
  ?:  &(=('GET' meth) ?=([%api %actions ~] suffix))             `[%get-actions %any]
  ?:  &(=('POST' meth) ?=([%api %actions @ ~] suffix))          `[%post-actions %any]
  ?:  &(=('POST' meth) ?=([%api %actions @ %refine ~] suffix))  `[%post-actions-refine %any]
  ?:  &(=('GET' meth) ?=([%api %settings ~] suffix))            `[%get-settings %own]
  ?:  &(=('GET' meth) ?=([%api %schema ~] suffix))              `[%get-schema %own]
  ?:  &(=('PUT' meth) ?=([%api %schema ~] suffix))              `[%put-schema %own]
  ?:  &(=('GET' meth) ?=([%api %policy ~] suffix))              `[%get-policy %own]
  ?:  &(=('PUT' meth) ?=([%api %policy ~] suffix))              `[%put-policy %own]
  ?:  &(=('POST' meth) ?=([%api %share ~] suffix))              `[%post-share %own]
  ?:  &(=('DELETE' meth) ?=([%api %share @ @ @ ~] suffix))      `[%delete-share %own]
  ?:  &(=('GET' meth) ?=([%api %shares ~] suffix))              `[%get-shares %own]
  ?:  &(=('POST' meth) ?=([%api %accept ~] suffix))             `[%post-accept %own]
  ?:  &(=('POST' meth) ?=([%api %decline ~] suffix))            `[%post-decline %own]
  ?:  &(=('POST' meth) ?=([%api %sync ~] suffix))               `[%post-sync %own]
  ?:  &(=('POST' meth) ?=([%api %clients ~] suffix))            `[%post-clients %own]
  ?:  &(=('GET' meth) ?=([%api %clients ~] suffix))             `[%get-clients %own]
  ?:  &(=('DELETE' meth) ?=([%api %clients @ ~] suffix))        `[%delete-clients %own]
  ?:  &(=('GET' meth) ?=([%api %generator ~] suffix))           `[%get-generator %own]
  ?:  &(=('PUT' meth) ?=([%api %generator ~] suffix))           `[%put-generator %own]
  ?:  &(=('GET' meth) ?=([%api %generator %last ~] suffix))     `[%get-generator-last %own]
  ?:  &(=('POST' meth) ?=([%api %generate ~] suffix))           `[%post-generate %any]
  ?:  &(=('POST' meth) ?=([%api %reconcile ~] suffix))          `[%post-reconcile %own]
  ?:  &(=('GET' meth) ?=([%api %reconcile %last ~] suffix))     `[%get-reconcile-last %own]
  ?:  &(=('GET' meth) ?=([%api %telegram ~] suffix))            `[%get-telegram %own]
  ?:  &(=('PUT' meth) ?=([%api %telegram ~] suffix))            `[%put-telegram %own]
  ?:  &(=('GET' meth) ?=([%api %telegram %last ~] suffix))      `[%get-telegram-last %own]
  ?:  &(=('POST' meth) ?=([%api %telegram %webhook ~] suffix))  `[%post-telegram-webhook %writes]
  ?:  &(=('GET' meth) ?=([%api %telegram %webhook ~] suffix))   `[%get-telegram-webhook %writes]
  ?:  &(=('POST' meth) ?=([%api %telegram %wake ~] suffix))     `[%post-telegram-wake %own]
  ?:  &(=('GET' meth) ?=([%api %chat ~] suffix))                `[%get-chat %writes]
  ?:  &(=('PUT' meth) ?=([%api %chat ~] suffix))                `[%put-chat %writes]
  ?:  &(=('GET' meth) ?=([%api %chat %last ~] suffix))          `[%get-chat-last %own]
  ?:  &(=('POST' meth) ?=([%api %chat %wake ~] suffix))         `[%post-chat-wake %own]
  ?:  &(=('GET' meth) ?=([%api %chat %peek ~] suffix))          `[%get-chat-peek %own]
  ?:  &(=('GET' meth) ?=([%api %version ~] suffix))             `[%get-version %any]
  ?:  &(=('GET' meth) ?=([%api %chat %lists ~] suffix))         `[%get-chat-lists %own]
  ?:  &(=('GET' meth) ?=([%api %chat %dms ~] suffix))           `[%get-chat-dms %own]
  ?:  &(=('GET' meth) ?=([%api %chat %channels ~] suffix))      `[%get-chat-channels %own]
  ?:  &(=('POST' meth) ?=([%api %read ~] suffix))               `[%post-read %writes]
  ?:  &(=('GET' meth) ?=([%api %read %settings ~] suffix))      `[%get-read-settings %writes]
  ?:  &(=('PUT' meth) ?=([%api %read %settings ~] suffix))      `[%put-read-settings %writes]
  ?:  &(=('GET' meth) ?=([%api %read %last ~] suffix))          `[%get-read-last %own]
  ?:  &(=('POST' meth) ?=([%api %read %wake ~] suffix))         `[%post-read-wake %own]
  ?:  &(=('GET' meth) ?=([%api %mail ~] suffix))                `[%get-mail %writes]
  ?:  &(=('PUT' meth) ?=([%api %mail ~] suffix))                `[%put-mail %writes]
  ?:  &(=('GET' meth) ?=([%api %mail %last ~] suffix))          `[%get-mail-last %own]
  ?:  &(=('POST' meth) ?=([%api %mail %wake ~] suffix))         `[%post-mail-wake %own]
  ?:  &(=('GET' meth) ?=([%api %brief %last ~] suffix))         `[%get-brief-last %own]
  ?:  &(=('POST' meth) ?=([%api %brief %wake ~] suffix))        `[%post-brief-wake %own]
  ?:  &(=('GET' meth) ?=([%api %exec %last ~] suffix))          `[%get-exec-last %own]
  ?:  &(=('GET' meth) ?=([%api %calendar %last ~] suffix))      `[%get-calendar-last %own]
  ?:  &(=('POST' meth) ?=([%api %exec %wake ~] suffix))         `[%post-exec-wake %own]
  ~
::  +access-refusal: why this actor may not take a route of this access,
::  or ~
::
++  access-refusal
  |=  [act=actor =access]
  ^-  (unit @t)
  ?:  owner.act  ~
  ?-  access
    %any     ~
    %own     `'owner only'
    %writes  ?:(&(?=(^ scope.act) write.u.scope.act) ~ `'read only key')
  ==
::  +request-refusal: a request refused before its route: a body that
::  does not say it is JSON (a POST with no body carries none to
::  mistype), and the owner's cookie on a request another site sent (a
::  browser says where a request came from; the Host header is no help,
::  a proxy rewrites it). ponytail: a browser too old to send
::  Sec-Fetch-Site is not held.
::
++  request-refusal
  |=  [meth=@t body=(unit octs) ctype=@t site=@t owner=?]
  ^-  (unit [code=@ud why=@t])
  ?:  ?&  |(=('POST' meth) =('PUT' meth))
          ?=(^ body)
          !=(0 p.u.body)
          !=('application/json' (end [3 16] (crip (cass (trip ctype)))))
      ==
    `[415 'content-type: application/json required']
  ?:  &(owner !=('GET' meth) |(=('cross-site' site) =('same-site' site)))
    `[403 'a request from another site is refused']
  ~
::  +act-refusal: why a key may not propose this action, or ~. A kind
::  outside its action kinds is 403 (the key sent the kind itself); a
::  body outside its kinds is 400 no such body, in about or in what the
::  payload names (a message's to, a merge's pair), so a key never
::  learns such a body exists; and a key does not merge at all, which
::  is the owner's and reconcile's.
::
++  act-refusal
  |=  [act=actor a=action]
  ^-  (unit [code=@ud why=@t])
  ?~  scope.act  ~
  =/  s=scope  u.scope.act
  ?.  (action-in-scope s kind.a)  `[403 (cat 3 'not in scope: ' kind.a)]
  =/  beyond
    |=  ids=(list @t)
    ^-  (unit @t)
    ?~  ids  ~
    =/  pk  (parse-bid i.ids)
    ?:  &(?=(^ pk) !(kind-in-scope s kind.u.pk))  `i.ids
    $(ids t.ids)
  =/  out=(unit @t)  (beyond ~(tap in about.a))
  ?^  out  `[400 (cat 3 'about: no such body ' u.out)]
  ?:  =(%merge kind.a)  `[403 'a key may not propose a merge']
  =/  named=(list @t)
    (skip (turn `(list @t)`~['to' 'from' 'into'] |=(k=@t (gs payload.a k))) |=(t=@t =('' t)))
  =/  far=(unit @t)  (beyond named)
  ?^  far  `[400 (cat 3 'payload: no such body ' u.far)]
  ~
::  ==  the read channel (version 60)
::
::  +read-item: a read-inbox item as the reader's message (the title
::  heads the text), the scope of the key that handed it in (~ for the
::  owner's), and the kind its facts are filed as: signed by the key's
::  by, else by web
::
++  read-item
  |=  [item=json now=@da]
  ^-  [msg=tg-msg sc=(unit scope) kind=reader-kind]
  =/  title=@t  (gs item 'title')
  =/  text=@t  (gs item 'text')
  =/  msg=tg-msg
    :*  (gs (gj item 'source') 'id')
        (gs item 'who')
        ?:(=('' title) text (rap 3 title nl nl text ~))
        (fall (de-iso (gs item 'at')) now)
        (gs item 'id')
        ''
    ==
  =/  sc=(unit scope)
    =/  sj=json  (gj item 'scope')
    ?.  ?=([%o *] sj)  ~
    =/  d  (de-scope sj)
    ?:(?=(%& -.d) `p.d ~)
  =/  kind=reader-kind  read-kind
  =?  kind  ?=(^ sc)  kind(by (gs item 'by'))
  [msg sc kind]
::  +read-held: whether today's texts are spent: the record's count, when
::  its day is today, at the cap
::
++  read-held
  |=  [last=json now=@da cap=@ud]
  ^-  ?
  (gte (day-count last 'read_today' now) cap)
::  +key-hide: what a key may not write: the policy's sensitive names
::  and the address attributes (where the executor sends a person's
::  messages), unless its scope says sensitive: write
::
++  key-hide
  |=  [s=scope policy=json]
  ^-  (set @t)
  ?:  sensitive.s  ~
  (~(uni in (sensitive-of policy)) address-attrs)
::  ==  the readers' verdicts (version 60)
::
::  +run-fresh: a run without its questions: a question states nothing,
::  and neither does an empty text; a handed-in page that ends in a
::  question still says things
::
++  run-fresh
  |=  [run=(list [msg=tg-msg who=@t]) kind=reader-kind]
  ^-  (list [msg=tg-msg who=@t])
  %+  skip  run
  |=  [msg=tg-msg who=@t]
  ?:  =('' text.msg)  &
  &(!=('web' channel.kind) =('?' (rsh [3 (dec (met 3 text.msg))] text.msg)))
::  +run-rows: what the analyst reads: the chat's window as context, then
::  the run's new messages, oldest first
::
++  run-rows
  |=  [recent=json fresh=(list [msg=tg-msg who=@t]) kind=reader-kind]
  ^-  (list window-row)
  ?~  fresh  ~
  %+  weld
    (turn (tg-window recent chat.msg.i.fresh) |=([id=@t at=@t w=@t t=@t] ^-(window-row [id at w t &])))
  %+  turn  `(list [msg=tg-msg who=@t])`fresh
  |=([msg=tg-msg who=@t] ^-(window-row [id:(tg-source msg kind) (en-iso at.msg) who text.msg |]))
::  +gate-verdict: whether the gate lets the run through, and the note
::  saying so. An answer without the question's noul is no answer, and
::  no answer reads the run.
::
++  gate-verdict
  |=  [g=(unit json) threshold=@ud]
  ^-  [read=? note=@t]
  =?  g  ?&(?=(^ g) ?=(~ (gj (gj u.g 'worth_reading') 'noul')))  ~
  =/  p=@ud  ?~(g 100 (noul-of u.g 'worth_reading'))
  =/  read=?  !(lth p threshold)
  :-  read
  ?~  g  'gate unavailable, analyst asked'
  (rap 3 'gate: ' (crip (a-co:co p)) ?:(read ', read' ', not read') ~)
::  +reader-answer: the analyst's answer as JSON, or why not and whether
::  the model counts as down, so the run waits and is asked again:
::  unreachable or timed out, 401 to 404, 408, 429 and 5xx, and a 200
::  that carries the host's error (a failure after the request began)
::
++  reader-answer
  |=  [status=@ud body=@t]
  ^-  (each json [down=? why=@t])
  ?.  =(200 status)
    :+  %|
      ?|  =(0 status)
          &((gte status 401) (lte status 404))
          =(408 status)
          =(429 status)
          &((gte status 500) (lte status 599))
      ==
    (rap 3 'model: ' (crip (a-co:co status)) ' ' (end [3 200] body) ~)
  =/  resp=json  (fall (de:json:html body) [%o ~])
  =/  ans  (answer-of resp)
  ?:  ?=(%| -.ans)  [%| ?=(^ (gj resp 'error')) p.ans]
  =/  parsed=(unit json)  (parse-answer text.p.ans)
  ?~  parsed  [%| | 'model: the answer is not JSON']
  [%& u.parsed]
::  +owner-zone: person/me's timezone, else the fallback given
::
++  owner-zone
  |=  [all=(list loaded) multi=(set @t) now=@da fallback=@t]
  ^-  @t
  =/  z=@t  (attr-text all multi now 'person/me' 'timezone')
  ?:(=('' z) fallback z)
::  ==  the mail reader's choices (version 60)
::
::  +mail-since: the floor: the backfill on the first pass, then never
::  later than a week ago, so mail delivered late, mail the cap held and
::  a reply the model could not read are read on a later pass; the seen
::  ring keeps what was read from being read twice
::
++  mail-since
  |=  [last=json backfill=@ud now=@da]
  ^-  @da
  =/  first=(unit @da)  (de-iso (gs last 'since'))
  =/  span=@dr  (mul backfill ~h1)
  ?~  first  ?:((lth now span) ~1970.1.1 (sub now span))
  (max u.first (sub now ~d7))
::  +mail-fresh: the copies to read, oldest first: verified as their
::  sender's, sent since the floor and not in the future
::
++  mail-fresh
  |=  [msgs=(list mail-msg) since=@da now=@da]
  ^-  (list mail-msg)
  %+  sort
    %+  skim  msgs
    |=(x=mail-msg &(trusted.x (gte sent.x since) (lte sent.x now)))
  |=([a=mail-msg b=mail-msg] (lth sent.a sent.b))
::  +brief-replies-of: the owner's replies to a brief sent today, each
::  with the brief's text: from us, answering a message from us whose
::  body is one of today's briefs word for word (a client's brief for
::  the same day carries other tags), under a brief's subject, and not
::  read before
::
++  brief-replies-of
  |=  [fresh=(list mail-msg) msgs=(list mail-msg) our=@p seen=(set @t) sent-today=(list @t)]
  ^-  (list [r=mail-msg root=@t])
  =/  by-id=(map @t mail-msg)  (~(gas by *(map @t mail-msg)) (turn msgs |=(x=mail-msg [id.x x])))
  %+  murn  fresh
  |=  x=mail-msg
  ^-  (unit [r=mail-msg root=@t])
  ?.  &(=(our from.x) ?=(^ prev.x) !=('' (brief-day-of subj.x)) !(~(has in seen) (cat 3 'mail:' id.x)))  ~
  =/  root=(unit mail-msg)  (~(get by by-id) (scot %uv u.prev.x))
  ?~  root  ~
  ?.  &(=(our from.u.root) (lien sent-today |=(t=@t =(t body.u.root))))  ~
  `[x body.u.root]
::  +mail-rows: everyone else's mail as the reader's rows; the owner's
::  own and a blank body say nothing
::
++  mail-rows
  |=  [fresh=(list mail-msg) our=@p]
  ^-  (list tg-msg)
  %+  murn  fresh
  |=  x=mail-msg
  ^-  (unit tg-msg)
  ?:  |(=(our from.x) =('' (trim-cord body.x)))  ~
  `(mail-row x)
::  ==  the chat reader's choices (version 60)
::
::  +day-count: a record's count under key for today, 0 when the record
::  is from another UTC day
::
++  day-count
  |=  [last=json key=@t now=@da]
  ^-  @ud
  ?.  =((end [3 10] (en-iso now)) (gs last 'day'))  0
  (fall (gn last key) 0)
::  +chat-since: where the scry starts, and the floor under which a row
::  is not read. The first pass looks back backfill hours and reads
::  nothing sent before that; a later pass takes whatever the scry says
::  changed, however old its sent, since a writ delivered late shows up
::  once.
::
++  chat-since
  |=  [last=json backfill=@ud now=@da]
  ^-  [since=@da floor=@da]
  =/  first=(unit @da)  (de-iso (gs last 'since'))
  =/  span=@dr  (mul backfill ~h1)
  =/  since=@da  ?^(first u.first ?:((lth now span) ~1970.1.1 (sub now span)))
  [since ?^(first *@da since)]
::  +chat-next: where the next pass starts. A pass one scry did not
::  answer asks again from the same since, the seen ring keeping what was
::  read from being read twice; a message the cap held is neither read
::  nor remembered, so the next pass starts at the first one held.
::
++  chat-next
  |=  [answered=? since=@da held-at=(unit @da) now=@da]
  ^-  @da
  ?.  answered  since
  (fall held-at now)
::  +$  sift: the rows a chat pass reads, gathered into runs, and what
::  it left: strangers, held by the cap (and the first held's time),
::  the ids to remember, and how many were taken against the cap
::
+$  sift
  $:  runs=(list [chat=@t items=(list [key=@t msg=tg-msg who=@t])])
      strangers=@ud
      held=@ud
      held-at=(unit @da)
      new=(list @t)
      taken=@ud
  ==
::  +sift-rows: the rows sifted (already read, a stranger, no text, the
::  cap) and gathered into runs, one per conversation in the order the
::  first of each arrived, so a conversation's new messages are read
::  together and a message further down that settles an earlier one is
::  seen before anything is proposed from the earlier one alone. A
::  reader's key-of names a row in its seen ring.
::
++  chat-key  |=(m=tg-msg ^-(@t (rap 3 chat.m '/' mid.m ~)))
++  mail-key  |=(m=tg-msg ^-(@t (cat 3 'mail:' mid.m)))
++  sift-rows
  |=  [rows=(list tg-msg) seen=(set @t) people=(map @t @t) today=@ud cap=@ud key-of=$-(tg-msg @t)]
  ^-  sift
  =|  acc=sift
  |-  ^+  acc
  ?~  rows  acc(runs (flop (turn runs.acc |=(r=[chat=@t items=(list [key=@t msg=tg-msg who=@t])] r(items (flop items.r))))))
  =/  msg=tg-msg  i.rows
  =/  key=@t  (key-of msg)
  ?:  (~(has in seen) key)  $(rows t.rows)
  =/  who=(unit @t)  (~(get by people) from.msg)
  ?~  who  $(rows t.rows, strangers.acc +(strangers.acc), new.acc [key new.acc])
  ?:  =('' text.msg)  $(rows t.rows, new.acc [key new.acc])
  ?:  (gte (add today taken.acc) cap)
    $(rows t.rows, held.acc +(held.acc), held-at.acc ?^(held-at.acc held-at.acc `at.msg))
  =/  item  [key msg u.who]
  =/  hit=?  (lien runs.acc |=(r=[chat=@t *] =(chat.r chat.msg)))
  %=  $
    rows  t.rows
    taken.acc  +(taken.acc)
    runs.acc
      ?.  hit  [[chat.msg ~[item]] runs.acc]
      %+  turn  runs.acc
      |=  r=[chat=@t items=(list [key=@t msg=tg-msg who=@t])]
      ?:(=(chat.r chat.msg) r(items [item items.r]) r)
  ==
::  ==  the generator's records (version 60)
::
::  +month-spend: the month's spend in micro-dollars, this call's cost
::  (from the model's own figure) added, from 0 in a new month
::
++  month-spend
  |=  [last=json usage=json now=@da]
  ^-  @ud
  =/  month=@t  (end [3 7] (en-iso now))
  =/  prior=@ud  ?:(=(month (gs last 'month')) (fall (gn last 'spend_month_micro') 0) 0)
  =/  cost=json  (gj usage 'cost')
  (add prior ?:(?=([%n *] cost) (micro-of p.cost) 0))
::  +transient-status: a failed call that may pass if asked again (no
::  answer, a timeout, the rate limit, the host's error), so the pass
::  keeps no digest and the next wake asks again; one that will not (a
::  refused key, a prompt too long) keeps it
::
++  transient-status
  |=  s=@ud
  ^-  ?
  |(=(0 s) =(408 s) =(429 s) &((gte s 500) (lte s 599)))
::  +counted-call: the generator's record with one more call today and
::  its cost added to the month's, for a call made outside its pass (a
::  refine)
::
++  counted-call
  |=  [last=json now=@da usage=json]
  ^-  json
  =/  base=(map @t json)  ?:(?=([%o *] last) p.last ~)
  :-  %o
  %-  ~(gas by base)
  :~  ['day' s+(end [3 10] (en-iso now))]
      ['calls_today' (numb:enjs:format +((day-count last 'calls_today' now)))]
      ['month' s+(end [3 7] (en-iso now))]
      ['spend_month_micro' (numb:enjs:format (month-spend last usage now))]
  ==
::  +gen-record-doc: generator-last.json after a pass. A skip (held by
::  the limits, nothing new) says why, and keeps what the last real pass
::  did for the page to show: its digest, its counts, its usage, its
::  error and its time, and its notes after the skip's own.
::
++  gen-record-doc
  |=  $:  last=json  now=@da  dg=(unit @ux)  filed=@ud  dropped=@ud  notes=(list @t)
          usage=json  error=(unit @t)  secs=@ud  skipped=?  rev=json
      ==
  ^-  json
  =/  keep=@t
    ?:  skipped  (gs last 'digest')
    ?~(dg '' (scot %ux u.dg))
  =/  kept  |=([k=@t d=json] ^-(json ?.(skipped d (gj last k))))
  =/  said=(list @t)
    ?.  skipped  notes
    (scag 20 (dedupe (weld notes (strings (ga last 'notes')))))
  %-  pairs:enjs:format
  :~  ['at' (en-time now)]
      ['called' (gj last 'called')]
      ['day' (gj last 'day')]
      ['calls_today' (gj last 'calls_today')]
      ['urgent_today' (gj last 'urgent_today')]
      ::  the month's spend, in micro-dollars, from the model's own
      ::  cost figure; the page shows it beside the calls
      ['month' s+(end [3 7] (en-iso now))]
      ['spend_month_micro' (numb:enjs:format (month-spend last usage now))]
      ['rev' rev]
      ['digest' s+keep]
      ['skipped' b+skipped]
      ['filed' (kept 'filed' (numb:enjs:format filed))]
      ['dropped' (kept 'dropped' (numb:enjs:format dropped))]
      ['notes' a+(turn said |=(n=@t `json`s+n))]
      ['usage' (kept 'usage' usage)]
      ['error' (kept 'error' ?~(error ~ s+u.error))]
      ['seconds' (kept 'seconds' (numb:enjs:format secs))]
  ==
::  +counted-pass: the generator's record with one more call today, and
::  one more urgent call when the pass was urgent, both from 0 on a new
::  day
::
++  counted-pass
  |=  [last=json now=@da urgent=?]
  ^-  json
  =/  today=@ud  (day-count last 'calls_today' now)
  =/  urgent-today=@ud  (day-count last 'urgent_today' now)
  =/  base=(map @t json)  ?:(?=([%o *] last) p.last ~)
  :-  %o
  %-  ~(gas by base)
  :~  ['called' (en-time now)]
      ['day' s+(end [3 10] (en-iso now))]
      ['calls_today' (numb:enjs:format +(today))]
      ['urgent_today' (numb:enjs:format ?:(urgent +(urgent-today) urgent-today))]
  ==
::  ==  a body gone, and a late answer (version 60)
::
::  +reabout-one: an action once from is merged into into, or deleted
::  (into ~), or ~ when it does not name from. An open message to from
::  goes to into; about names into where it named from, or loses from.
::
++  reabout-one
  |=  [a=action from=bid into=(unit bid)]
  ^-  (unit action)
  =/  to-it=?  &((is-open a) =(from (gs payload.a 'to')))
  ?.  |((~(has in about.a) from) &(to-it ?=(^ into)))  ~
  =/  kept=(set bid)  (~(del in about.a) from)
  :-  ~
  %=  a
    about  ?~(into kept ?.((~(has in about.a) from) about.a (~(put in kept) u.into)))
    payload  ?.(&(to-it ?=(^ into)) payload.a (set-key payload.a 'to' s+(need into)))
  ==
::  +repoint-people: a reader's settings with every people entry naming
::  from pointed at into, or ~ when none named it
::
++  repoint-people
  |=  [doc=json from=bid into=bid]
  ^-  (unit json)
  =/  p=json  (gj doc 'people')
  ?.  ?=([%o *] p)  ~
  ?.  (lien ~(val by p.p) |=(v=json =(v s+from)))  ~
  `(set-key doc 'people' [%o (~(run by p.p) |=(v=json ?:(=(v s+from) s+into v)))])
::  +answer-fits: whether a 200 answer is shaped for the endpoint that
::  asked: the decider answers with answers, the model with choices or
::  an error. Iris's answer carries nothing that names its request, so
::  a late answer to one that timed out is skipped this way. ponytail:
::  two late answers from one endpoint still cross; the kernel handing
::  back the request's wire would end it. Anything but a 200 fits.
::
++  answer-fits
  |=  [wire=@ta status=@ud body=@t]
  ^-  ?
  ?.  =(200 status)  &
  =/  j=json  (fall (de:json:html body) ~)
  ?+  wire  &
    %decider  (has-key j 'answers')
    ?(%model %reader %brief %refine)  |((has-key j 'choices') (has-key j 'error'))
  ==
::  ==  the writer's choices (version 60)
::
::  +revives: whether a row already stored is written again: the same
::  claim is no news, but the same claim corrected (its until or its
::  confidence changed, which the id leaves out) after the owner
::  retracted it is the new row
::
++  revives
  |=  [old=(unit obs) new=obs]
  ^-  ?
  ?&  ?=(^ old)
      retracted.u.old
      !retracted.new
      |(!=(until.u.old until.new) !=(conf.u.old conf.new))
  ==
::  +dead-rows: what compaction culls from one body: superseded,
::  expired and retracted rows recorded before the horizon, save the
::  row each attribute would fall back to if its winner went
::
++  dead-rows
  |=  [rows=(list row) multi=(set @t) horizon=@da now=@da]
  ^-  (list @ta)
  =/  winners  (fold rows multi now)
  =/  keep=(set @ta)  (fallback-ids rows multi now)
  %+  murn  rows
  |=  r=row
  ^-  (unit @ta)
  ?:  (gte (max at.obs.r seen.obs.r) horizon)  ~
  ?:  (~(has in keep) id.r)  ~
  =/  st=@tas  (status-of r winners now)
  ?:(?=(?(%superseded %expired %retracted) st) `id.r ~)
::  +op-gone: the body a writer op takes away (a delete's id, a merge's
::  from), or '' for any other op
::
++  op-gone
  |=  op=json
  ^-  @t
  =/  o=@t  (gs op 'op')
  ?:  =('delete-body' o)  (gs op 'id')
  ?:  =('merge' o)  (gs op 'from')
  ''
::  +offer-refusal: why a share offer is dropped, or ~. A full inbox
::  drops new offers (200 is far past what a person gets), and one ship
::  holds at most twenty, so a stranger cannot fill it; an offer already
::  held is always taken again.
::
++  offer-refusal
  |=  [cur=(map @t json) key=@t src=@p]
  ^-  (unit @t)
  ?:  (~(has by cur) key)  ~
  ?:  (gte ~(wyt by cur) 200)  `'inbox full'
  =/  theirs=@ud  (lent (skim ~(val by cur) |=(o=json =((scot %p src) (gs o 'host')))))
  ?:  (gte theirs 20)  `'too many offers from this ship'
  ~
::  +replacement: the action a brief move filed in place of the one it
::  changed: another proposed action of the same title proposed this
::  second or later
::
++  replacement
  |=  [after=(list [id=@ta a=action]) old=@ta title=@t now=@da]
  ^-  (unit @ta)
  =/  hits=(list [id=@ta a=action])
    %+  skim  after
    |=([id=@ta a=action] &(!=(id old) =(title.a title) =(%proposed status.a) (gte proposed.a (sub now (mod now ~s1)))))
  ?~(hits ~ `id.i.hits)
::  ==  keys and the telegram filter (version 60)
::
::  +de-mint: a request to mint a key: a name, the identity its writes
::  are signed with, and its scope, or why not
::
++  de-mint
  |=  jon=json
  ^-  (each [name=@t by=@t sc=scope] @t)
  ?.  ?=([%o *] jon)  [%| 'a JSON object is required']
  =/  name=@t  (gs jon 'name')
  ?:  |(=('' name) (gth (met 3 name) max-name))  [%| 'name: 1 to 200 bytes']
  =/  who=@t  (gs jon 'by')
  ?:  |(=('' who) (gth (met 3 who) max-by))  [%| 'by: 1 to 64 bytes']
  =/  sc  (de-scope (gj jon 'scope'))
  ?:  ?=(%| -.sc)  [%| p.sc]
  [%& name who p.sc]
::  +touch-due: whether a key's last use is stamped again: at most hourly
::
++  touch-due
  |=  [used=(unit @da) now=@da]
  ^-  ?
  ?~  used  &
  !(lth now (add u.used ~h1))
::  +tg-why: why the telegram reader ignores an update, as far as the
::  update alone says: not a message, a chat not in chats, a sender not
::  in people. A stranger's business connection and an empty text are
::  checked after.
::
++  tg-why
  |=  [cfg=tg-config mu=(unit tg-msg)]
  ^-  (unit [chat=@t from=@t note=@t])
  ?~  mu  `['' '' 'not a message']
  =/  msg=tg-msg  u.mu
  ?.  (~(has in chats.cfg) chat.msg)  `[chat.msg from.msg (rap 3 'chat ' chat.msg ' is not in chats' ~)]
  ?.  (~(has by people.cfg) from.msg)  `[chat.msg from.msg (rap 3 'sender ' from.msg ' is not in people' ~)]
  ~
::  ==  after a crash (version 60)
::
::  +rise-plan: a crashed fiber's crashes in a row and when it tries
::  again, from its row in rise.json: 1, 2, 4 and up to 60 minutes, the
::  count starting over after two quiet hours, longer than the longest
::  wait, so the waits stay at an hour rather than cycling back to a
::  minute. A restart that is not a crash (a poke refused while waiting)
::  keeps the wait it had.
::
++  rise-plan
  |=  [row=json crash=? now=@da]
  ^-  [n=@ud until=@da]
  =/  was=@ud  (fall (gn row 'n') 0)
  =/  n=@ud
    ?.  crash  was
    ?:((gth now (add (da-of-ms (fall (gn row 'last_ms') 0)) ~h2)) 1 +(was))
  :-  n
  ?.  crash  (da-of-ms (fall (gn row 'until_ms') 0))
  (add now (min ~h1 (mul ~m1 (bex (dec (min n 7))))))
::  +rise-row: a fiber's row in rise.json
::
++  rise-row
  |=  [plan=[n=@ud until=@da] now=@da]
  ^-  json
  %-  pairs:enjs:format
  :~  ['n' (numb:enjs:format n.plan)]
      ['last_ms' (numb:enjs:format (ms-of now))]
      ['until_ms' (numb:enjs:format (ms-of until.plan))]
  ==
::  +mail-threads: the threads a mail pass walks: the most recently
::  active, from auspex's inbox order (/mail/idx, newest first), those
::  the tree holds. ponytail: at most max-mail-threads a pass; more
::  threads than that with mail since the floor leaves the oldest
::  touched unread, and without the index (an auspex that keeps none)
::  the cap takes them in the tree's order.
::
++  max-mail-threads  200
++  mail-threads
  |=  [idx=(unit (list @uv)) segs=(list @ta)]
  ^-  (set @ta)
  ?~  idx  (sy (scag max-mail-threads segs))
  =/  have=(set @ta)  (sy segs)
  %-  sy
  %+  scag  max-mail-threads
  (skim (turn u.idx |=(t=@uv ^-(@ta (scot %uv t)))) |=(x=@ta (~(has in have) x)))
--
