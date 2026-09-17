#!/usr/bin/env python3
"""ship-share-matrix.py HOST HJAR PEER PJAR
The sharing gate for orrery (spec section 11) against two fake ships:
HOST (~wex) shares person/sarah with PEER (~feb), whose person/me it is.
Read mode mirrors the host's observations and retractions; edit mode
carries the peer's back; revoke keeps the data; a re-share works.
HOST and PEER like http://localhost:8080; the jars from POST /~/login.
Exits 1 on any failure. Safe to rerun: it revokes, declines and retracts
what an earlier run left."""
import json, subprocess, sys, time
from datetime import datetime, timedelta, timezone

HOST, HJAR, PEER, PJAR = sys.argv[1:5]
HOSTNAME, PEERNAME = '~wex', '~feb'
fails = []
count = [0]


def curl(base, jar, method, path, body=None, timeout=60):
    cmd = ['curl', '-s', '-m', str(timeout), '-X', method, '-w', '\n%{http_code}',
           '-b', jar, base + '/apps/orrery/api' + path]
    if body is not None:
        cmd += ['-H', 'content-type: application/json', '-d', json.dumps(body)]
    out = subprocess.run(cmd, capture_output=True, text=True).stdout
    text, _, code = out.rpartition('\n')
    try:
        data = json.loads(text) if text else None
    except json.JSONDecodeError:
        data = text
    return int(code or 0), data


def host(method, path, body=None):
    return curl(HOST, HJAR, method, path, body)


def peer(method, path, body=None):
    return curl(PEER, PJAR, method, path, body)


def check(label, cond, detail=''):
    count[0] += 1
    print(('  ok   ' if cond else '  FAIL ') + label + ('' if cond else '   ' + str(detail)[:300]))
    if not cond:
        fails.append(label)


def wait(label, fn, secs):
    """poll fn every 2 s until it answers truthy; check the result"""
    deadline = time.time() + secs
    got = None
    while time.time() < deadline:
        got = fn()
        if got:
            break
        time.sleep(2)
    check(label, bool(got), 'timed out after %ds' % secs)
    return got


def dictish(x):
    return x if isinstance(x, dict) else {}


def iso(dt):
    return dt.replace(microsecond=0).strftime('%Y-%m-%dT%H:%M:%SZ')


def attr(side, bid, name):
    """the current row of one attribute, or None"""
    code, d = side('GET', '/body/' + bid)
    if code != 200:
        return None
    return dictish(dictish(d).get('attrs')).get(name)


def source_id(row):
    return str(dictish(dictish(row).get('source')).get('id'))


def observe(side, subject, name, value, at, sid):
    return side('POST', '/observe', {'bodies': [], 'observations': [
        {'subject': subject, 'attr': name, 'value': value, 'at': iso(at),
         'source': {'kind': 'matrix', 'id': sid}, 'by': 'ship-share-matrix'}]})


def retract(side, row):
    return side('POST', '/retract', {'id': dictish(row).get('obs', ''), 'note': 'gate'})


def shares(side):
    return dictish(side('GET', '/shares')[1])


def clean():
    host('DELETE', '/share/person/sarah/' + PEERNAME)
    for key in list(dictish(shares(peer).get('offers'))):
        h, _, i = key.partition('/')
        peer('POST', '/decline', {'host': h, 'id': i})
    for side, bid in ((host, 'person/sarah'), (peer, 'person/me')):
        for n in ('location', 'mood', 'plan'):
            row = attr(side, bid, n)
            if row:
                retract(side, row)


T0 = datetime.now(timezone.utc) - timedelta(hours=1)
KEY = HOSTNAME + '/person/sarah'
print('== setup')
clean()
code, d = peer('POST', '/bodies', {'id': 'person/me', 'ship': PEERNAME})
check('peer person/me carries its ship', code == 200, d)
code, d = host('POST', '/bodies', {'id': 'person/sarah', 'name': 'Sarah', 'ship': PEERNAME})
check('host person/sarah carries the peer ship', code == 200, d)
code, d = observe(host, 'person/sarah', 'location', 'at the lake house', T0, 'share-1')
check('host observes location', code == 200 and all(dictish(r).get('ok') for r in dictish(d).get('observations', [])) and len(dictish(d).get('observations', [])) == 1, d)

print('== share in read mode')
code, d = host('POST', '/share', {'id': 'person/sarah', 'ship': PEERNAME, 'mode': 'read'})
check('share answers ok', code == 200 and dictish(d).get('ok') is True, d)
offer = dictish(wait('the offer reaches the peer', lambda: dictish(shares(peer).get('offers')).get(KEY), 30))
check('the offer names the body, its ship and the mode', offer.get('ship') == PEERNAME and offer.get('name') == 'Sarah' and offer.get('mode') == 'read', offer)
code, d = peer('POST', '/accept', {'host': HOSTNAME, 'id': 'person/sarah'})
check('accept lands on person/me', code == 200 and dictish(d).get('target') == 'person/me', d)
s = shares(peer)
check('the offer is gone and the row is kept', KEY in dictish(s.get('accepted')) and KEY not in dictish(s.get('offers')), s)
row = dictish(wait('the location mirrors onto person/me', lambda: attr(peer, 'person/me', 'location'), 90))
check('the mirrored row is the host claim', row.get('by') == HOSTNAME and dictish(row.get('source')).get('kind') == 'ship' and source_id(row).startswith(HOSTNAME + '/') and row.get('value') == 'at the lake house', row)
hrow = dictish(attr(host, 'person/sarah', 'location'))
check('the source names the host grub', source_id(row) == HOSTNAME + '/' + str(hrow.get('obs')), (row, hrow))
srow = dictish(dictish(shares(peer).get('accepted')).get(KEY))
check('the row records the pass', srow.get('last') and srow.get('error') == '', srow)

print('== a retraction on the host follows')
code, d = retract(host, hrow)
check('host retracts', code == 200, d)
peer('POST', '/sync')
wait('the mirrored location goes', lambda: attr(peer, 'person/me', 'location') is None, 90)

print('== read mode carries nothing back')
code, d = observe(peer, 'person/me', 'mood', 'tired', T0, 'share-2')
check('peer observes mood', code == 200, d)
peer('POST', '/sync')
time.sleep(10)
check('the host does not see the peer mood in read mode', attr(host, 'person/sarah', 'mood') is None, attr(host, 'person/sarah', 'mood'))

print('== edit mode needs a fresh accept')
code, d = host('POST', '/share', {'id': 'person/sarah', 'ship': PEERNAME, 'mode': 'edit'})
check('re-share in edit mode answers ok', code == 200 and dictish(d).get('ok') is True, d)
offer = dictish(wait('an edit offer reaches the peer', lambda: dictish(shares(peer).get('offers')).get(KEY), 30))
check('the offer asks for edit', offer.get('mode') == 'edit', offer)
check('the row stays read until accepted', dictish(dictish(shares(peer).get('accepted')).get(KEY)).get('mode') == 'read', shares(peer))
peer('POST', '/sync')
time.sleep(10)
check('nothing is pushed before the accept', attr(host, 'person/sarah', 'mood') is None, attr(host, 'person/sarah', 'mood'))
code, d = peer('POST', '/accept', {'host': HOSTNAME, 'id': 'person/sarah'})
check('accept the edit share', code == 200 and dictish(d).get('target') == 'person/me', d)
s = shares(peer)
check('the row turns to edit and the offer is gone', dictish(dictish(s.get('accepted')).get(KEY)).get('mode') == 'edit' and KEY not in dictish(s.get('offers')), s)
peer('POST', '/sync')
hrow = dictish(wait('the mood reaches the host', lambda: attr(host, 'person/sarah', 'mood'), 90))
check('the host row is the peer claim', hrow.get('by') == PEERNAME and dictish(hrow.get('source')).get('kind') == 'ship' and source_id(hrow).startswith(PEERNAME + '/') and hrow.get('value') == 'tired', hrow)
prow = dictish(attr(peer, 'person/me', 'mood'))
check('the host source names the peer grub', source_id(hrow) == PEERNAME + '/' + str(prow.get('obs')), (hrow, prow))
peer('POST', '/sync')
time.sleep(10)
check('nothing echoes back onto the peer', dictish(attr(peer, 'person/me', 'mood')).get('by') == 'ship-share-matrix', attr(peer, 'person/me', 'mood'))
code, d = retract(peer, prow)
check('peer retracts mood', code == 200, d)
peer('POST', '/sync')
wait('the retraction reaches the host', lambda: attr(host, 'person/sarah', 'mood') is None, 90)

print('== a narrower share applies at once')
code, d = host('POST', '/share', {'id': 'person/sarah', 'ship': PEERNAME, 'mode': 'read'})
check('re-share in read mode answers ok', code == 200, d)
wait('the row turns to read without an offer', lambda: dictish(dictish(shares(peer).get('accepted')).get(KEY)).get('mode') == 'read' and KEY not in dictish(shares(peer).get('offers')), 30)

print('== revoke keeps the data')
code, d = observe(host, 'person/sarah', 'plan', 'dinner at seven', T0, 'share-3')
check('host observes plan', code == 200, d)
peer('POST', '/sync')
wait('the plan mirrors', lambda: attr(peer, 'person/me', 'plan'), 90)
code, d = host('DELETE', '/share/person/sarah/' + PEERNAME)
check('revoke answers ok', code == 200, d)
wait('the peer row goes', lambda: KEY not in dictish(shares(peer).get('accepted')), 30)
check('the mirrored plan stays', dictish(attr(peer, 'person/me', 'plan')).get('value') == 'dinner at seven', attr(peer, 'person/me', 'plan'))
check('the host no longer lists the share', PEERNAME not in dictish(dictish(shares(host).get('shares')).get('person/sarah')), shares(host))

print('== a re-share works')
code, d = host('POST', '/share', {'id': 'person/sarah', 'ship': PEERNAME, 'mode': 'read'})
check('share again', code == 200, d)
wait('a fresh offer', lambda: dictish(shares(peer).get('offers')).get(KEY), 30)
code, d = peer('POST', '/accept', {'host': HOSTNAME, 'id': 'person/sarah'})
check('accept again', code == 200, d)

print('== refusals')
code, d = host('POST', '/share', {'id': 'nope', 'ship': PEERNAME})
check('share refuses a bad id', code == 400, d)
code, d = host('POST', '/share', {'id': 'person/sarah', 'ship': 'sarah'})
check('share refuses a bad ship', code == 400, d)
code, d = host('POST', '/share', {'id': 'person/sarah', 'ship': HOSTNAME})
check('share refuses this ship', code == 400, d)
code, d = host('POST', '/share', {'id': 'person/nobody', 'ship': PEERNAME})
check('share refuses an unknown body', code == 404, d)
code, d = host('DELETE', '/share/person/sarah/~zod')
check('revoke refuses a ship not shared with', code == 404, d)
code, d = peer('POST', '/accept', {'host': HOSTNAME, 'id': 'person/nobody'})
check('accept refuses an unknown offer', code == 404, d)
code, d = peer('POST', '/accept', {'host': 'nobody', 'id': 'person/sarah'})
check('accept refuses a bad host', code == 400, d)

print('== cleanup')
clean()
if fails:
    print('FAILED: ' + ', '.join(fails))
    sys.exit(1)
print('ALL OK (%d checks)' % count[0])
