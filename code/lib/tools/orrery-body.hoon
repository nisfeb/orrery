::  orrery-body: one body's view, as GET /apps/orrery/api/body/<kind>/<slug>
::
/<  tools  /lib/tools.hoon
/<  orr  /lib/orrery.hoon
/<  om  /lib/orrery-mcp.hoon
^-  tool:tools
|%
++  name  'orrery_body'
++  description
  'One body: its record, current attributes, the situations it is involved in, the open actions about it, and its timeline of observations with source pointers.'
++  parameters
  ^-  (map @t parameter-def:tools)
  %-  ~(gas by *(map @t parameter-def:tools))
  :~  ['id' [%string 'the body id, <kind>/<slug>, e.g. "person/me"']]
      ['at' [%string 'ISO 8601 UTC time; the view as of then (default: now)']]
  ==
++  required  ~['id']
++  handler
  ^-  tool-handler:tools
  =/  m  (fiber:fiber:nexus ,tool-result:tools)
  ^-  form:m
  ;<  st=tool-state:tools  bind:m  (get-state-as:io ,tool-state:tools)
  ;<  ok=?  bind:m  ensure-me:om
  ?.  ok  (pure:m (fail:om 'orrery: peek refused'))
  =/  id=(unit @t)  (arg:om args.st 'id')
  ?~  id  (pure:m (fail:om 'id: required'))
  ?~  (parse-bid:orr u.id)  (pure:m (fail:om 'id: expected <kind>/<slug>'))
  ;<  now=@da  bind:m  get-time:io
  =/  when=(unit @da)  (when-arg:om args.st now)
  ?~  when  (pure:m (fail:om 'at: expected an ISO 8601 UTC time'))
  ;<  schema=json  bind:m  (read-json:om / %'schema.json')
  ;<  all=(list loaded:orr)  bind:m  load-bodies:om
  =/  mine=(unit loaded:orr)  (find-loaded:om all u.id)
  ?~  mine  (pure:m (fail:om 'no such body'))
  ;<  acts=(list [id=@ta a=action:orr])  bind:m  load-actions:om
  =/  multi=(set @t)  (multi-of:orr schema)
  (pure:m (text:om (body-json:orr u.mine (situations:orr all multi u.when) acts multi u.when)))
--
