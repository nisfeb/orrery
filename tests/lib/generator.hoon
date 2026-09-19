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
--
