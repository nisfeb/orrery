::  orrery: a model of the user's world. docs/superpowers/specs/2026-09-16-orrery-design.md
::
::  The tree this nexus owns (every persistent path has a row in +on-load):
::    /main.sig                        the writer: every mutation goes through it
::    /web.sig                         binds /apps/orrery; one fiber per request
::    /requests/<id>                   the ephemeral request fibers
::    /bodies/<kind>/<slug>/body       [/orrery %body]
::    /bodies/<kind>/<slug>/obs/<oid>  [/orrery %obs]
::    /actions/<aid>                   [/orrery %action]
::    /schema.json  /policy.json       seeded once; edits survive a reload
::    /beacon/rev                      the change beacon, nested so it streams
::    /tr/last                         the last writer outcome, as json
::    /tr/log                          the audit ring, the last 500 ops
::    /tr/inbox                        ship traffic, its own ring of 500
::    /shares.json                     what we share out, by body id
::    /shares.sig                      the inbox other ships poke
::    /share-offers.json               what was offered to us
::    /ship-remotes.json               what we accepted, a row per share
::    /sync.sig                        the follower: pull, then push
::    /clients.json                    the minted keys, salted hashes only
::    /telegram.sig                    the telegram reader: drains the inbox
::    /telegram-inbox/<update_id>      an update the webhook took, until read
::    /exec.sig                        the executor: approved actions carried out, the todo list kept in step
::    /exec-last.json                  what its last pass did
::    /refining/<aid>                  the lock a refine request holds on its action
::    the page and the manifests       laid fresh on every load, not %fall
::
::  ROADS ARE NEXUS-RELATIVE. A desk-installed app cannot learn its own
::  absolute path, so every road is [%| up lane], where up is the number
::  of steps from the calling fiber to the nexus root: 0 for the writer
::  and the binder, 1 for a request fiber at /requests/<id>.
::
::  THE WRITER MUST NOT CRASH. +rise-wait restarts a failed process by
::  consuming the next poke without processing it, so every refusal is a
::  branch that returns cleanly and writes /tr/last.
::
/<  orr   /lib/orrery.hoon
/<  om    /lib/orrery-mcp.hoon
/&  icon  icon.svg
/&  page-html  orrery.html
/&  page-css   orrery.css
/&  page-js    orrery.js
=<  ^-  nexus:nexus
    |%
    ++  on-load
      |=  =ball:tarball
      ^-  bole:tarball
      =/  tile=json
        %-  pairs:enjs:format
        :~  title+s+'Orrery'
            info+s+'What is going on in your world'
            color+s+'#101541'
            image+s+'/grubbery/tiles/icon/orrery'
            href+s+'/apps/orrery'
        ==
      =/  link=json
        (pairs:enjs:format ~[['name' s+'orrery'] ['description' s+'A model of your world']])
      %+  spin:loader  ball
      :~  (manifest:loader 0)
          [%over %& [/ %'tile.json'] [[/ %json] tile]]
          [%over %& [/ %'link.json'] [[/ %json] link]]
          [%over %& [/ %'weir.json'] [[/ %json] weir-json]]
          [%over %& [/ %'icon.svg'] [[/ %mime] icon]]
          [%over %& [/ %'orrery.html'] [[/ %mime] page-html]]
          [%over %& [/ %'orrery.css'] [[/ %mime] page-css]]
          [%over %& [/ %'orrery.js'] [[/ %mime] page-js]]
          [%fall %& [/ %'main.sig'] [[/ %sig] ~]]
          [%fall %& [/ %'web.sig'] [[/ %sig] ~]]
          [%fall %| /requests empty-dir:loader]
          [%fall %| /bodies empty-dir:loader]
          [%fall %| /actions empty-dir:loader]
          [%fall %| /tr empty-dir:loader]
          [%fall %| /beacon empty-dir:loader]
          [%fall %& [/ %'schema.json'] [[/ %json] starter-schema:orr]]
          [%fall %& [/ %'policy.json'] [[/ %json] starter-policy:orr]]
          [%fall %& [/beacon %rev] [[/ %json] (numb:enjs:format 0)]]
          [%fall %& [/tr %last] [[/ %json] [%o ~]]]
          [%fall %& [/tr %log] [[/ %json] [%a ~]]]
          [%fall %& [/tr %inbox] [[/ %json] [%a ~]]]
          ::  sharing (spec section 11). shares.json: body id to the ships
          ::  it is shared with and the mode. shares.sig: the inbox other
          ::  ships poke offers, revokes and edits into. share-offers.json:
          ::  what was offered to us. ship-remotes.json: what we accepted.
          ::  sync.sig: the follower that pulls and pushes.
          [%fall %& [/ %'shares.json'] [[/ %json] [%o ~]]]
          [%fall %& [/ %'shares.sig'] [[/ %sig] ~]]
          [%fall %& [/ %'share-offers.json'] [[/ %json] [%o ~]]]
          [%fall %& [/ %'ship-remotes.json'] [[/ %json] [%o ~]]]
          [%fall %& [/ %'sync.sig'] [[/ %sig] ~]]
          ::  clients.json: the minted keys, each a salted hash of its
          ::  secret with a name, an identity and a scope (spec section 11,
          ::  phase 3)
          [%fall %& [/ %'clients.json'] [[/ %json] [%o ~]]]
          ::  the on-ship generator: its settings (the key lives here and
          ::  is never served) and what its last pass did
          [%fall %& [/ %'generator.json'] [[/ %json] [%o (my ~[['enabled' b+|]])]]]
          [%fall %& [/ %'generator-last.json'] [[/ %json] [%o ~]]]
          [%fall %& [/ %'gen.sig'] [[/ %sig] ~]]
          ::  reconcile: the passes of orrery-utils' reconcile.py on the
          ::  ship, twice a day; what the last run did
          [%fall %& [/ %'reconcile.sig'] [[/ %sig] ~]]
          [%fall %& [/ %'reconcile-last.json'] [[/ %json] [%o ~]]]
          ::  the telegram reader (version 29): settings with the bot token
          ::  and webhook secret, never served; the context window, the
          ::  last update handled, the business connections checked, and
          ::  the inbox the webhook writes into
          [%fall %& [/ %'telegram.json'] [[/ %json] [%o (my ~[['enabled' b+|]])]]]
          [%fall %& [/ %'telegram-recent.json'] [[/ %json] [%o ~]]]
          [%fall %& [/ %'telegram-last.json'] [[/ %json] [%o ~]]]
          [%fall %& [/ %'telegram-connections.json'] [[/ %json] [%o ~]]]
          [%fall %| /telegram-inbox empty-dir:loader]
          [%fall %& [/telegram-inbox %rev] [[/ %json] (numb:enjs:format 0)]]
          [%fall %& [/ %'telegram.sig'] [[/ %sig] ~]]
          ::  the executor (version 34): the fiber that carries out the
          ::  approved actions the ship can serve and keeps the calendar's
          ::  todo list in step, and what its last pass did
          [%fall %& [/ %'exec.sig'] [[/ %sig] ~]]
          [%fall %& [/ %'exec-last.json'] [[/ %json] [%o ~]]]
          ::  the chat reader (version 39): its settings, its record, the
          ::  ids it has read, its window, and the fiber that polls
          [%fall %& [/ %'chat.json'] [[/ %json] [%o (my ~[['enabled' b+|]])]]]
          [%fall %& [/ %'chat-last.json'] [[/ %json] [%o ~]]]
          [%fall %& [/ %'chat-seen.json'] [[/ %json] [%a ~]]]
          [%fall %& [/ %'chat-recent.json'] [[/ %json] [%o ~]]]
          [%fall %& [/ %'chat.sig'] [[/ %sig] ~]]
          ::  refine (version 36): one lock grub per action being refined
          [%fall %| /refining empty-dir:loader]
      ==
    ::
    ++  on-file
      |=  [=rail:tarball =blot:tarball]
      ^-  spool:fiber:nexus
      |=  =prod:fiber:nexus
      =/  m  (fiber:fiber:nexus ,~)
      ^-  process:fiber:nexus
      ?+    rail  stay:m
          ::  the writer. It reaches nothing at rise: a jailed install
          ::  (weir not yet approved) would have every bowl poke vetoed,
          ::  and a crashed writer waits for the next poke before it
          ::  runs again. person/me is laid by the first request instead.
          [~ %'main.sig']
        ;<  ~  bind:m  (rise-wait:io prod "%orrery writer: failed")
        |-
        ;<  [=from:fiber:nexus =sage:tarball]  bind:m  take-poke-from:io
        ;<  changed=?  bind:m  (apply from sage)
        ::  the beacon is also how the generator hears of the change: the
        ::  writer never pokes it, since a soft poke waits for its
        ::  consumption and the generator pokes the writer back, and the
        ::  two waited on each other for ever (2026-09-19, a pass filing
        ::  two proposals)
        ;<  ~  bind:m  ?.(changed (pure:m ~) bump-beacon)
        $
          ::  the HTTP binder. bind-http-self is veto-tolerant: jailed,
          ::  it logs and waits; the approval reload binds for real.
          [~ %'web.sig']
        ;<  ~  bind:m  (rise-wait:io prod "%orrery web: failed")
        ;<  ~  bind:m  (bind-http-self:io [~ /apps/orrery])
        (http-dispatch:io %orrery)
          ::  the inbox: other ships poke offers, revokes, and observations
          ::  on bodies shared with them in edit mode. The sender is the
          ::  transport's; the payload is data; nothing reaches the writer
          ::  without by and source rewritten here. A local poke is ignored.
          [~ %'shares.sig']
        ;<  ~  bind:m  (rise-wait:io prod "%orrery inbox: failed")
        ::  the road any ship pokes is laid from here: the registry keys a
        ::  grant to the poking fiber's own rail and scopes it to that
        ::  fiber's directory, so only a fiber at the root can grant a
        ::  road at the root. A request fiber's grant is refused.
        ;<  ~  bind:m  lay-inbox-road
        |-
        ;<  [=from:fiber:nexus =sage:tarball]  bind:m  take-poke-from:io
        =/  src=(unit @p)  (get-poke-src:io from)
        ;<  our=@p  bind:m  get-our:io
        ;<  ~  bind:m
          ?:  |(?=(~ src) =(our (fall src our)))  (pure:m ~)
          (take-inbox (fall src our) sage)
        $
          ::  the follower: every five minutes, and whenever prodded (an
          ::  accept, a sync request), pull every body another ship shared
          ::  with us and push our own observations back on the ones shared
          ::  in edit mode. A grant approved after the rise lands the inbox
          ::  road here too.
          [~ %'sync.sig']
        ;<  ~  bind:m  (rise-wait:io prod "%orrery sync: failed")
        |-
        ;<  ~  bind:m  lay-inbox-road
        ;<  ~  bind:m  sync-pass
        ;<  now=@da  bind:m  get-time:io
        ;<  ~  bind:m  (set-timer:io /tick (add now ~m5))
        ;<  *  bind:m  take-poke-from:io
        ;<  ~  bind:m  (cancel-timer:io /tick)
        $
          ::  the generator: woken by the beacon after a change, by a
          ::  cooldown timer, and by POST /api/generate. It settles for
          ::  twenty seconds so a burst of writes is one pass, then runs
          ::  one; a pass is skipped while the prompt it would send is the
          ::  one it sent last. Nothing here writes model state: proposals
          ::  go to the writer as act ops. It is never poked by the writer.
          [~ %'gen.sig']
        ;<  ~  bind:m  (rise-wait:io prod "%orrery generator: failed")
        ;<  *  bind:m  (keep:io /gen (rf 0 /beacon %rev) ~)
        |-
        ;<  in=gen-in  bind:m  (take-gen-in /gen)
        ::  a settle timer that fired after its pass began is not a wake;
        ::  a cooldown timer is one, the pass the limits held back
        ?:  &(?=(%wake -.in) !?=([%cooldown *] path.in))  $
        =/  force=?  ?:(?=(%poke -.in) (force-of sage.in) |)
        =/  urgent=(unit (list @t))  ?:(?=(%poke -.in) (urgent-of sage.in) ~)
        ::  off, and not forced: no settle, so a burst of writes drains
        ::  at once instead of twenty seconds a pair
        ;<  cfg-json=json  bind:m  (read-json (rf 0 / %'generator.json'))
        ?.  |(force enabled:(de-config:orr cfg-json))  $
        ;<  now=@da  bind:m  get-time:io
        ;<  ~  bind:m  (set-timer:io /settle (add now ~s20))
        ::  whatever ends the settle: the timer, more news, or a run-now,
        ::  which keeps its force
        ;<  second=gen-in  bind:m  (take-gen-in /gen)
        ;<  ~  bind:m  (cancel-timer:io /settle)
        =/  forced=?  |(force ?:(?=(%poke -.second) (force-of sage.second) |))
        =/  urg=(unit (list @t))
          ?^  urgent  urgent
          ?:(?=(%poke -.second) (urgent-of sage.second) ~)
        ;<  again=(unit @da)  bind:m  (gen-pass forced urg)
        ::  held by a limit: wake when it lifts, so the changes made
        ::  meanwhile become one pass then
        ;<  ~  bind:m  ?~(again (pure:m ~) (set-timer:io /cooldown u.again))
        $
          ::  reconcile: at rise, twice a day, and on POST /api/reconcile,
          ::  the passes of orrery-utils' reconcile.py (times, activities,
          ::  participants, people, the approved merges, retire, prune),
          ::  moved on-ship 2026-09-20. Nothing here writes: every change
          ::  goes to the writer as an op. It is never poked by the writer.
          [~ %'reconcile.sig']
        ;<  ~  bind:m  (rise-wait:io prod "%orrery reconcile: failed")
        ;<  *  bind:m  (keep:io /rec (rf 0 /beacon %rev) ~)
        |-
        ;<  ~  bind:m  reconcile-pass
        ;<  now=@da  bind:m  get-time:io
        ;<  ~  bind:m  (set-timer:io /tick (add now ~h12))
        ;<  *  bind:m  take-poke-from:io
        ;<  ~  bind:m  (cancel-timer:io /tick)
        $
          ::  the telegram reader (version 29): wakes on the inbox, drains
          ::  it in update order, runs the bot's pipeline for each and
          ::  files the facts through the writer. It is never poked by
          ::  the writer; an urgent message pokes the generator. The
          ::  owner's wake route pokes it, and a retry timer wakes it
          ::  when the model could not read an update.
          [~ %'telegram.sig']
        ;<  ~  bind:m  (rise-wait:io prod "%orrery telegram: failed")
        ;<  *  bind:m  (keep:io /tg (rf 0 /telegram-inbox %rev) ~)
        |-
        ;<  ~  bind:m  tg-drain
        ;<  *  bind:m  (take-gen-in /tg)
        $
          ::  the chat reader (version 39): every poll_minutes, the writs
          ::  and posts changed since the last pass, read through Tlon's
          ::  own JSON, each through the reader's pipeline. Nothing pokes
          ::  it but the owner's wake, which runs a pass at once.
          [~ %'chat.sig']
        ;<  ~  bind:m  (rise-wait:io prod "%orrery chat: failed")
        |-
        ;<  poll=@ud  bind:m  chat-pass
        ;<  now=@da  bind:m  get-time:io
        ;<  ~  bind:m  (cancel-timer:io /poll)
        ;<  ~  bind:m  (set-timer:io /poll (add now (mul (max 1 poll) ~m1)))
        ;<  *  bind:m  (take-gen-in /chat)
        $
          ::  the executor (version 34): on orrery's beacon it carries out
          ::  the approved actions it can serve; on the calendar's store it
          ::  keeps the todo list and the task actions in step. It pokes
          ::  the writer, the calendar and auspex, and is poked by nothing
          ::  but the owner's wake. The calendar is found through link on
          ::  every pass, so one installed after the rise is kept from the
          ::  pass that first finds it, with no restart. A %fell on /cal is
          ::  not consumed, so a calendar removed and installed again is
          ::  kept again only once the fiber restarts: a wake, the owner's
          ::  wake route included, restarts the loop's wait, not the keep.
          [~ %'exec.sig']
        ;<  ~  bind:m  (rise-wait:io prod "%orrery executor: failed")
        ;<  *  bind:m  (keep:io /exec (rf 0 /beacon %rev) ~)
        =/  kept=?  |
        =/  seen=(unit exec-seen)  ~
        |-
        ;<  k=?  bind:m  ?:(kept (pure:(fiber:fiber:nexus ,?) &) keep-calendar)
        ;<  [s=(unit exec-seen) busy=?]  bind:m  (exec-run seen)
        ::  a pass that moved something runs again at once: the settles
        ::  inside it took the beacon's news, so an approval made while
        ::  it ran would otherwise wait for the next wake
        ?:  busy  $(kept k, seen s)
        ;<  *  bind:m  take-exec-in
        $(kept k, seen s)
          ::  one ephemeral fiber per in-flight request
          [[%requests ~] @]
        ;<  ~  bind:m  (rise-wait:io prod "%orrery request: failed")
        (handle-request name.rail)
      ==
    --
|%
::  ==  roads
::
++  rf  |=([up=@ud p=path n=@ta] ^-(road:tarball [%| up [%& p n]]))
++  rv  |=([up=@ud p=path] ^-(road:tarball [%| up [%| p]]))
++  body-dir  |=([kind=@tas slug=@ta] ^-(path /bodies/[kind]/[slug]))
++  obs-dir   |=([kind=@tas slug=@ta] ^-(path /bodies/[kind]/[slug]/obs))
++  srv  ~(. http-res:io [%| 1 %& ~ %'web.sig'])
::  ==  the ask
::
++  weir-json
  ^-  json
  =/  line  |=([r=@t w=@t] `json`(pairs:enjs:format ~[['road' s+r] ['why' s+w]]))
  %-  pairs:enjs:format
  :~  :-  'poke'
      :-  %a
      :~  (line '/sys/bowl.sig' 'read the current time and our ship')
          (line '/sys/eyre/' 'bind /apps/orrery and answer requests')
          (line '/sys/push/' 'notify you when the assistant proposes or files an action. Refuse this and proposals wait silently in the inbox')
          (line '/sys/gall/' 'tell another ship you shared a body with it, revoke that, and send it your observations on a body it shared with you in edit mode. Refuse this and sharing with ships is unavailable; everything else works')
          (line '/sys/behn/' 'the follower ticks every five minutes to pull what other ships shared with you, and a message to another ship gives up after thirty seconds. Refuse this and sharing with ships is unavailable')
          (line '/sys/ames/registry' 'let other ships poke your inbox with an offer, a revoke, or edits on a body you shared with them. Refuse this and sharing with ships is unavailable')
          (line '/sys/iris/' 'ask a model over HTTPS when the state changes, so it can propose actions. Refuse this and the on-ship generator is off; orrery-utils can still run it from a computer')
          (line '/sys/scry/' 'read your Tlon messages, the DMs and the group channels you pick, so what people tell you on Urbit becomes facts the ship knows. Refuse this and the ship reads no chat')
          (line '/apps/shell.shell/desks/calendar.desk/' 'put an approved calendar action on your calendar, an approved task in its todo list, and keep the two in step. Refuse this and those actions wait for another executor')
          (line '/apps/shell.shell/desks/auspex.desk/' 'send an approved message by mail. Refuse this and mail actions wait for another executor')
      ==
      :-  'peek'
      :-  %a
      :~  (line '/sys/link/' 'find where this app is installed, so the page can address its own writer and an offer can say where to read')
          (line '/sys/ames/usergroups/' 'read a share group before rewriting it')
          (line '/sys/ames/ships/' 'read a body another ship shared with you, and keep it current. Refuse this and bodies shared with you are unavailable')
          (line '/apps/shell.shell/desks/calendar.desk/' 'read your todo list, so a todo you tick or type is a task the ship knows')
      ==
      :-  'make'
      :-  %a
      :~  (line '/sys/ames/usergroups/' 'make and rewrite the group for a shared body: the ships that may read it')
      ==
  ==
::  ==  the writer
::
::  +apply: one op from a poke. Answers whether the tree changed.
::
++  apply
  |=  [=from:fiber:nexus =sage:tarball]
  =/  m  (fiber:fiber:nexus ,?)
  ^-  form:m
  ?.  =([/ %json] p.sage)  (pure:m |)
  ;<  our=@p  bind:m  get-our:io
  ::  +get-poke-src reads the ship off the transport. ~ is a fiber
  ::  inside this nexus; our own ship arrives named through the
  ::  agent-facing surface. Anything else is refused.
  =/  src=(unit @p)  (get-poke-src:io from)
  ?.  ?|(?=(~ src) =(our u.src))
    (refuse 'poke' 'a foreign ship may not write here')
  =/  jon=json  (fall (mole |.(!<(json q.sage))) ~)
  =/  op=@t  (gs:orr jon 'op')
  ?:  =('ensure-me' op)  ensure-me
  ?:  =('observe' op)  (do-observe jon)
  ?:  =('upsert-body' op)  (do-upsert-body jon)
  ?:  =('delete-body' op)  (do-delete-body jon)
  ?:  =('merge' op)  (do-merge jon)
  ?:  =('retract' op)  (do-retract jon)
  ?:  =('act' op)  (do-act jon)
  ?:  =('set-action' op)  (do-set-action jon)
  ?:  =('revise-action' op)  (do-revise-action jon)
  ?:  =('set-schema' op)  (do-set-doc %'schema.json' 'set-schema' jon)
  ?:  =('set-policy' op)  (do-set-doc %'policy.json' 'set-policy' jon)
  ?:  =('set-generator' op)  (do-set-generator jon)
  ?:  =('set-telegram' op)  (do-set-telegram jon)
  ?:  =('set-chat' op)  (do-set-chat jon)
  ?:  =('add-client' op)  (do-add-client jon)
  ?:  =('drop-client' op)  (do-drop-client jon)
  ?:  =('touch-client' op)  (do-touch-client jon)
  (refuse op 'unknown op')
::  +refuse: a refusal that leaves the writer standing
::
++  refuse
  |=  [op=@t why=@t]
  =/  m  (fiber:fiber:nexus ,?)
  ^-  form:m
  ;<  ~  bind:m  (note op | why)
  (pure:m |)
::  +note-then-no: a no-op that still leaves its reason in /tr/last
::
++  note-then-no
  |=  [op=@t why=@t]
  =/  m  (fiber:fiber:nexus ,?)
  ^-  form:m
  ;<  ~  bind:m  (note op & why)
  (pure:m |)
::  +trail-entry: one audit row. Both rings carry the same five pairs,
::  so they are built in one place.
::
++  trail-entry
  |=  [op=@t ok=? why=@t by=@t now=@da]
  ^-  json
  %-  pairs:enjs:format
  ~[['op' s+op] ['ok' b+ok] ['why' s+why] ['by' s+by] ['at' (en-time:orr now)]]
::  +note: the last writer outcome at /tr/last, and the audit ring at
::  /tr/log (the last 500). Fiber prints reach only the raw console; a
::  grub is readable by every tool.
::
++  note
  |=  [op=@t ok=? why=@t]
  =/  m  (fiber:fiber:nexus ,~)
  ^-  form:m
  (note-by op ok why '')
::  +note-by: the same outcome with the actor who caused it named
::
++  note-by
  |=  [op=@t ok=? why=@t by=@t]
  =/  m  (fiber:fiber:nexus ,~)
  ^-  form:m
  ;<  now=@da  bind:m  get-time:io
  =/  entry=json  (trail-entry op ok why by now)
  ;<  ~  bind:m  (over:io (rf 0 /tr %last) [[/ %json] entry])
  ;<  log=json  bind:m  (read-json (rf 0 /tr %log))
  (over:io (rf 0 /tr %log) [[/ %json] (ring:orr log entry 500)])
::  +note-inbox: an outcome of ship traffic, in its own ring (500), so a
::  stranger's pokes never evict the owner's audit log or /tr/last
::
++  note-inbox
  |=  [op=@t ok=? why=@t by=@t]
  =/  m  (fiber:fiber:nexus ,~)
  ^-  form:m
  (note-inbox-at 0 op ok why by)
::  +note-inbox-at: the same ring from a fiber that is not the nexus
::  root, which a request fiber is
::
++  note-inbox-at
  |=  [up=@ud op=@t ok=? why=@t by=@t]
  =/  m  (fiber:fiber:nexus ,~)
  ^-  form:m
  ;<  now=@da  bind:m  get-time:io
  =/  entry=json  (trail-entry op ok why by now)
  ;<  log=json  bind:m  (read-json (rf up /tr %inbox))
  (over:io (rf up /tr %inbox) [[/ %json] (ring:orr log entry 500)])
::  +note-refusals: one ship-traffic note per refusal, for the rows a
::  ship sent or holds that the decoder would not take
::
++  note-refusals
  |=  [op=@t by=@t bad=(list [oid=@t why=@t])]
  =/  m  (fiber:fiber:nexus ,~)
  ^-  form:m
  ?~  bad  (pure:m ~)
  ::  the oid is a peer's text: keep it to 64 bytes so the ring holds
  ::  notes rather than one ship's essay
  =/  why=@t  (rap 3 (end [3 64] oid.i.bad) ': ' why.i.bad ~)
  ;<  ~  bind:m  (note-inbox op | why by)
  (note-refusals op by t.bad)
::  +bump-beacon: the change beacon moves once per op that changed the
::  tree, never on a refusal or a no-op. Milliseconds since 1970, so a
::  browser keeps it exact.
::
++  bump-beacon
  =/  m  (fiber:fiber:nexus ,~)
  ^-  form:m
  ;<  now=@da  bind:m  get-time:io
  (over:io (rf 0 /beacon %rev) [[/ %json] (numb:enjs:format (ms-of:orr now))])
::  +ensure-me: person/me, named "me", aliased me and I, on our ship
::
++  ensure-me
  =/  m  (fiber:fiber:nexus ,?)
  ^-  form:m
  ;<  ex=?  bind:m  (peek-exists:io (rf 0 (body-dir %person %me) %body))
  ?:  ex  (pure:m |)
  ;<  our=@p  bind:m  get-our:io
  ;<  now=@da  bind:m  get-time:io
  =/  b=body:orr  [%person 'me' (sy `(list @t)`~['me' 'I']) now `our]
  (write-body 0 %person %me b)
::  +ensure-dirs: make each directory along base/segs, in order
::
++  ensure-dirs
  |=  [up=@ud base=path segs=(list @ta)]
  =/  m  (fiber:fiber:nexus ,~)
  ^-  form:m
  ?~  segs  (pure:m ~)
  =/  dir=path  (weld base /[i.segs])
  ;<  ex=?  bind:m  (peek-exists:io (rv up dir))
  ;<  ~  bind:m
    ?:  ex  (pure:(fiber:fiber:nexus ,~) ~)
    ;<  *  bind:(fiber:fiber:nexus ,~)  (make-soft:io (rv up dir) &+empty-dir:loader)
    (pure:(fiber:fiber:nexus ,~) ~)
  (ensure-dirs up dir t.segs)
::  +write-body: create a body with retention on, or merge onto the one
::  there: the name and aliases move, the created stamp stays. Answers
::  whether anything changed.
::
++  write-body
  |=  [up=@ud kind=@tas slug=@ta new=body:orr]
  =/  m  (fiber:fiber:nexus ,?)
  ^-  form:m
  ;<  ~  bind:m  (ensure-dirs up / `(list @ta)`~[%bodies kind slug %obs])
  =/  road=road:tarball  (rf up (body-dir kind slug) %body)
  =/  fresh=body:orr  new(name (fresh-name:orr slug name.new))
  ;<  cur=view:nexus  bind:m  (peek:io road ~)
  ?.  ?=([%file *] cur)
    ::  a vetoed make wrote nothing: the beacon must not move for it
    ;<  err=(unit tang)  bind:m
      (make-gained-soft:io road |+[[[/orrery %body] `stored-body:orr`[%2 fresh]] ~])
    (pure:m ?=(~ err))
  =/  old=(unit body:orr)  (read-body:orr (sang-noun:tarball sang.cur))
  ::  a grub this build cannot read is left where it is: overwriting it
  ::  would throw away a body a later shape may still understand
  ?~  old
    ;<  ~  bind:m  (note 'write-body' | 'unreadable body')
    (pure:m |)
  =/  merged=body:orr  (merge-body:orr u.old new)
  ?:  =(merged u.old)  (pure:m |)
  ;<  ~  bind:m  (over:io road [[/orrery %body] `stored-body:orr`[%2 merged]])
  (pure:m &)
::  +do-observe: bodies first, then observations, then compaction of
::  every subject written. Items that failed to decode are skipped
::  here; the caller already reported them.
::
++  do-observe
  |=  jon=json
  =/  m  (fiber:fiber:nexus ,?)
  ^-  form:m
  ;<  now=@da  bind:m  get-time:io
  ;<  policy=json  bind:m  (read-json (rf 0 / %'policy.json'))
  =/  prep  (prep-observe:orr jon now 'writer')
  ;<  c1=?  bind:m  (write-bodies bodies.prep |)
  ;<  c2=?  bind:m  (write-obs obs.prep (sensitive-of:orr policy) |)
  =/  subjects=(list bid:orr)
    %~  tap  in
    %-  sy
    %+  murn  obs.prep
    |=(e=(each obs:orr @t) ?:(?=(%& -.e) `subject.p.e ~))
  ;<  ~  bind:m  (compact-each subjects)
  ::  a batch carried from a shared peer belongs in the ship-traffic
  ::  ring, not in the owner's audit log
  =/  who=@t
    =/  os=(list json)  (ga:orr jon 'observations')
    ?~(os '' (gs:orr i.os 'by'))
  ;<  ~  bind:m
    ?:  =('ship' (gs:orr jon 'via'))  (note-inbox 'observe' & '' who)
    (note-by 'observe' & '' who)
  (pure:m |(c1 c2))
::  +write-bodies: one grub per body in a batch. A refused item or an
::  id that will not parse is skipped, so one bad row never stops the
::  rest of the batch.
::
++  write-bodies
  |=  [items=(list (each [id=bid:orr =body:orr] @t)) changed=?]
  =/  m  (fiber:fiber:nexus ,?)
  ^-  form:m
  ?~  items  (pure:m changed)
  ?:  ?=(%| -.i.items)  (write-bodies t.items changed)
  =/  pk  (parse-bid:orr id.p.i.items)
  ?~  pk  (write-bodies t.items changed)
  ;<  c=?  bind:m  (write-body 0 kind.u.pk slug.u.pk body.p.i.items)
  (write-bodies t.items |(changed c))
::  +write-obs: one grub per observation, under its subject. An unknown
::  subject is noted and skipped; an existing id is a no-op. A repeat on
::  an attribute in sens still counts as a change, so the beacon moves
::  for it as it does for a fresh row and rev tells a key that may write
::  a sensitive attribute nothing about whether its claim was held.
::
++  write-obs
  |=  [items=(list (each obs:orr @t)) sens=(set @t) changed=?]
  =/  m  (fiber:fiber:nexus ,?)
  ^-  form:m
  ?~  items  (pure:m changed)
  ?:  ?=(%| -.i.items)  (write-obs t.items sens changed)
  =/  o=obs:orr  p.i.items
  =/  pk  (parse-bid:orr subject.o)
  ?~  pk  (write-obs t.items sens changed)
  ;<  has=?  bind:m  (peek-exists:io (rf 0 (body-dir kind.u.pk slug.u.pk) %body))
  ?.  has
    ;<  ~  bind:m  (note 'observe' | (cat 3 'unknown subject ' subject.o))
    (write-obs t.items sens changed)
  =/  road=road:tarball  (rf 0 (obs-dir kind.u.pk slug.u.pk) (obs-id:orr o))
  ;<  ex=?  bind:m  (peek-exists:io road)
  ?:  ex  (write-obs t.items sens |(changed (~(has in sens) attr.o)))
  ;<  err=(unit tang)  bind:m
    (make-soft:io road |+[[[/orrery %obs] `stored-obs:orr`[%1 o]] ~])
  (write-obs t.items sens |(changed ?=(~ err)))
::  +do-upsert-body: lay or replace one body. The decoder's refusal is
::  the refusal, so the writer and the route agree on what is valid.
::
++  do-upsert-body
  |=  jon=json
  =/  m  (fiber:fiber:nexus ,?)
  ^-  form:m
  ;<  now=@da  bind:m  get-time:io
  =/  got  (de-body:orr (gj:orr jon 'body') now)
  ?:  ?=(%| -.got)  (refuse 'upsert-body' p.got)
  =/  pk  (parse-bid:orr id.p.got)
  ?~  pk  (refuse 'upsert-body' 'id: bad')
  ;<  changed=?  bind:m  (write-body 0 kind.u.pk slug.u.pk body.p.got)
  ;<  ~  bind:m  (note 'upsert-body' & '')
  (pure:m changed)
::  ==  reads: walking the tree
::
::  +read-json: a JSON grub in the instance, [%o ~] when absent
::
++  read-json
  |=  road=road:tarball
  =/  m  (fiber:fiber:nexus ,json)
  ^-  form:m
  ;<  vw=view:nexus  bind:m  (peek:io road ~)
  ?.  ?=([%file *] vw)  (pure:m [%o ~])
  (pure:m (fall (mole |.(!<(json (need-vase:tarball sang.vw)))) [%o ~]))
::  +read-map: a JSON object grub as its map, empty when absent or not
::  an object
::
++  read-map
  |=  road=road:tarball
  =/  m  (fiber:fiber:nexus ,(map @t json))
  ^-  form:m
  ;<  j=json  bind:m  (read-json road)
  (pure:m ?:(?=([%o *] j) p.j ~))
::  +load-bodies: every body under /bodies with its observation rows
::
++  load-bodies
  |=  up=@ud
  =/  m  (fiber:fiber:nexus ,(list loaded:orr))
  ^-  form:m
  ;<  vw=view:nexus  bind:m  (peek:io (rv up /bodies) ~)
  ?.  ?=([%ball *] vw)  (pure:m ~)
  (pure:m (bodies-in:om ball.vw))
::  ==  HTTP
::
++  send-json
  |=  [eyre-id=@ta code=@ud jon=json]
  =/  m  (fiber:fiber:nexus ,~)
  ^-  form:m
  =/  bod=octs  (as-octs:mimes:html (en:json:html jon))
  ::  no-store: a browser served the previous /telegram answer after a
  ::  save and the card showed the public url blank (2026-09-21)
  (send-simple:srv eyre-id [[code ['content-type' 'application/json'] ['cache-control' 'no-store'] ~] `bod])
++  send-err
  |=  [eyre-id=@ta code=@ud msg=@t]
  =/  m  (fiber:fiber:nexus ,~)
  ^-  form:m
  (send-json eyre-id code (err-json:orr msg))
::  +write-then: one op to the writer from a request fiber, then the
::  rest of the answer; 500 when the writer refused the poke
::
++  write-then
  =/  m  (fiber:fiber:nexus ,~)
  |=  [eyre-id=@ta op=json then=form:m]
  ^-  form:m
  ;<  err=(unit tang)  bind:m  (poke-soft:io (rf 1 / %'main.sig') [[/ %json] op])
  ?^  err  (send-err eyre-id 500 'the writer refused the poke')
  then
::  +when-arg: ?at=<iso>, or now. ~ when given and unreadable.
::
++  when-arg
  |=  [args=quay:eyre now=@da]
  ^-  (unit @da)
  =/  v=(unit @t)  (get-key:kv:html-utils 'at' args)
  ?~  v  `now
  (de-iso:orr u.v)
::  +ensure-me-from-request: person/me is laid by the writer on the
::  first request after consent, since the writer itself reaches
::  nothing at rise
::
++  ensure-me-from-request
  =/  m  (fiber:fiber:nexus ,~)
  ^-  form:m
  ;<  ex=?  bind:m  (peek-exists:io (rf 1 (body-dir %person %me) %body))
  ?:  ex  (pure:m ~)
  ;<  *  bind:m
    (poke-soft:io (rf 1 / %'main.sig') [[/ %json] (pairs:enjs:format ~[['op' s+'ensure-me']])])
  (pure:m ~)
::  +handle-request: one HTTP request, on its own ephemeral fiber.
::  Who is asking is settled by +identify: the owner (eyre's
::  authenticated flag and src equal to our) or a minted key. The
::  scoped routes take the actor and apply its scope themselves; every
::  other route is wrapped in +own, the owner alone.
::
++  handle-request
  |=  eyre-id=@ta
  =/  m  (fiber:fiber:nexus ,~)
  ^-  form:m
  ;<  [src=@p req=inbound-request:eyre]  bind:m
    (get-state-as:io ,[src=@p inbound-request:eyre])
  ;<  our=@p  bind:m  get-our:io
  =/  parsed  (parse-url:http-utils url.request.req)
  ::  drop /apps/orrery; a trailing slash parses as a trailing empty knot
  =/  suffix0=path  (slag 2 site.parsed)
  =/  suffix=path
    ?:  &(?=(^ suffix0) =('' (rear `path`suffix0)))  (snip `path`suffix0)
    suffix0
  =/  meth=@t  method.request.req
  ::  the telegram webhook carries no cookie and no key: the secret header
  ::  is its whole credential, and it is answered before +identify
  ?:  &(=('POST' meth) ?=([%telegram ~] suffix))  (serve-telegram-hook eyre-id req)
  ;<  who=(unit actor)  bind:m  (identify req src our)
  ?~  who  (send-err eyre-id 403 'forbidden')
  =/  act=actor  u.who
  ::  +own: a route the owner alone may take
  =/  own  |=(f=form:m ^-(form:m ?:(owner.act f (send-err eyre-id 403 'owner only'))))
  ::  +writes: a route the owner or a key with write may take, so a
  ::  client that walks the owner through a setup can finish it
  =/  writes
    |=  f=form:m
    ^-  form:m
    ?:  owner.act  f
    ?:  &(?=(^ scope.act) write.u.scope.act)  f
    (send-err eyre-id 403 'read only key')
  ::  a body is read as JSON, so a request carrying one says it is JSON.
  ::  The gates and the page all send the header. A POST with no body
  ::  carries no JSON to mistype, so it is not a 415.
  =/  ctype=@t
    =/  raw=tape
      (cass (trip (fall (get-header:http 'content-type' header-list.request.req) '')))
    (crip raw)
  ?:  ?&  |(=('POST' meth) =('PUT' meth))
          ?=(^ body.request.req)
          !=(0 p.u.body.request.req)
          !=('application/json' (end [3 16] ctype))
      ==
    (send-err eyre-id 415 'content-type: application/json required')
  ;<  ~  bind:m  ensure-me-from-request
  =/  jon=json
    (fall (de:json:html ?~(body.request.req '' q.u.body.request.req)) ~)
  =/  s2=@ta  ?:(?=([@ @ @ *] suffix) i.t.t.suffix %$)
  =/  s3=@ta  ?:(?=([@ @ @ @ *] suffix) i.t.t.t.suffix %$)
  =/  s4=@ta  ?:(?=([@ @ @ @ @ *] suffix) i.t.t.t.t.suffix %$)
  =/  args=quay:eyre  args.parsed
  ?:  &(=('GET' meth) ?=(~ suffix))                          (own (serve-file eyre-id %'orrery.html'))
  ?:  &(=('GET' meth) ?=([%'orrery.css' ~] suffix))          (own (serve-file eyre-id %'orrery.css'))
  ?:  &(=('GET' meth) ?=([%'orrery.js' ~] suffix))           (own (serve-file eyre-id %'orrery.js'))
  ?:  &(=('GET' meth) ?=([%api %state ~] suffix))           (serve-state eyre-id args act)
  ?:  &(=('GET' meth) ?=([%api %body @ @ ~] suffix))        (serve-body eyre-id s2 s3 args act)
  ?:  &(=('DELETE' meth) ?=([%api %body @ @ ~] suffix))     (own (serve-delete-body eyre-id s2 s3))
  ?:  &(=('GET' meth) ?=([%api %resolve ~] suffix))         (serve-resolve eyre-id args act)
  ?:  &(=('POST' meth) ?=([%api %observe ~] suffix))        (serve-observe eyre-id jon act)
  ?:  &(=('POST' meth) ?=([%api %retract ~] suffix))        (serve-retract eyre-id jon act)
  ?:  &(=('POST' meth) ?=([%api %bodies ~] suffix))         (serve-bodies eyre-id jon act)
  ?:  &(=('POST' meth) ?=([%api %merge ~] suffix))          (own (serve-merge eyre-id jon))
  ?:  &(=('POST' meth) ?=([%api %act ~] suffix))            (serve-act eyre-id jon act)
  ?:  &(=('GET' meth) ?=([%api %actions ~] suffix))         (serve-actions eyre-id args act)
  ?:  &(=('POST' meth) ?=([%api %actions @ ~] suffix))      (serve-set-action eyre-id s2 jon act)
  ?:  &(=('POST' meth) ?=([%api %actions @ %refine ~] suffix))  (serve-refine eyre-id s2 jon act)
  ?:  &(=('GET' meth) ?=([%api %schema ~] suffix))          (own (serve-doc eyre-id %'schema.json'))
  ?:  &(=('PUT' meth) ?=([%api %schema ~] suffix))          (own (serve-set-doc eyre-id 'set-schema' jon))
  ?:  &(=('GET' meth) ?=([%api %policy ~] suffix))          (own (serve-doc eyre-id %'policy.json'))
  ?:  &(=('PUT' meth) ?=([%api %policy ~] suffix))          (own (serve-set-doc eyre-id 'set-policy' jon))
  ?:  &(=('POST' meth) ?=([%api %share ~] suffix))          (own (serve-share eyre-id jon))
  ?:  &(=('DELETE' meth) ?=([%api %share @ @ @ ~] suffix))  (own (serve-revoke eyre-id s2 s3 s4))
  ?:  &(=('GET' meth) ?=([%api %shares ~] suffix))          (own (serve-shares eyre-id))
  ?:  &(=('POST' meth) ?=([%api %accept ~] suffix))         (own (serve-accept eyre-id jon))
  ?:  &(=('POST' meth) ?=([%api %decline ~] suffix))        (own (serve-decline eyre-id jon))
  ?:  &(=('POST' meth) ?=([%api %sync ~] suffix))           (own (serve-prod eyre-id %'sync.sig' 'follower'))
  ?:  &(=('POST' meth) ?=([%api %clients ~] suffix))        (own (serve-mint eyre-id jon))
  ?:  &(=('GET' meth) ?=([%api %clients ~] suffix))         (own (serve-clients eyre-id))
  ?:  &(=('DELETE' meth) ?=([%api %clients @ ~] suffix))    (own (serve-drop-client eyre-id s2))
  ?:  &(=('GET' meth) ?=([%api %generator ~] suffix))        (own (serve-generator eyre-id))
  ?:  &(=('PUT' meth) ?=([%api %generator ~] suffix))        (own (serve-set-doc eyre-id 'set-generator' jon))
  ?:  &(=('GET' meth) ?=([%api %generator %last ~] suffix))  (own (serve-doc eyre-id %'generator-last.json'))
  ?:  &(=('POST' meth) ?=([%api %generate ~] suffix))       (serve-generate eyre-id jon act)
  ?:  &(=('POST' meth) ?=([%api %reconcile ~] suffix))      (own (serve-reconcile eyre-id))
  ?:  &(=('GET' meth) ?=([%api %reconcile %last ~] suffix))  (own (serve-doc eyre-id %'reconcile-last.json'))
  ?:  &(=('GET' meth) ?=([%api %telegram ~] suffix))         (own (serve-telegram eyre-id))
  ?:  &(=('PUT' meth) ?=([%api %telegram ~] suffix))         (own (serve-set-telegram eyre-id jon))
  ?:  &(=('GET' meth) ?=([%api %telegram %last ~] suffix))   (own (serve-doc eyre-id %'telegram-last.json'))
  ?:  &(=('POST' meth) ?=([%api %telegram %webhook ~] suffix))  (writes (serve-set-webhook eyre-id))
  ?:  &(=('GET' meth) ?=([%api %telegram %webhook ~] suffix))   (writes (serve-webhook-info eyre-id))
  ?:  &(=('POST' meth) ?=([%api %telegram %wake ~] suffix))  (own (serve-prod eyre-id %'telegram.sig' 'telegram'))
  ?:  &(=('GET' meth) ?=([%api %chat ~] suffix))             (writes (serve-chat eyre-id))
  ?:  &(=('PUT' meth) ?=([%api %chat ~] suffix))             (writes (serve-set-doc eyre-id 'set-chat' jon))
  ?:  &(=('GET' meth) ?=([%api %chat %last ~] suffix))       (own (serve-doc eyre-id %'chat-last.json'))
  ?:  &(=('POST' meth) ?=([%api %chat %wake ~] suffix))      (own (serve-prod eyre-id %'chat.sig' 'chat'))
  ?:  &(=('GET' meth) ?=([%api %chat %dms ~] suffix))        (own (serve-chat-list eyre-id /gx/chat/dm/json))
  ?:  &(=('GET' meth) ?=([%api %chat %channels ~] suffix))   (own (serve-chat-list eyre-id /gx/channels/v5/channels/json))
  ?:  &(=('GET' meth) ?=([%api %exec %last ~] suffix))       (own (serve-doc eyre-id %'exec-last.json'))
  ?:  &(=('POST' meth) ?=([%api %exec %wake ~] suffix))      (own (serve-prod eyre-id %'exec.sig' 'executor'))
  (send-err eyre-id 404 'no such route')
::  +serve-state: every body with its current attributes, the open
::  situations, the open actions and the schema, as of ?at
::
++  serve-state
  |=  [eyre-id=@ta args=quay:eyre act=actor]
  =/  m  (fiber:fiber:nexus ,~)
  ^-  form:m
  ;<  now=@da  bind:m  get-time:io
  =/  when=(unit @da)  (when-arg args now)
  ?~  when  (send-err eyre-id 400 'at: expected an ISO 8601 UTC time')
  =/  kind=@t  (fall (get-key:kv:html-utils 'kind' args) '')
  ;<  schema=json  bind:m  (read-json (rf 1 / %'schema.json'))
  ;<  policy=json  bind:m  (read-json (rf 1 / %'policy.json'))
  ;<  rev=json  bind:m  (read-json (rf 1 /beacon %rev))
  ;<  all0=(list loaded:orr)  bind:m  (load-bodies 1)
  ;<  acts0=(list [id=@ta a=action:orr])  bind:m  (load-actions 1)
  =/  seen  (view-of act all0 acts0 (hidden-for act policy))
  =/  all=(list loaded:orr)  all.seen
  =/  acts=(list [id=@ta a=action:orr])  acts.seen
  ::  a key gets the schema trimmed to its scope: GET /schema is the
  ::  owner's, so the state view must not hand the whole document over.
  ::  A key that may write the sensitive attributes is told their names,
  ::  so it knows what it may write; it still reads no value of one.
  =/  shown-schema=json
    ?~  scope.act  schema
    =/  hide=(set @t)  ?:(sensitive.u.scope.act ~ (hidden-for act policy))
    (scope-schema:orr schema u.scope.act hide)
  =/  multi=(set @t)  (multi-of:orr schema)
  (send-json eyre-id 200 (state-json:orr all acts multi u.when kind rev shown-schema))
::  +serve-observe: decode, answer per item, hand the stamped request to
::  the writer. The ids reported here are the ids the writer makes,
::  because at and by are stamped before either side decodes.
::
++  serve-observe
  |=  [eyre-id=@ta jon=json act=actor]
  =/  m  (fiber:fiber:nexus ,~)
  ^-  form:m
  ?.  ?=([%o *] jon)  (send-err eyre-id 400 'a JSON object is required')
  =/  obs-j=json  (gj:orr jon 'observations')
  ?.  |(?=(~ obs-j) ?=([%a *] obs-j))
    (send-err eyre-id 400 'observations: expected an array')
  =/  bodies-j=json  (gj:orr jon 'bodies')
  ?.  |(?=(~ bodies-j) ?=([%a *] bodies-j))
    (send-err eyre-id 400 'bodies: expected an array')
  ?:  (gth (lent (ga:orr jon 'bodies')) max-bodies:orr)
    (send-err eyre-id 400 'bodies: over 50')
  ?:  (gth (lent (ga:orr jon 'observations')) max-obs:orr)
    (send-err eyre-id 400 'observations: over 200')
  ;<  policy=json  bind:m  (read-json (rf 1 / %'policy.json'))
  =/  denied=(unit @t)  (deny-observe act jon policy)
  ?^  denied  (send-err eyre-id 403 u.denied)
  ;<  now=@da  bind:m  get-time:io
  =/  stamp
    |=  j=json
    ^-  json
    ?:(owner.act (fill-obs:orr j now 'http') (fill-obs-as:orr j now by.act))
  =/  all-obs=(list json)  (turn (ga:orr jon 'observations') stamp)
  ::  a ship source is the inbox's to set, from the transport: a local
  ::  client sending one would be forging another ship's claim, so the
  ::  item is answered refused and never reaches the writer
  =/  stamped=json
    %-  pairs:enjs:format
    :~  ['op' s+'observe']
        ['bodies' a+(ga:orr jon 'bodies')]
        ['observations' a+(skip all-obs ship-source:orr)]
    ==
  =/  shown=json
    %-  pairs:enjs:format
    :~  ['op' s+'observe']
        ['bodies' a+(ga:orr jon 'bodies')]
        ['observations' a+all-obs]
    ==
  =/  prep  (prep-observe:orr shown now by.act)
  =/  items=(list (each obs:orr @t))  (mark-reserved:orr all-obs obs.prep)
  ;<  bodies-res=(list json)  bind:m  (body-results bodies.prep ~ ~)
  =/  known=(set bid:orr)
    %-  sy
    :-  'person/me'
    %+  murn  bodies.prep
    |=(e=(each [id=bid:orr =body:orr] @t) ?:(?=(%& -.e) `id.p.e ~))
  ::  a key's answer on an attribute it may write but never read says
  ::  nothing about whether the row was already there
  =/  hush=(set @t)  (hidden-for act policy)
  ;<  obs-res=(list json)  bind:m  (obs-results items known hush ~ ~)
  %^  write-then  eyre-id  stamped
  %^  send-json  eyre-id  200
  (pairs:enjs:format ~[['bodies' a+bodies-res] ['observations' a+obs-res]])
::  +body-results: one answer per body in a batch: whether it parsed,
::  and whether the id was already there
::
::    seen carries the ids already answered in this batch, so the second
::    copy of one item answers existing rather than claiming a fresh
::    write. +obs-results below keeps the same set for the rows.
::
++  body-results
  |=  [items=(list (each [id=bid:orr =body:orr] @t)) seen=(set bid:orr) acc=(list json)]
  =/  m  (fiber:fiber:nexus ,(list json))
  ^-  form:m
  ?~  items  (pure:m (flop acc))
  ?:  ?=(%| -.i.items)
    %^  body-results  t.items  seen
    [(err-entry:orr p.i.items) acc]
  =/  pk  (parse-bid:orr id.p.i.items)
  ?~  pk
    %^  body-results  t.items  seen
    [(err-entry:orr 'id: bad') acc]
  =/  bd=bid:orr  id.p.i.items
  ;<  ex=?  bind:m  (peek-exists:io (rf 1 (body-dir kind.u.pk slug.u.pk) %body))
  =/  entry=json
    (pairs:enjs:format ~[['id' s+bd] ['ok' b+&] ['existing' b+|(ex (~(has in seen) bd))]])
  %^  body-results  t.items  (~(put in seen) bd)  [entry acc]
::  +obs-results: one answer per observation in the same batch. known
::  carries the bodies the batch is laying, so a row about one of them
::  is not an unknown subject. hush names the attributes the actor may
::  not read: their rows answer without existing, since that flag would
::  tell a writing key whether its exact claim was already held.
::
++  obs-results
  |=  $:  items=(list (each obs:orr @t))
          known=(set bid:orr)
          hush=(set @t)
          seen=(set @ta)
          acc=(list json)
      ==
  =/  m  (fiber:fiber:nexus ,(list json))
  ^-  form:m
  ?~  items  (pure:m (flop acc))
  ?:  ?=(%| -.i.items)
    =/  entry=json  (err-entry:orr p.i.items)
    (obs-results t.items known hush seen [entry acc])
  =/  o=obs:orr  p.i.items
  =/  pk  (parse-bid:orr subject.o)
  ?~  pk
    =/  entry=json  (err-entry:orr 'subject: bad')
    (obs-results t.items known hush seen [entry acc])
  ;<  has=?  bind:m
    ?:  (~(has in known) subject.o)  (pure:(fiber:fiber:nexus ,?) &)
    (peek-exists:io (rf 1 (body-dir kind.u.pk slug.u.pk) %body))
  ?.  has
    =/  why=@t  (cat 3 'unknown subject ' subject.o)
    =/  entry=json  (err-entry:orr why)
    (obs-results t.items known hush seen [entry acc])
  =/  id=@ta  (obs-id:orr o)
  ;<  ex=?  bind:m  (peek-exists:io (rf 1 (obs-dir kind.u.pk slug.u.pk) id))
  =/  entry=json
    ?:  (~(has in hush) attr.o)  (pairs:enjs:format ~[['id' s+id] ['ok' b+&]])
    (pairs:enjs:format ~[['id' s+id] ['ok' b+&] ['existing' b+|(ex (~(has in seen) id))]])
  (obs-results t.items known hush (~(put in seen) id) [entry acc])
::  +find-obs: the body holding an observation id, by a sweep
::
++  find-obs
  |=  [up=@ud id=@ta]
  =/  m  (fiber:fiber:nexus ,(unit [kind=@tas slug=@ta r=row:orr]))
  ^-  form:m
  ;<  all=(list loaded:orr)  bind:m  (load-bodies up)
  %-  pure:m
  |-
  ?~  all  ~
  =/  hit=(unit row:orr)  (find-row rows.i.all id)
  ?~  hit  $(all t.all)
  =/  pk  (parse-bid:orr id.i.all)
  ?~  pk  $(all t.all)
  `[kind.u.pk slug.u.pk u.hit]
++  find-row
  |=  [rs=(list row:orr) id=@ta]
  ^-  (unit row:orr)
  ?~  rs  ~
  ?:  =(id.i.rs id)  `i.rs
  $(rs t.rs)
::  +do-retract: the retracted flag and its note. The grub stays.
::
++  do-retract
  |=  jon=json
  =/  m  (fiber:fiber:nexus ,?)
  ^-  form:m
  =/  id=@t  (gs:orr jon 'id')
  =/  why=@t  (gs:orr jon 'note')
  ?:  (gth (met 3 why) max-note:orr)  (refuse 'retract' 'note: over 500 bytes')
  ;<  hit=(unit [kind=@tas slug=@ta r=row:orr])  bind:m  (find-obs 0 `@ta`id)
  ?~  hit  (refuse 'retract' (cat 3 'no observation ' id))
  ?:  retracted.obs.r.u.hit  (note-then-no 'retract' 'already retracted')
  =/  o=obs:orr  obs.r.u.hit(retracted &, note why)
  ;<  ~  bind:m
    %+  over:io  (rf 0 (obs-dir kind.u.hit slug.u.hit) id.r.u.hit)
    [[/orrery %obs] `stored-obs:orr`[%1 o]]
  ;<  terms=compact-terms  bind:m  read-compact-terms
  ;<  ~  bind:m  (compact kind.u.hit slug.u.hit terms)
  =/  who=@t  (gs:orr jon 'by')
  ;<  ~  bind:m
    ?:  =('ship' (gs:orr jon 'via'))  (note-inbox 'retract' & why who)
    (note-by 'retract' & why who)
  (pure:m &)
::  +do-delete-body: cull a body's whole directory, its observations
::  with it
::
++  do-delete-body
  |=  jon=json
  =/  m  (fiber:fiber:nexus ,?)
  ^-  form:m
  =/  pk  (parse-bid:orr (gs:orr jon 'id'))
  ?~  pk  (refuse 'delete-body' 'id: expected <kind>/<slug>')
  ;<  ex=?  bind:m  (peek-exists:io (rv 0 (body-dir kind.u.pk slug.u.pk)))
  ?.  ex  (refuse 'delete-body' 'no such body')
  ;<  *  bind:m  (cull-soft:io (rv 0 (body-dir kind.u.pk slug.u.pk)))
  ;<  ~  bind:m  (note 'delete-body' & '')
  (pure:m &)
::  +do-merge: fold one body into another. The rows move, the references
::  to from are re-pointed at into, the aliases union, and from is
::  culled the way delete-body culls it. The share record is the route's
::  to drop: it needs +self-base, which the writer cannot reach.
::
++  do-merge
  |=  jon=json
  =/  m  (fiber:fiber:nexus ,?)
  ^-  form:m
  =/  from=@t  (gs:orr jon 'from')
  =/  into=@t  (gs:orr jon 'into')
  ?:  =(from into)  (refuse 'merge' 'from and into are the same body')
  ?:  =('person/me' from)  (refuse 'merge' 'person/me cannot be merged away')
  =/  fk  (parse-bid:orr from)
  ?~  fk  (refuse 'merge' (cat 3 'no such body ' from))
  =/  ik  (parse-bid:orr into)
  ?~  ik  (refuse 'merge' (cat 3 'no such body ' into))
  ;<  now=@da  bind:m  get-time:io
  ;<  all=(list loaded:orr)  bind:m  (load-bodies 0)
  =/  src=(unit loaded:orr)  (loaded-of:orr all from)
  ?~  src  (refuse 'merge' (cat 3 'no such body ' from))
  =/  dst=(unit loaded:orr)  (loaded-of:orr all into)
  ?~  dst  (refuse 'merge' (cat 3 'no such body ' into))
  =/  fresh=(list row:orr)  (move-rows:orr rows.u.src rows.u.dst into)
  =/  pointing=(list [id=bid:orr r=row:orr])  (ref-rows:orr all from now)
  ;<  ~  bind:m  (ensure-dirs 0 / `(list @ta)`~[%bodies kind.u.ik slug.u.ik %obs])
  ;<  ~  bind:m  (write-rows 0 (obs-dir kind.u.ik slug.u.ik) fresh)
  ;<  ~  bind:m  (repoint-each pointing into now)
  ;<  acts=(list [id=@ta a=action:orr])  bind:m  (load-actions 0)
  ;<  ~  bind:m  (reabout acts from into)
  =/  merged=body:orr  (absorb:orr body.u.dst body.u.src)
  ;<  ~  bind:m
    ?:  =(merged body.u.dst)  (pure:(fiber:fiber:nexus ,~) ~)
    %+  over:io  (rf 0 (body-dir kind.u.ik slug.u.ik) %body)
    [[/orrery %body] `stored-body:orr`[%2 merged]]
  ;<  *  bind:m  (cull-soft:io (rv 0 (body-dir kind.u.fk slug.u.fk)))
  ;<  terms=compact-terms  bind:m  read-compact-terms
  ;<  ~  bind:m  (compact kind.u.ik slug.u.ik terms)
  =/  why=@t
    %+  rap  3
    :~  from  ' -> '  into
        ', moved '  (scot %ud (lent fresh))
        ', repointed '  (scot %ud (lent pointing))
    ==
  ;<  ~  bind:m  (note 'merge' & why)
  (pure:m &)
::  +write-rows: one grub per row, under a body's obs directory. A row
::  whose id is already there is left as it is.
::
++  write-rows
  |=  [up=@ud dir=path rows=(list row:orr)]
  =/  m  (fiber:fiber:nexus ,~)
  ^-  form:m
  ?~  rows  (pure:m ~)
  =/  cur=row:orr  i.rows
  =/  road=road:tarball  (rf up dir id.cur)
  ;<  ex=?  bind:m  (peek-exists:io road)
  ;<  ~  bind:m
    ?:  ex  (pure:(fiber:fiber:nexus ,~) ~)
    ;<  *  bind:(fiber:fiber:nexus ,~)
      (make-soft:io road |+[[[/orrery %obs] `stored-obs:orr`[%1 obs.cur]] ~])
    (pure:(fiber:fiber:nexus ,~) ~)
  (write-rows up dir t.rows)
::  +repoint-each: a reference to the merged body, rewritten in place:
::  the live row beside it points at into, and the old one is retracted
::  with the merge named
::
++  repoint-each
  |=  [items=(list [id=bid:orr r=row:orr]) into=bid:orr now=@da]
  =/  m  (fiber:fiber:nexus ,~)
  ^-  form:m
  ?~  items  (pure:m ~)
  =/  cur=[id=bid:orr r=row:orr]  i.items
  =/  pk  (parse-bid:orr id.cur)
  ?~  pk  (repoint-each t.items into now)
  =/  dir=path  (obs-dir kind.u.pk slug.u.pk)
  ;<  ~  bind:m  (write-rows 0 dir ~[(repoint:orr r.cur into now)])
  =/  old=obs:orr  obs.r.cur(retracted &, note (cat 3 'merged into ' into))
  ;<  ~  bind:m
    (over:io (rf 0 dir id.r.cur) [[/orrery %obs] `stored-obs:orr`[%1 old]])
  (repoint-each t.items into now)
::  +reabout: every action whose about names the merged body names the
::  body it was merged into instead. about is a set, so no duplicate.
::
++  reabout
  |=  [acts=(list [id=@ta a=action:orr]) from=bid:orr into=bid:orr]
  =/  m  (fiber:fiber:nexus ,~)
  ^-  form:m
  ?~  acts  (pure:m ~)
  =/  cur=[id=@ta a=action:orr]  i.acts
  ?.  (~(has in about.a.cur) from)  (reabout t.acts from into)
  =/  kept=(set bid:orr)  (~(del in about.a.cur) from)
  =/  next=action:orr  a.cur(about (~(put in kept) into))
  ;<  ~  bind:m
    (over:io (rf 0 /actions id.cur) [[/orrery %action] `stored-action:orr`[%2 next]])
  (reabout t.acts from into)
::  +load-actions: every action grub
::
++  load-actions
  |=  up=@ud
  =/  m  (fiber:fiber:nexus ,(list [id=@ta a=action:orr]))
  ^-  form:m
  ;<  vw=view:nexus  bind:m  (peek:io (rv up /actions) ~)
  ?.  ?=([%ball *] vw)  (pure:m ~)
  ?~  fil.ball.vw  (pure:m ~)
  %-  pure:m
  %+  murn  ~(tap by contents.u.fil.ball.vw)
  |=  [nam=@ta c=[=sang:tarball gain=? bang=(unit tang)]]
  ^-  (unit [id=@ta a=action:orr])
  =/  a=(unit action:orr)  (read-action:orr (sang-noun:tarball sang.c))
  ?~  a  ~
  `[nam u.a]
::  +load-action: one action grub, or why it could not be read: absent,
::  or there but not an action the decoder takes
::
++  load-action
  |=  [up=@ud id=@ta]
  =/  m  (fiber:fiber:nexus ,(each action:orr ?(%absent %unreadable)))
  ^-  form:m
  ;<  vw=view:nexus  bind:m  (peek:io (rf up /actions id) ~)
  ?.  ?=([%file *] vw)  (pure:m [%| %absent])
  =/  a=(unit action:orr)  (read-action:orr (sang-noun:tarball sang.vw))
  (pure:m ?~(a [%| %unreadable] [%& u.a]))
::  +scoped-action: an action a route may move, or the answer when it
::  is absent, outside the key's action kinds (the same 404, so a key
::  never learns the id is taken) or the key is read only
::
++  scoped-action
  |=  [id=@ta act=actor]
  =/  m  (fiber:fiber:nexus ,(each action:orr [code=@ud msg=@t]))
  ^-  form:m
  ;<  a=(each action:orr ?(%absent %unreadable))  bind:m  (load-action 1 id)
  ?:  ?=(%| -.a)
    (pure:m [%| ?:(?=(%absent p.a) [404 'no such action'] [500 'unreadable action'])])
  ?:  &(?=(^ scope.act) !(action-in-scope:orr u.scope.act kind.p.a))
    (pure:m [%| 404 'no such action'])
  ?:  &(?=(^ scope.act) !write.u.scope.act)  (pure:m [%| 403 'read only key'])
  (pure:m [%& p.a])
::  +first-missing: the first body id in the list that does not exist
::
++  first-missing
  |=  [up=@ud ids=(list bid:orr)]
  =/  m  (fiber:fiber:nexus ,(unit bid:orr))
  ^-  form:m
  ?~  ids  (pure:m ~)
  ::  person/me always exists by the time the writer reads this: the
  ::  request queued +ensure-me ahead of its own poke
  ?:  =('person/me' i.ids)  (first-missing up t.ids)
  =/  pk  (parse-bid:orr i.ids)
  ?~  pk  (pure:m `i.ids)
  ;<  ex=?  bind:m  (peek-exists:io (rf up (body-dir kind.u.pk slug.u.pk) %body))
  ?.  ex  (pure:m `i.ids)
  (first-missing up t.ids)
::  +body-attr: a body's live string attribute, read fresh from the
::  store by its id ("kind/slug"); '' when the id does not parse or
::  the body does not exist.
::
++  body-attr
  |=  [up=@ud id=bid:orr attr=@t]
  =/  m  (fiber:fiber:nexus ,@t)
  ^-  form:m
  =/  pk  (parse-bid:orr id)
  ?~  pk  (pure:m '')
  ;<  vw=view:nexus  bind:m  (peek:io (rv up (body-dir kind.u.pk slug.u.pk)) ~)
  ?.  ?=([%ball *] vw)  (pure:m '')
  =/  bf=(unit body:orr)  (body-in:om ball.vw)
  ?~  bf  (pure:m '')
  ;<  now=@da  bind:m  get-time:io
  (pure:m (attr-text:orr ~[[id u.bf (rows-in:om ball.vw)]] ~ now id attr))
::  +route-to: an action with the channel rule run for its recipient,
::  whose ship is read from the store
::
++  route-to
  |=  [up=@ud a=action:orr]
  =/  m  (fiber:fiber:nexus ,[a=action:orr note=@t])
  ^-  form:m
  ;<  ship=@t  bind:m  (body-attr up (gs:orr payload.a 'to') 'ship')
  (pure:m (route-message:orr a ship))
::  +open-twin: an open action with this kind and title, if any
::
++  open-twin
  |=  [all=(list [id=@ta a=action:orr]) kind=@tas title=@t]
  ^-  (unit [id=@ta a=action:orr])
  ?~  all  ~
  ?:  &((is-open:orr a.i.all) =(kind.a.i.all kind) =(title.a.i.all title))  `i.all
  $(all t.all)
::  +do-act: a proposal. Its about bodies must exist; an open twin
::  answers nothing new; policy decides the initial status; a new
::  action is pushed when policy says so.
::
++  do-act
  |=  jon=json
  =/  m  (fiber:fiber:nexus ,?)
  ^-  form:m
  ;<  now=@da  bind:m  get-time:io
  =/  got  (de-action:orr (gj:orr jon 'action') now 'writer')
  ?:  ?=(%| -.got)  (refuse 'act' p.got)
  ;<  missing=(unit bid:orr)  bind:m  (first-missing 0 ~(tap in about.p.got))
  ?^  missing  (refuse 'act' (cat 3 'about: no such body ' u.missing))
  ;<  policy=json  bind:m  (read-json (rf 0 / %'policy.json'))
  ;<  all=(list [id=@ta a=action:orr])  bind:m  (load-actions 0)
  ?^  (open-twin all kind.p.got title.p.got)  (note-then-no 'act' 'an open action with this kind and title exists')
  =/  auto=?  =(%approved (initial-status:orr kind.p.got (auto-of:orr policy)))
  =/  a=action:orr  ?.(auto p.got (transition:orr p.got %approved 'policy' '' now))
  ;<  routed=[a=action:orr note=@t]  bind:m  (route-to 0 a)
  =.  a  a.routed
  ;<  ~  bind:m  ?:(=('' note.routed) (pure:(fiber:fiber:nexus ,~) ~) (note 'act' & note.routed))
  =/  id=@ta  (act-id:orr a)
  ;<  ex=?  bind:m  (peek-exists:io (rf 0 /actions id))
  ?:  ex  (note-then-no 'act' 'an action with this id exists')
  ;<  *  bind:m
    (make-gained-soft:io (rf 0 /actions id) |+[[[/orrery %action] `stored-action:orr`[%2 a]] ~])
  ;<  ~  bind:m
    ?.  (should-push:orr (push-mode-of:orr policy) status.a)  (pure:(fiber:fiber:nexus ,~) ~)
    (push-soft a id)
  ;<  ~  bind:m  (note-by 'act' & '' by.a)
  (pure:m &)
::  +push-soft: a notification through /sys/push. Soft, so a refused
::  road never fails the writer, and the audit note says which it was.
::
++  push-soft
  |=  [a=action:orr id=@ta]
  =/  m  (fiber:fiber:nexus ,~)
  ^-  form:m
  ;<  eny=@uvJ  bind:m  get-entropy:io
  =/  title=@t  ?:(=(%approved status.a) 'Orrery filed' 'Orrery proposes')
  =/  tag=@t  (cat 3 'orrery-' id)
  ;<  err=(unit tang)  bind:m
    %+  poke-soft:io  push-road:io
    [[/ %push-action] `push-action:nexus`[%send [~ ~ ~ [title title.a ~ `'/apps/orrery' `tag]] eny]]
  =/  sent=?  ?=(~ err)
  ;<  ~  bind:m  (note-by 'push' sent ?:(sent title.a 'push refused') by.a)
  (pure:m ~)
::  +do-set-action: move one action to a new status, refusing a
::  transition the model does not allow
::
++  do-set-action
  |=  jon=json
  =/  m  (fiber:fiber:nexus ,?)
  ^-  form:m
  =/  id=@t  (gs:orr jon 'id')
  =/  want=@t  (gs:orr jon 'status')
  =/  why=@t  (gs:orr jon 'note')
  =/  who=@t  =/(b (gs:orr jon 'by') ?:(=('' b) 'user' b))
  ?:  (gth (met 3 why) max-note:orr)  (refuse 'set-action' 'note: over 500 bytes')
  =/  road=road:tarball  (rf 0 /actions `@ta`id)
  ;<  got=(each action:orr ?(%absent %unreadable))  bind:m  (load-action 0 `@ta`id)
  ?:  ?=(%| -.got)
    (refuse 'set-action' ?:(?=(%absent p.got) (cat 3 'no action ' id) 'unreadable action'))
  =/  a=action:orr  p.got
  ;<  now=@da  bind:m  get-time:io
  =/  no=(unit @t)  (move-refusal:orr a `@tas`want who now)
  ?^  no  (refuse 'set-action' u.no)
  =/  next=action:orr  (transition:orr a `@tas`want who why now)
  ;<  ~  bind:m  (over:io road [[/orrery %action] `stored-action:orr`[%2 next]])
  ;<  ~  bind:m  (note-by 'set-action' & '' who)
  (pure:m &)
::  +do-revise-action: the owner's rewrite of a proposed action's title,
::  payload, about and due, applied in place with a history step. A
::  channel the revision sets stands as written; a revision that only
::  moves the message to another person runs the channel rule for that
::  person, as the filing did for the first (+reroute-on-revise).
::
++  do-revise-action
  |=  jon=json
  =/  m  (fiber:fiber:nexus ,?)
  ^-  form:m
  =/  id=@t  (gs:orr jon 'id')
  =/  who=@t  =/(b (gs:orr jon 'by') ?:(=('' b) 'user' b))
  =/  road=road:tarball  (rf 0 /actions `@ta`id)
  ;<  got=(each action:orr ?(%absent %unreadable))  bind:m  (load-action 0 `@ta`id)
  ?:  ?=(%| -.got)
    (refuse 'revise-action' ?:(?=(%absent p.got) (cat 3 'no action ' id) 'unreadable action'))
  =/  a=action:orr  p.got
  ?.  =(%proposed status.a)
    (refuse 'revise-action' 'only a proposed action can be revised')
  =/  title=@t  (gs:orr jon 'title')
  ?:  |(=('' title) (gth (met 3 title) max-title:orr))
    (refuse 'revise-action' 'title: required')
  =/  payload=json  (gj:orr jon 'payload')
  ?.  |(?=(~ payload) ?=([%o *] payload))
    (refuse 'revise-action' 'payload: an object, or absent')
  ?:  (gth (met 3 (en:json:html payload)) max-payload:orr)
    (refuse 'revise-action' 'payload: over 4000 bytes')
  =/  raw=(list json)  (ga:orr jon 'about')
  =/  about=(set @t)  (sy (strings:orr raw))
  ?:  (gth ~(wyt in about) max-about:orr)  (refuse 'revise-action' 'about: over 20')
  ;<  missing=(unit bid:orr)  bind:m  (first-missing 0 ~(tap in about))
  ?^  missing  (refuse 'revise-action' (cat 3 'about: no such body ' u.missing))
  =/  due-s=@t  (gs:orr jon 'due')
  =/  due=(unit @da)  ?:(=('' due-s) ~ (de-iso-any:orr due-s))
  ?:  &(!=('' due-s) =(~ due))  (refuse 'revise-action' 'due: not a time')
  ;<  now=@da  bind:m  get-time:io
  =/  next=action:orr  (revise:orr a title payload about due who now)
  ;<  ship=@t  bind:m  (body-attr 0 (gs:orr payload 'to') 'ship')
  =/  routed  (reroute-on-revise:orr a next ship)
  =.  next  a.routed
  ;<  ~  bind:m  ?:(=('' note.routed) (pure:(fiber:fiber:nexus ,~) ~) (note 'revise-action' & note.routed))
  ;<  ~  bind:m  (over:io road [[/orrery %action] `stored-action:orr`[%2 next]])
  ;<  ~  bind:m  (note-by 'revise-action' & '' who)
  (pure:m &)
::  +do-set-doc: replace schema.json or policy.json whole. An unchanged
::  document is a no-op, not a write, so the beacon does not move.
::
++  do-set-doc
  |=  [name=@ta op=@t jon=json]
  =/  m  (fiber:fiber:nexus ,?)
  ^-  form:m
  =/  doc=json  (gj:orr jon 'doc')
  ?.  ?=([%o *] doc)  (refuse op 'doc: an object is required')
  ;<  cur=json  bind:m  (read-json (rf 0 / name))
  ?:  =(cur doc)  (note-then-no op 'unchanged')
  ;<  ~  bind:m  (over:io (rf 0 / name) [[/ %json] doc])
  ;<  ~  bind:m  (note op & '')
  (pure:m &)
::  +compact: cull a body's observations that are superseded, expired
::  or retracted and older than the retention. A live one never goes.
::
::    A row ages by the later of when it became true and when the ship
::    recorded it, so a fact learned today about five years ago is kept
::    for the retention from today, not culled the moment it is
::    superseded.
::
++  compact
  |=  [kind=@tas slug=@ta terms=compact-terms]
  =/  m  (fiber:fiber:nexus ,~)
  ^-  form:m
  ;<  now=@da  bind:m  get-time:io
  =/  horizon=@da  horizon.terms
  ;<  vw=view:nexus  bind:m  (peek:io (rv 0 (body-dir kind slug)) ~)
  ?.  ?=([%ball *] vw)  (pure:m ~)
  =/  rows=(list row:orr)  (rows-in:om ball.vw)
  =/  winners  (fold:orr rows multi.terms now)
  =/  dead=(list @ta)
    %+  murn  rows
    |=  r=row:orr
    ^-  (unit @ta)
    ?:  (gte (max at.obs.r seen.obs.r) horizon)  ~
    =/  st=@tas  (status-of:orr r winners now)
    ?:(?=(?(%superseded %expired %retracted) st) `id.r ~)
  (cull-each 0 (obs-dir kind slug) dead)
++  cull-each
  |=  [up=@ud dir=path names=(list @ta)]
  =/  m  (fiber:fiber:nexus ,~)
  ^-  form:m
  ?~  names  (pure:m ~)
  ;<  *  bind:m  (cull-soft:io (rf up dir i.names))
  (cull-each up dir t.names)
::  +compact-terms, +read-compact-terms: the retention horizon and the
::  multi set, read once for every compact an op runs
::
+$  compact-terms  [horizon=@da multi=(set @t)]
++  read-compact-terms
  =/  m  (fiber:fiber:nexus ,compact-terms)
  ^-  form:m
  ;<  now=@da  bind:m  get-time:io
  ;<  policy=json  bind:m  (read-json (rf 0 / %'policy.json'))
  ;<  schema=json  bind:m  (read-json (rf 0 / %'schema.json'))
  =/  span=@dr  (mul (retention-of:orr policy) ~d1)
  (pure:m [?:((lth now span) ~1970.1.1 (sub now span)) (multi-of:orr schema)])
++  compact-each
  |=  ids=(list bid:orr)
  =/  m  (fiber:fiber:nexus ,~)
  ^-  form:m
  ;<  terms=compact-terms  bind:m  read-compact-terms
  |-
  ?~  ids  (pure:m ~)
  =/  pk  (parse-bid:orr i.ids)
  ;<  ~  bind:m
    ?~  pk  (pure:(fiber:fiber:nexus ,~) ~)
    (compact kind.u.pk slug.u.pk terms)
  $(ids t.ids)
::  +serve-body: one body with its attributes, its situations, the open
::  actions about it, and its full timeline newest first
::
++  serve-body
  |=  [eyre-id=@ta kind=@ta slug=@ta args=quay:eyre act=actor]
  =/  m  (fiber:fiber:nexus ,~)
  ^-  form:m
  ;<  now=@da  bind:m  get-time:io
  =/  when=(unit @da)  (when-arg args now)
  ?~  when  (send-err eyre-id 400 'at: expected an ISO 8601 UTC time')
  =/  id=bid:orr  (rap 3 kind '/' slug ~)
  ?~  (parse-bid:orr id)  (send-err eyre-id 400 'expected <kind>/<slug>')
  ;<  schema=json  bind:m  (read-json (rf 1 / %'schema.json'))
  ;<  policy=json  bind:m  (read-json (rf 1 / %'policy.json'))
  =/  hide=(set @t)  (hidden-for act policy)
  ;<  all0=(list loaded:orr)  bind:m  (load-bodies 1)
  =/  all=(list loaded:orr)  all:(view-of act all0 ~ hide)
  =/  mine=(unit loaded:orr)  (loaded-of:orr all id)
  ?~  mine  (send-err eyre-id 404 'no such body')
  ;<  acts0=(list [id=@ta a=action:orr])  bind:m  (load-actions 1)
  =/  acts=(list [id=@ta a=action:orr])  acts:(view-of act ~ acts0 hide)
  =/  multi=(set @t)  (multi-of:orr schema)
  (send-json eyre-id 200 (body-json:orr u.mine (situations:orr all multi u.when) acts multi u.when))
::  +serve-delete-body: DELETE one body, and drop whatever share it had
::
++  serve-delete-body
  |=  [eyre-id=@ta kind=@ta slug=@ta]
  =/  m  (fiber:fiber:nexus ,~)
  ^-  form:m
  =/  id=bid:orr  (rap 3 kind '/' slug ~)
  =/  pk  (parse-bid:orr id)
  ?~  pk  (send-err eyre-id 400 'expected <kind>/<slug>')
  ;<  ex=?  bind:m  (peek-exists:io (rv 1 /bodies/[kind]/[slug]))
  ?.  ex  (send-err eyre-id 404 'no such body')
  =/  op=json  (pairs:enjs:format ~[['op' s+'delete-body'] ['id' s+id]])
  %^  write-then  eyre-id  op
  ;<  ~  bind:m  (drop-share kind.u.pk slug.u.pk id)
  (send-json eyre-id 200 (pairs:enjs:format ~[['id' s+id] ['ok' b+&]]))
::  +drop-share: a deleted body is shared with nobody. The record goes
::  and the group is rewritten with no ships, so the peek grant that
::  outlives the body goes with it.
::
++  drop-share
  |=  [kind=@tas slug=@ta id=bid:orr]
  =/  m  (fiber:fiber:nexus ,~)
  ^-  form:m
  ;<  shares=json  bind:m  (read-json (rf 1 / %'shares.json'))
  =/  all=(map @t json)  ?:(?=([%o *] shares) p.shares ~)
  ?.  (~(has by all) id)  (pure:m ~)
  ;<  ~  bind:m  (over:io (rf 1 / %'shares.json') [[/ %json] [%o (~(del by all) id)]])
  ;<  base=(unit path)  bind:m  self-base
  ?~  base
    (note-inbox-at 1 'delete-body' | 'cannot find where this app is installed' '')
  (set-share-group u.base kind slug ~)
::  +serve-merge: POST one body folded into another, owner only. The
::  route checks what the writer refuses, so a client hears 400 or 404
::  rather than a silent refusal in the trail, and counts what the write
::  will move from the same tree the writer reads: a write answers
::  before it applies.
::
++  serve-merge
  |=  [eyre-id=@ta jon=json]
  =/  m  (fiber:fiber:nexus ,~)
  ^-  form:m
  =/  from=@t  (gs:orr jon 'from')
  =/  into=@t  (gs:orr jon 'into')
  ?:  =(from into)  (send-err eyre-id 400 'from and into are the same body')
  ?:  =('person/me' from)  (send-err eyre-id 400 'person/me cannot be merged away')
  =/  fk  (parse-bid:orr from)
  ?~  fk  (send-err eyre-id 404 (cat 3 'no such body ' from))
  =/  ik  (parse-bid:orr into)
  ?~  ik  (send-err eyre-id 404 (cat 3 'no such body ' into))
  ;<  now=@da  bind:m  get-time:io
  ;<  all=(list loaded:orr)  bind:m  (load-bodies 1)
  =/  src=(unit loaded:orr)  (loaded-of:orr all from)
  ?~  src  (send-err eyre-id 404 (cat 3 'no such body ' from))
  =/  dst=(unit loaded:orr)  (loaded-of:orr all into)
  ?~  dst  (send-err eyre-id 404 (cat 3 'no such body ' into))
  =/  moved=@ud  (lent (move-rows:orr rows.u.src rows.u.dst into))
  =/  repointed=@ud  (lent (ref-rows:orr all from now))
  =/  op=json
    (pairs:enjs:format ~[['op' s+'merge'] ['from' s+from] ['into' s+into]])
  %^  write-then  eyre-id  op
  ;<  ~  bind:m  (drop-share kind.u.fk slug.u.fk from)
  %^  send-json  eyre-id  200
  %-  pairs:enjs:format
  :~  ['from' s+from]
      ['into' s+into]
      ['moved' (numb:enjs:format moved)]
      ['repointed' (numb:enjs:format repointed)]
      ['ok' b+&]
  ==
::  +serve-resolve: a name to the bodies it could mean, best match
::  first, over the bodies this actor may see
::
::    The answer emits id, kind, name and match, never an attribute, but
::    resolve matches on the folded email and phone, so a key that may
::    not see a sensitive attribute must not be able to confirm one by
::    asking for it: the hidden set is the actor's.
::
++  serve-resolve
  |=  [eyre-id=@ta args=quay:eyre act=actor]
  =/  m  (fiber:fiber:nexus ,~)
  ^-  form:m
  =/  q=@t  (fall (get-key:kv:html-utils 'q' args) '')
  ;<  now=@da  bind:m  get-time:io
  ;<  schema=json  bind:m  (read-json (rf 1 / %'schema.json'))
  ;<  policy=json  bind:m  (read-json (rf 1 / %'policy.json'))
  ;<  all0=(list loaded:orr)  bind:m  (load-bodies 1)
  =/  all=(list loaded:orr)  all:(view-of act all0 ~ (hidden-for act policy))
  =/  multi=(set @t)  (multi-of:orr schema)
  =/  bodies=(list [id=bid:orr =body:orr winners=(map @t (list row:orr))])
    (turn all |=(l=loaded:orr [id.l body.l (fold:orr rows.l multi now)]))
  %^  send-json  eyre-id  200
  :-  %a
  %+  turn  (resolve:orr q bodies)
  |=  [id=bid:orr =body:orr match=@tas]
  ^-  json
  (pairs:enjs:format ~[['id' s+id] ['kind' s+kind.body] ['name' s+name.body] ['match' s+match]])
::  +serve-retract: mark one observation retracted. A row the actor may
::  not see answers 404, never a refusal that would confirm it exists.
::
++  serve-retract
  |=  [eyre-id=@ta jon=json act=actor]
  =/  m  (fiber:fiber:nexus ,~)
  ^-  form:m
  =/  id=@t  (gs:orr jon 'id')
  ?:  =('' id)  (send-err eyre-id 400 'id: required')
  =/  why=@t  (gs:orr jon 'note')
  ?:  (gth (met 3 why) max-note:orr)  (send-err eyre-id 400 'note: over 500 bytes')
  ;<  hit=(unit [kind=@tas slug=@ta r=row:orr])  bind:m  (find-obs 1 `@ta`id)
  ?~  hit  (send-err eyre-id 404 'no such observation')
  ;<  policy=json  bind:m  (read-json (rf 1 / %'policy.json'))
  ::  a row whose value points at a body outside the key's kinds is
  ::  veiled on every view: retracting its real id would confirm the
  ::  hidden body the veil refuses to name
  =/  ref-ok=?
    ?~  scope.act  &
    =/  target=(unit bid:orr)  (ref-of:orr value.obs.r.u.hit)
    ?~  target  &
    =/  tk  (parse-bid:orr u.target)
    ?~  tk  &
    (kind-in-scope:orr u.scope.act kind.u.tk)
  =/  visible=?
    ?~  scope.act  &
    ?&  (kind-in-scope:orr u.scope.act kind.u.hit)
        !(~(has in (hidden-for act policy)) attr.obs.r.u.hit)
        ref-ok
    ==
  ?.  visible  (send-err eyre-id 404 'no such observation')
  ?:  &(?=(^ scope.act) !write.u.scope.act)  (send-err eyre-id 403 'read only key')
  =/  who=@t  ?:(owner.act ?:(=('' (gs:orr jon 'by')) 'http' (gs:orr jon 'by')) by.act)
  =/  op=json
    (pairs:enjs:format ~[['op' s+'retract'] ['id' s+id] ['note' s+why] ['by' s+who]])
  %^  write-then  eyre-id  op
  (send-json eyre-id 200 (pairs:enjs:format ~[['id' s+id] ['ok' b+&]]))
::  +serve-bodies: POST one body, laid or replaced. A key never sends a
::  ship: identity is the owner's to assign.
::
++  serve-bodies
  |=  [eyre-id=@ta jon=json act=actor]
  =/  m  (fiber:fiber:nexus ,~)
  ^-  form:m
  ;<  now=@da  bind:m  get-time:io
  =/  got  (de-body:orr jon now)
  ?:  ?=(%| -.got)  (send-err eyre-id 400 p.got)
  =/  pk  (parse-bid:orr id.p.got)
  ?~  pk  (send-err eyre-id 400 'id: bad')
  =/  denied=(unit @t)  (deny-write act kind.u.pk)
  ?^  denied  (send-err eyre-id 403 u.denied)
  ::  identity is the owner's to assign: a key never sends a ship
  ?:  &(?=(^ scope.act) ?=(^ (gj:orr jon 'ship')))
    (send-err eyre-id 403 'not in scope: ship')
  ;<  ex=?  bind:m  (peek-exists:io (rf 1 (body-dir kind.u.pk slug.u.pk) %body))
  =/  op=json  (pairs:enjs:format ~[['op' s+'upsert-body'] ['body' jon]])
  %^  write-then  eyre-id  op
  (send-json eyre-id 200 (pairs:enjs:format ~[['id' s+id.p.got] ['ok' b+&] ['existing' b+ex]]))
::  +serve-act: a proposal. The request stamps proposed and by, decodes
::  once for its answer, and the writer decodes the same JSON, so both
::  compute the same id. An open twin answers the existing action.
::
++  serve-act
  |=  [eyre-id=@ta jon=json act=actor]
  =/  m  (fiber:fiber:nexus ,~)
  ^-  form:m
  ;<  now=@da  bind:m  get-time:io
  =/  stamped=json  ?:(owner.act (fill-act:orr jon now 'http') (fill-act-as:orr jon now by.act))
  =/  got  (de-action:orr stamped now by.act)
  ?:  ?=(%| -.got)  (send-err eyre-id 400 p.got)
  ::  403 here: the key sent the kind itself; a stored id it may not see is a 404
  ?:  &(?=(^ scope.act) !(action-in-scope:orr u.scope.act kind.p.got))
    (send-err eyre-id 403 (cat 3 'not in scope: ' kind.p.got))
  =/  outside=(unit bid:orr)
    ?~  scope.act  ~
    =/  s=scope:orr  u.scope.act
    %+  roll  ~(tap in about.p.got)
    |=  [b=bid:orr acc=(unit bid:orr)]
    ^-  (unit bid:orr)
    ?^  acc  acc
    =/  pk  (parse-bid:orr b)
    ?~  pk  ~
    ?:((kind-in-scope:orr s kind.u.pk) ~ `b)
  ?^  outside  (send-err eyre-id 400 (cat 3 'about: no such body ' u.outside))
  ;<  missing=(unit bid:orr)  bind:m  (first-missing 1 ~(tap in about.p.got))
  ?^  missing  (send-err eyre-id 400 (cat 3 'about: no such body ' u.missing))
  ;<  policy=json  bind:m  (read-json (rf 1 / %'policy.json'))
  ;<  all=(list [id=@ta a=action:orr])  bind:m  (load-actions 1)
  =/  twin=(unit [id=@ta a=action:orr])  (open-twin all kind.p.got title.p.got)
  ?^  twin
    %^  send-json  eyre-id  200
    (pairs:enjs:format ~[['id' s+id.u.twin] ['status' s+status.a.u.twin] ['existing' b+&]])
  =/  a=action:orr  p.got(status (initial-status:orr kind.p.got (auto-of:orr policy)))
  ::  the writer's own decode of stamped runs the same channel rule on
  ::  the same 'to', so this echoes the id the writer will actually
  ::  store under, ship or no ship
  ;<  r=[a=action:orr note=@t]  bind:m  (route-to 1 a)
  =.  a  a.r
  =/  op=json  (pairs:enjs:format ~[['op' s+'act'] ['action' stamped]])
  %^  write-then  eyre-id  op
  %^  send-json  eyre-id  200
  (pairs:enjs:format ~[['id' s+(act-id:orr a)] ['status' s+status.a] ['existing' b+|]])
::  +serve-actions: ?status=open (the default: proposed, approved and
::  claimed), all, or one status; newest first
::
++  serve-actions
  |=  [eyre-id=@ta args=quay:eyre act=actor]
  =/  m  (fiber:fiber:nexus ,~)
  ^-  form:m
  =/  want=@t  (fall (get-key:kv:html-utils 'status' args) 'open')
  ;<  all0=(list [id=@ta a=action:orr])  bind:m  (load-actions 1)
  =/  all=(list [id=@ta a=action:orr])  acts:(view-of act ~ all0 ~)
  =/  keep
    |=  [id=@ta a=action:orr]
    ^-  ?
    ?:  =('all' want)  &
    ?:  =('open' want)  (is-open:orr a)
    =(want `@t`status.a)
  =/  shown=(list [id=@ta a=action:orr])
    %+  sort  (skim all keep)
    |=([x=[id=@ta a=action:orr] y=[id=@ta a=action:orr]] (gth proposed.a.x proposed.a.y))
  (send-json eyre-id 200 a+(turn shown |=([id=@ta a=action:orr] (en-action:orr id a))))
::  +serve-set-action: POST a new status for one action. The transition
::  is checked here as well as in the writer, so the client gets a 409
::  rather than a silent refusal in the trail.
::
++  serve-set-action
  |=  [eyre-id=@ta id=@ta jon=json act=actor]
  =/  m  (fiber:fiber:nexus ,~)
  ^-  form:m
  ?.  ?=([%o *] jon)  (send-err eyre-id 400 'expected an object')
  =/  want=@t  (gs:orr jon 'status')
  =/  why=@t  (gs:orr jon 'note')
  ?:  (gth (met 3 why) max-note:orr)  (send-err eyre-id 400 'note: over 500 bytes')
  ;<  got=(each action:orr [code=@ud msg=@t])  bind:m  (scoped-action id act)
  ?:  ?=(%| -.got)  (send-err eyre-id code.p.got msg.p.got)
  =/  said=@t  ?:(owner.act (gs:orr jon 'by') by.act)
  =/  who=@t  ?:(=('' said) 'user' said)
  ;<  now=@da  bind:m  get-time:io
  =/  no=(unit @t)  (move-refusal:orr p.got `@tas`want who now)
  ?^  no  (send-err eyre-id 409 u.no)
  =/  op=json  (set-action-op:orr id want why who)
  %^  write-then  eyre-id  op
  %^  send-json  eyre-id  200
  (pairs:enjs:format ~[['id' s+id] ['status' s+want] ['by' s+who] ['ok' b+&]])
::  +serve-refine: POST /api/actions/<id>/refine {"text"}, the owner's
::  note under a proposed action (version 36). The checks are the ones
::  +serve-set-action makes: the owner, or a key whose actions name the
::  kind and whose scope writes. /refining/<id> is the lock, so one
::  refinement runs per action at a time. A lock older than five
::  minutes was left by a crashed route and is dropped rather than
::  obeyed. The work is +refine-run's, so the lock is dropped on every
::  answer.
::
++  serve-refine
  |=  [eyre-id=@ta id=@ta jon=json act=actor]
  =/  m  (fiber:fiber:nexus ,~)
  ^-  form:m
  ?.  ?=([%o *] jon)  (send-err eyre-id 400 'expected an object')
  =/  text=@t  (trim-cord:orr (gs:orr jon 'text'))
  ?:  =('' text)  (send-err eyre-id 400 'text: required')
  ?:  (gth (met 3 text) 2.000)  (send-err eyre-id 400 'text: over 2000 bytes')
  ;<  got=(each action:orr [code=@ud msg=@t])  bind:m  (scoped-action id act)
  ?:  ?=(%| -.got)  (send-err eyre-id code.p.got msg.p.got)
  =/  a=action:orr  p.got
  ?.  =(%proposed status.a)  (send-err eyre-id 409 'only a proposed action can be refined')
  ;<  now=@da  bind:m  get-time:io
  =/  lock=road:tarball  (rf 1 /refining id)
  ;<  first=(unit @t)  bind:m  (lock-stamp id)
  ::  A lock with no readable stamp counts as older than any bound.
  =/  at=@da  ?~(first *@da (fall (de-iso:orr u.first) *@da))
  ?:  &(?=(^ first) (lth now (add at ~m5)))  (send-err eyre-id 409 'a refinement is running')
  ::  A stale lock is dropped only while it is the one read above. One
  ::  with another stamp by now is a fresh request's, and stands.
  ;<  same=?  bind:m
    ?~  first  (pure:(fiber:fiber:nexus ,?) &)
    ;<  again=(unit @t)  bind:(fiber:fiber:nexus ,?)  (lock-stamp id)
    (pure:(fiber:fiber:nexus ,?) =(first again))
  ?.  same  (send-err eyre-id 409 'a refinement is running')
  ;<  ~  bind:m  ?~(first (pure:(fiber:fiber:nexus ,~) ~) (drop-lock id))
  ::  The make is the arbiter: two requests can pass the checks at once,
  ::  and the second make fails on the name, the way a resent telegram
  ::  update's does.
  ;<  err=(unit tang)  bind:m
    (make-soft:io lock |+[[[/ %json] (pairs:enjs:format ~[['at' s+(en-iso:orr now)]])] ~])
  ?^  err  (send-err eyre-id 409 'a refinement is running')
  ;<  got=[code=@ud body=json]  bind:m  (refine-run a id text act now)
  ;<  ~  bind:m  (drop-lock id)
  (send-json eyre-id code.got body.got)
::  +lock-stamp: the at of the lock on an action, ~ when there is no
::  lock, '' when the lock has no readable stamp.
::
++  lock-stamp
  |=  id=@ta
  =/  m  (fiber:fiber:nexus ,(unit @t))
  ^-  form:m
  =/  lock=road:tarball  (rf 1 /refining id)
  ;<  held=?  bind:m  (peek-exists:io lock)
  ?.  held  (pure:m ~)
  ;<  jon=json  bind:m  (read-json lock)
  (pure:m `(gs:orr jon 'at'))
++  drop-lock
  |=  id=@ta
  =/  m  (fiber:fiber:nexus ,~)
  ^-  form:m
  ;<  *  bind:m  (cull-soft:io (rf 1 /refining id))
  (pure:m ~)
::  +refine-run: the model call and the filing, as a status and a body.
::  The prompt carries the action, the schema's kinds and payload
::  shapes, the bodies the note could mean and the owner's clock. The
::  answer is held to the reader's checks by +refine-check, then filed
::  as at most an observe, the revision and one act per extra. A poke
::  to the writer resolves when the writer takes it, not when the write
::  lands, so the fiber keeps the beacon and settles before it reads
::  the revision back; and the writer may refuse what it took, so the
::  extras are filed only once the action's last step says the
::  revision landed. A key sees the bodies its kinds allow and no
::  other, in the prompt's action as in its context, files no extra
::  outside its actions, and reads the answer through the same view
::  its action list gives it; the links it could not see stay on the
::  revised action.
::
++  refine-run
  |=  [a=action:orr id=@ta text=@t act=actor now=@da]
  =/  m  (fiber:fiber:nexus ,[code=@ud body=json])
  ^-  form:m
  =/  fail  |=([code=@ud msg=@t] ^-([code=@ud body=json] [code (err-json:orr msg)]))
  ;<  cfg-j=json  bind:m  (read-json (rf 1 / %'generator.json'))
  =/  cfg=config:orr  (de-config:orr cfg-j)
  ?:  =('' api-key.cfg)  (pure:m (fail 503 'the generator has no key'))
  ;<  schema=json  bind:m  (read-json (rf 1 / %'schema.json'))
  ;<  policy=json  bind:m  (read-json (rf 1 / %'policy.json'))
  ;<  all0=(list loaded:orr)  bind:m  (load-bodies 1)
  =/  all=(list loaded:orr)  all:(view-of act all0 ~ (hidden-for act policy))
  =/  ctx=reader-ctx:orr  (reader-context:orr all schema now)
  ::  The kinds a refinement may touch are the reader's: a merge or a
  ::  home action has no shape the prompt could hold a rewrite to.
  ?.  (lien kinds.ctx |=(k=@t =(k `@t`kind.a)))
    (pure:m (fail 409 'only a task, a calendar event or a message can be refined'))
  =/  tz=@t
    =/  mine=@t  (attr-text:orr all0 (multi-of:orr schema) now 'person/me' 'timezone')
    ?:(=('' mine) timezone.cfg mine)
  =/  who=@t  ?:(owner.act 'user' by.act)
  =/  shown=action:orr  (seen-by act a)
  ;<  got=[status=@ud body=@t secs=@ud]  bind:m
    %:  post-json
      (cat 3 url.cfg '/chat/completions')
      api-key.cfg
      (chat-body-with:orr cfg refine-prompt:orr ~[(refine-user:orr shown id ctx text now tz)])
      ~m2
      %refine
    ==
  ?.  =(200 status.got)
    %-  pure:m
    %+  fail  502
    ?:  =(0 status.got)  (cat 3 'no answer from the model: ' body.got)
    (rap 3 'the model answered ' (crip (a-co:co status.got)) ~)
  =/  ans  (answer-of:orr (fall (de:json:html body.got) [%o ~]))
  ?:  ?=(%| -.ans)  (pure:m (fail 502 p.ans))
  =/  parsed=(unit json)  (parse-answer:orr text.p.ans)
  ?~  parsed  (pure:m (fail 502 'the model answered without JSON'))
  =/  checked  (refine-check:orr u.parsed shown id ctx now)
  ?:  ?=(%| -.checked)
    (pure:m [200 (pairs:enjs:format ~[['ok' b+|] ['note' s+p.checked]])])
  =/  unseen=(list @t)  (skip ~(tap in about.a) |=(x=@t (~(has in about.shown) x)))
  ::  An extra of a kind outside a key's actions is dropped with a note:
  ::  the key could not have proposed it through /act either.
  =/  scoped=[extras=(list json) notes=(list @t)]
    ?~  scope.act  [extras.p.checked ~]
    =/  s=scope:orr  u.scope.act
    %+  roll  extras.p.checked
    |=  [e=json acc=[extras=(list json) notes=(list @t)]]
    ^-  [extras=(list json) notes=(list @t)]
    ?:  (action-in-scope:orr s `@tas`(gs:orr e 'kind'))  [(snoc extras.acc e) notes.acc]
    [extras.acc (snoc notes.acc (rap 3 'dropped extra ' (gs:orr e 'title') ': not in this key\'s actions' ~))]
  =/  held=refined:orr
    %=  p.checked
      about   (scag 20 (dedupe:orr (weld about.p.checked unseen)))
      extras  extras.scoped
      notes   (weld notes.p.checked notes.scoped)
    ==
  =/  ops=(list json)  (refine-ops:orr held id who now)
  =/  is-act  |=(o=json =('act' (gs:orr o 'op')))
  =/  acts=(list json)  (skim ops is-act)
  ;<  *  bind:m  (keep:io /refine (rf 1 /beacon %rev) ~)
  ;<  ~  bind:m  (poke-each 1 (skip ops is-act))
  ;<  ~  bind:m  (settle /refine)
  ;<  found=(each action:orr ?(%absent %unreadable))  bind:m  (load-action 1 id)
  =/  revised=(unit action:orr)  ?:(?=(%& -.found) `p.found ~)
  ?~  revised  (pure:m (fail 500 'the revised action cannot be read back'))
  ::  The writer's refusal leaves the action as it was, so a last step
  ::  that is not this request's revision means the note did not land.
  =/  took=?
    ?~  history.u.revised  |
    =/  last=step:orr  (rear history.u.revised)
    &(=(%revised status.last) (gte at.last now))
  ?.  took
    (pure:m [200 (pairs:enjs:format ~[['ok' b+|] ['note' s+'the action moved while the note was applied']])])
  ;<  ~  bind:m  (poke-each 1 acts)
  ;<  ~  bind:m  ?~(acts (pure:(fiber:fiber:nexus ,~) ~) (settle /refine))
  ;<  filed=[views=(list json) notes=(list @t)]  bind:m  (extras-filed acts now who act)
  %-  pure:m
  :-  200
  %-  pairs:enjs:format
  :~  ['ok' b+&]
      ['action' (en-action:orr id (seen-by act u.revised))]
      ['extras' a+views.filed]
      ['note' s+(join-cords:orr '\0a' (weld notes.held notes.filed))]
  ==
::  +seen-by: an action as an actor's view shows it: whole for the
::  owner, its about trimmed to the key's kinds, as +view-of trims the
::  action list
::
++  seen-by
  |=  [act=actor a=action:orr]
  ^-  action:orr
  ?~(scope.act a (scope-about:orr a kinds.u.scope.act))
::  +poke-each: each op to the writer in turn, from a fiber up steps
::  below the root. +file-ops is the generator's and reaches the root
::  directly, so a request fiber needs its own.
::
++  poke-each
  |=  [up=@ud ops=(list json)]
  =/  m  (fiber:fiber:nexus ,~)
  ^-  form:m
  ?~  ops  (pure:m ~)
  ;<  ~  bind:m  (poke-writer up i.ops)
  (poke-each up t.ops)
::  +extras-filed: the view of each extra the writer filed, found under
::  the id the writer computed. The channel rule runs on an extra as on
::  any act, so the same rule runs here before the id is taken. An
::  extra not found was refused as a twin, and becomes a note.
::
++  extras-filed
  |=  [ops=(list json) now=@da who=@t act=actor]
  =/  m  (fiber:fiber:nexus ,[views=(list json) notes=(list @t)])
  ^-  form:m
  =|  acc=[views=(list json) notes=(list @t)]
  |-
  ?~  ops  (pure:m [(flop views.acc) (flop notes.acc)])
  ?.  =('act' (gs:orr i.ops 'op'))  $(ops t.ops)
  =/  got  (de-action:orr (gj:orr i.ops 'action') now who)
  ?:  ?=(%| -.got)  $(ops t.ops)
  ;<  r=[a=action:orr note=@t]  bind:m  (route-to 1 p.got)
  =/  eid=@ta  (act-id:orr a.r)
  ;<  found=(each action:orr ?(%absent %unreadable))  bind:m  (load-action 1 eid)
  =/  e=(unit action:orr)  ?:(?=(%& -.found) `p.found ~)
  ?~  e
    =/  why=@t  (rap 3 'extra ' title.p.got ' was not filed, the trail says why' ~)
    $(ops t.ops, notes.acc [why notes.acc])
  $(ops t.ops, views.acc [(en-action:orr eid (seen-by act u.e)) views.acc])
::  +serve-doc: schema.json or policy.json, as stored
::
++  serve-doc
  |=  [eyre-id=@ta name=@ta]
  =/  m  (fiber:fiber:nexus ,~)
  ^-  form:m
  ;<  doc=json  bind:m  (read-json (rf 1 / name))
  (send-json eyre-id 200 doc)
::  +serve-generate: run a pass now, whatever the digest says
::
++  serve-generate
  |=  [eyre-id=@ta jon=json act=actor]
  =/  m  (fiber:fiber:nexus ,~)
  ^-  form:m
  ::  run-now is the owner's. A key with write in its scope asks for an
  ::  urgent pass by sending about: the situations to look at first, or
  ::  an empty list. That pass runs past the cooldown, under max_urgent.
  =/  urgent=?  (has-key:orr jon 'about')
  ?:  &(!owner.act !urgent)
    (send-err eyre-id 403 'run-now is the owner\'s; a key asks for an urgent pass with about')
  ?:  &(!owner.act |(?=(~ scope.act) !write.u.scope.act))
    (send-err eyre-id 403 'a key needs write in its scope to ask for an urgent pass')
  =/  about=(list @t)  (scag 5 (strings:orr (ga:orr jon 'about')))
  =/  body=json
    %-  pairs:enjs:format
    %-  zing
    :~  ~[['force' b+&]]
        ?.(urgent ~ ~[['about' a+(turn about |=(a=@t `json`s+a))]])
    ==
  ;<  err=(unit tang)  bind:m
    (poke-soft:io (rf 1 / %'gen.sig') [[/ %json] body])
  ?^  err  (send-err eyre-id 500 'the generator fiber refused the poke')
  (send-json eyre-id 200 (pairs:enjs:format ~[['ok' b+&] ['urgent' b+urgent]]))
::  +serve-reconcile: run the reconcile passes now
::
++  serve-reconcile
  |=  eyre-id=@ta
  =/  m  (fiber:fiber:nexus ,~)
  ^-  form:m
  ;<  err=(unit tang)  bind:m
    (poke-soft:io (rf 1 / %'reconcile.sig') [[/ %json] [%o ~]])
  ?^  err  (send-err eyre-id 500 'the reconcile fiber refused the poke')
  (send-json eyre-id 200 (pairs:enjs:format ~[['ok' b+&]]))
::  +file-ops: each op to the writer in turn, as a soft poke, then a
::  settle: a soft poke resolves when the writer takes it, not when its
::  write lands, so the next read would see the state before the ops
::  (a merge claimed at 23:13:09 and never run, 2026-09-19). The count
::  is what the writer took; a refusal inside the writer is not seen
::  here, it leaves the writer standing.
::
++  file-ops
  |=  ops=(list json)
  =/  m  (fiber:fiber:nexus ,@ud)
  ^-  form:m
  (file-ops-on ops /rec)
::  +file-ops-on: +file-ops for a fiber keeping its news on another wire
::
++  file-ops-on
  |=  [ops=(list json) wire=path]
  =/  m  (fiber:fiber:nexus ,@ud)
  ^-  form:m
  =|  n=@ud
  |-
  ?~  ops
    ;<  ~  bind:m  ?:(=(0 n) (pure:(fiber:fiber:nexus ,~) ~) (settle wire))
    (pure:m n)
  ;<  err=(unit tang)  bind:m
    (poke-soft:io (rf 0 / %'main.sig') [[/ %json] i.ops])
  $(ops t.ops, n ?~(err +(n) n))
::  +settle: wait until the news on the wire has been still for two
::  seconds. The writer bumps the beacon after each change, so a burst
::  of ops is one wait for the fiber keeping it; a run-now poke arriving
::  meanwhile is taken and dropped, the pass is already running.
::
++  settle
  |=  wire=path
  =/  m  (fiber:fiber:nexus ,~)
  ^-  form:m
  ;<  now=@da  bind:m  get-time:io
  ;<  ~  bind:m  (set-timer:io /quiet (add now ~s2))
  |-
  ;<  in=gen-in  bind:m  (take-gen-in wire)
  ?:  ?=(%wake -.in)  (pure:m ~)
  ?:  ?=(%poke -.in)  $
  ;<  ~  bind:m  (cancel-timer:io /quiet)
  ;<  now=@da  bind:m  get-time:io
  ;<  ~  bind:m  (set-timer:io /quiet (add now ~s2))
  $
::  +run-merges: the approved merge actions, each claimed, merged and
::  reported: done when from is gone and into remains, failed otherwise.
::  A claim another executor holds is left alone.
::
++  run-merges
  |=  todo=(list [id=@ta from=bid:orr into=bid:orr])
  =/  m  (fiber:fiber:nexus ,@ud)
  ^-  form:m
  =|  n=@ud
  |-
  ?~  todo  (pure:m n)
  =/  aid=@ta  id.i.todo
  ;<  *  bind:m  (file-ops ~[(set-action-op:orr aid 'claimed' '' 'reconcile')])
  ;<  acts=(list [id=@ta a=action:orr])  bind:m  (load-actions 0)
  =/  mine=?
    %+  lien  acts
    |=([id=@ta a=action:orr] &(=(id aid) =(%claimed status.a) =('reconcile' (claimant:orr a))))
  ?.  mine  $(todo t.todo)
  ;<  *  bind:m  (file-ops ~[(merge-op:orr from.i.todo into.i.todo)])
  ;<  all=(list loaded:orr)  bind:m  (load-bodies 0)
  =/  ok=?  &(?=(~ (loaded-of:orr all from.i.todo)) ?=(^ (loaded-of:orr all into.i.todo)))
  ;<  *  bind:m
    (file-ops ~[(set-action-op:orr aid ?:(ok 'done' 'failed') ?:(ok 'merged' 'the merge was refused') 'reconcile')])
  $(todo t.todo, n ?:(ok +(n) n))
::  +reload-if: the bodies again when ops were filed, else the ones read
::
++  reload-if
  |=  [n=@ud all=(list loaded:orr)]
  =/  m  (fiber:fiber:nexus ,(list loaded:orr))
  ^-  form:m
  ?:(=(0 n) (pure:m all) (load-bodies 0))
::  +reconcile-pass: the passes in order, the bodies re-read between
::  them when a pass filed something the next one reads; then the record
::
++  reconcile-pass
  =/  m  (fiber:fiber:nexus ,~)
  ^-  form:m
  ;<  now=@da  bind:m  get-time:io
  ;<  schema=json  bind:m  (read-json (rf 0 / %'schema.json'))
  ;<  policy=json  bind:m  (read-json (rf 0 / %'policy.json'))
  =/  multi=(set @t)  (multi-of:orr schema)
  =/  cfg  (reconcile-of:orr policy)
  ;<  all=(list loaded:orr)  bind:m  (load-bodies 0)
  =/  times=(list json)  (plan-times:orr all now)
  ;<  n=@ud  bind:m  (file-ops times)
  ;<  all=(list loaded:orr)  bind:m  (reload-if n all)
  =/  activities  (plan-activities:orr all multi now min.cfg)
  ;<  n=@ud  bind:m  (file-ops ops.activities)
  ;<  all=(list loaded:orr)  bind:m  (reload-if n all)
  =/  parts  (plan-participants:orr all multi now)
  ;<  n=@ud  bind:m  (file-ops ops.parts)
  ;<  all=(list loaded:orr)  bind:m  (reload-if n all)
  ;<  acts=(list [id=@ta a=action:orr])  bind:m  (load-actions 0)
  =/  people  (people-pass:orr all acts multi now)
  ;<  np=@ud  bind:m  (file-ops ops.people)
  ;<  acts=(list [id=@ta a=action:orr])  bind:m  (load-actions 0)
  =/  merges  (approved-merges:orr acts)
  ;<  merged=@ud  bind:m  (run-merges merges)
  ;<  all=(list loaded:orr)  bind:m  (reload-if (add np (lent merges)) all)
  =/  retire  (plan-retire:orr all multi now (mul stale.cfg ~d1))
  ;<  *  bind:m  (file-ops (retire-ops:orr retire))
  =/  expire  (plan-expire:orr all multi now)
  ;<  *  bind:m  (file-ops (expire-ops:orr expire))
  =/  prune=(list bid:orr)  (plan-prune:orr all multi now prune.cfg)
  ;<  *  bind:m  (file-ops (turn prune delete-op:orr))
  =/  doc=json
    %-  pairs:enjs:format
    :~  ['at' s+(en-iso:orr now)]
        ['times' (numb:enjs:format (lent times))]
        ['activities' a+(turn made.activities |=(b=@t `json`s+b))]
        ['people_made' (numb:enjs:format made.parts)]
        ['participants' (numb:enjs:format rows.parts)]
        ['proposed' (numb:enjs:format proposed.people)]
        ['merged' (numb:enjs:format merged)]
        ['retired' (numb:enjs:format (lent retire))]
        ['expired' (numb:enjs:format (lent expire))]
        ['pruned' (numb:enjs:format (lent prune))]
    ==
  (over:io (rf 0 / %'reconcile-last.json') [[/ %json] doc])
::  +serve-generator: the generator's settings without the key
::
++  serve-generator
  |=  eyre-id=@ta
  =/  m  (fiber:fiber:nexus ,~)
  ^-  form:m
  ;<  doc=json  bind:m  (read-json (rf 1 / %'generator.json'))
  (send-json eyre-id 200 (en-config-masked:orr (de-config:orr doc)))
::  +serve-telegram: the reader's settings without the token or secret
::
++  serve-telegram
  |=  eyre-id=@ta
  =/  m  (fiber:fiber:nexus ,~)
  ^-  form:m
  ;<  doc=json  bind:m  (read-json (rf 1 / %'telegram.json'))
  (send-json eyre-id 200 (en-tg-config-masked:orr (de-tg-config:orr doc)))
::  +serve-set-telegram: PUT the reader's settings. The route refuses a
::  short webhook secret itself, as +serve-merge checks what the writer
::  refuses, so the client hears 400 rather than a silent no in the
::  trail. A blank or absent secret is not a refusal: it keeps the
::  stored one, and a JSON null clears it.
::
++  serve-set-telegram
  |=  [eyre-id=@ta jon=json]
  =/  m  (fiber:fiber:nexus ,~)
  ^-  form:m
  ?:  (short-secret:orr jon)  (send-err eyre-id 400 'secret: 16 bytes at least')
  (serve-set-doc eyre-id 'set-telegram' jon)
::  +serve-set-webhook: the ship tells Telegram where to send updates:
::  setWebhook with the public url (a trailing slash trimmed), the
::  secret, the two update kinds the reader handles and one connection
::  at a time, since the hook's update-id check assumes the updates
::  arrive in order. Telegram's ok
::  and description come back as the answer, 502 when its status was
::  not 200; a blank token, secret or public url is a 400 before any
::  call.
::
++  serve-set-webhook
  |=  eyre-id=@ta
  =/  m  (fiber:fiber:nexus ,~)
  ^-  form:m
  ;<  cfg-j=json  bind:m  (read-json (rf 1 / %'telegram.json'))
  =/  cfg=tg-config:orr  (de-tg-config:orr cfg-j)
  ?:  |(=('' token.cfg) =('' secret.cfg) =('' public-url.cfg))
    (send-err eyre-id 400 'the token, the secret and the public URL must be set first')
  =/  base=@t
    =/  n=@ud  (met 3 public-url.cfg)
    ?:  &((gth n 0) =('/' (cut 3 [(dec n) 1] public-url.cfg)))
      (end [3 (dec n)] public-url.cfg)
    public-url.cfg
  =/  body=json
    %-  pairs:enjs:format
    :~  ['url' s+(cat 3 base '/apps/orrery/telegram')]
        ['secret_token' s+secret.cfg]
        ['allowed_updates' a+~[s+'message' s+'business_message']]
        ['max_connections' (numb:enjs:format 1)]
    ==
  ;<  got=[status=@ud body=@t secs=@ud]  bind:m
    (post-json (rap 3 api-url.cfg '/bot' token.cfg '/setWebhook' ~) '' body ~s30 %webhook)
  =/  resp=json  (fall (de:json:html body.got) [%o ~])
  %^  send-json  eyre-id  ?:(=(200 status.got) 200 502)
  (pairs:enjs:format ~[['ok' (gj:orr resp 'ok')] ['description' (gj:orr resp 'description')]])
::  +serve-webhook-info: Telegram's side of the story: the url it holds
::  for this bot, how many updates wait, and its last delivery error,
::  so a registration that did not take is read off the card rather
::  than guessed at (2026-09-21). The token is used and never shown.
::
++  serve-webhook-info
  |=  eyre-id=@ta
  =/  m  (fiber:fiber:nexus ,~)
  ^-  form:m
  ;<  cfg-j=json  bind:m  (read-json (rf 1 / %'telegram.json'))
  =/  cfg=tg-config:orr  (de-tg-config:orr cfg-j)
  ?:  =('' token.cfg)  (send-err eyre-id 400 'no token set')
  ;<  got=[status=@ud body=@t secs=@ud]  bind:m
    (get-json (rap 3 api-url.cfg '/bot' token.cfg '/getWebhookInfo' ~) ~s30 %webhook-info)
  =/  resp=json  (fall (de:json:html body.got) [%o ~])
  =/  r=json  (gj:orr resp 'result')
  %^  send-json  eyre-id  ?:(=(200 status.got) 200 502)
  %-  pairs:enjs:format
  :~  ['ok' (gj:orr resp 'ok')]
      ['description' (gj:orr resp 'description')]
      ['url' (gj:orr r 'url')]
      ['pending_update_count' (gj:orr r 'pending_update_count')]
      ['last_error_date' (gj:orr r 'last_error_date')]
      ['last_error_message' (gj:orr r 'last_error_message')]
      ['max_connections' (gj:orr r 'max_connections')]
      ['allowed_updates' (gj:orr r 'allowed_updates')]
  ==
::  +serve-prod: the owner pokes a fiber's sig: a live reader drains
::  the inbox now (an update the model could not read waits on a five
::  minute timer otherwise), a live executor or follower runs a pass
::  now, and a crashed one restarts on the poke, since nothing else
::  pokes it
::
++  serve-prod
  |=  [eyre-id=@ta sig=@ta what=@t]
  =/  m  (fiber:fiber:nexus ,~)
  ^-  form:m
  ;<  err=(unit tang)  bind:m  (poke-soft:io (rf 1 / sig) [[/ %sig] ~])
  ?^  err  (send-err eyre-id 500 (rap 3 'the ' what ' fiber refused the poke' ~))
  (send-json eyre-id 200 (pairs:enjs:format ~[['ok' b+&]]))
::  +serve-telegram-hook: an update from Telegram. The secret header must
::  equal the stored secret; the update goes to the inbox as its own grub
::  and the request answers at once, since Telegram gives up on a slow
::  answer and sends the update again. A disabled reader drops it. An
::  update resent is handled once: update ids are monotonic per bot, so
::  one not past the record's was handled already and is dropped as
::  seen (its inbox file culled), and one still in the inbox fails the
::  make on its name; the rev bump still wakes the reader.
::
++  serve-telegram-hook
  |=  [eyre-id=@ta req=inbound-request:eyre]
  =/  m  (fiber:fiber:nexus ,~)
  ^-  form:m
  ;<  cfg-j=json  bind:m  (read-json (rf 1 / %'telegram.json'))
  =/  cfg=tg-config:orr  (de-tg-config:orr cfg-j)
  =/  given=@t
    (fall (get-header:http 'x-telegram-bot-api-secret-token' header-list.request.req) '')
  ?:  |(=('' secret.cfg) !=(given secret.cfg))  (send-err eyre-id 403 'forbidden')
  ?:  &(?=(^ body.request.req) (gth p.u.body.request.req 65.536))
    (send-err eyre-id 413 'too large')
  ?.  enabled.cfg
    (send-json eyre-id 200 (pairs:enjs:format ~[['ok' b+&] ['dropped' s+'the reader is off']]))
  =/  jon=json  (fall (de:json:html ?~(body.request.req '' q.u.body.request.req)) ~)
  =/  uid=@ud  (fall (gn:orr jon 'update_id') 0)
  ;<  last=json  bind:m  (read-json (rf 1 / %'telegram-last.json'))
  ?.  (gth uid (fall (gn:orr last 'update_id') 0))
    (send-json eyre-id 200 (pairs:enjs:format ~[['ok' b+&] ['dropped' s+'seen']]))
  ::  twelve digits, so the inbox lists in update order as text
  =/  name=@ta  `@ta`(crip ((d-co:co 12) uid))
  ;<  *  bind:m  (make-soft:io (rf 1 /telegram-inbox name) |+[[[/ %json] jon] ~])
  ;<  ~  bind:m  (over:io (rf 1 /telegram-inbox %rev) [[/ %json] (numb:enjs:format uid)])
  (send-json eyre-id 200 (pairs:enjs:format ~[['ok' b+&]]))
::  +serve-set-doc: PUT one of those documents, through the writer
::
++  serve-set-doc
  |=  [eyre-id=@ta op=@t jon=json]
  =/  m  (fiber:fiber:nexus ,~)
  ^-  form:m
  ?.  ?=([%o *] jon)  (send-err eyre-id 400 'a JSON object is required')
  =/  pk=json  (pairs:enjs:format ~[['op' s+op] ['doc' jon]])
  %^  write-then  eyre-id  pk
  (send-json eyre-id 200 (pairs:enjs:format ~[['ok' b+&]]))
::  ==  sharing: where things are
::
::  +orrery-instance: the desk path a peer's orrery is assumed to sit
::  at. Only the first offer uses it; every later poke follows the base
::  that offer carried, which is why a peer that installed orrery
::  elsewhere answers notified false (docs/sharing.md).
::
++  orrery-instance  `path`/apps/'shell.shell'/desks/'orrery.desk'/desk/data/'orrery.orrery_app'
::  +ug-base: where this ship keeps its usergroups
::
++  ug-base     `path`/sys/ames/usergroups
::  +public-grp: the group every ship is in, whose weir carries the road
::  to our inbox
::
++  public-grp  `path`/sys/ames/usergroups/'public.grp'
::  +self-base: where this instance lives, from the shell's link registry
::  (/sys/link/orrery/dest.lanes: every instance claiming the name, ours
::  among them). ~ when the road is refused or the registry has no row.
::
++  self-base  (find-base %orrery)
::  +find-base: where an app claiming a link name lives: the first lane
::  in /sys/link/<name>/dest.lanes. The executor finds the calendar and
::  auspex this way. ~ when the road is refused or the registry has no
::  row.
::
++  find-base
  |=  name=@ta
  =/  m  (fiber:fiber:nexus ,(unit path))
  ^-  form:m
  ;<  vw=(unit view:nexus)  bind:m  (peek-soft:io [%& %& /sys/link/[name] %'dest.lanes'] ~)
  ?.  ?=([~ %file *] vw)  (pure:m ~)
  =/  ls=(unit (set lane:tarball))
    (mole |.(!<((set lane:tarball) (need-vase:tarball sang.u.vw))))
  ?~  ls  (pure:m ~)
  =/  dirs=(list path)
    (murn ~(tap in u.ls) |=(=lane:tarball ?:(?=(%| -.lane) `p.lane ~)))
  ?~  dirs  (pure:m ~)
  ::  an arbitrary lane: a desk app cannot learn its own path, so two
  ::  instances claiming the name leave nothing here to tell them apart
  (pure:m `i.dirs)
::  +ug-read-weir: a usergroup's how, read whole, the way calendar reads
::  its share groups
::
++  ug-read-weir
  |=  gdir=path
  =/  m  (fiber:fiber:nexus ,weir:nexus)
  ^-  form:m
  ;<  hv=(unit view:nexus)  bind:m  (peek-soft:io [%& %& gdir %'how.weir'] ~)
  ?~  hv  (pure:m *weir:nexus)
  ?.  ?=([%file *] u.hv)  (pure:m *weir:nexus)
  (pure:m (fall (mole |.(;;(weir:nexus (sang-noun:tarball sang.u.hv)))) *weir:nexus))
::  +ug-set: a usergroup's who and how, written whole: the ships in it
::  and the roads they reach through it
::
++  ug-set
  |=  [gname=@t ships=(set @p) pk=(set road:tarball) pok=(set road:tarball)]
  =/  m  (fiber:fiber:nexus ,~)
  ^-  form:m
  =/  gdir=path  (snoc ug-base (crip (weld (trip gname) ".grp")))
  ;<  old=weir:nexus  bind:m  (ug-read-weir gdir)
  =/  =weir:nexus  [make.old pok pk]
  ;<  ~  bind:m  (over:io [%& %& gdir %'who.ships'] [[/ %ships] ships])
  ;<  ~  bind:m  (over:io [%& %& gdir %'how.weir'] [[/ %weir] weir])
  (pure:m ~)
::  +set-share-group: the ships a body is shared with may peek its
::  directory. Edit mode adds nothing here: any ship may poke the inbox,
::  and the inbox checks the share record before it applies an edit.
::
++  set-share-group
  |=  [base=path kind=@tas slug=@ta mine=(map @t json)]
  =/  m  (fiber:fiber:nexus ,~)
  ^-  form:m
  =/  ships=(set @p)
    %-  ~(gas in *(set @p))
    (murn ~(tap by mine) |=([s=@t *] (slaw %p s)))
  =/  dir=road:tarball  [%& %| (weld base /bodies/[kind]/[slug])]
  (ug-set (group-name:orr kind slug) ships (sy ~[dir]) ~)
::  +lay-inbox-road: our shares.sig takes pokes from any ship, through
::  the /public group's weir. Quiet when the roads are refused: sharing
::  is optional.
::
++  lay-inbox-road
  =/  m  (fiber:fiber:nexus ,~)
  ^-  form:m
  ;<  base=(unit path)  bind:m  self-base
  ?~  base  (pure:m ~)
  ;<  old=weir:nexus  bind:m  (ug-read-weir public-grp)
  =/  road=road:tarball  [%& %& u.base %'shares.sig']
  ?:  (~(has in poke.old) road)  (pure:m ~)
  ;<  reg=(unit tang)  bind:m  (reg-register-at-soft:io [u.base %'shares.sig'])
  ?^  reg  (pure:m ~)
  ;<  err=(unit tang)  bind:m  (reg-how-soft:io /public [~ (sy road ~) ~])
  (pure:m ~)
::  +remote-poke-wait: a poke to another ship's grubbery, answered or
::  timed out (a peer that is down must not park the fiber). A timer
::  wake answers yes: grubbery's remote acks are unobservable and the
::  poke usually landed. A veto or a nack answers no.
::
++  remote-poke-wait
  |=  [target=@p =lane:tarball jon=json]
  =/  m  (fiber:fiber:nexus ,?)
  ^-  form:m
  ;<  now=@da  bind:m  get-time:io
  ;<  tw=wire  bind:m  (nonce:io /remote)
  =/  req=load:remo:nexus  [[/share-poke lane] %poke [[/ %json] jon]]
  ;<  w=wire  bind:m  (nonce:io /share-poke)
  ;<  ~  bind:m
    %-  send-dart:io
    [%node w &+&+[/sys/gall %'main.sig'] %poke [[/ %gall-poke] [[target %grubbery] grubbery-load+req]]]
  ;<  ~  bind:m  (set-timer:io tw (add now ~s30))
  ;<  ok=?  bind:m
    |=  input:fiber:nexus
    :+  ~  q.state
    ?+  in  [%skip ~]
        ~  [%wait ~]
        [~ %veto %node * * *]
      ?.(=(w wire.dart.u.in) [%skip ~] [%done %.n])
        [~ %pack * *]
      ?.  =(w wire.u.in)  [%skip ~]
      ?~(err.u.in [%wait ~] [%done %.n])
        [~ %poke * *]
      ?:  =([/ %timer-wake] p.sage.u.in)
        ?.(=(tw !<(path q.sage.u.in)) [%skip ~] [%done %.y])
      ?.  =([/ %poke-ack] p.sage.u.in)  [%skip ~]
      =/  [aw=wire err=(unit tang)]  !<([wire (unit tang)] q.sage.u.in)
      ?.  =(w aw)  [%skip ~]
      [%done ?=(~ err)]
    ==
  ;<  ~  bind:m  (cancel-timer:io tw)
  (pure:m ok)
::  +peek-remote-wait: a deep peek of another ship's file or directory,
::  ~ on veto, miss or timeout
::
++  peek-remote-wait
  |=  [target=@p road=road:tarball]
  =/  m  (fiber:fiber:nexus ,(unit view:nexus))
  ^-  form:m
  ;<  now=@da  bind:m  get-time:io
  =/  until=@da  (add now ~s30)
  ;<  tw=wire  bind:m  (nonce:io /remote)
  ;<  pw=wire  bind:m  (nonce:io /peek)
  =/  rr=road:tarball
    ?-  -.road
      %|  road
      %&
        =/  prefix=path  /sys/ames/ships/[(scot %p target)]/root
        ?-  -.p.road
          %&  [%& %& (weld prefix path.p.p.road) name.p.p.road]
          %|  [%& %| (weld prefix p.p.road)]
        ==
    ==
  ;<  ~  bind:m  (send-dart:io %node pw rr %peek ~ ~ %.y)
  ;<  ~  bind:m  (set-timer:io tw until)
  ;<  got=(unit view:nexus)  bind:m
    |=  input:fiber:nexus
    :+  ~  q.state
    ?+  in  [%skip ~]
        ~  [%wait ~]
        [~ %veto %node * * *]
      ?.(=(pw wire.dart.u.in) [%skip ~] [%done ~])
        [~ %peek * *]
      ?.(=(pw wire.u.in) [%skip ~] [%done `view.u.in])
        [~ %poke * *]
      ?.  =([/ %timer-wake] p.sage.u.in)  [%skip ~]
      ?.(=(tw !<(path q.sage.u.in)) [%skip ~] [%done ~])
    ==
  ;<  ~  bind:m  (cancel-timer:io tw)
  (pure:m got)
::  ==  the inbox
::
::  +take-inbox: one poke from another ship: an offer, a revoke, or
::  observations on a body we shared with it in edit mode
::
++  take-inbox
  |=  [src=@p =sage:tarball]
  =/  m  (fiber:fiber:nexus ,~)
  ^-  form:m
  =/  jon=json  (fall (mole |.(!<(json q.sage))) ~)
  =/  act=@t  (gs:orr jon 'action')
  =/  id=@t  (gs:orr jon 'id')
  ?:  =(~ (parse-bid:orr id))
    (note-inbox 'inbox' | 'id: expected <kind>/<slug>' (scot %p src))
  =/  key=@t  (share-key:orr src id)
  ?:  =('offer' act)  (take-offer src key id jon)
  ?:  =('revoke' act)  (take-revoke src key)
  ?:  =('observe' act)  (take-edit src id jon)
  (note-inbox 'inbox' | 'unknown action' (scot %p src))
::  +take-offer: a host offers a body. An offer for a share already
::  accepted narrows its mode in place; a wider one waits for an accept.
::
++  take-offer
  |=  [src=@p key=@t id=bid:orr jon=json]
  =/  m  (fiber:fiber:nexus ,~)
  ^-  form:m
  ;<  now=@da  bind:m  get-time:io
  =/  mode=@t  ?:(=('edit' (gs:orr jon 'mode')) 'edit' 'read')
  =/  oship=@t  (gs:orr jon 'ship')
  ?:  &(!=('' oship) ?=(~ (slaw %p oship)))  (note-inbox 'offer' | 'ship: expected an @p' (scot %p src))
  ?:  (gth (met 3 (gs:orr jon 'name')) max-name:orr)  (note-inbox 'offer' | 'name: over 200 bytes' (scot %p src))
  ?:  (gth (met 3 (gs:orr jon 'base')) 200)  (note-inbox 'offer' | 'base: over 200 bytes' (scot %p src))
  ;<  rm=(map @t json)  bind:m  (read-map (rf 0 / %'ship-remotes.json'))
  ?:  (~(has by rm) key)
    =/  row=json  (fall (~(get by rm) key) ~)
    ?.  ?=([%o *] row)  (note-inbox 'offer' | 'accepted row unreadable' (scot %p src))
    ::  a share we accepted: a narrower mode applies at once, a wider
    ::  one is a new offer, since it would change what we send the host
    ?:  &(=('edit' mode) !=('edit' (gs:orr row 'mode')))
      (file-offer src key id mode now jon)
    =/  next=json  [%o (~(put by p.row) 'mode' s+mode)]
    ;<  ~  bind:m  (over:io (rf 0 / %'ship-remotes.json') [[/ %json] [%o (~(put by rm) key next)]])
    ::  a wider offer filed earlier goes with the narrowing, so it can
    ::  no longer be accepted after the host changed its mind
    ;<  cur=(map @t json)  bind:m  (read-map (rf 0 / %'share-offers.json'))
    ;<  ~  bind:m
      ?.  (~(has by cur) key)  (pure:(fiber:fiber:nexus ,~) ~)
      (over:io (rf 0 / %'share-offers.json') [[/ %json] [%o (~(del by cur) key)]])
    (note-inbox 'offer' & 'mode updated' (scot %p src))
  (file-offer src key id mode now jon)
::  +file-offer: the offer waits in share-offers.json for an accept
::
++  file-offer
  |=  [src=@p key=@t id=bid:orr mode=@t now=@da jon=json]
  =/  m  (fiber:fiber:nexus ,~)
  ^-  form:m
  ;<  offers=json  bind:m  (read-json (rf 0 / %'share-offers.json'))
  =/  cur=(map @t json)  ?:(?=([%o *] offers) p.offers ~)
  ::  a full inbox drops new offers; 200 is far past what a person gets
  ?:  &((gte ~(wyt by cur) 200) !(~(has by cur) key))
    (note-inbox 'offer' | 'inbox full' (scot %p src))
  =/  offer=json
    %-  pairs:enjs:format
    :~  ['host' s+(scot %p src)]
        ['id' s+id]
        ['ship' s+(gs:orr jon 'ship')]
        ['name' s+(gs:orr jon 'name')]
        ['mode' s+mode]
        ['base' s+(gs:orr jon 'base')]
        ['at' (en-time:orr now)]
    ==
  ;<  ~  bind:m  (over:io (rf 0 / %'share-offers.json') [[/ %json] [%o (~(put by cur) key offer)]])
  (note-inbox 'offer' & key (scot %p src))
::  +take-revoke: the offer and the accepted row go; the mirrored
::  observations stay, with the host still named as their source
::
++  take-revoke
  |=  [src=@p key=@t]
  =/  m  (fiber:fiber:nexus ,~)
  ^-  form:m
  ;<  cur=(map @t json)  bind:m  (read-map (rf 0 / %'share-offers.json'))
  ;<  ~  bind:m  (over:io (rf 0 / %'share-offers.json') [[/ %json] [%o (~(del by cur) key)]])
  ;<  rm=(map @t json)  bind:m  (read-map (rf 0 / %'ship-remotes.json'))
  ;<  ~  bind:m  (over:io (rf 0 / %'ship-remotes.json') [[/ %json] [%o (~(del by rm) key)]])
  (note-inbox 'revoke' & key (scot %p src))
::  +take-edit: a peer's observations on a body we shared with it in
::  edit mode. The share record decides; every row must name the shared
::  body; by and source become the sender before the writer sees them.
::
++  take-edit
  |=  [src=@p id=bid:orr jon=json]
  =/  m  (fiber:fiber:nexus ,~)
  ^-  form:m
  ;<  shares=json  bind:m  (read-json (rf 0 / %'shares.json'))
  =/  mode=@t  (gs:orr (gj:orr shares id) (scot %p src))
  ?.  =('edit' mode)  (note-inbox 'edit' | 'not shared in edit mode' (scot %p src))
  ::  the body may have been deleted since the share was recorded
  =/  pk  (parse-bid:orr id)
  ?~  pk  (note-inbox 'edit' | 'no such body here' (scot %p src))
  ;<  here=?  bind:m  (peek-exists:io (rf 0 (body-dir kind.u.pk slug.u.pk) %body))
  ?.  here  (note-inbox 'edit' | 'no such body here' (scot %p src))
  =/  got=(list json)  (ga:orr jon 'observations')
  ?:  (gth (lent got) max-obs:orr)  (note-inbox 'edit' | 'observations: over 200' (scot %p src))
  =/  rows=(list json)
    %+  skim  got
    |=(j=json &(?=([%o *] j) =(id (gs:orr j 'subject'))))
  ?~  rows  (note-inbox 'edit' | 'nothing about the shared body' (scot %p src))
  ;<  r=[pokes=@ud refused=(list [oid=@t why=@t])]  bind:m
    (apply-carried 0 src `(list json)`rows)
  =/  bad=(list [oid=@t why=@t])  refused.r
  =/  head=@t
    (rap 3 (scot %ud (lent rows)) ' rows, ' (scot %ud pokes.r) ' pokes' ~)
  =/  why=@t
    ?~  bad  head
    (rap 3 head ', ' (scot %ud (lent bad)) ' refused: ' why.i.bad ~)
  (note-inbox 'edit' & why (scot %p src))
::  ==  carried rows: what another ship sent, or what we read from it
::
::  +apply-carried: rows from one ship about one of our bodies (the
::  subject is ours already). A row we do not hold becomes an
::  observation from that ship, through the writer; a row we hold that
::  the ship retracted since is retracted here. Every received row is
::  decoded here first, so a row the writer would refuse is answered
::  instead of vanishing. Answers the writer pokes and the refusals.
::
++  apply-carried
  |=  [up=@ud src=@p rows=(list json)]
  =/  m  (fiber:fiber:nexus ,[pokes=@ud refused=(list [oid=@t why=@t])])
  ^-  form:m
  ?~  rows  (pure:m [0 ~])
  =/  subject=bid:orr  (gs:orr i.rows 'subject')
  =/  pk  (parse-bid:orr subject)
  ?~  pk  (pure:m [0 ~])
  ;<  vw=view:nexus  bind:m  (peek:io (rv up (body-dir kind.u.pk slug.u.pk)) ~)
  ?.  ?=([%ball *] vw)  (pure:m [0 ~])
  =/  pre=@t  (rap 3 (scot %p src) '/' ~)
  ::  what we hold from this ship, by the sender's grub name
  =/  held=(map @t [oid=@ta retracted=?])
    %-  ~(gas by *(map @t [oid=@ta retracted=?]))
    %+  murn  (rows-in:om ball.vw)
    |=  r=row:orr
    ^-  (unit [@t [@ta ?]])
    ?.  (from-ship:orr obs.r src)  ~
    `[(rsh [3 (met 3 pre)] id.source.obs.r) id.r retracted.obs.r]
  =/  all=(list json)  `(list json)`rows
  ;<  now=@da  bind:m  get-time:io
  =/  received=(list [oid=@t j=json])
    %+  murn  all
    |=  j=json
    ^-  (unit [@t json])
    ?.  =(subject (gs:orr j 'subject'))  ~
    ?:  (~(has by held) (gs:orr j 'oid'))  ~
    ?:  =(`json`b+& (gj:orr j 'retracted'))  ~
    `[(gs:orr j 'oid') (receive-obs:orr src j)]
  =/  split=[ok=(list json) bad=(list [oid=@t why=@t])]
    %+  roll  received
    |=  [[oid=@t j=json] acc=[ok=(list json) bad=(list [oid=@t why=@t])]]
    =/  d  (de-obs:orr j now (scot %p src))
    ?:  ?=(%& -.d)  acc(ok [j ok.acc])
    acc(bad [[oid p.d] bad.acc])
  =/  fresh=(list json)  (flop ok.split)
  =/  gone=(list @ta)
    %+  murn  all
    |=  j=json
    ^-  (unit @ta)
    ?.  =(subject (gs:orr j 'subject'))  ~
    =/  h=(unit [oid=@ta retracted=?])  (~(get by held) (gs:orr j 'oid'))
    ?~  h  ~
    ?.  &(=(`json`b+& (gj:orr j 'retracted')) !retracted.u.h)  ~
    `oid.u.h
  ::  the retract pokes are capped, so the count answers for the cap
  =/  dead=(list @ta)  (scag max-obs:orr gone)
  ;<  ~  bind:m  (observe-fresh up fresh)
  ;<  ~  bind:m  (retract-each up src dead)
  (pure:m [(add ?~(fresh 0 1) (lent dead)) (flop bad.split)])
::  +poke-writer: one op to our writer, soft (a refusal is noted there)
::
++  poke-writer
  |=  [up=@ud op=json]
  =/  m  (fiber:fiber:nexus ,~)
  ^-  form:m
  ;<  *  bind:m  (poke-soft:io (rf up / %'main.sig') [[/ %json] op])
  (pure:m ~)
::  +observe-fresh: the rows we do not hold yet, as one observe op
::
++  observe-fresh
  |=  [up=@ud fresh=(list json)]
  =/  m  (fiber:fiber:nexus ,~)
  ^-  form:m
  ?~  fresh  (pure:m ~)
  %+  poke-writer  up
  %-  pairs:enjs:format
  :~  ['op' s+'observe']
      ['via' s+'ship']
      ['bodies' [%a ~]]
      ['observations' a+(scag max-obs:orr `(list json)`fresh)]
  ==
::  +retract-each: retractions carried from a ship, one writer poke each
::
++  retract-each
  |=  [up=@ud src=@p oids=(list @ta)]
  =/  m  (fiber:fiber:nexus ,~)
  ^-  form:m
  ?~  oids  (pure:m ~)
  =/  why=@t  (rap 3 'retracted on ' (scot %p src) ~)
  ;<  ~  bind:m
    %+  poke-writer  up
    %-  pairs:enjs:format
    :~  ['op' s+'retract']
        ['via' s+'ship']
        ['id' s+i.oids]
        ['note' s+why]
        ['by' s+(scot %p src)]
    ==
  (retract-each up src t.oids)
::  ==  the share routes, on request fibers
::
::  +serve-share: share a body with a ship: the record, the grant, the
::  offer to the peer's inbox
::
++  serve-share
  |=  [eyre-id=@ta jon=json]
  =/  m  (fiber:fiber:nexus ,~)
  ^-  form:m
  =/  id=@t  (gs:orr jon 'id')
  =/  pk  (parse-bid:orr id)
  ?~  pk  (send-err eyre-id 400 'id: expected <kind>/<slug>')
  =/  shp=(unit @p)  (slaw %p (gs:orr jon 'ship'))
  ?~  shp  (send-err eyre-id 400 'ship: expected an @p')
  ;<  our=@p  bind:m  get-our:io
  ?:  =(u.shp our)  (send-err eyre-id 400 'ship: that is this ship')
  =/  mode=@t  ?:(=('edit' (gs:orr jon 'mode')) 'edit' 'read')
  ;<  cur=view:nexus  bind:m  (peek:io (rf 1 (body-dir kind.u.pk slug.u.pk) %body) ~)
  ?.  ?=([%file *] cur)  (send-err eyre-id 404 'no such body')
  =/  b=(unit body:orr)  (read-body:orr (sang-noun:tarball sang.cur))
  ?~  b  (send-err eyre-id 500 'unreadable body')
  ;<  base=(unit path)  bind:m  self-base
  ?~  base  (send-err eyre-id 500 'cannot find where this app is installed')
  ;<  shares=json  bind:m  (read-json (rf 1 / %'shares.json'))
  =/  all=(map @t json)  ?:(?=([%o *] shares) p.shares ~)
  =/  mine=(map @t json)  =/(j (~(get by all) id) ?:(?=([~ %o *] j) p.u.j ~))
  =.  mine  (~(put by mine) (scot %p u.shp) s+mode)
  ;<  ~  bind:m  (over:io (rf 1 / %'shares.json') [[/ %json] [%o (~(put by all) id [%o mine])]])
  ;<  ~  bind:m  (set-share-group u.base kind.u.pk slug.u.pk mine)
  ;<  told=?  bind:m
    %^  remote-poke-wait  u.shp  [%& orrery-instance %'shares.sig']
    %-  pairs:enjs:format
    :~  ['action' s+'offer']
        ['id' s+id]
        ['ship' `json`?~(ship.u.b ~ s+(scot %p u.ship.u.b))]
        ['name' s+name.u.b]
        ['mode' s+mode]
        ['base' s+(spat u.base)]
    ==
  (send-json eyre-id 200 (pairs:enjs:format ~[['ok' b+&] ['notified' b+told]]))
::  +serve-revoke: the ship leaves the record and the group, and is told
::
++  serve-revoke
  |=  [eyre-id=@ta kind=@ta slug=@ta ship=@ta]
  =/  m  (fiber:fiber:nexus ,~)
  ^-  form:m
  =/  id=bid:orr  (rap 3 kind '/' slug ~)
  =/  pk  (parse-bid:orr id)
  ?~  pk  (send-err eyre-id 400 'expected <kind>/<slug>')
  =/  shp=(unit @p)  (slaw %p ship)
  ?~  shp  (send-err eyre-id 400 'ship: expected an @p')
  ;<  base=(unit path)  bind:m  self-base
  ?~  base  (send-err eyre-id 500 'cannot find where this app is installed')
  ;<  shares=json  bind:m  (read-json (rf 1 / %'shares.json'))
  =/  all=(map @t json)  ?:(?=([%o *] shares) p.shares ~)
  =/  mine=(map @t json)  =/(j (~(get by all) id) ?:(?=([~ %o *] j) p.u.j ~))
  ?.  (~(has by mine) (scot %p u.shp))  (send-err eyre-id 404 'not shared with that ship')
  =.  mine  (~(del by mine) (scot %p u.shp))
  ::  the grant goes first: a crash between the two leaves a record
  ::  claiming a share that cannot be read, never a grant with no record
  ;<  ~  bind:m  (set-share-group u.base kind.u.pk slug.u.pk mine)
  ;<  ~  bind:m
    (over:io (rf 1 / %'shares.json') [[/ %json] [%o ?:(=(~ mine) (~(del by all) id) (~(put by all) id [%o mine]))]])
  ;<  *  bind:m
    %^  remote-poke-wait  u.shp  [%& orrery-instance %'shares.sig']
    (pairs:enjs:format ~[['action' s+'revoke'] ['id' s+id]])
  (send-json eyre-id 200 (pairs:enjs:format ~[['ok' b+&]]))
::  +serve-shares: what we share, what was offered to us, what we accepted
::
++  serve-shares
  |=  eyre-id=@ta
  =/  m  (fiber:fiber:nexus ,~)
  ^-  form:m
  ;<  shares=json  bind:m  (read-json (rf 1 / %'shares.json'))
  ;<  offers=json  bind:m  (read-json (rf 1 / %'share-offers.json'))
  ;<  rows=json  bind:m  (read-json (rf 1 / %'ship-remotes.json'))
  (send-json eyre-id 200 (pairs:enjs:format ~[['shares' shares] ['offers' offers] ['accepted' rows]]))
::  +serve-accept: an offered body becomes ours to follow. The target is
::  a local body that already carries the offered ship, else where
::  +mirror-target puts it; the body is laid through the writer only
::  when the target is absent, so an accept never renames or re-ships a
::  body of ours. The row is written and the follower prodded.
::
++  serve-accept
  |=  [eyre-id=@ta jon=json]
  =/  m  (fiber:fiber:nexus ,~)
  ^-  form:m
  =/  host=(unit @p)  (slaw %p (gs:orr jon 'host'))
  ?~  host  (send-err eyre-id 400 'host: expected an @p')
  =/  id=@t  (gs:orr jon 'id')
  =/  key=@t  (share-key:orr u.host id)
  ;<  cur=(map @t json)  bind:m  (read-map (rf 1 / %'share-offers.json'))
  =/  offer=(unit json)  (~(get by cur) key)
  ?~  offer  (send-err eyre-id 404 'no such offer')
  ;<  our=@p  bind:m  get-our:io
  =/  oship=(unit @p)  (slaw %p (gs:orr u.offer 'ship'))
  ::  a ship is an identity: a local body already carrying the offered
  ::  ship is the body the offer is about, whatever either side calls it
  ;<  all=(list loaded:orr)  bind:m  (load-bodies 1)
  =/  same-ship=(unit bid:orr)
    ?~  oship  ~
    =/  hits=(list loaded:orr)  (skim all |=(l=loaded:orr =(oship ship.body.l)))
    ?~(hits ~ `id.i.hits)
  =/  target=bid:orr  (fall same-ship (mirror-target:orr our u.host oship id))
  =/  tpk  (parse-bid:orr target)
  ?~  tpk  (send-err eyre-id 400 'id: bad')
  ::  person/me counts as existing the way +first-missing counts it: the
  ::  request queued +ensure-me ahead of this, and an upsert would
  ::  rename our own self to whatever the host calls us
  ;<  ex=?  bind:m  (peek-exists:io (rf 1 (body-dir kind.u.tpk slug.u.tpk) %body))
  ;<  ~  bind:m
    ?:  |(ex =('person/me' target))  (pure:(fiber:fiber:nexus ,~) ~)
    %+  poke-writer  1
    %-  pairs:enjs:format
    :~  ['op' s+'upsert-body']
        :-  'body'
        %-  pairs:enjs:format
        :~  ['id' s+target]
            ['name' s+(gs:orr u.offer 'name')]
            ['ship' `json`?~(oship ~ s+(scot %p u.oship))]
        ==
    ==
  ;<  rm=(map @t json)  bind:m  (read-map (rf 1 / %'ship-remotes.json'))
  =/  old=json  (fall (~(get by rm) key) [%o ~])
  ::  what we already pushed counts only if we were pushing: a row that
  ::  was read mode until now has sent the host nothing
  =/  kept=json
    ?.  =('edit' (gs:orr old 'mode'))  [%o ~]
    =/(p (gj:orr old 'pushed') ?:(?=([%o *] p) p [%o ~]))
  =/  row=json
    %-  pairs:enjs:format
    :~  ['host' s+(scot %p u.host)]
        ['id' s+id]
        ['target' s+target]
        ['mode' s+(gs:orr u.offer 'mode')]
        ['base' s+(gs:orr u.offer 'base')]
        ['pushed' kept]
        ['last' s+'']
        ['error' s+'']
    ==
  ;<  ~  bind:m  (over:io (rf 1 / %'ship-remotes.json') [[/ %json] [%o (~(put by rm) key row)]])
  ;<  ~  bind:m  (over:io (rf 1 / %'share-offers.json') [[/ %json] [%o (~(del by cur) key)]])
  ;<  *  bind:m  (poke-soft:io (rf 1 / %'sync.sig') [[/ %sig] ~])
  (send-json eyre-id 200 (pairs:enjs:format ~[['ok' b+&] ['target' s+target]]))
::  +serve-decline: an offer we do not want leaves the inbox. Nothing is
::  told to the host: an offer is not a claim on us
::
++  serve-decline
  |=  [eyre-id=@ta jon=json]
  =/  m  (fiber:fiber:nexus ,~)
  ^-  form:m
  =/  host=(unit @p)  (slaw %p (gs:orr jon 'host'))
  ?~  host  (send-err eyre-id 400 'host: expected an @p')
  =/  key=@t  (share-key:orr u.host (gs:orr jon 'id'))
  ;<  cur=(map @t json)  bind:m  (read-map (rf 1 / %'share-offers.json'))
  ;<  ~  bind:m  (over:io (rf 1 / %'share-offers.json') [[/ %json] [%o (~(del by cur) key)]])
  (send-json eyre-id 200 (pairs:enjs:format ~[['ok' b+&]]))
::  ==  the follower: what other ships shared with us
::
::  +sync-pass: every accepted share: mirror the host's rows, push ours
::  back in edit mode, and record the pass on the row
::
++  sync-pass
  =/  m  (fiber:fiber:nexus ,~)
  ^-  form:m
  ;<  rows-j=json  bind:m  (read-json (rf 0 / %'ship-remotes.json'))
  =/  rows=(list [key=@t row=json])  ?:(?=([%o *] rows-j) ~(tap by p.rows-j) ~)
  (sync-rows rows ~)
::  +sync-rows: one row at a time; the file is re-read before the write
::  so an accept or a revoke that landed during the pass is kept
::
++  sync-rows
  |=  [rows=(list [key=@t row=json]) done=(map @t json)]
  =/  m  (fiber:fiber:nexus ,~)
  ^-  form:m
  ?~  rows
    ?:  =(~ done)  (pure:m ~)
    ;<  cur=(map @t json)  bind:m  (read-map (rf 0 / %'ship-remotes.json'))
    =/  merged=(map @t json)
      %+  roll  ~(tap by done)
      |=  [[key=@t row=json] acc=_cur]
      =/  live=(unit json)  (~(get by acc) key)
      ?~  live  acc
      ?.  &(?=([%o *] u.live) ?=([%o *] row))  acc
      =/  keep=(list [@t json])
        :~  ['last' (gj:orr row 'last')]
            ['error' (gj:orr row 'error')]
            ['pushed' (gj:orr row 'pushed')]
            ['refused' (gj:orr row 'refused')]
        ==
      (~(put by acc) key [%o (~(gas by p.u.live) keep)])
    (over:io (rf 0 / %'ship-remotes.json') [[/ %json] [%o merged]])
  ;<  next=json  bind:m  (sync-one row.i.rows)
  (sync-rows t.rows (~(put by done) key.i.rows next))
::  +sync-one: one accepted share, answering the row with last, error,
::  pushed and refused brought up to date. A row the host holds that our
::  decoder will not take is noted in /tr/inbox once, not every pass.
::
++  sync-one
  |=  row=json
  =/  m  (fiber:fiber:nexus ,json)
  ^-  form:m
  ?.  ?=([%o *] row)  (pure:m row)
  ;<  now=@da  bind:m  get-time:io
  ;<  policy=json  bind:m  (read-json (rf 0 / %'policy.json'))
  =/  hide=(set @t)  (sensitive-of:orr policy)
  =/  host=(unit @p)  (slaw %p (gs:orr row 'host'))
  ?~  host  (pure:m [%o (~(put by p.row) 'error' s+'host: expected an @p')])
  =/  id=bid:orr  (gs:orr row 'id')
  =/  target=bid:orr  (gs:orr row 'target')
  =/  base=path  (fall (mole |.((stab (gs:orr row 'base')))) orrery-instance)
  ;<  mir=[err=(unit @t) refused=(list [oid=@t why=@t])]  bind:m
    (mirror-pass u.host id target base)
  =/  err=(unit @t)  err.mir
  =/  bad=(list [oid=@t why=@t])  refused.mir
  ::  a refusal is noted once: the same host row is refused every pass
  ::  the key is a peer's text, capped at 64 bytes the way the notes are
  =/  seen=(map @t json)  =/(p (gj:orr row 'refused') ?:(?=([%o *] p) p.p ~))
  ;<  ~  bind:m
    %^  note-refusals  'mirror'  (scot %p u.host)
    (skim bad |=([o=@t *] !(~(has by seen) (end [3 64] o))))
  =/  all-ref=(map @t json)
    (~(gas by seen) (turn bad |=([o=@t w=@t] [(end [3 64] o) `json`s+w])))
  =/  refused=(map @t json)
    ?:  (lte ~(wyt by all-ref) max-obs:orr)  all-ref
    (~(gas by *(map @t json)) (scag max-obs:orr ~(tap by all-ref)))
  =/  pushed=(map @t json)  =/(p (gj:orr row 'pushed') ?:(?=([%o *] p) p.p ~))
  ::  only an untroubled read earns a push: a transport ack from a host
  ::  that refused the rows must not count them as landed
  =/  run=?  &(?=(~ err) =('edit' (gs:orr row 'mode')))
  ;<  push=[ok=? pushed=(map @t json)]  bind:m
    (push-pass u.host id target base pushed run hide)
  =/  msg=@t
    ?:  ?=(^ err)  u.err
    ?.  ok.push  'the host did not take our observations (down, or the share is read only now)'
    ''
  %-  pure:m
  :-  %o
  %-  ~(gas by p.row)
  :~  ['last' (en-time:orr now)]
      ['error' s+msg]
      ['pushed' [%o pushed.push]]
      ['refused' [%o refused]]
  ==
::  +mirror-pass: the host's body directory, read whole; its own rows
::  (not ones it mirrored from elsewhere: one hop) land here as
::  observations from the host, through +apply-carried. The error for
::  the row, ~ when fine, and the host rows our decoder would not take.
::
++  mirror-pass
  |=  [host=@p id=bid:orr target=bid:orr base=path]
  =/  m  (fiber:fiber:nexus ,[err=(unit @t) refused=(list [oid=@t why=@t])])
  ^-  form:m
  =/  pk  (parse-bid:orr id)
  ?~  pk  (pure:m [[~ 'id: expected <kind>/<slug>'] ~])
  ::  a body deleted here takes its mirror with it: +apply-carried would
  ::  answer no pokes and no refusals, which reads as a clean pass
  =/  tpk  (parse-bid:orr target)
  ?~  tpk  (pure:m [[~ 'target: expected <kind>/<slug>'] ~])
  ;<  here=?  bind:m  (peek-exists:io (rf 0 (body-dir kind.u.tpk slug.u.tpk) %body))
  ?.  here
    (pure:m [[~ 'the shared body does not exist here any more'] ~])
  ;<  vw=(unit view:nexus)  bind:m
    (peek-remote-wait host [%& %| (weld base (body-dir kind.u.pk slug.u.pk))])
  ?~  vw
    (pure:m [[~ 'the host did not answer (down, or the share was revoked)'] ~])
  ?.  ?=([%ball *] u.vw)
    (pure:m [[~ 'the host no longer shares this body'] ~])
  =/  rows=(list row:orr)  (skim (rows-in:om ball.u.vw) |=(r=row:orr (is-local:orr obs.r)))
  ;<  got=[pokes=@ud refused=(list [oid=@t why=@t])]  bind:m
    (apply-carried 0 host (turn rows |=(r=row:orr (carry-obs:orr target r))))
  (pure:m [~ refused.got])
::  +push-pass: in edit mode, our own rows on the target body that the
::  host has not taken yet (or whose retraction it has not), sent to its
::  inbox. pushed maps our grub name to the retracted flag it holds.
::
::    An attribute named in policy.sensitive is never pushed. The read
::    grant cannot filter by attribute, so a body with facts the owner
::    would not share is not a body to share (docs/sharing.md); this
::    stops the one direction that can be filtered.
::
++  push-pass
  |=  $:  host=@p
          id=bid:orr
          target=bid:orr
          base=path
          pushed=(map @t json)
          run=?
          hide=(set @t)
      ==
  =/  m  (fiber:fiber:nexus ,[ok=? pushed=(map @t json)])
  ^-  form:m
  ?.  run  (pure:m [& pushed])
  =/  pk  (parse-bid:orr target)
  ?~  pk  (pure:m [& pushed])
  ;<  vw=view:nexus  bind:m  (peek:io (rv 0 (body-dir kind.u.pk slug.u.pk)) ~)
  ?.  ?=([%ball *] vw)  (pure:m [& pushed])
  =/  todo=(list row:orr)
    %+  skim  (rows-in:om ball.vw)
    |=  r=row:orr
    ?.  (is-local:orr obs.r)  |
    ?:  (~(has in hide) attr.obs.r)  |
    =/  was=(unit json)  (~(get by pushed) id.r)
    ?~  was  &
    !=(`json`b+retracted.obs.r u.was)
  ?~  todo  (pure:m [& pushed])
  =/  batch=(list row:orr)  (scag max-obs:orr `(list row:orr)`todo)
  ;<  ok=?  bind:m
    %^  remote-poke-wait  host  [%& base %'shares.sig']
    %-  pairs:enjs:format
    :~  ['action' s+'observe']
        ['id' s+id]
        ['observations' a+(turn batch |=(r=row:orr (carry-obs:orr id r)))]
    ==
  ?.  ok  (pure:m [| pushed])
  =/  next=(map @t json)
    (roll batch |=([r=row:orr acc=_pushed] (~(put by acc) id.r b+retracted.obs.r)))
  (pure:m [& next])
::  ==  the writer: keys
::
::  +force-of: whether a poke to the generator asks for a pass now
::
++  force-of
  |=  =sage:tarball
  ^-  ?
  ?.  =([/ %json] p.sage)  |
  =/  jon=json  (fall (mole |.(!<(json q.sage))) ~)
  ?=([%b %.y] (gj:orr jon 'force'))
::  +urgent-of: the about list of an urgent request, or ~ for any other
::
++  urgent-of
  |=  =sage:tarball
  ^-  (unit (list @t))
  ?.  =([/ %json] p.sage)  ~
  =/  jon=json  (fall (mole |.(!<(json q.sage))) ~)
  ?.  (has-key:orr jon 'about')  ~
  `(strings:orr (ga:orr jon 'about'))
::  +gen-in, +take-gen-in: what wakes the generator: news on the beacon
::  it keeps, a poke (run-now), or a timer. The kernel's own
::  take-news-or-poke, with the timer told apart by its path.
::
+$  gen-in  $%([%news wave:nexus] [%poke =sage:tarball] [%wake =path])
++  take-gen-in
  |=  news-wire=wire
  =/  m  (fiber:fiber:nexus ,gen-in)
  ^-  form:m
  |=  input:fiber:nexus
  :+  ~  q.state
  ?+  in  [%skip ~]
      ~  [%wait ~]
      [~ %veto *]  [%fail (veto-error:io dart.u.in)]
      [~ %news * *]
    ?.(=(news-wire wire.u.in) [%skip ~] [%done %news wave.u.in])
      [~ %poke * *]
    ?.  =([/ %timer-wake] p.sage.u.in)  [%done %poke sage.u.in]
    [%done %wake (fall (mole |.(!<(path q.sage.u.in))) /)]
  ==
::  +take-exec-in: +take-gen-in for the executor, which keeps two
::  wires: orrery's beacon on /exec and the calendar's store on /cal.
::  The kernel keys a keep by its target and the watching fiber, so the
::  two need two wires, and either one's news is a wake. A veto is taken
::  as a wake rather than a failure: the executor's own takers consume
::  the vetoes of the roads it asks for, but one that reaches here must
::  not jam the fiber.
::
++  take-exec-in
  =/  m  (fiber:fiber:nexus ,gen-in)
  ^-  form:m
  |=  input:fiber:nexus
  :+  ~  q.state
  ?+  in  [%skip ~]
      ~  [%wait ~]
      [~ %veto *]  [%done %wake /veto]
      [~ %news * *]
    ?.(|(=(/exec wire.u.in) =(/cal wire.u.in)) [%skip ~] [%done %news wave.u.in])
      [~ %poke * *]
    ?.  =([/ %timer-wake] p.sage.u.in)  [%done %poke sage.u.in]
    [%done %wake (fall (mole |.(!<(path q.sage.u.in))) /)]
  ==
::  +gen-pass: one pass. Read the settings; off means nothing. Read the
::  state the way the state view does, build the prompt, and stop when
::  its digest is the last pass's unless forced. Ask the model under a
::  ten minute timer, validate, file each survivor as an act op under
::  by generator, and record what happened in generator-last.json.
::
++  gen-pass
  |=  [force=? urgent=(unit (list @t))]
  =/  m  (fiber:fiber:nexus ,(unit @da))
  ^-  form:m
  ;<  cfg-json=json  bind:m  (read-json (rf 0 / %'generator.json'))
  =/  cfg=config:orr  (de-config:orr cfg-json)
  ?.  enabled.cfg  (pure:m ~)
  ;<  rev=json  bind:m  (read-json (rf 0 /beacon %rev))
  ?:  =('' api-key.cfg)
    ;<  ~  bind:m  (gen-record ~ 0 0 ~['no api_key set'] ~ `'no api_key set' 0 | rev)
    (pure:m ~)
  ;<  now=@da  bind:m  get-time:io
  ::  the limits come before anything is read, and they hold a forced
  ::  pass too: run-now is a wish, the bill is a fact
  ;<  last0=json  bind:m  (read-json (rf 0 / %'generator-last.json'))
  ::  an urgent pass goes past the cooldown and the daily cap, under
  ::  its own: the sixth in a day is held like any other
  =/  held=(unit @da)  ?^(urgent ~ (held-until:orr cfg last0 now))
  ?^  held
    =/  why=@t  (rap 3 'held by the limits until ' (en-iso:orr u.held) ~)
    ;<  ~  bind:m  (gen-record ~ 0 0 ~[why] ~ ~ 0 & rev)
    (pure:m held)
  ?:  &(?=(^ urgent) (urgent-held:orr cfg last0 now))
    ;<  ~  bind:m  (gen-record ~ 0 0 ~['held: today\'s urgent passes are spent'] ~ ~ 0 & rev)
    (pure:m ~)
  ;<  schema=json  bind:m  (read-json (rf 0 / %'schema.json'))
  ;<  all=(list loaded:orr)  bind:m  (load-bodies 0)
  ;<  acts=(list [id=@ta a=action:orr])  bind:m  (load-actions 0)
  =/  decided=(list [id=@ta a=action:orr])
    %+  sort  (skim acts |=([* a=action:orr] ?=(?(%done %dismissed %failed) status.a)))
    |=([[* a=action:orr] [* b=action:orr]] (lth proposed.a proposed.b))
  =/  tz=@t
    =/  from-me=@t  (attr-text:orr all (multi-of:orr schema) now 'person/me' 'timezone')
    ?:(=('' from-me) timezone.cfg from-me)
  =/  parts=(list @t)  (build-parts:orr all acts decided schema now tz max-actions.cfg)
  =?  parts  ?=(^ urgent)  (urgent-parts:orr parts u.urgent)
  =/  dg=@ux  (digest:orr parts)
  =/  last=json  last0
  ?:  &(!force =((gs:orr last 'digest') (scot %ux dg)))
    ;<  ~  bind:m  (gen-record `dg 0 0 ~['nothing the model would see has changed: no pass'] ~ ~ 0 & rev)
    (pure:m ~)
  ;<  got=[status=@ud body=@t secs=@ud]  bind:m  (ask-model cfg parts)
  ::  the call counts against the limits whatever it answered
  ;<  ~  bind:m  (gen-count now ?=(^ urgent))
  ?.  =(200 status.got)
    =/  why=@t  (rap 3 'the model answered ' (scot %ud status.got) ': ' (end [3 200] body.got) ~)
    ;<  ~  bind:m  (gen-record `dg 0 0 ~ ~ `why secs.got | rev)
    (pure:m ~)
  =/  resp=json  (fall (de:json:html body.got) [%o ~])
  =/  ans  (answer-of:orr resp)
  ?:  ?=(%| -.ans)
    ;<  ~  bind:m  (gen-record `dg 0 0 ~ ~ `p.ans secs.got | rev)
    (pure:m ~)
  =/  parsed=(unit json)  (parse-answer:orr text.p.ans)
  ?~  parsed
    ;<  ~  bind:m  (gen-record `dg 0 0 ~ usage.p.ans `'the answer was not JSON' secs.got | rev)
    (pure:m ~)
  =/  known=(set @t)  (sy (turn all |=(l=loaded:orr id.l)))
  =/  taken=(list @t)
    %+  weld  (murn acts |=([* a=action:orr] ?.((is-open:orr a) ~ `title.a)))
    (turn decided |=([* a=action:orr] title.a))
  =/  events=(list @t)
    %+  murn  all
    |=(l=loaded:orr ?:(?=(?(%situation %activity) kind.body.l) `name.body.l ~))
  =/  v  (validate:orr u.parsed known taken events schema max-actions.cfg)
  =/  offered=@ud  (lent (ga:orr u.parsed 'actions'))
  =/  todo=(list json)  acts.v
  =/  filed=@ud  0
  =|  sent=(list [id=@ta a=action:orr])
  |-
  ?~  todo
    ::  the filings change the open actions, so the writer wakes this
    ::  fiber again; the digest recorded is of the prompt as it will read
    ::  with them open, so that wake finds nothing new and asks nothing
    =/  after=(list @t)  (build-parts:orr all (weld acts (flop sent)) decided schema now tz max-actions.cfg)
    =/  said=(list @t)
      ?~  urgent  notes.v
      [(cat 3 'urgent pass' ?~(u.urgent '' (cat 3 ': ' (join-cords:orr ', ' u.urgent)))) notes.v]
    ;<  ~  bind:m  (gen-record `(digest:orr after) filed (sub offered (min offered filed)) said usage.p.ans ~ secs.got | rev)
    (pure:m ~)
  =/  stamped=json  (fill-act-as:orr i.todo now 'generator')
  ;<  err=(unit tang)  bind:m
    (poke-soft:io (rf 0 / %'main.sig') [[/ %json] (pairs:enjs:format ~[['op' s+'act'] ['action' stamped]])])
  =/  parsed-act  (de-action:orr stamped now 'generator')
  =?  sent  &(?=(~ err) ?=(%& -.parsed-act))  [[(act-id:orr p.parsed-act) p.parsed-act] sent]
  $(todo t.todo, filed ?~(err +(filed) filed))
::  +gen-record: what a pass did, for the page and the next pass. The
::  digest is kept as text so the skip compares strings; a skip keeps
::  the last real pass's digest.
::
++  gen-record
  |=  $:  dg=(unit @ux)  filed=@ud  dropped=@ud  notes=(list @t)
          usage=json  error=(unit @t)  secs=@ud  skipped=?  rev=json
      ==
  =/  m  (fiber:fiber:nexus ,~)
  ^-  form:m
  ;<  now=@da  bind:m  get-time:io
  ;<  last=json  bind:m  (read-json (rf 0 / %'generator-last.json'))
  =/  month=@t  (end [3 7] (en-iso:orr now))
  =/  spend=@ud
    =/  prior=@ud  ?:(=(month (gs:orr last 'month')) (fall (gn:orr last 'spend_month_micro') 0) 0)
    =/  cost=json  (gj:orr usage 'cost')
    (add prior ?:(?=([%n *] cost) (micro-of:orr p.cost) 0))
  =/  keep=@t
    ?:  skipped  (gs:orr last 'digest')
    ?~(dg (gs:orr last 'digest') (scot %ux u.dg))
  =/  doc=json
    %-  pairs:enjs:format
    :~  ['at' (en-time:orr now)]
        ['called' (gj:orr last 'called')]
        ['day' (gj:orr last 'day')]
        ['calls_today' (gj:orr last 'calls_today')]
        ['urgent_today' (gj:orr last 'urgent_today')]
        ::  the month's spend, in micro-dollars, from the model's own
        ::  cost figure; the page shows it beside the calls
        ['month' s+month]
        ['spend_month_micro' (numb:enjs:format spend)]
        ['rev' rev]
        ['digest' s+keep]
        ['skipped' b+skipped]
        ['filed' (numb:enjs:format filed)]
        ['dropped' (numb:enjs:format dropped)]
        ['notes' a+(turn notes |=(n=@t `json`s+n))]
        ['usage' usage]
        ['error' ?~(error ~ s+u.error)]
        ['seconds' (numb:enjs:format secs)]
    ==
  (over:io (rf 0 / %'generator-last.json') [[/ %json] doc])
::  +gen-count: one more model call today, at now, for the limits
::
++  gen-count
  |=  [now=@da urgent=?]
  =/  m  (fiber:fiber:nexus ,~)
  ^-  form:m
  ;<  last=json  bind:m  (read-json (rf 0 / %'generator-last.json'))
  =/  day=@t  (end [3 10] (en-iso:orr now))
  =/  same=?  =(day (gs:orr last 'day'))
  =/  today=@ud  ?:(same (fall (gn:orr last 'calls_today') 0) 0)
  =/  urgent-today=@ud  ?:(same (fall (gn:orr last 'urgent_today') 0) 0)
  =/  base=(map @t json)  ?:(?=([%o *] last) p.last ~)
  =/  doc=json
    :-  %o
    %-  ~(gas by base)
    :~  ['called' (en-time:orr now)]
        ['day' s+day]
        ['calls_today' (numb:enjs:format +(today))]
        ['urgent_today' (numb:enjs:format ?:(urgent +(urgent-today) urgent-today))]
    ==
  (over:io (rf 0 / %'generator-last.json') [[/ %json] doc])
::  +post-json: one POST through iris, under the app's own timer (iris
::  has none): status 0 with why in the body when the timer wins or the
::  road is refused. Measured in docs/spikes/2026-09-19-iris-probe.md: a
::  259 second answer arrived whole. An empty key sends no authorization
::  header. +ask-model and +ask-decider both use it.
::
++  post-json
  |=  [url=@t key=@t body=json timeout=@dr wire=@ta]
  =/  m  (fiber:fiber:nexus ,[status=@ud body=@t secs=@ud])
  ^-  form:m
  =/  =request:http
    :^  %'POST'  url
      %-  zing
      :~  ~[['content-type' 'application/json']]
          ?:(=('' key) ~ ~[['authorization' (cat 3 'Bearer ' key)]])
      ==
    `(as-octs:mimes:html (en:json:html body))
  (fetch-json request timeout wire)
::  +get-json: one GET through iris, no body and no bearer header (the
::  telegram API takes a GET like a POST), under the same timer
::
++  get-json
  |=  [url=@t timeout=@dr wire=@ta]
  =/  m  (fiber:fiber:nexus ,[status=@ud body=@t secs=@ud])
  ^-  form:m
  (fetch-json [%'GET' url ~ ~] timeout wire)
::  +fetch-json: the request and its answer, what +post-json and
::  +get-json share
::
++  fetch-json
  |=  [=request:http timeout=@dr wire=@ta]
  =/  m  (fiber:fiber:nexus ,[status=@ud body=@t secs=@ud])
  ^-  form:m
  ;<  t0=@da  bind:m  get-time:io
  ;<  ~  bind:m  (send-request:io request)
  ;<  ~  bind:m  (set-timer:io /[wire] (add t0 timeout))
  ;<  res=[why=@t r=(unit client-response:iris)]  bind:m
    |=  input:fiber:nexus
    :+  ~  q.state
    ?+  in  [%skip ~]
        ~  [%wait ~]
        [~ %veto *]  [%done 'the iris road is refused: approve it on the permits page' ~]
        [~ %poke * *]
      ?:  =([/ %timer-wake] p.sage.u.in)
        ?.(=(/[wire] !<(path q.sage.u.in)) [%skip ~] [%done 'no answer before the timer' ~])
      ?.  =([/ %http-response] p.sage.u.in)  [%skip ~]
      =/  resp=client-response:iris  !<(client-response:iris q.sage.u.in)
      ?:(?=(%cancel -.resp) [%done 'the request was cancelled' ~] [%done '' `resp])
    ==
  ;<  ~  bind:m  (cancel-timer:io /[wire])
  ;<  t1=@da  bind:m  get-time:io
  =/  secs=@ud  (div (sub t1 t0) ~s1)
  ?~  r.res  (pure:m [0 why.res secs])
  =/  resp=client-response:iris  u.r.res
  ?.  ?=(%finished -.resp)  (pure:m [0 'not finished' secs])
  =/  body=@t  ?~(full-file.resp '' q.data.u.full-file.resp)
  (pure:m [status-code.response-header.resp body secs])
::  +ask-model: one POST to the model, ten minutes at most
::
++  ask-model
  |=  [cfg=config:orr parts=(list @t)]
  =/  m  (fiber:fiber:nexus ,[status=@ud body=@t secs=@ud])
  ^-  form:m
  (post-json (cat 3 url.cfg '/chat/completions') api-key.cfg (chat-body:orr cfg parts) ~m10 %model)
::  +ask-decider: one decisions call at the model host with the
::  generator's key and provider rule; ~ when it fails, so a decider that
::  cannot answer decides nothing
::
++  ask-decider
  |=  [cfg=config:orr body=json]
  =/  m  (fiber:fiber:nexus ,(unit json))
  ^-  form:m
  =/  full=json
    %^  set-key:orr  (set-key:orr body 'model' s+'typesafe/jev-1.13')
      'provider'
    (pairs:enjs:format ~[['zdr' b+&]])
  ;<  got=[status=@ud body=@t secs=@ud]  bind:m
    (post-json (decider-url:orr url.cfg) api-key.cfg full ~s30 %decider)
  ?.  =(200 status.got)  (pure:m ~)
  =/  resp=json  (fall (de:json:html body.got) ~)
  =/  answers=json  (gj:orr resp 'answers')
  (pure:m ?.(?=([%o *] answers) ~ `answers))
::  +do-set-generator: merge the owner's generator settings over the
::  stored ones. A blank or missing api_key keeps the stored key, so the
::  page can save every other field without holding the secret; a JSON
::  null clears it. Settings are not model state: the beacon does not move.
::
++  do-set-generator
  |=  jon=json
  =/  m  (fiber:fiber:nexus ,?)
  ^-  form:m
  =/  doc=json  (gj:orr jon 'doc')
  ?.  ?=([%o *] doc)  (refuse 'set-generator' 'doc: expected an object')
  ;<  base=(map @t json)  bind:m  (read-map (rf 0 / %'generator.json'))
  =/  merged=json  [%o (merge-settings:orr base p.doc (sy ~['api_key']))]
  ;<  ~  bind:m  (over:io (rf 0 / %'generator.json') [[/ %json] merged])
  ;<  ~  bind:m  (note-by 'set-generator' & '' 'http')
  (pure:m |)
::  +do-set-telegram: merge the owner's reader settings over the stored
::  ones. A blank or missing token or webhook secret keeps the stored
::  one, so the page can save every other field without holding either
::  secret; a JSON null clears it. A secret shorter than 16 bytes is
::  refused: that header is all that stands between Telegram's updates
::  and anyone else's. A token that differs from the stored one is a
::  new bot, whose update ids start over: the record's update_id goes
::  to 0 so the hook does not drop them as seen. Settings are not model
::  state: no beacon bump.
::
++  do-set-telegram
  |=  jon=json
  =/  m  (fiber:fiber:nexus ,?)
  ^-  form:m
  =/  doc=json  (gj:orr jon 'doc')
  ?.  ?=([%o *] doc)  (refuse 'set-telegram' 'doc: expected an object')
  ?:  (short-secret:orr doc)  (refuse 'set-telegram' 'secret: 16 bytes at least')
  ;<  base=(map @t json)  bind:m  (read-map (rf 0 / %'telegram.json'))
  =/  merged=(map @t json)  (merge-settings:orr base p.doc (sy ~['token' 'secret']))
  ;<  ~  bind:m  (over:io (rf 0 / %'telegram.json') [[/ %json] [%o merged]])
  =/  token=@t  (gs:orr doc 'token')
  ;<  ~  bind:m
    =/  n  (fiber:fiber:nexus ,~)
    ^-  form:n
    ?:  |(=('' token) =(token (gs:orr [%o base] 'token')))  (pure:n ~)
    ;<  last=json  bind:n  (read-json (rf 0 / %'telegram-last.json'))
    %+  over:io  (rf 0 / %'telegram-last.json')
    [[/ %json] (set-key:orr last 'update_id' (numb:enjs:format 0))]
  ;<  ~  bind:m  (note 'set-telegram' & '')
  (pure:m |)
::  +do-set-chat: merge the owner's chat reader settings over the stored
::  ones. There is no secret: a key given replaces its value whole, a
::  key left out keeps it. Settings are not model state: no beacon bump.
::
++  do-set-chat
  |=  jon=json
  =/  m  (fiber:fiber:nexus ,?)
  ^-  form:m
  =/  doc=json  (gj:orr jon 'doc')
  ?.  ?=([%o *] doc)  (refuse 'set-chat' 'doc: expected an object')
  ;<  base=(map @t json)  bind:m  (read-map (rf 0 / %'chat.json'))
  ;<  ~  bind:m
    (over:io (rf 0 / %'chat.json') [[/ %json] [%o (merge-settings:orr base p.doc ~)]])
  ;<  ~  bind:m  (note 'set-chat' & '')
  (pure:m |)
::  +serve-chat: the chat reader's settings, as stored, normalised
::
++  serve-chat
  |=  eyre-id=@ta
  =/  m  (fiber:fiber:nexus ,~)
  ^-  form:m
  ;<  doc=json  bind:m  (read-json (rf 1 / %'chat.json'))
  (send-json eyre-id 200 (en-chat-config:orr (de-chat-config:orr doc)))
::  +serve-chat-list: what the groups desk holds, for the card to offer:
::  the DM list or the channel list, through the same scries the reader
::  uses. An absent groups desk or a refused road answers an empty list
::  with a note, never an error, since the card renders either way.
::
++  serve-chat-list
  |=  [eyre-id=@ta pax=path]
  =/  m  (fiber:fiber:nexus ,~)
  ^-  form:m
  ;<  live=(unit ?)  bind:m  groups-live
  ?~  live  (send-json eyre-id 200 (pairs:enjs:format ~[['items' a+~] ['note' s+'the /sys/scry/ road is refused']]))
  ?.  u.live  (send-json eyre-id 200 (pairs:enjs:format ~[['items' a+~] ['note' s+'groups desk not installed']]))
  ;<  got=(unit json)  bind:m  (scry-json pax)
  =/  items=(list @t)
    ?~  got  ~
    ?:  ?=([%a *] u.got)  (strings:orr p.u.got)
    ?:  ?=([%o *] u.got)  (sort ~(tap in ~(key by p.u.got)) aor)
    ~
  (send-json eyre-id 200 (pairs:enjs:format ~[['items' a+(turn items |=(t=@t `json`s+t))] ['note' s+'']]))
::  ==  the scries (version 39): a gall agent's answer through the
::  /sys/scry service, the way fiberio's +typed-scry asks, but soft: a
::  refused road answers ~ instead of failing the fiber, so the chat
::  reader stays alive with a note. The path is what gall sees after
::  our ship and the desk, with the mark it should answer in last.
::
++  scry-soft
  |=  [mark=@tas pax=path]
  =/  m  (fiber:fiber:nexus ,(unit vase))
  ^-  form:m
  ;<  err=(unit tang)  bind:m
    (poke-soft:io [%& %& /sys/scry %'main.sig'] [[/ %scry-request] [mark pax]])
  ?^  err  (pure:m ~)
  |=  input:fiber:nexus
  :+  ~  q.state
  ?+  in  [%skip ~]
      ~  [%wait ~]
      [~ %veto *]  [%done ~]
      [~ %poke * *]
    ?.  =([/ mark] p.sage.u.in)  [%skip ~]
    [%done `q.sage.u.in]
  ==
++  scry-json
  |=  pax=path
  =/  m  (fiber:fiber:nexus ,(unit json))
  ^-  form:m
  ;<  v=(unit vase)  bind:m  (scry-soft %json pax)
  (pure:m ?~(v ~ `(fall (mole |.(!<(json u.v))) [%o ~])))
++  scry-loob
  |=  pax=path
  =/  m  (fiber:fiber:nexus ,(unit ?))
  ^-  form:m
  ;<  v=(unit vase)  bind:m  (scry-soft %loob pax)
  (pure:m ?~(v ~ `(fall (mole |.(!<(? u.v))) |)))
::  +groups-live: whether the chat and channels agents answer at all,
::  asked with %gu first: a %gx at an absent agent bails the event.
::  ~ when the scry road is refused.
::
++  groups-live
  =/  m  (fiber:fiber:nexus ,(unit ?))
  ^-  form:m
  ;<  a=(unit ?)  bind:m  (scry-loob /gu/chat/$)
  ?~  a  (pure:m ~)
  ?.  u.a  (pure:m `|)
  ;<  b=(unit ?)  bind:m  (scry-loob /gu/channels/$)
  ?~  b  (pure:m ~)
  (pure:m `u.b)
::  +chat-pass: one pass of the chat reader. Off means nothing. The
::  groups desk is asked whether it is there, then the two changes
::  scries since the last pass (the first pass looks back backfill
::  hours), and every writ or post they carry becomes a row: the ones
::  already read are skipped by id, a sender not in people (the settings
::  merged over the person bodies' ships) is a stranger and counted,
::  the daily cap holds, and each survivor goes through the pipeline
::  Telegram uses, signed chat. A model that cannot answer stops the
::  pass where it stood: since does not move, the rows read so far are
::  remembered as read, and the record says the model is down.
::
++  chat-pass
  =/  m  (fiber:fiber:nexus ,@ud)
  ^-  form:m
  ;<  cfg-j=json  bind:m  (read-json (rf 0 / %'chat.json'))
  =/  cfg=chat-config:orr  (de-chat-config:orr cfg-j)
  ?.  enabled.cfg  (pure:m poll.cfg)
  ;<  now=@da  bind:m  get-time:io
  ;<  last=json  bind:m  (read-json (rf 0 / %'chat-last.json'))
  ::  the first pass looks back backfill hours and reads nothing sent
  ::  before that; a later pass takes whatever the scry says changed,
  ::  however old its sent, since a writ delivered late shows up once
  =/  first=(unit @da)  (de-iso:orr (gs:orr last 'since'))
  =/  since=@da  ?^(first u.first (sub now (mul backfill.cfg ~h1)))
  =/  floor=@da  ?^(first *@da since)
  =/  record
    |=  [notes=(list @t)]
    ^-  form:m
    ;<  ~  bind:m  (chat-record last now since *chat-tally notes ~)
    (pure:m poll.cfg)
  ;<  live=(unit ?)  bind:m  groups-live
  ?~  live  (record ~['the /sys/scry/ road is refused: approve it on the permits page'])
  ?.  u.live  (record ~['groups desk not installed'])
  ;<  chat=(unit json)  bind:m  (scry-json /gx/chat/v4/changes/(scot %da since)/json)
  ;<  chans=(unit json)  bind:m  (scry-json /gx/channels/v6/changes/(scot %da since)/json)
  ?:  |(?=(~ chat) ?=(~ chans))
    (record ~['the /sys/scry/ road is refused: approve it on the permits page'])
  ;<  our=@p  bind:m  get-our:io
  =/  me=@t  (scot %p our)
  =/  rows=(list tg-msg:orr)
    %+  sort  (weld (chat-rows:orr u.chat cfg floor me) (channel-rows:orr u.chans cfg floor me))
    |=([a=tg-msg:orr b=tg-msg:orr] (lth at.a at.b))
  ;<  seen-j=json  bind:m  (read-json (rf 0 / %'chat-seen.json'))
  =/  seen=(set @t)  (sy (strings:orr ?:(?=([%a *] seen-j) p.seen-j ~)))
  ;<  all=(list loaded:orr)  bind:m  (load-bodies 0)
  =/  people=(map @t @t)  (~(uni by (people-of-ships all)) people.cfg)
  =?  people  !(~(has by people) me)  (~(put by people) me 'person/me')
  =/  tg=tg-config:orr  (chat-as-tg:orr cfg)
  =/  day=@t  (end [3 10] (en-iso:orr now))
  =/  today=@ud  ?:(=(day (gs:orr last 'day')) (fall (gn:orr last 'read_today') 0) 0)
  =|  tally=chat-tally
  =|  new=(list @t)
  |-
  ?~  rows
    ;<  ~  bind:m  (chat-remember seen-j new)
    ::  a message the cap held is neither read nor remembered, so since
    ::  stays where it was and tomorrow's pass finds it again
    ;<  ~  bind:m  (chat-record last now ?:(=(0 held.tally) now since) tally ~ ~)
    (pure:m poll.cfg)
  =/  msg=tg-msg:orr  i.rows
  =/  key=@t  (rap 3 chat.msg '/' mid.msg ~)
  ?:  (~(has in seen) key)  $(rows t.rows)
  =/  who=(unit @t)  (~(get by people) from.msg)
  ?~  who  $(rows t.rows, strangers.tally +(strangers.tally), new [key new])
  ?:  =('' text.msg)  $(rows t.rows, new [key new])
  ?:  (gte (add today read.tally) max-daily.cfg)  $(rows t.rows, held.tally +(held.tally))
  ;<  [read=? down=? facts=tg-facts:orr]  bind:m  (tg-read tg msg u.who now chat-kind:orr)
  ?:  down
    ;<  ~  bind:m  (chat-remember seen-j new)
    ;<  ~  bind:m  (chat-record last now since tally ~ `notes.facts)
    (pure:m poll.cfg)
  ;<  ~  bind:m  (tg-file facts u.who now chat-kind:orr)
  ;<  recent=json  bind:m  (read-json (rf 0 / %'chat-recent.json'))
  ;<  ~  bind:m
    (over:io (rf 0 / %'chat-recent.json') [[/ %json] (tg-remember:orr recent msg u.who now chat-kind:orr)])
  =/  n=@ud  :(add (lent obs.facts) (lent bodies.facts) (lent acts.facts))
  %=  $
    rows  t.rows
    new   [key new]
    read.tally   ?:(read +(read.tally) read.tally)
    filed.tally  (add filed.tally n)
    notes.tally  (weld notes.tally notes.facts)
  ==
::  +$  chat-tally: what one pass did
::
+$  chat-tally  [read=@ud filed=@ud strangers=@ud held=@ud notes=(list @t)]
::  +people-of-ships: every person body with a ship, keyed by that ship
::  as the settings key one, so a person the owner named on the ship is
::  known to the reader without a row on the card
::
++  people-of-ships
  |=  all=(list loaded:orr)
  ^-  (map @t @t)
  %-  ~(gas by *(map @t @t))
  %+  murn  all
  |=  l=loaded:orr
  ^-  (unit [@t @t])
  ?.  =(%person kind.body.l)  ~
  ?~  ship.body.l  ~
  `[(ship-key:orr (scot %p u.ship.body.l)) id.l]
::  +chat-remember: the ids read, appended to the seen ring (the last
::  5000), so a writ Tlon reports changed again is read once
::
++  chat-remember
  |=  [seen=json new=(list @t)]
  =/  m  (fiber:fiber:nexus ,~)
  ^-  form:m
  ?~  new  (pure:m ~)
  =/  ring=json  (roll (flop new) |=([k=@t acc=_seen] (ring:orr acc s+k 5.000)))
  (over:io (rf 0 / %'chat-seen.json') [[/ %json] ring])
::  +chat-record: what the pass did, for the card and the next pass:
::  since is where the next pass starts, read_today the cap's count,
::  and down, when given, says the model could not answer
::
++  chat-record
  |=  [last=json now=@da since=@da t=chat-tally notes=(list @t) down=(unit (list @t))]
  =/  m  (fiber:fiber:nexus ,~)
  ^-  form:m
  =/  day=@t  (end [3 10] (en-iso:orr now))
  =/  today=@ud  ?:(=(day (gs:orr last 'day')) (fall (gn:orr last 'read_today') 0) 0)
  =/  said=(list @t)  (scag 20 (weld notes notes.t))
  %+  over:io  (rf 0 / %'chat-last.json')
  :-  [/ %json]
  %-  pairs:enjs:format
  :~  ['since' s+(en-iso:orr since)]
      ['at' s+(en-iso:orr now)]
      ['read' (numb:enjs:format read.t)]
      ['filed' (numb:enjs:format filed.t)]
      ['strangers' (numb:enjs:format strangers.t)]
      ['held' (numb:enjs:format held.t)]
      ['notes' a+(turn said |=(n=@t `json`s+(end [3 300] n)))]
      ['day' s+day]
      ['read_today' (numb:enjs:format (add today read.t))]
      :-  'down'
      ?~  down  ~
      (pairs:enjs:format ~[['at' s+(en-iso:orr now)] ['notes' a+(turn (scag 6 u.down) |=(n=@t `json`s+(end [3 300] n)))]])
  ==
::  ==  the telegram reader (version 29): the bot's pipeline on the ship
::
::  +tg-drain: every update in the inbox, in order, each handled then
::  culled, so a crash mid-way leaves the rest for the next wake; then
::  the inbox again, since an update that arrived while these were
::  handled woke nothing the settle did not take. An update the model
::  could not read stops the drain: it is neither recorded nor culled,
::  and a retry timer wakes the reader in five minutes (the owner's
::  wake route sooner).
::
++  tg-drain
  =/  m  (fiber:fiber:nexus ,~)
  ^-  form:m
  ;<  vw=view:nexus  bind:m  (peek:io (rv 0 /telegram-inbox) ~)
  ?.  ?=([%ball *] vw)  (pure:m ~)
  ?~  fil.ball.vw  (pure:m ~)
  =/  names=(list @ta)
    %+  sort  (skip (turn ~(tap by contents.u.fil.ball.vw) head) |=(n=@ta =(%rev n)))
    aor
  ?~  names  (pure:m ~)
  ;<  culled=?  bind:m  (tg-drain-each names)
  ::  a file the cull left is not read again until the next wake
  ?.(culled (pure:m ~) tg-drain)
::  +tg-drain-each: the named updates in turn; whether every one was
::  culled. One the model was down for sets the retry timer (a pending
::  one cancelled first, so wakes do not stack) and ends the drain.
::
++  tg-drain-each
  |=  names=(list @ta)
  =/  m  (fiber:fiber:nexus ,?)
  ^-  form:m
  ;<  cfg-j=json  bind:m  (read-json (rf 0 / %'telegram.json'))
  =/  cfg=tg-config:orr  (de-tg-config:orr cfg-j)
  =/  culled=?  &
  |-
  ?~  names  (pure:m culled)
  ;<  update=json  bind:m  (read-json (rf 0 /telegram-inbox i.names))
  ;<  down=?  bind:m  (tg-handle cfg update)
  ?:  down
    ;<  now=@da  bind:m  get-time:io
    ;<  ~  bind:m  (cancel-timer:io /retry)
    ;<  ~  bind:m  (set-timer:io /retry (add now ~m5))
    (pure:m |)
  ;<  ~  bind:m  tg-yield
  ;<  err=(unit tang)  bind:m  (cull-soft:io (rf 0 /telegram-inbox i.names))
  $(names t.names, culled &(culled ?=(~ err)))
::  +tg-yield: the next event. The webhook's request fiber is answered
::  after its rev write is acked, and a cull in the event of that write
::  held the ack until another event came along (wex, 2026-09-20: an
::  update with no model call answered only when the next request hit
::  the ship), so the cull waits for a timer that fires at once. News
::  taken meanwhile is nothing lost: +tg-drain lists the inbox again.
::
++  tg-yield
  =/  m  (fiber:fiber:nexus ,~)
  ^-  form:m
  ;<  now=@da  bind:m  get-time:io
  ;<  ~  bind:m  (set-timer:io /yield now)
  |-
  ;<  in=gen-in  bind:m  (take-gen-in /tg)
  ?:  ?=([%wake [%yield ~]] in)  (pure:m ~)
  $
::  +tg-handle: one update: the filters, then the model, then the filing,
::  the window and the record. A held message is not
::  read and not context; the window is written after a reading whatever
::  it yielded, so a question rides along as the next message's context.
::  Yields whether the update is kept for a retry: the model was down,
::  so nothing was filed and nothing recorded.
::
++  tg-handle
  |=  [cfg=tg-config:orr update=json]
  =/  m  (fiber:fiber:nexus ,?)
  ^-  form:m
  ;<  now=@da  bind:m  get-time:io
  ;<  last=json  bind:m  (read-json (rf 0 / %'telegram-last.json'))
  =/  uid=@ud  (fall (gn:orr update 'update_id') 0)
  ::  a recorded update is done with
  =/  done
    |=  [chat=@t from=@t outcome=@t notes=(list @t) read=?]
    ^-  form:m
    ;<  ~  bind:m  (tg-record last now uid chat from outcome notes read)
    (pure:m |)
  =/  mu=(unit tg-msg:orr)  (tg-message:orr update)
  ?~  mu  (done '' '' 'ignored' ~['not a message'] |)
  =/  msg=tg-msg:orr  u.mu
  ?.  (~(has in chats.cfg) chat.msg)
    (done chat.msg from.msg 'ignored' ~[(rap 3 'chat ' chat.msg ' is not in chats' ~)] |)
  =/  who=(unit @t)  (~(get by people.cfg) from.msg)
  ?~  who
    (done chat.msg from.msg 'ignored' ~[(rap 3 'sender ' from.msg ' is not in people' ~)] |)
  ;<  stranger=?  bind:m  (tg-stranger cfg business.msg)
  ?:  stranger
    (done chat.msg from.msg 'ignored' ~['business connection of an account not in people'] |)
  ?:  =('' text.msg)  (done chat.msg from.msg 'ignored' ~['no text'] |)
  =/  day=@t  (end [3 10] (en-iso:orr now))
  =/  today=@ud  ?:(=(day (gs:orr last 'day')) (fall (gn:orr last 'read_today') 0) 0)
  ?:  (gte today max-daily.cfg)
    (done chat.msg from.msg 'held' ~['today\'s messages are spent'] |)
  ;<  [read=? down=? facts=tg-facts:orr]  bind:m  (tg-read cfg msg u.who now telegram-kind:orr)
  ::  kept for the retry, and said so: the record's update_id stays, a
  ::  down key names the update, the moment and the model's answer, so
  ::  a model the ship cannot reach reads off the card instead of
  ::  looking like a reader that never ran (ricsul, 2026-09-21)
  ?:  down
    ;<  ~  bind:m  (tg-record-down now uid notes.facts)
    (pure:m &)
  ;<  ~  bind:m  (tg-file facts u.who now telegram-kind:orr)
  ;<  recent=json  bind:m  (read-json (rf 0 / %'telegram-recent.json'))
  ::  a chat taken out of the settings loses its window
  =/  window=json
    =/  r=json  (tg-remember:orr recent msg u.who now telegram-kind:orr)
    ?.  ?=([%o *] r)  r
    [%o (~(gas by *(map @t json)) (skim ~(tap by p.r) |=([k=@t *] (~(has in chats.cfg) k))))]
  ;<  ~  bind:m  (over:io (rf 0 / %'telegram-recent.json') [[/ %json] window])
  =/  outcome=@t  ?:(&(=(~ obs.facts) =(~ bodies.facts) =(~ acts.facts)) 'nothing' 'facts')
  (done chat.msg from.msg outcome notes.facts read)
::  +tg-read: the gate, the analyst, validation, grounding, the status
::  check and the escalate question, with the window as context. A
::  decider that cannot answer reads the message, escalates nothing and
::  keeps every status, each said in the notes. The flag says whether
::  the analyst was asked (the request sent, whatever it answered): a
::  question, a missing key and a gate refusal ask nothing. The down
::  flag says the analyst could not answer (unreachable or timed out,
::  401 to 404, 408, 429, 5xx, the bot's own list), so the update is
::  worth asking about again.
::
++  tg-read
  |=  [cfg=tg-config:orr msg=tg-msg:orr who=@t now=@da kind=reader-kind:orr]
  =/  m  (fiber:fiber:nexus ,[read=? down=? facts=tg-facts:orr])
  ^-  form:m
  =/  q=?  =('?' (rsh [3 (dec (met 3 text.msg))] text.msg))
  ?:  q  (pure:m [| | ~ ~ ~ ~['a question states nothing'] ~])
  ;<  gen-j=json  bind:m  (read-json (rf 0 / %'generator.json'))
  =/  gen=config:orr  (de-config:orr gen-j)
  ?:  =('' api-key.gen)
    (pure:m [| | ~ ~ ~ ~['no api_key set on the generator: the reader has no model'] ~])
  ;<  schema=json  bind:m  (read-json (rf 0 / %'schema.json'))
  ;<  all=(list loaded:orr)  bind:m  (load-bodies 0)
  ;<  recent=json  bind:m  (read-json (rf 0 / recent.kind))
  =/  ctx=reader-ctx:orr  (reader-context:orr all schema now)
  =/  rows=(list window-row:orr)
    %+  snoc
      (turn (tg-window:orr recent chat.msg) |=([id=@t at=@t w=@t t=@t] ^-(window-row:orr [id at w t &])))
    ^-  window-row:orr
    [id:(tg-source:orr msg kind) (en-iso:orr at.msg) who text.msg |]
  ;<  gate=(unit json)  bind:m  (ask-decider gen (gate-body:orr rows ctx))
  =/  p=@ud  ?~(gate 100 (noul-of:orr u.gate 'worth_reading'))
  =/  gate-note=@t
    ?~  gate  'gate unavailable, analyst asked'
    (rap 3 'gate: ' (crip (a-co:co p)) ?:((lth p gate.cfg) ', not read' ', read') ~)
  ?:  (lth p gate.cfg)  (pure:m [| | ~ ~ ~ ~[gate-note] ~])
  =/  tz=@t
    =/  from-me=@t  (attr-text:orr all (multi-of:orr schema) now 'person/me' 'timezone')
    ?:(=('' from-me) timezone.gen from-me)
  =/  small=config:orr
    gen(model model.cfg, max-tokens max-tokens.cfg, reasoning [%o (my ~[['enabled' b+|]])])
  ;<  got=[status=@ud body=@t secs=@ud]  bind:m
    %:  post-json
      (cat 3 url.gen '/chat/completions')
      api-key.gen
      (chat-body-with:orr small analyst-prompt:orr ~[(reader-prompt:orr rows ctx tz kind)])
      ~m5
      %reader
    ==
  ?.  =(200 status.got)
    =/  why=@t  (rap 3 'model: ' (crip (a-co:co status.got)) ' ' (end [3 200] body.got) ~)
    =/  down=?
      =/  s=@ud  status.got
      ?|  =(0 s)
          &((gte s 401) (lte s 404))
          =(408 s)
          =(429 s)
          &((gte s 500) (lte s 599))
      ==
    (pure:m [& down ~ ~ ~ ~[gate-note why] ~])
  =/  ans  (answer-of:orr (fall (de:json:html body.got) [%o ~]))
  ?:  ?=(%| -.ans)  (pure:m [& | ~ ~ ~ ~[gate-note p.ans] ~])
  =/  parsed=(unit json)  (parse-answer:orr text.p.ans)
  ?~  parsed  (pure:m [& | ~ ~ ~ ~[gate-note 'model: the answer is not JSON'] ~])
  =/  facts=tg-facts:orr  (ground:orr (validate-reader:orr u.parsed rows ctx) rows ctx)
  =.  notes.facts  [gate-note notes.facts]
  ;<  facts=tg-facts:orr  bind:m  (tg-status-check gen rows facts)
  ;<  esc=(unit json)  bind:m
    ?:  =(~ obs.facts)  (pure:(fiber:fiber:nexus ,(unit json)) ~)
    (ask-decider gen (escalate-body:orr rows ctx obs.facts))
  =/  e=@ud  ?~(esc 0 (noul-of:orr u.esc 'needs_help_now'))
  =?  notes.facts  ?=(^ esc)  (snoc notes.facts (rap 3 'escalate: ' (crip (a-co:co e)) ~))
  =?  escalate.facts  &(?=(^ esc) (gte e escalate.cfg))  `(urgent-ids:orr facts)
  (pure:m [& | facts])
::  +tg-status-check: analyze.status_check: each status proposed for a
::  person put to the decider; one it calls a feeling with 60 or more is
::  dropped with a note
::
++  tg-status-check
  |=  [gen=config:orr rows=(list window-row:orr) facts=tg-facts:orr]
  =/  m  (fiber:fiber:nexus ,tg-facts:orr)
  ^-  form:m
  =/  asked=(list @ud)  (turn (status-asked:orr obs.facts) |=([i=@ud *] i))
  ?~  asked  (pure:m facts)
  ;<  ans=(unit json)  bind:m  (ask-decider gen (status-body:orr rows obs.facts))
  ?~  ans  (pure:m facts(notes (snoc notes.facts 'status check unavailable, kept')))
  =/  drop=(set @ud)
    %-  sy
    %+  skim  `(list @ud)`asked
    |=  i=@ud
    =/  c  (choice-of:orr u.ans (crip "status_{(a-co:co i)}"))
    &(!=('' choice.c) (gte p.c 60) !=('circumstance' choice.c))
  =/  kept=(list json)
    =/  n=@ud  0
    |-  ^-  (list json)
    ?~  obs.facts  ~
    =/  rest  $(obs.facts t.obs.facts, n +(n))
    ?:((~(has in drop) n) rest [i.obs.facts rest])
  =/  said=(list @t)
    %+  turn  (sort ~(tap in drop) lth)
    |=  i=@ud
    (rap 3 'status "' (ref-or-text:orr (gj:orr (snag i obs.facts) 'value')) '": dropped as a feeling' ~)
  (pure:m facts(obs kept, notes (weld notes.facts said)))
::  +tg-file: the facts through the writer, then the urgent pass: the
::  poke serve-generate sends, force with the ids to look at first
::
++  tg-file
  |=  [facts=tg-facts:orr who=@t now=@da kind=reader-kind:orr]
  =/  m  (fiber:fiber:nexus ,~)
  ^-  form:m
  =/  obs=(list json)  (turn obs.facts |=(o=json (tg-final-row o by.kind)))
  ;<  *  bind:m  (file-ops-on (observe-ops:orr bodies.facts obs) /tg)
  =/  act-ops=(list json)
    %+  turn  acts.facts
    |=(a=json (pairs:enjs:format ~[['op' s+'act'] ['action' (fill-act-as:orr a now by.kind)]]))
  ;<  *  bind:m  (file-ops-on act-ops /tg)
  ?~  escalate.facts  (pure:m ~)
  ;<  *  bind:m
    %+  poke-soft:io  (rf 0 / %'gen.sig')
    :-  [/ %json]
    (pairs:enjs:format ~[['force' b+&] ['about' a+(turn u.escalate.facts |=(x=@t `json`s+x))]])
  (pure:m ~)
::  +tg-final-row: a validated observation (subject, attr, value, at,
::  conf, message, until) as the writer's row: the source is the message
::  it came from, by telegram, the message key gone.
::
++  tg-final-row
  |=  [o=json signer=@t]
  ^-  json
  ?.  ?=([%o *] o)  o
  =/  msg=@t  (gs:orr o 'message')
  ?:  =('' msg)  o
  :-  %o
  %-  ~(gas by (~(del by p.o) 'message'))
  :~  ['source' (pairs:enjs:format ~[['kind' s+'chat'] ['id' s+msg]])]
      ['by' s+signer]
  ==
::  +tg-stranger: whether a business message comes through a connection
::  of an account not in people. The connection's owner is read from
::  telegram-connections.json, or asked of the telegram API once and
::  remembered there; one the API will not name is a stranger's.
::
++  tg-stranger
  |=  [cfg=tg-config:orr conn=@t]
  =/  m  (fiber:fiber:nexus ,?)
  ^-  form:m
  ?:  =('' conn)  (pure:m |)
  ;<  known=json  bind:m  (read-json (rf 0 / %'telegram-connections.json'))
  =/  owner=@t  (gs:orr known conn)
  ?.  =('' owner)  (pure:m !(~(has by people.cfg) owner))
  ;<  got=[status=@ud body=@t secs=@ud]  bind:m
    %^    get-json
        (rap 3 api-url.cfg '/bot' token.cfg '/getBusinessConnection?business_connection_id=' conn ~)
      ~s30
    %telegram
  =/  id=json  (gj:orr (gj:orr (gj:orr (fall (de:json:html body.got) ~) 'result') 'user') 'id')
  =/  found=@t  (num-cord:orr id)
  ?:  |(!=(200 status.got) =('' found))  (pure:m &)
  ;<  ~  bind:m
    (over:io (rf 0 / %'telegram-connections.json') [[/ %json] (set-key:orr known conn s+found)])
  (pure:m !(~(has by people.cfg) found))
::  +tg-record: what the reader did with the last update, for the page;
::  read_today counts the messages the analyst was asked about (read),
::  since the daily cap is about the model: a question, a gate refusal,
::  a held message and an ignored update do not move it
::
++  tg-record-down
  |=  [now=@da uid=@ud notes=(list @t)]
  =/  m  (fiber:fiber:nexus ,~)
  ^-  form:m
  ::  read again here: the model call took minutes, and a token saved
  ::  meanwhile reset update_id in this file
  ;<  last=json  bind:m  (read-json (rf 0 / %'telegram-last.json'))
  =/  down=json
    %-  pairs:enjs:format
    :~  ['at' s+(en-iso:orr now)]
        ['update_id' (numb:enjs:format uid)]
        ['notes' a+(turn (scag 6 notes) |=(n=@t `json`s+(end [3 300] n)))]
    ==
  (over:io (rf 0 / %'telegram-last.json') [[/ %json] (set-key:orr last 'down' down)])
++  tg-record
  |=  [last=json now=@da uid=@ud chat=@t from=@t outcome=@t notes=(list @t) read=?]
  =/  m  (fiber:fiber:nexus ,~)
  ^-  form:m
  =/  day=@t  (end [3 10] (en-iso:orr now))
  =/  today=@ud  ?:(=(day (gs:orr last 'day')) (fall (gn:orr last 'read_today') 0) 0)
  %+  over:io  (rf 0 / %'telegram-last.json')
  :-  [/ %json]
  %-  pairs:enjs:format
  :~  ['at' s+(en-iso:orr now)]
      ['update_id' (numb:enjs:format uid)]
      ['chat' s+chat]
      ['from' s+from]
      ['outcome' s+outcome]
      ['notes' a+(turn (scag 20 notes) |=(n=@t `json`s+(end [3 300] n)))]
      ['day' s+day]
      ['read_today' (numb:enjs:format ?:(read +(today) today))]
  ==
::  +do-add-client: one minted key, refused when the id is taken or the
::  table is full. The row arrives hashed; the writer never sees a
::  secret. Keys are not model state, so no beacon bump.
::
++  do-add-client
  |=  jon=json
  =/  m  (fiber:fiber:nexus ,?)
  ^-  form:m
  =/  c=(unit client:orr)  (de-client:orr (gj:orr jon 'client'))
  ?~  c  (refuse 'add-client' 'client: bad')
  ;<  clients=json  bind:m  (read-json (rf 0 / %'clients.json'))
  =/  cm=(map @t json)  ?:(?=([%o *] clients) p.clients ~)
  ?:  (~(has by cm) id.u.c)  (refuse 'add-client' 'id: taken')
  ?:  (gte ~(wyt by cm) max-clients:orr)  (refuse 'add-client' 'clients: over 50')
  ;<  ~  bind:m
    (over:io (rf 0 / %'clients.json') [[/ %json] [%o (~(put by cm) id.u.c (en-client-row:orr u.c))]])
  ;<  ~  bind:m  (note 'add-client' & name.u.c)
  (pure:m |)
::  +do-drop-client: a revoked key is gone; nothing else changes
::
++  do-drop-client
  |=  jon=json
  =/  m  (fiber:fiber:nexus ,?)
  ^-  form:m
  =/  id=@t  (gs:orr jon 'id')
  ;<  clients=json  bind:m  (read-json (rf 0 / %'clients.json'))
  =/  cm=(map @t json)  ?:(?=([%o *] clients) p.clients ~)
  ?.  (~(has by cm) id)  (refuse 'drop-client' 'no such client')
  ;<  ~  bind:m  (over:io (rf 0 / %'clients.json') [[/ %json] [%o (~(del by cm) id)]])
  ;<  ~  bind:m  (note 'drop-client' & id)
  (pure:m |)
::  +do-touch-client: last use, stamped by the writer's clock. No note:
::  one an hour per key would only fill the ring.
::
++  do-touch-client
  |=  jon=json
  =/  m  (fiber:fiber:nexus ,?)
  ^-  form:m
  =/  id=@t  (gs:orr jon 'id')
  ;<  clients=json  bind:m  (read-json (rf 0 / %'clients.json'))
  =/  cm=(map @t json)  ?:(?=([%o *] clients) p.clients ~)
  =/  row=json  (fall (~(get by cm) id) ~)
  ?.  ?=([%o *] row)  (pure:m |)
  ;<  now=@da  bind:m  get-time:io
  =/  next=json  [%o (~(put by p.row) 'used' (en-time:orr now))]
  ;<  ~  bind:m  (over:io (rf 0 / %'clients.json') [[/ %json] [%o (~(put by cm) id next)]])
  (pure:m |)
::  ==  the executor (version 34): the ship carries out its own approved
::  actions. docs/superpowers/specs/2026-09-21-executors-on-ship-design.md
::
::  The lib plans (+plan-exec, +plan-mirror); the fiber here files. One
::  pass is +exec-pass (the approved actions, each claimed, read back,
::  carried out and reported) then +todo-pass (the calendar's todo list
::  against the task actions), then the record.
::
::  what a pass did, for exec-last.json
::
+$  exec-tally
  $:  claimed=@ud                               ::  actions the ship claimed
      sent=@ud                                  ::  messages delivered
      placed=@ud                                ::  events and todos made
      failed=(list [id=@t title=@t note=@t])    ::  the newest first
      ticked=@ud                                ::  todos ticked for a done action
      deleted=@ud                               ::  todos deleted for a dismissed or failed one
      moved=@ud                                 ::  todos whose due followed the action's
      closed=@ud                                ::  actions done because their todo was ticked
      adopted=@ud                               ::  hand-typed todos made into tasks
      missing=(list @t)                         ::  desks link does not know
      notes=(list @t)
  ==
::  what the todo list was last read against: the actions as a hash,
::  the store's version, and the todos read then. The store, a few
::  megabytes turned into JSON, is re-read only when one of the two
::  moved; the beacon moves on every fact the ship takes, and most of
::  those are neither the executor's nor the mirror's.
::
+$  exec-seen  [acts=@uvH store=cass:clay todos=(list todo:orr)]
::  the calendar as one pass sees it: where it is (~ when link does not
::  know it), its todos (~ when the store could not be read this time),
::  what they were read against, and whether anything moved since the
::  last pass, which is when the mirror has work
::
+$  exec-cal
  $:  base=(unit path)
      todos=(unit (list todo:orr))
      seen=(unit exec-seen)
      moved=?
  ==
::  +exec-run: one pass: the calendar read once, the approved actions,
::  the mirror, then the record; and whether the pass moved anything,
::  which is when another pass should follow at once
::
++  exec-run
  |=  seen=(unit exec-seen)
  =/  m  (fiber:fiber:nexus ,[(unit exec-seen) busy=?])
  ^-  form:m
  ;<  cal=exec-cal  bind:m  (read-calendar seen)
  ;<  tally=exec-tally  bind:m  (exec-pass cal)
  ;<  tally=exec-tally  bind:m  (todo-pass cal tally)
  ;<  ~  bind:m  (exec-record tally)
  (pure:m [seen.cal !(tally-idle tally)])
::  +tally-idle: a pass that moved nothing (a claim that was refused
::  does not count, nor a poke the calendar refused, so a refusal that
::  repeats does not run passes without end)
::
++  tally-idle
  |=  t=exec-tally
  ^-  ?
  ?&  =(0 :(add claimed.t sent.t placed.t ticked.t deleted.t moved.t closed.t adopted.t))
      ?=(~ failed.t)
  ==
::  +read-calendar: the todo list, through the store's JSON, unless
::  neither the actions nor the store moved since it was last read, in
::  which case the todos read then still hold
::
++  read-calendar
  |=  seen=(unit exec-seen)
  =/  m  (fiber:fiber:nexus ,exec-cal)
  ^-  form:m
  ;<  base=(unit path)  bind:m  (find-base %calendar)
  ?~  base  (pure:m [~ ~ seen |])
  ;<  acts=(list [id=@ta a=action:orr])  bind:m  (load-actions 0)
  ;<  vw=(unit view:nexus)  bind:m  (peek-soft:io [%& %& u.base %'calendar.calendar'] ~)
  ?.  ?=([~ %file *] vw)  (pure:m [base ~ seen |])
  =/  acts-hash=@uvH  (sham acts)
  ?:  &(?=(^ seen) =(acts.u.seen acts-hash) =(store.u.seen cass.u.vw))
    (pure:m [base `todos.u.seen seen |])
  ;<  store=(unit json)  bind:m  (calendar-json u.base (sang-noun:tarball sang.u.vw))
  ?~  store  (pure:m [base ~ seen |])
  =/  todos=(list todo:orr)  (todos-of:orr u.store)
  (pure:m [base `todos `[acts-hash cass.u.vw todos] &])
::  +keep-calendar: subscribe to the calendar's store on /cal, & when
::  the keep took. Its own taker, since +keep waits for ever on a veto
::  and +keep-soft leaves the veto in the queue for the next hard taker
::  to fail on; a refused road must leave the executor running for the
::  actions it can still serve. News is only a wake signal, so no blot.
::
++  keep-calendar
  =/  m  (fiber:fiber:nexus ,?)
  ^-  form:m
  ;<  base=(unit path)  bind:m  (find-base %calendar)
  ?~  base  (pure:m |)
  ;<  ~  bind:m  (send-dart:io %node /cal [%& %& u.base %'calendar.calendar'] %keep ~)
  |=  input:fiber:nexus
  :+  ~  q.state
  ?+  in  [%skip ~]
      ~  [%wait ~]
      [~ %veto %node * * *]
    ?.(=(/cal wire.dart.u.in) [%skip ~] [%done |])
      [~ %news * *]
    ?.(=(/cal wire.u.in) [%skip ~] [%done &])
  ==
::  +ship-set-action: the writer's set-action by the ship
::
++  ship-set-action
  |=  [id=@t status=@t why=@t]
  ^-  json
  (set-action-op:orr `@ta`id status why 'ship')
::  +tang-head: a refusal's first line, as the note an action fails with
::
++  tang-head
  |=  t=tang
  ^-  @t
  ?~  t  'refused'
  (crip ~(ram re i.t))
::  +note-missing: a desk link does not know, named once in the tally
::
++  note-missing
  |=  [t=exec-tally name=@t]
  ^-  exec-tally
  ?:  (lien missing.t |=(x=@t =(x name)))  t
  t(missing (snoc missing.t name))
::  +exec-pass: the approved actions the ship can serve. A message or
::  a calendar event is claimed through the writer and the claim read
::  back, since another executor may hold it (the claim protocol's job,
::  and it already works); then carried out and moved to done or failed
::  with the note. A desk link does not know, or a road the owner has
::  refused, claims nothing and fails nothing: the plan is left
::  approved for another executor, the desk noted once in missing (the
::  spec's discovery rule) or the refusal once in notes. The road is
::  proved before any claim with a poke each writer ignores, since a
::  veto is the only way a refusal shows and a claimed action cannot
::  go back to approved; and only when a plan will poke it this pass,
::  so a pass with nothing new sends nothing. A message with no address
::  (no telegram attribute and not in the reader's people map, no ship
::  attribute) or no bot token to send it with is left approved the
::  same way, noted once, since another executor may know the way and
::  a claim the ship cannot serve would only fail it. A task is
::  different: the todo list IS the
::  task list (the model's own words: approved tasks not yet done), so
::  its action stays approved once its todo is placed, and done means
::  the task was done, ticked in the calendar or on the page. The todo
::  carrying the action id is what stops a second placing, as Talon's
::  mirror did, so a task is placed only when the list was read this
::  pass. A task the calendar itself filed (an adopted todo, by
::  calendar) has its todo already and is never placed.
::
++  exec-pass
  |=  cal=exec-cal
  =/  m  (fiber:fiber:nexus ,exec-tally)
  ^-  form:m
  ;<  acts=(list [id=@ta a=action:orr])  bind:m  (load-actions 0)
  ::  nothing approved plans nothing, and the tree is not read for it
  ?.  (lien acts |=([* a=action:orr] =(%approved status.a)))  (pure:m *exec-tally)
  ;<  now=@da  bind:m  get-time:io
  ;<  schema=json  bind:m  (read-json (rf 0 / %'schema.json'))
  ;<  all=(list loaded:orr)  bind:m  (load-bodies 0)
  ;<  tg-json=json  bind:m  (read-json (rf 0 / %'telegram.json'))
  =/  tg=tg-config:orr  (de-tg-config:orr tg-json)
  =/  plans=(list exec-plan:orr)  (plan-exec:orr acts all (multi-of:orr schema) people.tg now)
  ::  the desks the plans need, found and their roads proved, once, and
  ::  only for a plan that will poke this pass: a calendar event, a
  ::  todo not yet placed (and not the calendar's own), a mail with an
  ::  address
  =/  need-cal=?
    %+  lien  plans
    |=  p=exec-plan:orr
    ?:  ?=(?(%calendar %uncalendar) target.p)  &
    ?.  =(%todo target.p)  |
    ?~  todos.cal  |
    =/  was=(unit action:orr)  (act-of acts id.p)
    ?~  was  |
    ?:  =('calendar' by.u.was)  |
    !(lien u.todos.cal |=(t=todo:orr =(orrery.t id.p)))
  =/  need-mail=?  (lien plans |=(p=exec-plan:orr &(=(%mail target.p) =('' note.p))))
  ;<  cal-shut=(unit @t)  bind:m
    ?.  &(need-cal ?=(^ base.cal))  (pure:(fiber:fiber:nexus ,(unit @t)) ~)
    %+  road-shut  [%& %& u.base.cal %'calendar.calendar']
    [[/ %json] (pairs:enjs:format ~[['action' s+'noop']])]
  ;<  aus=(unit path)  bind:m
    ?.(need-mail (pure:(fiber:fiber:nexus ,(unit path)) ~) (find-base %auspex))
  ;<  aus-shut=(unit @t)  bind:m
    ?~  aus  (pure:(fiber:fiber:nexus ,(unit @t)) ~)
    (road-shut [%& %& u.aus %'main.sig'] [[/ %json] ~])
  =|  tally=exec-tally
  |-
  ?~  plans  (pure:m tally)
  =/  p=exec-plan:orr  i.plans
  =/  was=(unit action:orr)  (act-of acts id.p)
  ?~  was  $(plans t.plans)
  =/  title=@t  title.u.was
  ::  a message with no way out is left approved and noted, before any
  ::  desk is asked for it
  ?.  =('' note.p)
    $(plans t.plans, tally (note-once tally (cat 3 'a message waits: ' note.p)))
  ?:  &(=(%telegram target.p) =('' token.tg))
    $(plans t.plans, tally (note-once tally 'a message waits: no bot token'))
  ::  the desk the plan needs, or why it is left approved. An uncalendar
  ::  plan needs the calendar, the same road a calendar action needs.
  =/  desk=(each path exec-tally)
    ?-    target.p
        %telegram  [%& /]
        %mail
      ?~  aus  [%| (note-missing tally 'auspex')]
      ?~  aus-shut  [%& u.aus]
      [%| (note-once tally (cat 3 'a message waits: the auspex road is refused: ' u.aus-shut))]
        ?(%calendar %todo %uncalendar)
      ?~  base.cal  [%| (note-missing tally 'calendar')]
      ?~  cal-shut  [%& u.base.cal]
      [%| (note-once tally (cat 3 'an action waits: the calendar road is refused: ' u.cal-shut))]
    ==
  ?:  ?=(%| -.desk)  $(plans t.plans, tally p.desk)
  ?:  =(%todo target.p)
    ?:  =('calendar' by.u.was)  $(plans t.plans)
    ?~  todos.cal  $(plans t.plans, tally (note-once tally 'a task waits: the todo list could not be read'))
    ?:  (lien u.todos.cal |=(t=todo:orr =(orrery.t id.p)))  $(plans t.plans)
    ;<  err=(unit tang)  bind:m  (poke-calendar p.desk body.p)
    ?^  err
      $(plans t.plans, tally (note-once tally (cat 3 'the calendar refused a todo: ' (tang-head u.err))))
    $(plans t.plans, tally tally(placed +(placed.tally)))
  ;<  *  bind:m  (file-ops-on ~[(ship-set-action id.p 'claimed' '')] /exec)
  ;<  after=(list [id=@ta a=action:orr])  bind:m  (load-actions 0)
  =/  mine=?
    %+  lien  after
    |=([id=@ta a=action:orr] &(=(id id.p) =(%claimed status.a) =('ship' (claimant:orr a))))
  ?.  mine  $(plans t.plans)
  =.  claimed.tally  +(claimed.tally)
  ;<  [ok=? note=@t]  bind:m  (exec-one p tg p.desk)
  ;<  *  bind:m  (file-ops-on ~[(ship-set-action id.p ?:(ok 'done' 'failed') note)] /exec)
  =?  tally  !ok
    =/  f=(list [id=@t title=@t note=@t])  [[id.p title note] failed.tally]
    tally(failed (scag 20 f))
  =?  tally  &(ok ?=(?(%telegram %mail) target.p))  tally(sent +(sent.tally))
  =?  tally  &(ok ?=(?(%calendar %uncalendar) target.p))  tally(placed +(placed.tally))
  $(plans t.plans)
::  +road-shut: why a poke road is refused, or ~ when it is open. The
::  proof is a poke the target ignores: the calendar drops an action
::  it does not know, and auspex's writer drops a blot it does not
::  know. A veto (or a nack) is the road's answer before any claim.
::
++  road-shut
  |=  [road=road:tarball =bask:tarball]
  =/  m  (fiber:fiber:nexus ,(unit @t))
  ^-  form:m
  ;<  err=(unit tang)  bind:m  (poke-soft:io road bask)
  (pure:m (bind err tang-head))
::  +act-of: one action by id
::
++  act-of
  |=  [acts=(list [id=@ta a=action:orr]) id=@t]
  ^-  (unit action:orr)
  ?~  acts  ~
  ?:(=(id id.i.acts) `a.i.acts $(acts t.acts))
::  +note-once: a note in the tally, once however many times it comes
::
++  note-once
  |=  [t=exec-tally why=@t]
  ^-  exec-tally
  ?:  (lien notes.t |=(x=@t =(x why)))  t
  t(notes [why notes.t])
::  +exec-one: one claimed plan carried out at the desk found for it:
::  whether it went and the note. A plan with no address, or a telegram
::  one with no token, is never claimed (exec-pass leaves it approved),
::  so the plan here has its way out. A task is placed without a claim
::  and never comes here.
::
++  exec-one
  |=  [p=exec-plan:orr tg=tg-config:orr base=path]
  =/  m  (fiber:fiber:nexus ,[ok=? note=@t])
  ^-  form:m
  ?+    target.p  (pure:m [| 'a task is placed without a claim'])
      %telegram
    ;<  [ok=? why=@t]  bind:m
      %+  send-telegram  tg
      %-  pairs:enjs:format
      :~  ['chat_id' s+(gs:orr body.p 'chat_id')]
          ['text' s+(clean-text:orr (gs:orr body.p 'text'))]
      ==
    (pure:m [ok ?:(ok (cat 3 'sent to ' to.p) why)])
  ::
      %mail
    =/  who=(unit @p)  (slaw %p to.p)
    ?~  who  (pure:m [| (cat 3 to.p ' is not a ship name')])
    ;<  err=(unit tang)  bind:m
      %+  poke-auspex  base
      [u.who (gs:orr body.p 'subject') (clean-text:orr (gs:orr body.p 'text'))]
    ?^  err  (pure:m [| (tang-head u.err)])
    (pure:m [& (cat 3 'sent by mail to ' to.p)])
  ::
      %calendar
    ;<  err=(unit tang)  bind:m  (poke-calendar base body.p)
    ?^  err  (pure:m [| (tang-head u.err)])
    (pure:m [& 'on the calendar'])
  ::
      %uncalendar
    ::  a cancel takes the event off the calendar, or skips the one
    ::  occurrence the plan names. The store says which it is: a timed
    ::  or allday row whose kind is once happens once and is deleted,
    ::  anything else repeats and needs the occurrence, since the
    ::  calendar skips by the moment an occurrence starts.
    ;<  row=(each json @t)  bind:m  (event-row base to.p)
    ?:  ?=(%| -.row)  (pure:m [| p.row])
    =/  cat=@t  (gs:orr p.row 'cat')
    ?:  |(=('todo' cat) =('date' cat))
      (pure:m [| 'a task or a date is not something a cancel takes off the calendar'])
    =/  once=?  =('once' (gs:orr p.row 'kind'))
    =/  start=(unit @ud)  (gn:orr body.p 'start_ms')
    ?:  once
      ;<  err=(unit tang)  bind:m
        %+  poke-calendar  base
        (pairs:enjs:format ~[['action' s+'del-event'] ['id' s+to.p]])
      ?^  err  (pure:m [| (tang-head u.err)])
      ::  the poke is acked, not answered, so the proof that the event
      ::  is gone is that the store no longer has it.
      ;<  after=(each json @t)  bind:m  (event-row base to.p)
      ?:  ?=(%| -.after)  (pure:m [& 'off the calendar'])
      (pure:m [| 'the calendar kept the event'])
    ?~  start  (pure:m [| 'that event repeats, so the occurrence is needed'])
    =/  before=@ud  (lent (ga:orr p.row 'except'))
    ;<  err=(unit tang)  bind:m
      %+  poke-calendar  base
      %-  pairs:enjs:format
      :~  ['action' s+'skip-at']
          ['id' s+to.p]
          ['start_ms' (numb:enjs:format u.start)]
      ==
    ?^  err  (pure:m [| (tang-head u.err)])
    ::  the calendar drops a skip it cannot place (no occurrence starts
    ::  at that moment, or it is already skipped) without saying so, so
    ::  the proof is the event's own list of dropped occurrences: one
    ::  longer means this skip took.
    ;<  after=(each json @t)  bind:m  (event-row base to.p)
    ?:  ?=(%| -.after)  (pure:m [| p.after])
    ?:  (gth (lent (ga:orr p.after 'except')) before)
      (pure:m [& 'that occurrence skipped'])
    (pure:m [| 'the calendar skipped nothing: no occurrence starts then, or it is skipped already'])
  ==
::  +event-row: one event as the store's JSON gives it, or why not. The
::  store is read fresh each time, since a cancel acts on what the
::  calendar holds now, not on what the mirror last saw.
::
++  event-row
  |=  [base=path id=@t]
  =/  m  (fiber:fiber:nexus ,(each json @t))
  ^-  form:m
  ;<  vw=(unit view:nexus)  bind:m  (peek-soft:io [%& %& base %'calendar.calendar'] ~)
  ?.  ?=([~ %file *] vw)  (pure:m [%| 'the calendar\'s store could not be read'])
  ;<  store=(unit json)  bind:m  (calendar-json base (sang-noun:tarball sang.u.vw))
  ?~  store  (pure:m [%| 'the calendar\'s store could not be read'])
  =/  rows=(list json)
    %+  skim  (ga:orr u.store 'events')
    |=(e=json =(id (gs:orr e 'id')))
  ?~  rows  (pure:m [%| 'the calendar does not have that event'])
  (pure:m [%& i.rows])
::  +send-telegram: one sendMessage through the reader's token, the
::  body the planner made (chat_id and text). Telegram answers ok false
::  with a description, which is the failure note; no answer at all
::  (the timer, a refused road) fails with +post-json's reason.
::
++  send-telegram
  |=  [cfg=tg-config:orr body=json]
  =/  m  (fiber:fiber:nexus ,[ok=? why=@t])
  ^-  form:m
  ;<  got=[status=@ud body=@t secs=@ud]  bind:m
    (post-json (rap 3 api-url.cfg '/bot' token.cfg '/sendMessage' ~) '' body ~s30 %send)
  =/  resp=json  (fall (de:json:html body.got) [%o ~])
  ?:  &(=(200 status.got) ?=([%b %.y] (gj:orr resp 'ok')))  (pure:m [& ''])
  =/  why=@t  (gs:orr resp 'description')
  ?.  =('' why)  (pure:m [| why])
  ?:  =(0 status.got)  (pure:m [| body.got])
  (pure:m [| (cat 3 'telegram answered ' (crip (a-co:co status.got)))])
::  +poke-auspex: a send to auspex's writer. Its action type lays %send
::  out as to, subject, body, body-mime ('' is text/plain), prev, files
::  and bcc; the marc is a noun passthrough and the writer clams it, so
::  the layout here must match auspex's. A refusal inside the writer is
::  not seen here; the road's veto and a nack are.
::
++  poke-auspex
  |=  [base=path to=@p subject=@t body=@t]
  =/  m  (fiber:fiber:nexus ,(unit tang))
  ^-  form:m
  =/  send=*  [%send (sy ~[to]) subject body '' ~ ~ ~]
  (poke-soft:io [%& %& base %'main.sig'] [[/ %auspex-action] send])
::  +poke-calendar: one action to the calendar's store, which is the
::  fiber that takes its JSON pokes (add-event, edit-event, done-event,
::  del-event). A bad body is dropped inside the calendar, not refused.
::
++  poke-calendar
  |=  [base=path jon=json]
  =/  m  (fiber:fiber:nexus ,(unit tang))
  ^-  form:m
  (poke-soft:io [%& %& base %'calendar.calendar'] [[/ %json] jon])
::  +todo-pass: the calendar's todo list against the task actions,
::  both ways. Nothing when the calendar is not installed or its store
::  could not be read, and nothing again while neither the actions nor
::  the store have moved since the list was last read. The actions are
::  read afresh, since +exec-pass just moved some.
::
++  todo-pass
  |=  [cal=exec-cal tally=exec-tally]
  =/  m  (fiber:fiber:nexus ,exec-tally)
  ^-  form:m
  ?~  base.cal  (pure:m (note-missing tally 'calendar'))
  ?~  todos.cal  (pure:m (note-once tally 'the todo list could not be read'))
  ?.  moved.cal  (pure:m tally)
  ;<  now=@da  bind:m  get-time:io
  ;<  acts=(list [id=@ta a=action:orr])  bind:m  (load-actions 0)
  =/  ops=(list mirror-op:orr)  (plan-mirror:orr u.todos.cal acts now)
  (run-mirror-ops u.base.cal ops tally)
::  +calendar-json: the calendar's store as JSON. The store's noun is
::  the calendar's own type, which orrery cannot clam, and a peek with
::  a JSON blot converts in the PEEKING fiber's code namespace (the
::  kernel's +hydrate validates and finds the tube from the peeker's
::  rail), where no calendar marc lives. So the conversion the ball's
::  own JSON route makes is made here by hand: the calendar's compiled
::  marc, fetched from the code namespace that governs the store (a
::  %font then a %code dart, both read operations under the peek
::  grant), validates the raw noun and grows it to JSON. ~ when any
::  step refuses or crashes.
::
++  calendar-json
  |=  [base=path raw=*]
  =/  m  (fiber:fiber:nexus ,(unit json))
  ^-  form:m
  ;<  font=(unit (unit bend:tarball))  bind:m  (font-soft [%& %& base %'calendar.calendar'])
  ?.  ?=([~ ~ *] font)  (pure:m ~)
  ;<  mv=(unit vase)  bind:m  (code-soft (extend-road:tarball [%| u.u.font] /mar %calendar))
  ?~  mv  (pure:m ~)
  =/  mc=(unit marc:tarball)  (mole |.(!<(marc:tarball u.mv)))
  ?~  mc  (pure:m ~)
  (pure:m (mole |.(!<(json ((grow:u.mc [/ %json]) (vale:u.mc raw))))))
::  +font-soft: +get-font that answers ~ on a veto instead of failing
::
++  font-soft
  |=  road=road:tarball
  =/  m  (fiber:fiber:nexus ,(unit (unit bend:tarball)))
  ^-  form:m
  ;<  w=wire  bind:m  (nonce:io /font)
  ;<  ~  bind:m  (send-dart:io %node w road %font ~)
  |=  input:fiber:nexus
  :+  ~  q.state
  ?+  in  [%skip ~]
      ~  [%wait ~]
      [~ %veto %node * * *]
    ?.(=(w wire.dart.u.in) [%skip ~] [%done ~])
      [~ %font * *]
    ?.(=(w wire.u.in) [%skip ~] [%done res.u.in])
  ==
::  +code-soft: +get-code that answers ~ on a veto instead of failing
::
++  code-soft
  |=  road=road:tarball
  =/  m  (fiber:fiber:nexus ,(unit vase))
  ^-  form:m
  ;<  w=wire  bind:m  (nonce:io /code)
  ;<  ~  bind:m  (send-dart:io %node w road %code ~)
  |=  input:fiber:nexus
  :+  ~  q.state
  ?+  in  [%skip ~]
      ~  [%wait ~]
      [~ %veto %node * * *]
    ?.(=(w wire.dart.u.in) [%skip ~] [%done ~])
      [~ %code * *]
    ?.  =(w wire.u.in)  [%skip ~]
    ?.  ?=(%| -.res.u.in)  [%done ~]
    ?.(?=(%vase -.p.res.u.in) [%done ~] [%done `vase.p.res.u.in])
  ==
::  +run-mirror-ops: the mirror's ops in order, each writer op filed
::  and settled on its own and each calendar op poked. An adoption is
::  three ops: the act, the approval of the id the act will get, and
::  the todo's mark. The writer refuses an act whose open twin exists,
::  and then the approval names an id that does not exist and the mark
::  would give the todo an id naming no action, so that it is never
::  adopted: after an act the actions are re-read, and when the id is
::  not there the two ops that follow are dropped. An approval refused
::  because policy approved the act already is harmless trail noise.
::
++  run-mirror-ops
  |=  [base=path ops=(list mirror-op:orr) tally=exec-tally]
  =/  m  (fiber:fiber:nexus ,exec-tally)
  ^-  form:m
  ::  how many of the ops ahead belong to the adoption under way
  =/  adopting=@ud  0
  |-
  ?~  ops  (pure:m tally)
  =/  rest=@ud  ?:(=(0 adopting) 0 (dec adopting))
  ?-    -.i.ops
      %writer
    ;<  *  bind:m  (file-ops-on ~[+.i.ops] /exec)
    ?.  =('act' (gs:orr +.i.ops 'op'))
      ?.  =(0 adopting)  $(ops t.ops, adopting rest)
      $(ops t.ops, closed.tally +(closed.tally))
    =/  want=@t
      ?~  t.ops  ''
      ?.(?=(%writer -.i.t.ops) '' (gs:orr +.i.t.ops 'id'))
    ;<  acts=(list [id=@ta a=action:orr])  bind:m  (load-actions 0)
    ?.  ?=(^ (act-of acts want))  $(ops (slag 2 t.ops))
    $(ops t.ops, adopting 2, adopted.tally +(adopted.tally))
  ::
      %calendar
    ;<  err=(unit tang)  bind:m  (poke-calendar base +.i.ops)
    ?^  err
      =/  why=@t  (cat 3 'the calendar refused a poke: ' (tang-head u.err))
      $(ops t.ops, adopting rest, tally (note-once tally why))
    =/  act=@t  (gs:orr +.i.ops 'action')
    %=  $
      ops  t.ops
      adopting  rest
      ticked.tally  ?:(=('done-event' act) +(ticked.tally) ticked.tally)
      deleted.tally  ?:(=('del-event' act) +(deleted.tally) deleted.tally)
      moved.tally  ?:(&(=('edit-event' act) =(0 adopting)) +(moved.tally) moved.tally)
    ==
  ==
::  +exec-record: what the pass did, for the page and the owner's eye.
::  A pass that moved nothing (most of them: the beacon moves on every
::  fact, and the wake after a placing is one) keeps the last pass that
::  did, with its acted_at, and moves only the time and what it saw
::  missing or refused, so the card reads as the last thing done, when
::  the executor last looked, and what stands in its way now. The
::  failed list reads newest first.
::
++  exec-record
  |=  t=exec-tally
  =/  m  (fiber:fiber:nexus ,~)
  ^-  form:m
  ;<  now=@da  bind:m  get-time:io
  ;<  last=json  bind:m  (read-json (rf 0 / %'exec-last.json'))
  =/  active=?  !(tally-idle t)
  =/  saw=(list [@t json])
    :~  ['at' (en-time:orr now)]
        ['missing' a+(turn missing.t |=(x=@t `json`s+x))]
        ['notes' a+(turn (flop notes.t) |=(x=@t `json`s+x))]
    ==
  ?:  &(!active ?=([%o *] last) !=(~ p.last))
    =/  kept=(map @t json)  p.last
    (over:io (rf 0 / %'exec-last.json') [[/ %json] [%o (~(gas by kept) saw)]])
  =/  doc=json
    %-  pairs:enjs:format
    %+  weld  saw
    ^-  (list [@t json])
    :~  ['acted_at' ?:(active (en-time:orr now) ~)]
        ['claimed' (numb:enjs:format claimed.t)]
        ['sent' (numb:enjs:format sent.t)]
        ['placed' (numb:enjs:format placed.t)]
        :-  'failed'
        :-  %a
        %+  turn  failed.t
        |=  [id=@t title=@t note=@t]
        (pairs:enjs:format ~[['id' s+id] ['title' s+title] ['note' s+note]])
        ['ticked' (numb:enjs:format ticked.t)]
        ['deleted' (numb:enjs:format deleted.t)]
        ['moved' (numb:enjs:format moved.t)]
        ['closed' (numb:enjs:format closed.t)]
        ['adopted' (numb:enjs:format adopted.t)]
    ==
  (over:io (rf 0 / %'exec-last.json') [[/ %json] doc])
::  ==  who is asking
::
::  an actor: the owner (the cookie, writing as "http"), or a key with
::  its identity and its scope
::
+$  actor  [owner=? by=@t scope=(unit scope:orr)]
::  +identify: the owner cookie, else a valid bearer token, else ~. A
::  key's last use is stamped through the writer at most hourly.
::
++  identify
  |=  [req=inbound-request:eyre src=@p our=@p]
  =/  m  (fiber:fiber:nexus ,(unit actor))
  ^-  form:m
  ?:  &(authenticated.req =(src our))  (pure:m `[& 'http' ~])
  =/  au=(unit @t)  (get-header:http 'authorization' header-list.request.req)
  ?~  au  (pure:m ~)
  =/  tok=(unit [id=@t secret=@t])  (parse-bearer:orr u.au)
  ?~  tok  (pure:m ~)
  ;<  clients=json  bind:m  (read-json (rf 1 / %'clients.json'))
  =/  c=(unit client:orr)  (de-client:orr (gj:orr clients id.u.tok))
  ?~  c  (pure:m ~)
  ?.  (client-ok:orr u.c secret.u.tok)  (pure:m ~)
  ;<  now=@da  bind:m  get-time:io
  ;<  ~  bind:m
    ?:  &(?=(^ used.u.c) (lth now (add u.used.u.c ~h1)))  (pure:(fiber:fiber:nexus ,~) ~)
    (poke-writer 1 (pairs:enjs:format ~[['op' s+'touch-client'] ['id' s+id.u.c]]))
  (pure:m `[| by.u.c `scope.u.c])
::  ==  keys: the client routes, owner only
::
::  +serve-mint: a new key. The secret is answered once and stored only
::  as a salted hash; the row goes through the writer. The id and the
::  cap are checked here too, so the answer is honest without a read
::  back.
::
++  serve-mint
  |=  [eyre-id=@ta jon=json]
  =/  m  (fiber:fiber:nexus ,~)
  ^-  form:m
  ?.  ?=([%o *] jon)  (send-err eyre-id 400 'a JSON object is required')
  =/  name=@t  (gs:orr jon 'name')
  ?:  |(=('' name) (gth (met 3 name) max-name:orr))  (send-err eyre-id 400 'name: 1 to 200 bytes')
  =/  who=@t  (gs:orr jon 'by')
  ?:  |(=('' who) (gth (met 3 who) max-by:orr))  (send-err eyre-id 400 'by: 1 to 64 bytes')
  =/  sc  (de-scope:orr (gj:orr jon 'scope'))
  ?:  ?=(%| -.sc)  (send-err eyre-id 400 p.sc)
  ;<  clients=json  bind:m  (read-json (rf 1 / %'clients.json'))
  =/  cm=(map @t json)  ?:(?=([%o *] clients) p.clients ~)
  ?:  (gte ~(wyt by cm) max-clients:orr)  (send-err eyre-id 409 'clients: over 50')
  ;<  eny=@uvJ  bind:m  get-entropy:io
  ;<  now=@da  bind:m  get-time:io
  =/  id=@t  (id-of:orr eny)
  ?:  (~(has by cm) id)  (send-err eyre-id 409 'id: taken, try again')
  =/  salt=@t  (scot %uv (end [3 10] (rsh [3 5] eny)))
  =/  secret=@t  (secret-of:orr (rsh [3 15] eny))
  =/  c=client:orr  [id name who p.sc salt (hash-token:orr salt secret) now ~]
  =/  op=json  (pairs:enjs:format ~[['op' s+'add-client'] ['client' (en-client-row:orr c)]])
  %^  write-then  eyre-id  op
  %^  send-json  eyre-id  200
  %-  pairs:enjs:format
  :~  ['id' s+id]
      ['name' s+name]
      ['by' s+who]
      ['scope' (en-scope:orr p.sc)]
      ['token' s+(rap 3 id '.' secret ~)]
      ['made' (en-time:orr now)]
  ==
::  +serve-clients: the keys as the owner sees them: no salt, no hash
::
++  serve-clients
  |=  eyre-id=@ta
  =/  m  (fiber:fiber:nexus ,~)
  ^-  form:m
  ;<  cm=(map @t json)  bind:m  (read-map (rf 1 / %'clients.json'))
  =/  rows=(list json)
    %+  murn  ~(tap by cm)
    |=  [id=@t j=json]
    ^-  (unit json)
    =/  c=(unit client:orr)  (de-client:orr j)
    ?~(c ~ `(en-client-view:orr u.c))
  (send-json eyre-id 200 a+rows)
::  +serve-drop-client: a key revoked by id
::
++  serve-drop-client
  |=  [eyre-id=@ta id=@ta]
  =/  m  (fiber:fiber:nexus ,~)
  ^-  form:m
  ;<  clients=json  bind:m  (read-json (rf 1 / %'clients.json'))
  ?~  (gj:orr clients id)  (send-err eyre-id 404 'no such client')
  =/  op=json  (pairs:enjs:format ~[['op' s+'drop-client'] ['id' s+id]])
  %^  write-then  eyre-id  op
  (send-json eyre-id 200 (pairs:enjs:format ~[['id' s+id] ['ok' b+&]]))
::  ==  the scope, applied
::
::  +hidden-for: the attributes an actor never sees: none for the
::  owner, policy.sensitive for a key
::
++  hidden-for
  |=  [act=actor policy=json]
  ^-  (set @t)
  ?:(owner.act ~ (sensitive-of:orr policy))
::  +view-of: what an actor may see: the bodies in its kinds with the
::  hidden attributes dropped, and the actions in its action kinds. A
::  value that refs a body outside the kinds reads as cleared on a row
::  with a synthetic id, and an about naming one is trimmed away: a key
::  never learns such a body exists. The owner sees everything.
::
++  view-of
  |=  [act=actor all=(list loaded:orr) acts=(list [id=@ta a=action:orr]) hide=(set @t)]
  ^-  [all=(list loaded:orr) acts=(list [id=@ta a=action:orr])]
  ?~  scope.act  [all acts]
  =/  s=scope:orr  u.scope.act
  :-  %+  murn  all
      |=  l=loaded:orr
      ^-  (unit loaded:orr)
      ?.  (kind-in-scope:orr s kind.body.l)  ~
      `l(rows (veil-refs:orr (drop-attrs:orr rows.l hide) kinds.s))
  %+  turn  (skim acts |=([* a=action:orr] (action-in-scope:orr s kind.a)))
  |=([id=@ta a=action:orr] [id (scope-about:orr a kinds.s)])
::  +deny-observe: why a key may not send this batch, or ~. The owner is
::  never denied. A batch with one item outside the scope is refused
::  whole, naming the first offender (which the key itself sent). A key
::  whose scope says sensitive may observe the attributes the policy
::  marks sensitive; every view goes on hiding them from it.
::
++  deny-observe
  |=  [act=actor jon=json policy=json]
  ^-  (unit @t)
  ?~  scope.act  ~
  ?.  write.u.scope.act  `'read only key'
  =/  hide=(set @t)  ?:(sensitive.u.scope.act ~ (hidden-for act policy))
  =/  bad=(unit @t)  (out-of-scope:orr jon u.scope.act hide)
  ?~  bad  ~
  `(cat 3 'not in scope: ' u.bad)
::  +deny-write: why a key may not write a body of this kind, or ~
::
++  deny-write
  |=  [act=actor kind=@tas]
  ^-  (unit @t)
  ?~  scope.act  ~
  ?.  write.u.scope.act  `'read only key'
  ?.  (kind-in-scope:orr u.scope.act kind)  `(cat 3 'not in scope: ' kind)
  ~
::  ==  the page
::
::  +serve-file: one of the page's grubs, no-cache so an updated desk
::  shows at the next load
::
++  serve-file
  |=  [eyre-id=@ta name=@ta]
  =/  m  (fiber:fiber:nexus ,~)
  ^-  form:m
  =/  ct=(unit @t)
    ?+  name  ~
      %'orrery.html'  `'text/html; charset=utf-8'
      %'orrery.css'   `'text/css; charset=utf-8'
      %'orrery.js'    `'text/javascript; charset=utf-8'
    ==
  ?~  ct  (send-err eyre-id 404 'no such file')
  ;<  vw=view:nexus  bind:m  (peek:io (rf 1 / name) `[/ %mime])
  ?.  ?=([%file *] vw)  (send-err eyre-id 404 'no such file')
  =/  got=(unit mime)  (mole |.(!<(mime (need-vase:tarball sang.vw))))
  ?~  got  (send-err eyre-id 500 'unreadable file')
  ::  nosniff: each of the three files is served with its own type, and
  ::  a browser must not guess a different one out of the bytes
  =/  heads
    :~  ['content-type' u.ct]
        ['cache-control' 'no-cache']
        ['x-content-type-options' 'nosniff']
    ==
  (send-simple:srv eyre-id [[200 heads] `q.u.got])
--
