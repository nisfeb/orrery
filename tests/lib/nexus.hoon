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
    ['GET' `path`~[%api %preferences] %get-preferences %any]
    ['PUT' `path`~[%api %preferences] %put-preferences %writes]
    ['POST' `path`~[%api %unalias] %post-unalias %own]
    ['POST' `path`~[%api %correct] %post-correct %writes]
    ['GET' `path`~[%api %corrections] %get-corrections %any]
    ['DELETE' `path`~[%api %corrections %x] %delete-corrections %own]
    ['POST' `path`~[%api %instruct] %post-instruct %writes]
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
::  a correction: held at the door, kept newest first and once per fact,
::  taken back by its id, and matched however the value is cased
++  test-corrections
  =/  ref-me  (pairs:enjs:format ~[['ref' s+'person/lena']])
  =/  c1  (de-correct:orr (pairs:enjs:format ~[['subject' s+'situation/trip'] ['attr' s+'participants'] ['value' ref-me] ['why' s+'  she stays home ']]) now)
  =/  c2  (de-correct:orr (jo '{"subject": "person/lin", "attr": "school", "value": "Oak Hill"}') now)
  ?>  ?=(%& -.c1)
  ?>  ?=(%& -.c2)
  =/  stored=json  (add-correction:orr (add-correction:orr [%a ~] p.c1) p.c2)
  =/  again=json  (add-correction:orr stored p.c1(why 'twice'))
  =/  cs=(list correction:orr)  (de-corrections:orr again)
  =/  row
    |=  [id=@t sub=@t attr=@t v=json gone=?]
    ^-  row:orr
    [id [sub attr v now ~ 100 ['calendar' 'u1'] 'calendar' now gone '']]
  =/  rows=(list row:orr)
    :~  (row 'r1' 'situation/trip' 'participants' ref-me |)
        (row 'r2' 'situation/trip' 'participants' (pairs:enjs:format ~[['ref' s+'person/me']]) |)
        (row 'r3' 'situation/trip' 'participants' ref-me &)
        (row 'r4' 'situation/trip' 'organizer' ref-me |)
    ==
  =/  batch=(list (each obs:orr @t))
    :~  [%& obs:(row 'x' 'situation/trip' 'participants' ref-me |)]
        [%& obs:(row 'y' 'person/lin' 'school' s+'OAK HILL' |)]
        [%& obs:(row 'z' 'person/lin' 'school' s+'Elm' |)]
        [%| 'already bad']
    ==
  =/  struck  (strike-obs:orr batch cs)
  ;:  weld
    (expect-eq !>(['situation/trip' 'participants' 'person/lena' 'she stays home' now 'owner']) !>(p.c1))
    (expect-eq !>(`(list @t)`~['person/lena' 'person/lin']) !>((turn cs |=(c=correction:orr ?:(=('person/lin' subject.c) subject.c value.c)))))
    (expect-eq !>('twice') !>(why:(snag 0 cs)))
    (expect-eq !>(1) !>((lent (de-corrections:orr (drop-correction:orr again (correction-id:orr p.c1(why 'twice')))))))
    (expect-eq !>(again) !>((drop-correction:orr again 'nope')))
    (expect-eq !>(`(list @t)`~['r1']) !>((turn (struck-rows:orr rows p.c1) |=(r=row:orr id.r))))
    (expect-eq !>(`(list ?)`~[| | & |]) !>((turn struck |=(e=(each obs:orr @t) ?=(%& -.e)))))
    (expect-eq !>(`(each correction:orr @t)`[%| 'subject: expected <kind>/<slug>']) !>((de-correct:orr (jo '{"subject": "nope", "attr": "a", "value": "b"}') now)))
    (expect-eq !>(`(each correction:orr @t)`[%| 'value: a string or a ref, 1 to 300 bytes']) !>((de-correct:orr (jo '{"subject": "person/a", "attr": "a", "value": {"x": 1}}') now)))
    (expect-eq !>(`(each correction:orr @t)`[%| 'attr: 1 to 48 bytes']) !>((de-correct:orr (jo '{"subject": "person/a", "attr": "", "value": "b"}') now)))
  ==
::  the edges the mutation run found untested: a correction strikes its
::  own subject and attribute only, the caps hold at their bounds, a key
::  sees a ref in its scope, and each list keeps to its own proposer
++  test-learning-edges
  =/  row
    |=  [id=@t sub=@t attr=@t v=json]
    ^-  row:orr
    [id [sub attr v now ~ 100 ['calendar' 'u1'] 'calendar' now | '']]
  =/  c=correction:orr  ['situation/trip' 'venue' 'Oak Hall' '' now 'owner']
  =/  act
    |=  [n=@ud by=@t kind=@tas status=@tas note=@t]
    ^-  [@ta action:orr]
    [(crip "e{(a-co:co n)}") [kind (crip "E{(a-co:co n)}") [%o ~] ~ ~ by (add now (mul n ~s1)) status note ~]]
  =/  mk
    |=  [kind=@tas p=(list [@t json])]
    ^-  action:orr
    [kind 'x' (pairs:enjs:format p) ~ ~ 'generator' now %approved '' ~]
  =/  ok-op
    |=  a=action:orr
    ^-  ?
    =(%& -:(writer-op-of:orr 'a1' a now))
  =/  fact
    |=  [attr=@t v=json]
    ^-  ?
    (ok-op (mk %fact ~[['subject' s+'person/a'] ['attr' s+attr] ['value' v]]))
  =/  corr
    |=  [attr=@t value=@t why=@t]
    ^-  ?
    =(%& -:(de-correct:orr (pairs:enjs:format ~[['subject' s+'person/a'] ['attr' s+attr] ['value' s+value] ['why' s+why]]) now))
  =/  sc  (de-scope:orr (jo '{"kinds": ["situation"], "write": true}'))
  ?>  ?=(%& -.sc)
  =/  key=actor:orr  [| 'k' `p.sc]
  =/  b
    |=  [id=@t name=@t]
    ^-  loaded:orr
    [id [%person name ~ now ~] ~]
  ;:  weld
    %+  expect-eq  !>(`(list @t)`~['r1'])
    !>  %+  turn
          (struck-rows:orr ~[(row 'r1' 'situation/trip' 'venue' s+'oak hall') (row 'r2' 'situation/gala' 'venue' s+'Oak Hall') (row 'r3' 'situation/trip' 'host' s+'Oak Hall')] c)
        |=(r=row:orr id.r)
    %+  expect-eq  !>(`(list ?)`~[| & &])
    !>  %+  turn
          (strike-obs:orr ~[[%& obs:(row 'x' 'situation/trip' 'venue' s+'Oak Hall')] [%& obs:(row 'y' 'situation/gala' 'venue' s+'Oak Hall')] [%& obs:(row 'z' 'situation/trip' 'host' s+'Oak Hall')]] ~[c])
        |=(e=(each obs:orr @t) ?=(%& -.e))
    ::  an approved action's note is not a dismissal; another proposer's
    ::  kept action is not the generator's example
    %+  expect-eq  !>(`(list @t)`~['The owner dismissed these of your proposals, with the reason; do not propose their like:' '  task | E2 | no'])
    !>((lesson-lines:orr ~ ~[(act 1 'mail' %task %approved 'keep it') (act 2 'mail' %task %dismissed 'no')] 'mail'))
    %+  expect-eq  !>(`(list @t)`~['Proposals the owner kept lately (approved or done): what helps. Propose more like these:' '  task | E4'])
    !>((kept-lines:orr ~[(act 3 'mail' %task %done '') (act 4 'generator' %task %done '')]))
    ::  three decided is enough to tell
    (expect-eq !>(2) !>((lent (fared-lines:orr ~[(act 5 'generator' %task %done '') (act 6 'generator' %task %done '') (act 7 'generator' %task %dismissed 'x')]))))
    (expect-eq !>(1) !>((lent (corrections-for:orr key ~[['situation/trip' 'follows' 'situation/gala' '' now 'owner']] ~))))
    ::  an about body comes once, and a three-letter name is said
    (expect-eq !>(`(list @t)`~['person/an']) !>((turn (instruct-focus:orr ~[(b 'person/an' 'Ann')] (sy ~['person/an']) 'ann is home') |=(l=loaded:orr id.l))))
    (expect-eq !>(`(list @t)`~['person/bo']) !>((turn (instruct-focus:orr ~[(b 'person/bo' 'Bob')] ~ 'bob is here') |=(l=loaded:orr id.l))))
    %+  expect-eq  !>(`(list ?)`~[& | & | & |])
    !>  ^-  (list ?)
        :~  (corr (fil 3 48 'a') 'v' '')  (corr (fil 3 49 'a') 'v' '')
            (corr 'a' (fil 3 300 'v') '')  (corr 'a' (fil 3 301 'v') '')
            (corr 'a' 'v' (fil 3 500 'w'))  (corr 'a' 'v' (fil 3 501 'w'))
        ==
    %+  expect-eq  !>(`(list ?)`~[& | | | &])
    !>  ^-  (list ?)
        :~  (fact (fil 3 48 'a') s+'v')  (fact (fil 3 49 'a') s+'v')  (fact 'a' ~)
            (fact 'a' a+~[s+'v'])  (fact 'a' (pairs:enjs:format ~[['ref' s+'person/b']]))
        ==
    %+  expect-eq  !>(`(list ?)`~[| | & |])
    !>  ^-  (list ?)
        :~  (ok-op (mk %merge ~[['from' s+'nope'] ['into' s+'person/b']]))
            (ok-op (mk %merge ~[['from' s+'person/a'] ['into' s+'nope']]))
            (ok-op (mk %preference ~[['text' s+(fil 3 300 'p')]]))
            (ok-op (mk %preference ~[['text' s+(fil 3 301 'p')]]))
        ==
  ==
::  a key sees the corrections its view would show, the owner all
++  test-corrections-for
  =/  sc  (de-scope:orr (jo '{"kinds": ["situation"], "write": true}'))
  ?>  ?=(%& -.sc)
  =/  cs=(list correction:orr)
    :~  ['situation/trip' 'participants' 'person/lena' '' now 'owner']
        ['situation/trip' 'venue' 'Oak Hall' '' now 'owner']
        ['situation/trip' 'health' 'flu' '' now 'owner']
        ['person/lin' 'school' 'Oak Hill' '' now 'owner']
    ==
  =/  key=actor:orr  [| 'k' `p.sc]
  ;:  weld
    (expect-eq !>(4) !>((lent (corrections-for:orr [& 'http' ~] cs (sy ~['health'])))))
    (expect-eq !>(`(list @t)`~['venue']) !>((turn (corrections-for:orr key cs (sy ~['health'])) |=(c=correction:orr attr.c))))
  ==
::  what the readers and the generator are told of the owner's feedback
++  test-lessons
  =/  act
    |=  [n=@ud by=@t kind=@tas status=@tas note=@t]
    ^-  [@ta action:orr]
    :-  (crip "a{(a-co:co n)}")
    [kind (crip "T{(a-co:co n)}") (pairs:enjs:format ~[['notes' s+'bring the forms']]) ~ ~ by (add now (mul n ~s1)) status note ~]
  =/  acts=(list [@ta action:orr])
    :~  (act 1 'mail' %task %dismissed 'a refund')
        (act 2 'mail' %task %dismissed '')
        (act 3 'chat' %message %dismissed 'not ours')
        (act 4 'generator' %task %done '')
        (act 5 'generator' %task %approved '')
        (act 6 'generator' %task %dismissed 'no')
        (act 7 'generator' %task %dismissed 'no')
    ==
  =/  c=correction:orr  ['situation/trip' 'participants' 'person/lena' 'she stays home' now 'owner']
  ;:  weld
    %+  expect-eq
      !>  ^-  (list @t)
      :~  'The owner struck these facts as wrong; never write them again:'
          '  situation/trip participants = person/lena (she stays home)'
          'The owner dismissed these of your proposals, with the reason; do not propose their like:'
          '  task | T1 | a refund'
      ==
    !>((lesson-lines:orr ~[c] acts 'mail'))
    (expect-eq !>(`(list @t)`~) !>((lesson-lines:orr ~ acts 'telegram')))
    %+  expect-eq
      !>(`(list @t)`~['Proposals the owner kept lately (approved or done): what helps. Propose more like these:' '  task | T5 | bring the forms' '  task | T4 | bring the forms'])
    !>((kept-lines:orr acts))
    %+  expect-eq
      !>(`(list @t)`~['How proposals fared (kept of decided, by who proposed them and kind):' '  generator task: kept 2 of 4'])
    !>((fared-lines:orr acts))
  ==
::  what each kind the ship carries out itself asks of its writer, and
::  the executor's plan for it
++  test-writer-kinds
  =/  mk
    |=  [kind=@tas p=@t]
    ^-  action:orr
    [kind 'x' (jo p) ~ ~ 'generator' now %approved '' ~]
  =/  op
    |=  a=action:orr
    ^-  json
    =/  w  (writer-op-of:orr 'a1' a now)
    ?>(?=(%& -.w) p.w)
  =/  bad
    |=  a=action:orr
    ^-  @t
    =/  w  (writer-op-of:orr 'a1' a now)
    ?>(?=(%| -.w) p.w)
  =/  fact=json  (op (mk %fact '{"subject": "person/lin", "attr": "school", "value": "Oak Hill"}'))
  ::  a merge is left to run-merges, which checks it took
  =/  plans  (plan-exec:orr ~[['c1' (mk %correct '{"subject": "situation/trip", "attr": "participants", "value": {"ref": "person/lena"}}')] ['m1' (mk %merge '{"from": "person/a", "into": "person/b"}')] ['p1' (mk %preference '{"text": ""}')]] ~ ~ ~ now '' ['' ''])
  ;:  weld
    (expect-eq !>('correct') !>((gs:orr (op (mk %correct '{"subject": "situation/trip", "attr": "participants", "value": {"ref": "person/lena"}, "why": "home"}')) 'op')))
    (expect-eq !>('observe') !>((gs:orr fact 'op')))
    (expect-eq !>('owner') !>((gs:orr (gj:orr (snag 0 (ga:orr fact 'observations')) 'source') 'kind')))
    (expect-eq !>('Oak Hill') !>((gs:orr (snag 0 (ga:orr fact 'observations')) 'value')))
    (expect-eq !>((merge-op:orr 'person/a' 'person/b')) !>((op (mk %merge '{"from": "person/a", "into": "person/b"}'))))
    (expect-eq !>('add-preference') !>((gs:orr (op (mk %preference '{"text": " Never a todo for attending "}')) 'op')))
    (expect-eq !>('person/me cannot be merged away') !>((bad (mk %merge '{"from": "person/me", "into": "person/b"}'))))
    (expect-eq !>('value: a string, a number, true or false, or a ref') !>((bad (mk %fact '{"subject": "person/lin", "attr": "school", "value": {"x": 1}}'))))
    (expect-eq !>('text: 1 to 300 bytes') !>((bad (mk %preference '{"text": ""}'))))
    (expect-eq !>(`(list @t)`~['c1' 'p1']) !>((turn plans |=(p=exec-plan:orr `@t`id.p))))
    (expect-eq !>(`(list ?)`~[& &]) !>((turn plans |=(p=exec-plan:orr =(%writer target.p)))))
    (expect-eq !>(`(list @t)`~['' 'text: 1 to 300 bytes']) !>((turn plans |=(p=exec-plan:orr note.p))))
  ==
::  the model's answer to an instruction, held: kinds it may propose,
::  bodies the ship knows, a writer's kind whole, a default title
++  test-de-instruct
  =/  known=(set @t)  (sy ~['situation/trip' 'person/lena' 'person/me'])
  =/  ans=json
    %-  jo
    '''
    {"reply": "  Takes Lena off the trip. ",
     "actions": [
      {"kind": "correct", "title": "Lena is not on the trip", "about": ["situation/trip", "person/nobody"],
       "payload": {"subject": "situation/trip", "attr": "participants", "value": {"ref": "person/lena"}, "why": "she stays home"}},
      {"kind": "correct", "payload": {"subject": "situation/trip", "attr": "participants", "value": {"ref": "person/lena"}}},
      {"kind": "home", "title": "lights", "payload": {}},
      {"kind": "merge", "title": "one", "payload": {"from": "person/ghost", "into": "person/me"}},
      {"kind": "fact", "title": "bad", "payload": {"subject": "person/lena", "attr": "", "value": "x"}},
      {"kind": "preference", "title": "rule", "payload": {"text": "Lena stays home when I travel for work"}}]}
    '''
  =/  out  (de-instruct:orr ans known now 'owner')
  ;:  weld
    (expect-eq !>('Takes Lena off the trip.') !>(reply.out))
    (expect-eq !>(`(list @t)`~['correct' 'correct' 'preference']) !>((turn acts.out |=(j=json (gs:orr j 'kind')))))
    (expect-eq !>(`(list @t)`~['situation/trip']) !>((strings:orr (ga:orr (snag 0 acts.out) 'about'))))
    (expect-eq !>('correct') !>((gs:orr (snag 1 acts.out) 'title')))
    (expect-eq !>('owner') !>((gs:orr (snag 0 acts.out) 'by')))
    (expect-eq !>(3) !>((lent notes.out)))
  ==
::  the bodies an instruction is likely about: the answered action's
::  first, then the ones it names
++  test-instruct-focus
  =/  b
    |=  [id=@t name=@t als=(list @t)]
    ^-  loaded:orr
    [id [%person name (sy als) now ~] ~]
  =/  all=(list loaded:orr)
    :~  (b 'person/lena' 'Lena' ~['wife'])
        (b 'person/lin' 'Lin' ~)
        (b 'situation/trip' 'Barcelona trip' ~)
        (b 'person/al' 'Al' ~)
    ==
  ;:  weld
    (expect-eq !>(`(list @t)`~['situation/trip' 'person/lena']) !>((turn (instruct-focus:orr all (sy ~['situation/trip']) 'my Wife stays home') |=(l=loaded:orr id.l))))
    (expect-eq !>(`(list @t)`~) !>((turn (instruct-focus:orr all ~ 'al is here') |=(l=loaded:orr id.l))))
  ==
::  an alias comes off however it is cased or spaced, and the rest stay
++  test-without-alias
  =/  b=body:orr  [%person 'Lena' (sy ~['jackson' '~ricsul-bilwyt-dozzod-nisfeb' 'wife']) now `~wet]
  ;:  weld
    (expect-eq !>((sy ~['jackson' 'wife'])) !>(aliases:(without-alias:orr b ' ~Ricsul-Bilwyt-Dozzod-Nisfeb ')))
    (expect-eq !>(b) !>((without-alias:orr b 'nobody')))
  ==
::  a preferences request: the fields given are checked and trimmed, a
::  field left out is left as it is, and the rest of the schema stands
++  test-preferences
  =/  schema=json  (jo '{"kinds": {"person": {}}, "style": "old", "preferences": ["a"]}')
  =/  both  (de-preferences:orr (jo '{"style": "  Short.  ", "preferences": [" one ", "", "two"]}'))
  =/  only  (de-preferences:orr (jo '{"preferences": []}'))
  ;:  weld
    (expect-eq !>(`(each [(unit @t) (unit (list @t))] @t)`[%& `'Short.' `~['one' 'two']]) !>(both))
    (expect-eq !>(`(each [(unit @t) (unit (list @t))] @t)`[%& ~ `~]) !>(only))
    (expect-eq !>(`(each [(unit @t) (unit (list @t))] @t)`[%| 'style or preferences: required']) !>((de-preferences:orr (jo '{"other": 1}'))))
    (expect-eq !>(`(each [(unit @t) (unit (list @t))] @t)`[%| 'style: a string is required']) !>((de-preferences:orr (jo '{"style": 5}'))))
    (expect-eq !>(`(each [(unit @t) (unit (list @t))] @t)`[%| 'preferences: a list of strings is required']) !>((de-preferences:orr (jo '{"preferences": ["a", 5]}'))))
    (expect-eq !>(`(each [(unit @t) (unit (list @t))] @t)`[%| 'style: over 1000 bytes']) !>((de-preferences:orr (pairs:enjs:format ~[['style' s+(crip (reap 1.001 'x'))]]))))
    (expect-eq !>(`(each [(unit @t) (unit (list @t))] @t)`[%| 'preferences: over 30']) !>((de-preferences:orr (pairs:enjs:format ~[['preferences' a+(reap 31 `json`s+'x')]]))))
    (expect-eq !>(`(each [(unit @t) (unit (list @t))] @t)`[%| 'preferences: one is over 300 bytes']) !>((de-preferences:orr (pairs:enjs:format ~[['preferences' a+~[s+(crip (reap 301 'x'))]]]))))
    (expect-eq !>(`(each [(unit @t) (unit (list @t))] @t)`[%| 'a JSON object is required']) !>((de-preferences:orr (jo '[1]'))))
    ::  each cap itself is allowed
    (expect !>(=(& -:(de-preferences:orr (pairs:enjs:format ~[['style' s+(crip (reap 1.000 'x'))]])))))
    (expect !>(=(& -:(de-preferences:orr (pairs:enjs:format ~[['preferences' a+(reap 30 `json`s+'x')]])))))
    (expect !>(=(& -:(de-preferences:orr (pairs:enjs:format ~[['preferences' a+~[s+(crip (reap 300 'x'))]]])))))
    %+  expect-eq
      !>((jo '{"kinds": {"person": {}}, "style": "old", "preferences": ["one"]}'))
    !>((with-preferences:orr schema ~ `~['one']))
    (expect-eq !>((jo '{"style": "old", "preferences": ["a"]}')) !>((preferences-json:orr schema)))
    (expect-eq !>((jo '{"style": "", "preferences": []}')) !>((preferences-json:orr (jo '{}'))))
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
++  test-own-todo
  =/  todo=json  (jo '{"todo": "0v1.abc"}')
  ;:  weld
    (expect !>((own-todo:orr [%task 'Pay the mortgage' todo ~ ~ 'calendar' now %proposed '' ~])))
    ::  only the calendar's own filing, only a task, only with its todo
    (expect !>(!(own-todo:orr [%task 'Pay the mortgage' todo ~ ~ 'generator' now %proposed '' ~])))
    (expect !>(!(own-todo:orr [%calendar 'Pay the mortgage' todo ~ ~ 'calendar' now %proposed '' ~])))
    (expect !>(!(own-todo:orr [%task 'Pay the mortgage' ~ ~ ~ 'calendar' now %proposed '' ~])))
    (expect !>(!(own-todo:orr [%task 'Pay the mortgage' (jo '{"todo": ""}') ~ ~ 'calendar' now %proposed '' ~])))
  ==
::  ==  a situation resolved (version 64)
::
++  test-resolve
  =/  sit=@t  'situation/2026-09-24-boiler'
  =/  res=action:orr
    [%resolve 'Close the boiler' (jo '{"situation": "situation/2026-09-24-boiler", "outcome": " fixed, hot water back "}') ~ ~ 'generator' now %approved '' ~]
  =/  w  (writer-op-of:orr 'a1' res now)
  =/  rows=(list json)  ?:(?=(%& -.w) (ga:orr p.w 'observations') ~)
  =/  nag=action:orr  [%task 'Chase the plumber' ~ (sy ~[sit 'person/me']) ~ 'generator' now %proposed '' ~]
  =/  acts=(list [id=@ta a=action:orr])
    :~  ['r' res(status %done)]  ['n' nag]
        ['k' nag(title 'Pay the plumber', status %approved)]
        ['e' nag(title 'Other', about (sy ~['situation/other']))]
        ['b' nag(title 'Both', about (sy ~[sit 'situation/other']))]
        ['p' nag(title 'No situation', about (sy ~['person/me']))]
    ==
  =/  quiets  (quiets:orr acts (my ~[[sit 'resolved: fixed']]) 'ship')
  ::  as reconcile finds them: closed with an outcome, closed by the
  ::  clock with none, cancelled, and one still open
  =/  cl
    |=  [id=@t kvs=(list [@t @t])]
    ^-  loaded:orr
    [id [%situation id ~ now ~] (turn kvs |=([k=@t v=@t] (r (cat 3 id k) (ob id k s+v now))))]
  =/  over
    %:  over-situations:orr
      :~  (cl 'situation/a' ~[['status' 'closed'] ['outcome' 'paid']])
          (cl 'situation/b' ~[['status' 'closed']])
          (cl 'situation/c' ~[['status' 'cancelled']])
          (cl 'situation/d' ~[['status' 'open'] ['outcome' 'was fixed once']])
          ['person/me' [%person 'me' ~ now ~] ~[(r 'me-status' (ob 'person/me' 'status' s+'closed' now))]]
      ==
      ~  now
    ==
  ;:  weld
    ::  closed with how it ended, both rows the owner's, sourced to the action
    (expect-eq !>(`(list [@t @t])`~[['status' 'closed'] ['outcome' 'fixed, hot water back']]) !>((turn rows |=(r=json [(gs:orr r 'attr') (gs:orr r 'value')]))))
    (expect !>((levy rows |=(r=json &(=(sit (gs:orr r 'subject')) =('owner' (gs:orr r 'by')) =('a1' (gs:orr (gj:orr r 'source') 'id')) =('owner' (gs:orr (gj:orr r 'source') 'kind')))))))
    ::  only a situation, and only with an outcome
    (expect-eq !>(`(each json @t)`[%| 'situation: expected situation/<slug>']) !>((writer-op-of:orr 'a1' res(payload (jo '{"situation": "person/me", "outcome": "x"}')) now)))
    (expect-eq !>(`(each json @t)`[%| 'outcome: 1 to 200 bytes']) !>((writer-op-of:orr 'a1' res(payload (jo '{"situation": "situation/x", "outcome": " "}')) now)))
    ::  what was only proposed about it is dismissed; what the owner
    ::  approved, what is about another situation, what is also about one
    ::  still open, what is about no situation and the resolve itself stay
    (expect-eq !>(1) !>((lent quiets)))
    (expect-eq !>(['n' 'dismissed' 'resolved: fixed' 'ship']) !>(=/(q (snag 0 quiets) [(gs:orr q 'id') (gs:orr q 'status') (gs:orr q 'note') (gs:orr q 'by')])))
    ::  with the other situation over too, both of them go
    (expect-eq !>(`(list @t)`~['n' 'e' 'b']) !>((turn (quiets:orr acts (my ~[[sit 'resolved: fixed'] ['situation/other' 'closed']]) 'reconcile') |=(q=json (gs:orr q 'id')))))
    ::  what is over, and what a dismissal says of each
    (expect-eq !>(`(map @t @t)`(my ~[['situation/a' 'resolved: paid'] ['situation/b' 'closed'] ['situation/c' 'cancelled']])) !>(over))
  ==
++  test-moot
  =/  a=action:orr  [%task 'Chase the plumber' ~ ~ ~ 'generator' now %dismissed 'resolved: fixed' ~[[now %proposed 'generator'] [now %dismissed 'ship']]]
  =/  said=action:orr  a(note 'not now', history ~[[now %proposed 'generator'] [now %dismissed 'user']])
  =/  acts=(list [id=@ta a=action:orr])  ~[['a' a] ['s' said]]
  ;:  weld
    (expect !>((moot:orr a)))
    (expect !>((moot:orr a(history ~[[now %dismissed 'reconcile']]))))
    (expect !>(!(moot:orr said)))
    (expect !>(!(moot:orr a(status %proposed))))
    (expect !>(!(moot:orr a(history ~))))
    ::  the ship's own dismissal is no taste of the owner's: it is in no
    ::  tally, among no reasons, and no reader is told of it
    (expect-eq !>(`(list [@t @ud])`~[['not now' 1]]) !>((turn (reason-counts:orr acts) |=([r=@t c=@ud *] [r c]))))
    (expect-eq !>(`(list @ud)`~[1]) !>((turn (proposal-tally:orr acts) |=(t=tally-row:orr dismissed.t))))
    (expect-eq !>(0) !>((lent (lesson-lines:orr ~ ~[['a' a]] 'generator'))))
    (expect-eq !>(2) !>((lent (lesson-lines:orr ~ acts 'generator'))))
    ::  nor is it among the decisions the generator is shown
    (expect-eq !>(`(list @t)`~['head' '  dismissed | task | Chase the plumber | not now']) !>((decision-lines:orr 'head' acts)))
  ==
++  test-schema-upgrade
  =/  old=json
    %-  jo
    '{"kinds": {"person": {"attrs": ["status"], "notes": {"status": "mine"}}, "situation": {"attrs": ["status", "transcript", "needs"], "notes": {"needs": "my own words"}}}, "actions": ["task", "note", "fact"], "payloads": {"fact": {"mine": "kept"}}, "multi": ["participants"], "style": "plain", "preferences": ["never calls"]}'
  =/  new=json  (schema-upgrade:orr old)
  =/  sit=json  (gj:orr (gj:orr new 'kinds') 'situation')
  =/  starter-note
    |=  [kind=@t attr=@t]
    ^-  @t
    (gs:orr (gj:orr (gj:orr (gj:orr starter-schema:orr 'kinds') kind) 'notes') attr)
  ::  a document that took version 60's keys by hand gains only 64's
  =/  at60=json  (schema-upgrade:orr (set-key:orr old 'schema_version' (numb:enjs:format 60)))
  ::  a kind the document does not have is not made
  =/  bare=json  (schema-upgrade:orr (jo '{"kinds": {"person": {"attrs": ["status"]}}, "actions": ["task"]}'))
  ;:  weld
    ::  the kinds and their shapes are added after the owner's own
    (expect-eq !>(`(list @t)`~['task' 'note' 'fact' 'correct' 'merge' 'preference' 'resolve']) !>((strings:orr (ga:orr new 'actions'))))
    (expect-eq !>((jo '{"mine": "kept"}')) !>((gj:orr (gj:orr new 'payloads') 'fact')))
    (expect-eq !>((gj:orr (gj:orr starter-schema:orr 'payloads') 'resolve')) !>((gj:orr (gj:orr new 'payloads') 'resolve')))
    (expect !>((has-key:orr (gj:orr new 'payloads') 'correct')))
    ::  the attributes go on the end, the owner's own and their order kept
    (expect-eq !>(`(list @t)`~['status' 'transcript' 'needs' 'waiting-on' 'outcome' 'attending' 'leave-by' 'drop-off' 'pick-up' 'away' 'sphere']) !>((strings:orr (ga:orr sit 'attrs'))))
    (expect-eq !>(`(list @t)`~['status' 'spouse' 'children' 'parents' 'siblings' 'steps-target' 'sleep-target' 'bedtime-target' 'sphere']) !>((strings:orr (ga:orr (gj:orr (gj:orr new 'kinds') 'person') 'attrs'))))
    ::  a note in the owner's words stays; a missing one is the starter's
    (expect-eq !>('my own words') !>((gs:orr (gj:orr sit 'notes') 'needs')))
    (expect-eq !>((starter-note 'situation' 'outcome')) !>((gs:orr (gj:orr sit 'notes') 'outcome')))
    (expect-eq !>('mine') !>((gs:orr (gj:orr (gj:orr (gj:orr new 'kinds') 'person') 'notes') 'status')))
    (expect-eq !>(`(list @t)`~['participants' 'children' 'parents' 'siblings' 'sphere' 'drop-off' 'pick-up']) !>((strings:orr (ga:orr new 'multi'))))
    ::  nothing else moves, and the mark says where it stands
    (expect-eq !>(['plain' `(list @t)`~['never calls']]) !>([(gs:orr new 'style') (strings:orr (ga:orr new 'preferences'))]))
    (expect-eq !>(`(unit @ud)`[~ 87]) !>((gn:orr new 'schema_version')))
    ::  once: a second pass, and a new ship's starter, come back as they are
    (expect-eq !>(new) !>((schema-upgrade:orr new)))
    (expect-eq !>(starter-schema:orr) !>((schema-upgrade:orr starter-schema:orr)))
    (expect-eq !>(`(list @t)`~['task' 'note' 'fact' 'resolve']) !>((strings:orr (ga:orr at60 'actions'))))
    (expect-eq !>(`(list @t)`~['status' 'steps-target' 'sleep-target' 'bedtime-target' 'sphere']) !>((strings:orr (ga:orr (gj:orr (gj:orr at60 'kinds') 'person') 'attrs'))))
    (expect !>(!(has-key:orr (gj:orr bare 'kinds') 'situation')))
    (expect-eq !>(`(list @t)`~['children' 'parents' 'siblings' 'sphere' 'drop-off' 'pick-up']) !>((strings:orr (ga:orr bare 'multi'))))
    ::  but a kind a release brought in is made whole
    (expect-eq !>((gj:orr (gj:orr starter-schema:orr 'kinds') 'sphere')) !>((gj:orr (gj:orr bare 'kinds') 'sphere')))
    (expect-eq !>(`json`s+'x') !>((schema-upgrade:orr s+'x')))
    ::  the ledger names nothing the starter lacks: a release that adds
    ::  a row without the starter's shape or note fails here
    (expect-eq !>(starter-schema:orr) !>((schema-upgrade:orr (del-key:orr starter-schema:orr 'schema_version'))))
    %-  expect  !>
    %+  levy  schema-adds:orr
    |=  a=schema-add:orr
    ?&  (levy actions.a |=(k=@t (has-key:orr (gj:orr starter-schema:orr 'payloads') k)))
        %+  levy  kinds.a
        |=  [kind=@t attrs=(list @t)]
        =/  notes=json  (gj:orr (gj:orr (gj:orr starter-schema:orr 'kinds') kind) 'notes')
        (levy attrs |=(n=@t (has-key:orr notes n)))
    ==
  ==
::  ==  a lattice page followed (version 66)
::
++  test-follow
  =/  moves=json
    %-  jo
    '{"moves": [{"from": "trips/lisbon-2", "to": "trips/lisbon-3", "at_ms": 3}, {"from": "trips", "to": "travel", "at_ms": 2}, {"from": "notes/lisbon", "to": "trips/lisbon-2", "at_ms": 1}]}'
  =/  mk
    |=  [id=@t name=@t attrs=(list [a=@t v=@t])]
    ^-  loaded:orr
    :+  id  [%situation name ~ now ~]
    %+  turn  attrs
    |=  [a=@t v=@t]
    ^-  row:orr
    [(rap 3 id '/' a ~) [id a s+v now ~ 100 ['t' 'x'] 'owner' now | '']]
  =/  sit=loaded:orr  (mk 'situation/lisbon' 'Trip to Lisbon' ~[['status' 'closed'] ['outcome' 'flew home'] ['needs' 'a hotel']])
  =/  off=loaded:orr  (mk 'situation/porto' 'Trip to Porto' ~[['status' 'cancelled']])
  ::  a page moved twelve times: the follow goes ten hops and stops
  =/  chain=json
    :-  %o
    %+  ~(put by *(map @t json))  'moves'
    :-  %a
    %+  turn  (gulf 0 11)
    |=  i=@ud
    ^-  json
    (pairs:enjs:format ~[['from' s+(cat 3 'p' (scot %ud i))] ['to' s+(cat 3 'p' (scot %ud +(i)))]])
  =/  open=loaded:orr  (mk 'situation/rome' 'Trip to Rome' ~[['status' 'open'] ['needs' 'a hotel'] ['waiting-on' 'person/sarah']])
  =/  acts=(list [id=@ta a=action:orr])
    :~  ['a1' [%task 'Book the hotel' ~ (sy ~['situation/rome']) ~ 'generator' now %approved '' ~]]
        ['a2' [%task 'Pack' ~ (sy ~['situation/rome']) ~ 'generator' now %done '' ~]]
        ['a3' [%task 'Other' ~ (sy ~['situation/lisbon']) ~ 'generator' now %proposed '' ~]]
    ==
  =/  doc=json  (jo '{"path": "trips/rome", "situation": "situation/rome", "status": "following", "note": "", "read_at": "2026-09-18T11:00:00Z"}')
  =/  done=json  (jo '{"path": "trips/lisbon", "situation": "situation/lisbon", "status": "following", "note": ""}')
  =/  view=json  (follow-view:orr doc ~[sit open] ~ acts now)
  =/  facts=tg-facts:orr  [~[(jo '{"id": "thing/ticket", "kind": "thing", "name": "Ticket"}')] ~[(jo '{"subject": "situation/rome", "attr": "needs", "value": "a hotel"}')] ~ ~ ~]
  =/  text  (follow-text:orr 'trips/rome' 'Rome' 'Fly Friday.' ~[['trips/flights' 'TAP 1234']] `['situation/rome' 'Trip to Rome'])
  ;:  weld
    ::  the grub's name is the page's; a page path is segments, or nothing
    (expect-eq !>((follow-name:orr 'trips/rome')) !>((follow-name:orr 'trips/rome')))
    (expect !>(!=((follow-name:orr 'trips/rome') (follow-name:orr 'trips/roma'))))
    (expect-eq !>(`(unit path)`[~ /trips/rome]) !>((page-segs:orr 'trips/rome')))
    ::  an empty segment is dropped, as lattice's own paths never carry one
    (expect-eq !>(`(unit path)`[~ /trips/rome]) !>((page-segs:orr 'trips//rome')))
    (expect-eq !>(`(unit path)`~) !>((page-segs:orr 'Trips/Rome')))
    (expect-eq !>(`(unit path)`~) !>((page-segs:orr '')))
    ::  the text names whose page it is, the situation it is the record
    ::  of, the page, and each linked page under its path
    (expect !>(?=([~ %0] (find "The owner's own page \"Rome\" (lattice page trips/rome). It is their record of Trip to Rome (situation/rome), which the ship already holds: what it says moves that situation on.\0a\0aFly Friday." (trip text)))))
    (expect !>(?=(^ (find "\0aFly Friday.\0a\0a--- linked page trips/flights ---\0aTAP 1234" (trip text)))))
    (expect !>(?=(~ (find "record of" (trip (follow-text:orr 'p' '' 'x' ~ ~))))))
    (expect !>(?=(^ (find "page \"p\" (lattice page p)" (trip (follow-text:orr 'p' '' 'x' ~ ~))))))
    (expect-eq !>(follow-cap:orr) !>((met 3 (follow-text:orr 'p' '' (crip (reap 70.000 'a')) ~ ~))))
    ::  moves: a page moved, moved again, a folder moved over it; one never moved
    (expect-eq !>(`(unit @t)`[~ 'travel/lisbon-3']) !>((moved-to:orr 'notes/lisbon' moves)))
    (expect-eq !>(`(unit @t)`[~ 'travel/lisbon-3']) !>((moved-to:orr 'trips/lisbon-2' moves)))
    (expect-eq !>(`(unit @t)`[~ 'travel/porto']) !>((moved-to:orr 'trips/porto' moves)))
    (expect-eq !>(`(unit @t)`~) !>((moved-to:orr 'tripsy/porto' moves)))
    (expect-eq !>(`(unit @t)`~) !>((moved-to:orr 'notes/other' moves)))
    (expect-eq !>(`(unit @t)`~) !>((moved-to:orr 'notes/other' [%o ~])))
    (expect-eq !>(`(unit @t)`[~ 'p10']) !>((moved-to:orr 'p0' chain)))
    ::  the situation a read made: the first the urgent pass would look at
    (expect-eq !>(`(unit @t)`[~ 'situation/rome']) !>((facts-situation:orr facts)))
    (expect-eq !>(`(unit @t)`~) !>((facts-situation:orr [~[(jo '{"id": "thing/ticket", "kind": "thing", "name": "Ticket"}')] ~ ~ ~ ~])))
    ::  over: closed or cancelled, or gone from the ship
    (expect !>((follow-over:orr done ~[sit open] ~ now)))
    (expect !>((follow-over:orr (jo '{"path": "p", "situation": "situation/porto", "status": "following"}') ~[off] ~ now)))
    (expect !>(!(follow-over:orr doc ~[sit open] ~ now)))
    (expect !>((follow-over:orr doc ~[sit] ~ now)))
    (expect !>(!(follow-over:orr (jo '{"path": "p"}') ~[sit] ~ now)))
    ::  the view: the record with the situation as it stands
    (expect-eq !>(['following' 'situation/rome' 'Trip to Rome' 'a hotel']) !>([(gs:orr view 'status') (gs:orr view 'situation') (gs:orr view 'title') (gs:orr view 'needs')]))
    (expect-eq !>([`(unit @ud)`[~ 1] 'person/sarah' '' '2026-09-18T11:00:00Z']) !>([(gn:orr view 'open') (gs:orr view 'waiting_on') (gs:orr view 'outcome') (gs:orr view 'read_at')]))
    ::  what is still proposed about a resolved situation counts until reconcile quiets it
    (expect-eq !>(['resolved' 'flew home' `(unit @ud)`[~ 1]]) !>(=/(v (follow-view:orr done ~[sit open] ~ acts now) [(gs:orr v 'status') (gs:orr v 'outcome') (gn:orr v 'open')])))
    (expect-eq !>(['failed' ~]) !>(=/(v (follow-view:orr (jo '{"path": "p", "status": "failed", "note": "gone"}') ~[sit] ~ acts now) [(gs:orr v 'status') (gj:orr v 'situation')])))
    ::  only a follow that stands reads resolved when its situation is over: one failed or queued stays so
    (expect-eq !>(['failed' 'queued']) !>([(gs:orr (follow-view:orr (jo '{"path": "p", "situation": "situation/lisbon", "status": "failed"}') ~[sit] ~ acts now) 'status') (gs:orr (follow-view:orr (jo '{"path": "p", "situation": "situation/lisbon", "status": "queued"}') ~[sit] ~ acts now) 'status')]))
  ==
::  ==  the brief state view (version 67)
::
++  test-brief
  =/  mk
    |=  [id=@t kind=@tas name=@t attrs=(list [a=@t v=json])]
    ^-  loaded:orr
    :+  id  [kind name ~ now ~]
    %+  turn  attrs
    |=  [a=@t v=json]
    ^-  row:orr
    [(rap 3 id '/' a ~) [id a v now ~ 90 ['t' 'x'] 'owner' now | '']]
  =/  all=(list loaded:orr)
    :~  (mk 'person/wren' %person 'Wren' ~[['relationship' s+'daughter'] ['likes' s+'ballet'] ['likes' s+'swimming']])
        (mk 'situation/trip' %situation 'Trip to Lisbon' ~[['status' s+'open'] ['needs' s+'a hotel'] ['waiting-on' s+'person/wren'] ['participants' o+(~(put by *(map @t json)) 'ref' s+'person/wren')] ['starts' s+'2026-12-12T17:00:00Z']])
        (mk 'situation/done' %situation 'Over' ~[['status' s+'closed'] ['outcome' s+'fine']])
    ==
  =/  acts=(list [id=@ta a=action:orr])
    :~  ['a1' [%task 'Book the hotel' (jo '{"notes": "near Alfama"}') (sy ~['situation/trip']) `~2026.12.11 'generator' now %approved '' ~[[now %approved 'policy']]]]
        ['a2' [%task 'Old' ~ ~ ~ 'generator' now %done '' ~]]
    ==
  =/  multi=(set @t)  (sy ~['likes' 'participants'])
  =/  schema=json  (jo '{"kinds": {"person": {"attrs": ["status", "likes"], "notes": {"likes": "x"}}, "situation": {"attrs": ["status", "needs"]}}, "multi": ["likes", "participants"], "style": "s"}')
  =/  v=json  (brief-json:orr all acts multi now '' (numb:enjs:format 7) schema)
  =/  wren=json  (snag 0 (ga:orr v 'bodies'))
  =/  lisbon=json  (snag 1 (ga:orr v 'bodies'))
  =/  text=@t  (en:json:html v)
  ;:  weld
    (expect !>(?=([%b %.y] (gj:orr v 'brief'))))
    ::  values only: a single value as it is, a multi as the list, a ref as a ref
    (expect-eq !>('daughter') !>((gs:orr (gj:orr wren 'attrs') 'relationship')))
    (expect-eq !>(`(list @t)`~['ballet' 'swimming']) !>((sort (strings:orr (ga:orr (gj:orr wren 'attrs') 'likes')) aor)))
    (expect-eq !>(`(list @t)`~['situation/trip']) !>((strings:orr (ga:orr wren 'involved'))))
    (expect-eq !>((jo '{"ref": "person/wren"}')) !>((snag 0 (ga:orr (gj:orr lisbon 'attrs') 'participants'))))
    ::  no provenance anywhere
    (expect !>(?=(~ (find "\"source\"" (trip text)))))
    (expect !>(?=(~ (find "\"conf\"" (trip text)))))
    (expect !>(?=(~ (find "\"history\"" (trip text)))))
    ::  the open situations with what they need; the closed one is not among them
    (expect-eq !>(1) !>((lent (ga:orr v 'situations'))))
    (expect-eq !>(['situation/trip' 'Trip to Lisbon' 'open' 'a hotel' 'person/wren' '2026-12-12T17:00:00Z']) !>(=/(s (snag 0 (ga:orr v 'situations')) [(gs:orr s 'id') (gs:orr s 'name') (gs:orr s 'status') (gs:orr s 'needs') (gs:orr s 'waiting_on') (gs:orr s 'starts')])))
    ::  the open actions, small; the done one left out
    (expect-eq !>(1) !>((lent (ga:orr v 'actions'))))
    (expect-eq !>(['a1' 'task' 'Book the hotel' 'approved' '2026-12-11T00:00:00Z']) !>(=/(a (snag 0 (ga:orr v 'actions')) [(gs:orr a 'id') (gs:orr a 'kind') (gs:orr a 'title') (gs:orr a 'status') (gs:orr a 'due')])))
    (expect !>(!(has-key:orr (snag 0 (ga:orr v 'actions')) 'payload')))
    ::  the kinds with their attribute names, nothing else of the schema
    (expect-eq !>((jo '{"person": ["status", "likes"], "situation": ["status", "needs"]}')) !>((gj:orr v 'kinds')))
    (expect !>(!(has-key:orr v 'schema')))
    ::  one kind
    (expect-eq !>(1) !>((lent (ga:orr (brief-json:orr all acts multi now 'person' (numb:enjs:format 7) schema) 'bodies'))))
  ==
::  ==  time to leave (version 69)
::
++  test-schema-renote
  ::  a stored schema that still holds a retired note word for word gets the
  ::  starter's; one the owner rewrote keeps theirs
  =/  at74=json  (set-key:orr starter-schema:orr 'schema_version' (numb:enjs:format 74))
  =/  with
    |=  [d=json t=@t]
    ^-  json
    =/  ks=json  (gj:orr d 'kinds')
    =/  sit=json  (gj:orr ks 'situation')
    (set-key:orr d 'kinds' (set-key:orr ks 'situation' (set-key:orr sit 'notes' (set-key:orr (gj:orr sit 'notes') 'drop-off' s+t))))
  =/  note  |=(d=json (gs:orr (gj:orr (gj:orr (gj:orr d 'kinds') 'situation') 'notes') 'drop-off'))
  =/  [* * old=@t]  (snag 0 schema-renotes:orr)
  ;:  weld
    (expect-eq !>((note starter-schema:orr)) !>((note (schema-upgrade:orr (with at74 old)))))
    (expect-eq !>('my own words') !>((note (schema-upgrade:orr (with at74 'my own words')))))
    (expect !>(!=(old (note starter-schema:orr))))
  ==
++  test-leave-looks
  =/  t=@da  ~2026.10.6..12.00.00
  =/  leave=@da  ~2026.10.6..16.30.00
  =/  alert=@da  ~2026.10.6..16.20.00
  ;:  weld
    ::  far off: the window opens two hours before leaving
    (expect-eq !>(~2026.10.6..14.30.00) !>((next-look:orr t leave alert 1.500)))
    ::  a long drive opens it at twice the drive: 1 h 30 each way, three hours
    (expect-eq !>(~2026.10.6..13.30.00) !>((next-look:orr t leave alert 5.400)))
    ::  inside it, every ten minutes
    (expect-eq !>(~2026.10.6..15.10.00) !>((next-look:orr ~2026.10.6..15.00.00 leave alert 1.500)))
    ::  but never past a point: 16:05 is fifteen before the alert
    (expect-eq !>(~2026.10.6..16.05.00) !>((next-look:orr ~2026.10.6..16.00.00 leave alert 1.500)))
    (expect-eq !>(alert) !>((next-look:orr ~2026.10.6..16.16.00 leave alert 1.500)))
    ::  after the alert: one look three minutes before the leave-by, then the start
    (expect-eq !>(`(unit @da)``~2026.10.6..16.27.00) !>((after-alert:orr ~2026.10.6..16.20.00 ~2026.10.6..17.00.00 `leave |)))
    (expect-eq !>(`(unit @da)`~) !>((after-alert:orr ~2026.10.6..16.27.10 ~2026.10.6..17.00.00 `leave |)))
    (expect-eq !>(`(unit @da)``~2026.10.6..17.01.00) !>((after-alert:orr ~2026.10.6..16.27.10 ~2026.10.6..17.00.00 `leave &)))
    (expect-eq !>(`(unit @da)``~2026.10.6..17.01.00) !>((after-alert:orr ~2026.10.6..16.31.00 ~2026.10.6..17.00.00 `leave |)))
    (expect-eq !>(`(unit @da)``~2026.10.6..17.01.00) !>((after-alert:orr ~2026.10.6..16.20.00 ~2026.10.6..17.00.00 ~ |)))
  ==
++  test-place-search
  =/  res=json
    %-  jo
    '{"type": "locations", "results": [{"title": "Lakeside Diner", "url": "https://search.brave.com/x"}, {"title": "The Gate Ballet School", "url": "https://gateballet.example", "coordinates": [39.79, -89.65], "postal_address": {"displayAddress": "100 Main St, Riverton, IL 62701"}, "contact": {"telephone": "+12175550100"}, "opening_hours": {"days": [[{"abbr_name": "Mon", "opens": "09:00", "closes": "17:00"}], [{"abbr_name": "Tue", "opens": "09:00", "closes": "12:00"}, {"abbr_name": "Tue", "opens": "13:00", "closes": "17:00"}]]}}]}'
  =/  f  (found-of:orr res 'Gate Ballet')
  =/  mk
    |=  [id=@t name=@t attrs=(list [a=@t v=json])]
    ^-  loaded:orr
    :+  id  [%place name ~ now ~]
    (turn attrs |=([a=@t v=json] ^-(row:orr [(rap 3 id '/' a ~) [id a v now ~ 90 ['t' 'x'] 'owner' now | '']])))
  =/  studio  (mk 'place/gate-ballet' 'Gate Ballet' ~[['phone' s+'+12175550199']])
  =/  w  (fold:orr rows.studio (sy ~['participants']) now)
  =/  rows  ?~(f ~ (place-facts:orr 'place/gate-ballet' w u.f now))
  ;:  weld
    ::  the first result whose title holds the name's words, never a search page as a website
    (expect-eq !>(`(unit [@t @t @t @t @t @t @t])``['The Gate Ballet School' '100 Main St, Riverton, IL 62701' '+12175550100' 'Mon 09:00-17:00, Tue 09:00-12:00, Tue 13:00-17:00' 'https://gateballet.example' '39.79' '-89.65']) !>(f))
    (expect-eq !>(~) !>((found-of:orr res 'Nowhere Cafe')))
    ::  only what the place lacks: its own phone stands; hours held ninety days
    (expect-eq !>(`(list @t)`~['address' 'hours' 'website' 'geo']) !>((turn rows |=(r=json (gs:orr r 'attr')))))
    (expect-eq !>(['search' 'search' 60]) !>(=/(r (snag 0 rows) [(gs:orr r 'by') (gs:orr (gj:orr r 'source') 'kind') (fall (gn:orr r 'conf') 0)])))
    ::  thin places: never home, never a POTA park, never one looked up this month
    =/  full  (mk 'place/full' 'Full' ~[['address' s+'a'] ['phone' s+'p'] ['hours' s+'h'] ['website' s+'w']])
    =/  park  (mk 'place/pota-us-0001' 'Park' ~)
    =/  home  (mk 'place/home' 'Home' ~)
    (expect-eq !>(`(list @t)`~['place/gate-ballet']) !>((turn (thin-places:orr ~[studio full park home] (sy ~['participants']) now ~) |=([i=@t *] i))))
    (expect-eq !>(`(list @t)`~) !>((turn (thin-places:orr ~[studio] (sy ~['participants']) now (my ~[['place/gate-ballet' (sub now ~d3)]])) |=([i=@t *] i))))
    ::  off by default, the key never answered
    (expect-eq !>([| 'https://api.search.brave.com' 500]) !>(=/(c (de-search:orr ~) [enabled.c api.c cap.c])))
    (expect-eq !>(|) !>(?=(^ (gj:orr (en-search-masked:orr (de-search:orr (jo '{"api_key": "k"}'))) 'api_key'))))
  ==
++  test-legs-by-day
  =/  mkr
    |=  [a=@t v=json at=@da]
    ^-  row:orr
    [(rap 3 'activity/ballet/' a (en:json:html v) ~) ['activity/ballet' a v at ~ 90 ['t' 'x'] 'owner' at | '']]
  =/  ref  |=(b=@t `json`(pairs:enjs:format ~[['ref' s+b]]))
  =/  on  |=([b=@t d=@t] `json`(pairs:enjs:format ~[['ref' s+b] ['days' a+~[s+d]]]))
  ::  a Wednesday and a Friday at 4:45 PM in New York, a week out
  =/  wed=@da  ~2026.10.14..20.45.00
  =/  fri=@da  ~2026.10.16..20.45.00
  =/  drops=(list row:orr)
    :~  (mkr 'drop-off' (ref 'person/lena') ~2026.9.1)
        (mkr 'drop-off' (on 'person/andrea' 'Wednesday') ~2026.10.7)
        (mkr 'drop-off' (on 'person/me' 'fri') ~2026.10.7)
    ==
  =/  body
    |=  next=@da
    ^-  loaded:orr
    :+  'activity/ballet'  ['activity' 'Ballet' ~ ~2026.9.1 ~]
    %+  weld  drops
    :~  (mkr 'pick-up' (ref 'person/me') ~2026.10.7)
        ['activity/ballet/next' ['activity/ballet' 'next' s+(en-iso:orr next) ~2026.10.7 `(add next ~h1) 100 ['calendar' 'u-ballet'] 'calendar' ~2026.10.7 | '']]
        (mkr 'location' s+'1 Studio Rd' ~2026.10.7)
    ==
  =/  me=loaded:orr  ['person/me' ['person' 'me' ~ ~2026.9.1 ~] ~[['person/me/tz' ['person/me' 'timezone' s+'America/New_York' ~2026.9.1 ~ 100 ['t' 'x'] 'owner' ~2026.9.1 | '']]]]
  =/  multi=(set @t)  (sy ~['participants' 'drop-off' 'pick-up'])
  =/  legs
    |=  b=loaded:orr
    (turn (appointments-ahead:orr ~[me b] multi ~2026.10.8 ~d30) |=(a=appointment:orr leg.a))
  ;:  weld
    (expect-eq !>(`(list @ud)`~[3]) !>((leg-days:orr (on 'person/andrea' 'Wednesday'))))
    (expect-eq !>(`(list @ud)`~) !>((leg-days:orr (ref 'person/lena'))))
    ::  the day's own row, else the newest with no day
    (expect-eq !>('person/andrea') !>((leg-for:orr drops 3)))
    (expect-eq !>('person/me') !>((leg-for:orr drops 5)))
    (expect-eq !>('person/lena') !>((leg-for:orr drops 1)))
    (expect-eq !>(3) !>((day-in:orr wed 'America/New_York')))
    ::  Wednesdays the owner only picks up; Fridays both legs
    (expect-eq !>(`(list leg:orr)`~[%pick]) !>((legs (body wed))))
    (expect-eq !>(`(list leg:orr)`~[%drop %pick]) !>((legs (body fri))))
  ==
++  test-spheres
  =/  row
    |=  [sub=@t v=json by=@t]
    ^-  (each obs:orr @t)
    [%& [sub 'sphere' v now ~ 90 ['t' 'x'] by now | '']]
  =/  ref  |=(b=@t `json`(pairs:enjs:format ~[['ref' s+b]]))
  =/  other=(each obs:orr @t)  [%& ['situation/a' 'starts' s+'2026-10-09' now ~ 90 ['t' 'x'] 'mail' now | '']]
  =/  rows=(list (each obs:orr @t))
    :~  (row 'situation/a' (ref 'sphere/home') 'owner')
        (row 'situation/b' s+'The LLC' 'mail')
        (row 'situation/c' (ref 'sphere/road') 'generator')
        other
        (row 'situation/d' s+'' 'mail')
    ==
  =/  got  (sphere-hold:orr rows (my ~[['sphere/road' 3]]))
  ;:  weld
    ::  a ref, a name made one, nothing for nothing
    (expect-eq !>(`(unit @t)``'sphere/home') !>((sphere-of:orr (ref 'sphere/home'))))
    (expect-eq !>(`(unit @t)``'sphere/the-llc') !>((sphere-of:orr s+'The LLC')))
    (expect-eq !>(`(unit @t)`~) !>((sphere-of:orr s+'')))
    (expect-eq !>(`(unit @t)`~) !>((sphere-of:orr (ref 'person/me'))))
    ::  the owner's row kept and counted; a model's held while the sphere is new, kept once it is trusted; the rest as it came
    (expect-eq !>(`(list @t)`~['sphere/home']) !>(confirmed.got))
    (expect-eq !>(`(list [@t json])`~[['situation/b' (ref 'sphere/the-llc')]]) !>((turn held.got |=(o=obs:orr [subject.o value.o]))))
    (expect-eq !>(4) !>((lent kept.got)))
    (expect-eq !>(`(list @t)`~['situation/a' 'situation/c' 'situation/a']) !>((murn kept.got |=(e=(each obs:orr @t) ?:(?=(%& -.e) `subject.p.e ~)))))
    (expect-eq !>(`(list @t)`~['not a sphere: ']) !>((murn kept.got |=(e=(each obs:orr @t) ?:(?=(%| -.e) `p.e ~)))))
    ::  the proposal a held row becomes
    =/  ask=json  (sphere-ask:orr (snag 0 held.got))
    (expect-eq !>(['fact' 'File b under the-llc' 'mail']) !>([(gs:orr ask 'kind') (gs:orr ask 'title') (gs:orr ask 'by')]))
    (expect-eq !>(`(map @t @ud)`(my ~[['sphere/home' 2]])) !>((de-trust:orr (en-trust:orr (my ~[['sphere/home' 2]])))))
    ::  an old schema gains the sphere kind whole, and the sphere attribute
    =/  old=json  (set-key:orr (del-key:orr starter-schema:orr 'schema_version') 'kinds' (del-key:orr (gj:orr starter-schema:orr 'kinds') 'sphere'))
    =/  new=json  (schema-upgrade:orr (set-key:orr old 'schema_version' (numb:enjs:format 83)))
    (expect-eq !>((gj:orr (gj:orr starter-schema:orr 'kinds') 'sphere')) !>((gj:orr (gj:orr new 'kinds') 'sphere')))
  ==
++  test-away
  =/  mk
    |=  [id=@t kind=@tas name=@t attrs=(list [a=@t v=json by=@t])]
    ^-  loaded:orr
    :+  id  [kind name ~ now ~]
    %+  turn  attrs
    |=  [a=@t v=json by=@t]
    ^-  row:orr
    [(rap 3 id '/' a '/' by (en:json:html v) ~) [id a v now ~ 90 ['t' 'x'] by now | '']]
  =/  ref  |=(b=@t `json`(pairs:enjs:format ~[['ref' s+b]]))
  =/  iso  |=(d=@dr `json`s+(en-iso:orr (add now d)))
  =/  multi=(set @t)  (sy ~['participants'])
  =/  home  (mk 'place/home' %place 'Home' ~[['address' s+'1 Home Rd' 'owner']])
  =/  cache=json  (pairs:enjs:format ~[['1 home rd' s+'39.78,-89.65'] ['dock 9, lakeside' s+'40.25,-89.65'] ['school, home town' s+'39.79,-89.65']])
  ::  said to be away, with no place: the trip from the calendar
  =/  trip  (mk 'situation/trip' %situation 'Team offsite' ~[['starts' (iso ~d1) 'calendar'] ['ends' (iso ~d6) 'calendar'] ['participants' (ref 'person/me') 'calendar'] ['away' s+'yes' 'generator']])
  ::  a two-day sail 52 km off, the owner on it: away by itself
  =/  sail  (mk 'situation/sail' %situation 'Sail weekend' ~[['starts' (iso ~d10) 'owner'] ['ends' (iso ~d12) 'owner'] ['participants' (ref 'person/me') 'owner'] ['location' s+'Dock 9, Lakeside' 'owner']])
  ::  the same sail, said not to be away: not
  =/  nope  (mk 'situation/nope' %situation 'Day sail' ~[['starts' (iso ~d20) 'owner'] ['ends' (iso ~d21) 'owner'] ['participants' (ref 'person/me') 'owner'] ['location' s+'Dock 9, Lakeside' 'owner'] ['away' s+'no' 'owner']])
  ::  long, near home: not
  =/  near  (mk 'situation/near' %situation 'School fair' ~[['starts' (iso ~d2) 'owner'] ['ends' (iso ~d3) 'owner'] ['participants' (ref 'person/me') 'owner'] ['location' s+'School, home town' 'owner']])
  =/  all=(list loaded:orr)  ~[home trip sail nope near]
  =/  hp  (home-point:orr all multi now cache)
  =/  spans  (away-spans:orr all multi now hp cache)
  =/  game=appointment:orr  ['situation/game' 'Game' (add now ~d2) ~ 'School, home town' ~ %yes %go]
  =/  there=appointment:orr  ['situation/dinner' 'Dinner' (add now ~d2) ~ 'Dock 9, Lakeside' ~ %yes %go]
  =/  later=appointment:orr  ['situation/game' 'Game' (add now ~d8) ~ 'School, home town' ~ %yes %go]
  =/  itself=appointment:orr  ['situation/sail' 'Sail weekend' (add now ~d10) ~ 'Dock 9, Lakeside' ~ %yes %go]
  ;:  weld
    (expect-eq !>(`(unit [@t @t])``['39.78' '-89.65']) !>(hp))
    (expect-eq !>(`(list [@t @t])`~[['situation/trip' 'said to be away'] ['situation/sail' '52 km from home']]) !>((turn spans |=(s=away-span:orr [id.s why.s]))))
    (expect-eq !>(`(unit @t)``'situation/trip') !>(=/(s (away-at:orr spans (add now ~d3)) ?~(s ~ `id.u.s))))
    (expect-eq !>(`(unit @t)`~) !>(=/(s (away-at:orr spans (add now ~d8)) ?~(s ~ `id.u.s))))
    ::  away: a home game is passed over, a dinner where the owner is is not
    (expect !>((away-skips:orr game spans ~ hp all multi now cache)))
    (expect !>(!(away-skips:orr there spans ~ hp all multi now cache)))
    (expect !>(!(away-skips:orr later spans ~ hp all multi now cache)))
    ::  the trip's own start still has its alert
    (expect !>(!(away-skips:orr itself spans ~ hp all multi now cache)))
    ::  the phone far from home: home's games are passed over whenever they are
    (expect !>((away-skips:orr later spans `7.500 hp all multi now cache)))
    (expect-eq !>(`(unit @ud)`~) !>((far-from-home:orr (pairs:enjs:format ~[['lat' n+'39.80'] ['lon' n+'-89.60']]) hp)))
    ::  ponytail: flat over long distances, so far is only far, past 150 km
    (expect !>(=/(k (far-from-home:orr (pairs:enjs:format ~[['lat' s+'41.38'] ['lon' s+'2.17']]) hp) &(?=(^ k) (gth u.k 7.000)))))
    (expect-eq !>(`(unit @ud)`~) !>((far-from-home:orr (pairs:enjs:format ~[['lat' s+'41.38'] ['lon' s+'2.17']]) ~)))
  ==
++  test-family-busy
  =/  r=rhythm:orr  (de-rhythm:orr (jo '{"family_from": "17:30", "family_to": "20:30"}'))
  =/  late=rhythm:orr  (de-rhythm:orr (jo '{"family_from": "22:00", "family_to": "01:00"}'))
  ;:  weld
    (expect-eq !>(`(list [@da @da])`~[[~2026.10.6..17.30.00 ~2026.10.6..20.30.00]]) !>((family-busy:orr '2026-10-06' 'UTC' r)))
    (expect-eq !>(`(list [@da @da])`~[[~2026.10.6..22.00.00 ~2026.10.7]]) !>((family-busy:orr '2026-10-06' 'UTC' late)))
    (expect-eq !>(`(list [@da @da])`~) !>((family-busy:orr '2026-10-06' 'UTC' (de-rhythm:orr ~))))
  ==
++  test-outdoors
  =/  fc=json  (jo '{"properties": {"periods": [{"startTime": "2026-09-18T06:00:00-05:00", "endTime": "2026-09-18T18:00:00-05:00", "isDaytime": true, "temperature": 78, "windSpeed": "10 to 15 mph", "probabilityOfPrecipitation": {"value": 20}, "shortForecast": "Mostly Sunny"}, {"startTime": "2026-09-18T18:00:00-05:00", "endTime": "2026-09-19T06:00:00-05:00", "isDaytime": false, "temperature": 60, "windSpeed": "5 mph", "probabilityOfPrecipitation": {"value": null}, "shortForecast": "Clear"}, {"startTime": "2026-09-19T06:00:00-05:00", "endTime": "2026-09-19T18:00:00-05:00", "isDaytime": true, "temperature": 84, "windSpeed": "20 to 25 mph", "probabilityOfPrecipitation": {"value": 60}, "shortForecast": "Chance Showers And Thunderstorms"}]}}')
  =/  ps  (nws-periods:orr fc)
  =/  mk
    |=  [id=@t kind=@tas name=@t attrs=(list [a=@t v=json by=@t])]
    ^-  loaded:orr
    :+  id  [kind name ~ now ~]
    %+  turn  attrs
    |=  [a=@t v=json by=@t]
    ^-  row:orr
    [(rap 3 id '/' a '/' by (en:json:html v) ~) [id a v now ~ 90 ['t' 'x'] by now | '']]
  =/  boat  (mk 'activity/sailing' %activity 'Sailing' ~[['wind-mph' s+'8-18' 'owner'] ['rain-max' n+'30' 'owner'] ['temp-f' s+'60 to 90' 'owner']])
  =/  chess  (mk 'activity/chess' %activity 'Chess Club' ~[['schedule' s+'Thursdays' 'owner']])
  =/  park  (mk 'place/pota-us-0001' %place 'Lakeside Park' ~[['pota' s+'US-0001' 'ship'] ['geo' s+'39.7817,-89.6501' 'ship'] ['activated' s+'2026-09-10' 'owner']])
  =/  parks  (pota-parks:orr (jo '[{"reference": "US-0001", "name": "Lakeside Park", "latitude": 39.7817, "longitude": -89.6501}, {"reference": "US-0002", "name": "Far Woods", "latitude": 40.5, "longitude": -89.0}, {"reference": "", "name": "No ref", "latitude": 39.8, "longitude": -89.6}]'))
  =/  rule=weather-rule:orr  rule:(snag 0 (outings:orr ~[boat chess] (sy ~['participants']) now))
  =/  m=@ud  (need (metres-between:orr ['39.78' '-89.70'] ['39.78' '-89.60']))
  ;:  weld
    ::  the forecast as the weather service answers it, wind as a range
    (expect-eq !>(3) !>((lent ps)))
    (expect-eq !>([& 78 10 15 20 'Mostly Sunny']) !>(=/(p (snag 0 ps) [day.p temp.p wind-lo.p wind-hi.p rain.p short.p])))
    (expect-eq !>([| 5 5 0]) !>(=/(p (snag 1 ps) [day.p wind-lo.p wind-hi.p rain.p])))
    (expect-eq !>(~2026.9.18..11.00.00) !>(start:(snag 0 ps)))
    (expect-eq !>(ps) !>((de-periods:orr (turn ps en-period:orr))))
    (expect-eq !>([0 0]) !>((wind-range:orr '')))
    (expect-eq !>(`(list @ud)`~[10 15]) !>((numbers:orr 'from 10 to 15 mph')))
    ::  leaving in a storm adds ten minutes, likely rain five, a dry hour none
    (expect-eq !>([~m10 'storms']) !>((weather-extra:orr ps ~2026.9.19..15.00.00)))
    (expect-eq !>([`@dr`0 '']) !>((weather-extra:orr ps ~2026.9.18..15.00.00)))
    (expect-eq !>([~m5 'rain']) !>((weather-extra:orr ~[[now (add now ~h1) & 70 5 5 60 'Showers']] (add now ~m30))))
    ::  an outing's rule, and the days that suit it: daytime only, every bound held
    (expect-eq !>(`(list [@t @t])`~[['activity/sailing' 'Sailing']]) !>((turn (outings:orr ~[boat chess] (sy ~['participants']) now) |=([id=@t n=@t *] [id n]))))
    (expect-eq !>(`weather-rule:orr`[`[8 18] `30 `[60 90]]) !>(rule))
    (expect-eq !>(`(list @da)`~[~2026.9.18..11.00.00]) !>((turn (skim ps |=(p=period:orr (suits:orr rule p))) |=(p=period:orr start.p))))
    (expect-eq !>('78F, Mostly Sunny, wind 10 to 15 mph, rain 20%') !>((period-line:orr (snag 0 ps))))
    ::  alerts in force
    (expect-eq !>(`(list [@t (unit @da) @t])`~[['Heat Advisory' `~2026.9.18..23.00.00 'Heat Advisory until 7 PM']]) !>((nws-alerts:orr (jo '{"features": [{"properties": {"event": "Heat Advisory", "ends": "2026-09-18T19:00:00-04:00", "headline": "Heat Advisory until 7 PM"}}]}'))))
    ::  distance without trigonometry: a tenth of a degree of longitude near 40N is about 8.55 km
    (expect !>(&((gth m 8.530) (lth m 8.580))))
    (expect-eq !>(`(unit @ud)`[~ 11.132]) !>((metres-between:orr ['39.70' '-89.65'] ['39.80' '-89.65'])))
    (expect-eq !>(1.000.000) !>((cos-of:orr 0)))
    ::  POTA: the parks with a reference, the near ones, the nearest first
    (expect-eq !>(2) !>((lent parks)))
    (expect-eq !>(`(list @t)`~['US-0001']) !>((turn (parks-within:orr parks ['39.79' '-89.65'] 40.000) |=([p=pota-park:orr *] ref.p))))
    (expect-eq !>('place/pota-us-0001') !>((park-id:orr 'US-0001')))
    (expect-eq !>(`(list [@t @t (unit @da)])`~[['place/pota-us-0001' 'US-0001' `~2026.9.10]]) !>((turn (pota-places:orr ~[park boat] (sy ~['participants']) now) |=([id=@t n=@t ref=@t * a=(unit @da)] [id ref a]))))
    ::  the brief: the day's weather, alerts, an outing's good days (light calendar), parks near a wait
    =/  wx=json  (pairs:enjs:format ~[['periods' a+(turn ps en-period:orr)] ['alerts' a+~[(en-alert:orr 'Heat Advisory' ~ 'Heat Advisory until 7 PM')]]])
    =/  out  (outdoor-lines:orr wx ~ ~[boat chess park] (sy ~['participants']) ~2026.9.18..12.00.00 ~2026.9.19..05.00.00 'America/Chicago')
    (expect-eq !>(`(list @t)`~['Weather: 78F, Mostly Sunny, wind 10 to 15 mph, rain 20%' 'Alert: Heat Advisory until 7 PM' 'Sailing weather: Fri']) !>(out))
    =/  ref  |=(b=@t `json`(pairs:enjs:format ~[['ref' s+b]]))
    =/  studio  (mk 'place/studio' %place 'The Studio' ~[['geo' s+'39.80,-89.65' 'owner']])
    =/  ballet  (mk 'situation/ballet' %situation 'Ballet' ~[['starts' s+(en-iso:orr (add now ~h1)) 'calendar'] ['ends' s+(en-iso:orr (add now ~h2)) 'calendar'] ['location' (ref 'place/studio') 'calendar'] ['drop-off' (ref 'person/me') 'owner'] ['pick-up' (ref 'person/me') 'owner']])
    =/  quick  (mk 'situation/quick' %situation 'Quick' ~[['starts' s+(en-iso:orr (add now ~h1)) 'calendar'] ['location' (ref 'place/studio') 'calendar'] ['drop-off' (ref 'person/me') 'owner']])
    (expect-eq !>(`(list @t)`~['Parks near Ballet: Lakeside Park US-0001 (2 km, done 2026-09-10)']) !>((outdoor-lines:orr [%o ~] ~ ~[studio ballet quick park] (sy ~['participants']) now (add now ~h12) 'UTC')))
    ::  a wait written as text finds its point in the geocache (version 77)
    =/  ref  |=(b=@t `json`(pairs:enjs:format ~[['ref' s+b]]))
    =/  hall  (mk 'situation/hall' %situation 'Hall' ~[['starts' s+(en-iso:orr (add now ~h1)) 'calendar'] ['ends' s+(en-iso:orr (add now ~h2)) 'calendar'] ['location' s+'1 Gate  Hall,  Riverton' 'calendar'] ['drop-off' (ref 'person/me') 'owner'] ['pick-up' (ref 'person/me') 'owner']])
    =/  cache=json  (pairs:enjs:format ~[['1 gate hall, riverton' s+'39.80,-89.65']])
    (expect-eq !>(`(list @t)`~['Parks near Hall: Lakeside Park US-0001 (2 km, done 2026-09-10)']) !>((outdoor-lines:orr [%o ~] cache ~[hall park] (sy ~['participants']) now (add now ~h12) 'UTC')))
    =/  ref  |=(b=@t `json`(pairs:enjs:format ~[['ref' s+b]]))
    =/  hall  (mk 'situation/hall' %situation 'Hall' ~[['starts' s+(en-iso:orr (add now ~h1)) 'calendar'] ['ends' s+(en-iso:orr (add now ~h2)) 'calendar'] ['location' s+'1 Gate  Hall,  Riverton' 'calendar'] ['drop-off' (ref 'person/me') 'owner'] ['pick-up' (ref 'person/me') 'owner']])
    (expect-eq !>(`(list @t)`~) !>((outdoor-lines:orr [%o ~] ~ ~[hall park] (sy ~['participants']) now (add now ~h12) 'UTC')))
    ::  the addresses with no point: a place with an address and no geo, each text location once; a park and a ref are not
    =/  ref  |=(b=@t `json`(pairs:enjs:format ~[['ref' s+b]]))
    =/  shop  (mk 'place/shop' %place 'Shop' ~[['address' s+'9 Gate St' 'owner']])
    =/  hall  (mk 'situation/hall' %situation 'Hall' ~[['location' s+'1 Gate  Hall,  Riverton' 'calendar']])
    =/  again  (mk 'situation/again' %situation 'Again' ~[['location' s+'1 gate hall,   Riverton' 'calendar']])
    =/  to-place  (mk 'situation/to-place' %situation 'To place' ~[['location' (ref 'place/shop') 'calendar']])
    (expect-eq !>([`(list [@t @t])`~[['place/shop' '9 Gate St']] `(list @t)`~['1 Gate  Hall,  Riverton']]) !>((known-addresses:orr ~[shop park hall again to-place] (sy ~['participants']) now)))
    ::  settings: weather on and parks off by default, nobody's location
    (expect-eq !>([%'rhythm.json' %'outdoors.json']) !>([(settings-file:orr 'set-rhythm') (settings-file:orr 'set-outdoors')]))
    (expect-eq !>([& 'https://api.weather.gov' | 'https://api.pota.app' '' 40]) !>((de-outdoors:orr ~)))
    (expect-eq !>((de-outdoors:orr (jo '{"pota": true, "pota_location": "US-IL", "pota_radius_km": 30}'))) !>((de-outdoors:orr (en-outdoors:orr (de-outdoors:orr (jo '{"pota": true, "pota_location": "US-IL", "pota_radius_km": 30}'))))))
  ==
++  test-nudges
  ::  now is 2026-09-18 (a Friday) in the tests' clock; UTC as the owner's zone
  =/  blk  |=([a=@da b=@da] [a b ''])
  =/  mk
    |=  [id=@t kind=@tas name=@t attrs=(list [a=@t v=json by=@t])]
    ^-  loaded:orr
    :+  id  [kind name ~ now ~]
    %+  turn  attrs
    |=  [a=@t v=json by=@t]
    ^-  row:orr
    [(rap 3 id '/' a '/' by (en:json:html v) ~) [id a v now ~ 90 ['t' 'x'] by now | '']]
  =/  read  (mk 'activity/reading' %activity 'Reading' ~[['per-week' n+'3' 'owner'] ['minutes' s+'30' 'owner'] ['last' s+'2026-09-15' 'owner'] ['last' s+'2026-09-17T20:00:00Z' 'mail'] ['last' s+'2026-09-13' 'owner']])
  =/  guitar  (mk 'activity/guitar' %activity 'Guitar' ~[['per-week' s+'2' 'owner']])
  =/  chess  (mk 'activity/chess' %activity 'Chess' ~[['cadence' s+'weekly' 'calendar']])
  =/  hs  (habits:orr ~[read guitar chess] (sy ~['participants']) now 'UTC')
  =/  d17  |=(n=@ud (end [3 10] (en-iso:orr (sub now (mul n ~d1)))))
  =/  wd  |=([d=@t e=@da] (pairs:enjs:format ~[['day' s+d] ['blocks' a+~[(pairs:enjs:format ~[['start' s+(en-iso:orr (sub e ~h2))] ['end' s+(en-iso:orr e)]])]]]))
  =/  hd  |=([n=@ud steps=@ud] (pairs:enjs:format ~[['steps' (numb:enjs:format steps)] ['sleep' a+~[(pairs:enjs:format ~[['start' s+(en-iso:orr (sub (sub now (mul n ~d1)) ~h8))] ['end' s+(en-iso:orr (sub (sub now (mul n ~d1)) ~h1))]])]] ['partial' b+|]]))
  =/  store=json  [%o (~(gas by *(map @t json)) (turn (gulf 1 15) |=(n=@ud [(d17 n) (hd n (mul n 1.000))])))]
  =/  thin=json  [%o (~(gas by *(map @t json)) (turn (gulf 1 13) |=(n=@ud [(d17 n) (hd n 4.000)])))]
  =/  plain=rhythm:orr  (de-rhythm:orr ~)
  =/  own=rhythm:orr  (de-rhythm:orr (jo '{"quiet_from": "23:00", "quiet_to": "07:00", "family_from": "17:00", "family_to": "19:30", "evening_from": "19:30", "evening_to": "23:00", "weekend_from": "08:00", "weekend_to": "11:00", "per_window": 1, "young_age": 6, "young_share": 50}'))
  ;:  weld
    ::  the clock: quiet from nine at night to seven in the morning
    ::  the defaults, for anyone: quiet nine at night to seven, evenings six to nine, weekend mornings
    (expect !>((quiet-hour:orr ~2026.9.18..21.00.00 'UTC' plain)))
    (expect !>((quiet-hour:orr ~2026.9.18..06.59.00 'UTC' plain)))
    (expect !>(!(quiet-hour:orr ~2026.9.18..20.59.00 'UTC' plain)))
    ::  an owner's own: quiet from eleven, family time, evenings past it, one habit a window
    (expect !>(!(quiet-hour:orr ~2026.9.18..22.30.00 'UTC' own)))
    (expect !>((quiet-hour:orr ~2026.9.18..23.30.00 'UTC' own)))
    (expect-eq !>(`(unit [@ud @ud])`[~ 1.020 1.170]) !>(family.own))
    (expect-eq !>(`(unit [@ud @ud])`[~ 6 50]) !>(young.own))
    (expect-eq !>(`(unit [@ud @ud])`~) !>(young.plain))
    (expect-eq !>('23:00') !>((gs:orr (en-rhythm:orr own) 'quiet_from')))
    (expect-eq !>(own) !>((de-rhythm:orr (en-rhythm:orr own))))
    (expect !>((in-span:orr 30 1.380 420)))
    (expect !>(!(in-span:orr 600 1.380 420)))
    ::  a stretch: the latest block, ninety minutes or more, ending within seven of now
    (expect-eq !>(`(unit [@da @ud])`[~ (sub now ~m100) 95]) !>((desk-stretch:orr ~[(blk (sub now ~h5) (sub now ~h4)) (blk (sub now ~m100) (sub now ~m5))] now)))
    (expect-eq !>(`(unit [@da @ud])`~) !>((desk-stretch:orr ~[(blk (sub now ~m100) (sub now ~m10))] now)))
    (expect-eq !>(`(unit [@da @ud])`~) !>((desk-stretch:orr ~[(blk (sub now ~m80) now)] now)))
    ::  late nights: work that ran past eleven, until five
    (expect-eq !>(2) !>((late-nights:orr ~[(wd '2026-09-15' ~2026.9.16..00.30.00) (wd '2026-09-16' ~2026.9.16..22.30.00) (wd '2026-09-17' ~2026.9.17..23.10.00) ~] 'UTC')))
    ::  the week begins on Monday
    (expect-eq !>('2026-09-14') !>((monday-of:orr '2026-09-18')))
    (expect-eq !>('2026-09-14') !>((monday-of:orr '2026-09-14')))
    (expect-eq !>('2026-09-14') !>((monday-of:orr '2026-09-20')))
    ::  habits: those with a weekly count; this week's distinct days done; thirty minutes unless said
    (expect-eq !>(`(list habit:orr)`~[['activity/reading' 'Reading' 3 30 2] ['activity/guitar' 'Guitar' 2 30 0]]) !>(hs))
    ::  a free slot: the first gap long enough, the busy spans in any order
    (expect-eq !>(`(unit [@da @da])`[~ (add now ~h2) (add now ~h3)]) !>((free-slot:orr ~[[(add now ~h3) (add now ~h4)] [now (add now ~h2)]] now (add now ~h6) ~h1)))
    (expect-eq !>(`(unit [@da @da])`~) !>((free-slot:orr ~[[now (add now ~h6)]] now (add now ~h6) ~h1)))
    ::  the window: five to nine on a weekday, eight to nine at the weekend
    (expect-eq !>(`(list [@da @da])`~[[~2026.9.18..18.00.00 ~2026.9.18..21.00.00]]) !>((habit-windows:orr '2026-09-18' 'UTC' plain)))
    (expect-eq !>(`(list [@da @da])`~[[~2026.9.19..09.00.00 ~2026.9.19..12.00.00] [~2026.9.19..18.00.00 ~2026.9.19..21.00.00]]) !>((habit-windows:orr '2026-09-19' 'UTC' plain)))
    (expect-eq !>(`(list [@da @da])`~[[~2026.9.18..19.30.00 ~2026.9.18..23.00.00]]) !>((habit-windows:orr '2026-09-18' 'UTC' own)))
    ::  the plan: the furthest behind first, each slot taken from the next one's time
    =/  plan  (plan-habits:orr hs ~[[~2026.9.18..17.00.00 ~2026.9.18..18.00.00]] ~2026.9.18..17.00.00 ~2026.9.18..21.00.00 2)
    (expect-eq !>(`(list [@t @da @da])`~[['activity/guitar' ~2026.9.18..18.00.00 ~2026.9.18..18.30.00] ['activity/reading' ~2026.9.18..18.40.00 ~2026.9.18..19.10.00]]) !>((turn plan |=([h=habit:orr s=@da e=@da] [id.h s e]))))
    ::  one a window holds only the furthest behind
    (expect-eq !>(1) !>((lent (plan-habits:orr hs ~ ~2026.9.18..17.00.00 ~2026.9.18..21.00.00 1))))
    (expect-eq !>('18:40  Reading, 30 min (2 of 3 this week)') !>((habit-line:orr ['activity/reading' 'Reading' 3 30 2] ~2026.9.18..18.40.00 'UTC')))
    ::  the baseline needs fourteen complete days; the targets a notch above it
    (expect-eq !>(`(unit [@ud @ud @ud])`~) !>((baseline:orr thin (d17 0) 'UTC')))
    (expect-eq !>(`(unit [@ud @ud @ud])`[~ 8.000 420 (bed-minutes:orr (sub now ~h8) 'UTC')]) !>((baseline:orr store (d17 0) 'UTC')))
    (expect-eq !>([4.700 435 '00:45']) !>((targets-of:orr [4.210 420 (bed-minutes:orr ~2026.9.18..01.00.00 'UTC')])))
    ::  busy: the owner's own appointments only, around start and end
    =/  mk2
      |=  [id=@t kind=@tas attrs=(list [a=@t v=json by=@t])]
      ^-  loaded:orr
      :+  id  [kind id ~ now ~]
      %+  turn  attrs
      |=  [a=@t v=json by=@t]
      ^-  row:orr
      [(rap 3 id '/' a '/' by (en:json:html v) ~) [id a v now ~ 90 ['t' 'x'] by now | '']]
    =/  ref  |=(b=@t `json`(pairs:enjs:format ~[['ref' s+b]]))
    =/  go  (mk2 'situation/go' %situation ~[['starts' s+(en-iso:orr (add now ~h2)) 'owner'] ['ends' s+(en-iso:orr (add now ~h3)) 'owner'] ['attending' s+'yes' 'owner']])
    =/  nope  (mk2 'situation/nope' %situation ~[['starts' s+(en-iso:orr (add now ~h2)) 'owner'] ['attending' s+'no' 'owner']])
    =/  pick  (mk2 'situation/pick' %situation ~[['starts' s+(en-iso:orr (add now ~h4)) 'owner'] ['ends' s+(en-iso:orr (add now ~h5)) 'owner'] ['pick-up' (ref 'person/me') 'owner'] ['drop-off' (ref 'person/lena') 'owner']])
    (expect-eq !>(`(list [@da @da])`~[[(add now ~m100) (add now ~m195)] [(add now ~m270) (add now ~m315)]]) !>((day-busy:orr ~[go nope pick] (sy ~['participants']) now now (add now ~h12))))
    ::  the day's nudges
    (expect-eq !>(1) !>((lent (sent-today:orr (jo '{"day": "2026-09-18", "sent": [{"kind": "desk"}]}') '2026-09-18'))))
    (expect-eq !>(0) !>((lent (sent-today:orr (jo '{"day": "2026-09-17", "sent": [{"kind": "desk"}]}') '2026-09-18'))))
  ==
++  test-review-replies
  =/  our=@p  ~zod
  =/  root=mail-msg:orr  ['t1' '0v1' our 'Your week, 2026-09-20' 'Your week, Sunday\0a...' now ~ &]
  =/  reply=mail-msg:orr  ['t1' '0v2' our 'Re: Your week, 2026-09-20' 'make reading 4 times a week' now `0v1 &]
  =/  other=mail-msg:orr  ['t2' '0v3' our 'Re: Daily brief 2026-09-20' 'approve A1' now `0v1 &]
  =/  msgs=(list mail-msg:orr)  ~[root reply other]
  ;:  weld
    (expect-eq !>(`(list @t)`~['0v2']) !>((turn (review-replies-of:orr msgs msgs our ~ 'Your week, Sunday\0a...') |=([r=mail-msg:orr *] id.r))))
    ::  read once; not a reply to an older review; not with no review sent
    (expect-eq !>(`(list @t)`~) !>((turn (review-replies-of:orr msgs msgs our (sy ~['mail:0v2']) 'Your week, Sunday\0a...') |=([r=mail-msg:orr *] id.r))))
    (expect-eq !>(`(list @t)`~) !>((turn (review-replies-of:orr msgs msgs our ~ 'another week') |=([r=mail-msg:orr *] id.r))))
    (expect-eq !>(`(list @t)`~) !>((turn (review-replies-of:orr msgs msgs our ~ '') |=([r=mail-msg:orr *] id.r))))
  ==
++  test-review
  =/  has  |=([t=@t n=tape] ^-(? ?=(^ (find n (trip t)))))
  ::  a Thursday till half past one, a Friday short; three nights' sleep; two kids
  =/  work=(list [@t @ud (unit @da)])
    :~  ['2026-09-17' 570 `~2026.9.18..01.30.00]
        ['2026-09-18' 45 `~2026.9.18..17.00.00]
        ['2026-09-19' 0 ~]
    ==
  =/  health=(list [@t (unit @ud) (unit @ud) @ud (unit [@da @da])])
    :~  ['2026-09-17' `3.000 `20 1 `[~2026.9.17..00.30.00 ~2026.9.17..06.30.00]]
        ['2026-09-18' `5.000 ~ 0 `[~2026.9.18..01.30.00 ~2026.9.18..07.00.00]]
        ['2026-09-19' ~ ~ 0 ~]
    ==
  =/  tally=(list kid-row:orr)  ~[['person/wren' 'Wren' 100 2 1 1 7] ['person/abe' 'Abe' 50 0 0 0 0]]
  =/  t=@t  (review-render:orr '2026-09-20' 'UTC' work health 9 tally `'Abe' ~['Tue  19:30 pick up: Swim Team'] ~[['Habits' ~['Reading: 2 of 3 this week']]])
  =/  none=@t  (review-render:orr '2026-09-20' 'UTC' ~ ~ 0 ~ ~ ~ ~)
  ;:  weld
    (expect !>((has t "Your week, Sunday 2026-09-20")))
    (expect !>((has t "Thu 9 h 30 until 01:30, Fri 45 min")))
    (expect !>((has t "In all 10 h 15, 1 late night.")))
    (expect !>((has t "Learning your baseline: 9 of 14 days so far.")))
    (expect !>((has t "Steps: 4000 a day.")))
    (expect !>((has t "Active: 20 min in all, 1 workout.")))
    (expect !>((has t "Sleep: 5 h 45 a night, to bed around 01:30.")))
    (expect !>((has t "Wren: 2 drives, 1 one-on-one, 1 shared")))
    (expect !>((has t "Abe: 0 drives, 0 one-on-ones (50% share)")))
    (expect !>((has t "Most behind: Abe.")))
    (expect !>((has t "The week ahead\0aTue  19:30 pick up: Swim Team")))
    (expect !>((has t "Habits\0aReading: 2 of 3 this week\0a\0aThe week ahead")))
    ::  nothing yet: says where it comes from, no kids, no week ahead
    (expect !>((has none "Nothing reported yet")))
    (expect !>((has none "Nothing from your phone yet")))
    (expect !>(!(has none "Time with the kids")))
  ==
++  test-the-week
  =/  mk
    |=  [id=@t kind=@tas name=@t attrs=(list [a=@t v=json by=@t])]
    ^-  loaded:orr
    :+  id  [kind name ~ now ~]
    %+  turn  attrs
    |=  [a=@t v=json by=@t]
    ^-  row:orr
    [(rap 3 id '/' a '/' by (en:json:html v) ~) [id a v now ~ 90 ['t' 'x'] by now | '']]
  =/  ref  |=(b=@t `json`(pairs:enjs:format ~[['ref' s+b]]))
  =/  multi=(set @t)  (sy ~['participants'])
  ::  now is 2026-09-18: a ten-year-old by age, a girl turning four next month, a baby
  =/  wren  (mk 'person/wren' %person 'Wren' ~[['relationship' s+'daughter' 'owner'] ['age' s+'10' 'owner']])
  =/  addie  (mk 'person/nora' %person 'Nora' ~[['relationship' s+'daughter' 'owner'] ['birthday' s+'2022-10-19' 'owner']])
  =/  baby  (mk 'person/abe' %person 'Abe' ~[['relationship' s+'son' 'owner'] ['birthday' s+'2025-11-03' 'owner']])
  =/  lena  (mk 'person/lena' %person 'Lena' ~[['relationship' s+'wife' 'owner']])
  =/  lunch  (mk 'situation/lunch' %situation 'Lunch with Wren' ~[['starts' s+(en-iso:orr (sub now ~d2)) 'owner'] ['participants' (ref 'person/me') 'owner'] ['participants' (ref 'person/wren') 'owner']])
  =/  party  (mk 'situation/party' %situation 'Party' ~[['starts' s+(en-iso:orr (sub now ~d1)) 'owner'] ['participants' (ref 'person/me') 'owner'] ['participants' (ref 'person/wren') 'owner'] ['participants' (ref 'person/lena') 'owner']])
  =/  old  (mk 'situation/old' %situation 'Lunch with Wren before' ~[['starts' s+(en-iso:orr (sub now ~d9)) 'owner'] ['participants' (ref 'person/me') 'owner'] ['participants' (ref 'person/wren') 'owner']])
  =/  all=(list loaded:orr)  ~[wren addie baby lena lunch party old]
  =/  kids  (children:orr all multi now `[5 50])
  =/  kidset=(set @t)  (silt (turn kids |=([id=@t *] id)))
  =/  times  (kid-times:orr all multi now (sub now ~d7) now kidset)
  =/  ones  ones.times
  =/  drives=(list [at=@da kids=(list @t)])  ~[[(sub now ~d3) ~['person/wren' 'person/nora']] [(sub now ~d8) ~['person/nora']]]
  =/  tally  (kid-tally:orr kids drives ones shared.times (sub now ~d7) now)
  =/  hd  (health-doc:orr (jo '{"day": "2026-09-17", "steps": 4210.0, "sleep": [{"start": "2026-09-17T04:55:00Z", "end": "2026-09-17T11:20:00Z"}, {"start": "2026-09-17T19:00:00Z", "end": "2026-09-17T18:00:00Z"}], "workouts": [{"type": "running", "start": "2026-09-17T22:00:00Z", "end": "2026-09-17T22:30:00Z"}, {"start": "2026-09-17T23:00:00Z", "end": "2026-09-17T23:20:00Z"}], "partial": true}'))
  =/  wd  (work-doc:orr (jo '{"day": "2026-09-17", "active_minutes": 999, "blocks": [{"start": "2026-09-17T13:00:00Z", "end": "2026-09-17T15:30:00Z"}, {"start": "2026-09-18T03:00:00Z", "end": "2026-09-18T05:20:00Z"}]}'))
  ;:  weld
    ::  the children, oldest first, half a share under five; Lena is not one
    (expect-eq !>(`(list [@t @t (unit @ud) @ud])`~[['person/wren' 'Wren' `10 100] ['person/nora' 'Nora' `3 50] ['person/abe' 'Abe' `0 50]]) !>(kids))
    ::  one-on-ones: the owner and one child, in the window; a party with Lena is not one
    (expect-eq !>(`(list [@da @t])`~[[(sub now ~d2) 'person/wren']]) !>(ones))
    ::  the tally: a drive counts for each child in it, a one-on-one three points, over the share
    (expect-eq !>(`(list kid-row:orr)`~[['person/wren' 'Wren' 100 1 1 1 6] ['person/nora' 'Nora' 50 1 0 0 2] ['person/abe' 'Abe' 50 0 0 0 0]]) !>(tally))
    ::  shared time: the owner with more than one other, each child in it, not from the calendar
    (expect-eq !>(`(list [@da (list @t)])`~[[(sub now ~d1) ~['person/wren']]]) !>(shared.times))
    (expect-eq !>(`(unit @t)`[~ 'Abe']) !>((kid-behind:orr tally)))
    (expect-eq !>(`(unit @t)`~) !>((kid-behind:orr (kid-tally:orr kids ~ ~ ~ (sub now ~d7) now))))
    ::  a health day kept: steps whole, no active minutes, a backward session dropped, workouts typed or other
    (expect !>(?=(%& -.hd)))
    (expect-eq !>((jo '{"active_minutes":null,"day":"2026-09-17","partial":true,"sleep":[{"end":"2026-09-17T11:20:00Z","start":"2026-09-17T04:55:00Z"}],"steps":4210,"workouts":[{"end":"2026-09-17T22:30:00Z","start":"2026-09-17T22:00:00Z","type":"running"},{"end":"2026-09-17T23:20:00Z","start":"2026-09-17T23:00:00Z","type":"other"}]}')) !>(?:(?=(%& -.hd) p.hd ~)))
    (expect-eq !>(`(each json @t)`|+'day: a local date, YYYY-MM-DD, is required') !>((health-doc:orr (jo '{"day": "yesterday"}'))))
    ::  a work day counts its own minutes from the blocks
    (expect-eq !>(`json`(numb:enjs:format 290)) !>(?:(?=(%& -.wd) (gj:orr p.wd 'active_minutes') ~)))
    ::  the store keeps the newest sixty days
    (expect-eq !>(60) !>(=/(st=json [%o ~] =/(n=@ud 0 |-(?:((gte n 70) (lent ~(tap by ?>(?=([%o *] st) p.st))) $(n +(n), st (keep-days:orr st (day-plus:orr '2026-01-01' n) b+&))))))))
    (expect !>(=/(st (keep-days:orr [%o ~] '2026-01-01' b+&) ?=([%o *] st))))
    ::  dates: the day of the week, the next Sunday
    (expect-eq !>(5) !>((dow-of:orr '2026-09-18')))
    (expect-eq !>('2026-09-20') !>((next-sunday:orr '2026-09-18')))
    (expect-eq !>('2026-09-27') !>((next-sunday:orr '2026-09-20')))
    ::  the night: the longest session
    (expect-eq !>(`(unit [@da @da])`[~ (sub now ~h9) (sub now ~h2)]) !>((night-of:orr ~[[(sub now ~h12) (sub now ~h11) ''] [(sub now ~h9) (sub now ~h2) ''] [(sub now ~h1) now '']])))
    ::  minutes in words
    (expect-eq !>(['40 min' '11 h' '9 h 05']) !>([(hours:orr 40) (hours:orr 660) (hours:orr 545)]))
    ::  a bedtime past midnight sorts after one before it
    (expect !>((gth (bed-minutes:orr ~2026.9.18..01.10.00 'UTC') (bed-minutes:orr ~2026.9.17..23.30.00 'UTC'))))
  ==
++  test-on-the-way
  =/  dir=json  (jo '{"routes": [{"duration": 1860.2, "duration_typical": 1140.4, "legs": [{"summary": "I 95 South, Elm Road", "incidents": [{"impact": "minor", "description": "Independent Dr: no through traffic"}, {"impact": "major", "description": "Crash on I-95 S at Elm"}]}]}]}')
  =/  calm=json  (jo '{"routes": [{"duration": 1200, "legs": [{"summary": "Main Hwy", "incidents": [{"impact": "low", "description": "Lane closed"}]}]}]}')
  =/  shop=json  (jo '{"features": [{"geometry": {"coordinates": [-89.6518, 39.7826]}, "properties": {"name": "Walgreens", "metadata": {"phone": "+19049249019", "open_hours": {"weekday_text": ["Monday: 8:00 AM - 10:00 PM", "Tuesday: 8:00 AM - 9:00 PM", "Sunday: Closed"]}}}}]}')
  =/  club=json  (jo '{"features": [{"geometry": {"coordinates": [-89.6508, 39.7821]}, "properties": {"name": "Club", "metadata": {"open_hours": {"weekday_text": ["Tuesday: Open 24 hours"]}}}}]}')
  =/  far=json  (jo '{"features": [{"geometry": {"coordinates": [-89.5912, 39.5682]}, "properties": {"name": "Elsewhere", "metadata": {}}}]}')
  =/  at=[@t @t]  ['39.7817' '-89.6501']
  ;:  weld
    ::  why the drive is what it is: usual seconds, the roads, the worst that matters
    (expect-eq !>([`(unit @ud)`[~ 1.140] 'I 95 South, Elm Road' 'Crash on I-95 S at Elm']) !>((route-why:orr dir)))
    (expect-eq !>([`(unit @ud)`~ 'Main Hwy' '']) !>((route-why:orr calm)))
    (expect-eq !>(`(unit @ud)`[~ 1.860]) !>((route-secs:orr dir)))
    ::  the usual time only when traffic adds three minutes or more
    (expect-eq !>('31 min with traffic (19 usual) via I 95 South') !>((drive-line:orr 1.860 `1.140 'I 95 South')))
    (expect-eq !>('20 min with traffic') !>((drive-line:orr 1.200 `1.140 '')))
    ::  late by the drive and the minutes to park past the time to be there
    (expect-eq !>(5) !>((late-by:orr now 1.800 ~m5 (add now ~m30))))
    (expect-eq !>(0) !>((late-by:orr now 600 ~m5 (add now ~m30))))
    ::  learned: nothing under three arrivals, the lower middle, twenty minutes at most
    (expect-eq !>(`@dr`0) !>((learned-extra:orr ~[300 60])))
    (expect-eq !>(~s120) !>((learned-extra:orr ~[300 60 120])))
    (expect-eq !>(~m20) !>((learned-extra:orr ~[3.000 2.000 2.500 9.000])))
    ::  points: millionths, near within about 300 m, across the sign apart
    (expect-eq !>(`(unit [? @ud])`[~ & 89.650.100]) !>((micro:orr '-89.6501')))
    (expect !>((near:orr at ['39.7826' '-89.6518'])))
    (expect !>(!(near:orr at ['39.5682' '-89.5912'])))
    (expect !>(!(near:orr ['0.001' '1.0'] ['-0.003' '1.0'])))
    ::  a place now: near, its phone, its hours that day; open all day says nothing
    (expect-eq !>(`(unit [@t @t @t])`[~ 'Walgreens' '+19049249019' 'Tuesday: 8:00 AM - 9:00 PM']) !>((place-info:orr shop at 2)))
    (expect-eq !>(`(unit [@t @t @t])`[~ 'Walgreens' '+19049249019' 'Sunday: Closed']) !>((place-info:orr shop at 0)))
    (expect-eq !>(`(unit [@t @t @t])`[~ 'Club' '' '']) !>((place-info:orr club at 2)))
    (expect-eq !>(`(unit [@t @t @t])`~) !>((place-info:orr far at 2)))
    ::  the search: encoded twice, near the point, businesses only
    (expect-eq !>('https://api.mapbox.com/search/searchbox/v1/forward?q=Smile%2520Dental%252C%25201%2520Main%2520St&proximity=-89.6501,39.7817&types=poi&limit=1&access_token=tk') !>((searchbox-url:orr 'https://api.mapbox.com' 'tk' 'Smile Dental\0a1 Main St' at)))
    ::  the map: numbered pins, lon before lat, fit to them
    (expect-eq !>('pin-l-1+d9534f(-89.5,39.6),pin-l-2+d9534f(-89.6,39.7)') !>((static-overlay:orr ~[['39.6' '-89.5'] ['39.7' '-89.6']])))
    (expect-eq !>('https://api.mapbox.com/styles/v1/mapbox/streets-v12/static/pin-l-1+d9534f(-89.5,39.6)/auto/600x360@2x?padding=40&access_token=tk') !>((static-url:orr 'https://api.mapbox.com' 'tk' 'pin-l-1+d9534f(-89.5,39.6)')))
  ==
++  test-leave
  =/  mk
    |=  [id=@t kind=@tas name=@t attrs=(list [a=@t v=json by=@t])]
    ^-  loaded:orr
    :+  id  [kind name ~ now ~]
    %+  turn  attrs
    |=  [a=@t v=json by=@t]
    ^-  row:orr
    [(rap 3 id '/' a '/' by (en:json:html v) ~) [id a v now ~ 90 ['t' 'x'] by now | '']]
  =/  ref  |=(b=@t `json`(pairs:enjs:format ~[['ref' s+b]]))
  =/  iso  |=(d=@dr `json`s+(en-iso:orr (add now d)))
  =/  multi=(set @t)  (sy ~['participants'])
  ::  the dentist names nobody the ship knows: the calendar's guess
  =/  dentist  (mk 'situation/dentist' %situation 'Dentist' ~[['starts' (iso ~h2) 'calendar'] ['ends' (iso ~h3) 'calendar'] ['location' s+'Smile Dental\0a1 Main St, Riverton' 'calendar'] ['participants' (ref 'person/me') 'calendar']])
  ::  the play date: the owner filed the children and not themselves
  =/  play  (mk 'situation/play' %situation 'Bea play date' ~[['starts' (iso ~h1) 'calendar'] ['location' s+'Alberts Field' 'calendar'] ['participants' (ref 'person/me') 'calendar'] ['participants' (ref 'person/wren') 'owner']])
  ::  the meeting: the owner said they go; a place they named
  =/  meet  (mk 'situation/meet' %situation 'Parent meeting' ~[['starts' (iso ~m90) 'calendar'] ['location' (ref 'place/ballet') 'calendar'] ['attending' s+'yes' 'owner']])
  ::  the practice, a series, next in four hours: out of a three-hour window
  =/  practice  (mk 'activity/practice' %activity 'Practice' ~[['next' (iso ~h4) 'calendar'] ['location' s+'Alberts Field' 'calendar'] ['participants' (ref 'person/me') 'owner']])
  ::  online, all day, closed, and said no to
  =/  call  (mk 'situation/call' %situation 'Call' ~[['starts' (iso ~h1) 'calendar'] ['location' s+'https://zoom.us/j/1' 'calendar']])
  =/  fair  (mk 'situation/fair' %situation 'Fair' ~[['starts' (iso ~h1) 'calendar'] ['ends' (iso ~h30) 'calendar'] ['location' s+'Fairground' 'calendar']])
  =/  over  (mk 'situation/over' %situation 'Over' ~[['starts' (iso ~h1) 'calendar'] ['location' s+'Somewhere' 'calendar'] ['status' s+'closed' 'owner']])
  =/  nope  (mk 'situation/nope' %situation 'Nope' ~[['starts' (iso ~h2) 'calendar'] ['location' s+'Elsewhere' 'calendar'] ['participants' (ref 'person/me') 'calendar'] ['attending' s+'no' 'owner']])
  =/  all=(list loaded:orr)  ~[dentist play meet practice call fair over nope]
  =/  ahead=(list appointment:orr)  (appointments-ahead:orr all multi now ~h3)
  =/  ids=(list @t)  (turn ahead |=(a=appointment:orr id.a))
  =/  dir=json  (jo '{"routes": [{"duration": 1834.7, "distance": 20000}], "code": "Ok"}')
  =/  geo=json  (jo '{"type": "FeatureCollection", "features": [{"geometry": {"type": "Point", "coordinates": [-89.6501, 39.7817]}, "properties": {}}]}')
  ;:  weld
    ::  the verdicts
    (expect-eq !>(%unsure) !>((attends:orr dentist multi now)))
    (expect-eq !>(%no) !>((attends:orr play multi now)))
    (expect-eq !>(%yes) !>((attends:orr meet multi now)))
    (expect-eq !>(%yes) !>((attends:orr practice multi now)))
    (expect-eq !>(%no) !>((attends:orr nope multi now)))
    (expect-eq !>(%no) !>((attends:orr call multi now)))
    ::  what is ahead, soonest first: what the owner does not go to,
    ::  online, all day, closed and beyond the window left out
    (expect-eq !>(`(list @t)`~['situation/meet' 'situation/dentist']) !>(ids))
    (expect-eq !>([`(unit @t)`[~ 'place/ballet'] '']) !>(=/(m (snag 0 ahead) [place.m where.m])))
    (expect-eq !>('Smile Dental\0a1 Main St, Riverton') !>(where:(snag 1 ahead)))
    ::  a series is ahead by its next once the window reaches it
    (expect !>((lien (turn (appointments-ahead:orr all multi now ~h5) |=(a=appointment:orr id.a)) |=(t=@t =('activity/practice' t)))))
    ::  one alert per occurrence
    =/  first=appointment:orr  (snag 0 ahead)
    (expect !>(!=((appt-key:orr first) (appt-key:orr first(starts (add now ~d7))))))
    ::  leave and alert: the start less the drive and the buffer, less the lead
    (expect-eq !>([(sub (add now ~h2) (add ~s1834 ~m5)) (sub (add now ~h2) (add ~s1834 ~m15))]) !>((leave-times:orr (add now ~h2) 1.834 ~m5 ~m10)))
    ::  no telling needed: at the place already, from a close fix of any age
    (expect-eq !>(`(unit @t)`[~ 'already there']) !>((leave-quiet:orr 90 1.500 'position' '12' `(sub now ~h2) now %yes)))
    ::  set off: a close fix minutes old and the drive far shorter
    (expect-eq !>(`(unit @t)`[~ 'on the way already']) !>((leave-quiet:orr 700 1.500 'position' '8.5' `(sub now ~m3) now %yes)))
    ::  a coarse fix is never evidence, near or moving
    (expect-eq !>(`(unit @t)`~) !>((leave-quiet:orr 90 1.500 'position' '2000' `now now %yes)))
    (expect-eq !>(`(unit @t)`~) !>((leave-quiet:orr 700 1.500 'position' '2000' `(sub now ~m3) now %yes)))
    ::  an old fix with the drive shorter is the traffic, not a set-off
    (expect-eq !>(`(unit @t)`~) !>((leave-quiet:orr 700 1.500 'position' '8' `(sub now ~m30) now %yes)))
    ::  a little shorter is not a set-off
    (expect-eq !>(`(unit @t)`~) !>((leave-quiet:orr 1.300 1.500 'position' '8' `(sub now ~m3) now %yes)))
    ::  leaving from home, not the phone's fix, or a fix with no accuracy: no evidence
    (expect-eq !>(`(unit @t)`~) !>((leave-quiet:orr 60 1.500 'home' '8' `now now %yes)))
    (expect-eq !>(`(unit @t)`~) !>((leave-quiet:orr 60 1.500 'position' '' `now now %yes)))
    ::  over two hours away: only for what the owner said they go to
    (expect-eq !>(`(unit @t)`[~ 'over two hours away, and not said to be going']) !>((leave-quiet:orr 8.000 8.000 'home' '' ~ now %unsure)))
    (expect-eq !>(`(unit @t)`~) !>((leave-quiet:orr 8.000 8.000 'home' '' ~ now %yes)))
    (expect-eq !>(`(unit @t)`~) !>((leave-quiet:orr 7.200 7.200 'home' '' ~ now %unsure)))
    ::  addresses and coordinates
    (expect-eq !>('smile dental 1 main st, riverton') !>((addr-key:orr 'Smile  Dental\0a1 Main St,  Riverton ')))
    (expect-eq !>(`(unit [@t @t])`[~ '39.7817' '-89.6501']) !>((geo-of:orr s+'39.7817, -89.6501')))
    (expect-eq !>(`(unit [@t @t])`[~ '39.7817' '-89.6501']) !>((geo-of:orr (jo '{"lat": 39.7817, "lon": -89.6501}'))))
    (expect-eq !>(`(unit [@t @t])`~) !>((geo-of:orr s+'95.1,-89.6')))
    (expect-eq !>(`(unit [@t @t])`~) !>((geo-of:orr s+'home')))
    ::  Mapbox: lon before lat, no geometry, departing when ahead; a permanent lookup
    (expect-eq !>('https://api.mapbox.com/directions/v5/mapbox/driving-traffic?access_token=tk') !>((directions-url:orr 'https://api.mapbox.com' 'tk')))
    (expect-eq !>('coordinates=-89.7,39.7;-89.6501,39.7817&overview=false&steps=false&depart_at=2026-09-18T13:00:00Z') !>((directions-body:orr ['39.7' '-89.7'] ['39.7817' '-89.6501'] `(add now ~h1))))
    (expect-eq !>('coordinates=-89.7,39.7;-89.6501,39.7817&overview=false&steps=false') !>((directions-body:orr ['39.7' '-89.7'] ['39.7817' '-89.6501'] ~)))
    (expect-eq !>('https://api.mapbox.com/search/geocode/v6/batch?permanent=true&access_token=tk') !>((geocode-url:orr 'https://api.mapbox.com' 'tk')))
    ::  the address in the body, its lines one line
    (expect-eq !>((jo '[{"q": "The City Ballet, 100 Main St, Ste #2571, Riverton", "limit": 1}]')) !>((geocode-body:orr 'The City Ballet\0a100 Main St, Ste #2571, Riverton \0a')))
    (expect-eq !>(`(unit [@t @t])`[~ '39.7817' '-89.6501']) !>((geocode-point:orr (jo '{"batch": [{"type": "FeatureCollection", "features": [{"geometry": {"type": "Point", "coordinates": [-89.6501, 39.7817]}}]}]}'))))
    (expect-eq !>(`(unit [@t @t])`~) !>((geocode-point:orr (jo '{"batch": [{"type": "FeatureCollection", "features": []}]}'))))
    (expect-eq !>(`(unit @ud)`[~ 1.834]) !>((route-secs:orr dir)))
    (expect-eq !>(`(unit @ud)`~) !>((route-secs:orr (jo '{"routes": [], "code": "NoRoute"}'))))
    (expect-eq !>(`(unit [@t @t])`[~ '39.7817' '-89.6501']) !>((geocode-point:orr geo)))
    (expect-eq !>(`(unit [@t @t])`~) !>((geocode-point:orr (jo '{"features": []}'))))
    ::  the brief's lines: the sure ones say so, the unsure ones ask, a no is left out
    (expect-eq !>(`(list @t)`~['13:30  Parent meeting: I\'ll say when to leave' '14:00  Dentist (Smile Dental): going? Reply "not me: Dentist" if not']) !>((brief-leaving:orr (turn ahead |=(a=appointment:orr [a '' ''])) 'UTC')))
    ::  a stop with its pin on the map and that day's hours (version 73)
    (expect-eq !>(`(list @t)`~['[1] 13:30  Parent meeting (Tuesday: 9:00 AM - 5:00 PM): I\'ll say when to leave']) !>((brief-leaving:orr (scag 1 (turn ahead |=(a=appointment:orr [a '1' 'Tuesday: 9:00 AM - 5:00 PM']))) 'UTC')))
  ==
++  test-trips
  =/  mk
    |=  [id=@t kind=@tas name=@t attrs=(list [a=@t v=json by=@t])]
    ^-  loaded:orr
    :+  id  [kind name ~ now ~]
    %+  turn  attrs
    |=  [a=@t v=json by=@t]
    ^-  row:orr
    [(rap 3 id '/' a '/' by (en:json:html v) ~) [id a v now ~ 90 ['t' 'x'] by now | '']]
  =/  ref  |=(b=@t `json`(pairs:enjs:format ~[['ref' s+b]]))
  =/  iso  |=(d=@dr `json`s+(en-iso:orr (add now d)))
  =/  multi=(set @t)  (sy ~['participants'])
  =/  where  ['location' s+'Lakeside Pool' 'calendar']
  ::  swimming today: Lena drops off, the owner picks up; 4 to 6
  =/  sail  (mk 'situation/sail' %situation 'Sail' ~[['starts' (iso ~h1) 'calendar'] ['ends' (iso ~h3) 'calendar'] where ['drop-off' (ref 'person/lena') 'owner'] ['pick-up' (ref 'person/me') 'owner']])
  ::  the owner does both legs
  =/  both  (mk 'situation/both' %situation 'Both' ~[['starts' (iso ~h1) 'calendar'] ['ends' (iso ~h2) 'calendar'] where ['drop-off' (ref 'person/me') 'owner'] ['pick-up' (ref 'person/me') 'owner']])
  ::  Lena does both, though the calendar lists the owner: no trip
  =/  hers  (mk 'situation/hers' %situation 'Hers' ~[['starts' (iso ~h1) 'calendar'] ['ends' (iso ~h2) 'calendar'] where ['participants' (ref 'person/me') 'calendar'] ['drop-off' (ref 'person/lena') 'owner'] ['pick-up' (ref 'person/lena') 'owner']])
  ::  a pick-up with no end known: left out
  =/  open-end  (mk 'situation/open' %situation 'Open' ~[['starts' (iso ~h1) 'calendar'] where ['pick-up' (ref 'person/me') 'owner']])
  ::  a series: the end is the calendar's next row's until, though
  ::  reconcile's later row for the same occurrence, a day's until, wins
  =/  series=loaded:orr
    :+  'activity/swim'  [%activity 'Swim' ~ now ~]
    :~  ['activity/swim/next' ['activity/swim' 'next' s+(en-iso:orr (add now ~h1)) (sub now ~h1) `(add now ~h3) 100 ['calendar' 'E9'] 'calendar' now | '']]
        ['activity/swim/rnext' ['activity/swim' 'next' s+(en-iso:orr (add now ~h1)) now `(add now ~d1) 90 ['reconcile' 'times/x'] 'reconcile' now | '']]
        ['activity/swim/loc' ['activity/swim' 'location' s+'Lakeside Pool' now ~ 100 ['calendar' 'E9'] 'calendar' now | '']]
        ['activity/swim/pick' ['activity/swim' 'pick-up' (ref 'person/me') now ~ 100 ['owner' 'x'] 'owner' now | '']]
    ==
  =/  ahead  |=(ls=(list loaded:orr) (appointments-ahead:orr ls multi now ~h4))
  =/  legs  |=(as=(list appointment:orr) (turn as |=(a=appointment:orr [id.a leg.a starts.a])))
  ;:  weld
    (expect-eq !>(`(list [@t leg:orr @da])`~[['situation/sail' %pick (add now ~h3)]]) !>((legs (ahead ~[sail]))))
    (expect-eq !>(`(list [@t leg:orr @da])`~[['situation/both' %drop (add now ~h1)] ['situation/both' %pick (add now ~h2)]]) !>((legs (ahead ~[both]))))
    (expect-eq !>(`(list [@t leg:orr @da])`~) !>((legs (ahead ~[hers]))))
    (expect-eq !>(`(list [@t leg:orr @da])`~) !>((legs (ahead ~[open-end]))))
    (expect-eq !>(`(list [@t leg:orr @da])`~[['activity/swim' %pick (add now ~h3)]]) !>((legs (ahead ~[series]))))
    ::  a drop-off and a pick-up of one occurrence are two alerts
    =/  bs=(list appointment:orr)  (ahead ~[both])
    (expect !>(!=((appt-key:orr (snag 0 bs)) (appt-key:orr (snag 1 bs)))))
    ::  the brief says which leg
    (expect-eq !>(`(list @t)`~['13:00  Drop off: Both (Lakeside Pool): I\'ll say when to leave' '14:00  Pick up: Both (Lakeside Pool): I\'ll say when to leave']) !>((brief-leaving:orr (turn (ahead ~[both]) |=(a=appointment:orr [a '' ''])) 'UTC')))
  ==
++  test-del-key
  =/  o=json  (jo '{"a": 1, "parked": "x"}')
  ;:  weld
    (expect-eq !>((jo '{"a": 1}')) !>((del-key:orr o 'parked')))
    (expect-eq !>(o) !>((del-key:orr o 'nope')))
    (expect-eq !>(`json`s+'t') !>((del-key:orr s+'t' 'a')))
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
