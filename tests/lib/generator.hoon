::  Unit tests for /lib/generator: the pure half of the on-ship
::  generator, on fixtures. Nothing here touches the ship.
::
/+  *test, orr=orrery, gen=orrery
|%
++  jo   |=(t=@t ^-(json (need (de:json:html t))))
++  now  ~2026.9.18..12.00.00
::  a winners map with one single-valued attr per key: what +fold answers
++  win
  |=  kvs=(list [k=@t v=@t])
  ^-  (map @t (list row:orr))
  %-  ~(gas by *(map @t (list row:orr)))
  %+  turn  kvs
  |=  [k=@t v=@t]
  :-  k
  ^-  (list row:orr)
  :_  ~
  ^-  row:orr
  ['x' ['s/x' k s+v now ~ 100 ['test' 'fx'] 'test' now | '']]
::  ==  phase
::
++  test-phase
  ;:  weld
    (expect-eq !>('closed') !>((phase:gen (win ~[['status' 'closed'] ['ends' '2099-01-01T00:00:00Z']]) now)))
    (expect-eq !>('cancelled') !>((phase:gen (win ~[['status' 'cancelled']]) now)))
    (expect-eq !>('over') !>((phase:gen (win ~[['starts' '2026-09-18T11:00:00Z'] ['ends' '2026-09-18T11:30:00Z']]) now)))
    (expect-eq !>('under way') !>((phase:gen (win ~[['starts' '2026-09-18T11:00:00Z'] ['ends' '2026-09-18T13:00:00Z']]) now)))
    (expect-eq !>('upcoming') !>((phase:gen (win ~[['status' 'under way'] ['starts' '2026-12-05T19:00:00Z']]) now)))
    (expect-eq !>('open') !>((phase:gen (win ~) now)))
  ==
::  ==  titles
::
++  test-same-title
  ;:  weld
    (expect !>((same-title:gen 'Call the shop about the Subaru' 'call the shop about the subaru.')))
    (expect !>((same-title:gen 'Call John\'s shop about the Subaru' 'Call the shop about the Subaru')))
    (expect !>(!(same-title:gen 'Pay the electricity bill' 'Call the shop about the Subaru')))
    (expect !>(!(same-title:gen '' 'Call the shop')))
    (expect-eq !>(~['call' 'the' 'shop']) !>((norm-words:gen 'Call the SHOP!')))
  ==
::  ==  the prompt
::
::  the fixture: what test_run.py's STATE holds, as loaded bodies
++  rows
  |=  kvs=(list [k=@t v=@t])
  ^-  (list row:orr)
  (turn kvs |=([k=@t v=@t] ^-(row:orr ['x' ['s/x' k s+v now ~ 100 ['test' 'fx'] 'test' now | '']])))
++  mk
  |=  [id=@t kind=@tas name=@t kvs=(list [@t @t])]
  ^-  loaded:orr
  [id [kind name ~ now ~] (rows kvs)]
++  fixture
  ^-  [all=(list loaded:orr) acts=(list [id=@ta a=action:orr]) schema=json]
  =/  a1=action:orr
    :*  %task  'Call the shop about the Subaru'  [%o ~]  (sy ~['thing/subaru'])  ~
        'mcp'  now  %approved  ''  ~
    ==
  :+  :~  (mk 'person/me' %person 'dana' ~[['timezone' 'America/New_York']])
          (mk 'person/sarah' %person 'Sarah' ~[['status' 'on jury duty']])
          (mk 'thing/subaru' %thing 'the Subaru' ~[['status' 'at the shop, awaiting diagnosis']])
          (mk 'situation/2026-09-16-breakdown' %situation 'The breakdown' ~[['started' '2026-09-16T22:00:00Z']])
          (mk 'situation/2026-12-05-meeting' %situation 'Parent meeting' ~[['starts' '2026-12-05T19:00:00Z'] ['ends' '2026-12-05T20:00:00Z']])
          (mk 'situation/2026-09-10-walk' %situation 'Walk' ~[['status' 'closed'] ['ended' '2026-09-10T15:00:00Z']])
          (mk 'activity/ballet' %activity 'Ballet' ~[['last' '2026-09-16T20:45:00Z'] ['next' '2026-09-18T20:45:00Z']])
      ==
    ~[['a1' a1]]
  %-  jo
  '{"kinds":{},"actions":["task","note","message","home"],"payloads":{"message":{"via":"required: telegram","to":"required: a body id","text":"required"},"home":{"service":"required","entity_id":"required","data":"optional"}}}'
++  has-sub  |=([hay=@t pin=@t] ^-(? ?=(^ (find (trip pin) (trip hay)))))
++  test-build-parts
  =/  f  fixture
  =/  parts=(list @t)  (build-parts:gen all.f acts.f ~ schema.f now 'America/New_York' 5)
  =/  p0=@t  (snag 0 parts)
  =/  p1=@t  (snag 1 parts)
  =/  p2=@t  (snag 2 parts)
  =/  p3=@t  (snag 3 parts)
  =/  p4=@t  (snag 4 parts)
  =/  dismissed=action:orr
    :*  %task  'Go to Ballet'  [%o ~]  (sy ~['activity/ballet'])  ~
        'generator'  now  %dismissed  'just the event'  ~
    ==
  =/  p3-with=@t  (snag 3 (build-parts:gen all.f acts.f ~[['d1' dismissed]] schema.f now 'America/New_York' 5))
  ;:  weld
    (expect-eq !>(5) !>((lent parts)))
    (expect !>((has-sub p0 'The owner is person/me. Propose at most 5 actions.')))
    (expect !>((has-sub p0 'Payload shapes:')))
    (expect !>((has-sub p0 '"via":"required: telegram"')))
    (expect !>((has-sub p0 'things:')))
    (expect !>((has-sub p1 'persons:')))
    (expect !>((has-sub p1 (rap 3 'activities:' nl:gen '  activity/ballet | Ballet | last=2026-09-16T20:45:00Z; next=2026-09-18T20:45:00Z' ~))))
    (expect !>((has-sub p2 'situation/2026-12-05-meeting | Parent meeting | upcoming')))
    (expect !>((has-sub p2 'situation/2026-09-16-breakdown | The breakdown | under way')))
    (expect !>(!(has-sub p2 'situation/2026-09-10-walk')))
    (expect !>((has-sub p3 'Open actions')))
    (expect !>((has-sub p3 'task | Call the shop about the Subaru | about thing/subaru')))
    (expect !>((has-sub p3-with 'dismissed | task | Go to Ballet | just the event')))
    (expect !>((has-sub system-prompt:gen 'A dismissed action may carry the owner\'s reason')))
    (expect-eq !>('Now: 2026-09-18T12:00:00Z, timezone America/New_York. Answer with the JSON object.') !>(p4))
    (expect-eq !>((digest:gen parts)) !>((digest:gen (build-parts:gen all.f acts.f ~ schema.f (add now ~m5) 'America/New_York' 5))))
    (expect !>(!=((digest:gen parts) (digest:gen (build-parts:gen all.f ~ ~ schema.f now 'America/New_York' 5)))))
  ==
::  ==  the request and the answer
::
++  cfg
  ^-  config:gen
  %-  de-config:gen
  %-  jo
  '{"enabled":true,"url":"https://openrouter.ai/api/v1","model":"moonshotai/kimi-k3","api_key":"sk-test","reasoning":{"effort":"high"},"max_tokens":32000,"max_actions":5}'
++  marked  |=(b=json ^-(? ?&(?=([%o *] b) (~(has by p.b) 'cache_control'))))
++  test-chat-body
  =/  body=json  (chat-body:gen cfg ~['a' 'b' 'c' 'd' 'e'])
  =/  msgs=(list json)  (ga:orr body 'messages')
  =/  sys=json  (snag 0 msgs)
  =/  usr=json  (snag 1 msgs)
  =/  blocks=(list json)  (ga:orr usr 'content')
  ;:  weld
    (expect-eq !>('moonshotai/kimi-k3') !>((gs:orr body 'model')))
    (expect-eq !>(`32.000) !>((gn:orr body 'max_tokens')))
    (expect-eq !>(`json`[%o (my ~[['zdr' b+&]])]) !>((gj:orr body 'provider')))
    (expect-eq !>(`json`[%o (my ~[['include' b+&]])]) !>((gj:orr body 'usage')))
    (expect-eq !>(`json`~) !>((gj:orr body 'temperature')))
    (expect-eq !>(`json`[%o (my ~[['effort' s+'high']])]) !>((gj:orr body 'reasoning')))
    (expect-eq !>('system') !>((gs:orr sys 'role')))
    (expect !>((marked (snag 0 (ga:orr sys 'content')))))
    (expect-eq !>(5) !>((lent blocks)))
    (expect-eq !>(~[& & & | |]) !>((turn blocks marked)))
    (expect-eq !>('c') !>((gs:orr (snag 2 blocks) 'text')))
    (expect !>((has-sub (gs:orr (snag 0 (ga:orr sys 'content')) 'text') 'You are the analyst for orrery')))
  ==
++  test-chat-body-no-reasoning
  =/  base=config:gen  cfg
  =/  off=config:gen  base(reasoning [%o (my ~[['enabled' b+|]])])
  =/  body=json  (chat-body:gen off ~['a'])
  ;:  weld
    (expect-eq !>(`json`~) !>((gj:orr body 'reasoning')))
    (expect-eq !>(`0) !>((gn:orr body 'temperature')))
  ==
++  test-answer-of
  =/  resp=json  (jo '{"choices":[{"message":{"content":"{\\"actions\\":[]}"}}],"usage":{"prompt_tokens":8556,"completion_tokens":2125,"cost":0.0959}}')
  =/  got  (answer-of:gen resp)
  =/  empty  (answer-of:gen (jo '{"choices":[{"message":{"content":""},"finish_reason":"length"}]}'))
  =/  bad  (answer-of:gen (jo '{"error":{"message":"no endpoints"}}'))
  ;:  weld
    (expect !>(?=(%& -.got)))
    (expect-eq !>('{"actions":[]}') !>(?>(?=(%& -.got) text.p.got)))
    (expect-eq !>(`8.556) !>((gn:orr ?>(?=(%& -.got) usage.p.got) 'prompt_tokens')))
    (expect !>(?=(%| -.bad)))
    (expect-eq !>('no endpoints') !>(?>(?=(%| -.bad) p.bad)))
    (expect-eq !>('the model ran out of tokens before answering') !>(?>(?=(%| -.empty) p.empty)))
  ==
++  test-parse-answer
  ;:  weld
    (expect-eq !>(`(jo '{"actions":[]}')) !>((parse-answer:gen (rap 3 '```json' nl:gen '{"actions":[]}' nl:gen '```' ~))))
    (expect-eq !>(`(jo '{"a":{"b":1}}')) !>((parse-answer:gen 'Sure: {"a":{"b":1}} hope that helps')))
    (expect-eq !>(*(unit json)) !>((parse-answer:gen 'not json at all')))
  ==
++  test-config
  =/  shown=json  (en-config-masked:gen cfg)
  =/  bare=config:gen  (de-config:gen (jo '{}'))
  ;:  weld
    (expect-eq !>(`json`~) !>((gj:orr shown 'api_key')))
    (expect-eq !>(`json`b+&) !>((gj:orr shown 'api_key_set')))
    (expect-eq !>('moonshotai/kimi-k3') !>((gs:orr shown 'model')))
    (expect-eq !>(|) !>(enabled.bare))
    (expect-eq !>(8.000) !>(max-tokens.bare))
    (expect-eq !>(60) !>(cooldown.bare))
    (expect-eq !>(24) !>(max-daily.bare))
    (expect-eq !>(5) !>(max-urgent.bare))
    (expect-eq !>('https://openrouter.ai/api/v1') !>(url.bare))
    (expect !>((reasoning-on:gen reasoning.bare)))
  ==
::  ==  the validator: test_run.py's cases, one for one
::
++  test-validate
  =/  f  fixture
  =/  known=(set @t)  (sy (turn all.f |=(l=loaded:orr id.l)))
  =/  taken=(list @t)  ~['Call the shop about the Subaru' 'Pay Utility Co $142.50' 'Tell Sarah the car is at the shop']
  =/  answer=json
    %-  jo
    '''
    {"actions": [
      {"kind": "task", "title": "Ask the shop for a diagnosis estimate", "about": ["thing/subaru"], "due": "2026-09-19T13:00:00Z", "why": "the car has sat two days"},
      {"kind": "task", "title": "Call the shop about the Subaru", "about": ["thing/subaru"]},
      {"kind": "message", "title": "Tell Sarah the car is at the shop", "payload": {"via": "telegram", "to": "person/sarah", "text": "x"}},
      {"kind": "message", "title": "Wish Sarah luck at jury duty", "about": ["person/sarah"], "payload": {"via": "telegram", "to": "person/sarah", "text": "Good luck today"}},
      {"kind": "message", "title": "Ping the mechanic", "payload": {"to": "person/mechanic"}},
      {"kind": "email", "title": "Email the shop"},
      {"kind": "task", "title": "Buy a new car", "about": ["thing/tesla"]},
      {"kind": "home", "title": "Porch light on", "payload": {"service": "light.turn_on", "entity_id": "light.porch"}}
    ], "notes": ["the breakdown situation has no ended"]}
    '''
  =/  events=(list @t)  ~['Ballet' 'Parent meeting' 'The breakdown']
  =/  got  (validate:gen answer known taken events schema.f 5)
  =/  titles=(list @t)  (turn acts.got |=(a=json (gs:orr a 'title')))
  =/  joined=@t  (join-cords:gen ' ' notes.got)
  =/  nine=json  (jo '{"actions":[{"kind":"task","title":"Task 1"},{"kind":"task","title":"Task 2"},{"kind":"task","title":"Task 3"},{"kind":"task","title":"Task 4"}]}')
  ;:  weld
    (expect-eq !>(~['Ask the shop for a diagnosis estimate' 'Wish Sarah luck at jury duty' 'Porch light on']) !>(titles))
    (expect-eq !>('the car has sat two days') !>((gs:orr (gj:orr (snag 0 acts.got) 'payload') 'why')))
    (expect-eq !>('2026-09-19T13:00:00Z') !>((gs:orr (snag 0 acts.got) 'due')))
    (expect-eq !>('person/sarah') !>((gs:orr (gj:orr (snag 1 acts.got) 'payload') 'to')))
    (expect !>((has-sub joined 'already open or decided: Call the shop about the Subaru')))
    (expect !>((has-sub joined 'already open or decided: Tell Sarah the car is at the shop')))
    (expect !>((has-sub joined 'payload lacks')))
    (expect !>((has-sub joined 'kind email')))
    (expect !>((has-sub joined 'thing/tesla')))
    (expect !>((has-sub joined 'model note: the breakdown situation has no ended')))
    (expect-eq !>(3) !>((lent acts:(validate:gen nine known ~ ~ schema.f 3))))
  ==
++  test-restates
  ;:  weld
    (expect !>((restates:gen 'Go to Ballet' 'Ballet')))
    (expect !>((restates:gen 'Attend the Nutcracker rehearsal' 'Nutcracker rehearsal')))
    (expect !>(!(restates:gen 'Plan Magnus\'s birthday' 'Magnus Birthday')))
    (expect !>(!(restates:gen 'Pack for the day at Grandma and Grandaddy\'s' 'Grandma and Grandaddy\'s')))
    (expect !>(!(restates:gen 'Ballet' '')))
  ==
++  test-validate-drops-event-todos
  =/  f  fixture
  =/  known=(set @t)  (sy (turn all.f |=(l=loaded:orr id.l)))
  =/  events=(list @t)  ~['Ballet' 'Nutcracker rehearsal' 'Parent meeting']
  =/  answer=json
    %-  jo
    '''
    {"actions": [
      {"kind": "task", "title": "Ballet", "about": ["activity/ballet"]},
      {"kind": "task", "title": "Go to the Nutcracker rehearsal"},
      {"kind": "task", "title": "Pack ballet shoes and tights for the first class", "about": ["activity/ballet"], "payload": {"notes": "shoes, tights, hair ties"}},
      {"kind": "task", "title": "Sort out the overlap between ballet and the parent meeting", "about": ["activity/ballet", "situation/2026-12-05-meeting"]}
    ]}
    '''
  =/  got  (validate:gen answer known ~ events schema.f 5)
  =/  joined=@t  (join-cords:gen ' ' notes.got)
  ;:  weld
    (expect-eq !>(`(list @t)`~['Pack ballet shoes and tights for the first class' 'Sort out the overlap between ballet and the parent meeting']) !>(`(list @t)`(turn acts.got |=(a=json (gs:orr a 'title')))))
    (expect !>((has-sub joined 'dropped as a todo for an event on the calendar: Ballet (Ballet)')))
    (expect !>((has-sub joined 'Go to the Nutcracker rehearsal (Nutcracker rehearsal)')))
  ==
::  ==  the limits
::
++  test-held-until
  =/  c=config:gen  (de-config:gen (jo '{"cooldown_minutes": 60, "max_daily": 2}'))
  =/  fresh=json  (jo '{}')
  =/  recent=json  (jo '{"called": "2026-09-18T11:30:00Z", "day": "2026-09-18", "calls_today": 1}')
  =/  old=json  (jo '{"called": "2026-09-18T10:00:00Z", "day": "2026-09-18", "calls_today": 1}')
  =/  capped=json  (jo '{"called": "2026-09-18T10:00:00Z", "day": "2026-09-18", "calls_today": 2}')
  =/  yesterday=json  (jo '{"called": "2026-09-17T23:00:00Z", "day": "2026-09-17", "calls_today": 2}')
  ;:  weld
    (expect-eq !>(*(unit @da)) !>((held-until:gen c fresh now)))
    (expect-eq !>(`~2026.9.18..12.30.00) !>((held-until:gen c recent now)))
    (expect-eq !>(*(unit @da)) !>((held-until:gen c old now)))
    (expect-eq !>(`~2026.9.19) !>((held-until:gen c capped now)))
    (expect-eq !>(*(unit @da)) !>((held-until:gen c yesterday now)))
  ==
::  ==  retire
::
++  sit
  |=  [id=@t kvs=(list [k=@t v=@t]) seen=@da]
  ^-  loaded:orr
  :+  id  [%situation 'x' ~ now ~]
  %+  turn  kvs
  |=  [k=@t v=@t]
  ^-  row:orr
  [(cat 3 k '-row') [id k s+v seen ~ 100 ['test' 'fx'] 'test' seen | '']]
++  test-plan-retire
  =/  ago=@da  (sub now ~d40)
  =/  all=(list loaded:orr)
    :~  (sit 'situation/2026-09-10-dentist' ~[['ends' '2026-09-10T15:00:00Z']] ago)
        (sit 'situation/2026-09-20-dentist' ~[['ends' '2026-09-20T15:00:00Z']] ago)
        (sit 'situation/2026-09-01-done' ~[['ended' '2026-09-01T15:00:00Z'] ['status' 'closed']] ago)
        (sit 'situation/2026-09-01-trip' ~[['started' '2026-09-01T15:00:00Z']] ago)
        (sit 'situation/2026-09-15-trip' ~[['started' '2026-09-15T15:00:00Z']] ago)
        (sit 'situation/2026-07-01-stale' ~[['started' '2026-07-01T15:00:00Z']] ago)
        (sit 'situation/2026-07-01-alive' ~[['started' '2026-07-01T15:00:00Z']] now)
        (sit 'situation/2026-09-10-fresh' ~[['starts' '2026-09-10T15:00:00Z']] ago)
    ==
  =/  got  (plan-retire:orr all ~ now ~d30)
  ;:  weld
    %+  expect-eq
      !>(`(list @t)`~['situation/2026-09-10-dentist' 'situation/2026-09-01-trip' 'situation/2026-07-01-stale'])
      !>(`(list @t)`(turn got |=([id=@t *] id)))
    (expect-eq !>(~2026.9.10..15.00.00) !>(at:(snag 0 got)))
    (expect-eq !>(~2026.9.8..15.00.00) !>(at:(snag 1 got)))
    (expect-eq !>(ago) !>(at:(snag 2 got)))
    (expect-eq !>('ended 2026-09-10T15:00:00Z') !>(why:(snag 0 got)))
  ==
++  test-plan-retire-after-status
  ::  a reminder said open after the event: the close lands a second past it
  =/  l=loaded:orr
    (sit 'situation/2026-09-10-dentist' ~[['ends' '2026-09-10T15:00:00Z'] ['status' 'open']] now)
  =/  got  (plan-retire:orr ~[l] ~ now ~d30)
  ;:  weld
    (expect-eq !>(1) !>((lent got)))
    (expect-eq !>((add now ~s1)) !>(at:(snag 0 got)))
    (expect !>((is-trip:orr 'situation/2026-09-01-trip')))
    (expect !>(!(is-trip:orr 'situation/2026-09-01-triple')))
  ==
++  test-retire-op
  =/  ops=(list json)  (retire-ops:orr ~[['situation/2026-09-10-dentist' ~2026.9.10..15.00.00 'ended']])
  =/  op=json  (snag 0 ops)
  =/  rows=(list json)  (ga:orr op 'observations')
  ;:  weld
    (expect-eq !>('observe') !>((gs:orr op 'op')))
    (expect-eq !>(1) !>((lent rows)))
    (expect-eq !>('closed') !>((gs:orr (snag 0 rows) 'value')))
    (expect-eq !>('2026-09-10T15:00:00Z') !>((gs:orr (snag 0 rows) 'at')))
    (expect-eq !>('retire/situation/2026-09-10-dentist') !>((gs:orr (gj:orr (snag 0 rows) 'source') 'id')))
  ==
::  ==  reconcile
::
++  mkb
  |=  [id=@t kind=@tas name=@t als=(list @t) kvs=(list [k=@t v=json]) at=@da]
  ^-  loaded:orr
  :+  id  [kind name (sy als) at ~]
  %+  turn  kvs
  |=  [k=@t v=json]
  ^-  row:orr
  [(rap 3 id '/' k ~) [id k v at ~ 100 ['test' 'fx'] 'test' at | '']]
++  ops-of  |=(ops=(list json) ^-((list @t) (turn ops |=(o=json (gs:orr o 'op')))))
++  test-normalize-title
  ;:  weld
    (expect-eq !>('pottery') !>((normalize-title:orr 'Reminder: Pottery @ Thu May 14, 6:00pm')))
    (expect-eq !>('robin pottery/wheel') !>((normalize-title:orr 'Robin- Pottery/Wheel')))
    (expect-eq !>('trip') !>((normalize-title:orr 'Fwd: Re: Trip 2026-09-02')))
    (expect-eq !>('dinner') !>((normalize-title:orr 'Dinner 6 pm Friday 9/12')))
    (expect-eq !>('ballet') !>((normalize-title:orr 'Ballet Sep 12, 2026')))
    (expect-eq !>('trip starting') !>((strict-key:orr 'Reminder:  Trip   Starting')))
    (expect-eq !>('theo-juno-opti-sail') !>((slug:orr 'Theo & Juno: Opti Sail!')))
    (expect-eq !>('x') !>((slug:orr '---')))
  ==
++  test-same-person
  ;:  weld
    (expect !>((same-person:orr 'dana' 'Dana Quill')))
    (expect !>(!(same-person:orr 'dana' 'daniel quill')))
    (expect !>(!(same-person:orr 'wife' 'dana')))
    (expect !>((same-person:orr 'Dana Quill' 'Quill, Dana')))
    (expect !>((person-named:orr [%org 'Dana Quill' ~ now ~])))
    (expect !>(!(person-named:orr [%org 'Quill Bank' ~ now ~])))
    (expect !>(!(person-named:orr [%org 'Dana' ~ now ~])))
    (expect !>((person-named:orr [%person 'x' ~ now ~])))
  ==
++  test-names-in
  ;:  weld
    (expect-eq !>(`[(list @t) (unit @t)]`[~['Mira'] ~]) !>((names-in:orr 'Mira- Ballet/Tap')))
    (expect-eq !>(`[(list @t) (unit @t)]`[~['Theo' 'Juno'] ~]) !>((names-in:orr 'Theo and Juno- Opti Sail')))
    (expect-eq !>(`[(list @t) (unit @t)]`[~['Felix'] ~]) !>((names-in:orr 'Felix\'s birthday')))
    (expect-eq !>(`[(list @t) (unit @t)]`[~['Felix'] ~]) !>((names-in:orr 'Felix Birthday party')))
    (expect-eq !>(`[(list @t) (unit @t)]`[~ `'Felix']) !>((names-in:orr 'Felix Fencing Lesson')))
    (expect-eq !>(`[(list @t) (unit @t)]`[~ ~]) !>((names-in:orr 'trip to Boston')))
    (expect-eq !>(`[(list @t) (unit @t)]`[~ ~]) !>((names-in:orr 'FELIX x')))
  ==
++  test-cal-uid
  ;:  weld
    %+  expect-eq
      !>(`(unit @t)`[~ 'cal-abc-12345678-1234-1234-1234-123456789abc'])
      !>((cal-uid:orr 'situation/cal-abc-12345678-1234-1234-1234-123456789abc-20260829t100000'))
    (expect-eq !>(`(unit @t)`[~ 'cal-12345678-1234-1234-1234-123456789abc']) !>((cal-uid:orr 'situation/cal-12345678-1234-1234-1234-123456789abc')))
    (expect-eq !>(*(unit @t)) !>((cal-uid:orr 'situation/2026-09-01-dentist')))
    (expect-eq !>('Ballet') !>((common-title:orr ~['Ballet' 'Ballet Class' 'Ballet' ''])))
    (expect-eq !>('Tap') !>((common-title:orr ~['Ballet' 'Tap'])))
  ==
++  test-plan-times
  =/  ahead=@da  (add now ~d3)
  =/  all=(list loaded:orr)
    :~  (mkb 'situation/2026-09-21-dentist' %situation 'Dentist' ~ ~[['started' s+(en-iso:orr ahead)] ['status' s+'upcoming']] now)
        (mkb 'activity/ballet' %activity 'Ballet' ~ ~[['next' s+'2026-09-01T15:00:00Z'] ['last' s+(en-iso:orr ahead)]] now)
        (mkb 'situation/2026-09-01-ok' %situation 'Ok' ~ ~[['ended' s+'2026-09-01T15:00:00Z'] ['status' s+'closed']] now)
    ==
  =/  ops=(list json)  (plan-times:orr all now)
  =/  writes=(list json)  (ga:orr (rear ops) 'observations')
  ;:  weld
    (expect-eq !>(`(list @t)`~['retract' 'retract' 'retract' 'observe']) !>((ops-of ops)))
    (expect-eq !>('situation/2026-09-21-dentist/started') !>((gs:orr (snag 0 ops) 'id')))
    (expect-eq !>(2) !>((lent writes)))
    (expect-eq !>('starts') !>((gs:orr (snag 0 writes) 'attr')))
    (expect-eq !>((en-iso:orr now)) !>((gs:orr (snag 0 writes) 'at')))
    (expect-eq !>('next') !>((gs:orr (snag 1 writes) 'attr')))
    (expect-eq !>((en-iso:orr ahead)) !>((gs:orr (snag 1 writes) 'value')))
    (expect-eq !>((en-iso:orr (add ahead ~d1))) !>((gs:orr (snag 1 writes) 'until')))
  ==
++  test-plan-activities
  =/  ahead=@da  (add now ~d7)
  =/  loc=[k=@t v=json]  ['location' s+'the studio']
  =/  all=(list loaded:orr)
    :~  (mkb 'situation/2026-09-04-ballet' %situation 'Ballet' ~ ~[['started' s+'2026-09-04T15:00:00Z'] loc] now)
        (mkb 'situation/2026-09-11-ballet' %situation 'Reminder: Ballet' ~ ~[['started' s+'2026-09-11T15:00:00Z'] ['participants' (pairs:enjs:format ~[['ref' s+'person/mira']])]] now)
        (mkb 'situation/2026-09-25-ballet' %situation 'Ballet' ~ ~[['started' s+(en-iso:orr ahead)]] now)
        (mkb 'situation/2026-09-05-tap' %situation 'Tap' ~ ~ now)
        (mkb 'situation/2026-09-01-trip' %situation 'Trip' ~ ~ now)
    ==
  =/  got  (plan-activities:orr all (sy ~['participants']) now 3)
  =/  first=json  (snag 0 ops.got)
  =/  bodies=(list json)  (ga:orr first 'bodies')
  =/  rows=(list json)  (ga:orr first 'observations')
  ;:  weld
    (expect-eq !>(`(list @t)`~['activity/ballet']) !>(`(list @t)`made.got))
    (expect-eq !>(`(list @t)`~['observe' 'delete-body' 'delete-body' 'delete-body']) !>((ops-of ops.got)))
    (expect-eq !>('Ballet') !>((gs:orr (snag 0 bodies) 'name')))
    (expect-eq !>(`(list @t)`~['Reminder: Ballet']) !>((strings:orr (ga:orr (snag 0 bodies) 'aliases'))))
    %+  expect-eq
      !>(`(list @t)`~['status' 'last' 'last' 'last' 'next' 'location' 'participants'])
      !>((turn rows |=(r=json (gs:orr r 'attr'))))
    (expect-eq !>('2026-09-04T15:00:00Z') !>((gs:orr (snag 0 rows) 'at')))
    (expect-eq !>((en-iso:orr ahead)) !>((gs:orr (snag 4 rows) 'value')))
    (expect-eq !>('situation/2026-09-04-ballet') !>((gs:orr (snag 1 ops.got) 'id')))
    ::  once the activity exists, no body rides along
    (expect-eq !>(0) !>((lent (ga:orr (snag 0 ops:(plan-activities:orr [(mkb 'activity/ballet' %activity 'Ballet' ~ ~ now) all] ~ now 3)) 'bodies'))))
    ::  two occurrences are not an activity
    (expect-eq !>(0) !>((lent ops:(plan-activities:orr all ~ now 4))))
  ==
++  test-plan-participants
  =/  all=(list loaded:orr)
    :~  (mkb 'person/mira-quill' %person 'Mira Quill' ~ ~ now)
        (mkb 'activity/ballet' %activity 'Mira- Ballet/Tap' ~ ~[['participants' (pairs:enjs:format ~[['ref' s+'person/mira-quill']])]] now)
        (mkb 'situation/2026-10-01-felix-birthday' %situation 'Felix Birthday' ~ ~ now)
        (mkb 'situation/2026-10-02-felix-fencing' %situation 'Felix Fencing Lesson' ~ ~ now)
        (mkb 'situation/2026-10-03-trip' %situation 'Trip to Boston' ~ ~ now)
    ==
  =/  got  (plan-participants:orr all (sy ~['participants']) now)
  =/  op=json  (snag 0 ops.got)
  ;:  weld
    (expect-eq !>(1) !>(made.got))
    (expect-eq !>(2) !>(rows.got))
    (expect-eq !>('person/felix') !>((gs:orr (snag 0 (ga:orr op 'bodies')) 'id')))
    %+  expect-eq
      !>(`(list @t)`~['situation/2026-10-01-felix-birthday' 'situation/2026-10-02-felix-fencing'])
      !>((turn (ga:orr op 'observations') |=(r=json (gs:orr r 'subject'))))
    (expect-eq !>('person/felix') !>((gs:orr (gj:orr (snag 1 (ga:orr op 'observations')) 'value') 'ref')))
  ==
++  test-plan-people
  =/  all=(list loaded:orr)
    :~  (mkb 'person/me' %person 'me' ~ ~[['email' s+'Me@x.org']] now)
        (mkb 'person/dana' %person 'dana' ~ ~ (sub now ~d9))
        (mkb 'org/dana-quill' %org 'Dana Quill' ~ ~ now)
        (mkb 'person/d-quill' %person 'D. Quill' ~ ~[['email' s+'me@x.org']] now)
        (mkb 'org/quill-bank' %org 'Quill Bank' ~ ~ now)
    ==
  =/  got  (plan-people:orr all ~ now)
  ;:  weld
    (expect-eq !>(2) !>((lent got)))
    (expect-eq !>(`[@t @t @t]`['person/d-quill' 'person/me' 'same me@x.org']) !>((snag 0 got)))
    (expect-eq !>(`[@t @t @t]`['org/dana-quill' 'person/dana' 'the names match: dana and Dana Quill']) !>((snag 1 got)))
  ==
++  test-people-ops
  =/  pay
    |=  [f=@t i=@t]
    ^-  json
    (pairs:enjs:format ~[['from' s+f] ['into' s+i]])
  =/  acts=(list [id=@ta a=action:orr])
    :~  ['a1' [%merge 'Merge org/a into person/a' (pay 'org/a' 'person/a') ~ ~ 'reconcile' now %dismissed 'no' ~]]
        ['a2' [%merge 'Merge org/b into person/b' (pay 'org/b' 'person/b') ~ ~ 'reconcile' now %done '' ~]]
        ['a3' [%merge 'Merge org/c into person/c' (pay 'org/c' 'person/c') ~ ~ 'reconcile' now %proposed '' ~]]
        ['a4' [%merge 'Merge org/gone into person/x' (pay 'org/gone' 'person/x') ~ ~ 'reconcile' now %proposed '' ~]]
    ==
  =/  props=(list [from=@t into=@t why=@t])
    :~  ['org/a' 'person/a' 'names']
        ['org/b' 'person/b' 'names']
        ['org/c' 'person/c' 'names']
        ['org/d' 'person/d' 'names']
    ==
  =/  all=(list loaded:orr)
    %+  turn  ~['org/a' 'person/a' 'org/b' 'person/b' 'org/c' 'person/c' 'org/d' 'person/d' 'person/x']
    |=(id=@t (mkb id ?:(=('org/' (end [3 4] id)) %org %person) id ~ ~ now))
  =/  got  (people-ops:orr props acts now)
  =/  full  (people-pass:orr all acts ~ now)
  ;:  weld
    (expect-eq !>(`(list @t)`~['merge' 'act']) !>((ops-of ops.got)))
    (expect-eq !>(1) !>(proposed.got))
    (expect-eq !>('org/b') !>((gs:orr (snag 0 ops.got) 'from')))
    (expect-eq !>('Merge org/d into person/d') !>((gs:orr (gj:orr (snag 1 ops.got) 'action') 'title')))
    (expect-eq !>('reconcile') !>((gs:orr (gj:orr (snag 1 ops.got) 'action') 'by')))
    ::  the fixture's bodies are named by id, so nothing matches: only the stale dismissal
    (expect-eq !>(`(list @t)`~['set-action']) !>((ops-of ops.full)))
    (expect-eq !>('a4') !>((gs:orr (snag 0 ops.full) 'id')))
    (expect-eq !>(`(list [@ta @t @t])`~[['a2' 'org/b' 'person/b']]) !>((approved-merges:orr [['a2' [%merge 'x' (pay 'org/b' 'person/b') ~ ~ 'u' now %approved '' ~]] acts])))
  ==
++  test-plan-prune
  =/  old=@da  (sub now ~d100)
  =/  all=(list loaded:orr)
    :~  (mkb 'situation/2026-06-01-old' %situation 'Old' ~ ~[['ended' s+(en-iso:orr old)] ['status' s+'closed']] old)
        (mkb 'situation/2026-09-10-recent' %situation 'Recent' ~ ~[['ended' s+'2026-09-10T15:00:00Z'] ['status' s+'closed']] now)
        (mkb 'situation/2026-06-01-open' %situation 'Open' ~ ~[['ended' s+(en-iso:orr old)]] old)
    ==
  ;:  weld
    (expect-eq !>(`(list @t)`~['situation/2026-06-01-old']) !>(`(list @t)`(plan-prune:orr all ~ now 90)))
    (expect-eq !>(`(list @t)`~) !>(`(list @t)`(plan-prune:orr all ~ now 0)))
  ==
++  test-micro-of
  ;:  weld
    (expect-eq !>(22.900) !>((micro-of:orr '0.0229')))
    (expect-eq !>(22) !>((micro-of:orr '2.29e-05')))
    (expect-eq !>(2.000.000) !>((micro-of:orr '2')))
    (expect-eq !>(1.500.000) !>((micro-of:orr '1.5E+0')))
    (expect-eq !>(0) !>((micro-of:orr '')))
  ==
++  test-urgent
  =/  c=config:gen  (de-config:gen (jo '{"max_urgent": 2}'))
  =/  spent=json  (jo '{"day": "2026-09-18", "urgent_today": 2}')
  =/  fresh=json  (jo '{"day": "2026-09-17", "urgent_today": 2}')
  =/  parts=(list @t)  ~['a' 'b' 'clock']
  =/  got=(list @t)  (urgent-parts:gen parts ~['situation/x'])
  ;:  weld
    (expect !>((urgent-held:gen c spent now)))
    (expect !>(!(urgent-held:gen c fresh now)))
    (expect !>(!(urgent-held:gen c (jo '{}') now)))
    (expect-eq !>(4) !>((lent got)))
    (expect-eq !>('clock') !>((rear got)))
    (expect !>(?=(^ (find "situation/x" (trip (snag 2 got))))))
    (expect-eq !>(1) !>((lent (urgent-parts:gen ~ ~))))
  ==
--
