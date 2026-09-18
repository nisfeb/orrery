#!/usr/bin/env python3
"""key-matrix.py HOST JAR
The key gate for orrery (spec section 11, phase 3) against a fake ship.
The owner (JAR, from POST /~/login) marks health sensitive, mints a
triage key, a key that writes the sensitive attributes, a todo key, a
narrow key and two read-only keys, and the keys then see and write
exactly their scope and read nothing sensitive.
Exits 1 on any failure. Safe to rerun: it revokes what it minted,
retracts what it observed, deletes the bodies it made and restores the
starter policy and the schema it found."""
import json, subprocess, sys, time
from datetime import datetime, timedelta, timezone

HOST, JAR = sys.argv[1:3]
API = HOST + '/apps/orrery/api'
STARTER = {'auto': ['task', 'note'], 'push': 'proposed', 'retention_days': 365}
STARTER_SCHEMA = [None]
fails = []
count = [0]


def curl(method, path, body=None, jar=None, token=None, timeout=60):
    cmd = ['curl', '-s', '-m', str(timeout), '-X', method, '-w', '\n%{http_code}', API + path]
    if jar:
        cmd += ['-b', jar]
    if token:
        cmd += ['-H', 'Authorization: Bearer ' + token]
    if body is not None:
        cmd += ['-H', 'content-type: application/json', '-d', json.dumps(body)]
    out = subprocess.run(cmd, capture_output=True, text=True).stdout
    text, _, code = out.rpartition('\n')
    try:
        data = json.loads(text) if text else None
    except json.JSONDecodeError:
        data = text
    return int(code or 0), data


def owner(method, path, body=None):
    return curl(method, path, body, jar=JAR)


def as_key(token):
    return lambda method, path, body=None: curl(method, path, body, token=token)


def check(label, cond, detail=''):
    count[0] += 1
    print(('  ok   ' if cond else '  FAIL ') + label + ('' if cond else '   ' + str(detail)[:300]))
    if not cond:
        fails.append(label)


def dictish(x):
    return x if isinstance(x, dict) else {}


def listish(x):
    return x if isinstance(x, list) else []


def iso(dt):
    return dt.replace(microsecond=0).strftime('%Y-%m-%dT%H:%M:%SZ')


def obs(subject, attr, value, at, sid):
    """every payload lies about by, so a forced by is visible"""
    return {'subject': subject, 'attr': attr, 'value': value, 'at': iso(at),
            'source': {'kind': 'matrix', 'id': sid}, 'by': 'liar'}


def attrs_of(side, bid):
    """(code, the attrs map) with the map None when the read failed"""
    code, d = side('GET', '/body/' + bid)
    return code, (dictish(dictish(d).get('attrs')) if code == 200 else None)


def state_ids(side):
    code, d = side('GET', '/state')
    if code != 200:
        return None
    return {b.get('id'): b for b in listish(dictish(d).get('bodies')) if isinstance(b, dict)}


def all_ok(d, key, n):
    items = listish(dictish(d).get(key))
    return len(items) == n and all(dictish(r).get('ok') is True for r in items)


def retract_all(bid, names):
    code, a = attrs_of(owner, bid)
    for n in names:
        row = dictish(dictish(a).get(n))
        if row.get('obs'):
            owner('POST', '/retract', {'id': row['obs'], 'note': 'key gate'})


def clean():
    code, d = owner('GET', '/clients')
    for c in listish(d):
        if isinstance(c, dict) and str(c.get('name', '')).startswith('key-gate '):
            owner('DELETE', '/clients/' + str(c.get('id')))
    retract_all('person/me', ('health', 'status', 'mood', 'spouse', 'home'))
    retract_all('person/me', ('health',))  # a full run leaves two live: the owner's and the writing key's
    retract_all('thing/subaru', ('status',))
    owner('PUT', '/policy', STARTER)
    if STARTER_SCHEMA[0] is not None:
        owner('PUT', '/schema', STARTER_SCHEMA[0])
    for a in listish(owner('GET', '/actions?status=open')[1]):
        if isinstance(a, dict) and str(a.get('title', '')).startswith('key gate'):
            owner('POST', '/actions/' + str(a.get('id')), {'status': 'dismissed', 'note': 'key gate'})
    owner('DELETE', '/body/place/lake-house')
    owner('DELETE', '/body/situation/key-gate')


T0 = datetime.now(timezone.utc) - timedelta(hours=1)
T1 = T0 + timedelta(minutes=30)  # later than T0, so the key's row wins over the owner's
print('== setup')
clean()
code, d = owner('POST', '/bodies', {'id': 'thing/subaru', 'name': 'the Subaru'})
check('owner reaches thing/subaru', code == 200, d)
code, d = owner('PUT', '/policy', dict(STARTER, sensitive=['health']))
check('policy marks health sensitive', code == 200, d)
code, d = owner('GET', '/schema')
check('the owner reads the schema', code == 200 and isinstance(dictish(d).get('kinds'), dict), d)
base = json.loads(json.dumps(d)) if code == 200 else {'kinds': {}}
STARTER_SCHEMA[0] = json.loads(json.dumps(base))  # the schema as found
base_person = dictish(dictish(base.get('kinds')).get('person'))
base_person['attrs'] = [a for a in listish(base_person.get('attrs')) if a != 'health']
run_schema = json.loads(json.dumps(base))
dictish(dictish(run_schema.get('kinds')).get('person'))['attrs'] = base_person['attrs'] + ['health']
code, d = owner('PUT', '/schema', run_schema)
check('the schema names health among the person attributes', code == 200, d)
code, d = owner('POST', '/observe', {'bodies': [], 'observations': [
    obs('person/me', 'health', 'flu', T0, 'kg-1'), obs('person/me', 'status', 'working from bed', T0, 'kg-2')]})
check('owner observes health and status', code == 200 and all_ok(d, 'observations', 2), d)

print('== minting')
code, d = owner('POST', '/clients', {'name': 'key-gate triage', 'by': 'talon',
                                     'scope': {'kinds': ['person', 'thing', 'place', 'situation'], 'actions': [], 'write': True}})
check('mint the triage key', code == 200 and '.' in str(dictish(d).get('token', '')), d)
triage_id, triage_tok = dictish(d).get('id'), str(dictish(d).get('token', ''))
triage = as_key(triage_tok)
code, d = owner('POST', '/clients', {'name': 'key-gate todo', 'by': 'todo-app',
                                     'scope': {'kinds': [], 'actions': ['task'], 'write': True}})
check('mint the todo key', code == 200 and '.' in str(dictish(d).get('token', '')), d)
todo_id, todo_tok = dictish(d).get('id'), str(dictish(d).get('token', ''))
todo = as_key(todo_tok)
code, d = owner('POST', '/clients', {'name': 'key-gate reader', 'by': 'reader',
                                     'scope': {'kinds': ['person'], 'actions': [], 'write': False}})
check('mint the read-only key', code == 200 and '.' in str(dictish(d).get('token', '')), d)
reader_id, reader_tok = dictish(d).get('id'), str(dictish(d).get('token', ''))
reader = as_key(reader_tok)
code, d = owner('GET', '/clients')
rows = {c.get('id'): c for c in listish(d) if isinstance(c, dict)}
check('the owner lists the keys without secrets', code == 200 and triage_id in rows
      and not any(k in rows[triage_id] for k in ('hash', 'salt', 'token')), d)
check('a fresh key has no last use', triage_id in rows and rows[triage_id].get('used') is None, rows.get(triage_id))
code, d = owner('POST', '/clients', {'name': 'key-gate bad', 'by': 'x', 'scope': {'kinds': ['Nope']}})
check('a bad scope is 400', code == 400, d)
code, d = owner('POST', '/clients', {'name': '', 'by': 'x', 'scope': {}})
check('a missing name is 400', code == 400, d)

print('== the triage key sees its kinds and never the sensitive attribute')
ids = state_ids(triage)
check('the triage key reads the state', ids is not None and 'person/me' in ids, ids)
me = dictish(dictish(ids).get('person/me'))
check('the state hides health and shows status', 'health' not in dictish(me.get('attrs'))
      and dictish(dictish(me.get('attrs')).get('status')).get('value') == 'working from bed', me)
code, a = attrs_of(triage, 'person/me')
check('the body view hides health', code == 200 and a is not None and 'health' not in a and 'status' in a, a)
code, d = triage('GET', '/body/person/me')
tl = [o.get('attr') for o in listish(dictish(d).get('observations')) if isinstance(o, dict)]
check('the timeline hides health', code == 200 and 'health' not in tl and 'status' in tl, tl)
code, a = attrs_of(owner, 'person/me')
check('the owner still sees health', code == 200 and a is not None and 'health' in a, a)
code, d = triage('GET', '/resolve?q=subaru')
check('resolve answers a body in scope', code == 200 and any(dictish(r).get('id') == 'thing/subaru' for r in listish(d)), d)
ids = state_ids(todo)
check('the todo key sees no bodies', ids is not None and ids == {}, ids)
code, d = todo('GET', '/body/person/me')
check('a body outside the scope is 404 for the todo key', code == 404, d)
code, d = todo('GET', '/resolve?q=subaru')
check('resolve answers nothing to the todo key', code == 200 and d == [], d)

print('== writes carry the key identity and stay in scope')
code, d = triage('POST', '/observe', {'bodies': [], 'observations': [obs('thing/subaru', 'status', 'in the shop', T0, 'kg-3')]})
check('the triage key observes in scope', code == 200 and all_ok(d, 'observations', 1), d)
code, a = attrs_of(owner, 'thing/subaru')
check('by is the key identity, not the payload', dictish(dictish(a).get('status')).get('by') == 'talon', a)
code, d = triage('POST', '/observe', {'bodies': [], 'observations': [obs('person/me', 'health', 'better', T0, 'kg-4')]})
check('a sensitive attribute is 403 for a key', code == 403, d)
forged = dict(obs('person/me', 'mood', 'forged', T0, 'kg-15'), source={'kind': 'ship', 'id': '~zod/x'})
code, d = owner('POST', '/observe', {'bodies': [], 'observations': [forged]})
o = listish(dictish(d).get('observations'))
check('a ship source is refused per item', code == 200 and len(o) == 1 and dictish(o[0]).get('ok') is False
      and dictish(o[0]).get('error') == 'source.kind: reserved for the inbox', d)
code, a = attrs_of(owner, 'person/me')
check('the forged ship claim was not written', dictish(dictish(a).get('mood')).get('value') != 'forged', a)
code, d = triage('POST', '/observe', {'bodies': [{'id': 'org/acme', 'name': 'Acme'}], 'observations': []})
check('a body outside the kinds is 403', code == 403, d)
code, d = triage('POST', '/observe', {'bodies': [], 'observations': [obs('org/acme', 'status', 'x', T0, 'kg-5')]})
check('a subject outside the kinds is 403', code == 403, d)
code, d = triage('POST', '/observe', {'bodies': [], 'observations': [
    obs('person/me', 'status', 'mixed batch', T0, 'kg-10'), obs('org/acme', 'status', 'x', T0, 'kg-11')]})
check('a mixed batch is 403', code == 403, d)
code, a = attrs_of(owner, 'person/me')
check('the in-scope half of a refused batch was not written',
      code == 200 and dictish(dictish(a).get('status')).get('value') == 'working from bed', a)
code, d = triage('POST', '/bodies', {'id': 'person/sam', 'name': 'Sam', 'ship': '~zod'})
check('a key may not set a body ship', code == 403 and dictish(d).get('error') == 'not in scope: ship', (code, d))
code, d = triage('POST', '/observe', {'bodies': [{'id': 'person/sam', 'name': 'Sam', 'ship': '~zod'}], 'observations': []})
check('a key may not set a ship in an observe batch',
      code == 403 and dictish(d).get('error') == 'not in scope: ship', (code, d))
code, d = triage('POST', '/bodies', {'id': 'place/lake-house', 'name': 'the lake house'})
check('the triage key creates a body in scope', code == 200, d)
code, d = triage('POST', '/bodies', {'id': 'org/acme', 'name': 'Acme'})
check('a body outside the kinds is 403 on bodies too', code == 403, d)
code, d = reader('POST', '/observe', {'bodies': [], 'observations': [obs('person/me', 'mood', 'fine', T0, 'kg-6')]})
check('a read-only key cannot observe', code == 403, d)
code, a = attrs_of(reader, 'person/me')
check('the read-only key still reads its kinds', code == 200 and a is not None and 'status' in a and 'health' not in a, a)
code, d = owner('POST', '/observe', {'bodies': [], 'observations': [
    obs('person/me', 'spouse', {'ref': 'person/sarah'}, T0, 'kg-8'), obs('person/me', 'home', {'ref': 'place/home'}, T0, 'kg-9')]})
check('owner observes two refs', code == 200 and all_ok(d, 'observations', 2), d)
code, a = attrs_of(reader, 'person/me')
check('a ref inside the kinds shows and one outside does not', code == 200 and a is not None and 'spouse' in a and 'home' not in a, a)
code, d = reader('GET', '/body/person/me')
tl = [o.get('attr') for o in listish(dictish(d).get('observations')) if isinstance(o, dict)]
home_rows = [o for o in listish(dictish(d).get('observations')) if isinstance(o, dict) and o.get('attr') == 'home']
check('the timeline veils the outside ref as a cleared value', code == 200 and 'spouse' in tl and home_rows and all(o.get('value') is None for o in home_rows), home_rows)
code, d = triage('POST', '/observe', {'bodies': [], 'observations': [obs('person/me', 'mood', 'fine', T0, 'kg-7')]})
check('the triage key observes mood', code == 200 and all_ok(d, 'observations', 1), d)
code, a = attrs_of(owner, 'person/me')
mood_obs = str(dictish(dictish(a).get('mood')).get('obs', ''))
health_obs = str(dictish(dictish(a).get('health')).get('obs', ''))
check('the owner sees both rows to retract', bool(mood_obs) and bool(health_obs), a)
code, d = reader('POST', '/retract', {'id': mood_obs, 'note': 'key gate'})
check('a read-only key cannot retract', code == 403, d)
code, d = todo('POST', '/retract', {'id': mood_obs, 'note': 'key gate'})
check('a retract outside the kinds reads as no such observation', code == 404, d)
code, d = triage('POST', '/retract', {'id': health_obs, 'note': 'key gate'})
check('a sensitive observation reads as no such observation', code == 404, d)
code, d = triage('POST', '/retract', {'id': mood_obs, 'note': 'key gate'})
check('the triage key retracts its own observation', code == 200, d)

print('== a key that writes what it can never read')
code, d = owner('POST', '/clients', {'name': 'key-gate writer', 'by': 'writer',
                                     'scope': {'kinds': ['person', 'thing', 'place', 'situation'], 'actions': [],
                                               'write': True, 'sensitive': 'write'}})
check('mint a key that may write the sensitive attributes', code == 200 and '.' in str(dictish(d).get('token', '')), d)
writer_id = dictish(d).get('id')
writer = as_key(str(dictish(d).get('token', '')))
code, d = owner('POST', '/clients', {'name': 'key-gate no-write', 'by': 'x',
                                     'scope': {'kinds': ['person'], 'actions': [], 'write': False, 'sensitive': 'write'}})
check('a sensitive write without write is 400',
      code == 400 and dictish(d).get('error') == 'sensitive: write needs write', (code, d))
code, d = owner('GET', '/clients')
rows = {c.get('id'): c for c in listish(d) if isinstance(c, dict)}
check('the owner lists the field, write for the one key and none for the other',
      code == 200 and dictish(dictish(rows.get(writer_id)).get('scope')).get('sensitive') == 'write'
      and dictish(dictish(rows.get(triage_id)).get('scope')).get('sensitive') == 'none', rows.get(writer_id))
code, d = writer('POST', '/observe', {'bodies': [], 'observations': [obs('person/me', 'health', 'better', T1, 'kg-16')]})
first = dictish((listish(dictish(d).get('observations')) or [{}])[0])
check('the writing key observes a sensitive attribute', code == 200 and first.get('ok') is True, d)
check('the answer on a sensitive row has an id and no existing', bool(first.get('id')) and 'existing' not in first, first)
time.sleep(1)
code, d = writer('GET', '/state')
me = dictish({b.get('id'): b for b in listish(dictish(d).get('bodies')) if isinstance(b, dict)}.get('person/me'))
check('the state still hides health from the key that wrote it', code == 200 and 'health' not in dictish(me.get('attrs'))
      and 'status' in dictish(me.get('attrs')), me)
wsch = listish(dictish(dictish(dictish(dictish(d).get('schema')).get('kinds')).get('person')).get('attrs'))
check('the state schema names health, so the key knows it may write it', 'health' in wsch, wsch)
code, d = triage('GET', '/state')
tsch = listish(dictish(dictish(dictish(dictish(d).get('schema')).get('kinds')).get('person')).get('attrs'))
check('the state schema still drops health for a key without the field', code == 200 and 'health' not in tsch, tsch)
code, a = attrs_of(writer, 'person/me')
check('the body view still hides health', code == 200 and a is not None and 'health' not in a and 'status' in a, a)
code, d = writer('GET', '/body/person/me')
tl = [o.get('attr') for o in listish(dictish(d).get('observations')) if isinstance(o, dict)]
check('the timeline omits the sensitive row', code == 200 and 'health' not in tl and 'status' in tl, tl)
code, a = attrs_of(owner, 'person/me')
health = dictish(dictish(a).get('health'))
check('the owner reads the row, under the key identity',
      code == 200 and health.get('value') == 'better' and health.get('by') == 'writer', health)
written = str(health.get('obs', ''))
code, d = writer('POST', '/retract', {'id': written, 'note': 'key gate'})
check('the key cannot retract the row it wrote',
      code == 404 and dictish(d).get('error') == 'no such observation', (code, d))
code, d = writer('GET', '/state')
rev0 = dictish(d).get('rev')
code, d = writer('POST', '/observe', {'bodies': [], 'observations': [obs('person/me', 'health', 'better', T1, 'kg-16')]})
check('the same sensitive row again is ok', code == 200 and all_ok(d, 'observations', 1), d)
time.sleep(1)
code, d = writer('GET', '/state')
check('rev moves for a repeat of a sensitive row, as it does for a new one',
      code == 200 and bool(rev0) and dictish(d).get('rev') != rev0, (rev0, dictish(d).get('rev')))

print('== a key relates only what it can see')
code, d = owner('POST', '/clients', {'name': 'key-gate narrow', 'by': 'narrow',
                                     'scope': {'kinds': ['person'], 'actions': [], 'write': True}})
check('mint the narrow key', code == 200 and '.' in str(dictish(d).get('token', '')), d)
narrow = as_key(str(dictish(d).get('token', '')))
code, d = narrow('POST', '/observe', {'bodies': [], 'observations': [
    obs('person/me', 'home', {'ref': 'place/lake-house'}, T0, 'kg-12')]})
check('a ref at a body outside the kinds is 403',
      code == 403 and 'place/lake-house' in str(dictish(d).get('error', '')), (code, d))
code, d = narrow('POST', '/observe', {'bodies': [], 'observations': [
    obs('person/me', 'home', {'ref': 'place/home'}, T0, 'kg-9')]})
check('resubmitting the owner ref row is 403, never existing',
      code == 403 and 'place/home' in str(dictish(d).get('error', '')), (code, d))
code, d = narrow('GET', '/body/person/me')
home_rows = [o for o in listish(dictish(d).get('observations')) if isinstance(o, dict) and o.get('attr') == 'home']
veiled = str(dictish(home_rows[0] if home_rows else {}).get('id', ''))
check('a veiled row carries a synthetic id', veiled.startswith('veiled-'), home_rows)
code, d = narrow('POST', '/retract', {'id': veiled, 'note': 'key gate'})
check('a veiled row cannot be retracted', code == 404, d)
code, a = attrs_of(owner, 'person/me')
home_obs = str(dictish(dictish(a).get('home')).get('obs', ''))
check('the owner holds the real id behind the veil', bool(home_obs), a)
code, d = narrow('POST', '/retract', {'id': home_obs, 'note': 'key gate'})
check('the real id of a veiled row cannot be retracted either', code == 404, d)
code, a = attrs_of(owner, 'person/me')
check('the veiled row is still live for the owner', a is not None and 'home' in a, a)
code, d = narrow('GET', '/state')
sch = dictish(dictish(d).get('schema'))
kinds = dictish(sch.get('kinds'))
check('the state schema keeps only the kinds of the key', code == 200 and sorted(kinds) == ['person'], sch)
person_attrs = listish(dictish(kinds.get('person')).get('attrs'))
check('the state schema drops the sensitive attribute name',
      'health' not in person_attrs and 'location' in person_attrs, person_attrs)
code, d = owner('POST', '/bodies', {'id': 'situation/key-gate', 'name': 'the key gate situation'})
check('the owner creates a situation the key may not see', code == 200, d)
time.sleep(1)
code, d = owner('POST', '/observe', {'bodies': [], 'observations': [
    obs('situation/key-gate', 'participants', {'ref': 'person/me'}, T0, 'kg-13'),
    obs('situation/key-gate', 'status', 'open', T0, 'kg-14')]})
check('the owner opens the situation with person/me in it', code == 200 and all_ok(d, 'observations', 2), d)
time.sleep(1)
code, d = owner('GET', '/body/person/me')
check('the owner sees the situation in involved',
      code == 200 and 'situation/key-gate' in listish(dictish(d).get('involved')), d)
code, d = narrow('GET', '/body/person/me')
check('involved is empty for a key that cannot see the situation',
      code == 200 and listish(dictish(d).get('involved')) == [], dictish(d).get('involved'))

print('== actions by kind')
code, d = todo('POST', '/act', {'kind': 'task', 'title': 'key gate: call the shop', 'about': ['thing/subaru']})
check('an about outside the kinds reads as no such body', code == 400, d)
code, d = todo('POST', '/act', {'kind': 'task', 'title': 'key gate: call the shop', 'by': 'liar'})
check('the todo key proposes a task', code == 200 and dictish(d).get('status') == 'approved', d)
task_id = str(dictish(d).get('id', ''))
code, d = todo('GET', '/actions')
mine = [x for x in listish(d) if isinstance(x, dict) and x.get('id') == task_id]
check('the todo key lists its task with its identity as by', len(mine) == 1 and mine[0].get('by') == 'todo-app', mine)
code, d = todo('POST', '/act', {'kind': 'note', 'title': 'key gate: a note'})
check('an action kind outside the scope is 403', code == 403, d)
code, d = triage('POST', '/act', {'kind': 'task', 'title': 'key gate: another task'})
check('a key with no action kinds cannot propose', code == 403, d)
code, d = triage('GET', '/actions')
check('a key with no action kinds lists none', code == 200 and d == [], d)
code, d = owner('POST', '/clients', {'name': 'key-gate watcher', 'by': 'watcher',
                                     'scope': {'kinds': [], 'actions': ['task'], 'write': False}})
check('mint a read-only key that may see tasks', code == 200 and '.' in str(dictish(d).get('token', '')), d)
watcher = as_key(str(dictish(d).get('token', '')))
code, d = watcher('GET', '/actions')
check('the read-only key lists the task', code == 200 and any(isinstance(x, dict) and x.get('id') == task_id for x in listish(d)), d)
code, d = watcher('POST', '/act', {'kind': 'task', 'title': 'key gate: watcher task'})
check('a read-only key with action kinds still proposes',
      code == 200 and dictish(d).get('status') == 'approved', d)
code, d = watcher('POST', '/actions/' + task_id, {'status': 'done'})
check('a read-only key cannot transition', code == 403, d)
code, d = todo('POST', '/actions/' + task_id, {'status': 'claimed', 'by': 'liar'})
check('the todo key claims a task of its kind', code == 200 and dictish(d).get('status') == 'claimed', d)
code, d = watcher('POST', '/actions/' + task_id, {'status': 'claimed'})
check('a read-only key cannot claim', code == 403, d)
code, d = owner('POST', '/clients', {'name': 'key-gate second', 'by': 'second-app',
                                     'scope': {'kinds': [], 'actions': ['task'], 'write': True}})
check('mint a second writing key for tasks', code == 200 and '.' in str(dictish(d).get('token', '')), d)
second = as_key(str(dictish(d).get('token', '')))
code, d = second('POST', '/actions/' + task_id, {'status': 'done'})
check('another writing key cannot complete a claimed task',
      code == 409 and dictish(d).get('error') == 'claimed by todo-app', (code, d))
code, d = todo('POST', '/actions/' + task_id, {'status': 'done', 'by': 'liar'})
check('the todo key completes its task', code == 200, d)
code, d = owner('GET', '/actions?status=done')
done = [x for x in listish(d) if isinstance(x, dict) and x.get('id') == task_id]
hist = listish(dictish(done[0] if done else {}).get('history'))
check('the transition carries the key identity', any(dictish(h).get('by') == 'todo-app' and dictish(h).get('status') == 'done' for h in hist)
      and any(dictish(h).get('by') == 'todo-app' and dictish(h).get('status') == 'claimed' for h in hist), hist)
code, d = owner('POST', '/act', {'kind': 'note', 'title': 'key gate: owner note'})
note_id = str(dictish(d).get('id', ''))
code, d = todo('POST', '/actions/' + note_id, {'status': 'dismissed'})
check('an action outside the kinds reads as no such action', code == 404, d)
code, d = owner('POST', '/act', {'kind': 'task', 'title': 'key gate: owner task about the car', 'about': ['thing/subaru']})
about_id = str(dictish(d).get('id', ''))
code, d = todo('GET', '/actions')
about_rows = [x for x in listish(d) if isinstance(x, dict) and x.get('id') == about_id]
check('an about outside the kinds is trimmed from what the todo key lists', len(about_rows) == 1 and about_rows[0].get('about') == [], about_rows)
check('the todo key does not list an action of another kind', len(about_rows) == 1 and not any(isinstance(x, dict) and x.get('id') == note_id for x in listish(d)), d)
code, d = owner('GET', '/actions')
owner_rows = [x for x in listish(d) if isinstance(x, dict) and x.get('id') == about_id]
check('the owner still sees the about', len(owner_rows) == 1 and owner_rows[0].get('about') == ['thing/subaru'], owner_rows)

print('== owner only')
for label, fn in (('clients', lambda: triage('GET', '/clients')),
                  ('policy', lambda: triage('GET', '/policy')),
                  ('schema', lambda: triage('GET', '/schema')),
                  ('shares', lambda: triage('GET', '/shares')),
                  ('delete body', lambda: triage('DELETE', '/body/place/lake-house')),
                  ('merge', lambda: triage('POST', '/merge', {'from': 'place/lake-house', 'into': 'person/me'})),
                  ('share', lambda: triage('POST', '/share', {'id': 'person/me', 'ship': '~feb'}))):
    code, d = fn()
    check('a key may not reach ' + label, code == 403 and dictish(d).get('error') == 'owner only', (code, d))

print('== last use, revocation, bad tokens')
code, d = owner('GET', '/clients')
rows = {c.get('id'): c for c in listish(d) if isinstance(c, dict)}
check('a used key records its last use', code == 200 and isinstance(rows.get(triage_id, {}).get('used'), str)
      and rows[triage_id]['used'] != '', rows.get(triage_id))
code, d = curl('GET', '/state', token=triage_tok + 'x')
check('a wrong secret is 403', code == 403, d)
code, d = curl('GET', '/state', token='nope.' + triage_tok.split('.', 1)[1])
check('a wrong id is 403', code == 403, d)
code, d = curl('GET', '/state')
check('no credentials is 403', code == 403, d)
code, d = owner('DELETE', '/clients/' + str(todo_id))
check('the owner revokes the todo key', code == 200, d)
time.sleep(1)
code, d = todo('GET', '/state')
check('a revoked key is 403', code == 403, d)
code, d = owner('DELETE', '/clients/' + str(todo_id))
check('revoking twice is 404', code == 404, d)

print('== cleanup')
clean()
if fails:
    print('FAILED: ' + ', '.join(fails))
    sys.exit(1)
print('ALL OK (%d checks)' % count[0])
