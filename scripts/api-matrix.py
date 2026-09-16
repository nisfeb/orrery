#!/usr/bin/env python3
"""api-matrix.py HOST JAR
The HTTP gate for orrery: spec section 8, the stranded car, against a
fake ship. HOST like http://localhost:8080; JAR a curl cookie jar from
POST /~/login. Exits 1 on any failure. Safe to rerun: it deletes,
retracts and dismisses what an earlier run left."""
import json, subprocess, sys
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
TITLE = "Call John's Machine Shop about the Subaru"
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


# ── 0. a clean slate ────────────────────────────────────────────────
print('0. clean slate')
for b in ['person/sarah', 'thing/subaru', 'place/home', SHOP, SIT]:
    curl('DELETE', API + '/body/' + b)
code, me = body('person/me')
check('person/me exists', code == 200, (code, me))
for o in dictish(me).get('observations', []):
    if o['source']['id'].startswith('matrix-') and o['status'] != 'retracted':
        curl('POST', API + '/retract', {'id': o['id'], 'note': 'matrix rerun'})
code, acts = curl('GET', API + '/actions?status=open')
for a in (acts if isinstance(acts, list) else []):
    if a['title'] == TITLE:
        curl('POST', API + f'/actions/{a["id"]}', {'status': 'dismissed', 'note': 'matrix rerun'})
curl('PUT', API + '/policy', {'auto': ['task', 'note'], 'push': True, 'retention_days': 365})

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
s = state()
check('me.spouse is sarah, read back at once', val(s, 'person/me', 'spouse') == ref('person/sarah'), attrs(s, 'person/me'))
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
check('resolve finds the shop by alias', code == 200 and [x['id'] for x in r] == [SHOP], r)

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
check('the task is on the open list', code == 200 and any(x['id'] == AID for x in acts), acts)
code, a2 = curl('POST', API + '/act', prop)
check('a second identical proposal answers the same id', code == 200 and a2['id'] == AID and a2['existing'], a2)
code, last = curl('GET', INSTANCE + '/tr/last?raw=1')
check('the writer noted the act', code == 200 and isinstance(last, dict) and last.get('op') == 'act' and last.get('ok') is True, last)
code, bs = body('thing/subaru')
check('the subaru view lists the open task', code == 200 and any(x['id'] == AID for x in bs['actions']), bs.get('actions') if code == 200 else bs)

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
check('it left the open list', code == 200 and not any(x['id'] == AID for x in acts), acts)
code, d = curl('POST', API + f'/actions/{AID}', {'status': 'approved'})
check('done is terminal', code == 409, (code, d))
curl('PUT', API + '/policy', {'auto': ['task', 'note'], 'push': True, 'retention_days': 0})
code, d = observe([], [obs('thing/subaru', 'plate', 'ABC 123', now - timedelta(minutes=1), USER)])
check('a write with retention 0 lands', code == 200 and all_ok(d, 'observations', 1), (code, d))
code, bs = body('thing/subaru')
statuses = {o['id']: o['status'] for o in bs.get('observations', [])} if code == 200 else {}
check('superseded observations were culled', code == 200 and 'superseded' not in statuses.values(), statuses)
check('live observations remain', code == 200 and bs['attrs']['location']['value'] == ref(SHOP) and bs['attrs']['plate']['value'] == 'ABC 123', bs.get('attrs') if code == 200 else bs)
curl('PUT', API + '/policy', {'auto': ['task', 'note'], 'push': True, 'retention_days': 365})

# ── 7. refusals ─────────────────────────────────────────────────────
print('7. refusals')
code, d = curl('GET', API + '/state', jar=None)
check('no cookie is 403', code == 403, (code, d))
code, d = observe([{'id': f'place/p{i}'} for i in range(51)], [])
check('51 bodies is 400 naming bodies', code == 400 and dictish(d).get('error') == 'bodies: over 50', (code, d))
code, d = observe([], [obs('thing/subaru', 'plate', 'x', now - timedelta(minutes=1), USER)] * 201)
check('201 observations is 400 naming observations', code == 400 and dictish(d).get('error') == 'observations: over 200', (code, d))
code, d = observe([], [{'subject': 'thing/subaru', 'attr': 'status', 'value': 'x', 'at': 'yesterday', 'source': USER}])
check('a bad at is refused per item', code == 200 and not d['observations'][0]['ok'] and d['observations'][0]['error'].startswith('at:'), d)
code, d = curl('GET', API + '/state?at=yesterday')
check('a bad ?at is 400', code == 400, (code, d))
code, d = curl('POST', API + '/act', {'kind': 'task', 'title': 'x', 'about': ['thing/nothing']})
check('an unknown about body is 400', code == 400 and str(d.get('error', '')).startswith('about: no such body'), (code, d))
code, d = curl('GET', API + '/nothing')
check('an unknown route is 404', code == 404, (code, d))

print()
print('FAILED: ' + ', '.join(fails) if fails else 'ALL OK')
sys.exit(1 if fails else 0)
