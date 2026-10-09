#!/usr/bin/env python3
"""api-matrix.py HOST JAR
The HTTP gate for orrery: spec section 8, the stranded car, against a
fake ship. HOST like http://localhost:8080; JAR a curl cookie jar from
POST /~/login. Exits 1 on any failure. Safe to rerun: it deletes,
retracts and dismisses what an earlier run left.

ONLY=outdoors,"the week" runs the clean slate and the stub, then only the
sections whose "# ---- " header holds one of those words: a release's
own checks in a minute or two, where the whole gate takes twenty. A
section that leans on another's state needs that one named too."""
import json, os, re, sys, threading, time, urllib.parse
from gate import fails, check, dictish, listish, iso, all_ok
import gate
from datetime import datetime, timedelta, timezone

HOST, JAR = sys.argv[1:3]
#  the ship the gate runs on, so a letter to it lands in its own inbox
OUR = sys.argv[3] if len(sys.argv) > 3 else '~wex'
API = HOST + '/apps/orrery/api'
INSTANCE = HOST + '/grubbery/ball/apps/shell.shell/desks/orrery.desk/desk/data/orrery.orrery_app'
# the ids of the task actions this run files: the executor on the ship
# places each one in the calendar's todo list, and the last section
# deletes those todos so repeated runs do not pile them up
MADE = []


def curl(method, url, body=None, jar=JAR, timeout=60, token=None):
    return gate.curl(method, url, body, jar=jar, token=token, timeout=timeout)


# a ship without a live calendar or auspex cannot pass the executor's, the calendar's or the mail's checks,
# and each would wait out its timeout: 27 of 40 minutes on a bare test ship (2026-10-05). Say so and stop,
# unless --partial asks for the run anyway
def desk_live(d):
    code, v = curl('GET', HOST + '/grubbery/ball/apps/shell.shell/desks/%s.desk/desk/data?info=1' % d)
    return code == 200 and any(str(dictish(c).get('name', '')).startswith(d + '.') for c in dictish(v).get('children') or [])
# and orrery itself must have built: a banged instance answers nothing, and every check would time out
code, info = curl('GET', INSTANCE + '?info=1')
if code != 200 or dictish(info).get('bang') is not None or curl('GET', API + '/version')[0] != 200:
    print('orrery is not running on this ship (its instance: %s): fix the build first.' % str(dictish(info).get('bang'))[-300:])
    sys.exit(2)
MISSING = [d for d in ('calendar', 'auspex') if not desk_live(d)]
if MISSING and '--partial' not in sys.argv:
    print('no live %s desk on this ship: the executor, calendar and mail checks cannot pass, and each would wait out its timeout. '
          'Set it up, or pass --partial to run anyway.' % ' or '.join(MISSING))
    sys.exit(2)


now = datetime.now(timezone.utc).replace(microsecond=0)
T0 = now - timedelta(hours=12)                       # the breakdown
M2 = T0 + timedelta(hours=1, minutes=35)             # the tow arrives
M3 = T0 + timedelta(hours=4, minutes=5)              # home, car at the shop
UNTIL = T0 + timedelta(hours=4)
DUE = T0 + timedelta(hours=15)
SIT = 'situation/' + T0.strftime('%Y-%m-%d') + '-breakdown'
SHOP = 'place/johns-machine-shop'
ORG = 'org/sarah-connor'
MAIL = 'Sarah.Connor@example.com'
TITLE = "Call John's Machine Shop about the Subaru"
MSG = "Tell Sarah the car is at John's"
RACE = "Tell Sarah the tow is booked"
USER = {'kind': 'user', 'id': 'matrix-setup'}


def src(i):
    return {'kind': 'talon-dm', 'id': 'matrix-' + i}


def ref(b):
    return {'ref': b}


def state(at=None):
    code, d = curl('GET', API + '/state' + (f'?at={at}' if at else ''))
    check(f'GET /state {at or ""} answers 200', code == 200, (code, d))
    return d if code == 200 else {'bodies': [], 'situations': [], 'actions': []}


def body(bid, at=None):
    return curl('GET', API + f'/body/{bid}' + (f'?at={at}' if at else ''))


def attrs(d, bid):
    for b in d.get('bodies', []):
        if b['id'] == bid:
            return b['attrs']
    return None


def val(d, bid, attr):
    a = attrs(d, bid)
    return None if not a or attr not in a else a[attr]['value']


def observe(bodies, observations):
    return curl('POST', API + '/observe', {'bodies': bodies, 'observations': observations})


def obs(subject, attr, value, at, source, until=None, conf=100):
    o = {'subject': subject, 'attr': attr, 'value': value, 'at': iso(at),
         'conf': conf, 'source': source, 'by': 'api-matrix'}
    if until is not None:
        o['until'] = iso(until)
    return o


def retract_matrix(bid):
    #  every live row this gate wrote on a body it does not delete
    code, d = body(bid)
    if code != 200:
        return
    for o in dictish(d).get('observations', []):
        if o['source']['id'].startswith('matrix-') and o['status'] != 'retracted':
            curl('POST', API + '/retract', {'id': o['id'], 'note': 'matrix rerun'})


# ── 0. a clean slate ────────────────────────────────────────────────
print('0. clean slate')
#  the readers run on by default since version 58; a reader filing
#  facts or a pass moving the beacon mid-gate would change what the
#  generator sections count, so they are off for the gate (the
#  telegram and chat sections turn theirs on themselves)
for r in ('/telegram', '/chat', '/mail', '/generator', '/read/settings'):
    curl('PUT', API + r, {'enabled': False})
#  the keys an earlier run minted: a run stopped part way never revokes
#  them, and the ship holds fifty at most
for k in (curl('GET', API + '/clients')[1] or []):
    if str(dictish(k).get('by', '')).startswith('gate-'):
        curl('DELETE', API + '/clients/' + dictish(k)['id'])
#  a key with write, for the checks that an owner-only route refuses
#  even a writing key (no credentials at all is refused earlier, by
#  another guard, so that would prove nothing about the route)
WKEY = dictish(curl('POST', API + '/clients', {'name': 'gate writer', 'by': 'gate-writer', 'scope': {'kinds': ['person'], 'actions': [], 'write': True}})[1]).get('token')


def owner_only(label, method, path, body=None):
    code, d = curl(method, API + path, body, jar=None, token=WKEY)
    check(label, code == 403 and dictish(d).get('error') == 'owner only', (code, d))
#  a DM from the ship needs the kernel's marc, which the dev ship's kernel
#  lacks; a poke without it wedges the executor, so DMs stay off here
curl('PUT', API + '/chat', {'send_dms': False})
#  SIT is keyed on today's date, so a run on the other side of midnight
#  UTC would leave an earlier day's breakdown open for ever
code, st0 = curl('GET', API + '/state')
old_sits = [] if code != 200 else [str(dictish(b).get('id', '')) for b in dictish(st0).get('bodies', [])]
for b in old_sits:
    if b.startswith('situation/') and b.endswith('-breakdown'):
        curl('DELETE', API + '/body/' + b)
retract_matrix('person/sarah')
#  and what a run that died before its teardown left: a gate person
#  named "the ..." is named by any text with "the" in it
for b in ['person/sarah', 'thing/subaru', 'place/home', SHOP, ORG, SIT, 'person/gate-tg', 'person/gate-ship', 'person/gate-nobody',
          'person/gate-people', 'person/gate-shipped', 'person/gate-karl', 'person/gate-struck']:
    curl('DELETE', API + '/body/' + b)
code, me = body('person/me')
check('person/me exists', code == 200, (code, me))
curl('POST', API + '/bodies', {'id': 'person/me', 'ship': OUR})
retract_matrix('person/me')
code, acts = curl('GET', API + '/actions?status=open')
for a in (acts if isinstance(acts, list) else []):
    #  a run that died in the executor section leaves its gate actions open,
    #  and an approved message with no address is noted on every pass
    if a['title'] in (TITLE, MSG, RACE) or a['title'].startswith('Gate '):
        curl('POST', API + f'/actions/{a["id"]}', {'status': 'dismissed', 'note': 'matrix rerun'})
curl('PUT', API + '/policy', {'auto': ['task', 'note'], 'push': 'proposed', 'retention_days': 365})

if os.environ.get('ONLY'):
    want = os.environ['ONLY'].split(',')
    src = open(__file__).read()
    for chunk in re.split(r'(?m)^(?=# ---- )', src)[1:]:
        head = chunk.split('\n', 1)[0]
        if head.startswith('# ---- the stub:') or any(w in head for w in want):
            #  padded so a traceback's line numbers are the file's
            exec(compile('\n' * src[:src.index(chunk)].count('\n') + chunk, __file__, 'exec'))
            #  a section that leaves the stub up for the one after it, run alone
            if 'srv' in globals() and srv.socket.fileno() != -1:
                srv.shutdown(); srv.server_close()
    print()
    print('FAILED: ' + ', '.join(fails) if fails else 'ALL OK')
    sys.exit(1 if fails else 0)

# ── 1. setup ────────────────────────────────────────────────────────
print('1. setup')
code, d = observe(
    [{'id': 'person/sarah', 'name': 'Sarah', 'aliases': ['Sarah', 'wife']},
     {'id': 'thing/subaru', 'name': 'The Subaru', 'aliases': ['the car', 'subaru']},
     {'id': 'place/home', 'name': 'Home'}],
    [obs('person/me', 'spouse', ref('person/sarah'), T0 - timedelta(days=1), USER),
     obs('person/me', 'home', ref('place/home'), T0 - timedelta(days=1), USER),
     obs('thing/subaru', 'owner', ref('person/me'), T0 - timedelta(days=1), USER)])
check('setup answers 200', code == 200, (code, d))
check('setup bodies all ok', all_ok(d, 'bodies', 3), d)
check('setup observations all ok', all_ok(d, 'observations', 3), d)
code, me = body('person/me')
check('the API emits the ship on a body', code == 200 and dictish(me).get('ship') == OUR, me)
s = state()
check('me.spouse is sarah, read back at once', val(s, 'person/me', 'spouse') == ref('person/sarah'), attrs(s, 'person/me'))
code, r = curl('GET', API + '/resolve?q=' + urllib.parse.quote(OUR))
check('resolve finds me by ship', code == 200 and isinstance(r, list)
      and [x.get('id') for x in r if isinstance(x, dict)] == ['person/me'], r)
code, d = curl('POST', API + '/bodies', {'id': 'person/sarah', 'ship': 'sarah'})
check('a bad ship is 400', code == 400 and str(dictish(d).get('error', '')).startswith('ship:'), (code, d))
code, d = observe([], [obs('thing/subaru', 'location', ref('thing/subaru'), T0, USER)])
o = dictish(d).get('observations', [])
check('a self-reference is refused per item', code == 200 and len(o) == 1
      and not o[0].get('ok') and 'itself' in str(o[0].get('error', '')), d)
check('me.home is home', val(s, 'person/me', 'home') == ref('place/home'), attrs(s, 'person/me'))
check('the subaru is mine', val(s, 'thing/subaru', 'owner') == ref('person/me'), attrs(s, 'thing/subaru'))

# ── 2. message 1 ────────────────────────────────────────────────────
print('2. message 1: "car died on route 9, stranded waiting for a tow"')
code, d = observe(
    [{'id': SIT, 'name': 'Breakdown on Route 9'}],
    [obs('person/me', 'status', 'stranded, waiting for a tow', T0, src('m1'), UNTIL, 90),
     obs('person/me', 'location', 'Route 9', T0, src('m1'), None, 90),
     obs('thing/subaru', 'status', 'broken down', T0, src('m1'), None, 90),
     obs('thing/subaru', 'location', 'Route 9', T0, src('m1'), None, 90),
     obs(SIT, 'status', 'open', T0, src('m1')),
     obs(SIT, 'participants', ref('person/me'), T0, src('m1')),
     obs(SIT, 'participants', ref('person/sarah'), T0, src('m1')),
     obs(SIT, 'participants', ref('thing/subaru'), T0, src('m1')),
     obs(SIT, 'location', 'Route 9', T0, src('m1')),
     obs(SIT, 'started', iso(T0), T0, src('m1'))])
check('message 1 lands', code == 200 and all_ok(d, 'observations', 10), d)
s = state(iso(T0 + timedelta(minutes=5)))   # spec: the state view at 22:05, inside the until
check('me.status is stranded', val(s, 'person/me', 'status') == 'stranded, waiting for a tow', attrs(s, 'person/me'))
check('me on Route 9', val(s, 'person/me', 'location') == 'Route 9', attrs(s, 'person/me'))
check('subaru on Route 9', val(s, 'thing/subaru', 'location') == 'Route 9', attrs(s, 'thing/subaru'))
check('subaru is broken down', val(s, 'thing/subaru', 'status') == 'broken down', attrs(s, 'thing/subaru'))
parts = (attrs(s, SIT) or {}).get('participants')
check('situation has three participants', isinstance(parts, list) and len(parts) == 3, parts)
check('the situation is on Route 9', val(s, SIT, 'location') == 'Route 9', attrs(s, SIT))
check('the situation started at the breakdown', val(s, SIT, 'started') == iso(T0), attrs(s, SIT))
check('situation is open', SIT in s['situations'], s['situations'])
sarah = [b for b in s['bodies'] if b['id'] == 'person/sarah']
check("sarah's state names the situation", bool(sarah) and SIT in sarah[0]['involved'], sarah)

# ── 3. message 2 ────────────────────────────────────────────────────
print('3. message 2: "tow guy is here, taking it to john\'s machine shop"')
code, r = curl('GET', API + '/resolve?q=john%27s%20machine%20shop')
check('resolve finds no shop yet', code == 200 and r == [], (code, r))
code, d = observe(
    [{'id': SHOP, 'name': "John's Machine Shop", 'aliases': ["John's", 'the shop']}],
    [obs('thing/subaru', 'status', "being towed to John's Machine Shop", M2, src('m2'), None, 90),
     obs('person/me', 'status', 'riding with the tow', M2, src('m2'), UNTIL, 80)])
check('message 2 lands', code == 200 and all_ok(d, 'observations', 2), d)
RIDING = d['observations'][1].get('id', '') if code == 200 and len(dictish(d).get('observations', [])) > 1 else ''
s = state()
check('subaru is being towed', val(s, 'thing/subaru', 'status') == "being towed to John's Machine Shop", attrs(s, 'thing/subaru'))
code, r = curl('GET', API + '/resolve?q=the%20shop')
check('resolve finds the shop by alias', code == 200 and isinstance(r, list)
      and [dictish(x).get('id') for x in r] == [SHOP], r)

# ── 4. message 3 ────────────────────────────────────────────────────
print('4. message 3: "home. left the car at john\'s overnight"')
batch = [obs('thing/subaru', 'location', ref(SHOP), M3, src('m3'), None, 95),
         obs('thing/subaru', 'status', 'at the shop, awaiting diagnosis', M3, src('m3'), None, 90),
         obs('person/me', 'location', ref('place/home'), M3, src('m3'), None, 95),
         obs('person/me', 'status', None, M3, src('m3')),
         obs(SIT, 'status', 'car at shop, awaiting diagnosis', M3, src('m3'))]
code, d = observe([], batch)
check('message 3 lands', code == 200 and all_ok(d, 'observations', 5), d)
s = state()
check("subaru at John's", val(s, 'thing/subaru', 'location') == ref(SHOP), attrs(s, 'thing/subaru'))
check('subaru awaits diagnosis', val(s, 'thing/subaru', 'status') == 'at the shop, awaiting diagnosis', attrs(s, 'thing/subaru'))
check('me at home', val(s, 'person/me', 'location') == ref('place/home'), attrs(s, 'person/me'))
check('me has no status', 'status' not in (attrs(s, 'person/me') or {}), attrs(s, 'person/me'))
check('situation still open', SIT in s['situations'], s['situations'])
past = state(iso(T0 + timedelta(hours=1)))
check('an hour in, the subaru was still on Route 9', val(past, 'thing/subaru', 'location') == 'Route 9', attrs(past, 'thing/subaru'))
check('an hour in, me was stranded', val(past, 'person/me', 'status') == 'stranded, waiting for a tow', attrs(past, 'person/me'))
code, d = observe([], batch)
check('resubmitting message 3 changes nothing',
      code == 200 and len(d['observations']) == 5 and all(o['ok'] and o['existing'] for o in d['observations']), d)

# ── 5. the analyst ──────────────────────────────────────────────────
print('5. the analyst proposes a task')
s = state()
check('no open action yet', not any(a['title'] == TITLE for a in s['actions']), s['actions'])
prop = {'kind': 'task', 'title': TITLE, 'about': ['thing/subaru', SHOP], 'due': iso(DUE), 'by': 'api-matrix'}
code, a = curl('POST', API + '/act', prop)
check('proposal answers 200', code == 200, (code, a))
check('policy auto-approves a task', code == 200 and a['status'] == 'approved' and not a['existing'], a)
AID = a['id'] if code == 200 else ''
MADE.append(AID)
code, acts = curl('GET', API + '/actions')
check('the task is on the open list', code == 200 and isinstance(acts, list)
      and any(dictish(x).get('id') == AID for x in acts), acts)
mine = [x for x in acts if isinstance(x, dict) and x.get('id') == AID] if isinstance(acts, list) else []
check('the history shows proposed then approved by policy', bool(mine)
      and [(h.get('status'), h.get('by')) for h in mine[0].get('history', [])] == [('proposed', 'api-matrix'), ('approved', 'policy')], mine)
code, a2 = curl('POST', API + '/act', prop)
check('a second identical proposal answers the same id', code == 200 and a2['id'] == AID and a2['existing'], a2)
code, log = curl('GET', INSTANCE + '/tr/log?raw=1')
#  among the newest entries, since the calendar reader may have filed since
last = ([e for e in (log if isinstance(log, list) else [])[-6:] if dictish(e).get('op') == 'act'] or [{}])[-1]
check('the writer noted the act', code == 200 and last.get('op') == 'act' and last.get('ok') is True, last)
code, bs = body('thing/subaru')
check('the subaru view lists the open task', code == 200 and isinstance(bs, dict)
      and any(dictish(x).get('id') == AID for x in bs.get('actions', [])), bs.get('actions') if code == 200 else bs)
code, a3 = curl('POST', API + '/act', {'kind': 'message', 'title': MSG, 'by': 'api-matrix'})
check('a message waits for a human', code == 200 and dictish(a3).get('status') == 'proposed', (code, a3))
MID = dictish(a3).get('id', '') if code == 200 else ''
code, d = curl('POST', API + f'/actions/{MID}', {'status': 'approved'})
check('the owner approves the message', code == 200, (code, d))
code, d = curl('POST', API + f'/actions/{MID}', {'status': 'claimed', 'by': 'exec-a'})
check('an executor claims the approved message', code == 200 and dictish(d).get('status') == 'claimed', (code, d))
check('the claim answer carries the by the ship stores', dictish(d).get('by') == 'exec-a', (code, d))
code, acts = curl('GET', API + '/actions?status=open')
check('a claimed action is still open', code == 200 and any(dictish(x).get('id') == MID for x in (acts if isinstance(acts, list) else [])), acts)
code, acts = curl('GET', API + '/actions?status=approved')
check('a claimed action has left the approved list', code == 200
      and not any(dictish(x).get('id') == MID for x in (acts if isinstance(acts, list) else [])), acts)
code, d = curl('POST', API + f'/actions/{MID}', {'status': 'claimed', 'by': 'exec-b'})
check('a second claim inside the lease is 409 naming the claimant',
      code == 409 and dictish(d).get('error') == 'claimed by exec-a', (code, d))
code, d = curl('POST', API + f'/actions/{MID}', {'status': 'done', 'by': 'exec-b'})
check('done by another actor is 409 naming the claimant',
      code == 409 and dictish(d).get('error') == 'claimed by exec-a', (code, d))
code, d = curl('POST', API + '/act', {'kind': 'message', 'title': MSG, 'by': 'api-matrix'})
check('a proposal matching a claimed action answers the existing id',
      code == 200 and dictish(d).get('id') == MID and dictish(d).get('existing'), (code, d))
code, d = curl('POST', API + f'/actions/{MID}', {'status': 'done', 'by': 'exec-a'})
check('the claimant reports done', code == 200 and dictish(d).get('status') == 'done', (code, d))
code, acts = curl('GET', API + '/actions?status=done')
msg = [x for x in acts if isinstance(x, dict) and x.get('id') == MID] if isinstance(acts, list) else []
hist = [(h.get('status'), h.get('by')) for h in dictish(msg[0] if msg else {}).get('history', [])]
check('the history reads proposed, approved, claimed and done',
      hist == [('proposed', 'api-matrix'), ('approved', 'user'), ('claimed', 'exec-a'), ('done', 'exec-a')], hist)
#  the route answers before the writer applies, so two claims in one
#  instant can both hear ok; the writer keeps the first and the history
#  is the proof
code, r = curl('POST', API + '/act', {'kind': 'message', 'title': RACE, 'by': 'api-matrix'})
RID = dictish(r).get('id', '') if code == 200 else ''
code, d = curl('POST', API + f'/actions/{RID}', {'status': 'approved'})
check('the race message is proposed and approved', bool(RID) and code == 200, (code, r, d))
answers = {}


def claim_as(who):
    answers[who] = curl('POST', API + f'/actions/{RID}', {'status': 'claimed', 'by': who})


racers = [threading.Thread(target=claim_as, args=(w,)) for w in ('exec-x', 'exec-y')]
for t in racers:
    t.start()
for t in racers:
    t.join()
code, acts = curl('GET', API + '/actions?status=open')
race_row = [x for x in acts if isinstance(x, dict) and x.get('id') == RID] if isinstance(acts, list) else []
steps = [h for h in dictish(race_row[0] if race_row else {}).get('history', []) if dictish(h).get('status') == 'claimed']
check('two claims at once leave one claimed step, by one of the two',
      len(steps) == 1 and dictish(steps[0]).get('by') in ('exec-x', 'exec-y'), (answers, steps))
winner = str(dictish(steps[0]).get('by')) if len(steps) == 1 else ''
loser = 'exec-y' if winner == 'exec-x' else 'exec-x'
code, d = curl('POST', API + f'/actions/{RID}', {'status': 'done', 'by': loser})
check('the actor that lost the race cannot report done',
      code == 409 and dictish(d).get('error') == 'claimed by ' + winner, (code, d, winner))
code, log = curl('GET', INSTANCE + '/tr/log?raw=1')
check('the audit log holds the push among its newest entries', code == 200 and isinstance(log, list)
      and any(dictish(x).get('op') == 'push' for x in log[-30:]), log[-3:] if isinstance(log, list) else log)

# ── 6. retract, done, compact ───────────────────────────────────────
print('6. retract, done, compact')
code, d = curl('POST', API + '/retract', {'id': RIDING, 'note': 'never rode along'})
check('retract answers 200', code == 200, (code, d))
code, me = body('person/me')
riding = [o for o in dictish(me).get('observations', []) if o['id'] == RIDING]
check('the timeline labels it retracted', bool(riding) and riding[0]['status'] == 'retracted', riding)
code, d = curl('POST', API + f'/actions/{AID}', {'status': 'done'})
check('the task is marked done', code == 200 and d['status'] == 'done', (code, d))
code, acts = curl('GET', API + '/actions')
check('it left the open list', code == 200 and isinstance(acts, list)
      and not any(dictish(x).get('id') == AID for x in acts), acts)
code, allacts = curl('GET', API + '/actions?status=done')
done = [x for x in allacts if isinstance(x, dict) and x.get('id') == AID] if isinstance(allacts, list) else []
hist = done[0].get('history', []) if done else []
check('done is in the history with the actor', bool(hist)
      and hist[-1].get('status') == 'done' and hist[-1].get('by') == 'user', done)
code, log = curl('GET', INSTANCE + '/tr/log?raw=1')
#  among the newest entries: the executor's mirror files whenever the
#  calendar moves, which another session's tests can make it do
check('the audit log holds the set-action among its newest entries', code == 200 and isinstance(log, list) and bool(log)
      and any(dictish(x).get('op') == 'set-action' and dictish(x).get('by') == 'user' for x in log[-8:]), log[-3:] if isinstance(log, list) else log)
code, d = curl('POST', API + f'/actions/{AID}', {'status': 'approved'})
check('done is terminal', code == 409, (code, d))
curl('PUT', API + '/policy', {'auto': ['task', 'note'], 'push': 'proposed', 'retention_days': 0})
code, d = observe([], [obs('thing/subaru', 'plate', 'ABC 123', now - timedelta(minutes=1), USER)])
check('a write with retention 0 lands', code == 200 and all_ok(d, 'observations', 1), (code, d))
code, bs = body('thing/subaru')
statuses = {o['id']: o['status'] for o in bs.get('observations', [])} if code == 200 else {}
#  compaction keeps the row each attribute falls back to should its
#  winner be retracted: one superseded row per attribute at most
kept = [o.get('attr') for o in bs.get('observations', []) if o.get('status') == 'superseded'] if code == 200 else []
check('superseded observations were culled but for one fallback per attribute', code == 200 and len(kept) == len(set(kept)), statuses)
check('live observations remain', code == 200 and bs['attrs']['location']['value'] == ref(SHOP) and bs['attrs']['plate']['value'] == 'ABC 123', bs.get('attrs') if code == 200 else bs)
curl('PUT', API + '/policy', {'auto': ['task', 'note'], 'push': 'proposed', 'retention_days': 365})

# ── 7. refusals ─────────────────────────────────────────────────────
print('7. refusals')
code, d = observe([{'id': f'place/p{i}'} for i in range(51)], [])
check('51 bodies is 400 naming bodies', code == 400 and dictish(d).get('error') == 'bodies: over 50', (code, d))
code, d = observe([], [obs('thing/subaru', 'plate', 'x', now - timedelta(minutes=1), USER)] * 201)
check('201 observations is 400 naming observations', code == 400 and dictish(d).get('error') == 'observations: over 200', (code, d))
code, d = observe([], [{'subject': 'thing/subaru', 'attr': 'status', 'value': 'x', 'at': 'yesterday', 'source': USER}])
o = dictish(d).get('observations', [])
check('a bad at is refused per item', code == 200 and len(o) == 1
      and not o[0].get('ok') and str(o[0].get('error', '')).startswith('at:'), d)
code, d = curl('GET', API + '/state?at=yesterday')
check('a bad ?at is 400', code == 400, (code, d))
code, d = curl('POST', API + '/act', {'kind': 'task', 'title': 'x', 'about': ['thing/nothing']})
check('an unknown about body is 400', code == 400 and str(d.get('error', '')).startswith('about: no such body'), (code, d))
code, d = curl('POST', API + '/retract', {'id': RIDING, 'note': 'x' * 501})
check('an over-long retract note is 400', code == 400
      and dictish(d).get('error') == 'note: over 500 bytes', (code, d))
code, d = curl('POST', API + f'/actions/{AID}', {'status': 'dismissed', 'note': 'x' * 501})
check('an over-long action note is 400', code == 400
      and dictish(d).get('error') == 'note: over 500 bytes', (code, d))
code, d = curl('POST', API + f'/actions/{AID}', [])
check('a non-object action body is 400', code == 400
      and dictish(d).get('error') == 'expected an object', (code, d))
code, d = curl('POST', API + '/observe', {'bodies': [], 'observations': 'nope'})
check('a non-array observations is 400', code == 400
      and dictish(d).get('error') == 'observations: expected an array', (code, d))
code, d = curl('GET', API + '/nothing')
check('an unknown route is 404', code == 404, (code, d))

# ── 8. identity, tokens and the merge ───────────────────────────────
print('8. resolve on identity, and one body folded into another')
ORG_AT = T0 - timedelta(days=2)
code, d = observe([], [obs('person/sarah', 'email', MAIL, now - timedelta(minutes=2), USER)])
check('sarah gets an email address', code == 200 and all_ok(d, 'observations', 1), (code, d))
code, r = curl('GET', API + '/resolve?q=sarah.connor%40EXAMPLE.com')
hit = [x for x in (r if isinstance(r, list) else []) if dictish(x).get('id') == 'person/sarah']
check('resolve finds sarah by her address, exact',
      code == 200 and len(hit) == 1 and hit[0].get('match') == 'exact', (code, r))
code, r = curl('GET', API + '/resolve?q=Sarah%20Connor')
hit = [x for x in (r if isinstance(r, list) else []) if dictish(x).get('id') == 'person/sarah']
check('resolve finds sarah by the words of a fuller name',
      code == 200 and len(hit) == 1 and hit[0].get('match') == 'token', (code, r))
code, d = observe([{'id': ORG, 'name': 'Sarah Connor'}],
                  [obs(ORG, 'phone', '+1 555 0100', ORG_AT, src('merge')),
                   obs('person/me', 'spouse', ref(ORG), now - timedelta(minutes=1), USER)])
check('the duplicate org and a reference to it land',
      code == 200 and all_ok(d, 'bodies', 1) and all_ok(d, 'observations', 2), (code, d))
code, d = curl('POST', API + '/merge', {'from': ORG, 'into': 'person/sarah'})
check('the merge answers 200, one row moved and one reference repointed',
      code == 200 and dictish(d).get('moved') == 1 and dictish(d).get('repointed') == 1
      and dictish(d).get('ok') is True, (code, d))
time.sleep(2)
code, sar = body('person/sarah')
moved = [o for o in dictish(sar).get('observations', []) if o.get('attr') == 'phone']
check("the org's observation is on sarah, with its own at and source",
      code == 200 and len(moved) == 1 and moved[0].get('at') == iso(ORG_AT)
      and moved[0].get('source') == src('merge'), (code, moved))
check("the merged name is one of sarah's aliases",
      code == 200 and 'Sarah Connor' in dictish(sar).get('aliases', []), dictish(sar).get('aliases'))
s = state()
check('me.spouse points at sarah again',
      val(s, 'person/me', 'spouse') == ref('person/sarah'), attrs(s, 'person/me'))
code, me = body('person/me')
gone = [o for o in dictish(me).get('observations', []) if o.get('value') == ref(ORG)]
check('the old reference is retracted, and says where it went',
      code == 200 and bool(gone) and all(o.get('status') == 'retracted'
      and o.get('note') == 'merged into person/sarah' for o in gone), (code, gone))
code, d = body(ORG)
check('the body merged away is gone', code == 404, (code, d))
code, d = curl('POST', API + '/merge', {'from': 'person/sarah', 'into': 'person/sarah'})
check('a merge of a body into itself is 400',
      code == 400 and dictish(d).get('error') == 'from and into are the same body', (code, d))
code, d = curl('POST', API + '/merge', {'from': 'person/me', 'into': 'person/sarah'})
check('a merge from person/me is 400',
      code == 400 and dictish(d).get('error') == 'person/me cannot be merged away', (code, d))
code, d = curl('POST', API + '/merge', {'from': 'org/nobody', 'into': 'person/sarah'})
check('a merge of an unknown body is 404',
      code == 404 and dictish(d).get('error') == 'no such body org/nobody', (code, d))
code, log = curl('GET', INSTANCE + '/tr/log?raw=1')
#  the newest entries, since the calendar reader may have filed since
last = ([e for e in (log if isinstance(log, list) else [])[-6:] if dictish(e).get('op') == 'merge'] or [{}])[-1]
check('the writer noted the merge last',
      code == 200 and dictish(last).get('op') == 'merge' and dictish(last).get('ok') is True, last)

# ── 9. the ask ──────────────────────────────────────────────────────
# the executor's roads are asked for in the served weir; consent is the
# owner's, on the permits page, and a granted road shows in ?info=1
print('9. the ask names the calendar and auspex desks')
code, d = curl('GET', INSTANCE + '/weir.json?raw=1')
roads = {k: [r.get('road') for r in v] for k, v in dictish(d).items() if isinstance(v, list)}
CAL, AUS = '/apps/shell.shell/desks/calendar.desk/', '/apps/shell.shell/desks/auspex.desk/'
check('the ask pokes the calendar desk and the auspex desk',
      code == 200 and CAL in roads.get('poke', []) and AUS in roads.get('poke', []), (code, roads))
check('the ask peeks the calendar desk, and still the link registry',
      code == 200 and CAL in roads.get('peek', []) and '/sys/link/' in roads.get('peek', []), (code, roads))

# ---- the on-ship generator: its settings ----
# a rerun starts from the defaults: a JSON null clears the stored key
curl('PUT', API + '/generator', {'enabled': False, 'api_key': None, 'model': 'moonshotai/kimi-k3', 'url': 'https://openrouter.ai/api/v1', 'max_actions': 5, 'max_tokens': 8000, 'reasoning': {'effort': 'high'}})
time.sleep(0.5)
code, d = curl('GET', API + '/generator')
check('generator settings read', code == 200 and dictish(d).get('enabled') is False and 'api_key' not in dictish(d) and dictish(d).get('api_key_set') is False, (code, d))
code, d = curl('PUT', API + '/generator', {'enabled': False, 'model': 'moonshotai/kimi-k3', 'api_key': 'sk-gate-secret', 'max_actions': 2})
check('generator settings written', code == 200, (code, d))
time.sleep(0.5)
code, d = curl('GET', API + '/generator')
check('the key is never read back', code == 200 and 'api_key' not in dictish(d) and dictish(d).get('api_key_set') is True and dictish(d).get('model') == 'moonshotai/kimi-k3' and dictish(d).get('max_actions') == 2, (code, d))
curl('PUT', API + '/generator', {'model': 'deepseek/deepseek-v4.1-flash'})
time.sleep(0.5)
code, d = curl('GET', API + '/generator')
check('a write without the key keeps it', dictish(d).get('api_key_set') is True and dictish(d).get('model') == 'deepseek/deepseek-v4.1-flash', d)
owner_only('the settings are the owner\'s, even to a writing key', 'GET', '/generator')

# ---- following Armillary (version 96): every setting runs on what this ship's Armillary offers ----
# a ship with no Armillary, or one orrery may not read yet, says so; on
# one with Armillary every setting follows, a hand pick stops only that
# setting, and one tap follows it again
ARM_SETTINGS = {'generator', 'mail', 'chat', 'telegram', 'read', 'search'}
def arm_of(name):
    code, st = curl('GET', API + '/armillary')
    return dictish(dictish(dictish(st).get('settings')).get(name))
code, arm_st = curl('GET', API + '/armillary')
arm_st = dictish(arm_st)
check('the Armillary state names every setting that follows',
      code == 200 and set(dictish(arm_st.get('settings'))) == ARM_SETTINGS, (code, arm_st))
code, d = curl('POST', API + '/armillary/follow', {'feature': 'nonsense'})
check('following a setting that cannot follow is 400', code == 400, (code, d))
if not arm_st.get('offered'):
    code, d = curl('POST', API + '/armillary/follow', {})
    check('with no Armillary to follow, following says why', code == 409 and 'armillary' in json.dumps(d), (code, d))
else:
    code, d = curl('POST', API + '/armillary/follow', {})
    arm_after = dictish(dictish(d).get('settings'))
    check('following answers every setting following',
          code == 200 and all(dictish(v).get('following') is True for v in arm_after.values()), (code, d))
    code, arm_gen = curl('GET', API + '/generator')
    arm_gen = dictish(arm_gen)
    curl('PUT', API + '/generator', {'url': arm_gen.get('url'), 'model': arm_gen.get('model'), 'api_key': ''})
    time.sleep(0.5)
    check('a page save of the same address and model keeps the generator following',
          arm_of('generator').get('following') is True, arm_of('generator'))
    curl('PUT', API + '/mail', {'model': 'hand/picked-1'})
    time.sleep(0.5)
    check('a reader model picked by hand stops only that reader following',
          arm_of('mail').get('following') is False and arm_of('generator').get('following') is True,
          (arm_of('mail'), arm_of('generator')))
    code, d = curl('POST', API + '/armillary/follow', {'feature': 'mail'})
    check('one tap follows it again',
          code == 200 and dictish(dictish(dictish(d).get('settings')).get('mail')).get('following') is True, (code, d))
owner_only('what follows Armillary is the owner\'s to read, even to a writing key', 'GET', '/armillary')
owner_only('following is the owner\'s word, even to a writing key', 'POST', '/armillary/follow')

# ---- the stub: one server for the model, the decider, Telegram, Mapbox, the weather service and POTA ----
import http.server, socketserver
#  the stub's port: STUB_PORT when given, else one free now (8099, the
#  old fixed port, is a fake ship's http port on this machine since 2026-10-08)
def _free_port():
    import socket
    with socket.socket() as so:
        so.bind(('127.0.0.1', 0))
        return so.getsockname()[1]
STUB_PORT = int(os.environ.get('STUB_PORT') or _free_port())
# a title unlike any earlier run's, since a dismissed one stays decided
# for ever and the validator drops a rewording of it
import secrets
FRESH = 'Errand %s %s %s' % (secrets.token_hex(3), secrets.token_hex(3), secrets.token_hex(3))
# two survivors: a pass that files two once deadlocked the writer against the fiber
FRESH2 = 'Chore %s %s %s' % (secrets.token_hex(3), secrets.token_hex(3), secrets.token_hex(3))
CANNED = {'choices': [{'message': {'content': json.dumps({'actions': [
    {'kind': 'task', 'title': FRESH, 'about': ['thing/gate-car'], 'why': 'gate'},
    {'kind': 'task', 'title': FRESH2, 'about': ['thing/gate-car'], 'why': 'gate too'},
    {'kind': 'task', 'title': 'Open item for the gate car', 'about': ['thing/gate-car']},
    {'kind': 'task', 'title': 'Buy a new car', 'about': ['thing/tesla']}], 'notes': ['stub note']})}}],
    'usage': {'prompt_tokens': 10, 'completion_tokens': 5, 'cost': 0.0001}}
seen = []
DOWN = False  # the analyst answers 503 while set: the reader's model outage
SLOW = 0  # seconds the stub's drives take longer: traffic gone worse (version 76)
#  defined further down; until then the stub answers 503, since a reader
#  on the ship may call it as soon as it listens (the last run's settings)
TG_CANNED = DECIDER_CANNED = REFINE_CANNED = INSTRUCT_CANNED = BROWSING_CANNED = INTERESTS_CANNED = None
import base64
GATE_PNG = base64.b64decode('iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg==')
def user_text(body):
    #  the user block of a chat request: where a reader's channel and its messages are
    return (((body or {}).get('messages') or [{}])[-1].get('content') or [{}])[0].get('text', '') if isinstance(body, dict) else ''
class Stub(http.server.BaseHTTPRequestHandler):
    #  one stub for the model, the decider and Telegram, told apart by path:
    #  the analyst's chat request by its system block (the analyst prompt's
    #  first words), the generator's answered with CANNED
    def answer(self, body):
        seen.append((self.path, {k.lower(): v for k, v in self.headers.items()}, body))
        status = 200
        if self.path.endswith('/setWebhook'):
            out = {'ok': True, 'result': True, 'description': 'Webhook was set'}
        elif self.path.endswith('/getWebhookInfo'):
            out = {'ok': True, 'result': {'url': 'http://localhost:8080/apps/orrery/telegram', 'pending_update_count': 2, 'max_connections': 1, 'last_error_date': 1789900000, 'last_error_message': 'Connection refused'}}
        elif self.path.startswith('/bot123:abc/'):
            out = {'ok': True, 'result': {'user': {'id': 1001}}}
        elif self.path.endswith('/decisions'):
            out = DECIDER_CANNED
        elif self.path.startswith('/directions/v5/mapbox/driving-traffic?'):
            # Mapbox's route, as a form POST: two points or it is refused, as Mapbox refuses it; a minute
            # from the gate's place itself, half an hour from anywhere else
            form = urllib.parse.parse_qs(body if isinstance(body, str) else '')
            pts = form.get('coordinates', [''])[0].split(';')
            out = {'code': 'Ok', 'routes': [{'duration': (60.0 if pts[0] == '-89.6501,39.7817' else 1800.4) + SLOW, 'duration_typical': 1100.4, 'distance': 21000,
                   'legs': [{'summary': 'Gate Road', 'incidents': [{'impact': 'minor', 'description': 'a street note'}, {'impact': 'major', 'description': 'Gate crash'}]}]}]} if len(pts) == 2 else None
            if out is None: out, status = {'code': 'InvalidInput', 'message': 'two coordinates are needed'}, 422
        elif self.path.startswith('/search/searchbox/v1/forward?'):
            # Mapbox's place search (version 73): a business beside the gate's place, open nine to five
            days = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday']
            out = {'features': [{'geometry': {'coordinates': [-89.6503, 39.7819]}, 'properties': {'name': 'Gate Club', 'metadata': {
                'phone': '+19045550100', 'open_hours': {'weekday_text': [d + ': 9:00 AM - 5:00 PM' for d in days]}}}}]}
        elif self.path.startswith('/styles/v1/mapbox/streets-v12/static/'):
            out = GATE_PNG   # Mapbox's still map: an image, not JSON
        elif self.path.startswith('/points/'):
            # the weather service's grid for a point (version 76), then its forecasts and alerts
            base = 'http://127.0.0.1:%d/gridpoints/GATE/1,1' % STUB_PORT
            out = {'properties': {'forecast': base + '/forecast', 'forecastHourly': base + '/forecast/hourly'}}
        elif self.path.startswith('/gridpoints/GATE/1,1/forecast'):
            t0 = datetime.now(timezone.utc).replace(minute=0, second=0, microsecond=0)
            iso = lambda h: (t0 + timedelta(hours=h)).strftime('%Y-%m-%dT%H:%M:%S+00:00')
            hourly = self.path.endswith('/hourly')
            out = {'properties': {'periods': [{'startTime': iso(h), 'endTime': iso(h + (1 if hourly else 6)), 'isDaytime': True, 'temperature': 71,
                   'windSpeed': '10 to 15 mph', 'probabilityOfPrecipitation': {'value': 70}, 'shortForecast': 'Gate Thunderstorms'}
                   for h in ((range(-1, 60) if hourly else range(-1, 80, 6)))]}}
        elif self.path.startswith('/alerts/active?point='):
            out = {'features': [{'properties': {'event': 'Gate Advisory', 'ends': None, 'expires': '2099-01-01T00:00:00Z', 'headline': 'Gate Advisory in force'}}]}
        elif self.path.startswith('/res/v1/local/place_search?'):
            # Brave's place search (version 87): one place named after the query, with its facts
            q = urllib.parse.parse_qs(urllib.parse.urlparse(self.path).query).get('q', [''])[0]
            out = {'type': 'locations', 'results': [{'title': q + ' School', 'url': 'https://gate.example', 'coordinates': [39.79, -89.65],
                   'postal_address': {'displayAddress': '1 Gate Rd, Riverton, IL 62701'}, 'contact': {'telephone': '+12175550100'},
                   'opening_hours': {'days': [[{'abbr_name': 'Mon', 'opens': '09:00', 'closes': '17:00'}]]}}]}
        elif self.path.startswith('/locations/US-GT'):
            # the POTA list for a location: one park beside the gate's place, one far off
            out = [{'reference': 'US-0001', 'name': 'Gate Lake Park', 'latitude': 39.79, 'longitude': -89.65},
                   {'reference': 'US-0002', 'name': 'Far Gate Woods', 'latitude': 41.9, 'longitude': -87.6}]
        elif self.path.startswith('/search/geocode/v6/batch?'):
            out = {'batch': [{'type': 'FeatureCollection', 'features': [{'type': 'Feature', 'geometry': {'type': 'Point', 'coordinates': [-89.6501, 39.7817]}, 'properties': {}}]} for _ in (body if isinstance(body, list) else [])]}
        else:
            system = ((body.get('messages') or [{}])[0].get('content') or [{}])[0].get('text', '')
            if system.startswith('You turn') and DOWN:
                out, status = {'error': {'message': 'the stub is down'}}, 503
            elif system.startswith('You refine'):
                # the refine prompt ends with the owner's note, which picks the reply
                user = ((body.get('messages') or [{}])[-1].get('content') or [{}])[0].get('text', '')
                tail = user.rstrip().rsplit('The note: ', 1)[-1]
                out = REFINE_CANNED and REFINE_CANNED.get(tail, REFINE_CANNED[''])
            elif system.startswith('You carry out'):
                out = INSTRUCT_CANNED
            elif system.startswith('You read a week') and INTERESTS_CANNED:
                out = INTERESTS_CANNED
            elif system.startswith('You turn') and BROWSING_CANNED and 'Channel: browsing' in user_text(body):
                out = BROWSING_CANNED(user_text(body))
            else:
                out = TG_CANNED if system.startswith('You turn') else CANNED
        if out is None:
            out, status = {'error': {'message': 'the stub is not ready'}}, 503
        ctype = 'image/png' if isinstance(out, bytes) else 'application/json'
        out = out if isinstance(out, bytes) else json.dumps(out).encode()
        self.send_response(status); self.send_header('content-type', ctype); self.send_header('content-length', str(len(out))); self.end_headers(); self.wfile.write(out)
    def do_POST(self):
        n = int(self.headers.get('content-length', 0))
        raw = self.rfile.read(n).decode()
        try: body = json.loads(raw)
        except ValueError: body = raw   # a form body: Mapbox's route
        self.answer(body)
    def do_GET(self):
        self.answer({})
    def log_message(self, *a): pass
socketserver.TCPServer.allow_reuse_address = True


# ---- the on-ship generator: a pass against a stub model ----
srv = socketserver.TCPServer(('127.0.0.1', STUB_PORT), Stub)
threading.Thread(target=srv.serve_forever, daemon=True).start()
# a body and an open action of the section's own, deleted and dismissed at the end,
# so nothing here outlives the run for the other gates to trip over
curl('POST', API + '/observe', {'bodies': [{'id': 'thing/gate-car', 'name': 'the gate car'}], 'observations': []})
code, twin = curl('POST', API + '/act', {'kind': 'task', 'title': 'Open item for the gate car', 'about': ['thing/gate-car']})
MADE.append(dictish(twin).get('id', ''))
time.sleep(1)
curl('PUT', API + '/generator', {'enabled': True, 'url': 'http://127.0.0.1:%d' % STUB_PORT, 'model': 'moonshotai/kimi-k3', 'api_key': 'sk-stub', 'reasoning': {'enabled': False}, 'max_actions': 5, 'cooldown_minutes': 0, 'max_daily': 1000})
time.sleep(1)
code, before = curl('GET', API + '/generator/last')
before_at = dictish(before).get('at')
code, d = curl('POST', API + '/generate')
check('a forced pass answers ok', code == 200 and dictish(d).get('ok') is True, (code, d))
# the record changes when the pass ends; an earlier run's record is not it
deadline = time.time() + 90
last = {}
while time.time() < deadline:
    code, last = curl('GET', API + '/generator/last')
    #  the forced pass's own record carries the stub's usage; a record
    #  without it is another wake's (the settings write moved the beacon)
    if isinstance(last, dict) and last.get('at') and last.get('at') != before_at and not last.get('skipped') and last.get('usage'):
        break
    time.sleep(2)
# the filing wakes a follow-up pass, which finds the two open and rewrites
# the record a dozen seconds later; with the executor placing the two new
# tasks as todos meanwhile, a poll into the busy ship can land after that,
# so the two filed are read from whichever record stands
notes = ' '.join(dictish(last).get('notes', []))
filed_two = dictish(last).get('filed') == 2 and dictish(last).get('dropped') == 2 or (dictish(last).get('filed') == 0 and dictish(last).get('dropped') == 4 and all('dropped as already open or decided: ' + t in notes for t in (FRESH, FRESH2)))
# the follow-up pass the filing wakes can rewrite the record before a poll
# lands on the forced pass's own, so a skipped record with a fresh at is
# the same proof: the two filed are checked on the action list just below
check('the pass wrote a fresh record without error, two filed unless skipped', isinstance(last, dict) and last.get('at') != before_at and ((filed_two and 'stub note' in notes) or last.get('skipped') is True) and not last.get('error') and last.get('calls_today') >= 1, last)
#  the generator's request, not a reader's: the readers are on by
#  default and may call the stub first
def system_of(b):
    return ((b.get('messages') or [{}])[0].get('content') or [{}])[0].get('text', '')
gen_seen = [x for x in seen if x[2].get('messages') and not system_of(x[2]).startswith(('You turn', 'You refine'))]
_, hdrs, body = gen_seen[0] if gen_seen else ('', {}, {})
check('the stub saw the prompt with cache marks and temperature 0, reasoning off', body.get('model') == 'moonshotai/kimi-k3' and body.get('temperature') == 0 and body['messages'][1]['content'][0].get('cache_control') and body.get('provider') == {'zdr': True}, body.keys() if body else 'no request')
check('the key went in the header, not the body', hdrs.get('authorization') == 'Bearer sk-stub' and 'sk-stub' not in json.dumps(body), hdrs.get('authorization'))
code, acts = curl('GET', API + '/actions?status=open')
mine = [a for a in acts if a.get('by') == 'generator' and a.get('title') in (FRESH, FRESH2)] if isinstance(acts, list) else []
check('both surviving proposals are filed by generator with their why', len(mine) == 2 and sorted(a['payload'].get('why') for a in mine) == ['gate', 'gate too'], mine)
MADE.extend(a['id'] for a in mine)
code, d = curl('POST', API + '/observe', {'bodies': [], 'observations': [{'subject': 'thing/gate-car', 'attr': 'status', 'value': 'still writing', 'source': {'kind': 'user', 'id': 'gate'}}]}, timeout=20)
check('the writer still answers after a pass that filed two', code == 200, (code, d))
# filing a proposal is itself a change, so one more pass follows on its
# own and finds nothing new to file; wait for the model calls to settle
deadline = time.time() + 60
while time.time() < deadline and len(seen) < 2:
    time.sleep(2)
n = len(seen)
curl('POST', API + '/generate')
deadline = time.time() + 60
while time.time() < deadline and len(seen) == n:
    time.sleep(2)
check('a forced pass runs the model again', len(seen) == n + 1, (n, len(seen)))
n = len(seen)
curl('POST', API + '/observe', {'bodies': [], 'observations': [{'subject': 'thing/gate-car', 'attr': 'status', 'value': 'fixed', 'source': {'kind': 'user', 'id': 'gate'}}]})
deadline = time.time() + 90
while time.time() < deadline and len(seen) == n:
    time.sleep(2)
check('a change wakes the generator on its own', len(seen) == n + 1, (n, len(seen)))
n = len(seen)
curl('POST', API + '/observe', {'bodies': [], 'observations': [{'subject': 'thing/gate-car', 'attr': 'status', 'value': 'fixed', 'source': {'kind': 'user', 'id': 'gate'}}]})
deadline = time.time() + 12
while time.time() < deadline and len(seen) == n:
    time.sleep(1)
check('a repeat that changes nothing the model sees does not run it', len(seen) == n, (n, len(seen)))
for a in mine:
    curl('POST', API + '/actions/' + a['id'], {'status': 'dismissed', 'by': 'gate'})
if isinstance(twin, dict) and twin.get('id'):
    curl('POST', API + '/actions/' + twin['id'], {'status': 'dismissed', 'by': 'gate'})
# the limits hold a forced pass: with a cooldown of a day and a call just made, run-now is held
curl('PUT', API + '/generator', {'cooldown_minutes': 1440})
time.sleep(1)
code, before = curl('GET', API + '/generator/last')
curl('POST', API + '/generate')
deadline = time.time() + 60
while time.time() < deadline:
    code, last = curl('GET', API + '/generator/last')
    if dictish(last).get('at') != dictish(before).get('at'):
        break
    time.sleep(2)
check('a cooldown holds even a forced pass', dictish(last).get('skipped') is True and any('held by the limits' in n for n in dictish(last).get('notes', [])), last)


# ---- the urgent lane: a pass past the cooldown, under its own cap, open to writing keys ----
def urgent_pass(token=None, about=('thing/gate-car',)):
    code, before = curl('GET', API + '/generator/last')
    code, d = curl('POST', API + '/generate', {'about': list(about)}, token=token)
    if code != 200:
        return code, d, None
    deadline = time.time() + 60
    while time.time() < deadline:
        code2, last = curl('GET', API + '/generator/last')
        if dictish(last).get('at') != dictish(before).get('at'):
            return 200, d, last
        time.sleep(2)
    return 200, d, last


# the day's urgent count lives on the ship, so it is read before, not assumed zero
curl('PUT', API + '/generator', {'max_urgent': 1000})
time.sleep(0.5)
n = len(seen)
code, before = curl('GET', API + '/generator/last')
u0 = dictish(before).get('urgent_today') or 0
code, d, last = urgent_pass()
check('an urgent request answers ok and says it is urgent', code == 200 and dictish(d).get('urgent') is True, (code, d))
check('the urgent pass ran past the cooldown and says so', last and not dictish(last).get('skipped') and any(x.startswith('urgent pass: thing/gate-car') for x in dictish(last).get('notes', [])) and dictish(last).get('urgent_today') == u0 + 1, last)
gen_new = [b for _, _, b in seen[n:] if b.get('messages') and not system_of(b).startswith(('You turn', 'You refine'))]
prompt_seen = json.dumps(gen_new[-1]) if len(gen_new) == 1 else ''
check('the model saw the urgent line before the clock', 'Urgent:' in prompt_seen and prompt_seen.index('Urgent:') > prompt_seen.index('Recent decisions'), (len(gen_new), len(seen), n))
for a in curl('GET', API + '/actions?status=proposed')[1] or []:
    if isinstance(a, dict) and a.get('by') == 'generator':
        curl('POST', API + '/actions/' + a['id'], {'status': 'dismissed', 'by': 'gate', 'note': 'gate'})
code, reader = curl('POST', API + '/clients', {'name': 'gate reader', 'by': 'gate-reader', 'scope': {'kinds': ['person', 'situation', 'thing'], 'actions': ['task'], 'write': True, 'sensitive': 'none'}})
code, looker = curl('POST', API + '/clients', {'name': 'gate looker', 'by': 'gate-looker', 'scope': {'kinds': ['person'], 'actions': [], 'write': False, 'sensitive': 'none'}})
code, d = curl('POST', API + '/generate', {'about': []}, token=dictish(looker).get('token'))
check('a key without write may not ask for an urgent pass', code == 403, (code, d))
code, d = curl('POST', API + '/generate', {}, token=dictish(reader).get('token'))
check('a key may not run-now', code == 403, (code, d))
curl('PUT', API + '/generator', {'max_urgent': 1})
time.sleep(0.5)
code, d, last = urgent_pass(token=dictish(reader).get('token'), about=[])
check('a writing key may ask, and the second urgent pass of the day is held by the cap', code == 200 and last and dictish(last).get('skipped') is True and any('urgent passes are spent' in x for x in dictish(last).get('notes', [])), (code, d, last))
for k in (reader, looker):
    if dictish(k).get('id'):
        curl('DELETE', API + '/clients/' + dictish(k)['id'])
curl('PUT', API + '/generator', {'max_urgent': 5})
curl('PUT', API + '/generator', {'enabled': False, 'api_key': None, 'cooldown_minutes': 60})
time.sleep(1)
curl('DELETE', API + '/body/thing/gate-car')

# ---- the telegram reader: a webhook update becomes facts through the stub model and decider ----
# the window keeps a chat's last messages for a day, and a fact the model
# hangs on a message id the window already holds is thrown away as written
# from context, so each run's messages carry ids of their own
MID = int(time.time()) % 900000
M1 = 'telegram/1001/%d' % (MID + 1)
# update ids are monotonic per bot and the hook drops one the record has
# already passed, so each run's ids start past the last run's
U0 = int(time.time())
TG_CANNED = {'choices': [{'message': {'content': json.dumps({
    'bodies': [{'id': 'place/gate-shop', 'name': 'the gate shop'}],
    'observations': [{'subject': 'person/me', 'attr': 'status', 'value': 'stranded, waiting for a tow', 'conf': 85, 'message': M1},
                     {'subject': 'thing/gate-car', 'attr': 'status', 'value': 'broken down', 'message': M1},
                     {'subject': 'thing/gate-car', 'attr': 'location', 'value': {'ref': 'place/gate-shop'}, 'message': M1}],
    'actions': [{'kind': 'task', 'title': 'Call a tow for the gate car', 'about': ['thing/gate-car'], 'message': M1}]})}}],
    'usage': {'prompt_tokens': 10, 'completion_tokens': 5, 'cost': 0.0001}}
DECIDER_CANNED = {'answers': {'worth_reading': {'type': 'noul', 'noul': 0.9}, 'needs_help_now': {'type': 'noul', 'noul': 0.9},
                              'status_0': {'type': 'choice', 'choice': 'circumstance', 'probabilities': {'circumstance': 0.97}}}}
curl('DELETE', API + '/body/thing/gate-car'); curl('DELETE', API + '/body/place/gate-shop')
# "car died": grounding keeps a fact about a body the message names, so the car answers to "car"
observe([{'id': 'thing/gate-car', 'name': 'the gate car', 'aliases': ['gate car', 'car']}], [])
# the day's urgent count lives on the ship, so the escalation's pass must not meet the cap
curl('PUT', API + '/generator', {'enabled': True, 'url': 'http://127.0.0.1:%d' % STUB_PORT, 'api_key': 'sk-stub', 'reasoning': {'enabled': False}, 'cooldown_minutes': 1440, 'max_daily': 1000, 'max_urgent': 1000})
curl('PUT', API + '/telegram', {'enabled': True, 'token': '123:abc', 'secret': 'hook-secret-abcdef', 'api_url': 'http://127.0.0.1:%d' % STUB_PORT, 'public_url': 'http://localhost:8080',
                               'chats': [1001], 'people': {'1001': 'person/me'}, 'gate': 30, 'escalate': 60, 'max_daily_messages': 500})
time.sleep(1)
HOOK = HOST + '/apps/orrery/telegram'
def update(uid, mid, text, chat=1001, user=1001, business=None):
    msg = {'message_id': mid, 'date': int(time.time()), 'chat': {'id': chat}, 'from': {'id': user}, 'text': text}
    if business:
        msg['business_connection_id'] = business
        return {'update_id': uid, 'business_message': msg}
    return {'update_id': uid, 'message': msg}
def hook(body, secret='hook-secret-abcdef', full=False):
    heads = () if secret is None else ('x-telegram-bot-api-secret-token: ' + secret,)
    code, d = gate.curl('POST', HOOK, body, timeout=30, headers=heads)
    return (code, d) if full else code
def tg_last(after_uid):
    deadline = time.time() + 60
    while time.time() < deadline:
        code, last = curl('GET', API + '/telegram/last')
        if dictish(last).get('update_id') == after_uid:
            return last
        time.sleep(2)
    return last
check('a wrong secret is refused', hook(update(U0 + 1, MID, 'x'), secret='nope') == 403, None)
check('no secret is refused', hook(update(U0 + 1, MID, 'x'), secret=None) == 403, None)
check('a body over 64 KB is refused before the parse', hook({'update_id': U0 + 1, 'pad': 'x' * 70000}) == 413, None)
code, d = curl('PUT', API + '/telegram', {'secret': 'short'})
check('a short secret is refused', code == 400, (code, d))
check('the webhook answers 200 at once', hook(update(U0 + 2, MID + 1, 'car died on route 9, stranded waiting for a tow')) == 200, None)
last = tg_last(U0 + 2)
b = curl('GET', API + '/body/thing/gate-car')[1]
st = dictish(dictish(b).get('attrs')).get('status') or {}
check('the message became facts signed telegram with the message as source', st.get('value') == 'broken down' and st.get('by') == 'telegram' and dictish(st.get('source')) == {'kind': 'chat', 'id': M1}, st)
check('a body the message does not name was dropped with its fact', 'place/gate-shop' not in {x['id'] for x in state()['bodies']} and any('no fact is about it' in n for n in dictish(last).get('notes', [])), last)
me = dictish(dictish(curl('GET', API + '/body/person/me')[1]).get('attrs')).get('status') or {}
check('the owner\'s status stands, checked as a circumstance', me.get('value') == 'stranded, waiting for a tow', me)
acts = [a for a in (curl('GET', API + '/actions?status=open')[1] or []) if a.get('title') == 'Call a tow for the gate car']
check('the task was filed by telegram', len(acts) == 1 and acts[0].get('by') == 'telegram', acts)
MADE.extend(a['id'] for a in acts)
# the urgent pass runs on the generator's own fiber after the poke; its record follows the reader's
deadline = time.time() + 90
while time.time() < deadline:
    code, glast = curl('GET', API + '/generator/last')
    if any(x.startswith('urgent pass') for x in dictish(glast).get('notes', [])):
        break
    time.sleep(2)
check('the escalation ran an urgent pass', any(x.startswith('urgent pass') for x in dictish(glast).get('notes', [])), glast)
check('the record says what happened', dictish(last).get('outcome') == 'facts' and dictish(last).get('read_today', 0) >= 1, last)
read_before = dictish(last).get('read_today')
check('a question yields nothing and is remembered as context', hook(update(U0 + 3, MID + 2, 'is the shop open?')) == 200 and dictish(tg_last(U0 + 3)).get('outcome') == 'nothing', None)
read_after = dictish(tg_last(U0 + 3)).get('read_today')
check('a chat not in chats is ignored', hook(update(U0 + 4, MID + 3, 'hello', chat=9)) == 200 and dictish(tg_last(U0 + 4)).get('outcome') == 'ignored', None)
check('questions do not count against the day', read_before is not None and read_after == read_before, (read_before, read_after))
hook(update(U0 + 6, MID + 5, 'still on route 9', business='conn-1'))
check('a business message from a connection the stub owns is read', dictish(tg_last(U0 + 6)).get('outcome') in ('facts', 'nothing'), tg_last(U0 + 6))
# Telegram resends an update it saw no 200 for; one whose id the record
# has passed is dropped at the hook, so it is not handled twice
before = dictish(tg_last(U0 + 6))
code, d = hook(update(U0 + 2, MID + 1, 'car died on route 9, stranded waiting for a tow'), full=True)
time.sleep(5)
after = dictish(curl('GET', API + '/telegram/last')[1])
check('a resent update after its cull is dropped', code == 200 and dictish(d).get('dropped') == 'seen' and after.get('update_id') == U0 + 6 and after.get('at') == before.get('at'), (code, d, before.get('at'), after))
# a new bot numbers its updates from its own start, so a token change
# resets the record's high-water mark; the stub answers only for 123:abc,
# so the token goes back (a change too) before the resend, a command
curl('PUT', API + '/telegram', {'token': '456:def'})
time.sleep(0.5)
curl('PUT', API + '/telegram', {'token': '123:abc'})
time.sleep(0.5)
reset = dictish(curl('GET', API + '/telegram/last')[1])
check('a token change resets the record\'s update id', reset.get('update_id') == 0 and reset.get('at') == before.get('at'), reset)
check('an update seen under the old token is handled again under the new one', hook(update(U0 + 5, MID + 4, '/at the gate shop')) == 200 and dictish(tg_last(U0 + 5)).get('at') != before.get('at'), tg_last(U0 + 5))
# a model outage (429, 5xx, no answer) keeps the update: neither recorded
# nor culled, read again on a retry timer five minutes out; the owner's
# wake route is how the gate hurries it
def inbox():
    return [c.get('name') for c in dictish(curl('GET', INSTANCE + '/telegram-inbox')[1]).get('children', [])]


def culled(*ids, secs=30):
    """whether these updates leave the inbox: the reader records a run and
    then culls its updates, so the cull is a beat behind the record"""
    deadline = time.time() + secs
    while time.time() < deadline:
        if not any('%012d' % i in inbox() for i in ids):
            return True
        time.sleep(1)
    return False


DOWN = True
before = dictish(curl('GET', API + '/telegram/last')[1])
check('the hook takes an update the model is down for', hook(update(U0 + 7, MID + 6, 'the tow truck is here')) == 200, None)
time.sleep(6)
kept, after = inbox(), dictish(curl('GET', API + '/telegram/last')[1])
check('an update the model was down for is kept: not recorded, still in the inbox', after.get('update_id') == before.get('update_id') and after.get('at') == before.get('at') and '%012d' % (U0 + 7) in kept, (before.get('update_id'), after, kept))
DOWN = False
code, d = curl('POST', API + '/telegram/wake')
check('the owner wakes the reader', code == 200 and dictish(d).get('ok') is True, (code, d))
woken = dictish(tg_last(U0 + 7))
check('the woken reader handled the kept update and culled it', woken.get('update_id') == U0 + 7 and woken.get('outcome') in ('facts', 'nothing') and culled(U0 + 7), (woken, inbox()))
# three updates in one chat that wait together (the model down while they
# land) are read as one run: one analyst call that sees all three, three
# messages counted, the record at the last of them
DOWN = True
before = dictish(curl('GET', API + '/telegram/last')[1])
for i, text in enumerate(['the car is making a noise', 'never mind, it was the cat', 'all good now']):
    hook(update(U0 + 8 + i, MID + 7 + i, text))
time.sleep(6)
DOWN = False
calls_before = len([p for p, _, _ in seen if p.endswith('/chat/completions')])
curl('POST', API + '/telegram/wake')
run = dictish(tg_last(U0 + 10))
asked = [b for p, _, b in seen if p.endswith('/chat/completions')][calls_before:]
prompt = ' '.join(((b.get('messages') or [{}])[-1].get('content') or [{}])[0].get('text', '') for b in asked)
check('three updates in one chat are read as one run', run.get('update_id') == U0 + 10 and run.get('read_today') == (before.get('read_today') or 0) + 3 and len(asked) == 1 and 'making a noise' in prompt and 'it was the cat' in prompt and 'all good now' in prompt, (run.get('update_id'), before.get('read_today'), run.get('read_today'), len(asked)))
check('and every one of them was culled', culled(U0 + 8, U0 + 9, U0 + 10), inbox())
code, d = curl('POST', API + '/telegram/webhook')
check('the ship registers its webhook with telegram', code == 200 and dictish(d).get('ok') is True, (code, d))
sw = [b for p, _, b in seen if p.endswith('/setWebhook')]
check('setWebhook carried the public url, the secret, the update kinds and one connection', sw and sw[-1].get('url') == 'http://localhost:8080/apps/orrery/telegram' and sw[-1].get('secret_token') == 'hook-secret-abcdef' and sw[-1].get('allowed_updates') == ['message', 'business_message'] and sw[-1].get('max_connections') == 1, sw[-1:])
code, d = curl('GET', API + '/telegram/webhook')
check('what Telegram holds is read through the ship, never the token', code == 200 and dictish(d).get('url') == 'http://localhost:8080/apps/orrery/telegram' and dictish(d).get('pending_update_count') == 2 and dictish(d).get('last_error_message') == 'Connection refused' and '123:abc' not in json.dumps(d), (code, d))
curl('PUT', API + '/telegram', {'public_url': 'http://localhost:8080/'})
time.sleep(0.5)
curl('POST', API + '/telegram/webhook')
sw = [b for p, _, b in seen if p.endswith('/setWebhook')]
check('a trailing slash on the public url is trimmed', sw and sw[-1].get('url') == 'http://localhost:8080/apps/orrery/telegram', sw[-1:])
curl('PUT', API + '/telegram', {'enabled': False, 'token': None, 'secret': None})
code, d = curl('POST', API + '/telegram/webhook')
check('the webhook is not registered without a token', code == 400, (code, d))
curl('PUT', API + '/generator', {'enabled': False, 'api_key': None, 'cooldown_minutes': 60, 'max_urgent': 5})
curl('DELETE', API + '/body/thing/gate-car'); curl('DELETE', API + '/body/place/gate-shop')
for a in acts:
    curl('POST', API + '/actions/' + a['id'], {'status': 'dismissed', 'by': 'gate', 'note': 'gate'})
for a in curl('GET', API + '/actions?status=proposed')[1] or []:
    if isinstance(a, dict) and a.get('by') == 'generator':
        curl('POST', API + '/actions/' + a['id'], {'status': 'dismissed', 'by': 'gate', 'note': 'gate'})
# the owner's status and location came from telegram; the next run's clean slate expects neither
for o in dictish(curl('GET', API + '/body/person/me')[1]).get('observations', []):
    if o['source']['id'].startswith('telegram/') and o['status'] != 'retracted':
        curl('POST', API + '/retract', {'id': o['id'], 'note': 'matrix rerun'})
# shutdown ends serving but keeps the socket bound; the executor section binds the port again
srv.shutdown()
srv.server_close()

# ---- reconcile: the passes of reconcile.py on the ship, on POST /reconcile ----
OVER = 'situation/2026-09-01-gate-over'
AHEAD = 'situation/2099-09-01-gate-ahead'
BALLET = ['situation/2026-09-04-gate-ballet', 'situation/2026-09-11-gate-ballet', 'situation/2026-09-18-gate-ballet']
FUTURE = 'situation/2099-10-02-gate-dentist'
RUN = time.strftime('%H%M%S')
# a pair merged in an earlier run is merged again at once, not proposed, so the pair is fresh per run
ORG, DANA = 'org/gate-dana-quill-' + RUN, 'person/gate-dana-' + RUN
BDAY = 'situation/2026-10-01-gate-felix-birthday'
for b in [OVER, AHEAD, FUTURE, ORG, DANA, BDAY, 'activity/gate-ballet', 'person/felix'] + BALLET:
    curl('DELETE', API + '/body/' + b)
observe([{'id': OVER, 'name': 'gate over'}, {'id': AHEAD, 'name': 'gate ahead'}, {'id': FUTURE, 'name': 'Gate dentist'},
         {'id': ORG, 'name': 'Gate Dana Quill'}, {'id': DANA, 'name': 'gate dana'}, {'id': BDAY, 'name': 'Felix Birthday'}]
        + [{'id': b, 'name': 'Gate Ballet'} for b in BALLET], [
    {'subject': OVER, 'attr': 'ends', 'value': '2026-09-01T15:00:00Z', 'at': '2026-08-25T12:00:00Z', 'source': src('retire-over'), 'by': 'api-matrix'},
    {'subject': AHEAD, 'attr': 'ends', 'value': '2099-09-01T15:00:00Z', 'at': '2026-08-25T12:00:00Z', 'source': src('retire-ahead'), 'by': 'api-matrix'},
    {'subject': FUTURE, 'attr': 'started', 'value': '2099-10-02T15:00:00Z', 'at': '2026-09-19T12:00:00Z', 'source': src('times-1'), 'by': 'api-matrix'},
    {'subject': FUTURE, 'attr': 'status', 'value': 'upcoming', 'at': '2026-09-19T12:00:00Z', 'source': src('times-2'), 'by': 'api-matrix'},
    {'subject': ORG, 'attr': 'phone', 'value': '555-0100', 'at': '2026-09-19T12:00:00Z', 'source': src('people-1'), 'by': 'api-matrix'}]
    + [{'subject': b, 'attr': 'started', 'value': b.split('/')[1][:10] + 'T15:00:00Z', 'at': b.split('/')[1][:10] + 'T15:00:00Z', 'source': src('act-' + b[-20:-12]), 'by': 'api-matrix'} for b in BALLET])
s = state()
check('an over situation is open until retired', OVER in s['situations'] and AHEAD in s['situations'], s['situations'])


def reconcile_now():
    code, before = curl('GET', API + '/reconcile/last')
    code, d = curl('POST', API + '/reconcile')
    deadline = time.time() + 90
    while time.time() < deadline:
        code2, last = curl('GET', API + '/reconcile/last')
        if dictish(last).get('at') != dictish(before).get('at'):
            return d, last
        time.sleep(2)
    return d, last


d, last = reconcile_now()
check('POST /reconcile answers ok and the record follows', dictish(d).get('ok') is True and dictish(last).get('at'), (d, last))
s = state()
ids = {b['id'] for b in s['bodies']}
check('the retire pass closes what is over and leaves what is ahead', OVER not in s['situations'] and AHEAD in s['situations'], s['situations'])
code, b = curl('GET', API + '/body/' + OVER)
st = dictish(dictish(b).get('attrs')).get('status') or {}
check('closed at its end, by retire', st.get('value') == 'closed' and st.get('at') == '2026-09-01T15:00:00Z' and st.get('by') == 'retire', st)
check('three ballets became one activity and the occurrences are gone', 'activity/gate-ballet' in ids and not any(b in ids for b in BALLET), sorted(i for i in ids if 'ballet' in i))
act = attrs(s, 'activity/gate-ballet') or {}
check('the activity is active with its last occurrence', dictish(act.get('status')).get('value') == 'active' and dictish(act.get('last')).get('value') == '2026-09-18T15:00:00Z', act)
fut = attrs(s, FUTURE) or {}
check('a future started became starts, and the phase word went', dictish(fut.get('starts')).get('value') == '2099-10-02T15:00:00Z' and 'started' not in fut and 'status' not in fut, fut)
check('a title made a person and a participant', 'person/felix' in ids and any(dictish(p).get('value', {}).get('ref') == 'person/felix' for p in (attrs(s, BDAY) or {}).get('participants', [])), attrs(s, BDAY))
code, acts = curl('GET', API + '/actions?status=open')
merges = [a for a in acts if a.get('kind') == 'merge' and dictish(a.get('payload')).get('from') == ORG and dictish(a.get('payload')).get('into') == DANA]
check('an org named like a person is proposed for a merge into the person', len(merges) == 1 and merges[0]['payload'].get('into') == DANA and merges[0]['status'] == 'proposed', merges)
if merges:
    curl('POST', API + '/actions/' + merges[0]['id'], {'status': 'approved', 'by': 'api-matrix'})
    # the executor takes an approval once the news has been still three seconds (version 67), so the
    # merge is waited for, not looked at after a fixed two
    deadline = time.time() + 60
    while time.time() < deadline:
        code, acts0 = curl('GET', API + '/actions?status=all')
        if any(dictish(a).get('id') == merges[0]['id'] and dictish(a).get('status') == 'done' for a in (acts0 if isinstance(acts0, list) else [])):
            break
        time.sleep(2)
    d, last = reconcile_now()
    s = state()
    ids = {b['id'] for b in s['bodies']}
    code, acts = curl('GET', API + '/actions?status=all')
    mine = [a for a in acts if a.get('id') == merges[0]['id']]
    check('the approved merge ran: the org is gone, its phone is on the person, the action is done', ORG not in ids and dictish(dictish(attrs(s, DANA)).get('phone')).get('value') == '555-0100' and mine and mine[0]['status'] == 'done', (ORG in ids, attrs(s, DANA), mine))
    #  the executor runs a merge at approval; reconcile runs one it missed.
    #  Either way it runs once, and reconcile counts only its own
    ran_by = [h.get('by') for h in (mine[0].get('history') or []) if dictish(h).get('status') == 'claimed'] if mine else []
    check('the merge ran once, by the executor or reconcile, and reconcile\'s record counts it only when reconcile ran it',
          len(ran_by) == 1 and ran_by[0] in ('ship', 'reconcile') and dictish(last).get('merged') == (1 if ran_by[0] == 'reconcile' else 0), (ran_by, last))
for b in [OVER, AHEAD, FUTURE, ORG, DANA, BDAY, 'activity/gate-ballet', 'person/felix'] + BALLET:
    curl('DELETE', API + '/body/' + b)

# ---- the telegram reader's settings ----
curl('PUT', API + '/telegram', {'enabled': False, 'token': None, 'secret': None})
code, d = curl('GET', API + '/telegram')
check('telegram settings read masked', code == 200 and dictish(d).get('token_set') is False and 'token' not in dictish(d), (code, d))
code, d = curl('PUT', API + '/telegram', {'token': '123:abc', 'secret': 'hook-secret-abcdef', 'chats': [1001], 'people': {'1001': 'person/me'}, 'gate': 30, 'escalate': 60})
time.sleep(0.5)
code, d = curl('GET', API + '/telegram')
check('the token and secret are set and never served', dictish(d).get('token_set') is True and dictish(d).get('secret_set') is True and '123:abc' not in json.dumps(d) and dictish(d).get('chats') == ['1001'], d)
check('the thresholds read back as they were written', dictish(d).get('gate') == 30 and dictish(d).get('escalate') == 60, d)
code, d = curl('PUT', API + '/telegram', {'chats': [1001, 1002]})
time.sleep(0.5)
code, d = curl('GET', API + '/telegram')
check('a write without the token keeps it', dictish(d).get('token_set') is True and sorted(dictish(d).get('chats') or []) == ['1001', '1002'], d)
code, d = curl('PUT', API + '/telegram', {'secret': 'short'})

# ---- the chat reader (version 39): its settings, the key rule, a pass and its record ----
code, d = curl('PUT', API + '/chat', {'enabled': False, 'dms': [], 'channels': [], 'people': {}, 'poll_minutes': None, 'backfill_hours': None, 'gate': None, 'read_own': None})
code, d = curl('PUT', API + '/chat', {'enabled': True, 'dms': ['~sampel-palnet', ' 0v4.club '], 'channels': ['chat/~host/general'], 'people': {'SAMPEL-PALNET': 'person/me'}, 'poll_minutes': 2, 'gate': 0.4})
time.sleep(0.5)
code, d = curl('GET', API + '/chat')
check('the chat settings read back normalised', code == 200 and dictish(d).get('enabled') is True and sorted(dictish(d).get('dms') or []) == ['0v4.club', '~sampel-palnet'] and dictish(d).get('channels') == ['chat/~host/general'] and dictish(d).get('people') == {'~sampel-palnet': 'person/me'} and dictish(d).get('poll_minutes') == 2 and dictish(d).get('gate') == 40 and dictish(d).get('backfill_hours') == 24, (code, d))
code, d = curl('PUT', API + '/chat', {'poll_minutes': 7})
time.sleep(0.5)
code, d = curl('GET', API + '/chat')
check('a write of one key keeps the lists', dictish(d).get('poll_minutes') == 7 and dictish(d).get('channels') == ['chat/~host/general'], d)
code, k = curl('POST', API + '/clients', {'name': 'gate chat setter', 'by': 'gate-chat', 'scope': {'kinds': ['person'], 'actions': [], 'write': True}})
code, ro = curl('POST', API + '/clients', {'name': 'gate chat reader', 'by': 'gate-chat-ro', 'scope': {'kinds': ['person'], 'actions': [], 'write': False}})
code, d = curl('PUT', API + '/chat', {'read_own': True}, token=dictish(k).get('token'))
check('a key with write may set the chat settings', code == 200, (code, d))
code, d = curl('GET', API + '/chat', token=dictish(k).get('token'))
check('and read them', code == 200 and dictish(d).get('read_own') is True, (code, d))
code, d = curl('PUT', API + '/chat', {'read_own': False}, token=dictish(ro).get('token'))
check('a read-only key may not', code == 403 and dictish(d).get('error') == 'read only key', (code, d))
code, d = curl('GET', API + '/chat/last', token=dictish(k).get('token'))
check('the record is the owner\'s', code == 403, (code, d))
curl('DELETE', API + '/clients/' + str(dictish(k).get('id')))
curl('DELETE', API + '/clients/' + str(dictish(ro).get('id')))
before_at = dictish(curl('GET', API + '/chat/last')[1]).get('at')
time.sleep(1.1)
code, d = curl('POST', API + '/chat/wake')
check('the reader takes a wake', code == 200 and dictish(d).get('ok') is True, (code, d))
last = dictish(gate.wait('the woken pass wrote a new record', lambda: (lambda l: l if l.get('at') and l.get('at') != before_at else None)(dictish(curl('GET', API + '/chat/last')[1])), 30))
check('since and at are set, nothing read on a ship with no messages', bool(last.get('since')) and last.get('read') == 0 and isinstance(last.get('notes'), list), last)
code, d = curl('PUT', API + '/chat', {'gate': 90})
code, d = curl('PUT', API + '/chat', {'gate': None, 'backfill_hours': 100000000})
time.sleep(0.5)
code, d = curl('GET', API + '/chat')
check('a null puts the default back and a wild number is clamped', dictish(d).get('gate') == 30 and dictish(d).get('backfill_hours') == 720, (code, d))
curl('PUT', API + '/chat', {'backfill_hours': None, 'poll_minutes': None})
code, d = curl('GET', API + '/chat/dms')
check('the DM list answers items and a note', code == 200 and isinstance(dictish(d).get('items'), list) and 'note' in dictish(d), (code, d))
code, d = curl('PUT', API + '/chat', {'enabled': False})
check('the reader is switched off again', code == 200, (code, d))

# ---- version 57: the version route, both chat lists in one pass ----
code, d = curl('GET', API + '/state?brief=1')
check('the brief state view answers with values, open situations and the kinds, no provenance',
      code == 200 and dictish(d).get('brief') is True and 'source' not in json.dumps(d) and 'history' not in json.dumps(d)
      and isinstance(dictish(d).get('kinds'), dict) and all('needs' in dictish(s) for s in listish(dictish(d).get('situations'))), (code, sorted(dictish(d).keys())))
code, d = curl('GET', API + '/version', jar=None, token=dictish(curl('POST', API + '/clients', {'name': 'gate version', 'by': 'gate-v', 'scope': {'kinds': ['person'], 'actions': [], 'write': False}})[1]).get('token'))
check('any key reads the version, the desk\'s', code == 200 and dictish(d).get('version') == json.load(open('code/version.json'))['version'], (code, d))
code, d = gate.curl('POST', API + '/exec/wake', {}, jar=JAR, headers=['Sec-Fetch-Site: cross-site'])
check('the owner\'s cookie on a request another site sent changes nothing', code == 403 and dictish(d).get('error') == 'a request from another site is refused', (code, d))
code, d = curl('GET', API + '/chat/lists')
check('the chat lists come as one document, each with items and a note', code == 200 and isinstance(dictish(dictish(d).get('dms')).get('items'), list) and 'note' in dictish(dictish(d).get('channels')), (code, d))


# ---- the read channel (version 59): text a key hands in becomes facts through the stub model ----
#  a text with no model to read it waits, so the stub listens and the
#  generator holds its key for this section alone
srv = socketserver.TCPServer(('127.0.0.1', STUB_PORT), Stub)
threading.Thread(target=srv.serve_forever, daemon=True).start()
curl('PUT', API + '/generator', {'url': 'http://127.0.0.1:%d' % STUB_PORT, 'api_key': 'sk-stub', 'reasoning': {'enabled': False}})
code, d = curl('PUT', API + '/read/settings', {'enabled': True, 'gate': 0, 'model': 'stub/read'})
check('the read settings answer as stored', code == 200 and dictish(d).get('enabled') is True and dictish(d).get('model') == 'stub/read', (code, d))
code, rk = curl('POST', API + '/clients', {'name': 'gate read writer', 'by': 'gate-read', 'scope': {'kinds': ['person'], 'actions': ['task'], 'write': True}})
code, rro = curl('POST', API + '/clients', {'name': 'gate read looker', 'by': 'gate-read-ro', 'scope': {'kinds': ['person'], 'actions': [], 'write': False}})
code, d = curl('POST', API + '/read', {'text': 'car died on route 9, stranded waiting for a tow', 'title': 'A page about the car', 'source': {'kind': 'web', 'id': 'https://example.test/car-%s' % RUN}}, jar=None, token=dictish(rk).get('token'))
READID = dictish(d).get('id', '')
check('a key with write hands text in and gets an id at once', code == 200 and dictish(d).get('ok') is True and bool(READID), (code, d))
code, d = curl('POST', API + '/read', {'text': 'x'}, jar=None, token=dictish(rro).get('token'))
check('a read-only key may not hand text in', code == 403 and dictish(d).get('error') == 'read only key', (code, d))
code, d = curl('POST', API + '/read', {'title': 'nothing'})
check('text is required', code == 400 and dictish(d).get('error') == 'text: required', (code, d))
read_last = gate.wait('the text was read and recorded', lambda: (lambda l: l if any(READID in n for n in l.get('notes', [])) else None)(dictish(curl('GET', API + '/read/last')[1])), 60) or {}
check('the record names the text by its id and title', any(READID + ': A page about the car' in n for n in read_last.get('notes', [])), read_last)
st = dictish(dictish(dictish(curl('GET', API + '/body/person/me')[1]).get('attrs')).get('status'))
check('the facts carry the page as their source and are signed by the key that handed it in', st.get('by') == 'gate-read' and dictish(st.get('source')) == {'kind': 'web', 'id': 'https://example.test/car-%s' % RUN}, st)
owner_only('the read record is the owner\'s, even to a writing key', 'GET', '/read/last')
curl('PUT', API + '/read/settings', {'enabled': False})
curl('PUT', API + '/generator', {'api_key': None})
srv.shutdown()
srv.server_close()
# the page's facts and actions: the next run's clean slate expects none
for o in dictish(curl('GET', API + '/body/person/me')[1]).get('observations', []):
    if dictish(o.get('source')).get('id', '').startswith('https://example.test/') and o['status'] != 'retracted':
        curl('POST', API + '/retract', {'id': o['id'], 'note': 'matrix rerun'})
for a in curl('GET', API + '/actions?status=open')[1] or []:
    if isinstance(a, dict) and a.get('by') in ('gate-read', 'web'):
        curl('POST', API + '/actions/' + a['id'], {'status': 'dismissed', 'by': 'gate', 'note': 'gate'})


# ---- the browsing reader (version 98): what the extension sends is kept by day, the pages tied to what the ship knows go to the model ----
#  the stub stands in for the ZDR model and the decider; a page tied to a
#  gate situation gains research, an order for a gate task proposes its
#  close, and a plain page, a bank's and a Claude artifact go nowhere
srv = socketserver.TCPServer(('127.0.0.1', STUB_PORT), Stub)
threading.Thread(target=srv.serve_forever, daemon=True).start()
curl('PUT', API + '/generator', {'url': 'http://127.0.0.1:%d' % STUB_PORT, 'api_key': 'sk-stub', 'reasoning': {'enabled': False}})
DECIDER_CANNED = {'answers': {'worth_reading': {'type': 'noul', 'noul': 0.9}, 'needs_help_now': {'type': 'noul', 'noul': 0.1}}}
BR_RUN = time.strftime('%H%M%S')
BR_SIT = 'situation/gate-br-pergola-' + BR_RUN
BR_PAGE = 'https://gate.example/pergola-' + BR_RUN
BR_SHOP = 'https://shop.gate.example/thanks-' + BR_RUN
BR_PLAIN = 'https://gate.example/weather-' + BR_RUN
BR_TASK_TITLE = 'Gate order cedar boards ' + BR_RUN
BR_FORM = 'https://camp.gate.example/registration-' + BR_RUN
BR_APP = HOST + '/grubbery/ball/apps/shell.shell/desks/orrery.desk/desk/data/orrery.orrery_app'
for a in curl('GET', API + '/actions?status=open')[1] or []:
    if isinstance(a, dict) and str(a.get('title', '')).startswith('Done? Gate order'):
        curl('POST', API + '/actions/' + a['id'], {'status': 'dismissed', 'note': 'matrix rerun'})
code, d = curl('PUT', API + '/browsing/settings', {'enabled': True, 'model': '', 'exclude': ['skip.gate.example'], 'interval_hours': 3})
d = dictish(d)
check('the browsing settings answer as stored', code == 200 and d.get('enabled') is True and d.get('model') == '' and d.get('exclude') == ['skip.gate.example'] and d.get('interval_hours') == 3, (code, d))
code, d = curl('GET', API + '/browsing')
d = dictish(d)
check('the status names what is never read, for the extension to skip too', code == 200 and 'bank' in listish(d.get('skip_hosts'))
      and 'claude.ai/artifact' in listish(d.get('skip_paths')) and d.get('exclude') == ['skip.gate.example'], d)
owner_only('the browsing settings are the owner\'s', 'GET', '/browsing/settings')
check('the schema knows research on a situation, and close as an action', 'research' in listish(dictish(dictish(dictish(curl('GET', API + '/schema')[1]).get('kinds')).get('situation')).get('attrs'))
      and 'close' in listish(dictish(curl('GET', API + '/schema')[1]).get('actions')), dictish(curl('GET', API + '/schema')[1]).get('actions'))
observe([{'id': BR_SIT, 'name': 'Gate pergola lumber ' + BR_RUN}], [])
code, d = curl('POST', API + '/act', {'kind': 'task', 'title': BR_TASK_TITLE, 'about': [BR_SIT], 'by': 'owner', 'payload': {}})
BR_TASK = dictish(d).get('id', '')
if dictish(d).get('status') == 'proposed':
    curl('POST', API + '/actions/' + BR_TASK, {'status': 'approved', 'note': 'gate'})
br_ms = int(time.time() * 1000)
br_old = br_ms - 30 * 3600000
br_batch = {'visits': [{'url': BR_FORM, 'title': 'Pergola lumber workshop registration', 'at': br_old, 'how': 'link'},{'url': BR_PAGE, 'title': 'Pergola lumber guide', 'at': br_ms, 'how': 'link'},
                       {'url': BR_SHOP, 'title': 'Thank you for your order', 'at': br_ms, 'how': 'form_submit'},
                       {'url': BR_PLAIN, 'title': 'Weather', 'at': br_ms, 'how': 'typed'},
                       {'url': 'https://gatebank.example/acct', 'title': 'Balance', 'at': br_ms, 'how': 'typed'},
                       {'url': 'https://claude.ai/artifact/gate', 'title': 'Doc', 'at': br_ms, 'how': 'link'},
                       {'url': 'https://skip.gate.example/x', 'title': 'Left out', 'at': br_ms, 'how': 'link'}],
            'pages': [{'url': BR_FORM, 'title': 'Pergola lumber workshop registration', 'text': 'Register for the pergola lumber workshop.', 'at': br_old},
                      {'url': BR_PAGE, 'title': 'Pergola lumber guide', 'text': 'How much pergola lumber to buy, and which cedar. ' * 10, 'at': br_ms},
                      {'url': BR_SHOP, 'title': 'Thank you for your order', 'text': 'Order ' + BR_RUN + ': cedar boards, arriving Friday.', 'at': br_ms},
                      {'url': BR_PLAIN, 'title': 'Weather', 'text': 'Rain later today.', 'at': br_ms},
                      {'url': 'https://gatebank.example/acct', 'title': 'Balance', 'text': 'balance', 'at': br_ms},
                      {'url': 'https://claude.ai/artifact/gate', 'title': 'Doc', 'text': 'ship data', 'at': br_ms}]}
code, d = curl('POST', API + '/browsing', br_batch)
check('a batch is taken at once', code == 202 and dictish(d).get('ok') is True and dictish(d).get('visits') == 7 and dictish(d).get('pages') == 6, (code, d))
code, d = curl('POST', API + '/browsing', {'visits': [{}] * 5001})
check('a batch past the cap is a 413', code == 413, (code, d))
gate.wait('the batch is laid by day', lambda: dictish(curl('GET', API + '/browsing')[1]).get('inbox') == 0 or None, 60)
br_day = time.strftime('%Y-%m-%d', time.gmtime(br_ms / 1000))
br_pages = dictish(curl('GET', BR_APP + '/browsing/pages/' + br_day + '?raw=1')[1])
br_urls = {dictish(v).get('url') for v in br_pages.values()}
check('the day keeps the pages, and never a bank\'s, a Claude artifact or a site the owner left out',
      {BR_PAGE, BR_SHOP, BR_PLAIN} <= br_urls and not any(('gatebank' in str(u)) or ('claude.ai' in str(u)) or ('skip.gate' in str(u)) for u in br_urls), sorted(map(str, br_urls))[-6:])
br_visits = listish(curl('GET', BR_APP + '/browsing/visits/' + br_day + '?raw=1')[1])
check('a visit keeps how it came about', any(dictish(v).get('url') == BR_SHOP and dictish(v).get('how') == 'form_submit' for v in br_visits), br_visits[-6:])
def br_last():
    return dictish(curl('GET', API + '/browsing/last')[1])
def br_pass():
    before = br_last().get('pass_at')
    curl('POST', API + '/browsing/wake', {})
    return gate.wait('the browsing pass runs', lambda: (lambda l: l if l.get('pass_at') != before else None)(br_last()), 90) or {}
last = br_pass()
check('with no model the tied pages wait, read by no model', last.get('sent') == 0 and last.get('tied', 0) >= 2
      and any('no ZDR model' in str(n) for n in last.get('notes', [])), last)
br_pages = dictish(curl('GET', BR_APP + '/browsing/pages/' + br_day + '?raw=1')[1])
br_by = {dictish(v).get('url'): dictish(v) for v in br_pages.values()}
check('the plain page is set aside as read, the tied one waits', bool(br_by.get(BR_PLAIN, {}).get('read')) and br_by.get(BR_PLAIN, {}).get('hits') == []
      and not br_by.get(BR_PAGE, {}).get('read'), (br_by.get(BR_PLAIN), br_by.get(BR_PAGE, {}).get('read')))
def br_answer(user):
    tag = re.search(r'(A\d+) \| task \| ' + re.escape(BR_TASK_TITLE), user)
    moves = [{'tag': tag.group(1), 'status': 'done', 'reason': 'the order went through'}] if tag else []
    #  a fact cites the message it comes from, as the analyst is told to
    blocks = re.split(r'\n--- message ', user)
    cite = next((b.split(' |', 1)[0] for b in blocks[1:] if BR_PAGE in b), '')
    return {'choices': [{'message': {'content': json.dumps({'bodies': [], 'observations': [{'subject': BR_SIT, 'attr': 'research', 'value': BR_PAGE, 'conf': 85, 'message': cite}],
            'actions': [], 'moves': moves})}}], 'usage': {'prompt_tokens': 10, 'completion_tokens': 5, 'cost': 0.0001}}
BROWSING_CANNED = br_answer
INTERESTS_CANNED = {'choices': [{'message': {'content': json.dumps({'topics': [{'topic': 'pergola building ' + BR_RUN, 'pages': 3}]})}}],
                    'usage': {'prompt_tokens': 10, 'completion_tokens': 5, 'cost': 0.0001}}
curl('PUT', API + '/browsing/settings', {'model': 'stub/zdr'})
br_seen = len(seen)
last = br_pass()
check('with a model the tied pages are read and filed', last.get('sent', 0) >= 3 and last.get('filed', 0) >= 1, last)
br_int = dictish(curl('GET', BR_APP + '/browsing-interests.json?raw=1')[1])
check('the week\'s pass names what the owner has been into', any(dictish(t).get('topic') == 'pergola building ' + BR_RUN for t in listish(br_int.get('topics'))), br_int)
br_open = [dictish(a) for a in listish(curl('GET', API + '/actions?status=open')[1])]
check('a new topic is proposed as one of the owner\'s likes', any(a.get('kind') == 'fact' and a.get('by') == 'browsing' and dictish(a.get('payload')).get('attr') == 'likes'
      and dictish(a.get('payload')).get('value') == 'pergola building ' + BR_RUN and a.get('status') == 'proposed' for a in br_open), [a.get('title') for a in br_open][-6:])
br_asked = ' '.join(user_text(b) for p, h, b in seen[br_seen:] if 'Channel: browsing' in user_text(b))
check('the model saw the tied pages, never the plain one, the bank or the artifact', BR_PAGE in br_asked and BR_SHOP in br_asked
      and BR_PLAIN not in br_asked and 'gatebank' not in br_asked and 'claude.ai/artifact' not in br_asked, br_asked[:400])
br_rows = listish(dictish(dictish(curl('GET', API + '/body/' + BR_SIT)[1]).get('attrs')).get('research'))
check('the page that bears on the situation is its research, filed by browsing', any(dictish(r).get('value') == BR_PAGE and dictish(r).get('by') == 'browsing'
      and dictish(dictish(r).get('source')).get('kind') == 'browsing' for r in br_rows), br_rows)
br_open = [dictish(a) for a in listish(curl('GET', API + '/actions?status=open')[1])]
br_close = [a for a in br_open if a.get('kind') == 'close' and dictish(a.get('payload')).get('action') == BR_TASK]
br_task = next((a for a in br_open if a.get('id') == BR_TASK), {})
check('the order proposes closing its task, for the owner; the task itself stays open', len(br_close) == 1 and br_close[0].get('status') == 'proposed'
      and br_close[0].get('by') == 'browsing' and br_task.get('status') == 'approved', (br_close, br_task.get('status')))
if br_close:
    curl('POST', API + '/actions/' + br_close[0]['id'], {'status': 'approved', 'note': 'gate'})
    curl('POST', API + '/exec/wake', {})
    done = gate.wait('the close is carried out', lambda: next((a for a in listish(curl('GET', API + '/actions?status=all')[1]) if dictish(a).get('id') == BR_TASK and dictish(a).get('status') == 'done'), None), 90)
    check('approved, the close closes the task', bool(done), done)
last = br_pass()
br_open = [dictish(a) for a in listish(curl('GET', API + '/actions?status=open')[1])]
br_nudge = [a for a in br_open if a.get('title') == 'Finish Pergola lumber workshop registration?']
check('a form left on a page tied to a plan, a day on, is asked about', len(br_nudge) == 1 and br_nudge[0].get('by') == 'browsing' and BR_SIT in listish(br_nudge[0].get('about')), [a.get('title') for a in br_open][-6:])
last = br_pass()
check('and only once', len([a for a in listish(curl('GET', API + '/actions?status=open')[1]) if dictish(a).get('title') == 'Finish Pergola lumber workshop registration?']) == 1, last)
# the owner's hand on a page (version 101): what the popup shows, filing,
# not related, the place for a plan, and the day page's card
code, d = curl('GET', API + '/browsing/page?' + urllib.parse.urlencode({'url': BR_PAGE, 'title': 'Pergola lumber guide'}))
d = dictish(d)
check('the page in hand: kept, read, tied to the situation and its research', code == 200 and d.get('kept') is True and bool(d.get('read'))
      and BR_SIT in [dictish(t).get('id') for t in listish(d.get('tied'))] and BR_SIT in [dictish(t).get('id') for t in listish(d.get('filed'))]
      and BR_SIT in [dictish(t).get('id') for t in listish(d.get('plans'))], d)
code, d = curl('GET', API + '/browsing/page?' + urllib.parse.urlencode({'url': 'https://www.chase.com/x'}))
check('a page the ship never reads says so', code == 200 and dictish(d).get('skipped') is True, d)
BR_HAND = 'https://hand.gate.example/notes-' + BR_RUN
code, d = curl('POST', API + '/browsing/file', {'url': BR_HAND, 'body': BR_SIT})
check('the owner files a page under a plan, at once', code == 200, (code, d))
br_rows = lambda: [dictish(r) for r in listish(dictish(dictish(curl('GET', API + '/body/' + BR_SIT)[1]).get('attrs')).get('research'))]
check('it is the plan\'s research, the owner\'s', bool(gate.wait('the research lands', lambda: [r for r in br_rows() if r.get('value') == BR_HAND and r.get('by') == 'owner'] or None, 30)), br_rows())
code, d = curl('POST', API + '/browsing/file', {'url': BR_HAND, 'body': 'situation/gate-br-nothing-' + BR_RUN})
check('filing under a body the ship lacks is a 404', code == 404, (code, d))
code, d = curl('POST', API + '/browsing/unrelate', {'url': BR_PAGE, 'body': BR_SIT})
check('not related takes the research back', code == 200 and dictish(d).get('retracted') == 1, (code, d))
gate.wait('the page is untied', lambda: BR_SIT not in [dictish(t).get('id') for t in listish(dictish(curl('GET', API + '/browsing/page?' + urllib.parse.urlencode({'url': BR_PAGE}))[1]).get('tied'))] or None, 30)
d = dictish(curl('GET', API + '/browsing/page?' + urllib.parse.urlencode({'url': BR_PAGE}))[1])
check('and no pass ties them again', BR_SIT not in [dictish(t).get('id') for t in listish(d.get('tied'))] and BR_SIT not in [dictish(t).get('id') for t in listish(d.get('filed'))], d)
BR_DINNER = 'situation/gate-br-dinner-' + BR_RUN
observe([{'id': BR_DINNER, 'name': 'Gate dinner ' + BR_RUN}], [obs(BR_DINNER, 'starts', iso(datetime.now(timezone.utc) + timedelta(days=3)), datetime.now(timezone.utc), USER)])
BR_VENUE = 'https://www.gate-grill.example/menu-' + BR_RUN
curl('DELETE', API + '/body/place/gate-grill')  # an earlier run cut short leaves its place, found by name
code, d = curl('POST', API + '/browsing/place', {'url': BR_VENUE, 'title': 'Dinner menu | Gate Grill', 'plan': BR_DINNER})
BR_PLACE = dictish(d).get('place', '')
check('the page is the place for a plan, named for the site', code == 200 and BR_PLACE == 'place/gate-grill', (code, d))
loc = gate.wait('the plan\'s location is set', lambda: (lambda v: v if dictish(dictish(v).get('value')).get('ref') == BR_PLACE else None)(dictish(dictish(dictish(curl('GET', API + '/body/' + BR_DINNER)[1]).get('attrs')).get('location'))), 30)
check('the plan\'s location is the place', bool(loc), loc)
br_site = dictish(dictish(dictish(curl('GET', API + '/body/' + BR_PLACE)[1]).get('attrs')).get('website'))
check('the place keeps the page as its website', br_site.get('value') == BR_VENUE, br_site)
code, d = curl('GET', API + '/browsing/recent')
d = dictish(d)
check('the day page\'s card: interests, pages filed lately, forms left', code == 200 and listish(dictish(d.get('interests')).get('topics'))
      and any(dictish(r).get('url') == BR_HAND for r in listish(d.get('research'))) and any('Pergola lumber workshop registration' in str(dictish(f).get('title')) for f in listish(d.get('forms'))), d)
curl('DELETE', API + '/body/' + BR_DINNER)
curl('DELETE', API + '/body/' + BR_PLACE)
BROWSING_CANNED = None
INTERESTS_CANNED = None
curl('PUT', API + '/browsing/settings', {'model': '', 'exclude': []})
curl('PUT', API + '/generator', {'api_key': None})
srv.shutdown()
srv.server_close()
for a in curl('GET', API + '/actions?status=open')[1] or []:
    if isinstance(a, dict) and (a.get('id') == BR_TASK or str(a.get('title', '')).startswith('Done? Gate order')
                                or a.get('title') == 'Finish Pergola lumber workshop registration?' or str(a.get('title', '')).startswith('You have been into pergola building')):
        curl('POST', API + '/actions/' + a['id'], {'status': 'dismissed', 'note': 'gate'})
curl('DELETE', API + '/body/' + BR_SIT)


# ---- a lattice page followed (version 66): a page sent from lattice is read as the owner's own, its
# situation made, read again when edited, and the follow ends when the situation is over. Needs lattice
# on the ship (its link name) and orrery's road into it; without lattice the section is skipped
LAT = (lambda d: d[0] if isinstance(d, list) and d else '')(curl('GET', HOST + '/grubbery/ball/sys/link/lattice/dest.lanes?raw=1')[1])
if not LAT:
    print('== a lattice page followed: skipped, lattice is not installed here')
else:
    print('== a lattice page followed')
    srv = socketserver.TCPServer(('127.0.0.1', STUB_PORT), Stub)
    threading.Thread(target=srv.serve_forever, daemon=True).start()
    curl('PUT', API + '/generator', {'url': 'http://127.0.0.1:%d' % STUB_PORT, 'api_key': 'sk-stub', 'reasoning': {'enabled': False}})
    curl('PUT', API + '/read/settings', {'enabled': True, 'gate': 0})
    FRUN = secrets.token_hex(3)
    FSIT = 'situation/gate-lisbon-' + FRUN
    FPAGE = 'trips/gate-lisbon-' + FRUN
    FLINK = 'trips/gate-tickets-' + FRUN
    was_canned = TG_CANNED
    TG_CANNED = {'choices': [{'message': {'content': json.dumps({
        'bodies': [{'id': FSIT, 'name': 'Trip to Lisbon ' + FRUN}],
        'observations': [{'subject': FSIT, 'attr': 'status', 'value': 'open', 'conf': 90},
                         {'subject': FSIT, 'attr': 'needs', 'value': 'a hotel for the third night', 'conf': 85}],
        'actions': [{'kind': 'task', 'title': 'Book the Lisbon hotel %s' % FRUN, 'about': [FSIT]}]})}}],
        'usage': {'prompt_tokens': 10, 'completion_tokens': 5, 'cost': 0.0001}}

    def lattice_save(name, text):
        return gate.curl('POST', HOST + '/apps/lattice/page-save?name=%s&type=md' % name, jar=JAR,
                         headers=['content-type: text/markdown'], raw=text)
    page1 = '# Trip to Lisbon %s\n\nFly TAP Friday; the third hotel night is not booked yet.\n\nTickets: [[%s]]\n' % (FRUN, FLINK)
    code, d = lattice_save(FPAGE, page1)
    check('lattice takes the page', code == 200, (code, d))
    lattice_save(FLINK, 'TAP 1234 LIS. Booking ref GATE%s.\n' % FRUN)
    code, d = curl('GET', API + '/follow?path=' + FPAGE)
    check('a page never sent has no follow', code == 200 and dictish(d).get('status') == 'none', (code, d))
    code, d = curl('POST', API + '/follow', {'path': FPAGE, 'title': 'Trip to Lisbon ' + FRUN, 'text': page1, 'links': [FLINK]})
    check('the send is taken at once and queued', code == 202 and dictish(d).get('ok') is True and dictish(d).get('status') == 'queued', (code, d))
    code, d = curl('POST', API + '/follow', {'path': 'Bad Path', 'text': 'x'})
    check('a path that is not a lattice page path is refused', code == 400, (code, d))
    code, d = curl('POST', API + '/follow', {'path': 'trips/x'})
    check('text is required', code == 400 and dictish(d).get('error') == 'text: required', (code, d))
    owner_only('the follow is the owner\'s, even to a writing key', 'GET', '/follow?path=' + FPAGE)
    fv = gate.wait('the page is read and its situation made', lambda: (lambda v: v if v.get('status') == 'following' else None)(dictish(curl('GET', API + '/follow?path=' + FPAGE)[1])), 90) or {}
    check('the follow names the situation, its title, what it needs and the one open task',
          fv.get('situation') == FSIT and fv.get('title') == 'Trip to Lisbon ' + FRUN and fv.get('needs') == 'a hotel for the third night' and fv.get('open') == 1 and fv.get('note') == '', fv)
    sit = dictish(curl('GET', API + '/body/' + FSIT)[1])
    check('the facts are the owner\'s own, from the page', dictish(dictish(sit.get('attrs')).get('needs')).get('by') in ('web', 'owner') and dictish(dictish(dictish(sit.get('attrs')).get('needs')).get('source')).get('id') == FPAGE, dictish(sit.get('attrs')).get('needs'))
    asked = [b for _, _, b in seen if 'lattice page %s' % FPAGE in json.dumps(b.get('messages', []))]
    check('the model saw the page named as the owner\'s, with the linked page under its path', bool(asked) and 'linked page %s' % FLINK in json.dumps(asked[-1]) and 'GATE%s' % FRUN in json.dumps(asked[-1]), len(asked))
    # edited: read again, onto the same situation, the line naming it
    TG_CANNED = {'choices': [{'message': {'content': json.dumps({'bodies': [], 'observations': [{'subject': FSIT, 'attr': 'needs', 'value': 'nothing more: the hotel is booked', 'conf': 85}], 'actions': []})}}],
                 'usage': {'prompt_tokens': 10, 'completion_tokens': 5, 'cost': 0.0001}}
    lattice_save(FPAGE, '# Trip to Lisbon %s\n\nAll three hotel nights are booked now.\n' % FRUN)
    time.sleep(3)
    curl('POST', API + '/follow/wake', {})
    fv = gate.wait('the edit is read again onto the same situation', lambda: (lambda v: v if v.get('needs') == 'nothing more: the hotel is booked' else None)(dictish(curl('GET', API + '/follow?path=' + FPAGE)[1])), 90) or {}
    check('the follow stands on the same situation, read anew', fv.get('situation') == FSIT and fv.get('status') == 'following', fv)
    asked = [b for _, _, b in seen if 'record of Trip to Lisbon %s (%s)' % (FRUN, FSIT) in json.dumps(b.get('messages', []))]
    check('the re-read told the model which situation the page is the record of', bool(asked), len(asked))
    # over: the owner closes it; the follow is resolved, live and after the pass
    # the close is stamped now, not at the run's start: the fold's winner is the latest fact
    fnow = datetime.now(timezone.utc)
    observe([], [obs(FSIT, 'status', 'closed', fnow, src('lisbon-close')), obs(FSIT, 'outcome', 'flew, stayed, came home', fnow, src('lisbon-close'))])
    # the view is live, so it reads resolved as soon as the close has landed, before any pass
    fv = gate.wait('closed, the follow reads resolved, with the outcome', lambda: (lambda v: v if v.get('status') == 'resolved' else None)(dictish(curl('GET', API + '/follow?path=' + FPAGE)[1])), 30) or {}
    check('closed, the follow reads resolved before any pass, with the outcome', fv.get('status') == 'resolved' and fv.get('outcome') == 'flew, stayed, came home', fv)
    curl('POST', API + '/follow/wake', {})
    fv = gate.wait('the pass records the resolve', lambda: (lambda v: v if v.get('note', '').startswith('resolved: ') else None)(dictish(curl('GET', API + '/follow?path=' + FPAGE)[1])), 60) or {}
    check('the pass leaves the follow resolved and says how it ended', fv.get('note') == 'resolved: flew, stayed, came home', fv)
    # sent again after the resolve: a fresh read, queued
    code, d = curl('POST', API + '/follow', {'path': FPAGE, 'title': 'Trip to Lisbon ' + FRUN, 'text': 'again', 'links': []})
    check('sent again, it is queued afresh', code == 202 and dictish(d).get('status') == 'queued', (code, d))
    # the fresh read must land while the stub still answers for this page: restored first, the stub
    # answered the car section's canned facts and left a task of them for the next run to trip on
    gate.wait('the fresh read lands', lambda: (lambda v: v if v.get('status') != 'queued' else None)(dictish(curl('GET', API + '/follow?path=' + FPAGE)[1])), 90)
    TG_CANNED = was_canned
    curl('PUT', API + '/read/settings', {'enabled': False})
    curl('PUT', API + '/generator', {'api_key': None})
    srv.shutdown()
    srv.server_close()
    for a in curl('GET', API + '/actions?status=open')[1] or []:
        if isinstance(a, dict) and FSIT in (a.get('about') or []):
            curl('POST', API + '/actions/' + a['id'], {'status': 'dismissed', 'note': 'gate'})
    curl('DELETE', API + '/body/' + FSIT)
    gate.curl('POST', HOST + '/apps/lattice/page-del?name=' + FPAGE, jar=JAR)
    gate.curl('POST', HOST + '/apps/lattice/page-del?name=' + FLINK, jar=JAR)


# ---- time to leave (version 69): the owner's position, an appointment they go to, Mapbox through the stub,
# the leave-by written and the alert recorded once; one they do not go to passed over ----
print('== time to leave')
srv = socketserver.TCPServer(('127.0.0.1', STUB_PORT), Stub)
threading.Thread(target=srv.serve_forever, daemon=True).start()
TRUN = secrets.token_hex(3)
tnow = datetime.now(timezone.utc).replace(microsecond=0)
#  the real weather on the dev ship would add its minutes to every leave
#  time here (version 76): off, the forecast held is cleared
curl('PUT', API + '/outdoors', {'weather': False})
gate.wait('the weather held is cleared', lambda: dictish(curl('GET', API + '/weather')[1]).get('periods') is None or None, 30)
TADDR = 'The Gate Ballet\n100 Main St, Riverton, IL 62701 ' + TRUN
code, d = curl('PUT', API + '/travel', {'enabled': True, 'token': 'gate-token', 'api_url': 'http://127.0.0.1:%d' % STUB_PORT, 'lead_min': 10, 'buffer_min': 5})
check('the travel settings answer masked', code == 200 and dictish(d).get('token_set') is True and 'token' not in dictish(d), (code, d))
code, d = curl('POST', API + '/position', {'lat': 'north', 'lon': -89.7})
check('a position that is not degrees is refused', code == 400, (code, d))
code, d = curl('POST', API + '/position', {'lat': 39.6588, 'lon': -89.7112, 'acc': 12})
check('the owner\'s position is taken', code == 200 and dictish(d).get('ok') is True, (code, d))
code, d = curl('GET', API + '/travel')
check('the settings say when the position came, never where', dictish(d).get('position_at') and '39.6588' not in json.dumps(d), d)
TSIT, TNO = 'situation/gate-leave-' + TRUN, 'situation/gate-not-mine-' + TRUN
tsrc = {'kind': 'user', 'id': 'gate-leave-' + TRUN}
def tobs(sub, attr, value): return {'subject': sub, 'attr': attr, 'value': value, 'at': iso(tnow), 'conf': 100, 'source': tsrc, 'by': 'owner'}
observe([{'id': TNO, 'name': 'Gate not mine ' + TRUN}, {'id': TSIT, 'name': 'Gate leave ' + TRUN}],
        [tobs(TNO, 'starts', iso(tnow + timedelta(minutes=40))), tobs(TNO, 'location', TADDR), tobs(TNO, 'participants', {'ref': 'person/gate-tg'}),
         tobs(TSIT, 'starts', iso(tnow + timedelta(minutes=45))), tobs(TSIT, 'location', TADDR), tobs(TSIT, 'attending', 'yes')])
seen.clear()
curl('POST', API + '/travel/wake', {})
tl = gate.wait('the leave fiber alerts', lambda: (lambda l: l if any('Gate leave' in n for n in l.get('notes', [])) else None)(dictish(curl('GET', API + '/travel/last')[1])), 60) or {}
tn = dictish(tl.get('next'))
check('the alert goes for the appointment the owner goes to, from their position, with the drive', any('told the owner to leave for Gate leave' in n for n in tl.get('notes', [])) and tn.get('id') == TSIT and tn.get('minutes') == 30 and tn.get('from') == 'position', tl)
check('the one the owner does not go to is passed over', TNO not in json.dumps(tl), tl)
check('the plan says why (version 73): the usual minutes, the roads, the incident that matters, nothing learned yet',
      tn.get('typical_minutes') == 18 and tn.get('via') == 'Gate Road' and tn.get('incident') == 'Gate crash' and tn.get('learned_min') == 0, tn)
check('the record holds no coordinate and no token', '39.6588' not in json.dumps(tl) and 'gate-token' not in json.dumps(tl), tl)
tb = dictish(dictish(curl('GET', API + '/body/' + TSIT)[1]).get('attrs'))
check('leave-by is on the appointment, the ship\'s', dictish(tb.get('leave-by')).get('value') == tn.get('leave_by') and dictish(tb.get('leave-by')).get('by') == 'ship', tb.get('leave-by'))
#  the pass that geocodes every known address (version 77) may run beside this one: only this address is counted
tgeo = [x for x in seen if x[0].startswith('/search/geocode/v6/batch?') and 'The Gate Ballet' in json.dumps(x[2])]
tdir = [x for x in seen if x[0].startswith('/directions/v5/mapbox/driving-traffic?')]
check('the address went to Mapbox once, permanently, in the body', len(tgeo) == 1 and 'permanent=true' in tgeo[0][0] and dictish((tgeo[0][2] or [{}])[0]).get('q', '').startswith('The Gate Ballet, 100 Main St'), tgeo)
check('the drive went as a form, lon before lat, the token in the URL', len(tdir) == 1 and tdir[0][1].get('content-type') == 'application/x-www-form-urlencoded'
      and str(tdir[0][2]).startswith('coordinates=-89.7112,39.6588;-89.6501,39.7817') and 'access_token=gate-token' in tdir[0][0], tdir)
seen.clear()
curl('POST', API + '/travel/wake', {})
time.sleep(8)
tl2 = dictish(curl('GET', API + '/travel/last')[1])
check('a second look neither alerts again nor asks Mapbox', not [x for x in seen if x[0].startswith(('/search', '/directions'))] and tl2.get('alerted') == tl.get('alerted'), (tl2.get('notes'), len(seen)))
owner_only('the travel record is the owner\'s', 'GET', '/travel/last')
# a pick-up (version 70): someone else drops off, the owner picks up; the alert is for the end
TPU = 'situation/gate-pickup-' + TRUN
observe([{'id': TPU, 'name': 'Gate swimming ' + TRUN}],
        [tobs(TPU, 'starts', iso(tnow + timedelta(minutes=20))), tobs(TPU, 'ends', iso(tnow + timedelta(minutes=80))), tobs(TPU, 'location', TADDR),
         tobs(TPU, 'drop-off', {'ref': 'person/gate-tg'}), tobs(TPU, 'pick-up', {'ref': 'person/me'}),
         tobs(TSIT, 'status', 'closed')])
curl('POST', API + '/travel/wake', {})
tp = gate.wait('the pick-up is planned', lambda: (lambda l: l if dictish(l.get('next')).get('id') == TPU else None)(dictish(curl('GET', API + '/travel/last')[1])), 60) or {}
check('a pick-up is planned for the end, as a pick-up, and the drop-off is not the owner\'s',
      dictish(tp.get('next')).get('trip') == 'pick' and dictish(tp.get('next')).get('starts') == iso(tnow + timedelta(minutes=80)), tp)
curl('DELETE', API + '/body/' + TPU)
# already there (version 72): a close fix at the place and a minute's drive: no alert, no next, so the phone's
# alarm stands down, and the occurrence quiet, not alerted, since no push went
TQ = 'situation/gate-there-' + TRUN
curl('POST', API + '/position', {'lat': 39.7817, 'lon': -89.6501, 'acc': 10})
observe([{'id': TQ, 'name': 'Gate there ' + TRUN}], [tobs(TQ, 'starts', iso(tnow + timedelta(minutes=12))), tobs(TQ, 'location', TADDR), tobs(TQ, 'attending', 'yes')])
curl('POST', API + '/travel/wake', {})
tq = gate.wait('the one the owner is at is left quiet', lambda: (lambda l: l if any(k.startswith(TQ + '@') for k in l.get('quiet') or []) else None)(dictish(curl('GET', API + '/travel/last')[1])), 60) or {}
check('at the place already: no alert, the occurrence quiet and not alerted, and not the phone\'s next',
      any(k.startswith(TQ + '@') for k in tq.get('quiet') or []) and not any(k.startswith(TQ + '@') for k in tq.get('alerted') or [])
      and dictish(tq.get('next')).get('id') != TQ and not any('to leave for Gate there' in x for x in tq.get('notes', [])), tq)
curl('DELETE', API + '/body/' + TQ)
# running late (version 73): the alert went and the trip is watched; a fix from the road with the drive as
# long as before puts the owner five minutes late: one late push, and a message to the organizer proposed
TLATE, TORG = 'situation/gate-late-' + TRUN, 'person/gate-late-org-' + TRUN
curl('POST', API + '/position', {'lat': 39.6588, 'lon': -89.7112, 'acc': 12})
tl0 = datetime.now(timezone.utc).replace(microsecond=0)
observe([{'id': TORG, 'name': 'Gate Coach ' + TRUN}, {'id': TLATE, 'name': 'Gate late ' + TRUN}],
        [tobs(TORG, 'ship', '~zod'), tobs(TLATE, 'starts', iso(tl0 + timedelta(minutes=30))), tobs(TLATE, 'location', TADDR),
         tobs(TLATE, 'attending', 'yes'), tobs(TLATE, 'organizer', {'ref': TORG})])
curl('POST', API + '/travel/wake', {})
gate.wait('the late one is alerted', lambda: (lambda l: l if any('to leave for Gate late' in n for n in l.get('notes', [])) else None)(dictish(curl('GET', API + '/travel/last')[1])), 60)
time.sleep(2)
curl('POST', API + '/position', {'lat': 39.6589, 'lon': -89.7113, 'acc': 12})
late = gate.wait('the late message is proposed', lambda: [a for a in (curl('GET', API + '/actions?status=open')[1] or [])
                 if isinstance(a, dict) and a.get('kind') == 'message' and dictish(a.get('payload')).get('to') == TORG] or None, 60) or []
check('late by five minutes or more: a message to the organizer is proposed, by chat, saying so, about the appointment',
      len(late) == 1 and dictish(late[0].get('payload')).get('via') == 'chat' and 'late' in dictish(late[0].get('payload')).get('text', '')
      and TLATE in (late[0].get('about') or []) and late[0].get('status') == 'proposed', late)
ttrip = dictish(curl('GET', INSTANCE + '/trip.json?raw=1')[1])
check('the trip is told once and holds its first estimate from the road', ttrip.get('key', '').startswith(TLATE + '@') and ttrip.get('told') is True and bool(ttrip.get('eta')), ttrip)
# the brief's stops (version 73): the late one pinned with that day's hours, and the map of them through the ship
code, b0 = curl('GET', API + '/brief/last')
curl('POST', API + '/brief/wake', {})
bl = gate.wait('the brief with its stops lands', lambda: (lambda b: b if b.get('at') and b.get('at') != dictish(b0).get('at') else None)(dictish(curl('GET', API + '/brief/last')[1])), 90) or {}
# the stop is in the brief only when it starts before the day ends; a run near midnight (UTC on a test ship)
# puts it in tomorrow's
if bl.get('day') == tl0.strftime('%Y-%m-%d') == (tl0 + timedelta(minutes=31)).strftime('%Y-%m-%d'):
    bline = [x for x in bl.get('text', '').split('\n') if 'Gate late' in x and x[:1] == '[' and x[1:2].isdigit()]
    check('a stop in the brief has its pin and that day\'s hours from the place search', len(bline) == 1 and bline[0].startswith('[1] ') and '9:00 AM - 5:00 PM' in bline[0], bl.get('text'))
    check('the brief keeps the pins for its map, lon before lat', bl.get('map') == 'pin-l-1+d9534f(-89.6501,39.7817)', bl.get('map'))
    import subprocess
    mp = subprocess.run(['curl', '-s', '-m', '60', '-b', JAR, API + '/brief/map'], capture_output=True).stdout
    check('the map is Mapbox\'s image, fetched by the ship', mp == GATE_PNG, len(mp))
    sbx = [x for x in seen if x[0].startswith('/search/searchbox/v1/forward?')]
    check('the place search went once encoded, near the place, businesses only', sbx and 'q=The%20Gate%20Ballet%2C%20100%20Main%20St' in sbx[-1][0] and 'proximity=-89.6501,39.7817' in sbx[-1][0] and 'types=poi' in sbx[-1][0], [x[0] for x in sbx])
else:
    print('  (the brief stop checks are skipped: the late one starts after the brief\'s day ends)')
owner_only('the brief map is the owner\'s', 'GET', '/brief/map')
# there (version 73): a close fix at the place within three minutes of the last ends the trip, and an arrival
# before the estimate teaches the place nothing to add
curl('POST', API + '/position', {'lat': 39.7817, 'lon': -89.6501, 'acc': 10})
gate.wait('the trip ends at the place', lambda: True if not dictish(curl('GET', INSTANCE + '/trip.json?raw=1')[1]).get('key') else None, 60)
learned = dictish(curl('GET', INSTANCE + '/trips.json?raw=1')[1])
check('the arrival is learned for the place: early, so nothing added', [v for k, v in learned.items() if TRUN in k] == [[0]], learned)
curl('DELETE', API + '/body/' + TLATE)
curl('DELETE', API + '/body/' + TORG)
for a in late:
    curl('POST', API + '/actions/' + a['id'], {'status': 'dismissed', 'note': 'gate'})
# traffic gone worse after the alert (version 76): the leave-by four minutes off, so the alert goes at once;
# the drive ten minutes longer by the look three minutes before the leave-by: a second push, once
TW = 'situation/gate-worse-' + TRUN
curl('POST', API + '/position', {'lat': 39.6588, 'lon': -89.7112, 'acc': 12})
tw0 = datetime.now(timezone.utc).replace(microsecond=0)
observe([{'id': TW, 'name': 'Gate worse ' + TRUN}], [tobs(TW, 'starts', iso(tw0 + timedelta(minutes=39))), tobs(TW, 'location', TADDR), tobs(TW, 'attending', 'yes')])
curl('POST', API + '/travel/wake', {})
twn = lambda l, s: l if any(s in n for n in l.get('notes', [])) else None
gate.wait('the worse one is alerted', lambda: twn(dictish(curl('GET', API + '/travel/last')[1]), 'to leave for Gate worse'), 60)
SLOW = 600
tw = gate.wait('the look before leaving finds it worse', lambda: twn(dictish(curl('GET', API + '/travel/last')[1]), 'traffic got worse for Gate worse'), 150) or {}
check('ten minutes worse, three minutes before the leave-by: a second push, the plan says 40 min, the look done',
      dictish(tw.get('next')).get('minutes') == 40 and dictish(tw.get('next')).get('rechecked') is True, tw)
SLOW = 0
curl('DELETE', API + '/body/' + TW)
# away (version 83): a trip said to be away leaves home's appointments to others, says why, and the brief says so;
# the owner's no puts them back
TAW, TAH = 'situation/gate-away-' + TRUN, 'situation/gate-home-' + TRUN
aw0 = datetime.now(timezone.utc).replace(microsecond=0)
def nowobs(sub, attr, value): return {'subject': sub, 'attr': attr, 'value': value, 'at': iso(datetime.now(timezone.utc).replace(microsecond=0)), 'conf': 100, 'source': tsrc, 'by': 'owner'}
observe([{'id': TAW, 'name': 'Gate trip ' + TRUN}, {'id': TAH, 'name': 'Gate home game ' + TRUN}],
        [tobs(TAW, 'starts', iso(aw0 - timedelta(hours=1))), tobs(TAW, 'ends', iso(aw0 + timedelta(days=2))), tobs(TAW, 'away', 'yes'),
         tobs(TAH, 'starts', iso(aw0 + timedelta(minutes=50))), tobs(TAH, 'location', TADDR), tobs(TAH, 'attending', 'yes')])
curl('POST', API + '/travel/wake', {})
ta = gate.wait('the away note lands', lambda: twn(dictish(curl('GET', API + '/travel/last')[1]), 'away: Gate trip'), 60) or {}
check('away: the home game the owner said yes to has no plan, and the record says why',
      not ta.get('next') and any(('away: Gate trip %s (said to be away)' % TRUN) in n and 'at home left to others' in n for n in ta.get('notes', [])), ta)
code, ab0 = curl('GET', API + '/brief/last')
curl('POST', API + '/brief/wake', {})
ab = gate.wait('the brief while away lands', lambda: (lambda b: b if b.get('at') and b.get('at') != dictish(ab0).get('at') else None)(dictish(curl('GET', API + '/brief/last')[1])), 90) or {}
awl = (ab.get('text') or '').split('When to leave', 1)[-1].split('\n\n', 1)[0]
check('the brief\'s When to leave says the owner is away and leaves the home game out (the day still lists it)',
      ('Away: Gate trip ' + TRUN) in awl and ('Gate home game ' + TRUN) not in awl, (ab.get('text') or '')[:600])
observe([], [nowobs(TAW, 'away', 'no')])
curl('POST', API + '/travel/wake', {})
tb = gate.wait('not away, the home game is planned', lambda: (lambda l: l if dictish(l.get('next')).get('id') == TAH else None)(dictish(curl('GET', API + '/travel/last')[1])), 60) or {}
check('the owner\'s no puts the home game back', dictish(tb.get('next')).get('id') == TAH, tb)
curl('DELETE', API + '/body/' + TAW)
curl('DELETE', API + '/body/' + TAH)
# every known address gets its point (version 77): a place's address becomes its geo, the ship's
TGP = 'place/gate-geo-' + TRUN
observe([{'id': TGP, 'name': 'Gate geo ' + TRUN}], [tobs(TGP, 'address', '7 Gate Way ' + TRUN)])
curl('POST', API + '/geocode/wake', {})
tg = gate.wait('the place gets its point', lambda: dictish(dictish(dictish(curl('GET', API + '/body/' + TGP)[1]).get('attrs')).get('geo')) or None, 60) or {}
check('a place with an address and no point gets its geo from Mapbox, the ship\'s', tg.get('value') == '39.7817,-89.6501' and tg.get('by') == 'ship', tg)
owner_only('the geocode wake is the owner\'s', 'POST', '/geocode/wake', {})
curl('DELETE', API + '/body/' + TGP)
curl('PUT', API + '/travel', {'enabled': False, 'token': None, 'api_url': None})
code, d = curl('GET', API + '/travel')
check('time to leave is off again, no token', dictish(d).get('enabled') is False and dictish(d).get('token_set') is False, d)
gate.wait('off, no plan stands for the phone or the nudges (version 76)', lambda: not dictish(curl('GET', API + '/travel/last')[1]).get('next'), 30)
curl('PUT', API + '/outdoors', {'weather': True})
srv.shutdown()
srv.server_close()
curl('DELETE', API + '/body/' + TSIT)
curl('DELETE', API + '/body/' + TNO)


# ---- the week (version 74): a day of health from the phone and of work from the computer, kept owner-only;
# the children and their shares; the Sunday review, mailed and kept ----
print('== the week')
WRUN = secrets.token_hex(3)
wtoday = datetime.now(timezone.utc).date()
wd1 = (wtoday - timedelta(days=1)).isoformat()
code, d = curl('POST', API + '/health', {'day': 'yesterday'})
check('a health day without a date is refused', code == 400 and 'YYYY-MM-DD' in str(dictish(d).get('error')), (code, d))
code, d = curl('POST', API + '/health', {'day': wd1, 'steps': 5210.7, 'active_minutes': 25, 'partial': False,
                                         'sleep': [{'start': wd1 + 'T04:10:00Z', 'end': wd1 + 'T10:40:00Z'}, {'start': wd1 + 'T12:00:00Z', 'end': wd1 + 'T11:00:00Z'}],
                                         'workouts': [{'type': 'running', 'start': wd1 + 'T21:00:00Z', 'end': wd1 + 'T21:30:00Z'}]}, jar=None, token=WKEY)
check('a writing key sends a day of health, answered with its day', code == 200 and dictish(d).get('ok') is True and dictish(d).get('day') == wd1, (code, d))
code, d = curl('GET', API + '/health')
hd = dictish(dictish(d).get(wd1))
check('the day is kept: whole steps, the backward sleep dropped, the workout typed',
      code == 200 and hd.get('steps') == 5210 and len(hd.get('sleep') or []) == 1 and dictish((hd.get('workouts') or [{}])[0]).get('type') == 'running' and hd.get('partial') is False, hd)
code, d = curl('POST', API + '/work', {'day': wd1, 'active_minutes': 9999, 'blocks': [{'start': wd1 + 'T13:00:00Z', 'end': wd1 + 'T17:30:00Z'}, {'start': wd1 + 'T19:00:00Z', 'end': wtoday.isoformat() + 'T01:40:00Z'}]}, jar=None, token=WKEY)
check('a writing key sends a day of work', code == 200 and dictish(d).get('day') == wd1, (code, d))
code, d = curl('GET', API + '/work')
check('the ship counts the work minutes from the blocks, not the sender', dictish(dictish(d).get(wd1)).get('active_minutes') == 670, dictish(d).get(wd1))
owner_only('health is the owner\'s to read, even to the key that sends it', 'GET', '/health')
owner_only('work is the owner\'s to read', 'GET', '/work')
owner_only('the review is the owner\'s', 'GET', '/review/last')
owner_only('the review\'s wake is the owner\'s', 'POST', '/review/wake', {})
code, st = curl('GET', API + '/state')
check('health and work are never in the state', code == 200 and '5210' not in json.dumps(st) and 'active_minutes' not in json.dumps(st), code)
# two children: a ten-year-old with a one-on-one this week, a toddler at half a share
WKID, WTOT, WONE = 'person/gate-kid-' + WRUN, 'person/gate-tot-' + WRUN, 'situation/gate-lunch-' + WRUN
wsrc = {'kind': 'user', 'id': 'gate-week-' + WRUN}
def wobs(sub, attr, value): return {'subject': sub, 'attr': attr, 'value': value, 'at': iso(datetime.now(timezone.utc).replace(microsecond=0)), 'conf': 100, 'source': wsrc, 'by': 'owner'}
observe([{'id': WKID, 'name': 'Gate Kid ' + WRUN}, {'id': WTOT, 'name': 'Gate Tot ' + WRUN}, {'id': WONE, 'name': 'Gate lunch ' + WRUN}],
        [wobs(WKID, 'relationship', 'daughter'), wobs(WKID, 'birthday', (wtoday - timedelta(days=3700)).isoformat()),
         wobs(WTOT, 'relationship', 'son'), wobs(WTOT, 'birthday', (wtoday - timedelta(days=800)).isoformat()),
         wobs(WONE, 'starts', iso(datetime.now(timezone.utc).replace(microsecond=0) - timedelta(days=2))),
         wobs(WONE, 'participants', {'ref': 'person/me'}), wobs(WONE, 'participants', {'ref': WKID})])
# the owner's day (version 75): the defaults are anyone's; an owner sets theirs, children under an age at a share
code, d = curl('GET', API + '/rhythm')
check('the day reads with its defaults filled in', code == 200 and dictish(d).get('quiet_from') and 'per_window' in dictish(d), d)
owner_only('the day is the owner\'s to read', 'GET', '/rhythm')
owner_only('and to set', 'PUT', '/rhythm', {'per_window': 1})
code, d = curl('PUT', API + '/rhythm', {'young_age': 5, 'young_share': 50})
code, d = curl('GET', API + '/rhythm')
check('an owner\'s share for younger children reads back', dictish(d).get('young_age') == 5 and dictish(d).get('young_share') == 50, d)
code, r0 = curl('GET', API + '/review/last')
code, d = curl('POST', API + '/review/wake', {})
rv = gate.wait('the review lands', lambda: (lambda r: r if r.get('at') and r.get('at') != dictish(r0).get('at') else None)(dictish(curl('GET', API + '/review/last')[1])), 90) or {}
rt = rv.get('text', '')
#  a run the day before left its own day of work, so the count of late nights is any
check('the review has the week\'s work, its late night and the baseline\'s progress',
      rt.startswith('Your week, ') and '11 h 10 until 01:40' in rt and re.search(r'\b\d+ late nights?\b', rt) and 'Learning your baseline: ' in rt, rt)
check('the review counts each child: the one-on-one for the older, half a share for the toddler, who is most behind',
      ('Gate Kid %s: 0 drives, 1 one-on-one' % WRUN) in rt and ('Gate Tot %s: 0 drives, 0 one-on-ones (50%% share)' % WRUN) in rt and ('Most behind: Gate Tot %s.' % WRUN) in rt, rt)
check('the review was mailed through auspex and pushed in a line', rv.get('sent') is True and 'workout' in rv.get('line', ''), (rv.get('sent'), rv.get('line'), rv.get('notes')))
# nudges and habits (version 75): a long stretch at the desk is one nudge, once; a habit shows its week
wnow = datetime.now(timezone.utc).replace(second=0, microsecond=0)
if 7 <= wnow.hour < 21:
    # a test ship's day of nudges starts empty, so a rerun the same day is not held by the cap of three
    import subprocess
    subprocess.run(['curl', '-s', '-m', '60', '-b', JAR, '-o', '/dev/null', '-X', 'POST', INSTANCE + '/nudge-last.json',
                    '--data-urlencode', 'action=write-text', '--data-urlencode', 'content={}'])
    code, d = curl('POST', API + '/work', {'day': wnow.date().isoformat(), 'blocks': [{'start': iso(wnow - timedelta(minutes=100)), 'end': iso(wnow)}]})
    code, n0 = curl('GET', API + '/nudge/last')
    curl('POST', API + '/nudge/wake', {})
    nl = gate.wait('the nudge lands', lambda: (lambda n: n if any(dictish(x).get('kind') == 'desk' and dictish(x).get('key') == 'desk/%d' % int((wnow - timedelta(minutes=100)).timestamp() * 1000) for x in n.get('sent') or []) else None)(dictish(curl('GET', API + '/nudge/last')[1])), 60) or {}
    desk = [x for x in nl.get('sent') or [] if dictish(x).get('kind') == 'desk']
    check('an hour and forty at the desk is a nudge to walk, pushed', desk and desk[-1].get('title') == '1 h 40 at the desk' and desk[-1].get('pushed') is True, nl)
    curl('POST', API + '/nudge/wake', {})
    time.sleep(6)
    nl2 = dictish(curl('GET', API + '/nudge/last')[1])
    check('the same stretch is not nudged twice', len([x for x in nl2.get('sent') or [] if dictish(x).get('key') == desk[-1].get('key')]) == 1 if desk else False, nl2)
else:
    print('  (the nudge checks are skipped: the quiet hours, nine at night to seven, UTC on a test ship)')
owner_only('the nudges are the owner\'s', 'GET', '/nudge/last')
WHAB = 'activity/gate-habit-' + WRUN
observe([{'id': WHAB, 'name': 'Gate habit ' + WRUN}], [wobs(WHAB, 'per-week', 3), wobs(WHAB, 'minutes', '20'), wobs(WHAB, 'last', wtoday.isoformat())])
code, r1 = curl('GET', API + '/review/last')
curl('POST', API + '/review/wake', {})
rv2 = gate.wait('a second review lands', lambda: (lambda r: r if r.get('at') and r.get('at') != dictish(r1).get('at') else None)(dictish(curl('GET', API + '/review/last')[1])), 90) or {}
check('a habit shows its week in the review', ('Gate habit %s: 1 of 3 this week' % WRUN) in rv2.get('text', ''), rv2.get('text'))
# family time: at the computer ten minutes into it is the owner's working late, one nudge
if 7 <= wnow.hour < 20:
    import subprocess
    hm = lambda t: t.strftime('%H:%M')
    curl('PUT', API + '/rhythm', {'family_from': hm(wnow - timedelta(minutes=30)), 'family_to': hm(wnow + timedelta(minutes=30))})
    subprocess.run(['curl', '-s', '-m', '60', '-b', JAR, '-o', '/dev/null', '-X', 'POST', INSTANCE + '/nudge-last.json',
                    '--data-urlencode', 'action=write-text', '--data-urlencode', 'content={}'])
    curl('POST', API + '/work', {'day': wnow.date().isoformat(), 'blocks': [{'start': iso(wnow - timedelta(minutes=20)), 'end': iso(wnow)}]})
    curl('POST', API + '/nudge/wake', {})
    fl = gate.wait('the family nudge lands', lambda: (lambda n: n if any(dictish(x).get('kind') == 'family' for x in n.get('sent') or []) else None)(dictish(curl('GET', API + '/nudge/last')[1])), 60) or {}
    check('at the computer in family time: one nudge to step away', [dictish(x).get('title') for x in fl.get('sent') or []] == ['Family time'], fl)
    curl('PUT', API + '/rhythm', {'family_from': None, 'family_to': None})
curl('PUT', API + '/rhythm', {'young_age': None, 'young_share': None})
code, d = curl('GET', API + '/rhythm')
check('cleared, the day is the defaults again', dictish(d).get('family_from') == '' and dictish(d).get('young_age') == 0, d)
for b in [WONE, WKID, WTOT]:
    curl('DELETE', API + '/body/' + b)
curl('DELETE', API + '/body/' + WHAB)


# ---- spheres (version 84): a sphere a model files waits for the owner's tap until they have confirmed three there;
# the owner's own are kept, and the sphere a row names is made ----
print('== spheres')
SRUN = secrets.token_hex(3)
SPH = 'sphere/gate-llc-' + SRUN
SB = ['situation/gate-sph-%s-%d' % (SRUN, i) for i in range(5)]
def sobs(sub, v, by): return {'subject': sub, 'attr': 'sphere', 'value': v, 'at': iso(datetime.now(timezone.utc).replace(microsecond=0)), 'conf': 90, 'source': {'kind': 'user', 'id': 'gate-sph-' + SRUN}, 'by': by}
def sattr(b): return dictish(dictish(curl('GET', API + '/body/' + b)[1]).get('attrs')).get('sphere')
observe([{'id': b, 'name': 'Gate sphere thing %s %d' % (SRUN, i)} for i, b in enumerate(SB)], [])
observe([], [sobs(SB[0], 'Gate LLC ' + SRUN, 'gate-model')])
held = gate.wait('the model\'s filing waits as a proposal', lambda: [a for a in listish(curl('GET', API + '/actions?status=open')[1]) if isinstance(a, dict) and a.get('kind') == 'fact' and dictish(a.get('payload')).get('subject') == SB[0]] or None, 30) or []
check('a model\'s first filing under a new sphere is a proposal by the model, naming the sphere as a ref, and no fact yet',
      len(held) == 1 and held[0].get('by') == 'gate-model' and dictish(dictish(held[0].get('payload')).get('value')).get('ref') == SPH and not sattr(SB[0]), held)
observe([], [sobs(SB[1], {'ref': SPH}, 'owner'), sobs(SB[2], {'ref': SPH}, 'owner'), sobs(SB[3], {'ref': SPH}, 'owner')])
code, sp = curl('GET', API + '/body/' + SPH)
check('the owner\'s filings are kept, and the sphere they name is made, named from its slug', code == 200 and dictish(sp).get('name') == 'Gate llc ' + SRUN and sattr(SB[1]), (code, dictish(sp).get('name')))
observe([], [sobs(SB[4], {'ref': SPH}, 'gate-model')])
check('three confirmed, a model\'s filing there stands at once', bool(gate.wait('the trusted filing lands', lambda: sattr(SB[4]), 30)))
curl('POST', API + '/actions/' + held[0]['id'], {'status': 'approved'}) if held else None
check('the proposal approved, its filing is the owner\'s', bool(gate.wait('the approved filing lands', lambda: (lambda r: r if dictish(r if not isinstance(r, list) else r[0]).get('by') == 'owner' else None)(sattr(SB[0])), 90)))
for b in SB + [SPH]:
    curl('DELETE', API + '/body/' + b)


# ---- outdoors (version 76): the weather service and the POTA list through the stub; the brief's weather ----
print('== outdoors')
srv = socketserver.TCPServer(('127.0.0.1', STUB_PORT), Stub)
threading.Thread(target=srv.serve_forever, daemon=True).start()
STUB = 'http://127.0.0.1:%d' % STUB_PORT
#  the parks are fetched again only when the location or the distance
#  changes (or a week passes), so each run asks a distance the last did not
pl0 = dictish(curl('GET', INSTANCE + '/parks-last.json?raw=1')[1])
code, d = curl('PUT', API + '/outdoors', {'nws_api': STUB, 'pota': True, 'pota_location': 'US-GT', 'pota_radius_km': 21 if pl0.get('radius_km') == 20 else 20, 'pota_api': STUB})
check('the outdoors settings answer with themselves', code == 200 and dictish(d).get('pota_location') == 'US-GT' and dictish(d).get('weather') is True, (code, d))
owner_only('the outdoors settings are the owner\'s', 'GET', '/outdoors')
owner_only('the weather is the owner\'s', 'GET', '/weather')
wx = gate.wait('the weather from the stub lands', lambda: (lambda w: w if w.get('alerts') else None)(dictish(curl('GET', API + '/weather')[1])), 60) or {}
check('the forecast and the alert are held, and the answer names no point',
      len(wx.get('periods') or []) > 5 and dictish((wx.get('alerts') or [{}])[0]).get('event') == 'Gate Advisory' and 'point' not in wx, wx)
nws = [x for x in seen if x[0].startswith(('/points/', '/gridpoints/', '/alerts/'))]
check('every call to the weather service says who asks', nws and all('orrery' in x[1].get('user-agent', '') for x in nws), [x[1].get('user-agent') for x in nws])
check('the point sent is coarse, two decimals', nws and all(re.match(r'/points/-?\d+\.\d{1,2},-?\d+\.\d{1,2}$', x[0]) for x in nws if x[0].startswith('/points/')), [x[0] for x in nws])
pl = gate.wait('the parks pass lands', lambda: (lambda p: p if p.get('location') == 'US-GT' and p.get('at') != pl0.get('at') else None)(dictish(curl('GET', INSTANCE + '/parks-last.json?raw=1')[1])), 60) or {}
check('the near park is added, the far one not', pl.get('near') == 1 and pl.get('added') == 1, pl)
code, b = curl('GET', API + '/body/place/pota-us-0001')
check('the park is a place with its reference and point', code == 200 and 'US-0001' in json.dumps(b) and 'POTA park' in json.dumps(b), (code, str(b)[:300]))
code, b = curl('GET', API + '/body/place/pota-us-0002')
check('the far park is not', code == 404, code)
code, b0 = curl('GET', API + '/brief/last')
curl('POST', API + '/brief/wake', {})
bl = gate.wait('the brief with the weather lands', lambda: (lambda b: b if b.get('at') and b.get('at') != dictish(b0).get('at') else None)(dictish(curl('GET', API + '/brief/last')[1])), 90) or {}
check('the brief gives the day\'s weather and the alert', 'Weather: 71F, Gate Thunderstorms' in (bl.get('text') or '') and 'Alert: Gate Advisory in force' in (bl.get('text') or ''), (bl.get('text') or '')[:800])
curl('PUT', API + '/outdoors', {'nws_api': '', 'pota': False, 'pota_location': '', 'pota_api': ''})
curl('DELETE', API + '/body/place/pota-us-0001')
srv.shutdown()
srv.server_close()


# ---- place lookups (version 87): Brave Search fills in what a thin place lacks, through the stub, never over the
# owner's facts; the key goes in the header and is never answered back ----
print('== place lookups')
srv = socketserver.TCPServer(('127.0.0.1', STUB_PORT), Stub)
threading.Thread(target=srv.serve_forever, daemon=True).start()
LRUN = secrets.token_hex(3)
LP, LNAME = 'place/gate-lookup-' + LRUN, 'Gate Lookup ' + LRUN
lnow = datetime.now(timezone.utc).replace(microsecond=0)
def lobs(sub, attr, value): return {'subject': sub, 'attr': attr, 'value': value, 'at': iso(lnow), 'conf': 100, 'source': {'kind': 'user', 'id': 'gate-lookup-' + LRUN}, 'by': 'owner'}
code, hd = curl('POST', API + '/observe', {'bodies': [{'id': 'place/home', 'name': 'Home'}, {'id': LP, 'name': LNAME}],
                                           'observations': [lobs('place/home', 'geo', '39.7817,-89.6501'), lobs(LP, 'phone', '+12175550199')]})
home_geo = (dictish(hd).get('observations') or [{}])[0].get('id')
#  saving the settings wakes the lookups, so the stub's log is cleared before
seen.clear()
code, d = curl('PUT', API + '/search', {'enabled': True, 'api_key': 'brave-gate', 'api_url': 'http://127.0.0.1:%d' % STUB_PORT, 'monthly_cap': 50})
check('the lookup settings answer with the key masked', code == 200 and dictish(d).get('api_key_set') is True and 'api_key' not in dictish(d) and dictish(d).get('monthly_cap') == 50, (code, d))
owner_only('the lookup settings are the owner\'s', 'GET', '/search')
curl('POST', API + '/geocode/wake', {})
def lattrs(): return dictish(dictish(curl('GET', API + '/body/' + LP)[1]).get('attrs'))
la = gate.wait('the lookup fills the place', lambda: (lambda a: a if dictish(a.get('address')).get('value') else None)(lattrs()), 90) or {}
check('what the place lacked is filed by the search at 60, the owner\'s phone untouched',
      dictish(la.get('address')).get('value') == '1 Gate Rd, Riverton, IL 62701' and dictish(la.get('address')).get('by') == 'search' and dictish(la.get('address')).get('conf') == 60
      and dictish(la.get('hours')).get('value') == 'Mon 09:00-17:00' and dictish(la.get('website')).get('value') == 'https://gate.example'
      and dictish(la.get('phone')).get('value') == '+12175550199' and dictish(la.get('phone')).get('by') == 'owner', la)
ls = [x for x in seen if x[0].startswith('/res/v1/local/place_search?')]
check('the search was asked with the key in its header, for the place by name, near home', ls and all(x[1].get('x-subscription-token') == 'brave-gate' for x in ls)
      and any(LNAME.replace(' ', '%20') in x[0] for x in ls) and all('latitude=' in x[0] for x in ls), [x[0] for x in ls])
curl('PUT', API + '/search', {'enabled': False, 'api_url': ''})
curl('DELETE', API + '/body/' + LP)
if home_geo: curl('POST', API + '/retract', {'id': home_geo, 'note': 'gate'})
srv.shutdown()
srv.server_close()


# ---- sharing management (version 95): the routes the Sharing page's buttons use, on one ship; the two-ship
# part is scripts/sharing-matrix.py ----
print('== sharing management')
code, d = curl('GET', API + '/private')
check('the private rows are listed', code == 200 and isinstance(dictish(d).get('ids'), list), (code, d))
for path, body in (('/sphere-decline', {'host': '~sampel-palnet', 'sphere': 'sphere/home'}), ('/sphere-leave', {'host': '~sampel-palnet', 'sphere': 'sphere/home'}),
                   ('/leave', {'host': '~sampel-palnet', 'id': 'person/me'})):
    code, d = curl('POST', API + path, body)
    check(path + ' of nothing there is a 404', code == 404, (code, d))
_, POL0 = curl('GET', API + '/policy')
curl('PUT', API + '/policy', dict(dictish(POL0), auto=[k for k in listish(dictish(POL0).get('auto')) if k != 'note']))
ASN = 'Gate assign ' + secrets.token_hex(3)
WHO = 'person/gate-asg-' + secrets.token_hex(3)
curl('POST', API + '/bodies', {'id': WHO, 'name': 'Gate assignee'})
code, a = curl('POST', API + '/act', {'kind': 'note', 'title': ASN, 'about': ['person/me'], 'by': 'api-matrix', 'payload': {'text': 'x'}})
ASNID = dictish(a).get('id', '')
code, d = curl('POST', API + '/actions/' + ASNID + '/assign', {'assignee': WHO})
check('a proposed action is assigned', code == 200, (code, d))
got = gate.wait('the assignee is written', lambda: next((x for x in listish(curl('GET', API + '/actions')[1]) if dictish(x).get('id') == ASNID
                                                     and dictish(dictish(dictish(x).get('payload')).get('assignee')).get('ref') == WHO), None), 30)
check('the action names who does it', bool(got), got)
code, d = curl('POST', API + '/actions/' + ASNID + '/assign', {'assignee': ''})
check('and no one in particular again', code == 200 and bool(gate.wait('the assignee goes', lambda: next((x for x in listish(curl('GET', API + '/actions')[1]) if dictish(x).get('id') == ASNID
      and 'assignee' not in dictish(dictish(x).get('payload'))), None), 30)), (code, d))
code, d = curl('POST', API + '/actions/' + ASNID + '/assign', {'assignee': 'nope'})
check('an assignee that is not a body id is a 400', code == 400, (code, d))
curl('POST', API + '/actions/' + ASNID, {'status': 'dismissed', 'note': 'gate'})
code, d = curl('POST', API + '/actions/' + ASNID + '/assign', {'assignee': WHO})
check('only a proposed action is assigned', code == 409, (code, d))
curl('PUT', API + '/policy', POL0)
curl('DELETE', API + '/body/' + WHO)

# ---- shared actions (version 92): the schema tells the models about the assignee; the two-ship part is
# scripts/action-matrix.py ----
print('== shared actions')
code, d = curl('GET', API + '/schema')
check('the task shape names an assignee', code == 200 and 'assignee' in dictish(dictish(dictish(d).get('payloads')).get('task')), dictish(dictish(d).get('payloads')).get('task'))

# ---- pairing (version 91): the list of matches waiting, and a word on one that is not there; the two-ship part is
# scripts/pairing-matrix.py ----
print('== pairing')
code, d = curl('GET', API + '/pairing')
check('the matches waiting are a list', code == 200 and isinstance(d, list), (code, d))
code, d = curl('POST', API + '/pairing', {'key': '~sampel-palnet|sphere/home', 'there': 'person/x', 'same': True})
check('a word on a sphere not followed is a 404', code == 404, (code, d))

# ---- sphere sharing (version 90): what a share and an accept refuse, a private row, the listing; the two-ship part
# is scripts/sphere-matrix.py ----
print('== sphere sharing')
OUR_NAME = str(curl('GET', HOST + '/~/host')[1]).strip()
for body, code_wanted, why in (({'sphere': 'person/me', 'ship': '~sampel-palnet'}, 400, 'a share of a body that is not a sphere'),
                        ({'sphere': 'sphere/home', 'ship': 'nope'}, 400, 'a share to no ship'),
                        ({'sphere': 'sphere/home', 'ship': OUR_NAME}, 400, 'a share to this ship itself'),
                        ({'sphere': 'sphere/gate-none-' + secrets.token_hex(3), 'ship': '~sampel-palnet'}, 404, 'a share of a sphere not here')):
    code, d = curl('POST', API + '/sphere-share', body)
    check(why + ' is a ' + str(code_wanted), code == code_wanted, (code, d))
code, d = curl('DELETE', API + '/sphere-share/sphere/gate-none/~sampel-palnet')
check('stopping a sphere share that is not there is a 404', code == 404, (code, d))
code, d = curl('POST', API + '/sphere-accept', {'host': '~sampel-palnet', 'sphere': 'sphere/home'})
check('accepting an offer that was never made is a 404', code == 404, (code, d))
PRIV = 'gate-row-' + secrets.token_hex(3)
code, d = curl('POST', API + '/private', {'id': PRIV, 'private': True})
check('a row is kept private', code == 200 and dictish(d).get('private') is True, (code, d))
code, d = curl('POST', API + '/private', {'id': PRIV, 'private': False})
check('and no longer', code == 200 and dictish(d).get('private') is False, (code, d))
code, d = curl('POST', API + '/private', {'id': ''})
check('a private mark needs a row id', code == 400, (code, d))
code, d = curl('GET', API + '/shares')
check('the shares listing names the spheres shared, offered and followed', code == 200 and all(k in dictish(d) for k in ('sphere_shares', 'sphere_offers', 'sphere_follows')), d)

# ---- twins (version 89): the schema keeps a twin per peer; the two-ship part is scripts/twins-matrix.py ----
print('== twins')
code, d = curl('GET', API + '/schema')
check('the schema holds twin as multi-valued', code == 200 and 'twin' in listish(dictish(d).get('multi')), dictish(d).get('multi'))
TWB = 'person/gate-twin-' + secrets.token_hex(3)
code, d = curl('POST', API + '/observe', {'bodies': [{'id': TWB, 'name': 'Gate twin'}], 'observations': [
    {'subject': TWB, 'attr': 'twin', 'value': {'ship': s, 'id': 'person/me'}, 'conf': 100,
     'source': {'kind': 'share', 'id': s + '/person/me'}, 'by': 'share'} for s in ('~sampel-palnet', '~zod')]})
code, d = curl('GET', API + '/body/' + TWB)
tw = dictish(dictish(d).get('attrs')).get('twin')
check('a body keeps a twin on each ship side by side', isinstance(tw, list) and len(tw) == 2, tw)
curl('DELETE', API + '/body/' + TWB)

# ---- location sharing (version 88): the route's shape and what a share refuses; the two-ship part is
# scripts/location-matrix.py ----
print('== location sharing')
code, d = curl('GET', API + '/location')
check('the location route answers what is shared, with whom, and who could be', code == 200 and all(k in dictish(d) for k in ('out', 'in', 'peers')), (code, d))
code, d = curl('POST', API + '/location/share', {'ship': 'not-a-ship'})
check('a share to no ship is a 400', code == 400, (code, d))
code, d = curl('POST', API + '/location/share', {'ship': str(curl('GET', HOST + '/~/host')[1]).strip()})
check('a share to this ship itself is a 400', code == 400, (code, d))
code, d = curl('POST', API + '/location/share', {'ship': '~sampel-palnet', 'until': '2020-01-01T00:00:00Z'})
check('a share that ended before it began is a 400', code == 400, (code, d))
code, d = curl('POST', API + '/location/share', {'ship': '~sampel-palnet', 'hours': 500})
check('hours are held to three days', code == 200 and dictish(d).get('until') and
      datetime.fromisoformat(dictish(d)['until'].replace('Z', '+00:00')) <= datetime.now(timezone.utc) + timedelta(hours=73), d)
code, d = curl('POST', API + '/location/share', {'ship': '~sampel-palnet'})
check('with no time and not until home, a share lasts two hours, replacing the one before', code == 200 and
      len([g for g in listish(dictish(curl('GET', API + '/location')[1]).get('out')) if dictish(g).get('ship') == '~sampel-palnet']) == 1, d)
code, d = curl('DELETE', API + '/location/share/~sampel-palnet')
check('a stop answers, told or not', code == 200 and dictish(d).get('ok') is True, (code, d))
code, d = curl('DELETE', API + '/location/share/~sampel-palnet')
check('stopping what is not shared is a 404', code == 404, (code, d))


# ---- the mail reader and the daily brief (version 52): settings, a brief sent through auspex, the record ----
code, d = curl('PUT', API + '/mail', {'enabled': True, 'poll_minutes': 0, 'backfill_hours': 9999, 'model': 'stub/mail'})
check('the mail settings answer as stored, clamped', code == 200 and dictish(d).get('enabled') is True and dictish(d).get('poll_minutes') == 1 and dictish(d).get('backfill_hours') == 720 and dictish(d).get('model') == 'stub/mail', (code, d))
code, mk = curl('POST', API + '/clients', {'name': 'gate mail reader', 'by': 'gate-mail', 'scope': {'kinds': ['person'], 'actions': [], 'write': True}})
code, d = curl('GET', API + '/mail', jar=None, token=dictish(mk).get('token'))
check('a key with write reads the mail settings', code == 200 and dictish(d).get('model') == 'stub/mail', (code, d))
code, d = curl('PUT', API + '/mail', {'enabled': False, 'poll_minutes': None, 'backfill_hours': None, 'model': None})
check('nulls clear the mail settings', code == 200 and dictish(d).get('enabled') is False and dictish(d).get('poll_minutes') == 10, (code, d))
code, d = curl('POST', API + '/mail/wake')
check('the mail reader wakes', code == 200, (code, d))
mail_last = gate.wait('the mail record lands', lambda: dictish(curl('GET', API + '/mail/last')[1]).get('at') and dictish(curl('GET', API + '/mail/last')[1]), 30)
owner_only('the mail record is the owner\'s, even to a writing key', 'GET', '/mail/last')
code, d = curl('POST', API + '/brief/wake')
check('the brief sends on a wake', code == 200, (code, d))
brief = gate.wait('the brief record lands', lambda: dictish(curl('GET', API + '/brief/last')[1]).get('day') and dictish(curl('GET', API + '/brief/last')[1]), 60)
today_local = brief.get('day')
check('the brief record names the day, its tags and its text', bool(today_local) and isinstance(brief.get('tags'), dict) and 'Waiting on you' in (brief.get('text') or '') and brief.get('sent') is True, {k: brief.get(k) for k in ('day', 'sent', 'notes')})
inbox = gate.wait('the brief is in auspex\'s inbox', lambda: [t for t in dictish(curl('GET', HOST + '/apps/auspex/api/inbox?view=all&limit=20')[1]).get('threads', []) if dictish(t).get('subject') == 'Daily brief %s' % today_local] or None, 30)
check('auspex holds the brief, from the owner to the owner', bool(inbox) and dictish(inbox[0]).get('from') == OUR and OUR in (dictish(inbox[0]).get('participants') or [OUR]), inbox)


# ---- the executor (version 34): approved actions carried out on the ship, the todo list kept in step ----
# the stub stands in for Telegram again (the telegram section shut it
# down); the calendar and auspex are the real desks on wex, installed
# and their roads consented, so the record's missing list reads empty
# and every path is the real one. A message via chat is Talon's and is
# left approved.
srv = socketserver.TCPServer(('127.0.0.1', STUB_PORT), Stub)
threading.Thread(target=srv.serve_forever, daemon=True).start()
curl('PUT', API + '/telegram', {'token': '123:abc', 'api_url': 'http://127.0.0.1:%d' % STUB_PORT})
XRUN = secrets.token_hex(3)
CAL_BASE = '/apps/shell.shell/desks/calendar.desk/desk/data/calendar.calendar_app'


def cal_poke(action):
    return curl('POST', HOST + '/grubbery/api/poke' + CAL_BASE + '/calendar.calendar?blot=/json', action)


def todos():
    code, ev = curl('GET', HOST + '/apps/calendar/events.json')
    return [e for e in (ev if isinstance(ev, list) else []) if dictish(e).get('cat') == 'todo']


def todo_for(aid, bound=30, gone=False):
    #  the todo carrying the action id, waited for (or waited to go)
    deadline = time.time() + bound
    while True:
        hits = [t for t in todos() if dictish(t.get('meta')).get('orrery') == aid]
        if bool(hits) != gone or time.time() >= deadline:
            return hits[0] if hits else None
        time.sleep(1)


def event_named(name, bound=30, gone=False):
    #  the calendar's own id for the event with this name, waited for
    #  (or waited to go), since the store takes a poke after acking it
    deadline = time.time() + bound
    while True:
        code, ev = curl('GET', HOST + '/apps/calendar/events.json')
        hits = [e for e in (ev if isinstance(ev, list) else []) if dictish(dictish(e).get('meta')).get('name') == name]
        if bool(hits) != gone or time.time() >= deadline:
            return dictish(hits[0]).get('id') if hits else None
        time.sleep(1)


def occurrences(eid, days=40):
    #  the starts the calendar's own expansion gives this event over
    #  the next few weeks, which is the only place a skip shows
    frm, to = int(now.timestamp() * 1000), int((now + timedelta(days=days)).timestamp() * 1000)
    code, w = curl('GET', HOST + '/apps/calendar/window.json?from=%d&to=%d' % (frm, to))
    return sorted(dictish(r).get('l') for r in dictish(w).get('rows', []) if dictish(r).get('id') == eid)


def is_open(aid):
    code, acts = curl('GET', API + '/actions?status=open')
    return any(dictish(a).get('id') == aid for a in (acts if isinstance(acts, list) else []))


def action(aid):
    code, acts = curl('GET', API + '/actions?status=all')
    hits = [a for a in (acts if isinstance(acts, list) else []) if dictish(a).get('id') == aid]
    return hits[0] if hits else {}


def settled(aid, bound=30):
    #  the action once it has left the open list, or as it stands at the bound
    deadline = time.time() + bound
    while time.time() < deadline and is_open(aid):
        time.sleep(1)
    return action(aid)


def steps(a):
    return [(h.get('status'), h.get('by')) for h in dictish(a).get('history', [])]


def passed(before=None, bound=20):
    #  the executor's record once a pass has ended after `before` (the
    #  record read before the change), or as it stands at the bound;
    #  a pass at idle takes a second or two, so this beats a fixed sleep
    at0 = dictish(before).get('at') if before is not None else dictish(curl('GET', API + '/exec/last')[1]).get('at')
    deadline = time.time() + bound
    while time.time() < deadline:
        last = dictish(curl('GET', API + '/exec/last')[1])
        if last.get('at') != at0:
            return last
        time.sleep(1)
    return dictish(curl('GET', API + '/exec/last')[1])


def until(fn, bound=30):
    deadline = time.time() + bound
    while not fn() and time.time() < deadline:
        time.sleep(1)
    return fn()


def exec_last(**want):
    #  the record, waited for (ten seconds at most) until it carries the
    #  counts asked for: the pass writes the action or the todo first and
    #  its record last, so a record read the moment the action moved can
    #  still be the pass before
    deadline = time.time() + 10
    while True:
        last = dictish(curl('GET', API + '/exec/last')[1])
        if not want or all(last.get(k) == v for k, v in want.items()) or time.time() >= deadline:
            return last
        time.sleep(1)


def propose(kind, title, **more):
    body = dict(kind=kind, title=title, by='api-matrix')
    body.update(more)
    code, d = curl('POST', API + '/act', body)
    return dictish(d).get('id', '') if code == 200 else ''


def approve(aid):
    return curl('POST', API + f'/actions/{aid}', {'status': 'approved'})[0]


def completion(answer):
    return {'choices': [{'message': {'content': json.dumps(answer)}}], 'usage': {'prompt_tokens': 10, 'completion_tokens': 5, 'cost': 0.0001}}


# the refine stub's replies, keyed by the owner's note; the extra's due is
# in 2099 so the retire and expire passes never touch it, and its title
# carries the run so an earlier run's leftover is never its twin
REFINE_EXTRA = 'Gate: buy the tow guy a coffee %s' % XRUN
REFINE_CANNED = {
    '': completion({'action': {'title': 'Tell Wren and Dana the tow is booked', 'payload': {'via': 'chat', 'to': 'person/gate-shipped', 'text': 'The tow is booked. Dana knows too.'}, 'about': ['person/gate-shipped'], 'due': None},
                    'extras': [{'kind': 'task', 'title': REFINE_EXTRA, 'payload': {'notes': 'before the tow'}, 'about': ['person/gate-shipped'], 'due': '2099-01-01T12:00:00Z'}], 'refused': ''}),
    'include karl in this': completion({'bodies': [{'id': 'person/gate-karl', 'kind': 'person', 'name': 'Gate Karl', 'aliases': []}],
                                        'action': {'title': 'Tell Wren and Karl the tow is booked', 'payload': {'via': 'chat', 'to': 'person/gate-shipped', 'text': 'The tow is booked.'}, 'about': ['person/gate-shipped', 'person/gate-karl'], 'due': None},
                                        'extras': [], 'refused': ''}),
    'turn the porch light on': completion({'refused': 'a message cannot switch a light; propose a home action instead'}),
    'send this as mail': completion({'action': {'title': 'Gate mail by refine %s' % XRUN, 'payload': {'via': 'mail', 'to': 'person/gate-shipped', 'text': 'a letter asked for at approval %s' % XRUN}, 'about': ['person/gate-shipped'], 'due': None},
                                     'extras': [], 'refused': ''}),
    # a key whose actions name only message asks for a task extra: the
    # revision lands and the extra is dropped with a note
    'also add a todo': completion({'action': {'title': 'Tell Wren and Karl the tow is booked', 'payload': {'via': 'chat', 'to': 'person/gate-shipped', 'text': 'The tow is booked.'}, 'about': ['person/gate-shipped'], 'due': None},
                                   'extras': [{'kind': 'task', 'title': 'Gate: todo by key %s' % XRUN, 'payload': {'notes': 'outside the key'}, 'about': ['person/gate-shipped'], 'due': '2099-01-01T12:00:00Z'}], 'refused': ''}),
}


def refine(aid, text, token=None):
    return curl('POST', API + f'/actions/{aid}/refine', {'text': text}, token=token)


for b in ['person/gate-tg', 'person/gate-ship', 'person/gate-nobody', 'person/gate-people', 'person/gate-shipped', 'person/gate-karl']:
    curl('DELETE', API + '/body/' + b)
code, d = observe(
    [{'id': 'person/gate-tg', 'name': 'the gate telegram person'}, {'id': 'person/gate-ship', 'name': 'the gate ship person'},
     {'id': 'person/gate-nobody', 'name': 'the gate person with no channel'}, {'id': 'person/gate-people', 'name': 'the gate person the people map knows'}],
    [obs('person/gate-tg', 'telegram', '1001', now - timedelta(minutes=1), USER)])
check('the four people the executor addresses land', code == 200 and all_ok(d, 'bodies', 4) and all_ok(d, 'observations', 1), (code, d))
# the gate ship person's ship attribute is not given yet: the mail test
# below proposes before it lands, so the channel rule (which only sees
# what a person has at proposal time) leaves that message via mail
# the reader's people map is the second way to a chat id, read backwards
curl('PUT', API + '/telegram', {'people': {'1001': 'person/me', '1002': 'person/gate-people'}})
owner_only('the executor record is the owner\'s, even to a writing key', 'GET', '/exec/last')
owner_only('the wake is the owner\'s, even to a writing key', 'POST', '/exec/wake', {})
last = exec_last()
check('the record carries every count, the failures, the missing desks and the notes', all(k in last for k in ('at', 'acted_at', 'claimed', 'sent', 'placed', 'failed', 'ticked', 'deleted', 'moved', 'closed', 'adopted', 'missing', 'notes')), last)
check('the calendar and auspex are found on wex and their roads open', last.get('missing') == [] and last.get('notes') == [], last)
# a message via telegram: claimed by the ship, one sendMessage through the stub, done with the chat
n = len(seen)
TGID = propose('message', 'Gate telegram %s' % XRUN, payload={'via': 'telegram', 'to': 'person/gate-tg', 'text': 'the gate says hello %s' % XRUN})
check('a message via telegram is proposed and approved', bool(TGID) and approve(TGID) == 200, TGID)
a = settled(TGID)
check('the ship claimed it and reported done with the chat', a.get('status') == 'done' and a.get('note') == 'sent to person/gate-tg by telegram' and steps(a)[-2:] == [('claimed', 'ship'), ('done', 'ship')], (a.get('status'), a.get('note'), steps(a)))
sent = [(p, b) for p, _, b in seen[n:] if p.endswith('/sendMessage')]
check('the stub saw one sendMessage under the token with the chat id and the text', len(sent) == 1 and sent[0][0] == '/bot123:abc/sendMessage' and sent[0][1].get('chat_id') == '1001' and sent[0][1].get('text') == 'the gate says hello %s' % XRUN, sent)
last = exec_last(claimed=1, sent=1)
check('the record counts the claim and the send, and says when', last.get('claimed') == 1 and last.get('sent') == 1 and last.get('failed') == [] and bool(last.get('acted_at')), last)
# a message to a person with no telegram attribute but in the people map: sent to the user id the map gives them
PEOPLEID = propose('message', 'Gate telegram people %s' % XRUN, payload={'via': 'telegram', 'to': 'person/gate-people', 'text': 'the people map hears this %s' % XRUN})
approve(PEOPLEID)
a = settled(PEOPLEID)
check('a person the people map knows is sent to that user id', a.get('status') == 'done' and a.get('note') == 'sent to person/gate-people by telegram' and steps(a)[-2:] == [('claimed', 'ship'), ('done', 'ship')], (a.get('status'), a.get('note'), steps(a)))
sent = [(p, b) for p, _, b in seen[n:] if p.endswith('/sendMessage')]
check('the stub saw the second sendMessage under the chat id from the people map', len(sent) == 2 and sent[1][1].get('chat_id') == '1002' and sent[1][1].get('text') == 'the people map hears this %s' % XRUN, sent)
# a message to a person with a ship: the channel rule files it via chat before the id is computed, and the rewrite is on the trail
code, d = observe(
    [{'id': 'person/gate-shipped', 'name': 'the gate person with a ship'}],
    [obs('person/gate-shipped', 'ship', OUR, now - timedelta(minutes=1), USER),
     obs('person/gate-shipped', 'telegram', '1002', now - timedelta(minutes=1), USER)])
SHIPID = propose('message', 'Gate shipped %s' % XRUN, payload={'via': 'telegram', 'to': 'person/gate-shipped', 'text': 'routed to chat'})
a = action(SHIPID)
check('a message to a person with a ship is filed via chat', code == 200 and bool(SHIPID) and dictish(a.get('payload')).get('via') == 'chat', (code, SHIPID, a))
code, log = curl('GET', INSTANCE + '/tr/log?raw=1')
check('the trail carries the rewrite among its newest entries', code == 200 and isinstance(log, list)
      and any(dictish(x).get('why') == 'via rewritten to chat: person/gate-shipped has a ship' for x in log[-30:]), log[-3:] if isinstance(log, list) else log)
# ---- refine at approval (version 36): a note under the proposed message, through the stub as the generator's model ----
# the generator stays off; the route needs only its key and url
curl('PUT', API + '/generator', {'url': 'http://127.0.0.1:%d' % STUB_PORT, 'api_key': 'sk-stub', 'reasoning': {'enabled': False}})
time.sleep(0.5)
n_refine = len(seen)
code, d = refine(SHIPID, 'include dana in this')
d = dictish(d)
ra, rx = dictish(d.get('action')), [dictish(x) for x in (d.get('extras') or [])]
check('a note refines the proposed message: ok, the revised action with the canned title and via chat, one extra',
      code == 200 and d.get('ok') is True and ra.get('id') == SHIPID and ra.get('title') == 'Tell Wren and Dana the tow is booked'
      and dictish(ra.get('payload')).get('via') == 'chat' and dictish(ra.get('payload')).get('text') == 'The tow is booked. Dana knows too.' and len(rx) == 1, (code, d))
EXTRAID = rx[0].get('id', '') if rx else ''
MADE.append(EXTRAID)
check('the extra is a task carrying refined_from and the original\'s about, approved under auto',
      rx and rx[0].get('kind') == 'task' and rx[0].get('title') == REFINE_EXTRA and dictish(rx[0].get('payload')).get('refined_from') == SHIPID
      and 'person/gate-shipped' in (rx[0].get('about') or []) and rx[0].get('status') == 'approved' and rx[0].get('due') == '2099-01-01T12:00:00Z', rx)
#  the readers' calls (on by default) go to the same stub: only the refine's count
asked = [(h, b) for p, h, b in seen[n_refine:] if p.endswith('/chat/completions') and system_of(b).startswith('You refine')]
check('the model was asked once under the generator\'s key, with the refine prompt as the system block',
      len(asked) == 1 and asked[0][0].get('authorization') == 'Bearer sk-stub', len(asked))
a = action(SHIPID)
check('read back, the action is still proposed under the new title with a last step revised by user',
      a.get('status') == 'proposed' and a.get('title') == 'Tell Wren and Dana the tow is booked' and steps(a)[-1] == ('revised', 'user') and steps(a)[0] == ('proposed', 'api-matrix'), (a.get('status'), a.get('title'), steps(a)))
check('the extra is open and the executor places its todo', bool(EXTRAID) and is_open(EXTRAID) and todo_for(EXTRAID) is not None, EXTRAID)
code, log = curl('GET', INSTANCE + '/tr/log?raw=1')
check('the trail records the revision among its newest entries', code == 200 and isinstance(log, list) and any(dictish(x).get('op') == 'revise-action' and dictish(x).get('by') == 'user' for x in log[-30:]), log[-4:] if isinstance(log, list) else log)
code, d = refine(SHIPID, 'include karl in this')
d = dictish(d)
karl = dictish(curl('GET', API + '/body/person/gate-karl')[1])
a = action(SHIPID)
check('a person the note names is created and the action names them',
      code == 200 and d.get('ok') is True and karl.get('name') == 'Gate Karl' and 'person/gate-karl' in (a.get('about') or []) and a.get('title') == 'Tell Wren and Karl the tow is booked'
      and 'person/gate-karl' in (dictish(d.get('action')).get('about') or []), (code, d, karl, a.get('about')))
code, d = refine(SHIPID, 'turn the porch light on')
a = action(SHIPID)
check('a refusal changes nothing and says why', code == 200 and dictish(d).get('ok') is False and dictish(d).get('note') == 'a message cannot switch a light; propose a home action instead'
      and a.get('title') == 'Tell Wren and Karl the tow is booked' and steps(a)[-1] == ('revised', 'user') and len([s for s, _ in steps(a) if s == 'revised']) == 2, (code, d, a.get('title'), steps(a)))
code, d = refine(SHIPID, '')
check('an empty note is refused', code == 400, (code, d))
code, taskkey = curl('POST', API + '/clients', {'name': 'gate task key', 'by': 'gate-task', 'scope': {'kinds': ['person'], 'actions': ['task'], 'write': True, 'sensitive': 'none'}})
code, rokey = curl('POST', API + '/clients', {'name': 'gate read key', 'by': 'gate-read', 'scope': {'kinds': ['person'], 'actions': ['message'], 'write': False, 'sensitive': 'none'}})
code, d = refine(SHIPID, 'include dana in this', token=dictish(taskkey).get('token'))
check('a key whose actions lack the kind does not see the action', code == 404 and dictish(d).get('note') == 'no such action', (code, d))
code, d = refine(SHIPID, 'include dana in this', token=dictish(rokey).get('token'))
check('a read only key may not refine', code == 403 and dictish(d).get('note') == 'read only key', (code, d))
code, msgkey = curl('POST', API + '/clients', {'name': 'gate message key', 'by': 'gate-msg', 'scope': {'kinds': ['person'], 'actions': ['message'], 'write': True, 'sensitive': 'none'}})
code, d = refine(SHIPID, 'also add a todo', token=dictish(msgkey).get('token'))
d = dictish(d)
a = action(SHIPID)
check('a key refines within its actions: the revision lands by the key, and an extra outside its actions is dropped with a note, not filed',
      code == 200 and d.get('ok') is True and d.get('extras') == [] and d.get('note') == 'dropped extra Gate: todo by key %s: not in this key\'s actions' % XRUN
      and steps(a)[-1] == ('revised', 'gate-msg') and not any(dictish(x).get('title') == 'Gate: todo by key %s' % XRUN for x in curl('GET', API + '/actions?status=all')[1]), (code, d, steps(a)))
for k in (taskkey, rokey, msgkey):
    if dictish(k).get('id'):
        curl('DELETE', API + '/clients/' + dictish(k)['id'])
# only the reader's three kinds are refined: a note has no shape a rewrite could be held to
curl('PUT', API + '/policy', {'auto': ['task'], 'push': 'proposed', 'retention_days': 365})
NOTEID = propose('note', 'Gate note %s' % XRUN, payload={'text': 'a note the gate refines'})
code, d = refine(NOTEID, 'make it shorter')
check('a proposed note is not refined, with the reason as error and as note',
      bool(NOTEID) and code == 409 and dictish(d).get('error') == 'only a task, a calendar event or a message can be refined' and dictish(d).get('note') == dictish(d).get('error'), (code, d, action(NOTEID).get('status')))
curl('POST', API + f'/actions/{NOTEID}', {'status': 'dismissed', 'note': 'gate'})
curl('PUT', API + '/policy', {'auto': ['task', 'note'], 'push': 'proposed', 'retention_days': 365})
# the channel set at approval stands: a chat message asked for as mail goes by mail, though its person has a ship
MAILREFID = propose('message', 'Gate chat to mail %s' % XRUN, payload={'via': 'chat', 'to': 'person/gate-shipped', 'text': 'a DM until the owner says mail'})
code, d = refine(MAILREFID, 'send this as mail')
a = action(MAILREFID)
check('a note sets the channel to mail and the revision is not rerouted',
      code == 200 and dictish(d).get('ok') is True and dictish(dictish(dictish(d).get('action')).get('payload')).get('via') == 'mail' and dictish(a.get('payload')).get('via') == 'mail', (code, d, a.get('payload')))
approve(MAILREFID)
a = settled(MAILREFID, bound=90)
check('approved, the executor sends it by mail to the person\'s ship', a.get('status') == 'done' and a.get('note') == 'sent to person/gate-shipped by mail' and steps(a)[-1] == ('done', 'ship'), (a.get('status'), a.get('note'), steps(a)))
curl('PUT', API + '/generator', {'api_key': None})
before = exec_last()
approve(SHIPID)
# a DM goes from the ship only with send_dms on (version 52); off, the
# message is left for the client and the record says so
passed(before)
a = action(SHIPID)
after = exec_last()
check('approved with DMs off, it is left for the client that sends chat, noted, and the claimed count does not move',
      a.get('status') == 'approved' and not any(s == 'claimed' for s, _ in steps(a)) and after.get('claimed') == before.get('claimed') and any('DMs are off' in n for n in after.get('notes', [])),
      (a.get('status'), steps(a), before.get('claimed'), after.get('claimed'), after.get('notes')))
code, d = refine(SHIPID, 'include dana in this')
check('an approved action is not refined, with the reason as error and as note', code == 409 and dictish(d).get('error') == 'only a proposed action can be refined' and dictish(d).get('note') == 'only a proposed action can be refined', (code, d))
curl('POST', API + f'/actions/{SHIPID}', {'status': 'dismissed', 'note': 'gate'})
if EXTRAID:
    curl('POST', API + f'/actions/{EXTRAID}', {'status': 'dismissed', 'note': 'gate'})
# a message to a person with no telegram attribute and not in the people map: no address, so no claim; left approved and noted
before = exec_last()
NOID = propose('message', 'Gate telegram nobody %s' % XRUN, payload={'via': 'telegram', 'to': 'person/gate-nobody', 'text': 'nobody hears this'})
approve(NOID)
passed(before)
a = action(NOID)
check('a person with no address is left approved, with no claim', a.get('status') == 'approved' and not any(s == 'claimed' for s, _ in steps(a)), (a.get('status'), steps(a)))
check('nothing was sent for it', len([p for p, _, _ in seen[n:] if p.endswith('/sendMessage')]) == 2, [p for p, _, _ in seen[n:]])
last = exec_last(notes=['a message waits: person/gate-nobody has no telegram attribute and is not in people'])
check('the record notes the message that waits, and no failure', last.get('notes') == ['a message waits: person/gate-nobody has no telegram attribute and is not in people'] and last.get('failed') == [], last)
before = exec_last()
curl('POST', API + f'/actions/{NOID}', {'status': 'dismissed', 'note': 'gate'})
passed(before)
last = exec_last(notes=[])
check('dismissed, it is noted no more', last.get('notes') == [], last)
# a message via mail: a send poke to auspex's writer, which probes its peer before it lands
MAILID = propose('message', 'Gate mail %s' % XRUN, payload={'via': 'mail', 'to': 'person/gate-ship', 'text': 'a letter from the gate %s' % XRUN})
code, d = observe([], [obs('person/gate-ship', 'ship', OUR, now - timedelta(minutes=1), USER)])
check('the gate ship person\'s ship lands, after the mail message was proposed via mail', code == 200 and all_ok(d, 'observations', 1), (code, d))
approve(MAILID)
a = settled(MAILID, bound=90)
check('a message via mail is sent by mail to the person\'s ship', a.get('status') == 'done' and a.get('note') == 'sent to person/gate-ship by mail' and steps(a)[-1] == ('done', 'ship'), (a.get('status'), a.get('note'), steps(a)))
code, box = curl('GET', HOST + '/apps/auspex/api/inbox')
threads = [t for t in dictish(box).get('threads', []) if dictish(t).get('subject') == 'Gate mail %s' % XRUN]
check('auspex holds the letter, from this ship, with the text as its snippet', code == 200 and len(threads) == 1 and threads[0].get('from') == OUR and threads[0].get('snippet') == 'a letter from the gate %s' % XRUN, (code, threads))
# a message via chat with DMs off is the client's: the ship never claims it
before = exec_last()
CHATID = propose('message', 'Gate chat %s' % XRUN, payload={'via': 'chat', 'to': 'person/gate-ship', 'text': 'a DM the ship does not send'})
approve(CHATID)
passed(before)
a = action(CHATID)
check('a message via chat is left approved for the client while DMs are off', a.get('status') == 'approved' and not any(s == 'claimed' for s, _ in steps(a)), (a.get('status'), steps(a)))
curl('POST', API + f'/actions/{CHATID}', {'status': 'dismissed', 'note': 'gate'})
# a calendar action: an event on the calendar, timed, carrying the action id
EV_START = (now + timedelta(days=3)).replace(hour=14, minute=0, second=0)
EVID = propose('calendar', 'Gate event %s' % XRUN, payload={'title': 'Gate event %s' % XRUN, 'starts': iso(EV_START), 'ends': iso(EV_START + timedelta(minutes=90)), 'location': 'the gate'})
approve(EVID)
a = settled(EVID)
check('an approved calendar action is done, on the calendar', a.get('status') == 'done' and a.get('note') == 'on the calendar' and steps(a)[-2:] == [('claimed', 'ship'), ('done', 'ship')], (a.get('status'), a.get('note'), steps(a)))
last = exec_last(placed=1, claimed=1)
check('the record counts the placing', last.get('placed') == 1 and last.get('claimed') == 1, last)
# the calendar's store takes the poke after acking it, so the event can land a moment after the action reads done
deadline = time.time() + 20
events = []
while time.time() < deadline and not events:
    events = [e for e in (curl('GET', HOST + '/apps/calendar/events.json')[1] or []) if dictish(dictish(e).get('meta')).get('orrery') == EVID]
    if not events:
        time.sleep(2)
ev = dictish(curl('GET', HOST + '/apps/calendar/event.json?id=' + urllib.parse.quote(events[0]['id'] if events else 'none', safe=''))[1])
check('the event reads back through the calendar: timed, from starts to ends, at the location, tagged orrery',
      len(events) == 1 and ev.get('cat') == 'timed' and ev.get('kind') == 'once' and ev.get('fin') == 'to'
      and ev.get('start_ms') == int(EV_START.timestamp() * 1000) and ev.get('end_ms') == int((EV_START + timedelta(minutes=90)).timestamp() * 1000)
      and dictish(ev.get('meta')) == {'name': 'Gate event %s' % XRUN, 'orrery': EVID, 'tags': ['orrery'], 'location': 'the gate'}, ev)
EVENT_ID = events[0]['id'] if events else ''
# a calendar action that cancels: a one-off comes off the calendar, one
# occurrence of a repeat is skipped. Both events are made through the
# calendar's own poke, so the cancel meets events the ship never placed,
# which is the case the owner has
for b in [str(dictish(b).get('id', '')) for b in dictish(curl('GET', API + '/state')[1]).get('bodies', [])]:
    if 'gate-cancel-' in b:
        curl('DELETE', API + '/body/' + b)
CANCEL_ONCE = (now + timedelta(days=6)).replace(hour=9, minute=0, second=0)
ONCE_NAME, REPEAT_NAME = 'Gate cancel once %s' % XRUN, 'Gate cancel repeat %s' % XRUN
cal_poke({'action': 'add-event', 'cat': 'timed', 'kind': 'once', 'fin': 'to', 'meta': {'name': ONCE_NAME},
          'start_ms': int(CANCEL_ONCE.timestamp() * 1000), 'end_ms': int((CANCEL_ONCE + timedelta(minutes=60)).timestamp() * 1000)})
cal_poke({'action': 'add-event', 'cat': 'timed', 'kind': 'weekly', 'fin': 'dur', 'dur_min': 60, 'args': {'days': ['thu'], 'at': 600},
          'meta': {'name': REPEAT_NAME}, 'start_ms': int((now + timedelta(days=1)).replace(hour=0, minute=0, second=0).timestamp() * 1000)})
ONCE_ID, REPEAT_ID = event_named(ONCE_NAME), event_named(REPEAT_NAME)
check('a one-off and a repeat the owner keeps are on the calendar', bool(ONCE_ID) and bool(REPEAT_ID), (ONCE_ID, REPEAT_ID))
was = occurrences(REPEAT_ID) if REPEAT_ID else []
check('the repeat expands into several occurrences ahead', len(was) > 2, was)
# ---- the calendar events reader (version 47): the two events become a situation and an activity on the ship ----
# the executor's pass runs on the store's change, so the bodies are
# waited for by the uid every row of theirs carries as its source
def rows_of(b):
    for v in dictish(b.get('attrs')).values():
        for r in (v if isinstance(v, list) else [v]):
            yield dictish(r)


def body_by_uid(uid, bound=120):
    deadline = time.time() + bound
    while True:
        code, st = curl('GET', API + '/state')
        hits = [b for b in dictish(st).get('bodies', []) if any(dictish(r.get('source')).get('id') == uid for r in rows_of(dictish(b)))]
        if hits or time.time() >= deadline:
            return dictish(hits[0]) if hits else {}
        time.sleep(1)


def refs(b, attr):
    v = dictish(b.get('attrs')).get(attr)
    rows = v if isinstance(v, list) else ([v] if v else [])
    return sorted(dictish(dictish(r).get('value')).get('ref', '') for r in rows)


sit = body_by_uid(ONCE_ID or 'none')
check('the one-off is a situation named by its date and title, found by the uid its rows carry',
      sit.get('id', '').startswith('situation/') and sit['id'].endswith('-gate-cancel-once-%s' % XRUN.lower()) and sit.get('name') == ONCE_NAME, sit.get('id'))
sattrs = dictish(sit.get('attrs'))
#  the owner is in an event that names nobody else; this title's "gate"
#  may name a gate person made earlier in the run, who then stands alone
ps = refs(sit, 'participants')
check('it starts and ends at the event, learned now, and person/me is in it only when it names nobody else',
      dictish(sattrs.get('starts')).get('value') == iso(CANCEL_ONCE) and dictish(sattrs.get('ends')).get('value') == iso(CANCEL_ONCE + timedelta(minutes=60))
      and 'started' not in sattrs and (ps == ['person/me'] or (bool(ps) and 'person/me' not in ps)) and dictish(sattrs.get('starts')).get('by') == 'calendar', sattrs)
check('its rows name the calendar and the uid as their source', dictish(dictish(sattrs.get('starts')).get('source')) == {'kind': 'calendar', 'id': ONCE_ID}, dictish(sattrs.get('starts')).get('source'))
act = body_by_uid(REPEAT_ID or 'none')
aattrs = dictish(act.get('attrs'))
check('the repeat is an activity with its cadence, its schedule, an organizer and a next until its end',
      act.get('id') == 'activity/gate-cancel-repeat-%s' % XRUN.lower() and dictish(aattrs.get('cadence')).get('value') == 'weekly' and dictish(aattrs.get('schedule')).get('value') == 'weekly'
      and refs(act, 'organizer') == ['person/me'] and bool(was) and dictish(aattrs.get('next')).get('value') == iso(datetime.fromtimestamp(was[0] / 1000, timezone.utc))
      and dictish(aattrs.get('next')).get('until') == iso(datetime.fromtimestamp(was[0] / 1000, timezone.utc) + timedelta(minutes=60)), aattrs)
cal_last = dictish(curl('GET', API + '/calendar/last')[1])
check('the record counts the events, the bodies made and the rows', cal_last.get('made', 0) >= 1 and cal_last.get('rows', 0) >= 5 and bool(cal_last.get('acted_at')), cal_last)
owner_only('the calendar record is the owner\'s, even to a writing key', 'GET', '/calendar/last')
n_rows = len(list(rows_of(sit)))
before = exec_last()
curl('POST', API + '/exec/wake')
passed(before)
check('a second pass writes the same occurrence no second time', n_rows > 0 and len(list(rows_of(body_by_uid(ONCE_ID or 'none', 1)))) == n_rows, n_rows)

OFFID = propose('calendar', 'Gate cancel the one-off %s' % XRUN, payload={'mode': 'cancel', 'event': ONCE_ID or 'none'})
approve(OFFID)
a = settled(OFFID)
check('an approved cancel of a one-off is done, off the calendar',
      a.get('status') == 'done' and a.get('note') == 'off the calendar' and steps(a)[-2:] == [('claimed', 'ship'), ('done', 'ship')], (a.get('status'), a.get('note'), steps(a)))
check('the one-off is gone from the calendar', event_named(ONCE_NAME, gone=True) is None, ONCE_ID)
deadline = time.time() + 45
while time.time() < deadline and dictish(dictish(body_by_uid(ONCE_ID or 'none', 1).get('attrs')).get('status')).get('value') != 'cancelled':
    time.sleep(3)
gone_sit = body_by_uid(ONCE_ID or 'none', 1)
check('the situation of a one-off taken off the calendar while ahead is cancelled', dictish(dictish(gone_sit.get('attrs')).get('status')).get('value') == 'cancelled', dictish(gone_sit.get('attrs')).get('status'))
DROP = was[1] if len(was) > 1 else 0
SKIPID = propose('calendar', 'Gate cancel one occurrence %s' % XRUN,
                 payload={'mode': 'cancel', 'event': REPEAT_ID or 'none', 'starts': iso(datetime.fromtimestamp(DROP / 1000, timezone.utc))})
approve(SKIPID)
a = settled(SKIPID)
check('an approved cancel naming an occurrence is done, that occurrence skipped',
      a.get('status') == 'done' and a.get('note') == 'that occurrence skipped' and steps(a)[-2:] == [('claimed', 'ship'), ('done', 'ship')], (a.get('status'), a.get('note'), steps(a)))
# the calendar takes the skip after acking the poke, so the window is
# read again until the occurrence goes
deadline = time.time() + 20
standing = occurrences(REPEAT_ID) if REPEAT_ID else []
while time.time() < deadline and DROP in standing:
    time.sleep(2)
    standing = occurrences(REPEAT_ID)
check('the named occurrence is off the calendar and the other occurrences stand', standing == [o for o in was if o != DROP], (was, standing))
GONEID = propose('calendar', 'Gate cancel a stranger %s' % XRUN, payload={'mode': 'cancel', 'event': '0v0.no.such@' + OUR})
approve(GONEID)
a = settled(GONEID)
check('a cancel naming an event the calendar does not have is failed, with the reason',
      a.get('status') == 'failed' and a.get('note') == 'the calendar does not have that event' and steps(a)[-2:] == [('claimed', 'ship'), ('failed', 'ship')], (a.get('status'), a.get('note'), steps(a)))
before = exec_last()
BAREID = propose('calendar', 'Gate cancel with no event %s' % XRUN, payload={'mode': 'cancel'})
approve(BAREID)
passed(before)
a = action(BAREID)
check('a cancel with no event is left approved, with no claim', a.get('status') == 'approved' and not any(s == 'claimed' for s, _ in steps(a)), (a.get('status'), steps(a)))
last = exec_last(notes=['a message waits: cancel needs the event'])
check('the record says what the cancel is missing', 'a message waits: cancel needs the event' in (last.get('notes') or []), last)
curl('POST', API + f'/actions/{BAREID}', {'status': 'dismissed', 'note': 'gate'})
# a task: placed in the todo list without a claim, and done when the owner ticks it in the calendar
TASK_DUE = (now + timedelta(days=4)).replace(hour=15, minute=0, second=0)
TASKID = propose('task', 'Gate task %s' % XRUN, due=iso(TASK_DUE), payload={'notes': 'from the gate'})
MADE.append(TASKID)
t = todo_for(TASKID)
check('an approved task becomes a todo carrying the action id, its notes, its due and the tag',
      t is not None and t.get('done') is False and t.get('due_ms') == int(TASK_DUE.timestamp() * 1000)
      and dictish(t.get('meta')) == {'name': 'Gate task %s' % XRUN, 'orrery': TASKID, 'tags': ['orrery'], 'note': 'from the gate'}, t)
a = action(TASKID)
check('the task itself stays approved, with no claim', a.get('status') == 'approved' and steps(a) == [('proposed', 'api-matrix'), ('approved', 'policy')], steps(a))
before = exec_last()
curl('POST', API + '/exec/wake', {})
passed(before)
check('a second pass does not place it again', len([x for x in todos() if dictish(x.get('meta')).get('orrery') == TASKID]) == 1, None)
code, d = cal_poke({'action': 'done-event', 'id': t['id'] if t else 'none'})
a = settled(TASKID)
check('ticked in the calendar, the task is done by the calendar', a.get('status') == 'done' and a.get('note') == 'ticked in the calendar' and steps(a)[-1] == ('done', 'calendar'), (code, a.get('status'), a.get('note'), steps(a)))
last = exec_last(closed=1)
check('the record counts the close', last.get('closed') == 1, last)


def todo_by_id(eid):
    hits = [x for x in todos() if x.get('id') == eid]
    return hits[0] if hits else {}


def reopened(eid, was):
    #  the todo once it has moved to another action than `was`, or as it stands at the bound
    until(lambda: dictish(todo_by_id(eid).get('meta')).get('orrery') not in (None, '', was), 60)
    return todo_by_id(eid)


# unticked in the calendar (version 65): the ship never ticks it back. Done stays done; the todo is
# taken up afresh as a task of the owner's, and ticking it again closes that one
TID = t['id'] if t else 'none'
cal_poke({'action': 'done-event', 'id': TID, 'done': False})
tt = reopened(TID, TASKID)
REID = dictish(tt.get('meta')).get('orrery', '')
MADE.append(REID)
check('unticked after the owner\'s tick, the todo stays unticked and moves to a new task', tt.get('done') is False and REID not in ('', TASKID), tt)
ra = action(REID)
check('the new task is the owner\'s, approved, for that todo, and the old one stays done',
      ra.get('status') == 'approved' and ra.get('by') == 'calendar' and dictish(ra.get('payload')).get('todo') == TID
      and action(TASKID).get('status') == 'done', (ra, action(TASKID).get('status')))
before = exec_last()
curl('POST', API + '/exec/wake', {})
passed(before)
check('a later pass leaves it unticked, with one todo and no second task',
      todo_by_id(TID).get('done') is False and dictish(todo_by_id(TID).get('meta')).get('orrery') == REID
      and len([x for x in todos() if dictish(x.get('meta')).get('name') == 'Gate task %s' % XRUN]) == 1, todo_by_id(TID))
cal_poke({'action': 'done-event', 'id': TID})
a = settled(REID)
check('ticked again, the new task is done by the calendar', a.get('status') == 'done' and steps(a)[-1] == ('done', 'calendar'), (a.get('status'), steps(a)))
# a task the owner marks done on the page: section 6's task, ticked by the mirror, with the mark that
# says the ship ticked it for that action
t = todo_for(AID)
until(lambda: dictish(todo_for(AID, bound=1) or {}).get('done') is True, 30)
t = todo_for(AID)
check('the task done on the page has its todo ticked', t is not None and t.get('done') is True, t)
check('the ship\'s tick leaves its mark and keeps the due', dictish(dictish(t).get('meta')).get('ticked') == AID, t)
PTID = t['id'] if t else 'none'
cal_poke({'action': 'done-event', 'id': PTID, 'done': False})
pt = reopened(PTID, AID)
PREID = dictish(pt.get('meta')).get('orrery', '')
MADE.append(PREID)
check('unticked after the ship\'s tick, it stays unticked and is taken up, the mark gone',
      pt.get('done') is False and PREID not in ('', AID) and 'ticked' not in dictish(pt.get('meta')), pt)
check('the new task is about what the old one was about', action(PREID).get('status') == 'approved' and sorted(action(PREID).get('about') or []) == sorted(action(AID).get('about') or []),
      (action(PREID).get('about'), action(AID).get('about')))
before = exec_last()
curl('POST', API + '/exec/wake', {})
passed(before)
check('and a later pass does not tick it back', todo_by_id(PTID).get('done') is False, todo_by_id(PTID))
# a task dismissed on the page: its todo goes
DISID = propose('task', 'Gate dismissed task %s' % XRUN, payload={'notes': 'to be dismissed'})
MADE.append(DISID)
t = todo_for(DISID)
check('the second task is placed too', t is not None and t.get('done') is False, t)
curl('POST', API + f'/actions/{DISID}', {'status': 'dismissed', 'note': 'gate'})
t = todo_for(DISID, gone=True)
check('dismissed on the page, its todo is deleted', t is None, t)
last = exec_last(deleted=1)
check('the record counts the deletion', last.get('deleted') == 1, last)
# a todo the owner typed in the calendar is adopted as an approved task, and the todo gains the mark.
# The policy approves no task here, as on a ship whose owner approves each one: the owner's own todo
# is approved as it is filed all the same, so it is never seen standing as a proposal
curl('PUT', API + '/policy', {'auto': ['note'], 'push': 'proposed', 'retention_days': 365})
HAND_DUE = (now + timedelta(days=5)).replace(hour=12, minute=0, second=0)
code, d = cal_poke({'action': 'add-event', 'cat': 'todo', 'meta': {'name': 'Gate hand-typed todo %s' % XRUN, 'note': 'typed by hand'}, 'due_ms': int(HAND_DUE.timestamp() * 1000)})
check('a todo typed through the calendar is taken', code == 200, (code, d))
deadline = time.time() + 30
hand = []
while time.time() < deadline and not hand:
    time.sleep(2)
    hand = [a for a in (curl('GET', API + '/actions?status=open')[1] or []) if dictish(a).get('title') == 'Gate hand-typed todo %s' % XRUN]
a = hand[0] if hand else {}
HANDID = a.get('id', '')
MADE.append(HANDID)
check('it appears as an approved task filed by the calendar, with its note and due',
      a.get('kind') == 'task' and a.get('status') == 'approved' and a.get('by') == 'calendar' and a.get('due') == iso(HAND_DUE)
      and dictish(a.get('payload')).get('notes') == 'typed by hand' and steps(a) == [('proposed', 'calendar'), ('approved', 'calendar')], a)
curl('PUT', API + '/policy', {'auto': ['task', 'note'], 'push': 'proposed', 'retention_days': 365})
t = todo_for(HANDID)
check('the todo gains the action id and the tag, and keeps its name, note and due',
      t is not None and dictish(t.get('meta')) == {'name': 'Gate hand-typed todo %s' % XRUN, 'orrery': HANDID, 'tags': ['orrery'], 'note': 'typed by hand'} and t.get('due_ms') == int(HAND_DUE.timestamp() * 1000), t)
last = exec_last(adopted=1)
check('the record counts the adoption', last.get('adopted') == 1, last)
before = exec_last()
curl('POST', API + '/exec/wake', {})
passed(before)
check('a hand-typed todo is adopted once, not placed again', len([x for x in todos() if dictish(dictish(x.get('meta'))).get('name') == 'Gate hand-typed todo %s' % XRUN]) == 1, None)
curl('POST', API + f'/actions/{HANDID}', {'status': 'dismissed', 'note': 'gate'})
check('dismissing the adopted task deletes its todo', todo_for(HANDID, gone=True) is None, None)
# the owner's wake: the record's time moves within the second. The
# deletion's pass and the idle one that follows it are over in a few
# seconds, so the record read before the wake is the one the wake keeps
time.sleep(6)
before = exec_last()
code, d = curl('POST', API + '/exec/wake')
deadline = time.time() + 20
while time.time() < deadline and exec_last().get('at') == before.get('at'):
    time.sleep(1)
after = exec_last()
check('the owner wakes the executor and the record follows', code == 200 and dictish(d).get('ok') is True and after.get('at') != before.get('at'), (code, d, before.get('at'), after.get('at')))
check('an idle pass keeps the last active pass\'s counts and acted_at', after.get('acted_at') == before.get('acted_at') and after.get('deleted') == before.get('deleted'), (before, after))
# ---- corrections and instructions: a value struck as wrong goes from every source and stays out; the owner's words become actions ----
STRUCK = 'person/gate-struck'
PARIS, ROME, EMP = 'Gate Paris %s' % XRUN, 'Gate Rome %s' % XRUN, 'Gate Co %s' % XRUN
def live(attr):
    return [dictish(o).get('value') for o in dictish(curl('GET', API + '/body/' + STRUCK)[1]).get('observations') or [] if dictish(o).get('attr') == attr and dictish(o).get('status') == 'live']
now = datetime.now(timezone.utc)
observe([{'id': STRUCK, 'name': 'Gate Struck'}], [obs(STRUCK, 'city', PARIS, now - timedelta(minutes=2), src('struck-a')),
                                                  obs(STRUCK, 'city', PARIS, now - timedelta(minutes=1), src('struck-b'))])
until(lambda: live('city').count(PARIS) == 2)
code, d = curl('POST', API + '/correct', {'subject': STRUCK, 'attr': 'city', 'value': PARIS, 'why': 'never lived there'})
CID = dictish(d).get('id', '')
check('a value struck as wrong answers the correction, by the owner, with its id', code == 200 and bool(CID) and dictish(d).get('by') == 'owner', (code, d))
check('every row naming the value is retracted, from both sources', until(lambda: PARIS not in live('city')), live('city'))
code, cs = curl('GET', API + '/corrections')
check('the corrections list it first, with the reason', code == 200 and isinstance(cs, list) and cs and dictish(cs[0]).get('id') == CID and dictish(cs[0]).get('why') == 'never lived there', (code, cs[:1] if isinstance(cs, list) else cs))
#  the marker lands in the same batch, so its arrival says the writer took the batch
observe([], [obs(STRUCK, 'city', PARIS.upper(), now, src('struck-c')), obs(STRUCK, 'nickname', 'marker one', now, src('struck-c'))])
check('the writer refuses the value again, in any case, from any source', until(lambda: 'marker one' in live('nickname')) and PARIS.upper() not in live('city'), live('city'))
code, d = curl('POST', API + '/correct', {'subject': 'person/gate-nobody-' + XRUN, 'attr': 'city', 'value': 'x'})
check('a correction of an unknown body is 404', code == 404, (code, d))
code, d = curl('POST', API + '/correct', {'subject': STRUCK, 'attr': 'city'})
check('a correction without a value is 400', code == 400, (code, d))
code, rokey = curl('POST', API + '/clients', {'name': 'gate read key', 'by': 'gate-read', 'scope': {'kinds': ['person'], 'actions': ['note'], 'write': False, 'sensitive': 'none'}})
code, d = curl('POST', API + '/correct', {'subject': STRUCK, 'attr': 'city', 'value': 'x'}, jar=None, token=dictish(rokey).get('token'))
check('a read only key may not strike a value', code == 403, (code, d))
code, d = curl('POST', API + '/instruct', {'text': 'hello'}, jar=None, token=dictish(rokey).get('token'))
check('a read only key may not instruct', code == 403, (code, d))
if dictish(rokey).get('id'):
    curl('DELETE', API + '/clients/' + dictish(rokey)['id'])
owner_only('a key may not take a correction back', 'DELETE', '/corrections/' + CID)
code, d = curl('DELETE', API + '/corrections/' + CID)
check('the owner takes a correction back by its id', code == 200 and dictish(d).get('ok') is True, (code, d))
observe([], [obs(STRUCK, 'city', PARIS, now, src('struck-d'))])
check('taken back, the value may be written again', until(lambda: PARIS in live('city')), live('city'))
code, d = curl('DELETE', API + '/corrections/' + CID)
check('taking back an unknown correction is 404', code == 404, (code, d))
observe([], [obs(STRUCK, 'city', ROME, now + timedelta(seconds=1), src('struck-e'))])
until(lambda: ROME in live('city'))
INSTRUCT_CANNED = completion({'reply': 'Struck Rome and noted the job.', 'actions': [
    {'kind': 'correct', 'title': 'Gate Struck never lived in Rome', 'about': [STRUCK], 'payload': {'subject': STRUCK, 'attr': 'city', 'value': ROME, 'why': 'the owner said so'}},
    {'kind': 'fact', 'title': 'Gate Struck works at Gate Co', 'about': [STRUCK], 'payload': {'subject': STRUCK, 'attr': 'employer', 'value': EMP}},
    {'kind': 'launch', 'title': 'Launch something', 'about': [], 'payload': {}}]})
curl('PUT', API + '/generator', {'url': 'http://127.0.0.1:%d' % STUB_PORT, 'api_key': 'sk-stub', 'reasoning': {'enabled': False}})
code, d = curl('POST', API + '/instruct', {'text': ''})
check('an empty instruction is 400', code == 400, (code, d))
n_instruct = len(seen)
TOLD = 'she never lived in rome and she works at gate co'
code, d = curl('POST', API + '/instruct', {'text': TOLD, 'about': [STRUCK], 'apply': True}, timeout=180)
d = dictish(d)
IDS = [dictish(a).get('id') for a in d.get('actions') or []]
check('an instruction answers the reply, files the two kinds the ship knows and says why the third was dropped',
      code == 200 and d.get('ok') is True and d.get('reply') == 'Struck Rome and noted the job.'
      and sorted(dictish(a).get('kind') for a in d.get('actions') or []) == ['correct', 'fact'] and 'launch' in (d.get('note') or ''), (code, d))
asked = [b for p, h, b in seen[n_instruct:] if p.endswith('/chat/completions') and system_of(b).startswith('You carry out')]
user_text = json.dumps(asked[0].get('messages', [])[-1]) if asked else ''
check('the model was asked once, with the owner\'s words and the body in focus', len(asked) == 1 and TOLD in user_text and STRUCK in user_text, len(asked))
curl('POST', API + '/exec/wake', {})
check('with apply, the executor carries both out: Rome is struck and the job stands',
      until(lambda: ROME not in live('city') and EMP in live('employer'), 90), (live('city'), live('employer')))
check('both actions end done', until(lambda: IDS and all(action(i).get('status') == 'done' for i in IDS), 60), [action(i).get('status') for i in IDS])
check('the fact the owner stated is signed owner', any(dictish(o).get('value') == EMP and dictish(o).get('by') == 'owner' for o in dictish(curl('GET', API + '/body/' + STRUCK)[1]).get('observations') or []), None)
code, cs = curl('GET', API + '/corrections')
for c in cs if isinstance(cs, list) else []:
    if dictish(c).get('subject') == STRUCK:
        curl('DELETE', API + '/corrections/' + dictish(c)['id'])
curl('DELETE', API + '/body/' + STRUCK)

# a situation resolved (version 64): an approved resolve closes it with how it ended, the rows the
# owner's; what was only proposed about it is dismissed by the ship, what the owner approved stays
print('== a situation resolved')
RSIT = 'situation/gate-boiler-' + XRUN
OUT = 'fixed, the hot water is back ' + XRUN
observe([{'id': RSIT, 'name': 'Gate boiler ' + XRUN}], [obs(RSIT, 'status', 'open', now - timedelta(minutes=3), src('boiler-a')),
                                                         obs(RSIT, 'needs', 'a plumber comes and the hot water works', now - timedelta(minutes=3), src('boiler-b'))])
NAG = propose('message', 'Gate nudge the plumber ' + XRUN, about=[RSIT], payload={'via': 'telegram', 'to': 'person/gate-tg', 'text': 'any news on the plumber?'})
KEPT = propose('task', 'Gate pay the plumber ' + XRUN, about=[RSIT])
MADE.append(KEPT)
RES = propose('resolve', 'Gate boiler fixed ' + XRUN, about=[RSIT], payload={'situation': RSIT, 'outcome': OUT})
check('a resolve waits for the owner, as the reminder about its situation does',
      action(RES).get('status') == 'proposed' and action(NAG).get('status') == 'proposed' and action(KEPT).get('status') == 'approved',
      [action(i).get('status') for i in (RES, NAG, KEPT)])
approve(RES)
curl('POST', API + '/exec/wake', {})
check('approved, the executor closes the situation', until(lambda: action(RES).get('status') == 'done', 90), action(RES))
rb = dictish(curl('GET', API + '/body/' + RSIT)[1])
ra = dictish(rb.get('attrs'))
check('the situation is closed with how it ended, both rows the owner\'s',
      dictish(ra.get('status')).get('value') == 'closed' and dictish(ra.get('outcome')).get('value') == OUT
      and dictish(ra.get('status')).get('by') == 'owner' and dictish(ra.get('outcome')).get('by') == 'owner', ra)
nag = action(NAG)
check('the reminder that was only proposed is dismissed by the ship, with the outcome',
      until(lambda: action(NAG).get('status') == 'dismissed', 30) and action(NAG).get('note') == 'resolved: ' + OUT
      and steps(action(NAG))[-1] == ('dismissed', 'ship'), action(NAG))
check('the task the owner had approved stays', action(KEPT).get('status') == 'approved', action(KEPT))
code, d = curl('POST', API + '/reconcile', {})
rl = until(lambda: (lambda l: l if isinstance(l.get('resolved'), int) and l.get('resolved') >= 1 else None)(dictish(curl('GET', API + '/reconcile/last')[1])), 60)
check('reconcile counts it resolved, apart from what the clock closed', bool(rl) and isinstance(dictish(rl).get('presumed'), int), rl)
check('nothing was left to quiet: the executor had done it', dictish(rl).get('quieted') == 0, rl)
# a situation closed with no resolve (a reader's close, the clock's) loses what was only proposed about
# it at reconcile's pass, signed reconcile
CSIT = 'situation/gate-closed-' + XRUN
observe([{'id': CSIT, 'name': 'Gate closed ' + XRUN}], [obs(CSIT, 'status', 'open', now - timedelta(minutes=3), src('closed-a'))])
CNAG = propose('message', 'Gate ask about the closed one ' + XRUN, about=[CSIT], payload={'via': 'telegram', 'to': 'person/gate-tg', 'text': 'any news?'})
observe([], [obs(CSIT, 'status', 'closed', now, src('closed-b'))])
curl('POST', API + '/reconcile', {})
check('reconcile dismisses what was only proposed about a situation closed without a resolve',
      until(lambda: action(CNAG).get('status') == 'dismissed', 60) and action(CNAG).get('note') == 'closed' and steps(action(CNAG))[-1] == ('dismissed', 'reconcile'), action(CNAG))
curl('POST', API + '/actions/' + KEPT, {'status': 'dismissed', 'note': 'gate'})
curl('DELETE', API + '/body/' + RSIT)
curl('DELETE', API + '/body/' + CSIT)
# teardown: the events and the todos this run made, and the three people
for e in [EVENT_ID, ONCE_ID, REPEAT_ID]:
    if e:
        cal_poke({'action': 'del-event', 'id': e})
MADE = [m for m in MADE if m]
for t in todos():
    if dictish(t.get('meta')).get('orrery') in MADE:
        cal_poke({'action': 'del-event', 'id': t['id']})
time.sleep(2)
left = [t['id'] for t in todos() if dictish(t.get('meta')).get('orrery') in MADE]
check('no todo of this run\'s own tasks is left on the calendar', left == [], left)
for b in ['person/gate-tg', 'person/gate-ship', 'person/gate-nobody', 'person/gate-people', 'person/gate-shipped', 'person/gate-karl']:
    curl('DELETE', API + '/body/' + b)
curl('PUT', API + '/telegram', {'people': {'1001': 'person/me'}})
srv.shutdown()
srv.server_close()

# ---- a reload keeps the settings (version 97): the place lookups' key and the sharing trust survive a load ----
# a grub no on-load row declares is dropped at every load: until 97 that
# was search.json, search-last.json and sphere-trust.json, and ricsul's
# 87 to 96 update lost its owner's Brave key that way. Last in the gate,
# since the reload restarts every fiber.
RELOAD_APP = '/apps/shell.shell/desks/orrery.desk/desk/data/orrery.orrery_app'
RELOAD_FILES = ['search.json', 'search-last.json', 'sphere-trust.json', 'browsing.json', 'browsing-last.json']
def reload_raw(name):
    return gate.curl('GET', HOST + '/grubbery/ball' + RELOAD_APP + '/' + name + '?raw=1', jar=JAR)[1]
code, reload_before = curl('GET', API + '/search')
curl('PUT', API + '/search', {'api_key': 'reload-gate-key', 'enabled': dictish(reload_before).get('enabled') is True})
held_before = {n: reload_raw(n) for n in RELOAD_FILES}
code, d = curl('POST', HOST + '/apps/grubbery/permits/reload', {'app': RELOAD_APP})
check('the instance reloads', code == 200, (code, d))
gate.wait('orrery answers again after the reload', lambda: curl('GET', API + '/version')[0] == 200, 180)
code, reload_after = curl('GET', API + '/search')
check('a reload keeps the place lookups\' key and switch',
      dictish(reload_after).get('api_key_set') is True
      and dictish(reload_after).get('enabled') == (dictish(reload_before).get('enabled') is True), reload_after)
for n in RELOAD_FILES:
    if isinstance(held_before[n], dict):
        check('a reload keeps ' + n, reload_raw(n) == held_before[n], (held_before[n], reload_raw(n)))

print()
print('FAILED: ' + ', '.join(fails) if fails else 'ALL OK')
sys.exit(1 if fails else 0)
