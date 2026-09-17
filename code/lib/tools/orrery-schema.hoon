::  orrery-schema: read or replace schema.json, as GET and PUT /apps/orrery/api/schema
::
/<  tools  /lib/tools.hoon
/<  orr  /lib/orrery.hoon
/<  om  /lib/orrery-mcp.hoon
^-  tool:tools
|%
++  name  'orrery-schema'
++  description
  'Without arguments: the schema (the kinds and their attributes, which attributes are multi-valued). With schema: replace it whole.'
++  parameters
  ^-  (map @t parameter-def:tools)
  %-  ~(gas by *(map @t parameter-def:tools))
  :~  ['schema' [%object 'the whole schema document to store']]
  ==
++  required  *(list @t)
++  handler
  ^-  tool-handler:tools
  =/  m  (fiber:fiber:nexus ,tool-result:tools)
  ^-  form:m
  ;<  st=tool-state:tools  bind:m  (get-state-as:io ,tool-state:tools)
  =/  doc=json  (arg-json:om args.st 'schema')
  ?~  doc
    ;<  schema=json  bind:m  (read-json:om / %'schema.json')
    (pure:m (text:om schema))
  ?.  ?=([%o *] doc)  (pure:m (fail:om 'schema: expected an object'))
  ;<  err=(unit tang)  bind:m
    (poke-writer:om (pairs:enjs:format ~[['op' s+'set-schema'] ['doc' doc]]))
  ?^  err  (pure:m (fail:om 'the writer refused the poke'))
  (pure:m (text:om (pairs:enjs:format ~[['ok' b+&]])))
--
