::  generator: the on-ship action generator, the pure half. The prompt
::  from the state, the digest that says whether anything the model
::  would see has changed, the request and the answer as OpenRouter
::  speaks them, and the validator that keeps only what the schema and
::  the ship allow. orrery-utils/generator/run.py is the reference, arm
::  for arm; the nexus does the asking and the filing.
::
/+  orr=orrery
|%
++  nl  `@t`10
::  +winner-text: the current string value of an attribute, or ''
::
++  winner-text
  |=  [winners=(map @t (list row:orr)) name=@t]
  ^-  @t
  =/  w=(list row:orr)  (fall (~(get by winners) name) ~)
  ?~  w  ''
  ?:(?=([%s *] value.obs.i.w) p.value.obs.i.w '')
::  +phase: a situation's phase from its times: closed or cancelled when
::  status says so, over once its end has passed, under way once its
::  start has, upcoming while its start is ahead, else its status or open
::
++  phase
  |=  [winners=(map @t (list row:orr)) now=@da]
  ^-  @t
  =/  st=@t  (winner-text winners 'status')
  ?:  |(=('closed' st) =('cancelled' st))  st
  =/  end=@t  =/(e (winner-text winners 'ended') ?:(=('' e) (winner-text winners 'ends') e))
  =/  start=@t  =/(s (winner-text winners 'started') ?:(=('' s) (winner-text winners 'starts') s))
  =/  now-iso=@t  (en-iso:orr now)
  ?:  &(!=('' end) (lte-iso end now-iso))  'over'
  ?:  &(!=('' start) (lte-iso start now-iso))  'under way'
  ?:  !=('' start)  'upcoming'
  ?:(=('' st) 'open' st)
::  +lte-iso: ISO 8601 UTC strings of one shape compare as text
::
++  lte-iso  |=([a=@t b=@t] ^-(? !(gth-cord a b)))
++  gth-cord
  |=  [a=@t b=@t]
  ^-  ?
  =/  ta=tape  (trip a)
  =/  tb=tape  (trip b)
  |-
  ?~  ta  |
  ?~  tb  &
  ?:  =(i.ta i.tb)  $(ta t.ta, tb t.tb)
  (gth i.ta i.tb)
::  +norm-words: a title as lowercase words, punctuation gone
::
++  norm-words
  |=  t=@t
  ^-  (list @t)
  =/  low=tape  (cass (trip t))
  =/  clean=tape
    %+  turn  low
    |=(c=@ ?:(|(&((gte c 'a') (lte c 'z')) &((gte c '0') (lte c '9'))) c ' '))
  (turn (split-spaces clean) crip)
::  +split-spaces: the non-empty runs between spaces
::
++  split-spaces
  |=  t=tape
  ^-  (list tape)
  =|  cur=tape
  =|  out=(list tape)
  |-
  ?~  t  (flop ?:(=(~ cur) out [(flop cur) out]))
  ?:  =(' ' i.t)  $(t t.t, cur ~, out ?:(=(~ cur) out [(flop cur) out]))
  $(t t.t, cur [i.t cur])
::  +same-title: the same words, or four fifths of the shorter title's
::  words (at least two) in the longer
::
++  same-title
  |=  [a=@t b=@t]
  ^-  ?
  =/  ka=(set @t)  (sy (norm-words a))
  =/  kb=(set @t)  (sy (norm-words b))
  ?:  |(=(~ ka) =(~ kb))  |
  ?:  =(ka kb)  &
  =/  both=@ud  ~(wyt in (~(int in ka) kb))
  =/  short=@ud  (min ~(wyt in ka) ~(wyt in kb))
  (gte both (max 2 (div (mul 8 short) 10)))
::  the pieces of the user prompt and the count of decided actions shown
++  recent      60
++  max-bodies  300
::  +ref-or-text: a value as one token: a ref's id, a string, or its JSON
::
++  ref-or-text
  |=  v=json
  ^-  @t
  ?:  ?=([%o *] v)
    =/  r=(unit json)  (~(get by p.v) 'ref')
    ?:(?=([~ %s *] r) p.u.r (en:json:html v))
  ?:(?=([%s *] v) p.v (en:json:html v))
::  +join-cords: cords with a separator between
::
++  join-cords
  |=  [sep=@t xs=(list @t)]
  ^-  @t
  ?~  xs  ''
  (roll t.xs |=([x=@t acc=_i.xs] (rap 3 acc sep x ~)))
::  +squeeze: runs of whitespace as one space
::
++  squeeze
  |=  t=@t
  ^-  @t
  =/  flat=tape  (turn (trip t) |=(c=@ ?:(|(=(c 10) =(c 9) =(c 13)) ' ' c)))
  (crip (join-tapes " " (split-spaces flat)))
++  join-tapes
  |=  [sep=tape xs=(list tape)]
  ^-  tape
  ?~  xs  ""
  (roll t.xs |=([x=tape acc=_i.xs] (weld acc (weld sep x))))
::  +line: one body on one line: id | name (| phase for a situation) |
::  attr=value; ... with every attribute sorted, a multi as a list
::
++  line
  |=  [l=loaded:orr multi=(set @t) now=@da]
  ^-  @t
  =/  winners=(map @t (list row:orr))  (fold:orr rows.l multi now)
  =/  bits=(list @t)
    %+  murn  (sort ~(tap by winners) |=([[a=@t *] [b=@t *]] (aor a b)))
    |=  [k=@t w=(list row:orr)]
    ^-  (unit @t)
    ?~  w  ~
    ::  the head is tested on a copy: testing i.w narrows w into a
    ::  shape +turn will not take
    =/  first=row:orr  i.w
    ?:  ?=(~ value.obs.first)  ~
    =/  shown=@t
      ?.  (~(has in multi) k)  (ref-or-text value.obs.first)
      (join-cords ', ' (turn w |=(r=row:orr (ref-or-text value.obs.r))))
    `(rap 3 k '=' (end [3 120] (squeeze shown)) ~)
  =/  head=@t  (rap 3 id.l ' | ' name.body.l ~)
  =?  head  =(%situation kind.body.l)  (rap 3 head ' | ' (phase winners now) ~)
  ?~(bits head (rap 3 head ' | ' (join-cords '; ' bits) ~))
::  +build-parts: the five pieces, the least changing first and the
::  clock last, so the first four are the same text from one pass to the
::  next while nothing changed. decided are the done, dismissed and
::  failed actions, oldest first; the last +recent are shown.
::
++  build-parts
  |=  $:  all=(list loaded:orr)
          acts=(list [id=@ta a=action:orr])
          decided=(list [id=@ta a=action:orr])
          schema=json
          now=@da
          tz=@t
          limit=@ud
      ==
  ^-  (list @t)
  =/  multi=(set @t)  (multi-of:orr schema)
  =/  shown=(list loaded:orr)  (scag max-bodies all)
  =/  hidden=(set @t)
    %-  sy
    %+  murn  shown
    |=  l=loaded:orr
    ^-  (unit @t)
    ?.  =(%situation kind.body.l)  ~
    =/  ph=@t  (phase (fold:orr rows.l multi now) now)
    ?:(|(=('closed' ph) =('cancelled' ph) =('over' ph)) `id.l ~)
  =/  section
    |=  kinds=(list @tas)
    ^-  (list @t)
    %-  zing
    %+  turn  kinds
    |=  k=@tas
    ^-  (list @t)
    =/  rows=(list loaded:orr)
      (skim shown |=(l=loaded:orr &(=(k kind.body.l) !(~(has in hidden) id.l))))
    ?~  rows  ~
    :-  (cat 3 ?:(=(%activity k) 'activities' (cat 3 k 's')) ':')
    (turn rows |=(l=loaded:orr (cat 3 '  ' (line l multi now))))
  =/  kinds-line=@t
    =/  a=(list @t)  (strings:orr (ga:orr schema 'actions'))
    (cat 3 'Action kinds: ' (join-cords ', ' ?~(a ~['task' 'note'] a)))
  =/  head=(list @t)
    :~  (rap 3 'The owner is person/me. Propose at most ' (scot %ud limit) ' actions.' ~)
        kinds-line
    ==
  =/  payloads=json  (gj:orr schema 'payloads')
  =?  head  ?=([%o *] payloads)
    %+  weld  head
    :-  'Payload shapes:'
    %+  turn  ~(tap by p.payloads)
    |=([k=@t v=json] (rap 3 '  ' k ': ' (en:json:html v) ~))
  =/  p0=@t  (join-cords nl (weld head (section ~[%thing %place %org %note])))
  =/  p1=@t  (join-cords nl (section ~[%person %activity]))
  =/  p2=@t  (join-cords nl (section ~[%situation]))
  =/  open=(list @t)
    :-  'Open actions (proposed or approved, do not duplicate):'
    %+  murn  acts
    |=  [id=@ta a=action:orr]
    ^-  (unit @t)
    ?.  (is-open:orr a)  ~
    `(rap 3 '  ' kind.a ' | ' title.a ' | about ' (join-cords ', ' ~(tap in about.a)) ~)
  =/  done=(list @t)
    :-  'Recent decisions (do not propose these again):'
    %+  turn  (slag (sub (lent decided) (min recent (lent decided))) decided)
    |=([id=@ta a=action:orr] (rap 3 '  ' status.a ' | ' kind.a ' | ' title.a ~))
  =/  p3=@t  (join-cords nl (weld open done))
  =/  p4=@t
    (rap 3 'Now: ' (en-iso:orr now) ', timezone ' ?:(=('' tz) 'unknown' tz) '. Answer with the JSON object.' ~)
  ~[p0 p1 p2 p3 p4]
::  +digest: a hash of everything but the clock
::
++  digest
  |=  parts=(list @t)
  ^-  @ux
  `@ux`(sham (join-cords nl (scag 4 parts)))
::  +$  config: generator.json as the nexus reads it. Off until the owner
::  turns it on and gives a key. The key is read here and nowhere else.
::
+$  config
  $:  enabled=?
      url=@t
      model=@t
      api-key=@t
      reasoning=json
      max-tokens=@ud
      max-actions=@ud
      timezone=@t
  ==
++  de-config
  |=  j=json
  ^-  config
  :*  =/(e (gj:orr j 'enabled') ?:(?=([%b *] e) p.e |))
      =/(u (gs:orr j 'url') ?:(=('' u) 'https://openrouter.ai/api/v1' u))
      =/(m (gs:orr j 'model') ?:(=('' m) 'moonshotai/kimi-k3' m))
      (gs:orr j 'api_key')
      =/(r (gj:orr j 'reasoning') ?:(?=(~ r) [%o (my ~[['effort' s+'high']])] r))
      (fall (gn:orr j 'max_tokens') 8.000)
      (fall (gn:orr j 'max_actions') 5)
      (gs:orr j 'timezone')
  ==
::  +en-config-masked: what the owner reads back: everything but the key
::
++  en-config-masked
  |=  c=config
  ^-  json
  %-  pairs:enjs:format
  :~  ['enabled' b+enabled.c]
      ['url' s+url.c]
      ['model' s+model.c]
      ['api_key_set' b+!=('' api-key.c)]
      ['reasoning' reasoning.c]
      ['max_tokens' (numb:enjs:format max-tokens.c)]
      ['max_actions' (numb:enjs:format max-actions.c)]
      ['timezone' s+timezone.c]
  ==
::  +reasoning-on: any reasoning object but {"enabled": false}
::
++  reasoning-on
  |=  r=json
  ^-  ?
  ?.  ?=([%o *] r)  |
  !?=([~ %b %.n] (~(get by p.r) 'enabled'))
::  +block: one content block, with a cache mark when asked
::
++  block
  |=  [t=@t marked=?]
  ^-  json
  =/  base=(list [@t json])  ~[['type' s+'text'] ['text' s+t]]
  =/  mark=(list [@t json])  ~[['cache_control' [%o (my ~[['type' s+'ephemeral']])]]]
  [%o (~(gas by *(map @t json)) ?:(marked (weld base mark) base))]
::  +chat-body: the request. Every piece of the user prompt is a content
::  block; the system block and the first three user blocks carry a
::  cache mark, so a call minutes after another reads every piece up to
::  the first changed one from the cache. No temperature when the model
::  reasons; the router reports the cost with the usage.
::
++  chat-body
  |=  [c=config parts=(list @t)]
  ^-  json
  =/  blocks=(list json)
    =/  n=@ud  0
    |-
    ?~  parts  ~
    [(block i.parts (lth n 3)) $(parts t.parts, n +(n))]
  =/  on=?  (reasoning-on reasoning.c)
  =/  system=json  [%o (my ~[['role' s+'system'] ['content' a+~[(block system-prompt &)]]])]
  =/  user=json  [%o (my ~[['role' s+'user'] ['content' a+blocks]])]
  %-  pairs:enjs:format
  %-  zing
  :~  :~  ['model' s+model.c]
          ['max_tokens' (numb:enjs:format max-tokens.c)]
          ['messages' a+~[system user]]
          ['provider' [%o (my ~[['zdr' b+&]])]]
          ['usage' [%o (my ~[['include' b+&]])]]
      ==
      ?:(on ~[['reasoning' reasoning.c]] ~[['temperature' (numb:enjs:format 0)]])
  ==
::  +answer-of: the model's text and the usage out of a chat completion,
::  or why there is none
::
++  answer-of
  |=  resp=json
  ^-  (each [text=@t usage=json] @t)
  =/  choices=(list json)  (ga:orr resp 'choices')
  ?~  choices
    =/  err=@t  (gs:orr (gj:orr resp 'error') 'message')
    [%| ?:(=('' err) 'the model answered without choices' err)]
  =/  content=@t  (gs:orr (gj:orr i.choices 'message') 'content')
  ?:  =('' content)
    :-  %|
    ?:  =('length' (gs:orr i.choices 'finish_reason'))
      'the model ran out of tokens before answering'
    'the model answered without content'
  [%& content (gj:orr resp 'usage')]
::  +parse-answer: the first JSON object in the text, fences and chatter
::  ignored: from the first brace, shortening the tail until it parses
::
++  parse-answer
  |=  text=@t
  ^-  (unit json)
  =/  t=tape  (trip text)
  =/  start=(unit @ud)  (find "\{" t)
  ?~  start  ~
  =/  from=tape  (slag u.start t)
  =/  end=@ud  (lent from)
  |-
  ?:  =(0 end)  ~
  ?.  =('}' (snag (dec end) from))  $(end (dec end))
  =/  got=(unit json)  (de:json:html (crip (scag end from)))
  ?^  got  got
  $(end (dec end))
::  +system-prompt: orrery-utils/common/generator-prompt.md, verbatim
::
++  system-prompt
  ^-  @t
  '''
  You are the analyst for orrery, a model of one person's world kept on their own ship. You read the state and propose what should be done about it. You never write facts; other clients do that. You propose actions, and the owner approves or dismisses each one.

  What you are given.
  The state: every body with its current attributes (people with status, location and relationships; things; places; orgs; situations with their times and participants; activities with their schedule, last and next occurrence), the open situations, the open actions, and the schema with its notes and the payload shapes for each action kind.
  The recent decisions: actions done, dismissed or failed lately, with their titles. Do not propose these again, or a rewording of them. A dismissal is the owner saying no.
  The time now, and the owner's timezone.

  What to propose.
  Only what the owner would want done and has not done: a call to make, a thing to buy or bring, a message to send someone, a reminder ahead of a deadline, a preparation for something upcoming, a follow-up on something that stalled. An open situation with nothing being done about it, an activity whose next occurrence needs something, a person whose status calls for a reply, a delivery that never arrived.
  Few and good. Zero is a fine answer. Never propose more than the limit given.
  An action's kind is one of the kinds the schema lists. Its payload follows the shape the schema gives for that kind, exactly; a message names who it is for as a body id and says what to send in the owner's own voice, short; a home action names a Home Assistant service and entity. A task needs only a title and, when there is one, a due time.
  "about" names the bodies the action concerns, by id, at most a few. "due" is ISO 8601 UTC, only when the timing matters.
  Respect what the facts say about time: an occurrence in the past is over; a situation that is upcoming has not happened; "last" is the most recent occurrence and "next" the nearest one ahead.
  Do not invent facts, people, places or events. Do not propose things the owner cannot act on. Do not moralise.

  Answer with one JSON object and nothing else:
  {"actions": [{"kind": "task", "title": "...", "about": ["kind/slug"], "due": "...", "payload": {...}, "why": "one sentence"}],
   "notes": ["anything you noticed that is not an action: a fact that looks wrong, a duplicate, a missing piece"]}
  "why" is for the owner's eyes on the page; keep it to one sentence. Notes are optional and short.
  '''
::  +cass-cord: a cord lowercased
::
++  cass-cord  |=(t=@t ^-(@t (crip (cass (trip t)))))
::  +validate: what the answer keeps. A kind the schema lists (task and
::  note when it lists none), a title, not a rewording of anything open
::  or decided, every about body known, every required payload key
::  present, a due that parses, the why in the payload for the page; at
::  most limit, looking at twice that. Notes name what was dropped and
::  carry the model's own notes. Each kept action is the JSON an act op
::  takes, before fill-act-as stamps proposed and by.
::
++  validate
  |=  [answer=json known=(set @t) taken=(list @t) schema=json limit=@ud]
  ^-  [acts=(list json) notes=(list @t)]
  =/  kinds=(set @t)
    =/  a=(list @t)  (strings:orr (ga:orr schema 'actions'))
    (sy ?~(a ~['task' 'note'] a))
  =/  payloads=json  (gj:orr schema 'payloads')
  =/  todo=(list json)  (scag (mul 2 limit) (ga:orr answer 'actions'))
  =/  said=(list @t)
    %+  turn  (scag 10 (ga:orr answer 'notes'))
    |=(n=json (cat 3 'model note: ' (end [3 200] (ref-or-text n))))
  =|  acts=(list json)
  =|  notes=(list @t)
  |-
  ?:  |(?=(~ todo) (gte (lent acts) limit))
    [(flop acts) (weld (flop notes) said)]
  =/  a=json  i.todo
  ?.  ?=([%o *] a)  $(todo t.todo)
  =/  kind=@t  =/(k (cass-cord (gs:orr a 'kind')) ?:(=('' k) 'task' k))
  =/  title=@t  (end [3 200] (gs:orr a 'title'))
  ?:  |(!(~(has in kinds) kind) =('' title))
    $(todo t.todo, notes [(rap 3 'dropped: kind ' kind ' or no title (' (end [3 40] title) ')' ~) notes])
  ?:  (lien taken |=(t=@t (same-title title t)))
    $(todo t.todo, notes [(cat 3 'dropped as already open or decided: ' title) notes])
  =/  about=(list @t)  (turn (strings:orr (ga:orr a 'about')) cass-cord)
  =/  bad=(list @t)  (skip about |=(b=@t (~(has in known) b)))
  ?^  bad
    $(todo t.todo, notes [(rap 3 'dropped ' title ': names bodies that do not exist: ' (join-cords ', ' bad) ~) notes])
  =/  payload=(map @t json)
    =/  p=json  (gj:orr a 'payload')
    ?:(?=([%o *] p) p.p ~)
  =/  shape=json  (gj:orr payloads kind)
  =/  missing=(list @t)
    ?.  ?=([%o *] shape)  ~
    %+  murn  ~(tap by p.shape)
    |=  [k=@t v=json]
    ^-  (unit @t)
    ?.  ?=([%s *] v)  ~
    ?.  =('required' (end [3 8] p.v))  ~
    ?:((~(has by payload) k) ~ `k)
  ?^  missing
    $(todo t.todo, notes [(rap 3 'dropped ' title ': payload lacks ' (join-cords ', ' missing) ~) notes])
  =/  why=@t  (end [3 300] (gs:orr a 'why'))
  =?  payload  !=('' why)  (~(put by payload) 'why' s+why)
  =/  due=(unit @da)  (de-iso:orr (gs:orr a 'due'))
  =/  row=json
    %-  pairs:enjs:format
    %-  zing
    :~  :~  ['kind' s+kind]
            ['title' s+title]
            ['about' a+(turn (scag 20 about) |=(b=@t `json`s+b))]
            ['payload' [%o payload]]
        ==
        ?~(due ~ ~[['due' (en-time:orr u.due)]])
    ==
  $(todo t.todo, acts [row acts], taken [title taken])
--
