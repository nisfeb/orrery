#!/usr/bin/env python3
"""mcp-matrix.py HOST JAR
The MCP gate for orrery: the eight tools called by absolute path through
the ship's MCP server, replaying a slice of spec section 8, and checked
against the HTTP API's answers for the same reads. HOST like
http://localhost:8080; JAR a curl cookie jar from POST /~/login (the
MCP server answers JSON-RPC to the owner cookie). Exits 1 on any
failure. Safe to rerun: it retracts and deletes what it made."""
import json, subprocess, sys
from datetime import datetime, timedelta, timezone

HOST, JAR = sys.argv[1:3]
MCP = HOST + '/grubbery/mcp'
API = HOST + '/apps/orrery/api'
TOOLS = '/apps/shell.shell/desks/orrery.desk/desk/code/lib/tools/'
fails = []
count = [0]
seq = [0]


def post(url, body, timeout=120):
    cmd = ['curl', '-s', '-m', str(timeout), '-X', 'POST', '-w', '\n%{http_code}', '-b', JAR,
           '-H', 'content-type: application/json', '-d', json.dumps(body), url]
    out = subprocess.run(cmd, capture_output=True, text=True).stdout
    text, _, code = out.rpartition('\n')
    try:
        data = json.loads(text) if text else None
    except json.JSONDecodeError:
        data = text
    return int(code or 0), data


def http(method, path, body=None):
    cmd = ['curl', '-s', '-m', '60', '-X', method, '-w', '\n%{http_code}', '-b', JAR, API + path]
    if body is not None:
        cmd += ['-H', 'content-type: application/json', '-d', json.dumps(body)]
    out = subprocess.run(cmd, capture_output=True, text=True).stdout
    text, _, code = out.rpartition('\n')
    try:
        data = json.loads(text) if text else None
    except json.JSONDecodeError:
        data = text
    return int(code or 0), data


def call(tool, args):
    """(ok, payload): the tool's JSON answer parsed, or its error message"""
    seq[0] += 1
    body = {'jsonrpc': '2.0', 'id': seq[0], 'method': 'tools/call',
            'params': {'name': TOOLS + tool, 'arguments': args}}
    code, d = post(MCP, body)
    if code != 200 or not isinstance(d, dict):
        return False, 'http %s: %s' % (code, str(d)[:200])
    if 'error' in d:
        return False, str(dictish(d.get('error')).get('message'))
    content = listish(dictish(d.get('result')).get('content'))
    text = dictish(content[0] if content else {}).get('text', '')
    try:
        return True, json.loads(text)
    except (json.JSONDecodeError, TypeError):
        return True, text


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


def all_ok(d, key, n):
    items = listish(dictish(d).get(key))
    return len(items) == n and all(dictish(r).get('ok') is True for r in items)


def body_attrs(bid):
    """the attrs object, or None when the answer carries none"""
    ok, d = call('orrery-body', {'id': bid})
    a = dictish(d).get('attrs') if ok else None
    return a if isinstance(a, dict) else None


def clean():
    a = body_attrs('person/me')
    for n in ('mood',):
        row = dictish(dictish(a).get(n))
        if row.get('obs'):
            call('orrery-retract', {'id': row['obs'], 'note': 'mcp gate'})
    http('DELETE', '/body/place/mcp-test')
    ok, d = call('orrery-actions', {'status': 'open'})
    for x in listish(d if ok else []):
        if isinstance(x, dict) and str(x.get('title', '')).startswith('mcp gate'):
            call('orrery-actions', {'id': str(x.get('id')), 'status': 'dismissed', 'note': 'mcp gate'})


T0 = datetime.now(timezone.utc) - timedelta(hours=1)
print('== setup')
clean()

print('== reads agree with the HTTP API')
ok, st = call('orrery-state', {})
code, hs = http('GET', '/state')
check('state answers', ok and isinstance(st, dict), st)
check('state has the envelope', all(k in dictish(st) for k in ('rev', 'at', 'me', 'bodies', 'situations', 'actions', 'schema')), sorted(dictish(st).keys()))
check('the state view is the HTTP state view, whole',
      code == 200
      and dictish(st).get('bodies') == dictish(hs).get('bodies')
      and dictish(st).get('situations') == dictish(hs).get('situations')
      and dictish(st).get('schema') == dictish(hs).get('schema')
      and len(listish(dictish(st).get('bodies'))) >= 1,
      (st, hs))
ok, mb = call('orrery-body', {'id': 'person/me'})
code, hb = http('GET', '/body/person/me')
check('the body view is the HTTP body view, whole', ok and code == 200 and mb == hb, (mb, hb))
ok, sc = call('orrery-schema', {})
check('schema answers with kinds', ok and 'kinds' in dictish(sc), sc)
ok, st2 = call('orrery-state', {'kind': 'person'})
check('a kind filter narrows the state', ok and all(dictish(b).get('kind') == 'person' for b in listish(dictish(st2).get('bodies'))) and listish(dictish(st2).get('bodies')), st2)
ok, err = call('orrery-state', {'at': 'yesterday'})
check('a bad at is an error', not ok and 'at' in str(err), err)

print('== writes carry by and answer like the HTTP route')
ok, d = call('orrery-observe', {
    'bodies': [{'id': 'place/mcp-test', 'name': 'the MCP test place', 'aliases': ['mcp test']}],
    'observations': [{'subject': 'person/me', 'attr': 'mood', 'value': 'curious', 'at': iso(T0),
                      'source': {'kind': 'matrix', 'id': 'mcp-1'}}],
    'by': 'mcp-gate'})
check('observe answers one body and one observation, both ok', ok and all_ok(d, 'bodies', 1) and all_ok(d, 'observations', 1), d)
obs_id = str(dictish(listish(dictish(d).get('observations'))[0] if listish(dictish(d).get('observations')) else {}).get('id', ''))
a = body_attrs('person/me')
check('the body view shows the mood with by from the argument', a is not None and dictish(a.get('mood')).get('value') == 'curious' and dictish(a.get('mood')).get('by') == 'mcp-gate', a)
check('the observation id matches the view', bool(obs_id) and dictish(dictish(a).get('mood')).get('obs') == obs_id, (obs_id, a))
ok, d = call('orrery-observe', {'observations': [{'subject': 'person/me', 'attr': 'mood', 'value': 'curious', 'at': iso(T0), 'source': {'kind': 'matrix', 'id': 'mcp-1'}}], 'by': 'mcp-gate'})
check('a resubmit answers existing', ok and all_ok(d, 'observations', 1) and dictish(listish(dictish(d).get('observations'))[0]).get('existing') is True, d)
ok, d = call('orrery-observe', {'observations': [{'subject': 'org/nobody', 'attr': 'x', 'value': 1, 'source': {'kind': 'matrix', 'id': 'mcp-2'}}]})
check('an unknown subject is refused per item', ok and len(listish(dictish(d).get('observations'))) == 1 and dictish(listish(dictish(d).get('observations'))[0]).get('ok') is False, d)
ok, d = call('orrery-observe', {'observations': 'nope'})
check('a non-array batch is an error', not ok, d)
ok, d = call('orrery-observe', {'observations': [{'subject': 'person/me', 'attr': 'mood', 'value': 'forged',
                                                 'at': iso(T0), 'source': {'kind': 'ship', 'id': '~zod/x'}}]})
o = listish(dictish(d).get('observations'))
check('a ship source is refused per item', ok and len(o) == 1 and dictish(o[0]).get('ok') is False
      and dictish(o[0]).get('error') == 'source.kind: reserved for the inbox', d)
a = body_attrs('person/me')
check('the forged ship claim was not written', dictish(dictish(a).get('mood')).get('value') != 'forged', a)
ok, d = call('orrery-resolve', {'q': 'mcp test'})
check('resolve finds the new place by alias', ok and any(dictish(r).get('id') == 'place/mcp-test' for r in listish(d)), d)
ok, d = call('orrery-body', {'id': 'place/mcp-test'})
check('the body tool answers the new place', ok and dictish(d).get('id') == 'place/mcp-test' and dictish(d).get('name') == 'the MCP test place', d)
ok, d = call('orrery-body', {'id': 'place/nowhere'})
check('a missing body is an error', not ok and 'no such body' in str(d), d)
ok, d = call('orrery-body', {'id': 'nope'})
check('a bad id is an error', not ok, d)

print('== actions')
ok, d = call('orrery-act', {'kind': 'task', 'title': 'mcp gate: call the shop', 'about': ['place/mcp-test'], 'by': 'mcp-gate'})
check('a task is proposed and approved by policy', ok and dictish(d).get('status') == 'approved' and dictish(d).get('existing') is False, d)
task_id = str(dictish(d).get('id', ''))
ok, d = call('orrery-act', {'kind': 'task', 'title': 'mcp gate: call the shop', 'by': 'mcp-gate'})
check('the same title answers the existing action', ok and dictish(d).get('id') == task_id and dictish(d).get('existing') is True, d)
ok, d = call('orrery-actions', {})
mine = [x for x in listish(d) if isinstance(x, dict) and x.get('id') == task_id]
check('the open list has it with by from the argument', ok and len(mine) == 1 and mine[0].get('by') == 'mcp-gate' and mine[0].get('about') == ['place/mcp-test'], mine)
code, hd = http('GET', '/actions?status=open')
check('the HTTP open list agrees', code == 200 and any(isinstance(x, dict) and x.get('id') == task_id for x in listish(hd)), hd)
ok, d = call('orrery-act', {'kind': 'task', 'title': 'mcp gate: about nobody', 'about': ['place/nowhere']})
check('an unknown about is an error', not ok and 'about' in str(d), d)
ok, d = call('orrery-act', {'title': 'no kind'})
check('a missing kind is an error', not ok, d)
ok, d = call('orrery-actions', {'id': task_id, 'status': 'done', 'note': 'mcp gate', 'by': 'mcp-gate'})
check('the task is moved to done', ok and dictish(d).get('status') == 'done', d)
ok, d = call('orrery-actions', {'status': 'done'})
done = [x for x in listish(d) if isinstance(x, dict) and x.get('id') == task_id]
check('the done list has it and the history names the actor', len(done) == 1 and any(dictish(h).get('by') == 'mcp-gate' and dictish(h).get('status') == 'done' for h in listish(done[0].get('history'))), done)
ok, d = call('orrery-actions', {'id': task_id, 'status': 'approved'})
check('a transition out of a terminal state is an error', not ok and 'cannot go' in str(d), d)
ok, d = call('orrery-actions', {'id': 'nope', 'status': 'done'})
check('an unknown action is an error', not ok, d)
ok, d = call('orrery-act', {'kind': 'task', 'title': 'mcp gate: claim before doing', 'by': 'mcp-gate'})
claim_id = str(dictish(d).get('id', ''))
ok, d = call('orrery-actions', {'id': claim_id, 'status': 'claimed'})
check('the tool claims an approved action', ok and dictish(d).get('status') == 'claimed', d)
ok, d = call('orrery-actions', {'id': claim_id, 'status': 'done', 'note': 'mcp gate'})
check('the claimant completes it through the tool', ok and dictish(d).get('status') == 'done', d)
code, hd = http('GET', '/actions?status=done')
row = [x for x in listish(hd) if isinstance(x, dict) and x.get('id') == claim_id]
check('the HTTP history shows the claim by the default actor', code == 200 and len(row) == 1
      and any(dictish(h).get('status') == 'claimed' and dictish(h).get('by') == 'mcp' for h in listish(dictish(row[0]).get('history'))), row)

print('== retract')
ok, d = call('orrery-retract', {'id': obs_id, 'note': 'mcp gate', 'by': 'mcp-gate'})
check('retract answers ok', ok and dictish(d).get('ok') is True, d)
a = body_attrs('person/me')
check('the mood is gone from the view', a is not None and 'mood' not in a, a)
ok, d = call('orrery-body', {'id': 'person/me'})
tl = [o for o in listish(dictish(d).get('observations')) if isinstance(o, dict) and o.get('id') == obs_id]
check('the timeline keeps the retracted row with its note', len(tl) == 1 and tl[0].get('status') == 'retracted' and tl[0].get('note') == 'mcp gate', tl)
ok, d = call('orrery-retract', {'id': 'nope'})
check('an unknown observation is an error', not ok, d)

print('== schema round trip')
ok, sc = call('orrery-schema', {})
ok2, d = call('orrery-schema', {'schema': sc})
check('replacing the schema with itself answers ok', ok and ok2 and dictish(d).get('ok') is True, d)
ok, d = call('orrery-schema', {'schema': 'nope'})
check('a non-object schema is an error', not ok, d)

print('== cleanup')
clean()
if fails:
    print('FAILED: ' + ', '.join(fails))
    sys.exit(1)
print('ALL OK (%d checks)' % count[0])
