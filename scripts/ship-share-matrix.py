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
GROUP = '/grubbery/ball/sys/ames/usergroups/orrery-person.sarah.grp?info=1'
STARTER = {'auto': ['task', 'note'], 'push': 'proposed', 'retention_days': 365}
PEER_POLICY = [None]
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


def raw(base, jar, path, timeout=60):
    """a read of the ship's own tree, outside /apps/orrery/api"""
    cmd = ['curl', '-s', '-m', str(timeout), '-w', '\n%{http_code}', '-b', jar, base + path]
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


def listish(x):
    return x if isinstance(x, list) else []


def group_ships():
    """the size in bytes of the share group's who.ships, or None when
    the read failed. A group with no ship in it is 0; the ?info=1 text
    of a /ships grub is always null, so the size is what can be read."""
    code, d = raw(HOST, HJAR, GROUP)
    if code != 200:
        return None
    for c in listish(dictish(d).get('children')):
        if dictish(c).get('name') == 'who.ships':
            return dictish(c).get('size')
    return None


def iso(dt):
    return dt.replace(microsecond=0).strftime('%Y-%m-%dT%H:%M:%SZ')


def attrs_of(side, bid):
    """the body's attribute map, or None when the read itself failed"""
    code, d = side('GET', '/body/' + bid)
    if code != 200:
        return None
    return dictish(dictish(d).get('attrs'))


def attr(side, bid, name):
    """the current row of one attribute, or None"""
    a = attrs_of(side, bid)
    return None if a is None else a.get(name)


def absent(side, bid, name):
    """True only when the body was read and holds no such attribute;
    a failed read never counts as an absence"""
    a = attrs_of(side, bid)
    return a is not None and name not in a


def source_id(row):
    return str(dictish(dictish(row).get('source')).get('id'))


def observe(side, subject, name, value, at, sid):
    return side('POST', '/observe', {'bodies': [], 'observations': [
        {'subject': subject, 'attr': name, 'value': value, 'at': iso(at),
         'source': {'kind': 'matrix', 'id': sid}, 'by': 'ship-share-matrix'}]})


def retract(side, row):
    return side('POST', '/retract', {'id': dictish(row).get('obs', ''), 'note': 'gate'})


def shares(side):
    """the shares answer, or None when the read itself failed"""
    code, d = side('GET', '/shares')
    return dictish(d) if code == 200 else None


def gone_from(side, section, key):
    """True only when the shares were read and the section lacks the key"""
    s = shares(side)
    return s is not None and key not in dictish(s.get(section))


def clean():
    for bid in ('person/sarah', 'person/me', 'person/john'):
        host('DELETE', '/share/' + bid + '/' + PEERNAME)
    for key in list(dictish(dictish(shares(peer)).get('offers'))):
        h, _, i = key.partition('/')
        peer('POST', '/decline', {'host': h, 'id': i})
    for side, bid in ((host, 'person/sarah'), (peer, 'person/me'),
                      (host, 'person/me'), (peer, 'person/' + HOSTNAME[1:])):
        for n in ('location', 'mood', 'plan', 'health'):
            row = attr(side, bid, n)
            if row:
                retract(side, row)
    host('DELETE', '/body/person/john')
    peer('DELETE', '/body/person/john')
    if PEER_POLICY[0] is not None:
        peer('PUT', '/policy', PEER_POLICY[0])


T0 = datetime.now(timezone.utc) - timedelta(hours=1)
KEY = HOSTNAME + '/person/sarah'
print('== setup')
clean()
code, d = peer('POST', '/bodies', {'id': 'person/me', 'ship': PEERNAME})
check('peer person/me carries its ship', code == 200, d)
code, d = peer('GET', '/policy')
found = dictish(d) if code == 200 and isinstance(d, dict) else dict(STARTER)
#  an aborted run leaves the gate's own sensitive list behind: it is not
#  the peer's, so it never becomes the baseline
if found.get('sensitive') == ['health']:
    found = {k: v for k, v in found.items() if k != 'sensitive'}
PEER_POLICY[0] = found
code, d = peer('PUT', '/policy', dict(dictish(PEER_POLICY[0]), sensitive=['health']))
check('the peer marks health sensitive', code == 200, d)
code, d = host('POST', '/bodies', {'id': 'person/sarah', 'name': 'Sarah', 'ship': PEERNAME})
check('host person/sarah carries the peer ship', code == 200, d)
code, d = observe(host, 'person/sarah', 'location', 'at the lake house', T0, 'share-1')
check('host observes location', code == 200 and all(dictish(r).get('ok') for r in dictish(d).get('observations', [])) and len(dictish(d).get('observations', [])) == 1, d)

print('== share in read mode')
code, d = host('POST', '/share', {'id': 'person/sarah', 'ship': PEERNAME, 'mode': 'read'})
check('share answers ok', code == 200 and dictish(d).get('ok') is True, d)
offer = dictish(wait('the offer reaches the peer', lambda: dictish(dictish(shares(peer)).get('offers')).get(KEY), 30))
check('the offer names the body, its ship and the mode', offer.get('ship') == PEERNAME and offer.get('name') == 'Sarah' and offer.get('mode') == 'read', offer)
code, d = peer('POST', '/accept', {'host': HOSTNAME, 'id': 'person/sarah'})
check('accept lands on person/me', code == 200 and dictish(d).get('target') == 'person/me', d)
s = dictish(shares(peer))
check('the offer is gone and the row is kept', KEY in dictish(s.get('accepted')) and KEY not in dictish(s.get('offers')), s)
row = dictish(wait('the location mirrors onto person/me', lambda: attr(peer, 'person/me', 'location'), 90))
check('the mirrored row is the host claim', row.get('by') == HOSTNAME and dictish(row.get('source')).get('kind') == 'ship' and source_id(row).startswith(HOSTNAME + '/') and row.get('value') == 'at the lake house', row)
hrow = dictish(attr(host, 'person/sarah', 'location'))
check('the source names the host grub', source_id(row) == HOSTNAME + '/' + str(hrow.get('obs')), (row, hrow))
srow = dictish(dictish(dictish(shares(peer)).get('accepted')).get(KEY))
check('the row records the pass', srow.get('last') and srow.get('error') == '', srow)

print('== a retraction on the host follows')
code, d = retract(host, hrow)
check('host retracts', code == 200, d)
peer('POST', '/sync')
wait('the mirrored location goes', lambda: absent(peer, 'person/me', 'location'), 90)

print('== read mode carries nothing back')
code, d = observe(peer, 'person/me', 'mood', 'tired', T0, 'share-2')
check('peer observes mood', code == 200, d)
peer('POST', '/sync')
time.sleep(10)
check('the host does not see the peer mood in read mode', absent(host, 'person/sarah', 'mood'), attr(host, 'person/sarah', 'mood'))

print('== edit mode needs a fresh accept')
code, d = host('POST', '/share', {'id': 'person/sarah', 'ship': PEERNAME, 'mode': 'edit'})
check('re-share in edit mode answers ok', code == 200 and dictish(d).get('ok') is True, d)
offer = dictish(wait('an edit offer reaches the peer', lambda: dictish(dictish(shares(peer)).get('offers')).get(KEY), 30))
check('the offer asks for edit', offer.get('mode') == 'edit', offer)
check('the row stays read until accepted', dictish(dictish(dictish(shares(peer)).get('accepted')).get(KEY)).get('mode') == 'read', shares(peer))
peer('POST', '/sync')
time.sleep(10)
check('nothing is pushed before the accept', absent(host, 'person/sarah', 'mood'), attr(host, 'person/sarah', 'mood'))
code, d = peer('POST', '/accept', {'host': HOSTNAME, 'id': 'person/sarah'})
check('accept the edit share', code == 200 and dictish(d).get('target') == 'person/me', d)
s = dictish(shares(peer))
check('the row turns to edit and the offer is gone', dictish(dictish(s.get('accepted')).get(KEY)).get('mode') == 'edit' and KEY not in dictish(s.get('offers')), s)
peer('POST', '/sync')
hrow = dictish(wait('the mood reaches the host', lambda: attr(host, 'person/sarah', 'mood'), 90))
check('the host row is the peer claim', hrow.get('by') == PEERNAME and dictish(hrow.get('source')).get('kind') == 'ship' and source_id(hrow).startswith(PEERNAME + '/') and hrow.get('value') == 'tired', hrow)
prow = dictish(attr(peer, 'person/me', 'mood'))
check('the host source names the peer grub', source_id(hrow) == PEERNAME + '/' + str(prow.get('obs')), (hrow, prow))
peer('POST', '/sync')
time.sleep(10)
check('nothing echoes back onto the peer', dictish(attr(peer, 'person/me', 'mood')).get('by') == 'ship-share-matrix', attr(peer, 'person/me', 'mood'))

print('== a sensitive attribute stays home')
code, d = observe(peer, 'person/me', 'health', 'flu', T0, 'share-4')
check('peer observes a sensitive attribute', code == 200, d)
peer('POST', '/sync')
time.sleep(10)
check('the sensitive attribute is not pushed', absent(host, 'person/sarah', 'health'), attr(host, 'person/sarah', 'health'))
check('the attribute it may push is still there', dictish(attr(host, 'person/sarah', 'mood')).get('value') == 'tired', attr(host, 'person/sarah', 'mood'))
code, d = retract(peer, dictish(attr(peer, 'person/me', 'health')))
check('peer retracts the sensitive attribute', code == 200, d)
code, d = retract(peer, prow)
check('peer retracts mood', code == 200, d)
peer('POST', '/sync')
wait('the retraction reaches the host', lambda: absent(host, 'person/sarah', 'mood'), 90)

print('== a narrower share applies at once')
code, d = host('POST', '/share', {'id': 'person/sarah', 'ship': PEERNAME, 'mode': 'read'})
check('re-share in read mode answers ok', code == 200, d)
wait('the row turns to read without an offer', lambda: dictish(dictish(dictish(shares(peer)).get('accepted')).get(KEY)).get('mode') == 'read' and KEY not in dictish(dictish(shares(peer)).get('offers')), 30)

print('== revoke keeps the data')
code, d = observe(host, 'person/sarah', 'plan', 'dinner at seven', T0, 'share-3')
check('host observes plan', code == 200, d)
peer('POST', '/sync')
wait('the plan mirrors', lambda: attr(peer, 'person/me', 'plan'), 90)
check('the share group is not empty while the share is live', (group_ships() or 0) > 0, group_ships())
code, d = host('DELETE', '/share/person/sarah/' + PEERNAME)
check('revoke answers ok', code == 200, d)
wait('the peer row goes', lambda: gone_from(peer, 'accepted', KEY), 30)
check('the mirrored plan stays', dictish(attr(peer, 'person/me', 'plan')).get('value') == 'dinner at seven', attr(peer, 'person/me', 'plan'))
s = shares(host)
check('the host no longer lists the share', s is not None and PEERNAME not in dictish(dictish(s.get('shares')).get('person/sarah')), s)
check('the share group empties on revoke', group_ships() == 0, group_ships())

print('== a re-share works')
code, d = host('POST', '/share', {'id': 'person/sarah', 'ship': PEERNAME, 'mode': 'read'})
check('share again', code == 200, d)
wait('a fresh offer', lambda: dictish(dictish(shares(peer)).get('offers')).get(KEY), 30)
code, d = peer('POST', '/accept', {'host': HOSTNAME, 'id': 'person/sarah'})
check('accept again', code == 200, d)

print('== deleting a body drops its share')
code, d = host('DELETE', '/body/person/sarah')
check('the shared body goes', code == 200, d)
s = shares(host)
check('the host no longer lists the share of a deleted body',
      s is not None and 'person/sarah' not in dictish(s.get('shares')), s)
check('the share group empties with the body', group_ships() == 0, group_ships())
code, d = host('POST', '/bodies', {'id': 'person/sarah', 'name': 'Sarah', 'ship': PEERNAME})
check('the body comes back for the rest of the gate', code == 200, d)
code, d = host('POST', '/share', {'id': 'person/sarah', 'ship': PEERNAME, 'mode': 'read'})
check('and is shared again, so the next run can revoke it', code == 200, d)

print("== the host's own self lands on person/<host>")
SELF = 'person/' + HOSTNAME[1:]
SELFKEY = HOSTNAME + '/person/me'
code, d = host('POST', '/share', {'id': 'person/me', 'ship': PEERNAME, 'mode': 'read'})
check('share the host self', code == 200 and dictish(d).get('ok') is True, d)
wait('the self offer reaches the peer', lambda: dictish(dictish(shares(peer)).get('offers')).get(SELFKEY), 30)
code, d = peer('POST', '/accept', {'host': HOSTNAME, 'id': 'person/me'})
check('accept lands on ' + SELF, code == 200 and dictish(d).get('target') == SELF, d)
code, d = observe(host, 'person/me', 'location', 'in the workshop', T0, 'self-1')
check('host observes its own location', code == 200, d)
peer('POST', '/sync')
row = dictish(wait('the host self row mirrors onto ' + SELF, lambda: attr(peer, SELF, 'location'), 90))
check('the mirrored self row is the host claim', row.get('by') == HOSTNAME and source_id(row).startswith(HOSTNAME + '/') and row.get('value') == 'in the workshop', row)
code, d = retract(host, dictish(attr(host, 'person/me', 'location')))
check('the host self location is retracted', code == 200, d)
code, d = host('DELETE', '/share/person/me/' + PEERNAME)
check('revoke the self share', code == 200, d)
wait('the self row goes', lambda: gone_from(peer, 'accepted', SELFKEY), 30)

print('== an existing body keeps its name')
JOHNKEY = HOSTNAME + '/person/john'
code, d = host('POST', '/bodies', {'id': 'person/john', 'name': 'John', 'ship': '~zod'})
check('host person/john carries a third ship', code == 200, d)
code, d = peer('POST', '/bodies', {'id': 'person/john', 'name': 'Johnny'})
check('peer person/john is its own, with no ship', code == 200, d)
code, d = host('POST', '/share', {'id': 'person/john', 'ship': PEERNAME, 'mode': 'read'})
check('share person/john', code == 200 and dictish(d).get('ok') is True, d)
wait('the john offer reaches the peer', lambda: dictish(dictish(shares(peer)).get('offers')).get(JOHNKEY), 30)
code, d = peer('POST', '/accept', {'host': HOSTNAME, 'id': 'person/john'})
check('accept keeps the local id', code == 200 and dictish(d).get('target') == 'person/john', d)
code, d = peer('GET', '/body/person/john')
check('the peer body keeps its own name', code == 200 and dictish(d).get('name') == 'Johnny', d)
check('the peer body keeps its own ship', code == 200 and not dictish(d).get('ship'), d)
code, d = host('DELETE', '/share/person/john/' + PEERNAME)
check('revoke the john share', code == 200, d)
wait('the john row goes', lambda: gone_from(peer, 'accepted', JOHNKEY), 30)
code, d = host('DELETE', '/body/person/john')
check('the host john goes', code == 200, d)
code, d = peer('DELETE', '/body/person/john')
check('the peer john goes', code == 200, d)

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
