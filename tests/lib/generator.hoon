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
    (expect !>(!(restates:gen 'Plan Milo\'s birthday' 'Milo Birthday')))
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
        (sit 'situation/2026-09-18-soon' ~[['starts' '2026-09-18T09:00:00Z']] ago)
        (sit 'situation/2026-09-16-ongoing' ~[['started' '2026-09-16T09:00:00Z']] ago)
        (sit 'situation/2026-09-05-trip' ~[['started' '2026-09-05']] ago)
    ==
  =/  got  (plan-retire:orr all ~ now ~d30)
  ;:  weld
    %+  expect-eq
      !>(`(list @t)`~['situation/2026-09-10-dentist' 'situation/2026-09-01-trip' 'situation/2026-07-01-stale' 'situation/2026-09-10-fresh' 'situation/2026-09-05-trip'])
      !>(`(list @t)`(turn got |=([id=@t *] id)))
    (expect-eq !>(~2026.9.10..15.00.00) !>(at:(snag 0 got)))
    (expect-eq !>(~2026.9.8..15.00.00) !>(at:(snag 1 got)))
    (expect-eq !>(ago) !>(at:(snag 2 got)))
    (expect-eq !>('ended 2026-09-10T15:00:00Z') !>(why:(snag 0 got)))
    ::  a scheduled event with no end is over six hours after it starts
    (expect-eq !>(~2026.9.10..21.00.00) !>(at:(snag 3 got)))
    (expect-eq !>('scheduled for 2026-09-10T15:00:00Z with no end') !>(why:(snag 3 got)))
    ::  a trip whose start is a bare date closes a week on
    (expect-eq !>(~2026.9.12) !>(at:(snag 4 got)))
  ==
++  test-plan-expire
  =/  thing
    |=  [id=@t st=@t at=@da]
    ^-  loaded:orr
    :+  id  [%thing 'x' ~ now ~]
    ~[['status-row' [id 'status' s+st at ~ 100 ['mail' 'm1'] 'mail' at | '']]]
  =/  all=(list loaded:orr)
    :~  (thing 'thing/order-1' 'out for delivery' (sub now ~d4))
        (thing 'thing/order-2' 'Out for delivery' (sub now ~d1))
        (thing 'thing/order-3' 'shipped' (sub now ~d20))
        (thing 'thing/order-4' 'shipped' (sub now ~d10))
        (thing 'thing/order-5' 'delivered' (sub now ~d20))
        (thing 'thing/car' 'at the shop' (sub now ~d20))
        (sit 'situation/2026-09-01-trip' ~[['status' 'shipped']] (sub now ~d20))
    ==
  =/  got  (plan-expire:orr all ~ now)
  =/  ops=(list json)  (expire-ops:orr got)
  =/  rows=(list json)  (ga:orr (snag 0 ops) 'observations')
  ;:  weld
    (expect-eq !>(`(list @t)`~['thing/order-1' 'thing/order-3']) !>(`(list @t)`(turn got |=([id=@t *] id))))
    (expect-eq !>((sub now ~d1)) !>(at:(snag 0 got)))
    (expect-eq !>((sub now ~d6)) !>(at:(snag 1 got)))
    (expect !>((has-sub why:(snag 0 got) 'out for delivery since')))
    (expect !>((has-sub why:(snag 0 got) 'presumed delivered')))
    (expect-eq !>('delivered') !>((gs:orr (snag 0 rows) 'value')))
    (expect-eq !>(60) !>((fall (gn:orr (snag 0 rows) 'conf') 0)))
    (expect-eq !>('retire') !>((gs:orr (snag 0 rows) 'by')))
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
++  test-tg-config
  =/  bare=tg-config:orr  (de-tg-config:orr (jo '{}'))
  =/  full=tg-config:orr
    %-  de-tg-config:orr
    %-  jo
    '{"enabled": true, "token": "123:abc", "secret": "s", "chats": [1001, "-42"], "people": {"1001": "person/me"}, "gate": 0.3, "escalate": 0.6, "max_daily_messages": 20, "model": "x/y", "public_url": "https://ship.example"}'
  =/  shown=json  (en-tg-config-masked:orr full)
  ;:  weld
    (expect-eq !>(|) !>(enabled.bare))
    (expect-eq !>('https://api.telegram.org') !>(api-url.bare))
    (expect-eq !>(500) !>(max-daily.bare))
    (expect-eq !>(30) !>(gate.bare))
    (expect-eq !>(60) !>(escalate.bare))
    (expect !>((~(has in chats.full) '1001')))
    (expect !>((~(has in chats.full) '-42')))
    (expect-eq !>(`(unit @t)`[~ 'person/me']) !>((~(get by people.full) '1001')))
    (expect-eq !>(20) !>(max-daily.full))
    (expect-eq !>(`json`~) !>((gj:orr shown 'token')))
    (expect-eq !>(`json`b+&) !>((gj:orr shown 'token_set')))
    (expect-eq !>(`json`b+&) !>((gj:orr shown 'secret_set')))
    (expect-eq !>('x/y') !>((gs:orr shown 'model')))
  ==
++  test-tg-message
  =/  up=json  (jo '{"update_id": 7, "message": {"message_id": 13, "date": 1789660800, "chat": {"id": -1001}, "from": {"id": 42}, "text": "  hi there "}}')
  =/  biz=json  (jo '{"update_id": 8, "business_message": {"message_id": 2, "date": 1789660800, "business_connection_id": "c1", "chat": {"id": 55}, "from": {"id": 55}, "text": "yo"}}')
  =/  got=(unit tg-msg:orr)  (tg-message:orr up)
  ;:  weld
    (expect !>(?=(^ got)))
    (expect-eq !>('-1001') !>(chat:(need got)))
    (expect-eq !>('42') !>(from:(need got)))
    (expect-eq !>('hi there') !>(text:(need got)))
    (expect-eq !>('13') !>(mid:(need got)))
    (expect-eq !>('') !>(business:(need got)))
    (expect-eq !>('2026-09-17T16:00:00Z') !>((en-iso:orr at:(need got))))
    (expect-eq !>('c1') !>(business:(need (tg-message:orr biz))))
    (expect-eq !>(*(unit tg-msg:orr)) !>((tg-message:orr (jo '{"update_id": 9, "edited_message": {}}'))))
    (expect-eq !>(*(unit tg-msg:orr)) !>((tg-message:orr (jo '{"update_id": 10, "message": {"message_id": 1, "date": 1, "text": "x"}}'))))
    (expect-eq !>(`source:orr`['chat' 'telegram/-1001/13']) !>((tg-source:orr (need got))))
  ==
++  test-tg-window
  =/  m1=tg-msg:orr  ['1001' '42' 'first' (sub now ~h2) '1' '']
  =/  m2=tg-msg:orr  ['1001' '42' 'second' (sub now ~h1) '2' '']
  =/  old=tg-msg:orr  ['1001' '42' 'stale' (sub now ~d2) '0' '']
  =/  cmd=tg-msg:orr  ['1001' '42' '/status x' now '3' '']
  =/  w=json  (tg-remember:orr (jo '{}') old 'person/me' (sub now ~d2))
  =.  w  (tg-remember:orr w m1 'person/me' (sub now ~h2))
  =.  w  (tg-remember:orr w m2 'person/me' (sub now ~h1))
  =.  w  (tg-remember:orr w cmd 'person/me' now)
  =/  win  (tg-window:orr w '1001')
  =/  six=json
    %+  roll  (gulf 1 6)
    |=  [n=@ud acc=json]
    (tg-remember:orr acc ['9' '42' (crip (a-co:co n)) now (crip (a-co:co n)) ''] 'person/me' now)
  ;:  weld
    ::  the stale one aged out, the command never went in
    (expect-eq !>(`(list @t)`~['telegram/1001/1' 'telegram/1001/2']) !>((turn win |=([id=@t *] id))))
    (expect-eq !>('second') !>(text:(rear win)))
    (expect-eq !>('person/me') !>(who:(rear win)))
    (expect-eq !>(5) !>((lent (tg-window:orr six '9'))))
    (expect-eq !>('2') !>(text:(snag 0 (tg-window:orr six '9'))))
    (expect-eq !>(`(list [@t @t @t @t])`~) !>((tg-window:orr w '2')))
  ==
++  test-reader-prompt
  =/  schema=json
    %-  jo
    '{"kinds": {"person": {"attrs": ["status", "location"], "notes": {"status": "what they are doing"}}, "situation": {"attrs": ["status"]}}, "actions": ["task", "note", "message", "calendar"], "payloads": {"calendar": {"title": "required", "starts": "required: ISO 8601 UTC"}, "message": {"via": "required: one of telegram, mail, chat", "to": "required: the body id", "text": "required"}, "note": {"text": "required"}}}'
  =/  all=(list loaded:orr)
    :~  (mkb 'person/me' %person 'me' ~['I'] ~ now)
        (mkb 'person/sarah' %person 'Sarah' ~['wife'] ~ now)
        (mkb 'situation/2026-05-01-old' %situation 'Old' ~ ~[['status' s+'closed'] ['ended' s+'2026-05-01T00:00:00Z']] (sub now ~d100))
        (mkb 'situation/2026-09-10-fresh' %situation 'Fresh' ~ ~[['status' s+'closed'] ['ended' s+'2026-09-10T00:00:00Z']] now)
    ==
  =/  ctx=reader-ctx:orr  (reader-context:orr all schema now)
  =/  rows=(list window-row:orr)
    :~  ['telegram/1/1' '2026-09-17T16:00:00Z' 'person/me' 'jury duty tomorrow' &]
        ['telegram/1/2' '2026-09-17T16:10:00Z' 'person/me' 'home now, car is at the shop' |]
    ==
  =/  p=tape  (trip (reader-prompt:orr rows ctx 'America/New_York'))
  ;:  weld
    (expect-eq !>(`(list @t)`~['task' 'calendar' 'message']) !>(kinds.ctx))
    (expect-eq !>(3) !>((lent bodies.ctx)))
    (expect !>(?=(^ (find "person/sarah | Sarah | wife" p))))
    (expect !>(?=(^ (find "Channel: telegram" p))))
    (expect !>(?=(^ (find "person: status, location" p))))
    (expect !>(?=(^ (find "person.status: what they are doing" p))))
    (expect !>(?=(^ (find "Action kinds you may propose: task, calendar, message" p))))
    (expect !>(?=(^ (find "calendar payload: \{\"title\":\"required\"" p))))
    (expect !>(?=(^ (find "--- context telegram/1/1 | 2026-09-17T12:00:00-04:00 | from person/me" p))))
    (expect !>(?=(^ (find "New messages, oldest first:" p))))
    (expect !>(?=(^ (find "--- message telegram/1/2 | 2026-09-17T12:10:00-04:00 | from person/me" p))))
    (expect !>(?=(~ (find "situation/2026-05-01-old" p))))
    (expect !>(?=(^ (find "situation/2026-09-10-fresh" p))))
    (expect-eq !>("Answer with the JSON object.") !>((slag (sub (lent p) 28) p)))
    ::  winter is standard time, and a zone the table does not name stays UTC
    (expect-eq !>('2026-01-15T11:00:00-05:00') !>((local-iso:orr '2026-01-15T16:00:00Z' 'America/New_York')))
    (expect-eq !>('2026-07-04T11:00:00+01:00') !>((local-iso:orr '2026-07-04T10:00:00Z' 'Europe/London')))
    (expect-eq !>('2026-01-04T10:00:00+00:00') !>((local-iso:orr '2026-01-04T10:00:00Z' 'Europe/London')))
    (expect-eq !>('2026-09-17T16:00:00Z') !>((local-iso:orr '2026-09-17T16:00:00Z' 'Mars/Olympus')))
  ==
::  ==  the reader's validation
::
++  tg-ctx
  ^-  reader-ctx:orr
  :*  :~  ['person/me' 'me' ~['I']]
          ['person/sarah' 'Sarah' ~['wife']]
          ['place/home' 'Home' ~]
          ['thing/subaru' 'the Subaru' ~['the car']]
          ['situation/2026-09-19-x' 'the x situation' ~]
      ==
      (my ~[['person' `(list @t)`~['status' 'location' 'health']] ['thing' `(list @t)`~['status' 'location']] ['situation' `(list @t)`~['status' 'starts' 'location']]])
      ~
      'person/me'
      ~['task' 'calendar' 'message']
      %-  my
      :~  ['calendar' (jo '{"title": "required", "starts": "required: ISO 8601 UTC", "ends": "optional: ISO 8601 UTC", "location": "optional"}')]
          ['message' (jo '{"via": "required: one of telegram, mail, chat", "to": "required: the body id of the person", "text": "required"}')]
      ==
  ==
++  tg-rows
  ^-  (list window-row:orr)
  :~  ['telegram/1/1' '2026-09-17T16:00:00Z' 'person/me' 'jury duty tomorrow' &]
      ['telegram/1/2' '2026-09-17T16:10:00Z' 'person/me' 'home now, car is at the shop; dinner with sarah friday at 8 at the usual place' |]
  ==
++  test-validate-reader
  =/  answer=json
    %-  jo
    '{"bodies": [{"id": "place/johns-machine-shop", "name": "John\'s Machine Shop"}, {"id": "person/sara", "name": "Sarah"}, {"id": "Person/Me", "aliases": ["the boss"]}, {"id": "cat/x", "name": "x"}], "observations": [{"subject": "person/me", "attr": "location", "value": {"ref": "place/home"}, "conf": 80, "message": "telegram/1/2"}, {"subject": "person/me", "attr": "mood", "value": "tired", "message": "telegram/1/2"}, {"subject": "person/me", "attr": "status", "value": "on jury duty", "message": "telegram/1/1"}, {"subject": "thing/subaru", "attr": "status", "value": "at the shop", "message": "telegram/1/2"}, {"subject": "person/sara", "attr": "status", "value": "x", "message": "telegram/1/2"}, {"subject": "person/me", "attr": "income", "value": 5, "message": "telegram/1/2"}, {"subject": "situation/2026-09-19-x", "attr": "status", "value": "upcoming", "message": "telegram/1/2"}], "actions": [{"kind": "calendar", "title": "Dinner with Sarah", "about": ["person/sarah"], "payload": {"title": "Dinner with Sarah", "starts": "2026-09-19T20:00:00-04:00", "ends": "2026-11-01T00:00:00Z", "location": "the usual place"}, "message": "telegram/1/2"}, {"kind": "message", "title": "Tell Sarah", "payload": {"via": "Telegram", "to": "person/sara", "text": "hi"}, "message": "telegram/1/2"}, {"kind": "home", "title": "Porch", "payload": {"service": "x"}, "message": "telegram/1/2"}, {"kind": "task", "title": "Call the shop", "about": ["thing/subaru", "org/nope"], "due": "2026-09-18", "message": "telegram/1/2"}]}'
  =/  got=tg-facts:orr  (validate-reader:orr answer tg-rows tg-ctx)
  ;:  weld
    ::  bodies: the shop is new and kept (grounding decides later), sara is Sarah, me gains an alias, cat is no kind
    (expect-eq !>(`(list @t)`~['place/johns-machine-shop' 'person/me']) !>((turn bodies.got |=(b=json (gs:orr b 'id')))))
    (expect-eq !>(`(list @t)`~['the boss']) !>((strings:orr (ga:orr (snag 1 bodies.got) 'aliases'))))
    (expect !>((lien notes.got |=(n=@t =(n 'person/sara is person/sarah')))))
    ::  observations: mood is a sink, the context message yields nothing, income is unlisted, an upcoming status goes
    (expect-eq !>(`(list @t)`~['location' 'status' 'status']) !>((turn obs.got |=(o=json (gs:orr o 'attr')))))
    (expect-eq !>('person/sarah') !>((gs:orr (snag 2 obs.got) 'subject')))
    (expect-eq !>('2026-09-17T16:10:00Z') !>((gs:orr (snag 0 obs.got) 'at')))
    (expect-eq !>(80) !>((need (gn:orr (snag 0 obs.got) 'conf'))))
    (expect-eq !>(70) !>((need (gn:orr (snag 1 obs.got) 'conf'))))
    (expect !>((lien notes.got |=(n=@t ?=(^ (find "income" (trip n)))))))
    (expect !>((lien notes.got |=(n=@t ?=(^ (find "a situation is open, closed or cancelled" (trip n)))))))
    ::  actions: the plan stands with ends dropped, the message via is lower-cased and to canonised, home is not a reader's kind, the task's about keeps only known bodies
    (expect-eq !>(`(list @t)`~['calendar' 'message' 'task']) !>((turn acts.got |=(a=json (gs:orr a 'kind')))))
    (expect-eq !>(`json`~) !>((gj:orr (gj:orr (snag 0 acts.got) 'payload') 'ends')))
    (expect-eq !>('the usual place') !>((gs:orr (gj:orr (snag 0 acts.got) 'payload') 'location')))
    (expect-eq !>('2026-09-20T00:00:00Z') !>((gs:orr (gj:orr (snag 0 acts.got) 'payload') 'starts')))
    (expect-eq !>('telegram') !>((gs:orr (gj:orr (snag 1 acts.got) 'payload') 'via')))
    (expect-eq !>('person/sarah') !>((gs:orr (gj:orr (snag 1 acts.got) 'payload') 'to')))
    (expect-eq !>(`(list @t)`~['thing/subaru']) !>((strings:orr (ga:orr (snag 2 acts.got) 'about'))))
    (expect-eq !>('2026-09-18T00:00:00Z') !>((gs:orr (snag 2 acts.got) 'due')))
    (expect-eq !>('telegram/1/2') !>((gs:orr (snag 2 acts.got) 'message')))
  ==
::  +conf: a confidence the model wrote as a string or a fraction is still a
::  number, as python's int() reads it
++  test-reader-conf
  =/  answer=json
    %-  jo
    '{"bodies": [], "observations": [{"subject": "person/me", "attr": "status", "value": "home", "conf": "80", "message": "telegram/1/2"}, {"subject": "person/me", "attr": "location", "value": {"ref": "place/home"}, "conf": 80.5, "message": "telegram/1/2"}], "actions": []}'
  =/  got=tg-facts:orr  (validate-reader:orr answer tg-rows tg-ctx)
  ;:  weld
    (expect-eq !>(80) !>((need (gn:orr (snag 0 obs.got) 'conf'))))
    (expect-eq !>(80) !>((need (gn:orr (snag 1 obs.got) 'conf'))))
  ==
++  test-plan-problem
  =/  p  |=(t=@t ^-((map @t json) =/(j=json (jo t) ?:(?=([%o *] j) p.j ~))))
  =/  at=@t  '2026-09-19T12:00:00Z'
  ;:  weld
    (expect-eq !>(`(unit @t)`[~ 'the message fixes no time']) !>((plan-problem:orr (p '{"title": "Dinner", "starts": "2026-09-25T20:00:00Z"}') 'we should get dinner sometime' at)))
    (expect-eq !>(`(unit @t)`[~ 'the title is not in the message\'s words']) !>((plan-problem:orr (p '{"title": "Haircut", "starts": "2026-09-22T14:30:00Z"}') 'dentist tuesday at 2:30' at)))
    (expect-eq !>(`(unit @t)`[~ 'starts is not within the year ahead of the message']) !>((plan-problem:orr (p '{"title": "Dentist", "starts": "2027-11-22T14:30:00Z"}') 'dentist tuesday at 2:30' at)))
    (expect-eq !>(*(unit @t)) !>((plan-problem:orr (p '{"title": "Dentist", "starts": "2026-09-22T14:30:00Z"}') 'dentist tuesday at 2:30' at)))
    ::  a time with no seconds is a time, as python's fromisoformat has it
    (expect-eq !>(*(unit @t)) !>((plan-problem:orr (p '{"title": "Dentist", "starts": "2026-09-22T14:30"}') 'dentist tuesday at 2:30' at)))
    (expect !>((fixes-a-time:orr 'see you tonight')))
    (expect !>((fixes-a-time:orr 'on the 3rd')))
    (expect !>((fixes-a-time:orr 'Sep 12 works')))
    (expect !>(!(fixes-a-time:orr 'sometime soon')))
  ==
::  ==  the reader's grounding
::
++  test-ground
  =/  answer=json
    %-  jo
    '{"bodies": [{"id": "place/johns-machine-shop", "name": "John\'s Machine Shop"}, {"id": "place/home", "aliases": ["the house", "next door"]}], "observations": [{"subject": "person/me", "attr": "location", "value": {"ref": "place/home"}, "conf": 80, "message": "telegram/1/2"}, {"subject": "thing/subaru", "attr": "location", "value": {"ref": "place/johns-machine-shop"}, "message": "telegram/1/2"}, {"subject": "thing/subaru", "attr": "status", "value": "at the shop", "message": "telegram/1/2"}, {"subject": "person/sarah", "attr": "status", "value": "on jury duty", "message": "telegram/1/2"}, {"subject": "person/me", "attr": "status", "value": "on jury duty", "message": "telegram/1/2"}, {"subject": "person/me", "attr": "health", "value": "covid positive", "message": "telegram/1/2"}], "actions": []}'
  =/  facts=tg-facts:orr  (validate-reader:orr answer tg-rows tg-ctx)
  =/  got=tg-facts:orr  (ground:orr facts tg-rows tg-ctx)
  ;:  weld
    ::  the message names sarah and never the author, so what it says of the
    ::  author is about someone else; the car and the shop it does not name
    (expect-eq !>(`(list @t)`~) !>((turn obs.got |=(o=json (gs:orr o 'attr')))))
    (expect !>((lien notes.got |=(n=@t =(n 'dropped person/me.location: the message is about someone else')))))
    (expect !>((lien notes.got |=(n=@t =(n 'dropped person/me.health: the message is about someone else')))))
    (expect !>((lien notes.got |=(n=@t =(n 'dropped thing/subaru.location: not the author and not named in the message')))))
    ::  sarah the message does name, but her status is the earlier message's words
    (expect !>((lien notes.got |=(n=@t =(n 'dropped person/sarah.status: read from the earlier messages')))))
    ::  no fact is left about the shop; home keeps no alias the message does not use
    (expect-eq !>(`(list json)`~) !>(bodies.got))
    (expect !>((lien notes.got |=(n=@t =(n 'dropped body place/johns-machine-shop: no fact is about it')))))
    (expect !>((lien notes.got |=(n=@t =(n 'dropped new names for place/home: not in the message')))))
  ==
++  test-ground-someone-else
  =/  rows=(list window-row:orr)  ~[['telegram/1/3' '2026-09-17T16:20:00Z' 'person/sarah' 'grandpa\'s flight got cancelled' |]]
  =/  facts=tg-facts:orr
    %-  validate-reader:orr  :_  [rows tg-ctx]
    (jo '{"bodies": [], "observations": [{"subject": "person/sarah", "attr": "status", "value": "flight cancelled", "message": "telegram/1/3"}], "actions": []}')
  =/  got=tg-facts:orr  (ground:orr facts rows tg-ctx)
  =/  ctx=reader-ctx:orr  tg-ctx
  ;:  weld
    (expect-eq !>(0) !>((lent obs.got)))
    (expect !>((lien notes.got |=(n=@t =(n 'dropped person/sarah.status: the message is about someone else')))))
    (expect-eq !>(' car died on route 9 ') !>((words:orr 'Car died, on Route 9!')))
    (expect !>((~(has in (named-in:orr 'home now' bodies.ctx)) 'place/home')))
    (expect !>((~(has in (named-in:orr 'sarah called' bodies.ctx)) 'person/sarah')))
    (expect !>(!(~(has in (named-in:orr 'me too' bodies.ctx)) 'person/me')))
  ==
::  what grounding keeps: a fact the message bears out, a bare date fixed to
::  the message's hour, a diagnosis moved to health, a new body a fact is about
++  test-ground-keeps
  =/  rows=(list window-row:orr)
    :~  ['telegram/2/1' '2026-09-18T15:00:00Z' 'person/me' 'i tested positive for covid, car is at john\'s machine shop' |]
        ['telegram/2/2' '2026-09-18T15:05:00Z' 'person/me' 'is the car at the shop?' |]
    ==
  =/  answer=json
    %-  jo
    '{"bodies": [{"id": "place/johns-machine-shop", "name": "John\'s Machine Shop"}], "observations": [{"subject": "person/me", "attr": "status", "value": "covid positive", "message": "telegram/2/1"}, {"subject": "person/me", "attr": "location", "value": {"ref": "place/johns-machine-shop"}, "at": "2026-09-18", "message": "telegram/2/1"}, {"subject": "person/me", "attr": "location", "value": "Paris", "message": "telegram/2/1"}, {"subject": "person/me", "attr": "status", "value": "at the shop", "message": "telegram/2/2"}, {"subject": "person/me", "attr": "location", "value": {"ref": "place/home"}, "message": "telegram/2/1"}], "actions": []}'
  =/  facts=tg-facts:orr  (validate-reader:orr answer rows tg-ctx)
  =/  got=tg-facts:orr  (ground:orr facts rows tg-ctx)
  ;:  weld
    (expect-eq !>(`(list @t)`~['health' 'location']) !>((turn obs.got |=(o=json (gs:orr o 'attr')))))
    (expect !>((lien notes.got |=(n=@t =(n 'moved person/me.status to health: a medical fact')))))
    ::  a bare date is the message's hour, not midnight
    (expect-eq !>('2026-09-18T15:00:00Z') !>((gs:orr (snag 1 obs.got) 'at')))
    (expect !>((lien notes.got |=(n=@t =(n 'dropped person/me.location: the value is not in the message')))))
    (expect !>((lien notes.got |=(n=@t =(n 'dropped person/me.status: a question states nothing')))))
    (expect !>((lien notes.got |=(n=@t =(n 'dropped person/me.location: the message does not name place/home')))))
    ::  the shop is a new body a kept fact points at
    (expect-eq !>(`(list @t)`~['place/johns-machine-shop']) !>((turn bodies.got |=(b=json (gs:orr b 'id')))))
  ==
::  ==  the urgent pass's ids and the decider's route
::
++  test-urgent-ids
  =/  o  |=([s=@t a=@t] `json`(pairs:enjs:format ~[['subject' s+s] ['attr' s+a]]))
  =/  b  |=(id=@t `json`(pairs:enjs:format ~[['id' s+id]]))
  =/  things=(list json)  ~[(o 'person/me' 'status') (o 'thing/subaru' 'status') (o 'place/shop' 'phone') (o 'thing/subaru' 'location')]
  =/  many=(list json)  (turn `(list @t)`~['thing/a' 'thing/b' 'org/c' 'place/d' 'thing/e' 'thing/f'] |=(id=@t (o id 'status')))
  ;:  weld
    ::  a situation first, from an observation or a body made alongside
    (expect-eq !>(`(list @t)`~['situation/2026-09-19-x' 'situation/2026-09-20-y']) !>((urgent-ids:orr [~[(b 'situation/2026-09-20-y')] (weld things ~[(o 'situation/2026-09-19-x' 'status')]) ~ ~ ~])))
    ::  else the things, places and orgs, unique, in order, never a person
    (expect-eq !>(`(list @t)`~['thing/subaru' 'place/shop']) !>((urgent-ids:orr [~ things ~ ~ ~])))
    (expect-eq !>(5) !>((lent (urgent-ids:orr [~ many ~ ~ ~]))))
    (expect-eq !>(`(list @t)`~) !>((urgent-ids:orr [~ ~[(o 'person/me' 'status')] ~ ~ ~])))
    (expect-eq !>('https://openrouter.ai/api/alpha/decisions') !>((decider-url:orr 'https://openrouter.ai/api/v1')))
    (expect-eq !>('http://127.0.0.1:8099/api/alpha/decisions') !>((decider-url:orr 'http://127.0.0.1:8099')))
  ==
::  ==  the decider bodies
::
++  test-decider-bodies
  =/  g=json  (gate-body:orr tg-rows tg-ctx)
  =/  st=json  (gj:orr g 'state')
  =/  e=json  (escalate-body:orr tg-rows tg-ctx ~[(jo '{"subject": "person/me", "attr": "status", "value": "stranded, waiting for a tow"}')])
  =/  s=json  (status-body:orr tg-rows ~[(jo '{"subject": "person/me", "attr": "status", "value": "on jury duty"}') (jo '{"subject": "thing/subaru", "attr": "status", "value": "broken"}') (jo '{"subject": "person/me", "attr": "status", "value": "fed up"}')])
  ;:  weld
    (expect-eq !>('home now, car is at the shop; dinner with sarah friday at 8 at the usual place') !>((gs:orr st 'message')))
    (expect-eq !>('person/me') !>((gs:orr st 'from')))
    (expect-eq !>(`(list @t)`~['jury duty tomorrow']) !>((strings:orr (ga:orr st 'earlier'))))
    ::  ranked: the bodies the message names first, then people
    (expect-eq !>('person/sarah | Sarah | wife') !>((ref-or-text:orr (snag 0 (ga:orr st 'known_bodies')))))
    (expect !>((has-key:orr (gj:orr g 'questions') 'worth_reading')))
    (expect-eq !>('noul') !>((gs:orr (gj:orr (gj:orr g 'questions') 'worth_reading') 'type')))
    (expect-eq !>('stranded, waiting for a tow') !>((gs:orr (snag 0 (ga:orr (gj:orr e 'state') 'facts')) 'value')))
    (expect !>((has-key:orr (gj:orr e 'questions') 'needs_help_now')))
    (expect !>((has-key:orr (gj:orr s 'questions') 'status_0')))
    (expect !>((has-key:orr (gj:orr s 'questions') 'status_2')))
    (expect !>(!(has-key:orr (gj:orr s 'questions') 'status_1')))
    (expect-eq !>(88) !>((noul-of:orr (jo '{"worth_reading": {"type": "noul", "noul": 0.88}}') 'worth_reading')))
    (expect-eq !>(0) !>((noul-of:orr (jo '{}') 'worth_reading')))
    (expect-eq !>(`[@t @ud]`['feeling' 95]) !>((choice-of:orr (jo '{"status_2": {"type": "choice", "choice": "feeling", "probabilities": {"feeling": 0.95}}}') 'status_2')))
  ==
::  ==  the executors (version 34)
::
++  exec-acts
  ^-  (list [id=@ta a=action:orr])
  =/  pay  |=(t=@t ^-(json (need (de:json:html t))))
  :~  ['m1' [%message 'Tell Rose' (pay '{"via": "telegram", "to": "person/rose", "text": "Dana could not call back"}') (sy ~['person/rose']) ~ 'telegram' now %approved '' ~]]
      ['m2' [%message 'Tell Bob' (pay '{"via": "mail", "to": "person/bob", "text": "hi"}') (sy ~['person/bob']) ~ 'telegram' now %approved '' ~]]
      ['m3' [%message 'Tell Eve' (pay '{"via": "telegram", "to": "person/eve", "text": "x"}') ~ ~ 'telegram' now %approved '' ~]]
      ['m4' [%message 'DM Rose' (pay '{"via": "chat", "to": "person/rose", "text": "x"}') ~ ~ 'telegram' now %approved '' ~]]
      ['m5' [%message 'Tell Ann' (pay '{"via": "telegram", "to": "person/ann", "text": "y"}') ~ ~ 'telegram' now %approved '' ~]]
      ['c1' [%calendar 'Dinner with Sarah' (pay '{"title": "Dinner with Sarah", "starts": "2026-09-25T20:00:00Z", "ends": "2026-09-25T22:00:00Z", "location": "the usual place"}') ~ ~ 'telegram' now %approved '' ~]]
      ['c2' [%calendar 'Field day' (pay '{"title": "Field day", "starts": "2026-10-03T00:00:00Z", "ends": "2026-10-04T00:00:00Z"}') ~ ~ 'telegram' now %approved '' ~]]
      ['t1' [%task 'Call the shop' (pay '{"notes": "about the brakes"}') ~ `~2026.9.30 'generator' now %approved '' ~]]
      ['t2' [%task 'Old one' ~ ~ ~ 'generator' now %proposed '' ~]]
      ['t3' [%task 'Done one' ~ ~ ~ 'generator' now %done '' ~]]
  ==
++  exec-bodies
  ^-  (list loaded:orr)
  :~  (mkb 'person/rose' %person 'Rose' ~ ~[['telegram' s+'545179154']] now)
      (mkb 'person/bob' %person 'Bob' ~ ~[['ship' s+'~sampel-palnet']] now)
      (mkb 'person/eve' %person 'Eve' ~ ~ now)
      (mkb 'person/ann' %person 'Ann' ~ ~ now)
  ==
::  the reader's people map: a Telegram user id to the body it is
++  exec-people
  ^-  (map @t @t)
  (my ~[['1001' 'person/me'] ['777' 'person/ann']])
++  test-plan-exec
  =/  plans  (plan-exec:orr exec-acts exec-bodies ~ exec-people now)
  =/  by-id  (~(gas by *(map @ta exec-plan:orr)) (turn plans |=(p=exec-plan:orr [id.p p])))
  ;:  weld
    (expect-eq !>(`(list @ta)`~['m1' 'm2' 'm3' 'm5' 'c1' 'c2' 't1']) !>((turn plans |=(p=exec-plan:orr id.p))))
    (expect-eq !>(%telegram) !>(target:(~(got by by-id) 'm1')))
    (expect-eq !>('545179154') !>(to:(~(got by by-id) 'm1')))
    (expect-eq !>('Dana could not call back') !>((gs:orr body:(~(got by by-id) 'm1') 'text')))
    (expect-eq !>('545179154') !>((gs:orr body:(~(got by by-id) 'm1') 'chat_id')))
    (expect-eq !>(%mail) !>(target:(~(got by by-id) 'm2')))
    (expect-eq !>('~sampel-palnet') !>(to:(~(got by by-id) 'm2')))
    (expect-eq !>('Tell Bob') !>((gs:orr body:(~(got by by-id) 'm2') 'subject')))
    ::  m3: no attribute and not in people, so no address; m5: no
    ::  attribute, but the people map knows the person's user id
    (expect-eq !>('') !>(to:(~(got by by-id) 'm3')))
    (expect-eq !>('person/eve has no telegram attribute and is not in people') !>(note:(~(got by by-id) 'm3')))
    (expect-eq !>('777') !>(to:(~(got by by-id) 'm5')))
    (expect-eq !>('777') !>((gs:orr body:(~(got by by-id) 'm5') 'chat_id')))
    (expect-eq !>('') !>(note:(~(got by by-id) 'm5')))
    ::  the attribute wins over the people map
    (expect-eq !>('545179154') !>(to:(~(got by (~(gas by *(map @ta exec-plan:orr)) (turn (plan-exec:orr exec-acts exec-bodies ~ (my ~[['999' 'person/rose']]) now) |=(p=exec-plan:orr [id.p p])))) 'm1')))
    (expect-eq !>(%calendar) !>(target:(~(got by by-id) 'c1')))
    (expect-eq !>('timed') !>((gs:orr body:(~(got by by-id) 'c1') 'cat')))
    (expect-eq !>('allday') !>((gs:orr body:(~(got by by-id) 'c2') 'cat')))
    (expect-eq !>(%todo) !>(target:(~(got by by-id) 't1')))
    (expect-eq !>('todo') !>((gs:orr body:(~(got by by-id) 't1') 'cat')))
  ==
++  test-event-json
  =/  c1  (snag 5 exec-acts)
  =/  c2  (snag 6 exec-acts)
  =/  t1  (snag 7 exec-acts)
  =/  ej=json  (need (event-json:orr id.c1 a.c1 'America/New_York'))
  =/  aj=json  (need (event-json:orr id.c2 a.c2 ''))
  ::  a whole day on New York's clock starts at 04:00Z in summer
  =/  ny=action:orr  a.c2(payload (jo '{"title": "Field day", "starts": "2026-10-03T04:00:00Z", "ends": "2026-10-04T04:00:00Z"}'))
  =/  nj=json  (need (event-json:orr id.c2 ny 'America/New_York'))
  =/  tj=json  (need (event-json:orr id.t1 a.t1 'America/New_York'))
  =/  meta=json  (gj:orr ej 'meta')
  ;:  weld
    (expect-eq !>('add-event') !>((gs:orr ej 'action')))
    (expect-eq !>('timed') !>((gs:orr ej 'cat')))
    (expect-eq !>('once') !>((gs:orr ej 'kind')))
    (expect-eq !>('Dinner with Sarah') !>((gs:orr meta 'name')))
    (expect-eq !>('c1') !>((gs:orr meta 'orrery')))
    (expect-eq !>(`(list @t)`~['orrery']) !>((strings:orr (ga:orr meta 'tags'))))
    (expect-eq !>('the usual place') !>((gs:orr meta 'location')))
    ::  20:00Z on 2026-09-25 is 16:00 on New York's summer clock, and
    ::  the calendar wants that clock encoded as if it were UTC
    (expect-eq !>(1.790.352.000.000) !>((need (gn:orr ej 'start_ms'))))
    (expect-eq !>(1.790.359.200.000) !>((need (gn:orr ej 'end_ms'))))
    (expect-eq !>(1.790.366.400.000) !>((need (gn:orr (need (event-json:orr id.c1 a.c1 '')) 'start_ms'))))
    (expect-eq !>('to') !>((gs:orr ej 'fin')))
    (expect-eq !>('America/New_York') !>((gs:orr ej 'zone')))
    (expect-eq !>('allday') !>((gs:orr aj 'cat')))
    (expect-eq !>(1) !>((need (gn:orr aj 'span_days'))))
    (expect-eq !>(1.790.985.600.000) !>((need (gn:orr aj 'start_ms'))))
    (expect-eq !>('allday') !>((gs:orr nj 'cat')))
    (expect-eq !>(1.790.985.600.000) !>((need (gn:orr nj 'start_ms'))))
    (expect-eq !>('todo') !>((gs:orr tj 'cat')))
    (expect-eq !>('Call the shop') !>((gs:orr (gj:orr tj 'meta') 'name')))
    (expect-eq !>('about the brakes') !>((gs:orr (gj:orr tj 'meta') 'note')))
    (expect-eq !>(1.790.726.400.000) !>((need (gn:orr tj 'due_ms'))))
    (expect-eq !>(1.790.366.400.000) !>((ms-of:orr ~2026.9.25..20.00.00)))
    (expect-eq !>(~2026.9.25..20.00.00) !>((da-of-ms:orr 1.790.366.400.000)))
    ::  a time before the epoch is 0, not an underflow
    (expect-eq !>(0) !>((ms-of:orr ~1969.12.31)))
    (expect-eq !>(0) !>((ms-of:orr ~1970.1.1)))
  ==
++  test-todos-of
  =/  cal=json
    %-  jo
    '''
    {"title": "mine", "zone": "America/New_York", "calendars": [],
     "events": [
       {"id": "e1", "cat": "todo", "meta": {"name": "Buy milk", "orrery": "a9", "tags": ["orrery"], "note": "two litres"},
        "due_ms": 1790726400000, "done_ms": null, "done": false, "uid": "e1", "etag": "x", "seq": 1},
       {"id": "e2", "cat": "todo", "meta": {"name": "Done one"}, "due_ms": null, "done_ms": 1790726400000, "done": true, "uid": "e2", "etag": "x", "seq": 1},
       {"id": "e3", "cat": "timed", "meta": {"name": "Dinner"}, "kind": "once", "start_ms": 1790366400000, "fin": "to", "end_ms": 1790373600000, "zone": "none", "count": 0, "uid": "e3", "etag": "x", "seq": 1}
     ]}
    '''
  =/  todos=(list todo:orr)  (todos-of:orr cal)
  =/  e1=todo:orr  (snag 0 todos)
  =/  e2=todo:orr  (snag 1 todos)
  ;:  weld
    (expect-eq !>(2) !>((lent todos)))
    (expect-eq !>(`[@t @t @t ? (unit @da) @t]`['e1' 'Buy milk' 'a9' | `~2026.9.30 'two litres']) !>([id name orrery done due note]:e1))
    (expect-eq !>(`[@t @t @t ? (unit @da) @t]`['e2' 'Done one' '' & ~ '']) !>([id name orrery done due note]:e2))
    ::  the whole meta rides along, for an edit to carry
    (expect-eq !>(`(list @t)`~['orrery']) !>((strings:orr (ga:orr meta.e1 'tags'))))
    (expect-eq !>('Done one') !>((gs:orr meta.e2 'name')))
  ==
++  test-plan-mirror
  =/  acts=(list [id=@ta a=action:orr])
    :~  ['a1' [%task 'Ticked on the ship' ~ ~ ~ 'generator' now %done '' ~]]
        ['a2' [%task 'Dismissed on the ship' ~ ~ ~ 'generator' now %dismissed '' ~]]
        ['a3' [%task 'Ticked in the calendar' ~ ~ ~ 'generator' now %approved '' ~]]
        ['a4' [%task 'Due moved on the ship' ~ ~ `~2026.10.5 'generator' now %approved '' ~]]
        ['a5' [%task 'In step' ~ ~ ~ 'generator' now %approved '' ~]]
    ==
  ::  e6 carries a color and a tag of the owner's, which the adoption
  ::  must keep; e4's meta is what the ship placed
  =/  todos=(list todo:orr)
    :~  ['e1' 'Ticked on the ship' 'a1' | ~ '' [%o ~]]
        ['e2' 'Dismissed on the ship' 'a2' | ~ '' [%o ~]]
        ['e3' 'Ticked in the calendar' 'a3' & ~ '' [%o ~]]
        ['e4' 'Due moved on the ship' 'a4' | `~2026.10.1 '' (jo '{"name": "Due moved on the ship", "orrery": "a4", "tags": ["orrery"]}')]
        ['e5' 'In step' 'a5' | ~ '' [%o ~]]
        ['e6' 'Buy milk' '' | `~2026.10.2 'two litres' (jo '{"name": "Buy milk", "note": "two litres", "color": "red", "tags": ["home"]}')]
        ['e7' 'Already done by hand' '' & ~ '' [%o ~]]
    ==
  =/  ops=(list mirror-op:orr)  (plan-mirror:orr todos acts now)
  =/  cal=(list json)  (murn ops |=(o=mirror-op:orr ?:(?=(%calendar -.o) `+.o ~)))
  =/  wr=(list json)  (murn ops |=(o=mirror-op:orr ?:(?=(%writer -.o) `+.o ~)))
  =/  cal-act  (turn cal |=(j=json [(gs:orr j 'action') (gs:orr j 'id')]))
  =/  e4=json  (fall (find-by cal 'e4') ~)
  =/  e6=json  (fall (find-by cal 'e6') ~)
  =/  adopted=json  (fall (find-op wr 'act') ~)
  ::  the id the writer will give the adopted action
  =/  want=@ta  (fall (bind (lift-act (gj:orr adopted 'action')) act-id:orr) '')
  ;:  weld
    (expect !>((lien cal-act |=([a=@t i=@t] &(=('done-event' a) =('e1' i))))))
    (expect !>((lien cal-act |=([a=@t i=@t] &(=('del-event' a) =('e2' i))))))
    (expect !>((lien cal-act |=([a=@t i=@t] &(=('edit-event' a) =('e4' i))))))
    (expect !>(!(lien cal-act |=([a=@t i=@t] =('e5' i)))))
    (expect !>(!(lien cal-act |=([a=@t i=@t] =('e7' i)))))
    ::  e3: the action moves to done; e6: a task is made and the todo marked
    (expect !>((lien wr |=(j=json &(=('set-action' (gs:orr j 'op')) =('a3' (gs:orr j 'id')) =('done' (gs:orr j 'status')) =('calendar' (gs:orr j 'by')))))))
    (expect !>((lien wr |=(j=json &(=('act' (gs:orr j 'op')) =('Buy milk' (gs:orr (gj:orr j 'action') 'title')))))))
    (expect !>((lien wr |=(j=json &(=('set-action' (gs:orr j 'op')) =('approved' (gs:orr j 'status')) =('calendar' (gs:orr j 'by')))))))
    (expect !>((lien cal-act |=([a=@t i=@t] &(=('edit-event' a) =('e6' i))))))
    (expect-eq !>(1) !>((lent (skim wr |=(j=json =('act' (gs:orr j 'op')))))))
    ::  the adopted action: a task by calendar, its note and due, stamped
    (expect-eq !>('task') !>((gs:orr (gj:orr adopted 'action') 'kind')))
    (expect-eq !>('calendar') !>((gs:orr (gj:orr adopted 'action') 'by')))
    (expect-eq !>('two litres') !>((gs:orr (gj:orr (gj:orr adopted 'action') 'payload') 'notes')))
    (expect-eq !>('2026-10-02T00:00:00Z') !>((gs:orr (gj:orr adopted 'action') 'due')))
    ::  the approval names the id the writer will give it
    (expect !>(!=('' want)))
    (expect !>((lien wr |=(j=json &(=('set-action' (gs:orr j 'op')) =('approved' (gs:orr j 'status')) =(want (gs:orr j 'id')))))))
    ::  e6's edit carries the whole meta, since edit-event replaces the event
    (expect-eq !>('todo') !>((gs:orr e6 'cat')))
    (expect-eq !>('Buy milk') !>((gs:orr (gj:orr e6 'meta') 'name')))
    (expect-eq !>('two litres') !>((gs:orr (gj:orr e6 'meta') 'note')))
    (expect-eq !>(want) !>((gs:orr (gj:orr e6 'meta') 'orrery')))
    ::  the owner's color and tag survive, and the orrery tag is added
    (expect-eq !>(`(list @t)`~['home' 'orrery']) !>((strings:orr (ga:orr (gj:orr e6 'meta') 'tags'))))
    (expect-eq !>('red') !>((gs:orr (gj:orr e6 'meta') 'color')))
    (expect-eq !>((ms-of:orr ~2026.10.2)) !>((need (gn:orr e6 'due_ms'))))
    ::  e4's edit moves the due to the action's and keeps the name,
    ::  with the orrery tag once
    (expect-eq !>((ms-of:orr ~2026.10.5)) !>((need (gn:orr e4 'due_ms'))))
    (expect-eq !>('Due moved on the ship') !>((gs:orr (gj:orr e4 'meta') 'name')))
    (expect-eq !>('a4') !>((gs:orr (gj:orr e4 'meta') 'orrery')))
    (expect-eq !>(`(list @t)`~['orrery']) !>((strings:orr (ga:orr (gj:orr e4 'meta') 'tags'))))
    (expect !>(!(has-key:orr (gj:orr e4 'meta') 'note')))
    ::  e1's tick carries now
    (expect-eq !>((ms-of:orr now)) !>((need (gn:orr (fall (find-by cal 'e1') ~) 'done'))))
  ==
::  ==  clean-text
::
++  test-clean-text
  =/  em=@t  (crip (tufa ~[`@c`0x2014]))
  ;:  weld
    (expect-eq !>('Rose, call me back') !>((clean-text:orr (rap 3 'Rose ' em ' call me back' ~))))
    (expect-eq !>('Rose, call me back') !>((clean-text:orr (rap 3 'Rose' em 'call me back' ~))))
    (expect-eq !>('plain') !>((clean-text:orr 'plain')))
    ::  two in a row, with or without spaces, give one comma
    (expect-eq !>('a, b') !>((clean-text:orr (rap 3 'a' em em 'b' ~))))
    (expect-eq !>('a, b') !>((clean-text:orr (rap 3 'a ' em ' ' em ' b' ~))))
  ==
++  test-route-message
  =/  m=action:orr  [%message 'Tell Rose' (jo '{"via": "telegram", "to": "person/rose", "text": "hi"}') ~ ~ 'mail' now %proposed '' ~]
  =/  got  (route-message:orr m '~sampel-palnet')
  =/  same  (route-message:orr m '')
  =/  chat  (route-message:orr m(payload (jo '{"via": "chat", "to": "person/rose", "text": "hi"}')) '~sampel-palnet')
  =/  task  (route-message:orr m(kind %task) '~sampel-palnet')
  ;:  weld
    (expect-eq !>('chat') !>((gs:orr payload.a.got 'via')))
    (expect-eq !>('via rewritten to chat: person/rose has a ship') !>(note.got))
    (expect-eq !>('telegram') !>((gs:orr payload.a.same 'via')))
    (expect-eq !>('') !>(note.same))
    (expect-eq !>('') !>(note.chat))
    (expect-eq !>('') !>(note.task))
  ==
++  test-one-of
  ::  the starter's note for via, and the note ricsul stored before it:
  ::  both go on after the list, and hold-payload must read the list alone
  =/  new=@t  'required: one of chat, telegram, mail; chat when the person has a ship, telegram only when they have none'
  =/  old=@t  'one of telegram, mail, chat; the channel the conversation is on'
  =/  shape=json
    %-  pairs:enjs:format
    :~  ['via' s+new]
        ['to' s+'required: the body id of the person, e.g. person/alice']
        ['text' s+'required: the message, short, in the owner\'s own voice. No em dashes.']
    ==
  =/  pj=json  (jo '{"via": "mail", "to": "person/rose", "text": "hi"}')
  =/  held  (hold-payload:orr ?>(?=([%o *] pj) p.pj) shape (sy ~['person/rose']) ~)
  ;:  weld
    (expect-eq !>(`(list @t)`~['chat' 'telegram' 'mail']) !>((one-of:orr new)))
    (expect-eq !>(`(list @t)`~['telegram' 'mail' 'chat']) !>((one-of:orr old)))
    (expect-eq !>(`(list @t)`~['a' 'b']) !>((one-of:orr 'one of a, or b. Then more.')))
    (expect !>(?=(%& -.held)))
    (expect-eq !>('mail') !>(?>(?=(%& -.held) (gs:orr [%o p.held] 'via'))))
  ==
++  test-reroute-on-revise
  =/  old=action:orr  [%message 'Tell Rose' (jo '{"via": "telegram", "to": "person/rose", "text": "hi"}') ~ ~ 'mail' now %proposed '' ~]
  =/  to-karl  old(payload (jo '{"via": "telegram", "to": "person/karl", "text": "hi"}'))
  =/  karl-mail  old(payload (jo '{"via": "mail", "to": "person/karl", "text": "hi"}'))
  =/  moved  (reroute-on-revise:orr old to-karl '~sampel-palnet')
  =/  worded  (reroute-on-revise:orr old karl-mail '~sampel-palnet')
  =/  same  (reroute-on-revise:orr old old(title 'Tell Rose again') '~sampel-palnet')
  =/  noship  (reroute-on-revise:orr old to-karl '')
  ;:  weld
    ::  a new recipient with a ship, and no word on the channel: rerouted
    (expect-eq !>('chat') !>((gs:orr payload.a.moved 'via')))
    (expect-eq !>('via rewritten to chat: person/karl has a ship') !>(note.moved))
    ::  the note set the channel: the owner's word stands
    (expect-eq !>('mail') !>((gs:orr payload.a.worded 'via')))
    (expect-eq !>('') !>(note.worded))
    ::  the same recipient, or one without a ship: nothing moves
    (expect-eq !>('telegram') !>((gs:orr payload.a.same 'via')))
    (expect-eq !>('') !>(note.same))
    (expect-eq !>('telegram') !>((gs:orr payload.a.noship 'via')))
  ==
++  test-revise
  =/  m=action:orr  [%message 'Tell Rose' (jo '{"via": "chat", "to": "person/rose", "text": "hi"}') (sy ~['person/rose']) ~ 'mail' now %proposed '' ~[[now %proposed 'mail']]]
  =/  got  (revise:orr m 'Tell Rose and Dana' (jo '{"via": "chat", "to": "person/rose", "text": "hi both"}') (sy ~['person/rose' 'person/dana-hill']) `(add now ~d1) 'user' (add now ~m5))
  =/  op=json  (revise-action-op:orr 'a1' 'T' (jo '{}') ~['person/rose'] ~ 'user')
  ;:  weld
    (expect-eq !>('Tell Rose and Dana') !>(title.got))
    (expect-eq !>(%proposed) !>(status.got))
    (expect-eq !>(2) !>((lent history.got)))
    (expect-eq !>([%revised 'user']) !>([status by]:(rear history.got)))
    (expect-eq !>(`(add now ~d1)) !>(due.got))
    (expect-eq !>('revise-action') !>((gs:orr op 'op')))
    (expect-eq !>('a1') !>((gs:orr op 'id')))
  ==
++  refine-ctx
  ^-  reader-ctx:orr
  =/  schema=json  starter-schema:orr
  %-  reader-context:orr
  :+  :~  (mkb 'person/rose' %person 'Rose' ~ ~[['ship' s+'~sampel-palnet']] now)
          (mkb 'person/dana-hill' %person 'Dana Hill' ~['dana'] ~ now)
      ==
    schema
  now
++  refine-act
  ^-  action:orr
  [%message 'Tell Rose' (jo '{"via": "chat", "to": "person/rose", "text": "hi"}') (sy ~['person/rose']) ~ 'mail' now %proposed '' ~[[now %proposed 'mail']]]
++  test-refine-check
  =/  good=json  (jo '{"action": {"title": "Tell Rose and Dana", "payload": {"via": "chat", "to": "person/rose", "text": "hi both"}, "about": ["person/rose", "dana"], "due": null}, "extras": [{"kind": "task", "title": "Go shopping", "payload": {"notes": "before the dinner"}, "about": ["person/rose"], "due": "2026-09-24T14:00:00Z"}], "refused": ""}')
  =/  got  (refine-check:orr good refine-act 'a1' refine-ctx now)
  =/  newbie=json  (jo '{"bodies": [{"id": "person/karl", "kind": "person", "name": "Karl", "aliases": []}], "action": {"title": "Tell Rose and Karl", "payload": {"via": "chat", "to": "person/rose", "text": "hi"}, "about": ["person/rose", "person/karl"]}, "extras": [], "refused": ""}')
  =/  nobody=json  (jo '{"action": {"title": "Tell Rose", "payload": {"via": "chat", "to": "person/rose", "text": "hi"}, "about": ["person/nobody"]}, "extras": [], "refused": ""}')
  =/  refused=json  (jo '{"refused": "no person named Karl on the ship"}')
  =/  badkind=json  (jo '{"action": {"title": "T", "payload": {"via": "chat", "to": "person/rose", "text": "x"}, "about": []}, "extras": [{"kind": "home", "title": "Lights", "payload": {}, "about": []}], "refused": ""}')
  =/  past=json  (jo '{"action": {"title": "T", "payload": {"via": "chat", "to": "person/rose", "text": "x"}, "about": []}, "extras": [{"kind": "calendar", "title": "Dinner", "payload": {"title": "Dinner", "starts": "2020-01-01T00:00:00Z"}, "about": []}], "refused": ""}')
  =/  new-got  (refine-check:orr newbie refine-act 'a1' refine-ctx now)
  =/  no-got  (refine-check:orr nobody refine-act 'a1' refine-ctx now)
  =/  ref-got  (refine-check:orr refused refine-act 'a1' refine-ctx now)
  =/  bad-got  (refine-check:orr badkind refine-act 'a1' refine-ctx now)
  =/  past-got  (refine-check:orr past refine-act 'a1' refine-ctx now)
  ::  a recipient named, not id'd, whom the answer creates
  =/  byname=json  (jo '{"bodies": [{"id": "person/karl", "kind": "person", "name": "Karl", "aliases": [" K ", ""]}], "action": {"title": "Tell Karl", "payload": {"via": "chat", "to": "Karl", "text": "hi"}, "about": ["person/karl"]}, "extras": [], "refused": ""}')
  =/  name-got  (refine-check:orr byname refine-act 'a1' refine-ctx now)
  =/  em=@t  (crip (tufa ~[`@c`0x2014]))
  =/  dashed=json
    %-  jo
    %+  rap  3
    :~  '{"action": {"title": "T", "payload": {"via": "chat", "to": "person/rose", "text": "Rose '
        em
        ' call me"}, "about": []}, "extras": [{"kind": "calendar", "title": "Dinner", "payload": {"title": "Dinner", "starts": "2026-09-25T18:00:00Z", "ends": null}, "about": []}], "refused": ""}'
    ==
  =/  dash-got  (refine-check:orr dashed refine-act 'a1' refine-ctx now)
  ::  a due written but garbled refuses rather than clearing the time
  =/  garbled=json  (jo '{"action": {"title": "T", "payload": {"via": "chat", "to": "person/rose", "text": "x"}, "about": [], "due": "tomorrowish"}, "extras": [], "refused": ""}')
  =/  garbled-got  (refine-check:orr garbled refine-act 'a1' refine-ctx now)
  ::  a created body of a kind a note may not conjure is dropped, so an
  ::  about naming it refuses
  =/  sit=json  (jo '{"bodies": [{"id": "situation/2026-09-25-dinner", "kind": "situation", "name": "Dinner", "aliases": []}], "action": {"title": "T", "payload": {"via": "chat", "to": "person/rose", "text": "x"}, "about": ["situation/2026-09-25-dinner"]}, "extras": [], "refused": ""}')
  =/  sit-got  (refine-check:orr sit refine-act 'a1' refine-ctx now)
  =/  org=json  (jo '{"bodies": [{"id": "org/acme", "kind": "org", "name": "Acme", "aliases": []}], "action": {"title": "T", "payload": {"via": "chat", "to": "person/rose", "text": "x"}, "about": ["org/acme"]}, "extras": [], "refused": ""}')
  =/  org-got  (refine-check:orr org refine-act 'a1' refine-ctx now)
  ;:  weld
    (expect !>(?=(%& -.got)))
    (expect-eq !>('due is not a time') !>(?>(?=(%| -.garbled-got) p.garbled-got)))
    (expect-eq !>('no body named situation/2026-09-25-dinner on the ship') !>(?>(?=(%| -.sit-got) p.sit-got)))
    (expect-eq !>(1) !>(?>(?=(%& -.org-got) (lent bodies.p.org-got))))
    (expect-eq !>('Tell Rose and Dana') !>(?>(?=(%& -.got) title.p.got)))
    (expect-eq !>(`(list @t)`~['person/rose' 'person/dana-hill']) !>(?>(?=(%& -.got) about.p.got)))
    (expect-eq !>(1) !>(?>(?=(%& -.got) (lent extras.p.got))))
    (expect-eq !>('a1') !>(?>(?=(%& -.got) (gs:orr (gj:orr (snag 0 extras.p.got) 'payload') 'refined_from'))))
    ::  a person the note names and the ship lacks is created, not refused
    (expect-eq !>(1) !>(?>(?=(%& -.new-got) (lent bodies.p.new-got))))
    (expect-eq !>(`(list @t)`~['person/rose' 'person/karl']) !>(?>(?=(%& -.new-got) about.p.new-got)))
    ::  an about id the answer neither knows nor creates refuses
    (expect !>(?=(%| -.no-got)))
    (expect-eq !>('no body named person/nobody on the ship') !>(?>(?=(%| -.no-got) p.no-got)))
    (expect-eq !>('no person named Karl on the ship') !>(?>(?=(%| -.ref-got) p.ref-got)))
    ::  an extra of a kind a reader may not propose is dropped, not fatal
    (expect-eq !>(0) !>(?>(?=(%& -.bad-got) (lent extras.p.bad-got))))
    ::  a calendar extra in the past is dropped, with a note saying so
    (expect-eq !>(0) !>(?>(?=(%& -.past-got) (lent extras.p.past-got))))
    (expect-eq !>(`(list @t)`~['dropped extra Dinner: starts is not within the year ahead']) !>(?>(?=(%& -.past-got) notes.p.past-got)))
    (expect-eq !>(`(list @t)`~['dropped extra Lights: an extra may not be a home']) !>(?>(?=(%& -.bad-got) notes.p.bad-got)))
    ::  a to written as a name resolves to the body the answer creates,
    ::  whose aliases are trimmed and the empty one dropped
    (expect-eq !>('person/karl') !>(?>(?=(%& -.name-got) (gs:orr payload.p.name-got 'to'))))
    (expect-eq !>(`(list @t)`~['K']) !>(?>(?=(%& -.name-got) (strings:orr (ga:orr (snag 0 bodies.p.name-got) 'aliases')))))
    ::  an em dash in the revised text becomes a comma, and a null ends
    ::  on a calendar extra is no end
    (expect-eq !>('Rose, call me') !>(?>(?=(%& -.dash-got) (gs:orr payload.p.dash-got 'text'))))
    (expect-eq !>(1) !>(?>(?=(%& -.dash-got) (lent extras.p.dash-got))))
    (expect !>(?>(?=(%& -.dash-got) !(has-sub (en:json:html (gj:orr (snag 0 extras.p.dash-got) 'payload')) '"ends"'))))
  ==
++  test-refine-ops
  =/  r=refined:orr  [~[(jo '{"id": "person/karl", "kind": "person", "name": "Karl", "aliases": []}')] 'T' (jo '{"via": "chat", "to": "person/rose", "text": "x"}') ~['person/rose' 'person/karl'] ~ ~[(jo '{"kind": "task", "title": "Go shopping", "payload": {"refined_from": "a1"}, "about": ["person/rose"]}')] ~]
  =/  ops=(list json)  (refine-ops:orr r 'a1' 'user' now)
  =/  none=(list json)  (refine-ops:orr r(bodies ~) 'a1' 'user' now)
  ;:  weld
    (expect-eq !>(3) !>((lent ops)))
    (expect-eq !>('observe') !>((gs:orr (snag 0 ops) 'op')))
    (expect-eq !>('person/karl') !>((gs:orr (snag 0 (ga:orr (snag 0 ops) 'bodies')) 'id')))
    (expect-eq !>('revise-action') !>((gs:orr (snag 1 ops) 'op')))
    (expect-eq !>('act') !>((gs:orr (snag 2 ops) 'op')))
    (expect-eq !>('user') !>((gs:orr (gj:orr (snag 2 ops) 'action') 'by')))
    (expect-eq !>(2) !>((lent none)))
  ==
++  test-refine-user
  =/  t=@t  (refine-user:orr refine-act 'a1' refine-ctx 'include dana in this' now 'America/New_York')
  ;:  weld
    (expect !>((has-sub t 'person/dana-hill | Dana Hill | dana')))
    (expect !>((has-sub t 'include dana in this')))
    (expect !>((has-sub t 'message payload:')))
    (expect !>((has-sub t 'The owner\'s clock reads 2026-09-18T08:00:00-04:00')))
  ==
::  the first calendar op on an id, the first writer op of a kind
++  find-by
  |=  [l=(list json) id=@t]
  ^-  (unit json)
  ?~  l  ~
  ?:(=(id (gs:orr i.l 'id')) `i.l $(l t.l))
++  find-op
  |=  [l=(list json) op=@t]
  ^-  (unit json)
  ?~  l  ~
  ?:(=(op (gs:orr i.l 'op')) `i.l $(l t.l))
++  lift-act
  |=  j=json
  ^-  (unit action:orr)
  =/  got  (de-action:orr j now 'calendar')
  ?:(?=(%| -.got) ~ `p.got)
--
