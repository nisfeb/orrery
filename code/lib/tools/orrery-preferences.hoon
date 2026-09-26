::  orrery-preferences: read or change the owner's style and standing
::  preferences alone, as GET and PUT /apps/orrery/api/preferences
::
/<  tools  /lib/tools.hoon
/<  orr  /lib/orrery.hoon
/<  om  /lib/orrery-mcp.hoon
^-  tool:tools
|%
++  name  'orrery_preferences'
++  description
  'Without arguments: the owner\'s style (how anything written in their voice should read) and standing preferences (what they want proposed and what not), which every prompt reads. With style or preferences: replace that one; the rest of the schema is left alone.'
++  parameters
  ^-  (map @t parameter-def:tools)
  %-  ~(gas by *(map @t parameter-def:tools))
  :~  ['style' [%string 'the style, at most 1000 bytes']]
      ['preferences' [%array 'the standing preferences, at most 30 strings of at most 300 bytes each; this list replaces the one held']]
      ['by' [%string 'who is changing them (default "mcp")']]
  ==
++  required  *(list @t)
++  handler
  ^-  tool-handler:tools
  =/  m  (fiber:fiber:nexus ,tool-result:tools)
  ^-  form:m
  ;<  st=tool-state:tools  bind:m  (get-state-as:io ,tool-state:tools)
  ;<  schema=json  bind:m  (read-json:om / %'schema.json')
  =/  given=(map @t json)
    %-  ~(gas by *(map @t json))
    %+  murn  ~['style' 'preferences']
    |=  k=@t
    ^-  (unit [@t json])
    =/  v=(unit json)  (~(get by args.st) k)
    ?~(v ~ `[k u.v])
  ?:  =(~ given)  (pure:m (text:om (preferences-json:orr schema)))
  =/  req  (de-preferences:orr [%o given])
  ?:  ?=(%| -.req)  (pure:m (fail:om p.req))
  =/  who=@t  (fall (arg:om args.st 'by') 'mcp')
  ?:  (gth (met 3 who) max-by:orr)  (pure:m (fail:om 'by: over 64 bytes'))
  ;<  err=(unit tang)  bind:m
    (poke-writer:om [%o (~(gas by given) ~[['op' s+'set-preferences'] ['by' s+who]])])
  ?^  err  (pure:m (fail:om 'the writer refused the poke'))
  (pure:m (text:om (preferences-json:orr (with-preferences:orr schema style.p.req prefs.p.req))))
--
