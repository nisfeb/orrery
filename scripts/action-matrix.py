#!/usr/bin/env python3
"""action-matrix.py HOST HJAR PEER PJAR
The shared actions gate (version 92) against two fake ships. HOST shares
a test sphere with PEER. An action HOST assigns to PEER's owner crosses
only once HOST's owner approves it, and lands in PEER's Inbox as a
proposal from HOST, whatever PEER's policy; HOST's copy stays open, not
carried out there. PEER marks it done and HOST's copy is done by PEER; HOST
dismisses another and PEER's copy is dismissed. An open action of HOST's
on a shared body, assigned to no one, is not filed again on PEER. Uses
`note`, a kind the executor never serves, so nothing but the feed moves
it. Each ship's name is read from its own /~/host. Safe to rerun."""
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


def observe(side, subject, name, value, bodies=()):
    return side('POST', '/observe', {'bodies': list(bodies), 'observations': [
        {'subject': subject, 'attr': name, 'value': value, 'at': iso(NOW), 'conf': 100,
         'source': {'kind': 'matrix', 'id': 'actions-' + RUN}, 'by': 'owner'}]})


def titled(side, title):
    """the side's actions of this title, any status"""
    return [dictish(a) for a in listish(side('GET', '/actions?status=all')[1]) if dictish(a).get('title') == title]


def status(side, aid):
    return next((a.get('status') for a in listish(side('GET', '/actions?status=all')[1]) if dictish(a).get('id') == aid), None)


def move(side, aid, to):
    return side('POST', '/actions/' + aid, {'status': to, 'note': 'action gate'})


SPH = 'sphere/gate-ac-' + RUN
PARTNER, BOAT = 'person/gate-ac-partner-' + RUN, 'thing/gate-ac-boat-' + RUN
KEY = HOSTNAME + '|' + SPH
WAX, PAINT, OIL = 'Gate wax ' + RUN, 'Gate paint ' + RUN, 'Gate oil ' + RUN
ref = lambda b: {'ref': b}

print('== shared actions between', HOSTNAME, 'and', PEERNAME)
_, ppol = peer('GET', '/policy')
ppol = dictish(ppol)
#  the peer approves notes by itself: a crossed note must still wait for its owner
peer('PUT', '/policy', dict(ppol, auto=sorted(set(listish(ppol.get('auto'))) | {'note'})))
#  and the host does not: its note waits for its own owner first
_, hpol = host('GET', '/policy')
hpol = dictish(hpol)
host('PUT', '/policy', dict(hpol, auto=sorted(set(listish(hpol.get('auto'))) - {'note'})))
observe(host, SPH, 'summary', 'the action gate', bodies=[{'id': SPH, 'name': 'Gate actions ' + RUN}])
observe(host, PARTNER, 'sphere', ref(SPH), bodies=[{'id': PARTNER, 'name': 'Partner ' + RUN, 'ship': PEERNAME}])
observe(host, BOAT, 'sphere', ref(SPH), bodies=[{'id': BOAT, 'name': 'Boat ' + RUN}])
code, d = host('POST', '/sphere-share', {'sphere': SPH, 'ship': PEERNAME, 'mode': 'edit'})
wait('the offer reaches the peer', lambda: dictish(dictish(peer('GET', '/shares')[1]).get('sphere_offers')).get(KEY), 60)
peer('POST', '/sphere-accept', {'host': HOSTNAME, 'sphere': SPH})
peer('POST', '/sync')
check('the sphere comes in', bool(wait('the boat arrives', lambda: peer('GET', '/body/' + BOAT)[0] == 200 or None, 120)), BOAT)

# assigned to the peer's owner: proposed here, nothing crosses yet
code, a = host('POST', '/act', {'kind': 'note', 'title': WAX, 'about': [BOAT], 'by': 'action-matrix',
                                 'payload': {'text': 'wax it', 'assignee': ref(PARTNER)}})
WID = dictish(a).get('id', '')
check('the host proposes a note for the partner', code == 200 and dictish(a).get('status') == 'proposed', (code, a))
time.sleep(40)
check('a proposal does not cross before its owner approves it', not titled(peer, WAX), titled(peer, WAX))
code, d = move(host, WID, 'approved')
check('the host approves it', code == 200, (code, d))
got = wait('it crosses', lambda: titled(peer, WAX) or None, 120) or [{}]
p = got[0]
check("it lands in the peer's Inbox as a proposal from the host, though the peer approves notes by itself",
      p.get('status') == 'proposed' and p.get('by') == HOSTNAME, p)
check('assigned to the peer itself, about its own body', dictish(dictish(p.get('payload')).get('assignee')).get('ref') == 'person/me'
      and BOAT in listish(p.get('about')), p)
time.sleep(20)
check("the host's copy stays open, not carried out there", status(host, WID) == 'approved', status(host, WID))
PID = p.get('id', '')
move(peer, PID, 'approved')
code, d = move(peer, PID, 'done')
check('the peer does it', code == 200, (code, d))
check("the host's copy is done, by the peer", bool(wait('done comes back', lambda: status(host, WID) == 'done' or None, 120)), status(host, WID))
check('and says who', any(dictish(h).get('by') == PEERNAME for h in dictish(next(iter(titled(host, WAX)), {})).get('history', [])), titled(host, WAX))

# the host dismisses one: the peer's copy goes too
code, a = host('POST', '/act', {'kind': 'note', 'title': OIL, 'about': [BOAT], 'by': 'action-matrix',
                                 'payload': {'text': 'oil it', 'assignee': ref(PARTNER)}})
OID = dictish(a).get('id', '')
move(host, OID, 'approved')
got = wait('the second crosses', lambda: titled(peer, OIL) or None, 120) or [{}]
move(host, OID, 'dismissed')
check("dismissed on the host, the peer's copy is dismissed", bool(wait('the dismissal comes', lambda: dictish(next(iter(titled(peer, OIL)), {})).get('status') == 'dismissed' or None, 120)),
      titled(peer, OIL))

# an open one of the host's, assigned to no one, is not filed again on the peer
code, a = host('POST', '/act', {'kind': 'note', 'title': PAINT, 'about': [BOAT], 'by': 'action-matrix', 'payload': {'text': 'paint it'}})
NID = dictish(a).get('id', '')
time.sleep(45)
check('it does not cross: no one here is asked', not titled(peer, PAINT), titled(peer, PAINT))
peer('POST', '/act', {'kind': 'note', 'title': PAINT, 'about': [BOAT], 'by': 'action-matrix', 'payload': {'text': 'paint it'}})
time.sleep(5)
check('the peer does not file what the host has open', not titled(peer, PAINT), titled(peer, PAINT))

# put back what this run made
for aid in (NID,):
    move(host, aid, 'dismissed')
host('DELETE', '/sphere-share/' + SPH + '/' + PEERNAME)
for bid in (SPH, PARTNER, BOAT):
    host('DELETE', '/body/' + bid)
for bid in (SPH, BOAT):
    peer('DELETE', '/body/' + bid)
peer('PUT', '/policy', ppol)
host('PUT', '/policy', hpol)
print()
print('FAILED: ' + ', '.join(fails) if fails else 'ALL OK')
sys.exit(1 if fails else 0)
