::  orrery-actions: list actions, or move one, as GET and POST /apps/orrery/api/actions
::
::  +move sits in a core BELOW the tool: a tool:tools cast admits the five
::  arms it names and no more (core-number-of-arms.exp=5), so a helper
::  beside the handler is an extra arm and the cast refuses it.
::
/<  tools  /lib/tools.hoon
/<  orr  /lib/orrery.hoon
/<  om  /lib/orrery-mcp.hoon
=<
^-  tool:tools
|%
++  name  'orrery_actions'
++  description
  'Without an id: list actions, newest first, by status ("open" for proposed, approved and claimed, the default; "all"; or one status). With an id and a status: move that action to approved, claimed, dismissed, done or failed, with an optional note. A claim holds an approved action for ten minutes, so only the actor that claimed it reports done or failed.'
++  parameters
  ^-  (map @t parameter-def:tools)
  %-  ~(gas by *(map @t parameter-def:tools))
  :~  ['status' [%string 'to list: open, all, or one status; to move: the new status']]
      ['id' [%string 'the action to move']]
      ['note' [%string 'why, when moving (at most 500 bytes)']]
      ['by' [%string 'who is moving it (default "mcp")']]
  ==
++  required  *(list @t)
++  handler
  ^-  tool-handler:tools
  =/  m  (fiber:fiber:nexus ,tool-result:tools)
  ^-  form:m
  ;<  st=tool-state:tools  bind:m  (get-state-as:io ,tool-state:tools)
  =/  id=(unit @t)  (arg:om args.st 'id')
  ?^  id  (move u.id args.st)
  =/  want=@t  (fall (arg:om args.st 'status') 'open')
  ;<  all=(list [id=@ta a=action:orr])  bind:m  load-actions:om
  =/  keep
    |=  [id=@ta a=action:orr]
    ^-  ?
    ?:  =('all' want)  &
    ?:  =('open' want)  (is-open:orr a)
    =(want `@t`status.a)
  =/  shown=(list [id=@ta a=action:orr])
    %+  sort  (skim all keep)
    |=([x=[id=@ta a=action:orr] y=[id=@ta a=action:orr]] (gth proposed.a.x proposed.a.y))
  (pure:m (text:om a+(turn shown |=([id=@ta a=action:orr] (en-action:orr id a)))))
--
::  +move: one transition through the writer
::
|%
++  move
  |=  [id=@t args=(map @t json)]
  =/  m  (fiber:fiber:nexus ,tool-result:tools)
  ^-  form:m
  =/  want=@t  (fall (arg:om args 'status') '')
  ?:  =('' want)  (pure:m (fail:om 'status: required to move an action'))
  =/  why=@t  (fall (arg:om args 'note') '')
  ?:  (gth (met 3 why) max-note:orr)  (pure:m (fail:om 'note: over 500 bytes'))
  =/  who=@t  (fall (arg:om args 'by') 'mcp')
  ?:  (gth (met 3 who) max-by:orr)  (pure:m (fail:om 'by: over 64 bytes'))
  ;<  a=(unit action:orr)  bind:m  (read-action-at:om `@ta`id)
  ?~  a  (pure:m (fail:om 'no such action'))
  ;<  now=@da  bind:m  get-time:io
  =/  no=(unit @t)  (move-refusal:orr u.a `@tas`want who now)
  ?^  no  (pure:m (fail:om u.no))
  =/  op=json
    %-  pairs:enjs:format
    ~[['op' s+'set-action'] ['id' s+id] ['status' s+want] ['note' s+why] ['by' s+who]]
  ;<  err=(unit tang)  bind:m  (poke-writer:om op)
  ?^  err  (pure:m (fail:om 'the writer refused the poke'))
  =/  ans=json
    (pairs:enjs:format ~[['id' s+id] ['status' s+want] ['by' s+who] ['ok' b+&]])
  (pure:m (text:om ans))
--
