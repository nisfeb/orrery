#!/usr/bin/env python3
"""api-matrix.py HOST JAR
The HTTP gate for orrery: spec section 8, the stranded car, against a
fake ship. HOST like http://localhost:8080; JAR a curl cookie jar from
POST /~/login. Exits 1 on any failure. Safe to rerun: it deletes,
retracts and dismisses what an earlier run left."""
import json, subprocess, sys, threading, time
from datetime import datetime, timedelta, timezone

HOST, JAR = sys.argv[1:3]
API = HOST + '/apps/orrery/api'
INSTANCE = HOST + '/grubbery/ball/apps/shell.shell/desks/orrery.desk/desk/data/orrery.orrery_app'
fails = []


def curl(method, url, body=None, jar=JAR, timeout=60):
    cmd = ['curl', '-s', '-m', str(timeout), '-X', method, '-w', '\n%{http_code}', url]
    if jar:
        cmd += ['-b', jar]
    if body is not None:
        cmd += ['-H', 'content-type: application/json', '-d', json.dumps(body)]
    out = subprocess.run(cmd, capture_output=True, text=True).stdout
    text, _, code = out.rpartition('\n')
    try:
        data = json.loads(text) if text else None
    except json.JSONDecodeError:
        data = text
    return int(code or 0), data


def check(label, cond, detail=''):
    print(('  ok   ' if cond else '  FAIL ') + label + ('' if cond else '   ' + str(detail)[:300]))
    if not cond:
        fails.append(label)


def iso(dt):
    return dt.replace(microsecond=0).strftime('%Y-%m-%dT%H:%M:%SZ')


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


def dictish(x):
    return x if isinstance(x, dict) else {}


def all_ok(d, key, n):
    items = dictish(d).get(key, [])
    return len(items) == n and all(x.get('ok') for x in items)


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
#  SIT is keyed on today's date, so a run on the other side of midnight
#  UTC would leave an earlier day's breakdown open for ever
code, st0 = curl('GET', API + '/state')
old_sits = [] if code != 200 else [str(dictish(b).get('id', '')) for b in dictish(st0).get('bodies', [])]
for b in old_sits:
    if b.startswith('situation/') and b.endswith('-breakdown'):
        curl('DELETE', API + '/body/' + b)
retract_matrix('person/sarah')
for b in ['person/sarah', 'thing/subaru', 'place/home', SHOP, ORG, SIT]:
    curl('DELETE', API + '/body/' + b)
code, me = body('person/me')
check('person/me exists', code == 200, (code, me))
curl('POST', API + '/bodies', {'id': 'person/me', 'ship': '~wex'})
retract_matrix('person/me')
code, acts = curl('GET', API + '/actions?status=open')
for a in (acts if isinstance(acts, list) else []):
    if a['title'] in (TITLE, MSG, RACE):
        curl('POST', API + f'/actions/{a["id"]}', {'status': 'dismissed', 'note': 'matrix rerun'})
curl('PUT', API + '/policy', {'auto': ['task', 'note'], 'push': 'proposed', 'retention_days': 365})

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
check('the API emits the ship on a body', code == 200 and dictish(me).get('ship') == '~wex', me)
s = state()
check('me.spouse is sarah, read back at once', val(s, 'person/me', 'spouse') == ref('person/sarah'), attrs(s, 'person/me'))
code, r = curl('GET', API + '/resolve?q=%7Ewex')
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
code, acts = curl('GET', API + '/actions')
check('the task is on the open list', code == 200 and isinstance(acts, list)
      and any(dictish(x).get('id') == AID for x in acts), acts)
mine = [x for x in acts if isinstance(x, dict) and x.get('id') == AID] if isinstance(acts, list) else []
check('the history shows proposed then approved by policy', bool(mine)
      and [(h.get('status'), h.get('by')) for h in mine[0].get('history', [])] == [('proposed', 'api-matrix'), ('approved', 'policy')], mine)
code, a2 = curl('POST', API + '/act', prop)
check('a second identical proposal answers the same id', code == 200 and a2['id'] == AID and a2['existing'], a2)
code, last = curl('GET', INSTANCE + '/tr/last?raw=1')
check('the writer noted the act', code == 200 and isinstance(last, dict) and last.get('op') == 'act' and last.get('ok') is True, last)
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
check('the audit log holds the push', code == 200 and isinstance(log, list)
      and any(dictish(x).get('op') == 'push' for x in log), log[-3:] if isinstance(log, list) else log)

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
check('the audit log ends with the set-action', code == 200 and isinstance(log, list) and bool(log)
      and log[-1].get('op') == 'set-action' and log[-1].get('by') == 'user', log[-3:] if isinstance(log, list) else log)
code, d = curl('POST', API + f'/actions/{AID}', {'status': 'approved'})
check('done is terminal', code == 409, (code, d))
curl('PUT', API + '/policy', {'auto': ['task', 'note'], 'push': 'proposed', 'retention_days': 0})
code, d = observe([], [obs('thing/subaru', 'plate', 'ABC 123', now - timedelta(minutes=1), USER)])
check('a write with retention 0 lands', code == 200 and all_ok(d, 'observations', 1), (code, d))
code, bs = body('thing/subaru')
statuses = {o['id']: o['status'] for o in bs.get('observations', [])} if code == 200 else {}
check('superseded observations were culled', code == 200 and 'superseded' not in statuses.values(), statuses)
check('live observations remain', code == 200 and bs['attrs']['location']['value'] == ref(SHOP) and bs['attrs']['plate']['value'] == 'ABC 123', bs.get('attrs') if code == 200 else bs)
curl('PUT', API + '/policy', {'auto': ['task', 'note'], 'push': 'proposed', 'retention_days': 365})

# ── 7. refusals ─────────────────────────────────────────────────────
print('7. refusals')
code, d = curl('GET', API + '/state', jar=None)
check('no cookie is 403', code == 403, (code, d))
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
code, last = curl('GET', INSTANCE + '/tr/last?raw=1')
check('the writer noted the merge last',
      code == 200 and dictish(last).get('op') == 'merge' and dictish(last).get('ok') is True, last)

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
code, d = curl('GET', API + '/generator', jar=None)
check('the settings are the owner\'s', code == 403, (code, d))
code, d = curl('GET', API + '/generator/last')
check('the last pass reads as an object', code == 200 and isinstance(d, dict), (code, d))

# ---- the on-ship generator: a pass against a stub model ----
import http.server, socketserver
STUB_PORT = 8099
# a title unlike any earlier run's, since a dismissed one stays decided
# for ever and the validator drops a rewording of it
import secrets
FRESH = 'Errand %s %s %s' % (secrets.token_hex(3), secrets.token_hex(3), secrets.token_hex(3))
CANNED = {'choices': [{'message': {'content': json.dumps({'actions': [
    {'kind': 'task', 'title': FRESH, 'about': ['thing/gate-car'], 'why': 'gate'},
    {'kind': 'task', 'title': 'Open item for the gate car', 'about': ['thing/gate-car']},
    {'kind': 'task', 'title': 'Buy a new car', 'about': ['thing/tesla']}], 'notes': ['stub note']})}}],
    'usage': {'prompt_tokens': 10, 'completion_tokens': 5, 'cost': 0.0001}}
seen = []
class Stub(http.server.BaseHTTPRequestHandler):
    def do_POST(self):
        n = int(self.headers.get('content-length', 0))
        seen.append(({k.lower(): v for k, v in self.headers.items()}, json.loads(self.rfile.read(n))))
        out = json.dumps(CANNED).encode()
        self.send_response(200); self.send_header('content-type', 'application/json'); self.send_header('content-length', str(len(out))); self.end_headers(); self.wfile.write(out)
    def log_message(self, *a): pass
socketserver.TCPServer.allow_reuse_address = True
srv = socketserver.TCPServer(('127.0.0.1', STUB_PORT), Stub)
threading.Thread(target=srv.serve_forever, daemon=True).start()
# a body and an open action of the section's own, deleted and dismissed at the end,
# so nothing here outlives the run for the other gates to trip over
curl('POST', API + '/observe', {'bodies': [{'id': 'thing/gate-car', 'name': 'the gate car'}], 'observations': []})
code, twin = curl('POST', API + '/act', {'kind': 'task', 'title': 'Open item for the gate car', 'about': ['thing/gate-car']})
time.sleep(1)
curl('PUT', API + '/generator', {'enabled': True, 'url': 'http://127.0.0.1:%d' % STUB_PORT, 'model': 'moonshotai/kimi-k3', 'api_key': 'sk-stub', 'reasoning': {'enabled': False}, 'max_actions': 5})
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
    if isinstance(last, dict) and last.get('at') and last.get('at') != before_at and not last.get('skipped'):
        break
    time.sleep(2)
check('the pass wrote its record', isinstance(last, dict) and last.get('filed') == 1 and last.get('dropped') == 2 and 'stub note' in ' '.join(last.get('notes', [])) and not last.get('error'), last)
hdrs, body = seen[0] if seen else ({}, {})
check('the stub saw the prompt with cache marks and no temperature', body.get('model') == 'moonshotai/kimi-k3' and 'temperature' in body and body['messages'][1]['content'][0].get('cache_control') and body.get('provider') == {'zdr': True}, body.keys() if body else 'no request')
check('the key went in the header, not the body', hdrs.get('authorization') == 'Bearer sk-stub' and 'sk-stub' not in json.dumps(body), hdrs.get('authorization'))
code, acts = curl('GET', API + '/actions?status=open')
mine = [a for a in acts if a.get('by') == 'generator' and a.get('title') == FRESH] if isinstance(acts, list) else []
check('the surviving proposal is filed by generator with its why', len(mine) == 1 and mine[0]['payload'].get('why') == 'gate', mine)
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
time.sleep(30)
check('a repeat that changes nothing the model sees does not run it', len(seen) == n, (n, len(seen)))
for a in mine:
    curl('POST', API + '/actions/' + a['id'], {'status': 'dismissed', 'by': 'gate'})
if isinstance(twin, dict) and twin.get('id'):
    curl('POST', API + '/actions/' + twin['id'], {'status': 'dismissed', 'by': 'gate'})
curl('PUT', API + '/generator', {'enabled': False, 'api_key': None})
time.sleep(1)
curl('DELETE', API + '/body/thing/gate-car')
srv.shutdown()

print()
print('FAILED: ' + ', '.join(fails) if fails else 'ALL OK')
sys.exit(1 if fails else 0)
