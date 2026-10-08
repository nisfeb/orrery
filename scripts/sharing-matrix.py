#!/usr/bin/env python3
"""sharing-matrix.py HOST HJAR PEER PJAR
The sharing-management gate (version 95) against two fake ships: what the
page's buttons do between them. PEER declines a sphere HOST offers, and
the offer goes. PEER leaves a sphere it followed in edit mode: HOST's
record drops PEER, its group with it, and HOST stops reading PEER's feed.
PEER leaves a body it followed: HOST's record drops PEER. What PEER holds
stays. Each ship's name is read from its own /~/host. Safe to rerun."""
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
def hshares(): return dictish(host('GET', '/shares')[1])
def pshares(): return dictish(peer('GET', '/shares')[1])


def observe(side, subject, name, value, bodies=()):
    return side('POST', '/observe', {'bodies': list(bodies), 'observations': [
        {'subject': subject, 'attr': name, 'value': value, 'at': iso(NOW), 'conf': 100,
         'source': {'kind': 'matrix', 'id': 'sharing-' + RUN}, 'by': 'owner'}]})


S1, S2 = 'sphere/gate-sh-one-' + RUN, 'sphere/gate-sh-two-' + RUN
BOAT = 'thing/gate-sh-boat-' + RUN
ref = lambda b: {'ref': b}

print('== sharing management between', HOSTNAME, 'and', PEERNAME)
observe(host, S1, 'summary', 'one', bodies=[{'id': S1, 'name': 'Gate one ' + RUN}, {'id': S2, 'name': 'Gate two ' + RUN}, {'id': BOAT, 'name': 'Boat ' + RUN}])
observe(host, BOAT, 'sphere', ref(S2))

# a declined offer goes
host('POST', '/sphere-share', {'sphere': S1, 'ship': PEERNAME, 'mode': 'read'})
K1 = HOSTNAME + '|' + S1
wait('the offer reaches the peer', lambda: dictish(pshares().get('sphere_offers')).get(K1), 60)
code, d = peer('POST', '/sphere-decline', {'host': HOSTNAME, 'sphere': S1})
check('the peer declines a sphere', code == 200, (code, d))
check('and the offer goes', K1 not in dictish(pshares().get('sphere_offers')), pshares().get('sphere_offers'))
code, d = peer('POST', '/sphere-decline', {'host': HOSTNAME, 'sphere': S1})
check('declining it again is a 404', code == 404, (code, d))

# leaving a sphere followed in edit mode
host('POST', '/sphere-share', {'sphere': S2, 'ship': PEERNAME, 'mode': 'edit'})
K2 = HOSTNAME + '|' + S2
wait('the second offer reaches the peer', lambda: dictish(pshares().get('sphere_offers')).get(K2), 60)
peer('POST', '/sphere-accept', {'host': HOSTNAME, 'sphere': S2})
peer('POST', '/sync')
check('the sphere comes in', bool(wait('the boat arrives', lambda: peer('GET', '/body/' + BOAT)[0] == 200 or None, 120)), BOAT)
check('the host reads its edits', bool(wait('the host follows back', lambda: any(dictish(f).get('role') == 'host' and dictish(f).get('local') == S2
      for f in dictish(hshares().get('sphere_follows')).values()) or None, 60)), hshares().get('sphere_follows'))
code, d = peer('POST', '/sphere-leave', {'host': HOSTNAME, 'sphere': S2})
check('the peer leaves the sphere, and the host is told', code == 200 and dictish(d).get('told') is True, (code, d))
check('the peer follows it no more, nor keeps a feed for the host', K2 not in dictish(pshares().get('sphere_follows'))
      and HOSTNAME not in dictish(dictish(pshares().get('sphere_shares')).get(S2)), pshares())
check("the host's record drops the peer", bool(wait('the host drops it', lambda: PEERNAME not in dictish(dictish(hshares().get('sphere_shares')).get(S2)) or None, 60)),
      hshares().get('sphere_shares'))
check("and the host reads the peer's feed no more", not any(dictish(f).get('role') == 'host' and dictish(f).get('local') == S2
      for f in dictish(hshares().get('sphere_follows')).values()), hshares().get('sphere_follows'))
check('what the peer holds stays', peer('GET', '/body/' + BOAT)[0] == 200, BOAT)
code, d = peer('POST', '/sphere-leave', {'host': HOSTNAME, 'sphere': S2})
check('leaving it again is a 404', code == 404, (code, d))

# leaving a body
host('POST', '/share', {'id': BOAT, 'ship': PEERNAME, 'mode': 'read'})
KB = HOSTNAME + '/' + BOAT
wait('the body offer reaches the peer', lambda: dictish(pshares().get('offers')).get(KB), 60)
peer('POST', '/accept', {'host': HOSTNAME, 'id': BOAT})
code, d = peer('POST', '/leave', {'host': HOSTNAME, 'id': BOAT})
check('the peer leaves a body, and the host is told', code == 200 and dictish(d).get('told') is True, (code, d))
check('the peer follows it no more', KB not in dictish(pshares().get('accepted')), pshares().get('accepted'))
check("the host's record drops the peer", bool(wait('the host drops the body share', lambda: PEERNAME not in dictish(dictish(hshares().get('shares')).get(BOAT)) or None, 60)),
      dictish(hshares().get('shares')).get(BOAT))

# put back what this run made
host('DELETE', '/sphere-share/' + S1 + '/' + PEERNAME)
for bid in (S1, S2, BOAT):
    host('DELETE', '/body/' + bid)
for bid in (S2, BOAT):
    peer('DELETE', '/body/' + bid)
print()
print('FAILED: ' + ', '.join(fails) if fails else 'ALL OK')
sys.exit(1 if fails else 0)
