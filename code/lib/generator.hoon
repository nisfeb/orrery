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
--
