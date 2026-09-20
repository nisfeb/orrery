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


def curl(method, url, body=None, jar=JAR, timeout=60, token=None):
    cmd = ['curl', '-s', '-m', str(timeout), '-X', method, '-w', '\n%{http_code}', url]
    if token:
        cmd += ['-H', 'Authorization: Bearer ' + token]
    elif jar:
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
class Stub(http.server.BaseHTTPRequestHandler):
    #  one stub for the model, the decider and Telegram, told apart by path:
    #  the analyst's chat request by its system block (the analyst prompt's
    #  first words), the generator's answered with CANNED
    def answer(self, body):
        seen.append((self.path, {k.lower(): v for k, v in self.headers.items()}, body))
        status = 200
        if self.path.endswith('/setWebhook'):
            out = {'ok': True, 'result': True, 'description': 'Webhook was set'}
        elif self.path.startswith('/bot123:abc/'):
            out = {'ok': True, 'result': {'user': {'id': 1001}}}
        elif self.path.endswith('/decisions'):
            out = DECIDER_CANNED
        else:
            system = ((body.get('messages') or [{}])[0].get('content') or [{}])[0].get('text', '')
            if system.startswith('You turn') and DOWN:
                out, status = {'error': {'message': 'the stub is down'}}, 503
            else:
                out = TG_CANNED if system.startswith('You turn') else CANNED
        out = json.dumps(out).encode()
        self.send_response(status); self.send_header('content-type', 'application/json'); self.send_header('content-length', str(len(out))); self.end_headers(); self.wfile.write(out)
    def do_POST(self):
        n = int(self.headers.get('content-length', 0))
        self.answer(json.loads(self.rfile.read(n)))
    def do_GET(self):
        self.answer({})
    def log_message(self, *a): pass
socketserver.TCPServer.allow_reuse_address = True
srv = socketserver.TCPServer(('127.0.0.1', STUB_PORT), Stub)
threading.Thread(target=srv.serve_forever, daemon=True).start()
# a body and an open action of the section's own, deleted and dismissed at the end,
# so nothing here outlives the run for the other gates to trip over
curl('POST', API + '/observe', {'bodies': [{'id': 'thing/gate-car', 'name': 'the gate car'}], 'observations': []})
code, twin = curl('POST', API + '/act', {'kind': 'task', 'title': 'Open item for the gate car', 'about': ['thing/gate-car']})
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
check('the pass wrote its record, two filed', isinstance(last, dict) and last.get('filed') == 2 and last.get('dropped') == 2 and 'stub note' in ' '.join(last.get('notes', [])) and not last.get('error') and last.get('calls_today') >= 1, last)
_, hdrs, body = seen[0] if seen else ('', {}, {})
check('the stub saw the prompt with cache marks and no temperature', body.get('model') == 'moonshotai/kimi-k3' and 'temperature' in body and body['messages'][1]['content'][0].get('cache_control') and body.get('provider') == {'zdr': True}, body.keys() if body else 'no request')
check('the key went in the header, not the body', hdrs.get('authorization') == 'Bearer sk-stub' and 'sk-stub' not in json.dumps(body), hdrs.get('authorization'))
code, acts = curl('GET', API + '/actions?status=open')
mine = [a for a in acts if a.get('by') == 'generator' and a.get('title') in (FRESH, FRESH2)] if isinstance(acts, list) else []
check('both surviving proposals are filed by generator with their why', len(mine) == 2 and sorted(a['payload'].get('why') for a in mine) == ['gate', 'gate too'], mine)
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
time.sleep(30)
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
prompt_seen = json.dumps(seen[-1][2]) if len(seen) == n + 1 else ''
check('the model saw the urgent line before the clock', 'Urgent:' in prompt_seen and prompt_seen.index('Urgent:') > prompt_seen.index('Recent decisions'), (len(seen), n))
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
    cmd = ['curl', '-s', '-m', '30', '-X', 'POST', '-w', '\n%{http_code}', HOOK, '-H', 'content-type: application/json', '-d', json.dumps(body)]
    if secret is not None:
        cmd += ['-H', 'x-telegram-bot-api-secret-token: ' + secret]
    out = subprocess.run(cmd, capture_output=True, text=True).stdout
    text, _, code = out.rpartition('\n')
    if full:
        try:
            return int(code or 0), json.loads(text)
        except ValueError:
            return int(code or 0), text
    return int(code or 0)
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
check('a chat not in chats is ignored', hook(update(U0 + 4, MID + 3, 'hello', chat=9)) == 200 and dictish(tg_last(U0 + 4)).get('outcome') == 'ignored', None)
check('a command writes without the model', hook(update(U0 + 5, MID + 4, '/at the gate shop')) == 200 and dictish(dictish(dictish(curl('GET', API + '/body/person/me')[1]).get('attrs')).get('location')).get('value') == 'the gate shop', None)
read_after = dictish(tg_last(U0 + 5)).get('read_today')
check('commands and questions do not count against the day', read_before is not None and read_after == read_before, (read_before, read_after))
hook(update(U0 + 6, MID + 5, 'still on route 9', business='conn-1'))
check('a business message from a connection the stub owns is read', dictish(tg_last(U0 + 6)).get('outcome') in ('facts', 'nothing'), tg_last(U0 + 6))
check('the stub was asked the gate, the analyst, the status and the escalate questions', [p for p, _, _ in seen if 'decisions' in p] and any(p.endswith('/chat/completions') for p, _, _ in seen), [p for p, _, _ in seen][-8:])
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
check('the woken reader handled the kept update and culled it', woken.get('update_id') == U0 + 7 and woken.get('outcome') in ('facts', 'nothing') and '%012d' % (U0 + 7) not in inbox(), (woken, inbox()))
code, d = curl('POST', API + '/telegram/webhook')
check('the ship registers its webhook with telegram', code == 200 and dictish(d).get('ok') is True, (code, d))
sw = [b for p, _, b in seen if p.endswith('/setWebhook')]
check('setWebhook carried the public url, the secret, the update kinds and one connection', sw and sw[-1].get('url') == 'http://localhost:8080/apps/orrery/telegram' and sw[-1].get('secret_token') == 'hook-secret-abcdef' and sw[-1].get('allowed_updates') == ['message', 'business_message'] and sw[-1].get('max_connections') == 1, sw[-1:])
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
srv.shutdown()

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
    time.sleep(2)
    d, last = reconcile_now()
    s = state()
    ids = {b['id'] for b in s['bodies']}
    code, acts = curl('GET', API + '/actions?status=all')
    mine = [a for a in acts if a.get('id') == merges[0]['id']]
    check('the approved merge ran: the org is gone, its phone is on the person, the action is done', ORG not in ids and dictish(dictish(attrs(s, DANA)).get('phone')).get('value') == '555-0100' and mine and mine[0]['status'] == 'done', (ORG in ids, attrs(s, DANA), mine))
    check('the record counts the merge', dictish(last).get('merged') == 1, last)
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
check('a short secret is refused', code == 400, (code, d))

print()
print('FAILED: ' + ', '.join(fails) if fails else 'ALL OK')
sys.exit(1 if fails else 0)
