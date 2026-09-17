::  orrery-resolve: bodies by identity or name, as GET /apps/orrery/api/resolve?q=
::
/<  tools  /lib/tools.hoon
/<  orr  /lib/orrery.hoon
/<  om  /lib/orrery-mcp.hoon
^-  tool:tools
|%
++  name  'orrery_resolve'
++  description
  'Find the bodies a phrase could mean: an email address, a phone number, a name or an alias. Exact matches first, then bodies sharing every word of the phrase, then prefixes, case-insensitive, at most 20. Use it before observing about someone or something named in a message.'
++  parameters
  ^-  (map @t parameter-def:tools)
  %-  ~(gas by *(map @t parameter-def:tools))
  :~  ['q' [%string 'the name or alias to look up']]
  ==
++  required  ~['q']
++  handler
  ^-  tool-handler:tools
  =/  m  (fiber:fiber:nexus ,tool-result:tools)
  ^-  form:m
  ;<  st=tool-state:tools  bind:m  (get-state-as:io ,tool-state:tools)
  ;<  ok=?  bind:m  ensure-me:om
  ?.  ok  (pure:m (fail:om 'orrery: peek refused'))
  =/  q=@t  (fall (arg:om args.st 'q') '')
  ;<  now=@da  bind:m  get-time:io
  ;<  schema=json  bind:m  (read-json:om / %'schema.json')
  ;<  all=(list loaded:orr)  bind:m  load-bodies:om
  =/  multi=(set @t)  (multi-of:orr schema)
  =/  bodies=(list [id=bid:orr =body:orr winners=(map @t (list row:orr))])
    (turn all |=(l=loaded:orr [id.l body.l (fold:orr rows.l multi now)]))
  %-  pure:m
  %-  text:om
  :-  %a
  %+  turn  (resolve:orr q bodies)
  |=  [id=bid:orr =body:orr match=@tas]
  ^-  json
  (pairs:enjs:format ~[['id' s+id] ['kind' s+kind.body] ['name' s+name.body] ['match' s+match]])
--
