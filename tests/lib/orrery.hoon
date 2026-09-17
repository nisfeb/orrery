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
::
::  ==  names
::
++  test-ok-kind
  ;:  weld
    (expect !>((ok-kind:orr 'person')))
    (expect !>(!(ok-kind:orr 'Person')))
    (expect !>(!(ok-kind:orr '9lives')))
    (expect !>(!(ok-kind:orr '')))
    (expect !>(!(ok-kind:orr 'a-very-long-kind-name-over-24')))
  ==
++  test-ok-slug
  ;:  weld
    (expect !>((ok-slug:orr '2026-09-16-breakdown')))
    (expect !>((ok-slug:orr 'me')))
    (expect !>(!(ok-slug:orr '-x')))
    (expect !>(!(ok-slug:orr 'John')))
  ==
++  test-parse-bid
  ;:  weld
    (expect-eq !>(`(unit [@tas @ta])`[~ %person %sarah]) !>((parse-bid:orr 'person/sarah')))
    (expect-eq !>(`(unit [@tas @ta])`~) !>((parse-bid:orr 'sarah')))
    (expect-eq !>(`(unit [@tas @ta])`~) !>((parse-bid:orr 'Person/Sarah')))
    (expect-eq !>('thing/subaru') !>((make-bid:orr %thing %subaru)))
  ==
::
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
    (expect-eq !>('1970-01-01T00:00:00Z') !>((en-iso:orr ~1970.1.1)))
  ==
++  test-unix-secs
  ;:  weld
    (expect-eq !>(`@ud`1.789.596.300) !>((unix-secs:orr t0)))
    (expect-eq !>(`@ud`0) !>((unix-secs:orr ~1969.12.31)))
  ==
::
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
::
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
::
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
::
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
  =/  w  (fold:orr ~[a b c d] ~ when)
  =/  tl  (timeline:orr ~[a b c d] w when)
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
    (expect-eq !>('b') !>(?~(tl '' id.r.i.tl)))
  ==
::
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
++  test-resolve
  =/  bodies=(list [id=bid:orr =body:orr])
    :~  ['person/sarah' [%person 'Sarah' (sy ~['wife']) t0 `~sampel-palnet]]
        ['place/johns-machine-shop' [%place 'John\'s Machine Shop' (sy ~['John\'s' 'the shop']) t0 ~]]
        ['thing/subaru' [%thing 'The Subaru' (sy ~['the car']) t0 ~]]
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
::
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
::
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
    (expect-eq !>('proposed') !>((push-mode-of:orr starter-policy:orr)))
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
::
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
    (expect-eq !>(%approved) !>(status.b))
    (expect-eq !>(2) !>((lent history.b)))
  ==
::  an exact hit outranks a prefix hit on another body
::
++  test-resolve-exact-before-prefix
  =/  bodies=(list [id=bid:orr =body:orr])
    :~  ['person/sammy' [%person 'Sammy' ~ t0 ~]]
        ['person/sam' [%person 'Sam' ~ t0 ~]]
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
    (expect-eq !>(`(unit body:orr)`~) !>((read-body:orr [%3 'nope'])))
  ==
::
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
    (expect-eq !>('orrery-person-sarah') !>((group-name:orr %person %sarah)))
  ==
::  a carried observation names the other side's body and carries the
::  sender's grub name; the receiver sets by and source from the ship
::  it heard it from, so a decode on the receiving side reads as the
::  sender's claim
++  test-carry-and-receive
  =/  r=row:orr  ['1789596300-abcdef01' o1]
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
    (expect-eq !>(until:o1) !>(until.p.back))
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
  ==
::
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
    (expect !>((kind-in-scope:orr [(sy ~[%person]) ~ |] %person)))
    (expect !>(!(kind-in-scope:orr [(sy ~[%person]) ~ |] %place)))
    (expect !>((action-in-scope:orr [~ (sy ~[%task]) &] %task)))
    (expect !>(!(action-in-scope:orr [~ (sy ~[%task]) &] %note)))
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
    (expect-eq !>((hash-token:orr 'salt' s)) !>((hash-token:orr 'salt' s)))
    (expect !>(!=((hash-token:orr 'salt' s) (hash-token:orr 'pepper' s))))
    (expect !>(!=((hash-token:orr 'salt' s) (hash-token:orr 'salt' 'other'))))
  ==
++  test-client-roundtrip
  =/  sc=scope:orr  [(sy ~[%person]) (sy ~[%task]) &]
  =/  c=client:orr  ['abc' 'talon' 'talon' sc 'salt' (hash-token:orr 'salt' 'secret') t0 ~]
  =/  c2=client:orr  c(used `t0)
  =/  back=(unit client:orr)  (de-client:orr (en-client-row:orr c))
  =/  view=json  (en-client-view:orr c)
  ;:  weld
    (expect-eq !>(`c) !>(back))
    (expect-eq !>(`c2) !>((de-client:orr (en-client-row:orr c2))))
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
  =/  sc=scope:orr  [(sy ~[%person]) ~ &]
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
  ;:  weld
    (expect-eq !>(~) !>((out-of-scope:orr ok sc hide)))
    (expect-eq !>(`'place/home') !>((out-of-scope:orr bad-body sc hide)))
    (expect-eq !>(`'thing/car') !>((out-of-scope:orr bad-subject sc hide)))
    (expect-eq !>(`'health') !>((out-of-scope:orr bad-attr sc hide)))
    (expect-eq !>(~) !>((out-of-scope:orr unparsed sc hide)))
  ==
++  test-veil-refs-and-scope-about
  =/  base=obs:orr  o1
  =/  r-place=row:orr  ['1' base(value (pairs:enjs:format ~[['ref' s+'place/home']]))]
  =/  r-person=row:orr  ['2' base(value (pairs:enjs:format ~[['ref' s+'person/sarah']]))]
  =/  r-plain=row:orr  ['3' base]
  =/  kept=(list row:orr)  (veil-refs:orr ~[r-place r-person r-plain] (sy ~[%person]))
  =/  a=action:orr
    [%task 'Call the shop' ~ (sy ~['thing/subaru' 'person/sarah']) ~ 'mcp' t0 %proposed '' ~]
  =/  trimmed=action:orr  (scope-about:orr a (sy ~[%person]))
  ;:  weld
    (expect-eq !>(~['1' '2' '3']) !>((turn kept |=(r=row:orr id.r))))
    (expect-eq !>(`json`~) !>(?~(kept ~ value.obs.i.kept)))
    (expect-eq !>(`json`(pairs:enjs:format ~[['ref' s+'person/sarah']])) !>(value.obs:(snag 1 `(list row:orr)`kept)))
    (expect-eq !>(`json`(pairs:enjs:format ~[['ref' s+'place/home']])) !>(value.obs:(snag 0 (veil-refs:orr ~[r-place] (sy ~[%person %place])))))
    (expect-eq !>((sy ~['person/sarah'])) !>(about.trimmed))
    (expect-eq !>(~) !>(about:(scope-about:orr a ~)))
  ==
--
