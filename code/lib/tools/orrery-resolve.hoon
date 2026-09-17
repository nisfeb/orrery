::  orrery-resolve: bodies by name or alias, as GET /apps/orrery/api/resolve?q=
::
/<  tools  /lib/tools.hoon
/<  orr  /lib/orrery.hoon
/<  om  /lib/orrery-mcp.hoon
^-  tool:tools
|%
++  name  'orrery-resolve'
++  description
  'Find bodies whose name or alias matches a phrase: exact matches first, then prefixes, case-insensitive, at most 20. Use it before observing about someone or something named in a message.'
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
  ;<  ~  bind:m  ensure-me:om
  =/  q=@t  (fall (arg:om args.st 'q') '')
  ;<  all=(list loaded:orr)  bind:m  load-bodies:om
  =/  bodies=(list [id=bid:orr =body:orr])  (turn all |=(l=loaded:orr [id.l body.l]))
  %-  pure:m
  %-  text:om
  :-  %a
  %+  turn  (resolve:orr q bodies)
  |=  [id=bid:orr =body:orr match=@tas]
  ^-  json
  (pairs:enjs:format ~[['id' s+id] ['kind' s+kind.body] ['name' s+name.body] ['match' s+match]])
--
