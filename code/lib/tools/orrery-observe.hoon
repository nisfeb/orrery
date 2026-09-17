::  orrery-observe: a batch of bodies and observations, as POST /apps/orrery/api/observe
::
/<  tools  /lib/tools.hoon
/<  orr  /lib/orrery.hoon
/<  om  /lib/orrery-mcp.hoon
^-  tool:tools
|%
++  name  'orrery_observe'
++  description
  'Submit observations, and the bodies they need, in one batch. Each observation: {subject, attr, value, at?, until?, conf?, source: {kind, id}}; each body: {id, name?, aliases?, ship?}. Answers one result per item, in order, with the observation id and whether it already existed. A batch is at most 50 bodies and 200 observations.'
++  parameters
  ^-  (map @t parameter-def:tools)
  %-  ~(gas by *(map @t parameter-def:tools))
  :~  ['bodies' [%array 'bodies to create or update before the observations, each {id, name, aliases, ship}']]
      ['observations' [%array 'observations, each {subject, attr, value, at, until, conf, source: {kind, id}}']]
      ['by' [%string 'who is observing (default "mcp")']]
  ==
++  required  ~['observations']
++  handler
  ^-  tool-handler:tools
  =/  m  (fiber:fiber:nexus ,tool-result:tools)
  ^-  form:m
  ;<  st=tool-state:tools  bind:m  (get-state-as:io ,tool-state:tools)
  =/  who=@t  (fall (arg:om args.st 'by') 'mcp')
  =/  bodies=json  (arg-json:om args.st 'bodies')
  =/  observations=json  (arg-json:om args.st 'observations')
  ?.  |(?=(~ bodies) ?=([%a *] bodies))  (pure:m (fail:om 'bodies: expected an array'))
  ?.  ?=([%a *] observations)  (pure:m (fail:om 'observations: expected an array'))
  =/  jon=json
    (pairs:enjs:format ~[['bodies' ?~(bodies [%a ~] bodies)] ['observations' observations]])
  ?:  (gth (lent (ga:orr jon 'bodies')) max-bodies:orr)  (pure:m (fail:om 'bodies: over 50'))
  ?:  (gth (lent (ga:orr jon 'observations')) max-obs:orr)  (pure:m (fail:om 'observations: over 200'))
  ;<  now=@da  bind:m  get-time:io
  =/  all-obs=(list json)
    (turn (ga:orr jon 'observations') |=(j=json (fill-obs:orr j now who)))
  ::  a ship source is the inbox's to set, from the transport: an item
  ::  claiming one is answered refused and never reaches the writer
  =/  stamped=json
    %-  pairs:enjs:format
    :~  ['op' s+'observe']
        ['bodies' a+(ga:orr jon 'bodies')]
        ['observations' a+(skip all-obs ship-source:orr)]
    ==
  =/  shown=json
    %-  pairs:enjs:format
    :~  ['op' s+'observe']
        ['bodies' a+(ga:orr jon 'bodies')]
        ['observations' a+all-obs]
    ==
  =/  prep  (prep-observe:orr shown now who)
  =/  items=(list (each obs:orr @t))  (mark-reserved:orr all-obs obs.prep)
  ;<  ok=?  bind:m  ensure-me:om
  ?.  ok  (pure:m (fail:om 'orrery: peek refused'))
  ;<  bodies-res=(list json)  bind:m  (body-results:om bodies.prep ~ ~)
  =/  known=(set bid:orr)
    %-  sy
    :-  'person/me'
    %+  murn  bodies.prep
    |=(e=(each [id=bid:orr =body:orr] @t) ?:(?=(%& -.e) `id.p.e ~))
  ;<  obs-res=(list json)  bind:m  (obs-results:om items known ~ ~)
  ;<  err=(unit tang)  bind:m  (poke-writer:om stamped)
  ?^  err  (pure:m (fail:om 'the writer refused the poke'))
  (pure:m (text:om (pairs:enjs:format ~[['bodies' a+bodies-res] ['observations' a+obs-res]])))
--
