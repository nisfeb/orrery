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
::  ── names ──────────────────────────────────────────────────────────
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
::  ── time ───────────────────────────────────────────────────────────
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
::  ── ids ────────────────────────────────────────────────────────────
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
    [%task 'Call the shop' ~ (sy ~['thing/subaru']) ~ 'mcp' t0 %proposed '']
  (expect-eq !>(19) !>((lent (trip (act-id:orr a)))))
::
::  ── decoders ───────────────────────────────────────────────────────
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
    (expect-eq !>('source.kind: required') !>((bad '{"subject":"thing/subaru","attr":"location","value":1}')))
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
  ;:  weld
    (expect-eq !>('2026-09-16T22:05:00Z') !>((gs:orr j 'at')))
    (expect-eq !>('http') !>((gs:orr j 'by')))
    (expect-eq !>('keep') !>((gs:orr (fill-obs:orr (jo '{"at":"keep"}') t0 'http') 'at')))
    (expect-eq !>('2026-09-16T22:05:00Z') !>((gs:orr k 'proposed')))
    (expect-eq !>('user') !>((gs:orr k 'by')))
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
::  ── readers and merge ──────────────────────────────────────────────
::
++  test-readers
  =/  b=body:orr  [%person 'Sarah' (sy ~['Sarah']) t0]
  ;:  weld
    (expect-eq !>(`(unit body:orr)`[~ b]) !>((read-body:orr [%1 b])))
    (expect-eq !>(`(unit body:orr)`~) !>((read-body:orr [%2 'nope'])))
    (expect-eq !>(`(unit obs:orr)`[~ o1]) !>((read-obs:orr [%1 o1])))
    (expect-eq !>(`(unit obs:orr)`~) !>((read-obs:orr 'garbage')))
  ==
++  test-merge-body
  =/  old=body:orr  [%person 'Sarah' (sy ~['Sarah']) t0]
  =/  new=body:orr  [%person '' (sy ~['wife']) (add t0 ~d1)]
  =/  got=body:orr  (merge-body:orr old new)
  ;:  weld
    (expect-eq !>('Sarah') !>(name.got))
    (expect-eq !>(`(set @t)`(sy ~['Sarah' 'wife'])) !>(aliases.got))
    (expect-eq !>(t0) !>(created.got))
    (expect-eq !>('Sarah B') !>(name:(merge-body:orr old new(name 'Sarah B'))))
    (expect-eq !>('sarah') !>((fresh-name:orr %sarah '')))
    (expect-eq !>('Sarah') !>((fresh-name:orr %sarah 'Sarah')))
  ==
--
