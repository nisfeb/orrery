#!/usr/bin/env python3
"""sphere-matrix.py HOST HJAR PEER PJAR
The sphere feed gate (version 90) against two fake ships. HOST shares a
test sphere with PEER in edit mode and PEER accepts. PEER takes the
sphere's bodies and rows from HOST's feed, but nothing kept back: a
sensitive attribute, a private row, another sphere's filing, a body in
no shared sphere. An edit, a retraction and a correction on HOST reach
PEER without a sync; PEER's own edits and a body it files under the
sphere come back. A body filed out on HOST takes nothing more either way.
Never sphere/home: home is every unfiled body. Each ship's name is read
from its own /~/host. Safe to rerun: every run's ids are its own, and it
unshares, deletes, and puts the host's policy back."""
import secrets, sys, time
from gate import fails, check, wait, dictish, listish, iso
import gate
from datetime import datetime, timezone

HOST, HJAR, PEER, PJAR = sys.argv[1:5]
HOSTNAME, PEERNAME = (str(gate.curl('GET', b + '/~/host')[1]).strip() for b in (HOST, PEER))
RUN = secrets.token_hex(3)
NOW = datetime.now(timezone.utc)


def api(base, jar, method, path, body=None):
    return gate.curl(method, base + '/apps/orrery/api' + path, body, jar=jar)


def host(method, path, body=None): return api(HOST, HJAR, method, path, body)
def peer(method, path, body=None): return api(PEER, PJAR, method, path, body)


def rows(side, bid, name):
    """the live rows of one attribute, a list whether it is multi or not"""
    code, d = side('GET', '/body/' + bid)
    v = dictish(dictish(d).get('attrs')).get(name) if code == 200 else None
    return [dictish(r) for r in (v if isinstance(v, list) else [v] if v else [])]


def values(side, bid, name, by=None):
    return sorted(str(r.get('value') if not isinstance(r.get('value'), dict) else r['value'].get('ref', r['value']))
                  for r in rows(side, bid, name) if by is None or r.get('by') == by)


def has_body(side, bid):
    return side('GET', '/body/' + bid)[0] == 200


def observe(side, subject, name, value, bodies=()):
    code, d = side('POST', '/observe', {'bodies': list(bodies), 'observations': [
        {'subject': subject, 'attr': name, 'value': value, 'at': iso(NOW), 'conf': 100,
         'source': {'kind': 'matrix', 'id': 'sphere-' + RUN}, 'by': 'owner'}]})
    return code, (dictish(d).get('observations') or [{}])[0].get('id')


SPH, OTHER = 'sphere/gate-sp-' + RUN, 'sphere/gate-ot-' + RUN
A, B, C = 'person/gate-sp-a-' + RUN, 'place/gate-sp-b-' + RUN, 'thing/gate-sp-c-' + RUN
D = 'thing/gate-sp-d-' + RUN
ref = lambda b: {'ref': b}
KEY = HOSTNAME + '|' + SPH

print('== the sphere feed between', HOSTNAME, 'and', PEERNAME)
_, pol = host('GET', '/policy')
pol = dictish(pol)
host('PUT', '/policy', dict(pol, sensitive=sorted(set(listish(pol.get('sensitive'))) | {'health'})))
observe(host, SPH, 'summary', 'the gate sphere', bodies=[{'id': SPH, 'name': 'Gate sphere ' + RUN}, {'id': OTHER, 'name': 'Gate other ' + RUN}])
observe(host, A, 'sphere', ref(SPH), bodies=[{'id': A, 'name': 'Gate A ' + RUN}, {'id': B, 'name': 'Gate B ' + RUN}, {'id': C, 'name': 'Gate C ' + RUN}])
observe(host, A, 'likes', 'sailing')
observe(host, A, 'health', 'a cold')
_, secret = observe(host, A, 'status', 'a secret')
code, d = host('POST', '/private', {'id': secret, 'private': True})
check('a row is kept private', code == 200 and dictish(d).get('private') is True, (code, d))
observe(host, B, 'sphere', ref(SPH))
observe(host, B, 'sphere', ref(OTHER))
observe(host, B, 'address', '1 Gate Street')
observe(host, C, 'sphere', ref(OTHER))
observe(host, C, 'status', 'elsewhere')

code, d = host('POST', '/sphere-share', {'sphere': SPH, 'ship': PEERNAME, 'mode': 'edit'})
check('share the sphere in edit mode', code == 200 and dictish(d).get('notified') is True, (code, d))
wait('the offer reaches the peer', lambda: dictish(dictish(peer('GET', '/shares')[1]).get('sphere_offers')).get(KEY), 60)
code, d = peer('POST', '/sphere-accept', {'host': HOSTNAME, 'sphere': SPH})
check('the peer accepts it onto its own sphere', code == 200 and dictish(d).get('local') == SPH and dictish(d).get('told') is True, (code, d))
peer('POST', '/sync')
got = wait('the sphere arrives', lambda: values(peer, A, 'likes', HOSTNAME) or None, 120) or []
check("a member's row arrives as the host's", got == ['sailing'], got)
#  what stays home is only checked once the rest has come: an empty peer keeps everything home
arrived = got == ['sailing']
check('the sensitive attribute stays home', arrived and not rows(peer, A, 'health'), rows(peer, A, 'health'))
check('the private row stays home', arrived and 'a secret' not in values(peer, A, 'status'), values(peer, A, 'status'))
check("a member filed under another sphere too says only this one", values(peer, B, 'sphere') == [SPH] and values(peer, B, 'address') == ['1 Gate Street'], (values(peer, B, 'sphere'), values(peer, B, 'address')))
check('a body in no shared sphere stays home', arrived and not has_body(peer, C), C)
check('nor does the other sphere', arrived and not has_body(peer, OTHER), OTHER)
tw = [dictish(r.get('value')) for r in rows(peer, A, 'twin')]
check('a body made on the peer knows its twin', {'ship': HOSTNAME, 'id': A} in tw, tw)

# the host's edits reach the peer on the wake, with no sync asked for
observe(host, A, 'location', 'the harbour')
got = wait('an edit crosses on the wake', lambda: values(peer, A, 'location', HOSTNAME) or None, 120) or []
check('an edit crosses by itself', got == ['the harbour'], got)
check('the row to retract is on the peer first', bool(rows(peer, A, 'likes')), rows(peer, A, 'likes'))
code, d = host('POST', '/retract', {'id': dictish((rows(host, A, 'likes') or [{}])[0]).get('obs', ''), 'note': 'gate'})
check('a retraction crosses', bool(wait('the retraction crosses', lambda: (not rows(peer, A, 'likes')) or None, 120)), rows(peer, A, 'likes'))
wait('the address is on the peer first', lambda: rows(peer, B, 'address') or None, 120)
code, d = host('POST', '/correct', {'subject': B, 'attr': 'address', 'value': '1 Gate Street', 'why': 'gate'})
check('the owner strikes a value', code == 200, (code, d))
check('a correction strikes it on the peer too', bool(wait('the correction crosses', lambda: (not rows(peer, B, 'address')) or None, 120)), rows(peer, B, 'address'))
cs = [c for c in listish(dictish(peer('GET', '/corrections')[1]).get('corrections', peer('GET', '/corrections')[1])) if dictish(c).get('subject') == B]
check("the peer's correction names the host", any(dictish(c).get('by') == HOSTNAME for c in cs), cs)

# the peer's edits, and a body it files under the sphere, come back
observe(peer, A, 'mood', 'cheerful')
observe(peer, D, 'sphere', ref(SPH), bodies=[{'id': D, 'name': 'Gate D ' + RUN}])
got = wait("the peer's edit comes back", lambda: values(host, A, 'mood', PEERNAME) or None, 120) or []
check("the peer's edit lands as the peer's", got == ['cheerful'], got)
got = wait('the new body comes back', lambda: values(host, D, 'sphere', PEERNAME) or None, 120) or []
check('a body the peer files under the sphere comes to the host, in it', got == [SPH], got)
tw = [dictish(r.get('value')) for r in rows(host, D, 'twin')]
check('and knows its twin there', {'ship': PEERNAME, 'id': D} in tw, tw)
check("the peer's twin facts never crossed", not [r for r in rows(host, A, 'twin') if r.get('by') == PEERNAME], rows(host, A, 'twin'))

# filed out on the host: nothing more about it either way
for r in rows(host, A, 'sphere'):
    host('POST', '/retract', {'id': r.get('obs', ''), 'note': 'gate'})
observe(host, A, 'sphere', ref(OTHER))
observe(host, A, 'location', 'inland')
observe(peer, A, 'mood', 'gloomy')
observe(host, B, 'location', 'the shore')
wait('a later edit on a member still crosses', lambda: values(peer, B, 'location', HOSTNAME) or None, 120)
peer('POST', '/sync')
time.sleep(30)
check('a body filed out sends nothing more', values(peer, A, 'location', HOSTNAME) == ['the harbour'], values(peer, A, 'location'))
check('and takes nothing more', 'gloomy' not in values(host, A, 'mood'), values(host, A, 'mood'))
check('the other sphere was never told', not has_body(peer, OTHER), OTHER)

# put back what this run made
code, d = host('DELETE', '/sphere-share/' + SPH + '/' + PEERNAME)
check('the sphere is unshared, and the peer told', code == 200 and dictish(d).get('told') is True, (code, d))
check('the peer follows it no more', bool(wait('the follow goes', lambda: KEY not in dictish(dictish(peer('GET', '/shares')[1]).get('sphere_follows')) or None, 60)), KEY)
for b in (A, B, C, D, SPH, OTHER):
    host('DELETE', '/body/' + b)
for b in (A, B, D, SPH):
    peer('DELETE', '/body/' + b)
host('PUT', '/policy', pol)
print()
print('FAILED: ' + ', '.join(fails) if fails else 'ALL OK')
sys.exit(1 if fails else 0)
