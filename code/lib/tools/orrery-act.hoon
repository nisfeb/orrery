::  orrery-act: propose an action, as POST /apps/orrery/api/act
::
/<  tools  /lib/tools.hoon
/<  orr  /lib/orrery.hoon
/<  om  /lib/orrery-mcp.hoon
^-  tool:tools
|%
++  name  'orrery-act'
++  description
  'Propose an action about the state: a task, a note, a message, or another kind. Policy decides whether it is approved at once or waits in the inbox. An open action with the same kind and title answers the existing one.'
++  parameters
  ^-  (map @t parameter-def:tools)
  %-  ~(gas by *(map @t parameter-def:tools))
  :~  ['kind' [%string 'the action kind, e.g. "task"']]
      ['title' [%string 'what to do, at most 200 bytes']]
      ['payload' [%object 'anything the action needs, at most 4000 bytes serialized']]
      ['about' [%array 'body ids this action is about, at most 20']]
      ['due' [%string 'ISO 8601 UTC time the action is due']]
      ['by' [%string 'who is proposing (default "mcp")']]
  ==
++  required  ~['kind' 'title']
++  handler
  ^-  tool-handler:tools
  =/  m  (fiber:fiber:nexus ,tool-result:tools)
  ^-  form:m
  ;<  st=tool-state:tools  bind:m  (get-state-as:io ,tool-state:tools)
  =/  who=@t  (fall (arg:om args.st 'by') 'mcp')
  =/  jon=json
    :-  %o
    %-  ~(gas by *(map @t json))
    %+  murn  ~['kind' 'title' 'payload' 'about' 'due']
    |=  k=@t
    ^-  (unit [@t json])
    =/  v=json  (arg-json:om args.st k)
    ?~(v ~ `[k v])
  ;<  now=@da  bind:m  get-time:io
  =/  stamped=json  (fill-act:orr jon now who)
  =/  got  (de-action:orr stamped now who)
  ?:  ?=(%| -.got)  (pure:m (fail:om p.got))
  ;<  missing=(unit bid:orr)  bind:m  (first-missing:om ~(tap in about.p.got))
  ?^  missing  (pure:m (fail:om (cat 3 'about: no such body ' u.missing)))
  ;<  policy=json  bind:m  (read-json:om / %'policy.json')
  ;<  all=(list [id=@ta a=action:orr])  bind:m  load-actions:om
  =/  twin=(unit [id=@ta a=action:orr])  (open-twin:om all kind.p.got title.p.got)
  ?^  twin
    %-  pure:m
    %-  text:om
    (pairs:enjs:format ~[['id' s+id.u.twin] ['status' s+status.a.u.twin] ['existing' b+&]])
  =/  a=action:orr  p.got(status (initial-status:orr kind.p.got (auto-of:orr policy)))
  ;<  err=(unit tang)  bind:m
    (poke-writer:om (pairs:enjs:format ~[['op' s+'act'] ['action' stamped]]))
  ?^  err  (pure:m (fail:om 'the writer refused the poke'))
  %-  pure:m
  %-  text:om
  (pairs:enjs:format ~[['id' s+(act-id:orr a)] ['status' s+status.a] ['existing' b+|]])
--
