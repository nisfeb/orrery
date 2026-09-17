::  orrery-retract: withdraw one observation, as POST /apps/orrery/api/retract
::
/<  tools  /lib/tools.hoon
/<  orr  /lib/orrery.hoon
/<  om  /lib/orrery-mcp.hoon
^-  tool:tools
|%
++  name  'orrery_retract'
++  description
  'Retract one observation by id. The row stays on the timeline marked retracted with the note; the current state is recomputed without it.'
++  parameters
  ^-  (map @t parameter-def:tools)
  %-  ~(gas by *(map @t parameter-def:tools))
  :~  ['id' [%string 'the observation id, from a body view or an observe answer']]
      ['note' [%string 'why (at most 500 bytes)']]
      ['by' [%string 'who is retracting (default "mcp")']]
  ==
++  required  ~['id']
++  handler
  ^-  tool-handler:tools
  =/  m  (fiber:fiber:nexus ,tool-result:tools)
  ^-  form:m
  ;<  st=tool-state:tools  bind:m  (get-state-as:io ,tool-state:tools)
  =/  id=(unit @t)  (arg:om args.st 'id')
  ?~  id  (pure:m (fail:om 'id: required'))
  =/  why=@t  (fall (arg:om args.st 'note') '')
  ?:  (gth (met 3 why) max-note:orr)  (pure:m (fail:om 'note: over 500 bytes'))
  =/  who=@t  (fall (arg:om args.st 'by') 'mcp')
  ;<  all=(list loaded:orr)  bind:m  load-bodies:om
  ?~  (find-obs:om all `@ta`u.id)  (pure:m (fail:om 'no such observation'))
  =/  op=json
    (pairs:enjs:format ~[['op' s+'retract'] ['id' s+u.id] ['note' s+why] ['by' s+who]])
  ;<  err=(unit tang)  bind:m  (poke-writer:om op)
  ?^  err  (pure:m (fail:om 'the writer refused the poke'))
  (pure:m (text:om (pairs:enjs:format ~[['id' s+u.id] ['ok' b+&]])))
--
