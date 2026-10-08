#!/usr/bin/env python3
"""pairing-matrix.py HOST HJAR PEER PJAR
The pairing gate (version 91) against two fake ships. HOST shares a test
sphere with PEER; before any row comes in, PEER matches HOST's roster to
its own bodies. The body HOST keeps for PEER's owner pairs with PEER's
person/me at once (the same ship); a child each keeps under its own id
waits for PEER's owner, who says it is the same, and its rows land on
PEER's body; another name match is said to be different and arrives as a
body of its own; a body PEER lacks is made. Nothing comes in while a match
waits. Each ship's name is read from its own /~/host. Safe to rerun: every
run's ids are its own, and it unshares and deletes what it made."""
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
    code, d = side('GET', '/body/' + bid)
    v = dictish(dictish(d).get('attrs')).get(name) if code == 200 else None
    return [dictish(r) for r in (v if isinstance(v, list) else [v] if v else [])]


def values(side, bid, name, by=None):
    return sorted(str(r.get('value')) for r in rows(side, bid, name) if by is None or r.get('by') == by)


def has_body(side, bid):
    return side('GET', '/body/' + bid)[0] == 200


def observe(side, subject, name, value, bodies=()):
    code, d = side('POST', '/observe', {'bodies': list(bodies), 'observations': [
        {'subject': subject, 'attr': name, 'value': value, 'at': iso(NOW), 'conf': 100,
         'source': {'kind': 'matrix', 'id': 'pairing-' + RUN}, 'by': 'owner'}]})
    return code, (dictish(d).get('observations') or [{}])[0].get('id')


def follow():
    return dictish(dictish(dictish(peer('GET', '/shares')[1]).get('sphere_follows')).get(KEY))


SPH = 'sphere/gate-pr-' + RUN
PARTNER, ROWAN, ASH, BOAT = ('person/gate-pr-partner-' + RUN, 'person/gate-pr-rowan-' + RUN,
                             'person/gate-pr-ash-' + RUN, 'thing/gate-pr-boat-' + RUN)
KID, ASH2 = 'person/gate-pr-kid-' + RUN, 'person/gate-pr-ash2-' + RUN
KEY = HOSTNAME + '|' + SPH
ref = lambda b: {'ref': b}

print('== pairing between', HOSTNAME, 'and', PEERNAME)
observe(host, SPH, 'summary', 'the pairing gate', bodies=[{'id': SPH, 'name': 'Gate pairing ' + RUN}])
for bid, name, ship in ((PARTNER, 'Partner ' + RUN, PEERNAME), (ROWAN, 'Rowan ' + RUN, None),
                        (ASH, 'Ash ' + RUN, None), (BOAT, 'Boat ' + RUN, None)):
    b = {'id': bid, 'name': name}
    if ship: b['ship'] = ship
    observe(host, bid, 'sphere', ref(SPH), bodies=[b])
    observe(host, bid, 'likes', 'gate ' + RUN)
observe(peer, KID, 'likes', 'ours', bodies=[{'id': KID, 'name': 'Rowan ' + RUN}])
observe(peer, ASH2, 'likes', 'ours', bodies=[{'id': ASH2, 'name': 'Ash ' + RUN}])

code, d = host('POST', '/sphere-share', {'sphere': SPH, 'ship': PEERNAME, 'mode': 'edit'})
check('share the sphere', code == 200, (code, d))
wait('the offer reaches the peer', lambda: dictish(dictish(peer('GET', '/shares')[1]).get('sphere_offers')).get(KEY), 60)
code, d = peer('POST', '/sphere-accept', {'host': HOSTNAME, 'sphere': SPH})
check('the peer accepts', code == 200, (code, d))
peer('POST', '/sync')
asks = wait('the matches by name wait for the owner',
            lambda: (lambda l: l if len(l) == 2 else None)([p for p in listish(peer('GET', '/pairing')[1]) if dictish(p).get('key') == KEY]), 90) or []
pairs = sorted((dictish(p).get('there'), dictish(p).get('here'), dictish(p).get('why')) for p in asks)
check('two name matches wait: the child, and the other of the same name', pairs == sorted([(ASH, ASH2, 'name'), (ROWAN, KID, 'name')]), asks)
tw = [dictish(r.get('value')) for r in rows(peer, 'person/me', 'twin')]
check("the host's body for the peer's owner pairs with person/me at once, by its ship", {'ship': HOSTNAME, 'id': PARTNER} in tw, tw)
time.sleep(10)
check('nothing comes in while a match waits', not values(peer, KID, 'likes', HOSTNAME) and not has_body(peer, BOAT), (values(peer, KID, 'likes'), has_body(peer, BOAT)))
check('the follow says why it waits', 'wait for the owner' in str(follow().get('error')), follow())

code, d = peer('POST', '/pairing', {'key': KEY, 'there': ROWAN, 'same': True})
check('the owner says the child is the same', code == 200 and dictish(d).get('waiting') == 1, (code, d))
code, d = peer('POST', '/pairing', {'key': KEY, 'there': ASH, 'same': False})
check('and the other is not', code == 200 and dictish(d).get('waiting') == 0, (code, d))
code, d = peer('POST', '/pairing', {'key': KEY, 'there': ASH, 'same': False})
check('a match already answered is a 404', code == 404, (code, d))
got = wait('the sphere comes in', lambda: values(peer, KID, 'likes', HOSTNAME) or None, 120) or []
check("the child's rows land on the peer's own body", got == ['gate ' + RUN], values(peer, KID, 'likes'))
check('the child is not made twice', not has_body(peer, ROWAN), ROWAN)
check('the body said to be different comes as its own', bool(wait('the other comes', lambda: values(peer, ASH, 'likes', HOSTNAME) or None, 60))
      and not values(peer, ASH2, 'likes', HOSTNAME), (values(peer, ASH, 'likes'), values(peer, ASH2, 'likes')))
check('a body the peer lacked is made', bool(wait('the boat comes', lambda: values(peer, BOAT, 'likes', HOSTNAME) or None, 60)), BOAT)
check("the partner's rows land on the peer's own self", 'gate ' + RUN in values(peer, 'person/me', 'likes', HOSTNAME), values(peer, 'person/me', 'likes'))
check('the host has nothing to ask: what the peer holds came with its twins', not [p for p in listish(host('GET', '/pairing')[1]) if SPH in str(dictish(p).get('sphere'))], host('GET', '/pairing')[1])

# put back what this run made
host('DELETE', '/sphere-share/' + SPH + '/' + PEERNAME)
for r in rows(peer, 'person/me', 'likes') + rows(peer, 'person/me', 'twin'):
    if r.get('by') == HOSTNAME or dictish(r.get('value')).get('id') == PARTNER or r.get('by') == 'share' and PARTNER in str(r.get('value')):
        peer('POST', '/retract', {'id': r.get('obs', ''), 'note': 'pairing gate'})
for bid in (SPH, PARTNER, ROWAN, ASH, BOAT):
    host('DELETE', '/body/' + bid)
for bid in (SPH, KID, ASH2, ASH, BOAT):
    peer('DELETE', '/body/' + bid)
print()
print('FAILED: ' + ', '.join(fails) if fails else 'ALL OK')
sys.exit(1 if fails else 0)
