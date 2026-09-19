::  Unit tests for /lib/generator: the pure half of the on-ship
::  generator, on fixtures. Nothing here touches the ship.
::
/+  *test, orr=orrery, gen=generator
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
    (expect-eq !>('https://openrouter.ai/api/v1') !>(url.bare))
    (expect !>((reasoning-on:gen reasoning.bare)))
  ==
--
