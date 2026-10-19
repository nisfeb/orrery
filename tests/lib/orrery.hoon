::  Unit tests for /lib/orrery: names, time, ids and the decoders.
::
::    Every case a client can send, plus the cases only a broken client
::    sends. A decoder never crashes: "answers the field that failed" is
::    the behaviour under test.
::
/+  *test, orr=orrery
|%
++  jo  |=(t=@t ^-(json (need (de:json:html t))))
++  t0  ~2026.9.16..22.05.00
::  ==  names
::
++  test-ok-kind
  ;:  weld
    (expect !>((ok-kind:orr 'person')))
    (expect !>(!(ok-kind:orr 'Person')))
    (expect !>(!(ok-kind:orr '9lives')))
    (expect !>(!(ok-kind:orr '')))
    (expect !>(!(ok-kind:orr 'a-very-long-kind-name-over-24')))
    ::  the first letter and the last are letters too
    (expect !>((ok-kind:orr 'activity')))
    (expect !>((ok-kind:orr 'zone')))
    ::  the cap as a pair: exactly max-kind accepted, one more refused
    (expect !>((ok-kind:orr (crip (reap 24 'k')))))
    (expect !>(!(ok-kind:orr (crip (reap 25 'k')))))
  ==
++  test-ok-slug
  ;:  weld
    (expect !>((ok-slug:orr '2026-09-16-breakdown')))
    (expect !>((ok-slug:orr 'me')))
    (expect !>(!(ok-slug:orr '-x')))
    (expect !>(!(ok-slug:orr 'John')))
    (expect !>((ok-slug:orr 'oz-trip')))
    (expect !>((ok-slug:orr (crip (reap 64 's')))))
    (expect !>(!(ok-slug:orr (crip (reap 65 's')))))
  ==
++  test-parse-bid
  ;:  weld
    (expect-eq !>(`(unit [@tas @ta])`[~ %person %sarah]) !>((parse-bid:orr 'person/sarah')))
    (expect-eq !>(`(unit [@tas @ta])`~) !>((parse-bid:orr 'sarah')))
    (expect-eq !>(`(unit [@tas @ta])`~) !>((parse-bid:orr 'Person/Sarah')))
  ==
::  ==  time
::
++  test-iso-roundtrip
  =/  s=@t  '2026-09-16T22:05:00Z'
  ;:  weld
    (expect-eq !>(`(unit @da)`[~ t0]) !>((de-iso:orr s)))
    (expect-eq !>(s) !>((en-iso:orr t0)))
    (expect-eq !>(`(unit @da)`[~ t0]) !>((de-iso:orr '2026-09-16T22:05:00.250Z')))
    (expect-eq !>(`(unit @da)`~) !>((de-iso:orr '2026-09-16 22:05:00')))
    (expect-eq !>(`(unit @da)`~) !>((de-iso:orr '2026-13-01T00:00:00Z')))
    (expect-eq !>(`(unit @da)`~) !>((de-iso:orr '2026-09-16T22:05:00+02:00')))
    ::  a day the month does not have rolls over in +year: refuse it
    (expect-eq !>(`(unit @da)`~) !>((de-iso:orr '2026-02-30T00:00:00Z')))
    (expect-eq !>(`(unit @da)`[~ ~2026.2.28]) !>((de-iso:orr '2026-02-28T00:00:00Z')))
    (expect-eq !>('1970-01-01T00:00:00Z') !>((en-iso:orr ~1970.1.1)))
  ==
++  test-unix-secs
  ;:  weld
    (expect-eq !>(`@ud`1.789.596.300) !>((unix-secs:orr t0)))
    (expect-eq !>(`@ud`0) !>((unix-secs:orr ~1969.12.31)))
  ==
::  ==  ids
::
++  o1
  ^-  obs:orr
  ['thing/subaru' 'location' s+'Route 9' t0 ~ 90 ['talon-dm' 'm1'] 'talon/triage' t0 | '']
++  test-obs-id-shape
  =/  id=tape  (trip (obs-id:orr o1))
  ;:  weld
    (expect-eq !>("1789596300-") !>((scag 11 id)))
    (expect-eq !>(19) !>((lent id)))
  ==
++  test-obs-id-ignores-by-and-seen
  =/  base=obs:orr  o1
  =/  o2=obs:orr  base(by 'claude-code', seen (add t0 ~h1))
  =/  o3=obs:orr  base(value s+'Route 10')
  ;:  weld
    (expect-eq !>((obs-id:orr o1)) !>((obs-id:orr o2)))
    (expect !>(!=((obs-id:orr o1) (obs-id:orr o3))))
  ==
++  test-act-id-shape
  =/  a=action:orr
    [%task 'Call the shop' ~ (sy ~['thing/subaru']) ~ 'mcp' t0 %proposed '' ~]
  (expect-eq !>(19) !>((lent (trip (act-id:orr a)))))
::  ==  decoders
::
++  test-de-body-ok
  =/  got
    %+  de-body:orr
      (jo '{"id":"place/johns-machine-shop","name":"John\'s Machine Shop","aliases":["John\'s","the shop"]}')
    t0
  ?.  ?=(%& -.got)  (expect !>(|))
  ;:  weld
    (expect-eq !>('place/johns-machine-shop') !>(id.p.got))
    (expect-eq !>(%place) !>(kind.body.p.got))
    (expect-eq !>('John\'s Machine Shop') !>(name.body.p.got))
    (expect-eq !>(`(set @t)`(sy ~['John\'s' 'the shop'])) !>(aliases.body.p.got))
    (expect-eq !>(t0) !>(created.body.p.got))
    (expect-eq !>(`(unit @p)`~) !>(ship.body.p.got))
  ==
++  test-de-body-refusals
  =/  bad
    |=  t=@t
    ^-  @t
    =/  got  (de-body:orr (jo t) t0)
    ?:(?=(%| -.got) p.got 'accepted')
  ;:  weld
    (expect-eq !>('id: expected <kind>/<slug>, lowercase, digits and hyphens') !>((bad '{"id":"Sarah"}')))
    (expect-eq !>('aliases: every alias is a string') !>((bad '{"id":"person/sarah","aliases":[1]}')))
    (expect-eq !>('aliases: each 1 to 100 bytes') !>((bad '{"id":"person/sarah","aliases":[""]}')))
  ==
++  test-de-obs-ok
  =/  got
    %^  de-obs:orr
      (jo '{"subject":"thing/subaru","attr":"location","value":{"ref":"place/johns-machine-shop"},"at":"2026-09-17T02:10:00Z","conf":85,"source":{"kind":"talon-dm","id":"m3"}}')
    t0  'http'
  ?.  ?=(%& -.got)  (expect !>(|))
  ;:  weld
    (expect-eq !>('thing/subaru') !>(subject.p.got))
    (expect-eq !>('location') !>(attr.p.got))
    (expect-eq !>(`json`(jo '{"ref":"place/johns-machine-shop"}')) !>(value.p.got))
    (expect-eq !>(~2026.9.17..2.10.00) !>(at.p.got))
    (expect-eq !>(`(unit @da)`~) !>(until.p.got))
    (expect-eq !>(85) !>(conf.p.got))
    (expect-eq !>(`source:orr`['talon-dm' 'm3']) !>(source.p.got))
    (expect-eq !>('http') !>(by.p.got))
    (expect-eq !>(t0) !>(seen.p.got))
    (expect-eq !>(|) !>(retracted.p.got))
  ==
++  test-de-obs-defaults
  =/  got
    %^  de-obs:orr
      (jo '{"subject":"person/me","attr":"status","value":null,"source":{"kind":"user","id":""}}')
    t0  'http'
  ?.  ?=(%& -.got)  (expect !>(|))
  ;:  weld
    (expect-eq !>(t0) !>(at.p.got))
    (expect-eq !>(100) !>(conf.p.got))
    (expect-eq !>(`json`~) !>(value.p.got))
  ==
++  test-de-obs-refusals
  =/  bad
    |=  t=@t
    ^-  @t
    =/  got  (de-obs:orr (jo t) t0 'http')
    ?:(?=(%| -.got) p.got 'accepted')
  ;:  weld
    (expect-eq !>('subject: expected <kind>/<slug>') !>((bad '{"subject":"subaru","attr":"a","value":1,"source":{"kind":"user"}}')))
    (expect-eq !>('attr: lowercase, digits and hyphens, at most 48 bytes') !>((bad '{"subject":"thing/subaru","attr":"Location","value":1,"source":{"kind":"user"}}')))
    (expect-eq !>('value: required') !>((bad '{"subject":"thing/subaru","attr":"location","source":{"kind":"user"}}')))
    (expect-eq !>('value: a string, number, boolean, null or object, at most 2000 bytes') !>((bad '{"subject":"thing/subaru","attr":"location","value":[1],"source":{"kind":"user"}}')))
    (expect-eq !>('value.ref: expected <kind>/<slug>') !>((bad '{"subject":"thing/subaru","attr":"location","value":{"ref":"nowhere"},"source":{"kind":"user"}}')))
    (expect-eq !>('at: expected an ISO 8601 UTC time such as 2026-09-16T22:05:00Z') !>((bad '{"subject":"thing/subaru","attr":"location","value":1,"at":"yesterday","source":{"kind":"user"}}')))
    (expect-eq !>('conf: 0 to 100') !>((bad '{"subject":"thing/subaru","attr":"location","value":1,"conf":101,"source":{"kind":"user"}}')))
    (expect-eq !>('conf: 0 to 100') !>((bad '{"subject":"thing/subaru","attr":"location","value":1,"conf":-5,"source":{"kind":"user"}}')))
    (expect-eq !>('conf: 0 to 100') !>((bad '{"subject":"thing/subaru","attr":"location","value":1,"conf":"high","source":{"kind":"user"}}')))
    (expect-eq !>('source.kind: required') !>((bad '{"subject":"thing/subaru","attr":"location","value":1}')))
    (expect-eq !>('until: must be after at') !>((bad '{"subject":"thing/subaru","attr":"location","value":1,"at":"2026-09-16T22:05:00Z","until":"2026-09-16T22:05:00Z","source":{"kind":"user"}}')))
    (expect-eq !>('until: must be after at') !>((bad '{"subject":"thing/subaru","attr":"location","value":1,"at":"2026-09-16T22:05:00Z","until":"2026-09-16T21:00:00Z","source":{"kind":"user"}}')))
  ==
::  a fact stated with no source, through the MCP tool, a key or the
::  owner's own request, is the user's, its id who wrote it, and decodes;
::  a source named stands, and one with an id but no kind keeps the id
::
++  test-fill-obs-source
  =/  bare=json  (jo '{"subject":"thing/subaru","attr":"location","value":"the shop"}')
  =/  f=json  (fill-obs:orr bare t0 'mcp')
  =/  k=json  (fill-obs-as:orr bare t0 'talon')
  =/  named=json  (jo '{"subject":"thing/subaru","attr":"location","value":1,"source":{"kind":"chat","id":"m1"}}')
  =/  idonly=json  (jo '{"subject":"thing/subaru","attr":"location","value":1,"source":{"id":"m9"}}')
  =/  df  (de-obs:orr f t0 'mcp')
  =/  dk  (de-obs:orr k t0 'talon')
  ;:  weld
    (expect-eq !>((jo '{"kind":"user","id":"mcp"}')) !>((gj:orr f 'source')))
    (expect-eq !>((jo '{"kind":"user","id":"talon"}')) !>((gj:orr k 'source')))
    (expect !>(?=(%& -.df)))
    (expect !>(?=(%& -.dk)))
    (expect-eq !>((jo '{"kind":"chat","id":"m1"}')) !>((gj:orr (fill-obs:orr named t0 'mcp') 'source')))
    (expect-eq !>((jo '{"kind":"user","id":"m9"}')) !>((gj:orr (fill-obs:orr idonly t0 'mcp') 'source')))
  ==
::  the calendar's zone is taken for home only when none is set and the
::  ship can render it
::
++  test-cal-zone-seed
  ;:  weld
    (expect-eq !>(`(unit @t)``'America/New_York') !>((cal-zone-seed:orr '' (jo '{"zone":"America/New_York","events":[]}'))))
    (expect-eq !>(`(unit @t)`~) !>((cal-zone-seed:orr 'Europe/Madrid' (jo '{"zone":"America/New_York"}'))))
    (expect-eq !>(`(unit @t)`~) !>((cal-zone-seed:orr '' (jo '{"zone":null}'))))
    (expect-eq !>(`(unit @t)`~) !>((cal-zone-seed:orr '' (jo '{"zone":"Mars/Olympus"}'))))
  ==
++  test-de-action-ok
  =/  got
    %^  de-action:orr
      (jo '{"kind":"task","title":"Call John\'s Machine Shop about the Subaru","about":["thing/subaru","place/johns-machine-shop"],"due":"2026-09-17T13:00:00Z","proposed":"2026-09-17T03:00:00Z"}')
    t0  'mcp'
  ?.  ?=(%& -.got)  (expect !>(|))
  ;:  weld
    (expect-eq !>(%task) !>(kind.p.got))
    (expect-eq !>(`(set @t)`(sy ~['thing/subaru' 'place/johns-machine-shop'])) !>(about.p.got))
    (expect-eq !>(`(unit @da)`[~ ~2026.9.17..13.00.00]) !>(due.p.got))
    (expect-eq !>(~2026.9.17..3.00.00) !>(proposed.p.got))
    (expect-eq !>(%proposed) !>(status.p.got))
    (expect-eq !>('mcp') !>(by.p.got))
    (expect-eq !>(`json`~) !>(payload.p.got))
    (expect-eq !>(`(list step:orr)`~[[~2026.9.17..3.00.00 %proposed 'mcp']]) !>(history.p.got))
  ==
++  test-de-action-refusals
  =/  bad
    |=  t=@t
    ^-  @t
    =/  got  (de-action:orr (jo t) t0 'mcp')
    ?:(?=(%| -.got) p.got 'accepted')
  ;:  weld
    (expect-eq !>('title: 1 to 200 bytes') !>((bad '{"kind":"task"}')))
    (expect-eq !>('kind: lowercase, digits and hyphens, at most 24 bytes') !>((bad '{"kind":"Task","title":"x"}')))
    (expect-eq !>('about: expected <kind>/<slug> entries') !>((bad '{"kind":"task","title":"x","about":["subaru"]}')))
    (expect-eq !>('payload: an object, or absent') !>((bad '{"kind":"task","title":"x","payload":"notes"}')))
  ==
++  test-fill-defaults
  =/  j=json  (fill-obs:orr (jo '{"subject":"person/me","attr":"status","value":1}') t0 'http')
  =/  k=json  (fill-act:orr (jo '{"kind":"task","title":"x","by":"user"}') t0 'http')
  =/  by-of
    |=  j=json
    ^-  @t
    (gs:orr j 'by')
  =/  long=@t  (big 65)
  =/  kept=json
    %^  fill-act:orr
      (pairs:enjs:format ~[['kind' s+'task'] ['title' s+'x'] ['by' s+long]])
    t0  'http'
  ;:  weld
    (expect-eq !>('2026-09-16T22:05:00Z') !>((gs:orr j 'at')))
    (expect-eq !>('http') !>((gs:orr j 'by')))
    (expect-eq !>('keep') !>((gs:orr (fill-obs:orr (jo '{"at":"keep"}') t0 'http') 'at')))
    (expect-eq !>('2026-09-16T22:05:00Z') !>((gs:orr k 'proposed')))
    (expect-eq !>('user') !>((gs:orr k 'by')))
    (expect-eq !>('http') !>((by-of (fill-obs:orr (jo '{"subject":"person/me","attr":"status","value":1,"by":""}') t0 'http'))))
    (expect-eq !>('http') !>((by-of (fill-obs:orr (jo '{"subject":"person/me","attr":"status","value":1,"by":5}') t0 'http'))))
    (expect-eq !>('http') !>((by-of (fill-act:orr (jo '{"kind":"task","title":"x","by":""}') t0 'http'))))
    (expect-eq !>('http') !>((by-of (fill-act:orr (jo '{"kind":"task","title":"x","by":5}') t0 'http'))))
    (expect-eq !>(long) !>((by-of kept)))
  ==
++  test-prep-observe
  =/  got
    %^  prep-observe:orr
      (jo '{"bodies":[{"id":"place/home"},{"id":"bad"}],"observations":[{"subject":"person/me","attr":"home","value":{"ref":"place/home"},"source":{"kind":"user"}}]}')
    t0  'http'
  ;:  weld
    (expect-eq !>(2) !>((lent bodies.got)))
    (expect-eq !>(1) !>((lent obs.got)))
    (expect !>(?=([%& *] (snag 0 bodies.got))))
    (expect !>(?=([%| *] (snag 1 bodies.got))))
    (expect !>(?=([%& *] (snag 0 obs.got))))
  ==
::  ==  readers and merge
::
++  test-readers
  =/  b=body:orr  [%person 'Sarah' (sy ~['Sarah']) t0 ~]
  ;:  weld
    (expect-eq !>(`(unit body:orr)`[~ b]) !>((read-body:orr [%2 b])))
    (expect-eq !>(`(unit body:orr)`~) !>((read-body:orr [%3 'nope'])))
    (expect-eq !>(`(unit obs:orr)`[~ o1]) !>((read-obs:orr [%1 o1])))
    (expect-eq !>(`(unit obs:orr)`~) !>((read-obs:orr 'garbage')))
  ==
++  test-merge-body
  =/  old=body:orr  [%person 'Sarah' (sy ~['Sarah']) t0 ~]
  =/  new=body:orr  [%person '' (sy ~['wife']) (add t0 ~d1) ~]
  =/  got=body:orr  (merge-body:orr old new)
  ;:  weld
    (expect-eq !>('Sarah') !>(name.got))
    (expect-eq !>(`(set @t)`(sy ~['Sarah' 'wife'])) !>(aliases.got))
    (expect-eq !>(t0) !>(created.got))
    (expect-eq !>('Sarah B') !>(name:(merge-body:orr old new(name 'Sarah B'))))
    (expect-eq !>(`(unit @p)`[~ ~sampel-palnet]) !>(ship:(merge-body:orr old new(ship `~sampel-palnet))))
    (expect-eq !>(`(unit @p)`[~ ~sampel-palnet]) !>(ship:(merge-body:orr old(ship `~sampel-palnet) new)))
    (expect-eq !>('sarah') !>((fresh-name:orr %sarah '')))
    (expect-eq !>('Sarah') !>((fresh-name:orr %sarah 'Sarah')))
  ==
::  ==  the fold
::
++  r  |=([id=@ta o=obs:orr] ^-(row:orr [id o]))
++  mk
  |=  [attr=@t v=json at=@da]
  ^-  obs:orr
  ['thing/subaru' attr v at ~ 90 ['user' ''] 'user' at | '']
::  event time wins over arrival time: a tow receipt that arrives late
::  and speaks of an earlier moment cannot overwrite the present
++  test-fold-latest-at-wins
  =/  a  (r 'a' (mk 'location' s+'Route 9' t0))
  =/  b  (r 'b' (mk 'location' s+'shop' (add t0 ~h4)))
  =/  c  (r 'c' (mk 'location' s+'tow truck' (add t0 ~h1)))
  =.  seen.obs.c  (add t0 ~h6)
  =/  w  (fold:orr ~[a b c] ~ (add t0 ~d1))
  =/  loc=(list row:orr)  (fall (~(get by w) 'location') ~)
  ;:  weld
    (expect-eq !>(1) !>((lent loc)))
    (expect-eq !>('b') !>(?~(loc '' id.i.loc)))
  ==
++  test-fold-as-of
  =/  a  (r 'a' (mk 'location' s+'Route 9' t0))
  =/  b  (r 'b' (mk 'location' s+'shop' (add t0 ~h4)))
  =/  w  (fold:orr ~[a b] ~ (add t0 ~h1))
  =/  loc=(list row:orr)  (fall (~(get by w) 'location') ~)
  (expect-eq !>('a') !>(?~(loc '' id.i.loc)))
++  test-fold-until-expires
  =/  o=obs:orr  (mk 'status' s+'stranded' t0)
  =.  until.o  `(add t0 ~h4)
  ;:  weld
    (expect-eq !>(1) !>(~(wyt by (fold:orr ~[(r 'a' o)] ~ (add t0 ~h1)))))
    (expect-eq !>(0) !>(~(wyt by (fold:orr ~[(r 'a' o)] ~ (add t0 ~h5)))))
  ==
::  compaction keeps the row a retracted winner falls back to
++  test-fallback-ids
  =/  a  (r 'a' (mk 'location' s+'Route 9' t0))
  =/  b  (r 'b' (mk 'location' s+'tow truck' (add t0 ~h1)))
  =/  c  (r 'c' (mk 'location' s+'shop' (add t0 ~h4)))
  (expect-eq !>((sy `(list @ta)`~['b'])) !>((fallback-ids:orr ~[a b c] ~ (add t0 ~d1))))
::  a null value wins its slot and clears it; a retracted row is ignored
++  test-fold-retracted-and-null
  =/  a  (r 'a' (mk 'status' s+'stranded' t0))
  =/  b  (r 'b' (mk 'status' ~ (add t0 ~h4)))
  =/  c  (r 'c' (mk 'status' s+'home' (add t0 ~h5)))
  =.  retracted.obs.c  &
  =/  w  (fold:orr ~[a b c] ~ (add t0 ~d1))
  =/  st=(list row:orr)  (fall (~(get by w) 'status') ~)
  ;:  weld
    (expect-eq !>('b') !>(?~(st '' id.i.st)))
    (expect-eq !>(`json`~) !>(?~(st `json`~ value.obs.i.st)))
  ==
++  test-fold-multi
  =/  multi=(set @t)  (sy ~['participants'])
  =/  a  (r 'a' (mk 'participants' (jo '{"ref":"person/me"}') t0))
  =/  b  (r 'b' (mk 'participants' (jo '{"ref":"person/sarah"}') (add t0 ~m1)))
  =/  c  (r 'c' (mk 'participants' (jo '{"ref":"person/me"}') (add t0 ~m2)))
  =/  w  (fold:orr ~[a b c] multi (add t0 ~d1))
  =/  ps=(list row:orr)  (fall (~(get by w) 'participants') ~)
  ;:  weld
    (expect-eq !>(2) !>((lent ps)))
    (expect !>((lien ps |=(x=row:orr =('c' id.x)))))
    (expect !>(!(lien ps |=(x=row:orr =('a' id.x)))))
  ==
++  test-status-and-timeline
  =/  a  (r 'a' (mk 'location' s+'Route 9' t0))
  =/  b  (r 'b' (mk 'location' s+'shop' (add t0 ~h4)))
  =/  c  (r 'c' (mk 'status' s+'stranded' t0))
  =.  until.obs.c  `(add t0 ~h2)
  =/  d  (r 'd' (mk 'mood' s+'grim' t0))
  =.  retracted.obs.d  &
  =/  when  (add t0 ~d1)
  ::  e speaks of a moment after when: future, and it never wins the fold
  =/  e  (r 'e' (mk 'location' s+'garage' (add when ~d1)))
  =/  w  (fold:orr ~[a b c d e] ~ when)
  =/  tl  (timeline:orr ~[a b c d e] w when)
  =/  st
    |=  id=@ta
    ^-  @tas
    =/  f  (skim tl |=(x=[r=row:orr status=@tas] =(id id.r.x)))
    ?~(f %none status.i.f)
  ;:  weld
    (expect-eq !>(%superseded) !>((st 'a')))
    (expect-eq !>(%live) !>((st 'b')))
    (expect-eq !>(%expired) !>((st 'c')))
    (expect-eq !>(%retracted) !>((st 'd')))
    (expect-eq !>(%future) !>((st 'e')))
    (expect-eq !>('e') !>(?~(tl '' id.r.i.tl)))
  ==
::  ==  involved and resolve
::
++  test-involved
  =/  multi=(set @t)  (sy ~['participants'])
  =/  sit-open
    %-  fold:orr
    :+  ~[(r 'a' (mk 'participants' (jo '{"ref":"person/sarah"}') t0)) (r 'b' (mk 'status' s+'open' t0))]
      multi
    (add t0 ~d1)
  =/  sit-closed
    %-  fold:orr
    :+  ~[(r 'c' (mk 'participants' (jo '{"ref":"person/sarah"}') t0)) (r 'd' (mk 'status' s+'closed' t0))]
      multi
    (add t0 ~d1)
  =/  sits=(list [id=bid:orr winners=(map @t (list row:orr))])
    ~[['situation/one' sit-open] ['situation/two' sit-closed]]
  ;:  weld
    (expect-eq !>(`(list bid:orr)`~['situation/one']) !>((involved:orr 'person/sarah' sits)))
    (expect-eq !>(`(list bid:orr)`~) !>((involved:orr 'person/me' sits)))
  ==
::  +none, +wn: a body with nothing folded, and one whose winners hold
::  an attribute with the given values, the shape resolve takes
::
++  none  *(map @t (list row:orr))
++  wn
  |=  [attr=@t vs=(list @t)]
  ^-  (map @t (list row:orr))
  %-  ~(gas by *(map @t (list row:orr)))
  ~[[attr (turn vs |=(v=@t ^-(row:orr (r 'x' (mk attr s+v t0)))))]]
::  +marks: each hit as its body and how it matched
::
++  marks
  |=  hits=(list [id=bid:orr =body:orr match=@tas])
  ^-  (list [id=bid:orr match=@tas])
  (turn hits |=(h=[id=bid:orr =body:orr match=@tas] ^-([id=bid:orr match=@tas] [id.h match.h])))
++  test-resolve
  =/  bodies=(list [id=bid:orr =body:orr winners=(map @t (list row:orr))])
    :~  ['person/sarah' [%person 'Sarah' (sy ~['wife']) t0 `~sampel-palnet] none]
        ['place/johns-machine-shop' [%place 'John\'s Machine Shop' (sy ~['John\'s' 'the shop']) t0 ~] none]
        ['thing/subaru' [%thing 'The Subaru' (sy ~['the car']) t0 ~] none]
    ==
  =/  ids
    |=  q=@t
    ^-  (list bid:orr)
    (turn (resolve:orr q bodies) |=(h=[id=bid:orr =body:orr match=@tas] id.h))
  ;:  weld
    (expect-eq !>(`(list bid:orr)`~['person/sarah']) !>((ids 'sarah')))
    (expect-eq !>(`(list bid:orr)`~['person/sarah']) !>((ids 'WIFE')))
    (expect-eq !>(`(list bid:orr)`~['place/johns-machine-shop']) !>((ids 'john\'s')))
    (expect-eq !>(`(list bid:orr)`~['thing/subaru']) !>((ids 'the c')))
    (expect-eq !>(`(list bid:orr)`~['person/sarah']) !>((ids '~sampel-palnet')))
    (expect-eq !>(`(list bid:orr)`~) !>((ids 'zzz')))
    (expect-eq !>(`(list bid:orr)`~) !>((ids '')))
  ==
::  an address or a number is an identity: a query equal to one is an
::  exact hit, whether the attribute is single or multi valued
::
++  test-resolve-identity
  =/  bodies=(list [id=bid:orr =body:orr winners=(map @t (list row:orr))])
    :~  ['person/alice' [%person 'Alice' ~ t0 ~] (wn 'email' ~['Alice.Baker@example.com'])]
        ['person/bo' [%person 'Bo' ~ t0 ~] (wn 'phone' ~['+1 555 0100' '+1 555 0199'])]
        ['person/cy' [%person 'Cy' ~ t0 ~] none]
    ==
  =/  hits  |=(q=@t ^-((list [id=bid:orr match=@tas]) (marks (resolve:orr q bodies))))
  ;:  weld
    (expect-eq !>(`(list [id=bid:orr match=@tas])`~[['person/alice' %exact]]) !>((hits 'ALICE.baker@example.com')))
    (expect-eq !>(`(list [id=bid:orr match=@tas])`~[['person/bo' %exact]]) !>((hits '+1 555 0100')))
    (expect-eq !>(`(list [id=bid:orr match=@tas])`~[['person/bo' %exact]]) !>((hits '+1 555 0199')))
    (expect-eq !>(`(list [id=bid:orr match=@tas])`~) !>((hits 'nobody@example.com')))
  ==
::  a token hit: every word of the shorter side is in the longer, in
::  either direction; a near miss is no hit; exact, then token, then
::  prefix
::
++  test-resolve-tokens
  =/  bodies=(list [id=bid:orr =body:orr winners=(map @t (list row:orr))])
    :~  ['person/alice' [%person 'Alice' ~ t0 ~] none]
        ['org/alice-baker' [%org 'Alice Baker' ~ t0 ~] none]
        ['person/andrew' [%person 'Alicia Baker' ~ t0 ~] none]
        ['person/alicesson' [%person 'Alicesson' ~ t0 ~] none]
    ==
  =/  hits  |=(q=@t ^-((list [id=bid:orr match=@tas]) (marks (resolve:orr q bodies))))
  =/  one=(list [id=bid:orr match=@tas])
    ~[['person/alice' %exact] ['org/alice-baker' %token] ['person/alicesson' %prefix]]
  =/  two=(list [id=bid:orr match=@tas])
    ~[['org/alice-baker' %exact] ['person/alice' %token]]
  ;:  weld
    (expect-eq !>(one) !>((hits 'alice')))
    (expect-eq !>(two) !>((hits 'Alice Baker')))
    (expect-eq !>(`(list [id=bid:orr match=@tas])`~) !>((hits 'baker alicias')))
  ==
::  ==  merge: the pure parts
::
::  +resubject keeps everything but the subject and the id
::
++  test-resubject
  =/  o=obs:orr  (mk 'status' s+'open' t0)
  =/  old=row:orr  (r (obs-id:orr o) o)
  =/  new=row:orr  (resubject:orr old 'person/sarah')
  ;:  weld
    (expect-eq !>('person/sarah') !>(subject.obs.new))
    (expect-eq !>((obs-id:orr obs.new)) !>(id.new))
    (expect !>(!=(id.old id.new)))
    (expect-eq !>(obs.old(subject 'person/sarah')) !>(obs.new))
  ==
::  +absorb unions the aliases and takes from's name as one more, and
::  keeps into's name, ship and created
::
++  test-absorb
  =/  into=body:orr  [%person 'Alice' (sy ~['Andy']) t0 `~sampel-palnet]
  =/  gone=body:orr  [%org 'Alice Baker' (sy ~['AE']) (add t0 ~d1) ~]
  =/  got=body:orr  (absorb:orr into gone)
  ;:  weld
    (expect-eq !>('Alice') !>(name.got))
    (expect-eq !>(`(unit @p)`[~ ~sampel-palnet]) !>(ship.got))
    (expect-eq !>(t0) !>(created.got))
    (expect-eq !>((sy `(list @t)`~['Andy' 'AE' 'Alice Baker'])) !>(aliases.got))
    ::  into with no ship keeps from's
    (expect-eq !>(`(unit @p)`[~ ~zod]) !>(ship:(absorb:orr into(ship ~) gone(ship `~zod))))
  ==
::  ==  actions, policy, encoders
::
++  test-action-rules
  =/  auto  (auto-of:orr starter-policy:orr)
  ;:  weld
    (expect !>((transition-ok:orr %proposed %approved)))
    (expect !>((transition-ok:orr %approved %done)))
    (expect !>(!(transition-ok:orr %proposed %done)))
    (expect !>(!(transition-ok:orr %done %approved)))
    (expect-eq !>(%approved) !>((initial-status:orr %task auto)))
    (expect-eq !>(%proposed) !>((initial-status:orr %message auto)))
    (expect-eq !>(365) !>((retention-of:orr starter-policy:orr)))
    (expect-eq !>('proposed') !>((push-mode-of:orr starter-policy:orr)))
    (expect !>((~(has in (multi-of:orr starter-schema:orr)) 'participants')))
  ==
::  +held: an action with a status and the history that led to it
::
++  held
  |=  [status=@tas history=(list step:orr)]
  ^-  action:orr
  [%message 'tell sarah' ~ ~ ~ 'mcp' t0 status '' history]
++  test-claim-transitions
  =/  open=action:orr  (held %claimed ~[[t0 %proposed 'mcp'] [(add t0 ~m1) %claimed 'exec-a']])
  =/  shut=action:orr  (held %done ~[[t0 %proposed 'mcp'] [(add t0 ~m1) %claimed 'exec-a'] [(add t0 ~m2) %done 'exec-a']])
  ;:  weld
    (expect !>((transition-ok:orr %approved %claimed)))
    (expect !>((transition-ok:orr %claimed %done)))
    (expect !>((transition-ok:orr %claimed %failed)))
    (expect !>((transition-ok:orr %claimed %dismissed)))
    (expect !>((transition-ok:orr %claimed %claimed)))
    (expect !>(!(transition-ok:orr %claimed %approved)))
    (expect !>(!(transition-ok:orr %proposed %claimed)))
    (expect !>(!(transition-ok:orr %done %claimed)))
    (expect !>((is-open:orr open)))
    (expect !>(!(is-open:orr shut)))
  ==
++  test-claimant
  =/  twice=action:orr
    %+  held  %claimed
    :~  [t0 %proposed 'mcp']
        [(add t0 ~s1) %approved 'user']
        [(add t0 ~m1) %claimed 'exec-a']
        [(add t0 ~m20) %claimed 'exec-b']
    ==
  =/  never=action:orr  (held %approved ~[[t0 %proposed 'mcp'] [(add t0 ~s1) %approved 'user']])
  ;:  weld
    (expect-eq !>('exec-b') !>((claimant:orr twice)))
    (expect-eq !>(`@da`(add t0 ~m20)) !>((claimed-at:orr twice)))
    (expect-eq !>('') !>((claimant:orr never)))
    (expect-eq !>(t0) !>((claimed-at:orr never)))
  ==
++  test-move-refusal
  =/  at=@da  (add t0 ~m1)
  =/  soon=@da  (add at ~m1)
  =/  late=@da  (add at ~m11)
  =/  mine=action:orr  (held %claimed ~[[t0 %proposed 'mcp'] [at %claimed 'exec-a']])
  ;:  weld
    (expect-eq !>(`(unit @t)`[~ 'claimed by exec-a']) !>((move-refusal:orr mine %claimed 'exec-b' soon)))
    (expect-eq !>(`(unit @t)`~) !>((move-refusal:orr mine %claimed 'exec-b' late)))
    (expect-eq !>(`(unit @t)`[~ 'claimed by exec-a']) !>((move-refusal:orr mine %done 'user' soon)))
    (expect-eq !>(`(unit @t)`[~ 'claimed by exec-a']) !>((move-refusal:orr mine %failed 'exec-b' soon)))
    (expect-eq !>(`(unit @t)`~) !>((move-refusal:orr mine %done 'exec-a' soon)))
    (expect-eq !>(`(unit @t)`~) !>((move-refusal:orr mine %dismissed 'user' soon)))
    (expect-eq !>(`(unit @t)`[~ 'claimed by exec-a']) !>((move-refusal:orr mine %claimed 'exec-b' t0)))
    (expect-eq !>(`(unit @t)`[~ 'cannot go from claimed to approved']) !>((move-refusal:orr mine %approved 'user' soon)))
    (expect-eq !>(`(unit @t)`~) !>((move-refusal:orr (held %approved ~[[t0 %proposed 'mcp']]) %claimed 'exec-a' soon)))
    ::  once the lease is out, anyone may close a claim left unfinished (version 86)
    (expect-eq !>(`(unit @t)`~) !>((move-refusal:orr mine %done 'user' late)))
    (expect-eq !>(`(unit @t)`~) !>((move-refusal:orr mine %failed 'exec-b' late)))
    ::  a stale claim is the ship's own, its lease out
    =/  ships=action:orr  (held %claimed ~[[t0 %proposed 'mcp'] [at %claimed 'ship']])
    (expect-eq !>([| & |]) !>([(stale-claim:orr ships soon) (stale-claim:orr ships late) (stale-claim:orr mine late)]))
  ==
++  test-encoders-roundtrip
  =/  j=json  (en-obs:orr (r 'x' o1) %live)
  =/  back  (de-obs:orr j t0 'http')
  ?.  ?=(%& -.back)  (expect !>(|))
  ;:  weld
    (expect-eq !>(subject:o1) !>(subject.p.back))
    (expect-eq !>(value:o1) !>(value.p.back))
    (expect-eq !>(at:o1) !>(at.p.back))
    (expect-eq !>('live') !>((gs:orr j 'status')))
    (expect-eq !>('Sarah') !>((gs:orr (en-body:orr 'person/sarah' [%person 'Sarah' ~ t0 ~]) 'name')))
  ==
::  ==  amendments: ship, history, push modes, the ring
::
++  test-de-body-ship
  =/  got  (de-body:orr (jo '{"id":"person/sarah","ship":"~sampel-palnet"}') t0)
  =/  bad  (de-body:orr (jo '{"id":"person/sarah","ship":"sarah"}') t0)
  ;:  weld
    (expect-eq !>(`(unit @p)`[~ ~sampel-palnet]) !>(?:(?=(%& -.got) ship.body.p.got ~)))
    (expect-eq !>('ship: expected an @p such as ~sampel-palnet') !>(?:(?=(%| -.bad) p.bad 'accepted')))
  ==
++  test-de-obs-self-ref
  =/  got  (de-obs:orr (jo '{"subject":"thing/subaru","attr":"location","value":{"ref":"thing/subaru"},"source":{"kind":"user"}}') t0 'http')
  (expect-eq !>('value.ref: a body cannot refer to itself') !>(?:(?=(%| -.got) p.got 'accepted')))
++  test-transition
  =/  a=action:orr  [%task 'x' ~ ~ ~ 'mcp' t0 %proposed '' ~[[t0 %proposed 'mcp']]]
  =/  b=action:orr  (transition:orr a %approved 'policy' '' (add t0 ~s1))
  =/  c=action:orr  (transition:orr b %done 'user' 'called them' (add t0 ~h1))
  ;:  weld
    (expect-eq !>(%approved) !>(status.b))
    (expect-eq !>(2) !>((lent history.b)))
    (expect-eq !>(`step:orr`[(add t0 ~h1) %done 'user']) !>((rear history.c)))
    (expect-eq !>('called them') !>(note.c))
    (expect-eq !>(3) !>((lent history.c)))
  ==
++  test-push-modes
  ;:  weld
    (expect-eq !>('none') !>((push-mode-of:orr (jo '{"push":"none"}'))))
    (expect !>((should-push:orr 'all' %approved)))
    (expect !>((should-push:orr 'proposed' %proposed)))
    (expect !>(!(should-push:orr 'proposed' %approved)))
    (expect !>(!(should-push:orr 'none' %proposed)))
    (expect !>((should-push:orr 'bogus' %proposed)))
    (expect !>(!(should-push:orr 'bogus' %approved)))
  ==
++  test-ring
  =/  one=json  (ring:orr [%a ~] (jo '{"n":1}') 2)
  =/  two=json  (ring:orr one (jo '{"n":2}') 2)
  =/  three=json  (ring:orr two (jo '{"n":3}') 2)
  =/  fresh=json  (ring:orr [%o ~] (jo '{"n":9}') 5)
  ;:  weld
    (expect-eq !>(1) !>((lent ?:(?=([%a *] one) p.one ~))))
    (expect-eq !>(2) !>((lent ?:(?=([%a *] three) p.three ~))))
    (expect-eq !>(`json`(jo '{"n":2}')) !>(?:(?=([%a *] three) (snag 0 p.three) ~)))
    (expect-eq !>(1) !>((lent ?:(?=([%a *] fresh) p.fresh ~))))
  ==
::  ==  the final review: caps, the seen tie-break, an id and an order
::
::  +big: a string of n bytes, for the over-cap cases
::
++  big  |=(n=@ud ^-(@t `@t`(fil 3 n 'a')))
++  test-caps-refused
  =/  bad-body
    |=  j=json
    ^-  @t
    =/  got  (de-body:orr j t0)
    ?:(?=(%| -.got) p.got 'accepted')
  =/  bad-obs
    |=  j=json
    ^-  @t
    =/  got  (de-obs:orr j t0 'http')
    ?:(?=(%| -.got) p.got 'accepted')
  =/  bad-act
    |=  j=json
    ^-  @t
    =/  got  (de-action:orr j t0 'mcp')
    ?:(?=(%| -.got) p.got 'accepted')
  =/  body-with
    |=  [k=@t v=json]
    ^-  json
    (pairs:enjs:format ~[['id' s+'person/x'] [k v]])
  =/  obs-with
    |=  [k=@t v=json]
    ^-  json
    %-  pairs:enjs:format
    :~  ['subject' s+'thing/subaru']
        ['attr' s+'location']
        ['value' s+'Route 9']
        ['source' (pairs:enjs:format ~[['kind' s+'user'] ['id' s+'m1']])]
        [k v]
    ==
  =/  act-with
    |=  [k=@t v=json]
    ^-  json
    (pairs:enjs:format ~[['kind' s+'task'] ['title' s+'x'] [k v]])
  ;:  weld
    (expect-eq !>('name: over 200 bytes') !>((bad-body (body-with 'name' s+(big 201)))))
    (expect-eq !>('aliases: over 32') !>((bad-body (body-with 'aliases' a+(reap 33 `json`s+'x')))))
    (expect-eq !>('aliases: each 1 to 100 bytes') !>((bad-body (body-with 'aliases' a+~[`json`s+(big 101)]))))
    (expect-eq !>('value: a string, number, boolean, null or object, at most 2000 bytes') !>((bad-obs (obs-with 'value' s+(big 2.001)))))
    (expect-eq !>('source.id: over 200 bytes') !>((bad-obs (obs-with 'source' (pairs:enjs:format ~[['kind' s+'user'] ['id' s+(big 201)]])))))
    (expect-eq !>('by: over 64 bytes') !>((bad-obs (obs-with 'by' s+(big 65)))))
    ::  each cap as a pair: exactly the cap is accepted
    (expect-eq !>('accepted') !>((bad-obs (obs-with 'source' (pairs:enjs:format ~[['kind' s+'user'] ['id' s+(big 200)]])))))
    (expect-eq !>('accepted') !>((bad-obs (obs-with 'by' s+(big 64)))))
    (expect-eq !>('title: 1 to 200 bytes') !>((bad-act (act-with 'title' s+(big 201)))))
    (expect-eq !>('payload: over 4000 bytes') !>((bad-act (act-with 'payload' (pairs:enjs:format ~[['x' s+(big 4.001)]])))))
    (expect-eq !>('about: over 20') !>((bad-act (act-with 'about' a+(reap 21 `json`s+'thing/subaru')))))
  ==
::  two rows claim the same moment: the one the ship saw later wins,
::  whichever order the fold reaches them in
::
++  test-fold-seen-tie-break
  =/  a  (r 'a' (mk 'location' s+'Route 9' t0))
  =/  b  (r 'b' (mk 'location' s+'shop' t0))
  =.  seen.obs.b  (add t0 ~h1)
  =/  won
    |=  rows=(list row:orr)
    ^-  @t
    =/  loc=(list row:orr)  (fall (~(get by (fold:orr rows ~ (add t0 ~d1))) 'location') ~)
    ?~(loc '' id.i.loc)
  ;:  weld
    (expect-eq !>('b') !>((won ~[a b])))
    (expect-eq !>('b') !>((won ~[b a])))
  ==
::  the request fiber hashes a proposal, the writer hashes the same
::  proposal with the policy's approval on it: one id
::
++  test-act-id-survives-transition
  =/  got
    %^  de-action:orr
      (jo '{"kind":"task","title":"Call the shop","by":"http","proposed":"2026-09-16T22:05:00Z"}')
    t0  'http'
  ?.  ?=(%& -.got)  (expect !>(|))
  =/  a=action:orr  p.got
  =/  b=action:orr  (transition:orr a %approved 'policy' '' (add t0 ~s1))
  ;:  weld
    (expect-eq !>((act-id:orr a)) !>((act-id:orr b)))
  ==
::  an exact hit outranks a prefix hit on another body
::
++  test-resolve-exact-before-prefix
  =/  bodies=(list [id=bid:orr =body:orr winners=(map @t (list row:orr))])
    :~  ['person/sammy' [%person 'Sammy' ~ t0 ~] none]
        ['person/sam' [%person 'Sam' ~ t0 ~] none]
    ==
  =/  hits  (resolve:orr 'sam' bodies)
  ;:  weld
    (expect-eq !>(`(list bid:orr)`~['person/sam' 'person/sammy']) !>((turn hits |=(h=[id=bid:orr =body:orr match=@tas] id.h))))
    (expect-eq !>(`(list @tas)`~[%exact %prefix]) !>((turn hits |=(h=[id=bid:orr =body:orr match=@tas] match.h))))
  ==
++  test-readers-lift
  =/  old-body  [%1 [%person 'Sarah' (sy ~['Sarah']) t0]]
  =/  old-act   [%1 [%task 'x' ~ ~ ~ 'mcp' t0 %approved '']]
  ;:  weld
    (expect-eq !>(`(unit body:orr)`[~ [%person 'Sarah' (sy ~['Sarah']) t0 ~]]) !>((read-body:orr old-body)))
    (expect-eq !>(`(unit (list step:orr))`[~ ~[[t0 %approved 'mcp']]]) !>((bind (read-action:orr old-act) |=(a=action:orr history.a))))
  ==
::  ==  sharing
::
++  test-share-helpers
  ;:  weld
    (expect-eq !>('~wex/person/sarah') !>((share-key:orr ~wex 'person/sarah')))
    (expect-eq !>('person/me') !>((mirror-target:orr ~feb ~wex `~feb 'person/sarah')))
    (expect-eq !>('person/sarah') !>((mirror-target:orr ~feb ~wex `~wex 'person/sarah')))
    (expect-eq !>('person/sarah') !>((mirror-target:orr ~feb ~wex ~ 'person/sarah')))
    (expect-eq !>('person/wex') !>((mirror-target:orr ~feb ~wex `~wex 'person/me')))
    (expect-eq !>('person/wex') !>((mirror-target:orr ~feb ~wex ~ 'person/me')))
    (expect-eq !>('person/ricsul-bilwyt') !>((mirror-target:orr ~feb ~ricsul-bilwyt `~ricsul-bilwyt 'person/me')))
    ::  the host's self lands named by its ship, not "me"
    (expect-eq !>('~wex') !>((landed-name:orr ~wex 'person/me' 'me')))
    (expect-eq !>('Sarah') !>((landed-name:orr ~wex 'person/sarah' 'Sarah')))
    (expect-eq !>('orrery-person.sarah') !>((group-name:orr %person %sarah)))
    ::  a dot cannot appear in a kind or a slug, so no two bodies share
    ::  a group name
    (expect-eq !>('orrery-per-son.me') !>((group-name:orr %per-son %me)))
    (expect-eq !>('orrery-per.son-me') !>((group-name:orr %per %son-me)))
  ==
::  a carried observation names the other side's body and carries the
::  sender's grub name; the receiver sets by and source from the ship
::  it heard it from, so a decode on the receiving side reads as the
::  sender's claim
++  test-carry-and-receive
  ::  o1 carries no until, so the row under test sets one: an until that
  ::  does not survive the trip would compare ~ with ~ and prove nothing
  =/  src=obs:orr  o1
  =/  r=row:orr  ['1789596300-abcdef01' src(until `(add t0 ~h2))]
  =/  carried=json  (carry-obs:orr 'person/me' r)
  ::  a sender that plants by and source changes nothing: the receiver
  ::  writes both from the transport it heard the row on
  =/  lies=json
    ?.  ?=([%o *] carried)  carried
    :-  %o
    %-  ~(gas by p.carried)
    :~  ['by' s+'liar']
        ['source' (pairs:enjs:format ~[['kind' s+'talon'] ['id' s+'m9']])]
    ==
  =/  j=json  (receive-obs:orr ~wex lies)
  =/  back  (de-obs:orr j t0 'x')
  ?.  ?=(%& -.back)  (expect !>(|))
  =/  base=obs:orr  o1
  =/  other=obs:orr  base(source ['ship' '~wexx/1'])
  ;:  weld
    (expect-eq !>('person/me') !>(subject.p.back))
    (expect-eq !>('~wex') !>(by.p.back))
    (expect-eq !>(`source:orr`['ship' '~wex/1789596300-abcdef01']) !>(source.p.back))
    (expect-eq !>(value:o1) !>(value.p.back))
    (expect-eq !>(at:o1) !>(at.p.back))
    (expect-eq !>(`(unit @da)`[~ (add t0 ~h2)]) !>(until.p.back))
    (expect-eq !>(90) !>(conf.p.back))
    (expect-eq !>(`json`~) !>((gj:orr carried 'by')))
    (expect-eq !>(`json`~) !>((gj:orr carried 'source')))
    (expect-eq !>(`json`b+|) !>((gj:orr j 'retracted')))
    (expect !>(!(is-local:orr p.back)))
    (expect !>((is-local:orr o1)))
    (expect !>((from-ship:orr p.back ~wex)))
    (expect !>(!(from-ship:orr p.back ~feb)))
    (expect !>(!(from-ship:orr o1 ~wex)))
    (expect !>(!(from-ship:orr other ~wex)))
    ::  a carried value that is not an object comes back untouched
    (expect-eq !>(`json`s+'not an object') !>((receive-obs:orr ~wex s+'not an object')))
  ==
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
  =/  many=json  (pairs:enjs:format ~[['kinds' a+(reap 25 `json`s+'person')]])
  =/  empty  (de-scope:orr [%o ~])
  ::  the sensitive leg: "write" needs write, anything else is "none",
  ::  and the codec round trips
  =/  sens=json
    %-  pairs:enjs:format
    :~  ['kinds' a+~[s+'person']]
        ['write' b+&]
        ['sensitive' s+'write']
    ==
  =/  got-sens  (de-scope:orr sens)
  =/  no-write  (de-scope:orr (pairs:enjs:format ~[['sensitive' s+'write']]))
  =/  odd  (de-scope:orr (pairs:enjs:format ~[['write' b+&] ['sensitive' s+'maybe']]))
  ;:  weld
    (expect !>(?=(%& -.got)))
    (expect-eq !>((sy ~['person' 'thing'])) !>(?:(?=(%& -.got) kinds.p.got ~)))
    (expect-eq !>((sy ~['task'])) !>(?:(?=(%& -.got) actions.p.got ~)))
    (expect-eq !>(&) !>(?:(?=(%& -.got) write.p.got |)))
    (expect-eq !>([%| 'scope.kinds: each a kind name']) !>(bad-kind))
    (expect-eq !>([%| 'scope.write: expected true or false']) !>(bad-write))
    (expect-eq !>([%| 'scope.kinds: over 24']) !>((de-scope:orr many)))
    (expect !>(?=(%& -.empty)))
    (expect-eq !>(|) !>(?:(?=(%& -.empty) write.p.empty &)))
    (expect-eq !>([%| 'scope: expected an object']) !>((de-scope:orr s+'x')))
    (expect !>((kind-in-scope:orr [(sy ~[%person]) ~ | |] %person)))
    (expect !>(!(kind-in-scope:orr [(sy ~[%person]) ~ | |] %place)))
    (expect !>((action-in-scope:orr [~ (sy ~[%task]) & |] %task)))
    (expect !>(!(action-in-scope:orr [~ (sy ~[%task]) & |] %note)))
    (expect-eq !>(&) !>(?:(?=(%& -.got-sens) sensitive.p.got-sens |)))
    (expect-eq !>([%| 'sensitive: write needs write']) !>(no-write))
    (expect-eq !>(|) !>(?:(?=(%& -.odd) sensitive.p.odd &)))
    (expect-eq !>(|) !>(?:(?=(%& -.empty) sensitive.p.empty &)))
    (expect-eq !>(|) !>(?:(?=(%& -.got) sensitive.p.got &)))
    (expect-eq !>(got-sens) !>((de-scope:orr (en-scope:orr [(sy ~[%person]) ~ & &]))))
    (expect-eq !>(empty) !>((de-scope:orr (en-scope:orr [~ ~ | |]))))
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
    (expect-eq !>(`['abc' 'def']) !>((parse-bearer:orr 'Bearer   abc.def')))
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
    (expect-eq !>(6) !>((met 3 (id-of:orr 1))))
    (expect-eq !>('000001') !>((id-of:orr 1)))
    (expect-eq !>(20) !>((met 3 (secret-of:orr 1))))
    (expect !>(!=((hash-token:orr 'salt' s) (hash-token:orr 'pepper' s))))
    (expect !>(!=((hash-token:orr 'salt' s) (hash-token:orr 'salt' 'other'))))
  ==
++  test-client-roundtrip
  =/  sc=scope:orr  [(sy ~[%person]) (sy ~[%task]) & |]
  =/  c=client:orr  ['abc' 'talon' 'talon' sc 'salt' (hash-token:orr 'salt' 'secret') t0 ~]
  =/  c2=client:orr  c(used `t0)
  =/  c3=client:orr  c(scope sc(sensitive &))
  =/  back=(unit client:orr)  (de-client:orr (en-client-row:orr c))
  =/  view=json  (en-client-view:orr c)
  ::  a row stored before version 13 has no sensitive field in its
  ::  scope: it reads as "none", never as a crash
  =/  old=json
    =/  row=json  (en-client-row:orr c)
    ?.  ?=([%o *] row)  row
    =/  sj=json  (gj:orr row 'scope')
    ?.  ?=([%o *] sj)  row
    [%o (~(put by p.row) 'scope' [%o (~(del by p.sj) 'sensitive')])]
  ;:  weld
    (expect-eq !>(`c) !>(back))
    (expect-eq !>(`c2) !>((de-client:orr (en-client-row:orr c2))))
    (expect-eq !>(`c3) !>((de-client:orr (en-client-row:orr c3))))
    (expect-eq !>(`c) !>((de-client:orr old)))
    (expect-eq !>(`json`s+'none') !>((gj:orr (en-scope:orr sc) 'sensitive')))
    (expect-eq !>(`json`s+'write') !>((gj:orr (en-scope:orr sc(sensitive &)) 'sensitive')))
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
  =/  sc=scope:orr  [(sy ~[%person]) ~ & |]
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
  =/  ref-obs
    |=  target=@t
    ^-  json
    =/  v=json  (pairs:enjs:format ~[['ref' s+target]])
    =/  one=json
      (pairs:enjs:format ~[['subject' s+'person/me'] ['attr' s+'home'] ['value' v]])
    (pairs:enjs:format ~[['observations' a+~[one]]])
  =/  wide=scope:orr  [(sy ~[%person %place]) ~ & |]
  =/  ship-body=json
    (pairs:enjs:format ~[['bodies' a+~[(pairs:enjs:format ~[['id' s+'person/sam'] ['ship' s+'~zod']])]]])
  ;:  weld
    (expect-eq !>(~) !>((out-of-scope:orr ok sc hide)))
    (expect-eq !>(`'place/home') !>((out-of-scope:orr bad-body sc hide)))
    (expect-eq !>(`'thing/car') !>((out-of-scope:orr bad-subject sc hide)))
    (expect-eq !>(`'health') !>((out-of-scope:orr bad-attr sc hide)))
    (expect-eq !>(~) !>((out-of-scope:orr unparsed sc hide)))
    (expect-eq !>(`'place/home') !>((out-of-scope:orr (ref-obs 'place/home') sc hide)))
    (expect-eq !>(~) !>((out-of-scope:orr (ref-obs 'place/home') wide hide)))
    (expect-eq !>(~) !>((out-of-scope:orr (ref-obs 'nope') sc hide)))
    (expect-eq !>(`'ship') !>((out-of-scope:orr ship-body sc hide)))
  ==
++  test-veil-refs-and-scope-about
  =/  base=obs:orr  o1
  =/  r-place=row:orr  ['1' base(value (pairs:enjs:format ~[['ref' s+'place/home']]))]
  =/  r-person=row:orr  ['2' base(value (pairs:enjs:format ~[['ref' s+'person/sarah']]))]
  =/  r-plain=row:orr  ['3' base]
  =/  r-nope=row:orr  ['4' base(value (pairs:enjs:format ~[['ref' s+'nope']]))]
  =/  r-thing=row:orr  ['5' base(value (pairs:enjs:format ~[['ref' s+'thing/subaru']]))]
  =/  kept=(list row:orr)  (veil-refs:orr ~[r-place r-person r-thing r-plain] (sy ~[%person]))
  =/  unparsed=(list row:orr)  (veil-refs:orr ~[r-nope] (sy ~[%person]))
  =/  a=action:orr
    [%task 'Call the shop' ~ (sy ~['thing/subaru' 'person/sarah']) ~ 'mcp' t0 %proposed '' ~]
  =/  trimmed=action:orr  (scope-about:orr a (sy ~[%person]))
  ;:  weld
    (expect-eq !>(~['veiled-0' '2' 'veiled-1' '3']) !>((turn kept |=(r=row:orr id.r))))
    (expect-eq !>(`json`~) !>(?~(kept ~ value.obs.i.kept)))
    (expect-eq !>('2') !>(id:(snag 1 `(list row:orr)`kept)))
    (expect-eq !>(`json`(pairs:enjs:format ~[['ref' s+'person/sarah']])) !>(value.obs:(snag 1 `(list row:orr)`kept)))
    (expect-eq !>(`json`~) !>(value.obs:(snag 2 `(list row:orr)`kept)))
    (expect-eq !>(`json`s+'Route 9') !>(value.obs:(snag 3 `(list row:orr)`kept)))
    (expect-eq !>(~['4']) !>((turn unparsed |=(r=row:orr id.r))))
    (expect-eq !>(`json`(pairs:enjs:format ~[['ref' s+'nope']])) !>(?~(unparsed ~ value.obs.i.unparsed)))
    (expect-eq !>(`json`(pairs:enjs:format ~[['ref' s+'place/home']])) !>(value.obs:(snag 0 (veil-refs:orr ~[r-place] (sy ~[%person %place])))))
    (expect-eq !>((sy ~['person/sarah'])) !>(about.trimmed))
    (expect-eq !>(~) !>(about:(scope-about:orr a ~)))
  ==
::  +test-scope-schema: a key sees its kinds, without the hidden
::  attribute names, and only the action kinds it may propose
::
++  test-scope-schema
  =/  base=json  starter-schema:orr
  =/  schema=json
    ?.  ?=([%o *] base)  base
    [%o (~(put by p.base) 'actions' a+~[s+'task' s+'note'])]
  =/  sc=scope:orr  [(sy ~[%person]) (sy ~[%task]) & |]
  ::  likes is both a person attr and a multi name: it pins that the
  ::  hidden names leave multi too, not only the attrs lists
  =/  hide=(set @t)  (sy ~['health' 'status' 'likes'])
  =/  out=json  (scope-schema:orr schema sc hide)
  =/  kinds=json  (gj:orr out 'kinds')
  =/  names=(list @t)  ?:(?=([%o *] kinds) (sort ~(tap in ~(key by p.kinds)) aor) ~)
  =/  attrs=(list @t)  (strings:orr (ga:orr (gj:orr kinds 'person') 'attrs'))
  =/  multi=(list @t)  (strings:orr (ga:orr out 'multi'))
  =/  acts=(list @t)  (strings:orr (ga:orr out 'actions'))
  ;:  weld
    (expect-eq !>(~['person']) !>(names))
    (expect !>(!(lien attrs |=(t=@t =('status' t)))))
    (expect !>((lien attrs |=(t=@t =('location' t)))))
    (expect !>((lien multi |=(t=@t =('participants' t)))))
    (expect !>(!(lien multi |=(t=@t =('likes' t)))))
    (expect !>(!(lien attrs |=(t=@t =('likes' t)))))
    (expect-eq !>(~['task']) !>(acts))
  ==
::  ==  the shared view encoders
::
++  test-state-and-body-json
  =/  base=obs:orr  o1
  =/  car=loaded:orr
    ['thing/subaru' [%thing 'the Subaru' (sy ~['the car']) t0 ~] ~[['1' base]]]
  =/  me=loaded:orr
    :+  'person/me'  [%person 'me' ~ t0 `~wex]
    ~[['2' base(subject 'person/me', attr 'spouse', value (pairs:enjs:format ~[['ref' s+'person/sarah']]))]]
  =/  sit=loaded:orr
    :+  'situation/2026-09-16-breakdown'  [%situation 'breakdown' ~ t0 ~]
    :~  ['3' base(subject 'situation/2026-09-16-breakdown', attr 'status', value s+'open')]
        ['4' base(subject 'situation/2026-09-16-breakdown', attr 'participants', value (pairs:enjs:format ~[['ref' s+'thing/subaru']]))]
    ==
  =/  shut=loaded:orr
    :+  'situation/2026-09-15-thaw'  [%situation 'thaw' ~ t0 ~]
    :~  ['5' base(subject 'situation/2026-09-15-thaw', attr 'status', value s+'closed')]
        ['6' base(subject 'situation/2026-09-15-thaw', attr 'participants', value (pairs:enjs:format ~[['ref' s+'thing/subaru']]))]
    ==
  =/  a=action:orr
    [%task 'Call the shop' ~ (sy ~['thing/subaru']) ~ 'mcp' t0 %approved '' ~]
  =/  shut-act=action:orr
    [%task 'Order the part' ~ (sy ~['thing/subaru']) ~ 'mcp' t0 %done '' ~]
  =/  acts=(list [id=@ta a=action:orr])  ~[['a1' a] ['a2' shut-act]]
  =/  all=(list loaded:orr)  ~[car me sit shut]
  =/  multi=(set @t)  (sy ~['participants'])
  =/  when=@da  (add t0 ~m1)
  =/  st=json  (state-json:orr all acts multi when '' (numb:enjs:format 7) [%o ~])
  =/  only-things=json  (state-json:orr all acts multi when 'thing' (numb:enjs:format 7) [%o ~])
  =/  no-kind=json  (state-json:orr all acts multi when 'nope' (numb:enjs:format 7) [%o ~])
  =/  bj=json  (body-json:orr car (situations:orr all multi when) acts multi when)
  =/  ids=(list json)  (turn (ga:orr st 'bodies') |=(j=json (gj:orr j 'id')))
  ;:  weld
    (expect-eq !>(4) !>((lent (ga:orr st 'bodies'))))
    (expect-eq !>(1) !>((lent (ga:orr only-things 'bodies'))))
    (expect-eq !>(0) !>((lent (ga:orr no-kind 'bodies'))))
    (expect !>((lien ids |=(j=json =(j `json`s+'situation/2026-09-15-thaw')))))
    (expect-eq !>(`json`a+~[(en-action:orr `@ta`'a1' a)]) !>((gj:orr st 'actions')))
    (expect-eq !>(`json`a+~[s+'situation/2026-09-16-breakdown']) !>((gj:orr st 'situations')))
    (expect-eq !>(1) !>((lent (ga:orr st 'actions'))))
    (expect-eq !>(`json`(numb:enjs:format 7)) !>((gj:orr st 'rev')))
    (expect-eq !>(`json`s+'thing/subaru') !>((gj:orr bj 'id')))
    (expect-eq !>(`json`s+'Route 9') !>((gj:orr (gj:orr (gj:orr bj 'attrs') 'location') 'value')))
    (expect-eq !>(`json`a+~[s+'situation/2026-09-16-breakdown']) !>((gj:orr bj 'involved')))
    (expect-eq !>(1) !>((lent (ga:orr bj 'actions'))))
    (expect-eq !>(1) !>((lent (ga:orr bj 'observations'))))
  ==
::  a cancelled situation is closed: it leaves the open list and every
::  involved list, like one the owner closed
++  test-is-closed-counts-cancelled
  =/  mk  |=(v=@t ^-((map @t (list row:orr)) (my ~[['status' ~[`row:orr`['x' ['s/x' 'status' s+v ~2026.9.18..12.00.00 ~ 100 ['test' 'fx'] 'test' ~2026.9.18..12.00.00 | '']]]]])))
  ;:  weld
    (expect !>((is-closed:orr (mk 'cancelled'))))
    (expect !>((is-closed:orr (mk 'closed'))))
    (expect !>(!(is-closed:orr (mk 'open'))))
  ==
::  the fencing clash: a weekly series whose winning next is a stale
::  reconcile row (an hour early, a day-long until) still yields a
::  pick-up appointment, at the end of the calendar's own occurrence
++  test-appointments-series-pick-from-calendar
  =/  fb  'activity/magnus-fencing-lesson'
  =/  ob
    |=  [attr=@t v=json src=@t at=@da un=(unit @da)]
    ^-  obs:orr
    [fb attr v at un 100 [src ''] src at | '']
  =/  now  ~2026.10.19..18.00.00
  =/  rows=(list row:orr)
    :~  (r 'rec' (ob 'next' s+'2026-10-19T20:00:00Z' 'reconcile' ~2026.10.13..02.21.55 [~ ~2026.10.20..20.00.00]))
        (r 'cal' (ob 'next' s+'2026-10-19T21:00:00Z' 'calendar' ~2026.10.12..21.00.00 [~ ~2026.10.19..22.00.00]))
        (r 'loc' (ob 'location' (jo '{"ref":"place/north-florida-fencing-club"}') 'owner' ~2026.10.7..19.31.15 ~))
        (r 'pik' (ob 'pick-up' (jo '{"ref":"person/me"}') 'owner' ~2026.10.7..19.31.15 ~))
        (r 'sts' (ob 'status' s+'active' 'reconcile' ~2026.8.24..21.00.00 ~))
    ==
  =/  lo=loaded:orr  [fb [%activity 'Magnus Fencing Lesson' ~ t0 ~] rows]
  =/  got=(list appointment:orr)
    (appointments-ahead:orr ~[lo] (sy ~['pick-up' 'drop-off']) now ~h8)
  ?.  ?=([* ~] got)  (expect-eq !>(1) !>((lent got)))
  =/  a=appointment:orr  i.got
  ;:  weld
    (expect-eq !>(%pick) !>(leg.a))
    (expect-eq !>(~2026.10.19..22.00.00) !>(starts.a))
    (expect-eq !>(`(unit @da)`[~ ~2026.10.19..22.00.00]) !>(ends.a))
    (expect-eq !>(`(unit bid:orr)`[~ 'place/north-florida-fencing-club']) !>(place.a))
  ==
::  a game to get to and a pick-up at the same time: the owner cannot do
::  both, so the game's leave-by is pinned by the pick-up. A pick-up
::  after the game starts does not pin it
++  test-pinned-until
  =/  game=appointment:orr
    ['situation/game' 'Game' ~2026.10.19..22.00.00 [~ ~2026.10.20..0.0.0] '' ~ %yes %go]
  =/  pick=appointment:orr
    ['activity/magnus-fencing-lesson' 'Fencing' ~2026.10.19..22.00.00 [~ ~2026.10.19..22.00.00] '' [~ 'place/x'] %yes %pick]
  =/  later-pick=appointment:orr
    pick(starts ~2026.10.19..23.00.00)
  =/  leave  ~2026.10.19..21.30.00
  =/  now  ~2026.10.19..21.00.00
  ;:  weld
    (expect-eq !>(`(unit @da)`[~ ~2026.10.19..22.00.00]) !>((pinned-until:orr game ~[game pick] leave now)))
    (expect-eq !>(`(unit @da)`~) !>((pinned-until:orr game ~[game later-pick] leave now)))
    (expect-eq !>(`(unit @da)`~) !>((pinned-until:orr game ~[game] leave now)))
  ==
::  the flight-status parser reads an AeroDataBox answer, and flight-change
::  tells the owner only when something notable moved
++  test-flight-status
  =/  body=json
    %-  jo
    '''
    [{"number":"DL 2627","status":"Expected","departure":{"airport":{"iata":"JAX"},"scheduledTime":{"utc":"2026-10-18 23:00Z","local":"x"},"revisedTime":{"utc":"2026-10-18 23:20Z"},"terminal":"S","gate":"C7"},"arrival":{"scheduledTime":{"utc":"2026-10-19 01:05Z"},"revisedTime":{"utc":"2026-10-19 01:30Z"},"gate":"B14"}}]
    '''
  =/  v=(unit flight-view:orr)  (flight-status:orr body '2026-10-18' '')
  ?~  v  (expect-eq !>('parsed') !>('none'))
  =/  delayed=flight-view:orr  u.v(status 'Delayed')
  ;:  weld
    (expect-eq !>('Expected') !>(status.u.v))
    (expect-eq !>('2026-10-18 23:20Z') !>(dep-revised.u.v))
    (expect-eq !>('C7') !>(dep-gate.u.v))
    (expect-eq !>('B14') !>(arr-gate.u.v))
    (expect-eq !>(`(unit @t)`~) !>((flight-change:orr u.v u.v)))
    (expect-eq !>(`(unit @t)`[~ 'status Delayed']) !>((flight-change:orr u.v delayed)))
  ==
::  a number's answer holds each leg it flies that day and the flight that
::  left the evening before: the watch takes the one leaving on its date,
::  from its airport (live AeroDataBox answers of 2026-10-18, trimmed)
++  test-flight-leg
  =/  dl2627=json
    %-  jo
    '''
    [{"status":"Expected","departure":{"airport":{"iata":"ATL"},"scheduledTime":{"utc":"2026-10-18 20:47Z","local":"2026-10-18 16:47-04:00"},"terminal":"S"},"arrival":{"airport":{"iata":"JAX"},"scheduledTime":{"utc":"2026-10-18 21:55Z","local":"2026-10-18 17:55-04:00"}}},{"status":"Expected","departure":{"airport":{"iata":"JAX"},"scheduledTime":{"utc":"2026-10-18 23:00Z","local":"2026-10-18 19:00-04:00"}},"arrival":{"airport":{"iata":"ATL"},"scheduledTime":{"utc":"2026-10-19 00:19Z","local":"2026-10-18 20:19-04:00"}}}]
    '''
  =/  dl194=json
    %-  jo
    '''
    [{"status":"Arrived","departure":{"airport":{"iata":"ATL"},"scheduledTime":{"utc":"2026-10-18 02:05Z","local":"2026-10-17 22:05-04:00"},"revisedTime":{"utc":"2026-10-18 02:25Z","local":"2026-10-17 22:25-04:00"},"terminal":"I"},"arrival":{"airport":{"iata":"BCN"},"scheduledTime":{"utc":"2026-10-18 10:50Z","local":"2026-10-18 12:50+02:00"}}},{"status":"Expected","departure":{"airport":{"iata":"ATL"},"scheduledTime":{"utc":"2026-10-19 02:05Z","local":"2026-10-18 22:05-04:00"},"terminal":"I"},"arrival":{"airport":{"iata":"BCN"},"scheduledTime":{"utc":"2026-10-19 10:50Z","local":"2026-10-19 12:50+02:00"}}}]
    '''
  =/  dep  |=(v=(unit flight-view:orr) ?~(v '' dep-sched.u.v))
  ;:  weld
    (expect-eq !>('2026-10-18 23:00Z') !>((dep (flight-status:orr dl2627 '2026-10-18' 'JAX'))))
    (expect-eq !>('2026-10-18 23:00Z') !>((dep (flight-status:orr dl2627 '2026-10-18' 'jax'))))
    (expect-eq !>('2026-10-18 20:47Z') !>((dep (flight-status:orr dl2627 '2026-10-18' ''))))
    (expect-eq !>(`(unit flight-view:orr)`~) !>((flight-status:orr dl2627 '2026-10-18' 'BCN')))
    (expect-eq !>('2026-10-19 02:05Z') !>((dep (flight-status:orr dl194 '2026-10-18' 'ATL'))))
    (expect-eq !>('2026-10-19 02:05Z') !>((dep (flight-status:orr dl194 '2026-10-18' ''))))
    ::  no flight leaves on the date: every flight is a candidate
    (expect-eq !>('2026-10-18 02:05Z') !>((dep (flight-status:orr dl194 '2026-10-20' ''))))
  ==
::  API.market takes the key in its own header; RapidAPI, the default,
::  with its host, which a config naming none still sends
++  test-flight-headers
  =/  am  (de-watch-config:orr (jo '{"url":"https://prod.api.market/api/v1/aedbx/aerodatabox","key":"k"}'))
  =/  ra  (de-watch-config:orr (jo '{"key":"k"}'))
  ;:  weld
    (expect-eq !>(~[['x-api-market-key' 'k'] ['accept' 'application/json']]) !>((flight-headers:orr am)))
    (expect-eq !>(~[['x-rapidapi-key' 'k'] ['x-rapidapi-host' 'aerodatabox.p.rapidapi.com']]) !>((flight-headers:orr ra)))
  ==
::  a flight watch looks more often as the departure nears, down to every
::  five minutes; the cadence once the flight has left; done once it has
::  landed or is a day past its arrival
++  test-flight-every
  =/  v=flight-view:orr  ['Expected' '2026-10-18 23:00Z' '' '' '' '2026-10-19 00:19Z' '' '']
  =/  dep=@da  (need (adb-time:orr '2026-10-18 23:00Z'))
  =/  every  |=([w=flight-view:orr t=@da] (flight-every:orr w t ~h3))
  ;:  weld
    (expect-eq !>(~2026.10.18..23.00.00) !>(dep))
    (expect-eq !>(`(unit @dr)``~h3) !>((every v (sub dep ~d3))))
    (expect-eq !>(`(unit @dr)``~h1) !>((every v (sub dep ~h12))))
    (expect-eq !>(`(unit @dr)``~m10) !>((every v (sub dep ~h2))))
    (expect-eq !>(`(unit @dr)``~m5) !>((every v (sub dep ~m30))))
    ::  a revised departure is the one counted to
    (expect-eq !>(`(unit @dr)``~h1) !>((every v(dep-revised '2026-10-19 09:00Z') (sub dep ~h2))))
    (expect-eq !>(`(unit @dr)``~h3) !>((every v(status 'Departed') (add dep ~m10))))
    (expect-eq !>(`(unit @dr)`~) !>((every v(status 'Arrived') (add dep ~h2))))
    (expect-eq !>(`(unit @dr)`~) !>((every v (add dep ~d2))))
    ::  no departure to count to: the cadence
    (expect-eq !>(`(unit @dr)``~h3) !>((every v(dep-sched '') (sub dep ~h2))))
  ==
::  a high-priority action is not urgent until its due passes; late, it
::  is nagged until it is snoozed, done, dismissed or unmarked
++  test-late-high
  =/  a=action:orr  [%task 'Check in for DL 2627' (jo '{"priority":"high"}') ~ `t0 'http' (sub t0 ~d5) %approved '' ~]
  =/  plain=action:orr  a(payload (jo '{"notes":"x"}'))
  ::  t0 is 22:05Z: snoozed until 00:00Z
  =/  snoozed=action:orr  a(payload (jo '{"priority":"high","snooze_until":"2026-09-17T00:00:00Z"}'))
  =/  late  |=([acts=(list [@ta action:orr]) now=@da] (turn (late-high:orr acts now) |=([id=@ta * l=@dr] [id l])))
  ;:  weld
    (expect-eq !>(`(list [@ta @dr])`~) !>((late ~[['a' a]] (sub t0 ~m1))))
    (expect-eq !>(`(list [@ta @dr])`~[['a' ~h2]]) !>((late ~[['a' a]] (add t0 ~h2))))
    (expect-eq !>(`(list [@ta @dr])`~[['p' ~h2]]) !>((late ~[['p' a(status %proposed)]] (add t0 ~h2))))
    (expect-eq !>(`(list [@ta @dr])`~) !>((late ~[['p' plain] ['d' a(status %done)] ['x' a(status %dismissed)] ['c' a(status %claimed)]] (add t0 ~h2))))
    (expect-eq !>(`(list [@ta @dr])`~) !>((late ~[['s' snoozed]] (add t0 ~h1))))
    (expect-eq !>(`(list [@ta @dr])`~[['s' ~h3]]) !>((late ~[['s' snoozed]] (add t0 ~h3))))
    (expect-eq !>(`(list [@ta @dr])`~) !>((late ~[['n' a(due ~)]] (add t0 ~h2))))
  ==
::  a late one is pushed again once fifteen minutes have passed since the
::  last push, and at once when it has none
++  test-nag-now
  =/  a=action:orr  [%task 'T' (jo '{"priority":"high"}') ~ `t0 'http' t0 %approved '' ~]
  =/  late=(list [id=@ta a=action:orr late=@dr])  ~[['a' a ~h1] ['b' a ~h1]]
  =/  now=@da  (add t0 ~h1)
  =/  ids  |=(l=(list [id=@ta a=action:orr late=@dr]) (turn l |=([id=@ta *] id)))
  =/  last=json  (pairs:enjs:format ~[['a' s+(en-iso:orr (sub now ~m10))] ['b' s+(en-iso:orr (sub now ~m15))]])
  ;:  weld
    (expect-eq !>(`(list @ta)`~['a' 'b']) !>((ids (nag-now:orr late ~ now))))
    (expect-eq !>(`(list @ta)`~['b']) !>((ids (nag-now:orr late last now))))
  ==
::  the push says what, when it was due on the owner's clock (with the
::  day once a day late), how late, and the note
++  test-nag-text
  =/  a=action:orr  [%task 'Check in for DL 2627' (jo '{"priority":"high","notes":"Seats 31C."}') ~ `~2026.10.17..23.05.00 'http' t0 %approved '' ~]
  ;:  weld
    (expect-eq !>(['Late: Check in for DL 2627' 'Due 19:05, 2 h 10 late. Seats 31C.']) !>((nag-text:orr a ~h2.m10 'America/New_York')))
    (expect-eq !>(['Late: Check in for DL 2627' 'Due 19:05, 40 min late.']) !>((nag-text:orr a(payload (jo '{"priority":"high"}')) ~m40 'America/New_York')))
    (expect-eq !>(['Late: Check in for DL 2627' 'Due Sat 19:05, 26 h late. Seats 31C.']) !>((nag-text:orr a ~h26 'America/New_York')))
  ==
::  a read's proposals whose time has passed are dropped: an event that
::  has ended, or begun with no end; a task due before now from a message
::  over a day old. A fresh message's overdue task stands (version 111)
++  test-drop-stale
  =/  now=@da  ~2026.10.18..12.00.00
  =/  rows=(list window-row:orr)
    :~  ['old' '2026-09-18T12:00:00Z' 'person/me' 'the bill' |]
        ['new' '2026-10-18T11:00:00Z' 'person/me' 'the bill' |]
    ==
  =/  task
    |=  [t=@t msg=@t due=@t]
    (pairs:enjs:format ~[['kind' s+'task'] ['title' s+t] ['message' s+msg] ['due' s+due]])
  =/  cal
    |=  [t=@t starts=@t ends=@t]
    =/  p  (pairs:enjs:format (weld `(list [@t json])`~[['starts' s+starts]] `(list [@t json])`?:(=('' ends) ~ ~[['ends' s+ends]])))
    (pairs:enjs:format ~[['kind' s+'calendar'] ['title' s+t] ['message' s+'new'] ['payload' p]])
  =/  acts=(list json)
    :~  (task 'old late' 'old' '2026-10-01T00:00:00Z')
        (task 'old ahead' 'old' '2026-11-01T00:00:00Z')
        (task 'fresh late' 'new' '2026-10-17T00:00:00Z')
        (cal 'ended' '2026-10-17T10:00:00Z' '2026-10-17T11:00:00Z')
        (cal 'begun no end' '2026-10-18T09:00:00Z' '')
        (cal 'ahead' '2026-10-19T10:00:00Z' '')
        (pairs:enjs:format ~[['kind' s+'task'] ['title' s+'no due'] ['message' s+'old']])
    ==
  =/  out=tg-facts:orr  (drop-stale:orr [~ ~ acts ~['kept'] ~] rows now)
  ;:  weld
    (expect-eq !>(`(list @t)`~['old ahead' 'fresh late' 'ahead' 'no due']) !>((turn acts.out |=(a=json (gs:orr a 'title')))))
    %+  expect-eq
      !>  ^-  (list @t)
      :~  'kept'
          'dropped action old late: due before now, from a message over a day old'
          'dropped action ended: its time has passed'
          'dropped action begun no end: its time has passed'
      ==
    !>(notes.out)
  ==
::  a note filed with no text says its title; one with text keeps it; a
::  task is left alone (version 111)
++  test-note-text
  =/  got  (de-action:orr (jo '{"kind":"note","title":"Check the oil"}') t0 'mcp')
  =/  with  (de-action:orr (jo '{"kind":"note","title":"T","payload":{"text":"own"}}') t0 'mcp')
  =/  task  (de-action:orr (jo '{"kind":"task","title":"T"}') t0 'mcp')
  ?.  ?=(%& -.got)  (expect-eq !>('decoded') !>(p.got))
  ?.  ?=(%& -.with)  (expect-eq !>('decoded') !>(p.with))
  ?.  ?=(%& -.task)  (expect-eq !>('decoded') !>(p.task))
  ;:  weld
    (expect-eq !>('Check the oil') !>((gs:orr payload.p.got 'text')))
    (expect-eq !>('own') !>((gs:orr payload.p.with 'text')))
    (expect-eq !>(`json`~) !>(payload.p.task))
  ==
::  an empty prompt part is left out of the request: Anthropic refuses an
::  empty text block (version 111)
++  test-chat-body-skips-empty
  =/  c=config:orr  (de-config:orr (jo '{"model":"m"}'))
  =/  body=json  (chat-body-with:orr c 'sys' ~['one' '' 'three'])
  =/  user=json  (rear (ga:orr body 'messages'))
  (expect-eq !>(~['one' 'three']) !>((turn (ga:orr user 'content') |=(b=json (gs:orr b 'text')))))
::  an action last changed at its newest step, else when it was proposed
::  (version 112)
++  test-last-change
  =/  a=action:orr  [%task 'T' ~ ~ ~ 'http' t0 %proposed '' ~[[t0 %proposed 'http']]]
  =/  moved=action:orr  a(history ~[[t0 %proposed 'http'] [(add t0 ~h2) %approved 'user'] [(add t0 ~h5) %done 'user']])
  ;:  weld
    (expect-eq !>(t0) !>((last-change:orr a)))
    (expect-eq !>((add t0 ~h5)) !>((last-change:orr moved)))
    (expect-eq !>(t0) !>((last-change:orr a(history ~))))
  ==
::  the owner signs as owner since version 114; user and http, the old
::  signatures, are still the owner's
++  test-owner-by
  ;:  weld
    (expect !>((owner-by:orr 'owner')))
    (expect !>((owner-by:orr 'user')))
    (expect !>((owner-by:orr 'http')))
    (expect !>(!(owner-by:orr 'talon')))
    (expect !>(!(owner-by:orr 'generator')))
  ==
::  a lattice memory entry is one standing preference, the text after
::  its front matter; one an agent wrote, or one superseded, is not, so
::  only the owner's own words steer the proposals (version 117)
++  test-rule-of-entry
  =/  nl=@t  `@t`10
  =/  fm  |=([meta=@t text=@t] (rap 3 '---' nl meta nl '---' nl text ~))
  ;:  weld
    (expect-eq !>(`(unit @t)``'Never propose calls.') !>((rule-of-entry:orr 'Never propose calls.')))
    (expect-eq !>(`(unit @t)``'Never propose calls.') !>((rule-of-entry:orr (fm 'source: user' 'Never propose calls.'))))
    (expect-eq !>(`(unit @t)`~) !>((rule-of-entry:orr (fm 'source: agent' 'Always propose calls.'))))
    (expect-eq !>(`(unit @t)`~) !>((rule-of-entry:orr (fm 'superseded-by: /orrery/preferences/b' 'Old rule.'))))
    (expect-eq !>(`(unit @t)`~) !>((rule-of-entry:orr (fm 'source: user' ''))))
    (expect-eq !>(300) !>((met 3 (need (rule-of-entry:orr (crip (reap 400 'x')))))))
  ==
::  the rules go after the owner's own standing preferences, those there
::  already left out; none, and the schema is as it was
++  test-with-rules
  =/  schema=json  (jo '{"preferences": ["Never propose calls."]}')
  ;:  weld
    (expect-eq !>(schema) !>((with-rules:orr schema ~)))
    (expect-eq !>(schema) !>((with-rules:orr schema ~['Never propose calls.'])))
    (expect-eq !>(`(list @t)`~['Never propose calls.' 'Texts, not calls.']) !>((strings:orr (ga:orr (with-rules:orr schema ~['Texts, not calls.']) 'preferences'))))
  ==
++  test-has-phrase
  ;:  weld
    (expect !>((has-phrase:orr 'ETIAS is now REQUIRED for travel' 'now required')))
    (expect !>(!(has-phrase:orr 'ETIAS is not yet in force' 'now required')))
    (expect !>(!(has-phrase:orr 'anything' '')))
  ==
::  the expanded zones render a local clock with the right offset, both
::  hemispheres (DST wraps the new year in the south) and fixed-offset
++  test-zones-local-iso
  =/  li  |=([at=@t tz=@t] ^-(@t (local-iso:orr at tz)))
  ;:  weld
    (expect-eq !>('2026-07-15T08:00:00-04:00') !>((li '2026-07-15T12:00:00Z' 'America/New_York')))
    (expect-eq !>('2026-01-15T07:00:00-05:00') !>((li '2026-01-15T12:00:00Z' 'America/New_York')))
    (expect-eq !>('2026-07-15T14:00:00+02:00') !>((li '2026-07-15T12:00:00Z' 'Europe/Madrid')))
    (expect-eq !>('2026-01-15T13:00:00+01:00') !>((li '2026-01-15T12:00:00Z' 'Europe/Madrid')))
    (expect-eq !>('2026-01-15T23:00:00+11:00') !>((li '2026-01-15T12:00:00Z' 'Australia/Sydney')))
    (expect-eq !>('2026-07-15T22:00:00+10:00') !>((li '2026-07-15T12:00:00Z' 'Australia/Sydney')))
    (expect-eq !>('2026-07-15T21:00:00+09:00') !>((li '2026-07-15T12:00:00Z' 'Asia/Tokyo')))
    (expect-eq !>('2026-01-15T17:30:00+05:30') !>((li '2026-01-15T12:00:00Z' 'Asia/Kolkata')))
    (expect-eq !>('2026-07-15T12:00:00+00:00') !>((li '2026-07-15T12:00:00Z' 'UTC')))
  ==
--
