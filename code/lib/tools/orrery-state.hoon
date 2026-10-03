::  orrery-state: the state view, as GET /apps/orrery/api/state gives it
::
/<  tools  /lib/tools.hoon
/<  orr  /lib/orrery.hoon
/<  om  /lib/orrery-mcp.hoon
^-  tool:tools
|%
++  name  'orrery_state'
++  description
  'The state view of orrery. Start with brief: true: every body as id, kind, name, aliases, its current values and the situations it is in; the open situations with what each needs and whose move it is; the open actions; the kinds with their attribute names. It is a tenth the size of the full view. The full view (brief absent) adds every value\'s source, time and confidence and every action\'s history and payload, and runs to hundreds of kilobytes on a busy ship: read it only when you need provenance, and then with kind set. To act on a few named things, orrery_resolve and orrery_body are smaller still.'
++  parameters
  ^-  (map @t parameter-def:tools)
  %-  ~(gas by *(map @t parameter-def:tools))
  :~  ['at' [%string 'ISO 8601 UTC time; the view as of then (default: now)']]
      ['kind' [%string 'only the bodies of this kind, e.g. "person"']]
      ['brief' [%boolean 'true for the values and what is open, without provenance; read this first']]
  ==
++  required  *(list @t)
++  handler
  ^-  tool-handler:tools
  =/  m  (fiber:fiber:nexus ,tool-result:tools)
  ^-  form:m
  ;<  st=tool-state:tools  bind:m  (get-state-as:io ,tool-state:tools)
  ;<  ok=?  bind:m  ensure-me:om
  ?.  ok  (pure:m (fail:om 'orrery: peek refused'))
  ;<  now=@da  bind:m  get-time:io
  =/  when=(unit @da)  (when-arg:om args.st now)
  ?~  when  (pure:m (fail:om 'at: expected an ISO 8601 UTC time'))
  =/  kind=@t  (fall (arg:om args.st 'kind') '')
  ;<  schema=json  bind:m  (read-json:om / %'schema.json')
  ;<  rev=json  bind:m  (read-json:om /beacon %rev)
  ;<  all=(list loaded:orr)  bind:m  load-bodies:om
  ;<  acts=(list [id=@ta a=action:orr])  bind:m  load-actions:om
  =/  brief=?  ?=([~ %b %.y] (~(get by args.st) 'brief'))
  ?:  brief  (pure:m (text:om (brief-json:orr all acts (multi-of:orr schema) u.when kind rev schema)))
  (pure:m (text:om (state-json:orr all acts (multi-of:orr schema) u.when kind rev schema)))
--
