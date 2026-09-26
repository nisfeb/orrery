::  Unit tests for the nexus's rules, moved into /lib/orrery (version
::  60): the routes and who may take them, the request and key checks,
::  the readers' verdicts and choices, the generator's records and the
::  writer's choices. Nothing here touches a ship.
::
/+  *test, orr=orrery
|%
++  jo   |=(t=@t ^-(json (need (de:json:html t))))
++  now  ~2026.9.18..12.00.00
++  owner  ^-(actor:orr [& 'http' ~])
++  key
  |=  [kinds=(list @tas) acts=(list @tas) write=? sens=?]
  ^-  actor:orr
  [| 'k' `[(sy kinds) (sy acts) write sens]]
++  act
  |=  [kind=@tas title=@t payload=json about=(list @t) status=@tas]
  ^-  action:orr
  [kind title payload (sy about) ~ 'test' now status '' ~]
++  msg
  |=  [chat=@t from=@t text=@t at=@da mid=@t]
  ^-  tg-msg:orr
  [chat from text at mid '']
++  ob
  |=  [subject=@t attr=@t value=json at=@da]
  ^-  obs:orr
  [subject attr value at ~ 100 ['user' 'x'] 'test' at | '']
++  r  |=([id=@ta o=obs:orr] ^-(row:orr [id o]))
::  ==  the routes
::
++  test-route-path
  ;:  weld
    (expect-eq !>(`path`/api/state) !>((route-path:orr /apps/orrery/api/state)))
    (expect-eq !>(`path`/api/state) !>((route-path:orr `path`~[%apps %orrery %api %state %$])))
    (expect-eq !>(`path`~) !>((route-path:orr /apps/orrery)))
  ==
::  every route and who may take it: a route turned open, or an
::  owner-only one given to keys, fails here
::
++  test-route-table
  =/  table=(list [meth=@t pax=path tag=@tas =access:orr])
    :~
    ['GET' `path`~ %get-page %own]
    ['GET' `path`~['orrery.css'] %get-css %own]
    ['GET' `path`~['orrery.js'] %get-js %own]
    ['GET' `path`~[%api %state] %get-state %any]
    ['GET' `path`~[%api %body 'x0' 'x1'] %get-body %any]
    ['DELETE' `path`~[%api %body 'x0' 'x1'] %delete-body %own]
    ['GET' `path`~[%api %resolve] %get-resolve %any]
    ['POST' `path`~[%api %observe] %post-observe %any]
    ['POST' `path`~[%api %retract] %post-retract %any]
    ['POST' `path`~[%api %bodies] %post-bodies %any]
    ['POST' `path`~[%api %merge] %post-merge %own]
    ['POST' `path`~[%api %act] %post-act %any]
    ['GET' `path`~[%api %actions] %get-actions %any]
    ['POST' `path`~[%api %actions 'x0'] %post-actions %any]
    ['POST' `path`~[%api %actions 'x0' %refine] %post-actions-refine %any]
    ['GET' `path`~[%api %settings] %get-settings %own]
    ['GET' `path`~[%api %schema] %get-schema %own]
    ['PUT' `path`~[%api %schema] %put-schema %own]
    ['GET' `path`~[%api %policy] %get-policy %own]
    ['PUT' `path`~[%api %policy] %put-policy %own]
    ['POST' `path`~[%api %share] %post-share %own]
    ['DELETE' `path`~[%api %share 'x0' 'x1' 'x2'] %delete-share %own]
    ['GET' `path`~[%api %shares] %get-shares %own]
    ['POST' `path`~[%api %accept] %post-accept %own]
    ['POST' `path`~[%api %decline] %post-decline %own]
    ['POST' `path`~[%api %sync] %post-sync %own]
    ['POST' `path`~[%api %clients] %post-clients %own]
    ['GET' `path`~[%api %clients] %get-clients %own]
    ['DELETE' `path`~[%api %clients 'x0'] %delete-clients %own]
    ['GET' `path`~[%api %generator] %get-generator %own]
    ['PUT' `path`~[%api %generator] %put-generator %own]
    ['GET' `path`~[%api %generator %last] %get-generator-last %own]
    ['POST' `path`~[%api %generate] %post-generate %any]
    ['POST' `path`~[%api %reconcile] %post-reconcile %own]
    ['GET' `path`~[%api %reconcile %last] %get-reconcile-last %own]
    ['GET' `path`~[%api %telegram] %get-telegram %own]
    ['PUT' `path`~[%api %telegram] %put-telegram %own]
    ['GET' `path`~[%api %telegram %last] %get-telegram-last %own]
    ['POST' `path`~[%api %telegram %webhook] %post-telegram-webhook %writes]
    ['GET' `path`~[%api %telegram %webhook] %get-telegram-webhook %writes]
    ['POST' `path`~[%api %telegram %wake] %post-telegram-wake %own]
    ['GET' `path`~[%api %chat] %get-chat %writes]
    ['PUT' `path`~[%api %chat] %put-chat %writes]
    ['GET' `path`~[%api %chat %last] %get-chat-last %own]
    ['POST' `path`~[%api %chat %wake] %post-chat-wake %own]
    ['GET' `path`~[%api %chat %peek] %get-chat-peek %own]
    ['GET' `path`~[%api %version] %get-version %any]
    ['GET' `path`~[%api %chat %lists] %get-chat-lists %own]
    ['GET' `path`~[%api %chat %dms] %get-chat-dms %own]
    ['GET' `path`~[%api %chat %channels] %get-chat-channels %own]
    ['POST' `path`~[%api %read] %post-read %writes]
    ['GET' `path`~[%api %read %settings] %get-read-settings %writes]
    ['PUT' `path`~[%api %read %settings] %put-read-settings %writes]
    ['GET' `path`~[%api %read %last] %get-read-last %own]
    ['POST' `path`~[%api %read %wake] %post-read-wake %own]
    ['GET' `path`~[%api %mail] %get-mail %writes]
    ['PUT' `path`~[%api %mail] %put-mail %writes]
    ['GET' `path`~[%api %mail %last] %get-mail-last %own]
    ['POST' `path`~[%api %mail %wake] %post-mail-wake %own]
    ['GET' `path`~[%api %brief %last] %get-brief-last %own]
    ['POST' `path`~[%api %brief %wake] %post-brief-wake %own]
    ['GET' `path`~[%api %exec %last] %get-exec-last %own]
    ['GET' `path`~[%api %calendar %last] %get-calendar-last %own]
    ['POST' `path`~[%api %exec %wake] %post-exec-wake %own]
    ==
  ;:  weld
    %+  expect-eq
      !>  (turn table |=([m=@t p=path t=@tas a=access:orr] `(unit [@tas access:orr])``[t a]))
      !>  (turn table |=([m=@t p=path *] (route-of:orr m p)))
    (expect-eq !>(~) !>((route-of:orr 'PATCH' /api/state)))
    (expect-eq !>(~) !>((route-of:orr 'GET' /api/nope)))
    (expect-eq !>(~) !>((route-of:orr 'POST' /api/state)))
  ==
::  the page carries its stylesheet and script, each in place of its tag;
::  a page without them is served as it is
++  test-inline-page
  =/  html=@t
    %+  rap  3
    :~  '<head><link rel="stylesheet" href="/apps/orrery/orrery.css"></head>'
        '<body><script src="/apps/orrery/orrery.js"></script></body>'
    ==
  ;:  weld
    %+  expect-eq
      !>('<head><style>b{}</style></head><body><script>go()</script></body>')
    !>((inline-page:orr html 'b{}' 'go()'))
    (expect-eq !>('<p>x</p>') !>((inline-page:orr '<p>x</p>' 'b{}' 'go()')))
    (expect-eq !>('abXd') !>((swap-once:orr 'abcd' 'c' 'X')))
    (expect-eq !>('abcd') !>((swap-once:orr 'abcd' 'z' 'X')))
  ==
++  test-access-refusal
  ;:  weld
    (expect-eq !>(~) !>((access-refusal:orr owner %own)))
    (expect-eq !>(~) !>((access-refusal:orr owner %writes)))
    (expect-eq !>(`'owner only') !>((access-refusal:orr (key ~[%person] ~ & &) %own)))
    (expect-eq !>(~) !>((access-refusal:orr (key ~[%person] ~ & |) %writes)))
    (expect-eq !>(`'read only key') !>((access-refusal:orr (key ~[%person] ~ | |) %writes)))
    (expect-eq !>(~) !>((access-refusal:orr (key ~[%person] ~ | |) %any)))
  ==
::  ==  the request and the key
::
++  test-request-refusal
  =/  body=(unit octs)  `[2 '{}']
  =/  bad=(unit [@ud @t])  `[415 'content-type: application/json required']
  =/  far=(unit [@ud @t])  `[403 'a request from another site is refused']
  ;:  weld
    (expect-eq !>(bad) !>((request-refusal:orr 'POST' body 'text/plain' '' &)))
    (expect-eq !>(bad) !>((request-refusal:orr 'PUT' body '' '' |)))
    (expect-eq !>(~) !>((request-refusal:orr 'POST' body 'Application/JSON; charset=utf-8' '' &)))
    (expect-eq !>(~) !>((request-refusal:orr 'POST' ~ 'text/plain' '' |)))
    (expect-eq !>(~) !>((request-refusal:orr 'POST' `[0 ''] 'text/plain' '' |)))
    (expect-eq !>(~) !>((request-refusal:orr 'GET' body 'text/plain' '' |)))
    (expect-eq !>(~) !>((request-refusal:orr 'DELETE' body 'text/plain' '' |)))
    (expect-eq !>(far) !>((request-refusal:orr 'POST' ~ '' 'cross-site' &)))
    (expect-eq !>(far) !>((request-refusal:orr 'DELETE' ~ '' 'same-site' &)))
    (expect-eq !>(~) !>((request-refusal:orr 'GET' ~ '' 'cross-site' &)))
    (expect-eq !>(~) !>((request-refusal:orr 'POST' ~ '' 'cross-site' |)))
    (expect-eq !>(~) !>((request-refusal:orr 'POST' ~ '' 'same-origin' &)))
    ::  a body with the wrong type from another site is the 415
    (expect-eq !>(bad) !>((request-refusal:orr 'POST' body 'text/plain' 'cross-site' &)))
  ==
++  test-act-refusal
  =/  k  (key ~[%person] ~[%task %message] & |)
  ;:  weld
    (expect-eq !>(~) !>((act-refusal:orr owner (act %merge 'm' ~ ~['org/acme'] %proposed))))
    (expect-eq !>(`[403 'not in scope: note']) !>((act-refusal:orr k (act %note 'n' ~ ~ %proposed))))
    (expect-eq !>(`[400 'about: no such body org/acme']) !>((act-refusal:orr k (act %task 't' ~ ~['person/me' 'org/acme'] %proposed))))
    (expect-eq !>(~) !>((act-refusal:orr k (act %task 't' ~ ~['person/me' 'not an id'] %proposed))))
    (expect-eq !>(`[400 'payload: no such body org/acme']) !>((act-refusal:orr k (act %message 'm' (jo '{"to": "org/acme"}') ~ %proposed))))
    (expect-eq !>(`[400 'payload: no such body place/home']) !>((act-refusal:orr k (act %message 'm' (jo '{"to": "person/dana", "into": "place/home"}') ~ %proposed))))
    (expect-eq !>(~) !>((act-refusal:orr k (act %message 'm' (jo '{"to": "person/dana"}') ~ %proposed))))
    %+  expect-eq  !>(`[403 'a key may not propose a merge'])
    !>((act-refusal:orr (key ~[%person] ~[%merge] & |) (act %merge 'm' (jo '{"from": "person/a", "into": "person/b"}') ~ %proposed)))
  ==
++  test-de-mint
  =/  sc=json  (jo '{"kinds": ["person"], "actions": [], "write": false}')
  =/  why
    |=  [name=@t by=@t s=json]
    ^-  @t
    =/  g  (de-mint:orr (pairs:enjs:format ~[['name' s+name] ['by' s+by] ['scope' s]]))
    ?:(?=(%| -.g) p.g 'ok')
  =/  good  (de-mint:orr (pairs:enjs:format ~[['name' s+'n'] ['by' s+'b'] ['scope' sc]]))
  ;:  weld
    (expect-eq !>([%| 'a JSON object is required']) !>((de-mint:orr s+'x')))
    (expect-eq !>('name: 1 to 200 bytes') !>((why '' 'b' sc)))
    (expect-eq !>('name: 1 to 200 bytes') !>((why (crip (reap 201 'n')) 'b' sc)))
    (expect-eq !>('ok') !>((why (crip (reap 200 'n')) 'b' sc)))
    (expect-eq !>('by: 1 to 64 bytes') !>((why 'n' '' sc)))
    (expect-eq !>('by: 1 to 64 bytes') !>((why 'n' (crip (reap 65 'b')) sc)))
    (expect-eq !>('ok') !>((why 'n' (crip (reap 64 'b')) sc)))
    (expect-eq !>('scope: expected an object') !>((why 'n' 'b' s+'x')))
    (expect !>(?=(%& -.good)))
    (expect-eq !>(['n' 'b']) !>(?>(?=(%& -.good) [name.p.good by.p.good])))
  ==
++  test-touch-due
  ;:  weld
    (expect !>((touch-due:orr ~ now)))
    (expect !>(!(touch-due:orr `(sub now ~m59) now)))
    (expect !>((touch-due:orr `(sub now ~h1) now)))
  ==
::  ==  what a key sees and writes
::
++  test-key-hide
  =/  policy=json  (jo '{"sensitive": ["health"]}')
  ;:  weld
    (expect-eq !>((sy `(list @t)`~['health' 'ship' 'telegram'])) !>((key-hide:orr [(sy ~[%person]) ~ & |] policy)))
    (expect-eq !>(*(set @t)) !>((key-hide:orr [(sy ~[%person]) ~ & &] policy)))
    (expect-eq !>(*(set @t)) !>((hidden-for:orr owner policy)))
    (expect-eq !>((sy `(list @t)`~['health'])) !>((hidden-for:orr (key ~[%person] ~ & |) policy)))
  ==
++  test-deny
  =/  policy=json  (jo '{"sensitive": ["health"]}')
  =/  batch
    |=  [s=@t a=@t]
    ^-  json
    %-  pairs:enjs:format
    :~  ['bodies' a+~]
        ['observations' a+~[(pairs:enjs:format ~[['subject' s+s] ['attr' s+a] ['value' s+'x']])]]
    ==
  =/  w  (key ~[%person] ~ & |)
  ;:  weld
    (expect-eq !>(~) !>((deny-observe:orr owner (batch 'org/x' 'health') policy)))
    (expect-eq !>(`'read only key') !>((deny-observe:orr (key ~[%person] ~ | |) (batch 'person/me' 'status') policy)))
    (expect-eq !>(~) !>((deny-observe:orr w (batch 'person/me' 'status') policy)))
    (expect-eq !>(`'not in scope: health') !>((deny-observe:orr w (batch 'person/me' 'health') policy)))
    (expect-eq !>(`'not in scope: telegram') !>((deny-observe:orr w (batch 'person/me' 'telegram') policy)))
    (expect-eq !>(`'not in scope: org/x') !>((deny-observe:orr w (batch 'org/x' 'status') policy)))
    (expect-eq !>(~) !>((deny-observe:orr (key ~[%person] ~ & &) (batch 'person/me' 'ship') policy)))
    (expect-eq !>(~) !>((deny-write:orr owner %org)))
    (expect-eq !>(`'read only key') !>((deny-write:orr (key ~[%person] ~ | |) %person)))
    (expect-eq !>(`'not in scope: org') !>((deny-write:orr w %org)))
    (expect-eq !>(~) !>((deny-write:orr w %person)))
  ==
++  test-view-of
  =/  all=(list loaded:orr)
    :~  :+  'person/me'  [%person 'me' ~ now ~]
        ~[(r 'a' (ob 'person/me' 'health' s+'ok' now)) (r 'b' (ob 'person/me' 'status' s+'home' now))]
        ['org/acme' [%org 'Acme' ~ now ~] ~]
    ==
  =/  acts=(list [id=@ta a=action:orr])
    ~[['a1' (act %task 't' ~ ~['person/me' 'org/acme'] %proposed)] ['a2' (act %note 'n' ~ ~ %proposed)]]
  =/  k  (key ~[%person] ~[%task] & |)
  =/  v  (view-of:orr k all acts (sy ~['health']))
  ;:  weld
    (expect-eq !>([all acts]) !>((view-of:orr owner all acts (sy ~['health']))))
    (expect-eq !>(`(list @t)`~['person/me']) !>((turn all.v |=(l=loaded:orr id.l))))
    (expect-eq !>(`(list @t)`~['status']) !>((turn rows:(snag 0 all.v) |=(x=row:orr attr.obs.x))))
    (expect-eq !>(`(list @t)`~['a1']) !>((turn acts.v |=([id=@ta *] id))))
    (expect-eq !>((sy `(list @t)`~['person/me'])) !>(about.a:(snag 0 acts.v)))
    (expect-eq !>((sy `(list @t)`~['person/me'])) !>(about:(seen-by:orr k +:(snag 0 acts))))
    (expect-eq !>(+:(snag 0 acts)) !>((seen-by:orr owner +:(snag 0 acts))))
  ==
::  ==  the readers
::
++  test-run-fresh
  =/  rn=(list [msg=tg-msg:orr who=@t])
    :~  [(msg 'c' 'f' 'car broke down' now '1') 'person/me']
        [(msg 'c' 'f' 'where are you?' now '2') 'person/me']
        [(msg 'c' 'f' '' now '3') 'person/me']
    ==
  =/  mids  |=(l=(list [msg=tg-msg:orr who=@t]) (turn l |=([m=tg-msg:orr *] mid.m)))
  ;:  weld
    (expect-eq !>(`(list @t)`~['1']) !>((mids (run-fresh:orr rn telegram-kind:orr))))
    (expect-eq !>(`(list @t)`~['1' '2']) !>((mids (run-fresh:orr rn read-kind:orr))))
  ==
++  test-run-rows
  =/  recent=json  (jo '{"c": [{"id": "telegram/c/0", "at": "2026-09-18T11:00:00Z", "who": "person/me", "text": "earlier"}]}')
  =/  rows  (run-rows:orr recent ~[[(msg 'c' 'f' 'now' now '1') 'person/me']] telegram-kind:orr)
  ;:  weld
    %+  expect-eq
      !>  `(list window-row:orr)`~[['telegram/c/0' '2026-09-18T11:00:00Z' 'person/me' 'earlier' &] ['telegram/c/1' '2026-09-18T12:00:00Z' 'person/me' 'now' |]]
      !>  rows
    (expect-eq !>(`(list window-row:orr)`~) !>((run-rows:orr recent ~ telegram-kind:orr)))
  ==
++  test-gate-verdict
  =/  ans  |=(n=@t (jo (rap 3 '{"worth_reading": {"type": "noul", "noul": ' n '}}' ~)))
  ;:  weld
    (expect-eq !>([& 'gate unavailable, analyst asked']) !>((gate-verdict:orr ~ 30)))
    (expect-eq !>([& 'gate unavailable, analyst asked']) !>((gate-verdict:orr `(jo '{"worth_reading": {}}') 30)))
    (expect-eq !>([& 'gate: 90, read']) !>((gate-verdict:orr `(ans '0.9') 30)))
    (expect-eq !>([| 'gate: 20, not read']) !>((gate-verdict:orr `(ans '0.2') 30)))
    (expect-eq !>([& 'gate: 30, read']) !>((gate-verdict:orr `(ans '0.3') 30)))
    (expect-eq !>([| 'gate: 29, not read']) !>((gate-verdict:orr `(ans '0.29') 30)))
  ==
++  test-reader-answer
  =/  down  |=([s=@ud b=@t] ^-(? =/(a (reader-answer:orr s b) ?:(?=(%| -.a) down.p.a |))))
  =/  why  |=([s=@ud b=@t] ^-(@t =/(a (reader-answer:orr s b) ?:(?=(%| -.a) why.p.a ''))))
  ;:  weld
    (expect !>((down 0 '')))
    (expect !>(!(down 400 '')))
    (expect !>((down 401 '')))
    (expect !>((down 404 '')))
    (expect !>(!(down 405 '')))
    (expect !>((down 408 '')))
    (expect !>((down 429 '')))
    (expect !>(!(down 499 '')))
    (expect !>((down 500 '')))
    (expect !>((down 599 '')))
    (expect !>(!(down 600 '')))
    (expect-eq !>('model: 503 busy') !>((why 503 'busy')))
    (expect !>((down 200 '{"error": {"message": "overloaded"}}')))
    (expect !>(!(down 200 '{"nothing": 1}')))
    (expect-eq !>('model: the answer is not JSON') !>((why 200 '{"choices": [{"message": {"content": "no json here"}}]}')))
    %+  expect-eq  !>(`(each json [? @t])`[%& (jo '{"a": 1}')])
    !>((reader-answer:orr 200 '{"choices": [{"message": {"content": "{\\"a\\": 1}"}}]}'))
  ==
++  test-owner-zone
  =/  me
    |=  tz=(list @t)
    ^-  (list loaded:orr)
    ~[['person/me' [%person 'me' ~ now ~] (turn tz |=(z=@t (r 'tz' (ob 'person/me' 'timezone' s+z now))))]]
  ;:  weld
    (expect-eq !>('Europe/Paris') !>((owner-zone:orr (me ~['Europe/Paris']) ~ now 'Etc/UTC')))
    (expect-eq !>('Etc/UTC') !>((owner-zone:orr (me ~) ~ now 'Etc/UTC')))
  ==
::  ==  the read channel
::
++  test-read-item
  =/  keyed=json
    %-  jo
    '{"id": "r1", "title": "Car", "text": "it died", "who": "person/me", "at": "2026-09-18T11:00:00Z", "source": {"kind": "web", "id": "https://x"}, "by": "talon", "scope": {"kinds": ["person"], "actions": [], "write": true}}'
  =/  owned=json  (jo '{"id": "r2", "text": "hello", "who": "person/me"}')
  =/  k  (read-item:orr keyed now)
  =/  o  (read-item:orr owned now)
  ;:  weld
    (expect-eq !>('Car\0a\0ait died') !>(text.msg.k))
    (expect-eq !>('https://x') !>(chat.msg.k))
    (expect-eq !>('r1') !>(mid.msg.k))
    (expect-eq !>(~2026.9.18..11.00.00) !>(at.msg.k))
    (expect-eq !>(['web' 'talon']) !>([channel by]:kind.k))
    (expect !>(?=(^ sc.k)))
    (expect-eq !>('hello') !>(text.msg.o))
    (expect-eq !>(now) !>(at.msg.o))
    (expect-eq !>('web') !>(by.kind.o))
    (expect !>(?=(~ sc.o)))
  ==
++  test-day-count
  =/  last=json  (jo '{"day": "2026-09-18", "read_today": 5}')
  ;:  weld
    (expect-eq !>(5) !>((day-count:orr last 'read_today' now)))
    (expect-eq !>(0) !>((day-count:orr last 'read_today' (add now ~d1))))
    (expect-eq !>(0) !>((day-count:orr last 'calls_today' now)))
    (expect !>((read-held:orr last now 5)))
    (expect !>(!(read-held:orr last now 6)))
  ==
::  ==  the mail reader
::
++  mm
  |=  [id=@t from=@p subj=@t body=@t sent=@da prev=(unit @uv) trusted=?]
  ^-  mail-msg:orr
  ['t' id from subj body sent prev trusted]
++  test-mail-since
  ;:  weld
    (expect-eq !>((sub now ~h24)) !>((mail-since:orr (jo '{}') 24 now)))
    (expect-eq !>((sub now ~d7)) !>((mail-since:orr (jo '{"since": "2026-09-01T00:00:00Z"}') 24 now)))
    (expect-eq !>(~2026.9.17) !>((mail-since:orr (jo '{"since": "2026-09-17T00:00:00Z"}') 24 now)))
  ==
++  test-mail-fresh
  =/  msgs=(list mail-msg:orr)
    :~  (mm 'late' ~nec 's' 'b' (sub now ~h1) ~ &)
        (mm 'early' ~nec 's' 'b' (sub now ~h5) ~ &)
        (mm 'forged' ~nec 's' 'b' (sub now ~h2) ~ |)
        (mm 'old' ~nec 's' 'b' (sub now ~d2) ~ &)
        (mm 'future' ~nec 's' 'b' (add now ~s1) ~ &)
        (mm 'edge' ~nec 's' 'b' (sub now ~d1) ~ &)
        (mm 'now' ~nec 's' 'b' now ~ &)
    ==
  %+  expect-eq  !>(`(list @t)`~['edge' 'early' 'late' 'now'])
  !>((turn (mail-fresh:orr msgs (sub now ~d1) now) |=(x=mail-msg:orr id.x)))
++  test-brief-replies-of
  =/  root  (mm (scot %uv 0v1) ~zod 'Daily brief 2026-09-18' 'BRIEF' now ~ &)
  =/  reply  (mm 'r1' ~zod 'Re: Daily brief 2026-09-18' 'approve A1' now `0v1 &)
  =/  other  (mm 'r2' ~nec 'Re: Daily brief 2026-09-18' 'x' now `0v1 &)
  =/  lost  (mm 'r3' ~zod 'Re: Daily brief 2026-09-18' 'x' now `0v2 &)
  =/  plain  (mm 'r4' ~zod 'Re: lunch' 'x' now `0v1 &)
  ::  a reply to a message someone else sent is not a reply to the brief,
  ::  whatever it says
  =/  theirs  (mm (scot %uv 0v5) ~nec 'Daily brief 2026-09-18' 'BRIEF' now ~ &)
  =/  back  (mm 'r5' ~zod 'Re: Daily brief 2026-09-18' 'approve A1' now `0v5 &)
  =/  all  ~[root reply other lost plain theirs back]
  =/  got  |=([seen=(set @t) sent=(list @t)] (turn (brief-replies-of:orr all all ~zod seen sent) |=([x=mail-msg:orr t=@t] [id.x t])))
  ;:  weld
    (expect-eq !>(`(list [@t @t])`~[['r1' 'BRIEF']]) !>((got ~ ~['BRIEF'])))
    (expect-eq !>(`(list [@t @t])`~) !>((got (sy ~['mail:r1']) ~['BRIEF'])))
    (expect-eq !>(`(list [@t @t])`~) !>((got ~ ~['ANOTHER'])))
  ==
++  test-mail-rows
  =/  rows  (mail-rows:orr ~[(mm 'a' ~zod 's' 'mine' now ~ &) (mm 'b' ~nec 's' '  ' now ~ &) (mm 'c' ~nec 'Hi' 'hello' now ~ &)] ~zod)
  ;:  weld
    (expect-eq !>(`(list @t)`~['c']) !>((turn rows |=(m=tg-msg:orr mid.m))))
    (expect-eq !>('mail:t') !>(chat:(snag 0 rows)))
  ==
::  ==  the chat reader
::
++  test-chat-since
  ;:  weld
    (expect-eq !>([(sub now ~h24) (sub now ~h24)]) !>((chat-since:orr (jo '{}') 24 now)))
    (expect-eq !>([~2026.9.17 *@da]) !>((chat-since:orr (jo '{"since": "2026-09-17T00:00:00Z"}') 24 now)))
    (expect-eq !>(~2026.9.17) !>((chat-next:orr | ~2026.9.17 `~2026.9.18 now)))
    (expect-eq !>(~2026.9.18) !>((chat-next:orr & ~2026.9.17 `~2026.9.18 now)))
    (expect-eq !>(now) !>((chat-next:orr & ~2026.9.17 ~ now)))
  ==
++  test-sift-rows
  =/  people  (my ~[['~zod' 'person/me'] ['~nec' 'person/nec']])
  =/  rows=(list tg-msg:orr)
    :~  (msg 'a' '~zod' 'one' (sub now ~h3) '1')
        (msg 'b' '~nec' 'two' (sub now ~h2) '2')
        (msg 'a' '~zod' 'three' (sub now ~h1) '3')
        (msg 'a' '~bus' 'stranger' now '4')
        (msg 'a' '~zod' '' now '5')
        (msg 'a' '~zod' 'seen' now '6')
    ==
  =/  s  (sift-rows:orr rows (sy ~['a/6']) people 0 10 chat-key:orr)
  =/  c  (sift-rows:orr rows ~ people 8 10 mail-key:orr)
  ;:  weld
    (expect-eq !>(`(list @t)`~['a' 'b']) !>((turn runs.s |=([ch=@t *] ch))))
    (expect-eq !>(`(list @t)`~['a/1' 'a/3']) !>((turn items:(snag 0 runs.s) |=([k=@t *] k))))
    (expect-eq !>([1 0 3]) !>([strangers held taken]:s))
    (expect-eq !>((sy `(list @t)`~['a/4' 'a/5'])) !>((sy new.s)))
    ::  the cap: two left today; what follows is held from the first held
    (expect-eq !>([2 2]) !>([taken held]:c))
    (expect-eq !>(`(sub now ~h1)) !>(held-at.c))
    (expect-eq !>(`(list @t)`~['mail:1' 'mail:2']) !>((zing (turn runs.c |=([* items=(list [key=@t *])] (turn items |=([k=@t *] k)))))))
  ==
::  ==  the generator's records
::
++  gen-last
  %-  jo
  '{"day": "2026-09-18", "month": "2026-09", "calls_today": 2, "urgent_today": 1, "spend_month_micro": 1000, "digest": "0x1", "filed": 3, "dropped": 4, "notes": ["old"], "usage": {"cost": 0.5}, "error": "e", "seconds": 9}'
++  test-month-spend
  =/  usage=json  (jo '{"cost": 0.0001}')
  ;:  weld
    (expect-eq !>(1.100) !>((month-spend:orr gen-last usage now)))
    (expect-eq !>(100) !>((month-spend:orr gen-last usage ~2026.10.1)))
    (expect-eq !>(1.000) !>((month-spend:orr gen-last (jo '{}') now)))
  ==
++  test-transient-status
  ;:  weld
    (expect !>((transient-status:orr 0)))
    (expect !>((transient-status:orr 408)))
    (expect !>((transient-status:orr 429)))
    (expect !>((transient-status:orr 500)))
    (expect !>((transient-status:orr 599)))
    (expect !>(!(transient-status:orr 200)))
    (expect !>(!(transient-status:orr 400)))
    (expect !>(!(transient-status:orr 401)))
    (expect !>(!(transient-status:orr 499)))
    (expect !>(!(transient-status:orr 600)))
  ==
++  test-counted
  =/  c  (counted-call:orr gen-last now (jo '{"cost": 0.0001}'))
  =/  p  (counted-pass:orr gen-last now &)
  =/  q  (counted-pass:orr gen-last (add now ~d1) |)
  ;:  weld
    (expect-eq !>([`3 `1.100 '0x1']) !>([(gn:orr c 'calls_today') (gn:orr c 'spend_month_micro') (gs:orr c 'digest')]))
    (expect-eq !>([`3 `2]) !>([(gn:orr p 'calls_today') (gn:orr p 'urgent_today')]))
    (expect-eq !>([`1 `0 '2026-09-19']) !>([(gn:orr q 'calls_today') (gn:orr q 'urgent_today') (gs:orr q 'day')]))
  ==
++  test-gen-record-doc
  =/  skip  (gen-record-doc:orr gen-last now ~ 0 0 ~['held'] ~ ~ 0 & ~)
  =/  ran  (gen-record-doc:orr gen-last now `0x2 1 0 ~['new'] (jo '{"cost": 0}') ~ 5 | ~)
  =/  none  (gen-record-doc:orr gen-last now ~ 0 0 ~ ~ `'x' 0 | ~)
  ;:  weld
    (expect-eq !>(['0x1' `3 `4 `9 'e']) !>([(gs:orr skip 'digest') (gn:orr skip 'filed') (gn:orr skip 'dropped') (gn:orr skip 'seconds') (gs:orr skip 'error')]))
    (expect-eq !>(`(list @t)`~['held' 'old']) !>((strings:orr (ga:orr skip 'notes'))))
    (expect-eq !>((jo '{"cost": 0.5}')) !>((gj:orr skip 'usage')))
    (expect-eq !>(['0x2' `1 `5 `(list @t)`~['new']]) !>([(gs:orr ran 'digest') (gn:orr ran 'filed') (gn:orr ran 'seconds') (strings:orr (ga:orr ran 'notes'))]))
    (expect-eq !>(['' 'x']) !>([(gs:orr none 'digest') (gs:orr none 'error')]))
    (expect-eq !>(`1.000) !>((gn:orr ran 'spend_month_micro')))
  ==
::  ==  a body gone, a late answer
::
++  test-reabout-one
  =/  t  (act %task 't' ~ ~['person/a' 'person/c'] %proposed)
  =/  m  (act %message 'm' (jo '{"to": "person/a", "text": "hi"}') ~ %approved)
  ;:  weld
    (expect-eq !>(~) !>((reabout-one:orr (act %task 't' ~ ~['person/c'] %proposed) 'person/a' `'person/b')))
    (expect-eq !>((sy `(list @t)`~['person/b' 'person/c'])) !>(about:(need (reabout-one:orr t 'person/a' `'person/b'))))
    (expect-eq !>((sy `(list @t)`~['person/c'])) !>(about:(need (reabout-one:orr t 'person/a' ~))))
    (expect-eq !>('person/b') !>((gs:orr payload:(need (reabout-one:orr m 'person/a' `'person/b')) 'to')))
    (expect-eq !>(*(set @t)) !>(about:(need (reabout-one:orr m 'person/a' `'person/b'))))
    (expect-eq !>(~) !>((reabout-one:orr m 'person/a' ~)))
    (expect-eq !>(~) !>((reabout-one:orr m(status %done) 'person/a' `'person/b')))
    ::  a merge leaves a task's payload alone: only a message to from moves
    (expect-eq !>(`json`~) !>((gj:orr payload:(need (reabout-one:orr t 'person/a' `'person/b')) 'to')))
    ::  a message about from and to from, from deleted: about loses it, to stays
    =/  ma  m(about (sy ~['person/a']))
    =/  gone  (need (reabout-one:orr ma 'person/a' ~))
    (expect-eq !>([*(set @t) 'person/a']) !>([about.gone (gs:orr payload.gone 'to')]))
  ==
++  test-repoint-people
  ;:  weld
    (expect-eq !>(~) !>((repoint-people:orr (jo '{"people": {"1": "person/x"}}') 'person/a' 'person/b')))
    (expect-eq !>(~) !>((repoint-people:orr (jo '{}') 'person/a' 'person/b')))
    %+  expect-eq  !>(`(jo '{"people": {"1": "person/b", "2": "person/x"}, "chats": [1]}'))
    !>((repoint-people:orr (jo '{"people": {"1": "person/a", "2": "person/x"}, "chats": [1]}') 'person/a' 'person/b'))
  ==
++  test-answer-fits
  ;:  weld
    (expect !>((answer-fits:orr %decider 500 'x')))
    (expect !>((answer-fits:orr %decider 200 '{"answers": {}}')))
    (expect !>(!(answer-fits:orr %decider 200 '{"choices": []}')))
    (expect !>((answer-fits:orr %model 200 '{"choices": []}')))
    (expect !>((answer-fits:orr %reader 200 '{"error": {}}')))
    (expect !>((answer-fits:orr %brief 200 '{"choices": []}')))
    (expect !>(!(answer-fits:orr %refine 200 '{"answers": {}}')))
    (expect !>((answer-fits:orr %other 200 '{}')))
  ==
::  ==  the writer's choices
::
++  test-revives
  =/  o  (ob 'thing/car' 'status' s+'x' now)
  ;:  weld
    (expect !>(!(revives:orr ~ o)))
    (expect !>(!(revives:orr `o o(conf 50))))
    (expect !>(!(revives:orr `o(retracted &) o)))
    (expect !>((revives:orr `o(retracted &) o(conf 50))))
    (expect !>((revives:orr `o(retracted &) o(until `now))))
    (expect !>(!(revives:orr `o(retracted &) o(retracted &, conf 50))))
  ==
++  test-dead-rows
  =/  a  (r 'a' (ob 'thing/car' 'location' s+'Route 9' (sub now ~d10)))
  =/  b  (r 'b' (ob 'thing/car' 'location' s+'tow' (sub now ~d9)))
  =/  c  (r 'c' (ob 'thing/car' 'location' s+'shop' (sub now ~d8)))
  =/  d  (r 'd' (ob 'thing/car' 'status' s+'x' (sub now ~d8)))
  =/  e  (r 'e' (ob 'thing/car' 'status' s+'y' (sub now ~h2)))
  =/  f  (r 'f' (ob 'thing/car' 'status' s+'z' (sub now ~h1)))
  ::  a row recorded exactly at the horizon is not older than it: kept
  =/  horizon=@da  (sub now ~d5)
  =/  w  (r 'w' (ob 'thing/car' 'color' s+'red' (sub now ~h1)))
  =/  v  (r 'v' (ob 'thing/car' 'color' s+'blue' (add horizon ~h1)))
  =/  x  (r 'x' (ob 'thing/car' 'color' s+'green' horizon))
  ::  a and d are old and superseded; b is location's fallback, e is
  ::  status's, v is color's, and c, f and w win
  (expect-eq !>(`(list @ta)`~['a' 'd']) !>((dead-rows:orr ~[a b c d e f w v x] ~ horizon now)))
++  test-op-gone
  ;:  weld
    (expect-eq !>('person/a') !>((op-gone:orr (jo '{"op": "delete-body", "id": "person/a"}'))))
    (expect-eq !>('person/b') !>((op-gone:orr (jo '{"op": "merge", "from": "person/b", "into": "person/c"}'))))
    (expect-eq !>('') !>((op-gone:orr (jo '{"op": "observe", "id": "person/a"}'))))
  ==
++  test-offer-refusal
  =/  many
    |=  [n=@ud h=@p]
    ^-  (map @t json)
    %-  ~(gas by *(map @t json))
    (turn (gulf 1 n) |=(i=@ud [(crip "k{(a-co:co i)}") (pairs:enjs:format ~[['host' s+(scot %p h)]])]))
  ;:  weld
    (expect-eq !>(~) !>((offer-refusal:orr (many 19 ~nec) 'new' ~nec)))
    (expect-eq !>(`'too many offers from this ship') !>((offer-refusal:orr (many 20 ~nec) 'new' ~nec)))
    (expect-eq !>(~) !>((offer-refusal:orr (many 20 ~nec) 'k1' ~nec)))
    (expect-eq !>(~) !>((offer-refusal:orr (many 20 ~nec) 'new' ~bus)))
    (expect-eq !>(~) !>((offer-refusal:orr (many 199 ~zod) 'new' ~nec)))
    (expect-eq !>(`'inbox full') !>((offer-refusal:orr (many 200 ~zod) 'new' ~nec)))
  ==
++  test-replacement
  =/  a  |=([title=@t at=@da status=@tas] ^-(action:orr =/(x (act %task title ~ ~ status) x(proposed at))))
  =/  after=(list [id=@ta a=action:orr])
    :~  ['old' (a 'Call' now %dismissed)]
        ['early' (a 'Call' (sub now ~s1) %proposed)]
        ['other' (a 'Text' now %proposed)]
        ['done' (a 'Call' now %approved)]
        ['new' (a 'Call' now %proposed)]
    ==
  ;:  weld
    (expect-eq !>(`'new') !>((replacement:orr after 'old' 'Call' (add now ~s0..8000))))
    (expect-eq !>(~) !>((replacement:orr after 'new' 'Call' (add now ~s0..8000))))
  ==
++  test-tg-why
  =/  cfg=tg-config:orr
    %*  .  *tg-config:orr
      chats   (sy ~['c'])
      people  (my ~[['f' 'person/me']])
    ==
  ;:  weld
    (expect-eq !>(`['' '' 'not a message']) !>((tg-why:orr cfg ~)))
    (expect-eq !>(`['x' 'f' 'chat x is not in chats']) !>((tg-why:orr cfg `(msg 'x' 'f' 'hi' now '1'))))
    (expect-eq !>(`['c' 'g' 'sender g is not in people']) !>((tg-why:orr cfg `(msg 'c' 'g' 'hi' now '1'))))
    (expect-eq !>(~) !>((tg-why:orr cfg `(msg 'c' 'f' '' now '1'))))
  ==
::  ==  the helpers moved as they were
::
++  test-moved-helpers
  =/  rows  ~[(r 'a' (ob 'thing/car' 's' s+'x' now)) (r 'b' (ob 'thing/car' 's' s+'y' now))]
  =/  acts=(list [id=@ta a=action:orr])
    :~  ['d' (act %task 'Call' ~ ~ %done)]
        ['o' (act %task 'Other' ~ ~ %proposed)]
        ['p' (act %task 'Call' ~ ~ %proposed)]
        ['n' (act %note 'Call' ~ ~ %proposed)]
    ==
  =/  runs=(list tg-run:orr)  ~[['a' ~] ['b' ~]]
  =/  idle=exec-tally:orr  *exec-tally:orr
  ;:  weld
    (expect-eq !>([`'b' ~]) !>([(bind (find-row:orr rows 'b') |=(x=row:orr id.x)) (find-row:orr rows 'z')]))
    (expect-eq !>(`'p') !>((bind (open-twin:orr acts %task 'Call') head)))
    (expect-eq !>(~) !>((open-twin:orr acts %message 'Call')))
    (expect-eq !>(`(list @t)`~['b']) !>((turn (drop (find-run:orr runs 'b')) head)))
    (expect-eq !>(~) !>((find-run:orr runs 'z')))
    (expect-eq !>(`(list @ta)`~[%'schema.json' %'generator.json' %'telegram.json' %'chat.json' %'mail.json' %'read.json' %'policy.json']) !>((turn `(list @t)`~['set-schema' 'set-generator' 'set-telegram' 'set-chat' 'set-mail' 'set-read' 'set-policy'] settings-file:orr)))
    (expect-eq !>('') !>((gs:orr (settings-view:orr 'set-generator' (jo '{"api_key": "sk-secret"}')) 'api_key')))
    (expect-eq !>((jo '{"x": 1}')) !>((settings-view:orr 'set-policy' (jo '{"x": 1}'))))
    (expect-eq !>(`(list json)`~[s+'a' s+'b']) !>((dedupe-json:orr ~[s+'a' s+'b' s+'a'])))
    (expect-eq !>('refused') !>((tang-head:orr ~)))
    (expect-eq !>('no road') !>((tang-head:orr ~[leaf+"no road" leaf+"more"])))
    (expect !>((tally-idle:orr idle)))
    (expect !>(!(tally-idle:orr idle(sent 1))))
    (expect !>(!(tally-idle:orr idle(adopted 1))))
    (expect !>(!(tally-idle:orr idle(failed ~[['a' 't' 'n']]))))
    (expect-eq !>(`(list @t)`~['auspex']) !>(missing:(note-missing:orr (note-missing:orr idle 'auspex') 'auspex')))
    %+  expect-eq  !>((jo '{"op": "act", "ok": true, "why": "", "by": "http", "at": "2026-09-18T12:00:00Z"}'))
    !>((trail-entry:orr 'act' & '' 'http' now))
    %+  expect-eq  !>((jo '{"items": [{"id": "1", "name": "a"}], "note": "n"}'))
    !>((list-json:orr ~[['1' 'a']] 'n'))
  ==
++  test-people-and-briefs
  =/  all=(list loaded:orr)
    :~  ['person/me' [%person 'me' (sy ~['~Bus' 'me']) now `~zod] ~]
        ['person/dana' [%person 'Dana' (sy ~['~bus' '~wet']) now ~] ~]
        ['person/lee' [%person 'Lee' ~ now `~wet] ~]
        ['org/acme' [%org 'Acme' (sy ~['~dev']) now `~nec] ~]
    ==
  =/  bl=json
    (jo '{"text": "second", "tags": {"A1": "a2"}, "today": [{"text": "first", "tags": {"A1": "a1"}}]}')
  ;:  weld
    ::  an alias keys its person, a body's own ship wins over an alias,
    ::  and the owner over anyone
    %+  expect-eq  !>((my ~[['~zod' 'person/me'] ['~bus' 'person/me'] ['~wet' 'person/lee']]))
    !>((people-of-ships:orr all))
    (expect-eq !>(`(list @t)`~['second' 'first']) !>((brief-texts:orr bl)))
    (expect-eq !>(`(list [@t @ta])`~[['A1' 'a1']]) !>((brief-tags:orr bl 'first')))
    (expect-eq !>(`(list [@t @ta])`~[['A1' 'a2']]) !>((brief-tags:orr bl 'second')))
    (expect-eq !>(`(list [@t @ta])`~) !>((brief-tags:orr bl 'third')))
    (expect-eq !>(`(list @t)`~['first']) !>((brief-texts:orr (jo '{"today": [{"text": "first"}]}'))))
  ==
++  test-tg-final-row
  =/  o=json  (jo '{"subject": "person/me", "attr": "status", "value": "x", "message": "telegram/1/2"}')
  =/  f=json  (tg-final-row:orr o 'reader' 'web')
  ;:  weld
    (expect-eq !>((jo '{"kind": "web", "id": "telegram/1/2"}')) !>((gj:orr f 'source')))
    (expect-eq !>(['reader' ~]) !>([(gs:orr f 'by') (gj:orr f 'message')]))
    (expect-eq !>((jo '{"a": 1}')) !>((tg-final-row:orr (jo '{"a": 1}') 'reader' 'chat')))
  ==
++  test-essay-of
  %+  expect-eq  !>(`*`[[~[[%inline ~['one']] [%inline ~['two']]] ~zod now] /chat ~ ~])
  !>((essay-of:orr 'one\0atwo' ~zod now))::  ==  after a crash
::
++  test-rise-plan
  =/  row
    |=  [n=@ud last=@da until=@da]
    ^-  json
    (pairs:enjs:format ~[['n' (numb:enjs:format n)] ['last_ms' (numb:enjs:format (ms-of:orr last))] ['until_ms' (numb:enjs:format (ms-of:orr until))]])
  ;:  weld
    ::  the first crash waits a minute, the next two, then four
    (expect-eq !>([1 (add now ~m1)]) !>((rise-plan:orr ~ & now)))
    (expect-eq !>([2 (add now ~m2)]) !>((rise-plan:orr (row 1 (sub now ~m1) now) & now)))
    (expect-eq !>([3 (add now ~m4)]) !>((rise-plan:orr (row 2 (sub now ~m5) now) & now)))
    ::  never more than an hour
    (expect-eq !>([7 (add now ~h1)]) !>((rise-plan:orr (row 6 (sub now ~h1) now) & now)))
    (expect-eq !>([12 (add now ~h1)]) !>((rise-plan:orr (row 11 (sub now ~h1) now) & now)))
    ::  two quiet hours start the count over; exactly two do not
    (expect-eq !>([1 (add now ~m1)]) !>((rise-plan:orr (row 9 (sub now (add ~h2 ~s1)) now) & now)))
    (expect-eq !>([10 (add now ~h1)]) !>((rise-plan:orr (row 9 (sub now ~h2) now) & now)))
    ::  a refused poke's restart is no crash: the same wait, the same count
    (expect-eq !>([4 (add now ~m7)]) !>((rise-plan:orr (row 4 now (add now ~m7)) | now)))
    ::  the row it writes reads back the same
    %+  expect-eq  !>([3 (add now ~m4)])
    !>((rise-plan:orr (rise-row:orr [3 (add now ~m4)] now) | now))
  ==
++  test-mail-threads
  =/  segs=(list @ta)  ~[(scot %uv 0v1) (scot %uv 0v2) (scot %uv 0v3)]
  =/  many=(list @uv)  (turn (gulf 1 250) |=(i=@ud `@uv`i))
  =/  big=(list @ta)  (turn many |=(t=@uv ^-(@ta (scot %uv t))))
  ;:  weld
    ::  the index's order, only threads the tree holds
    (expect-eq !>((sy ~[(scot %uv 0v2) (scot %uv 0v1)])) !>((mail-threads:orr `~[0v2 0v9 0v1] segs)))
    ::  the most recent two hundred, by the index
    (expect-eq !>(200) !>(~(wyt in (mail-threads:orr `many big))))
    (expect !>((~(has in (mail-threads:orr `many big)) (scot %uv 0v1))))
    (expect !>(!(~(has in (mail-threads:orr `many big)) (scot %uv `@uv`201))))
    ::  no index: two hundred in the tree's order
    (expect-eq !>(3) !>(~(wyt in (mail-threads:orr ~ segs))))
    (expect-eq !>(200) !>(~(wyt in (mail-threads:orr ~ big))))
  ==
--
