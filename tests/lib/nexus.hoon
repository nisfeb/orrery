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
  =/  ref-me  (pairs:enjs:format ~[['ref' s+'person/andrea']])
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
    (expect-eq !>(['situation/trip' 'participants' 'person/andrea' 'she stays home' now 'owner']) !>(p.c1))
    (expect-eq !>(`(list @t)`~['person/andrea' 'person/lin']) !>((turn cs |=(c=correction:orr ?:(=('person/lin' subject.c) subject.c value.c)))))
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
    :~  ['situation/trip' 'participants' 'person/andrea' '' now 'owner']
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
  =/  c=correction:orr  ['situation/trip' 'participants' 'person/andrea' 'she stays home' now 'owner']
  ;:  weld
    %+  expect-eq
      !>  ^-  (list @t)
      :~  'The owner struck these facts as wrong; never write them again:'
          '  situation/trip participants = person/andrea (she stays home)'
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
  =/  plans  (plan-exec:orr ~[['c1' (mk %correct '{"subject": "situation/trip", "attr": "participants", "value": {"ref": "person/andrea"}}')] ['m1' (mk %merge '{"from": "person/a", "into": "person/b"}')] ['p1' (mk %preference '{"text": ""}')]] ~ ~ ~ now '' ['' ''])
  ;:  weld
    (expect-eq !>('correct') !>((gs:orr (op (mk %correct '{"subject": "situation/trip", "attr": "participants", "value": {"ref": "person/andrea"}, "why": "home"}')) 'op')))
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
  =/  known=(set @t)  (sy ~['situation/trip' 'person/andrea' 'person/me'])
  =/  ans=json
    %-  jo
    '''
    {"reply": "  Takes Andrea off the trip. ",
     "actions": [
      {"kind": "correct", "title": "Andrea is not on the trip", "about": ["situation/trip", "person/nobody"],
       "payload": {"subject": "situation/trip", "attr": "participants", "value": {"ref": "person/andrea"}, "why": "she stays home"}},
      {"kind": "correct", "payload": {"subject": "situation/trip", "attr": "participants", "value": {"ref": "person/andrea"}}},
      {"kind": "home", "title": "lights", "payload": {}},
      {"kind": "merge", "title": "one", "payload": {"from": "person/ghost", "into": "person/me"}},
      {"kind": "fact", "title": "bad", "payload": {"subject": "person/andrea", "attr": "", "value": "x"}},
      {"kind": "preference", "title": "rule", "payload": {"text": "Andrea stays home when I travel for work"}}]}
    '''
  =/  out  (de-instruct:orr ans known now 'owner')
  ;:  weld
    (expect-eq !>('Takes Andrea off the trip.') !>(reply.out))
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
    :~  (b 'person/andrea' 'Andrea' ~['wife'])
        (b 'person/lin' 'Lin' ~)
        (b 'situation/trip' 'Barcelona trip' ~)
        (b 'person/al' 'Al' ~)
    ==
  ;:  weld
    (expect-eq !>(`(list @t)`~['situation/trip' 'person/andrea']) !>((turn (instruct-focus:orr all (sy ~['situation/trip']) 'my Wife stays home') |=(l=loaded:orr id.l))))
    (expect-eq !>(`(list @t)`~) !>((turn (instruct-focus:orr all ~ 'al is here') |=(l=loaded:orr id.l))))
  ==
::  an alias comes off however it is cased or spaced, and the rest stay
++  test-without-alias
  =/  b=body:orr  [%person 'Andrea' (sy ~['jackson' '~ricsul-bilwyt-dozzod-nisfeb' 'wife']) now `~wet]
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
