#!/usr/bin/env python3
"""twins-matrix.py HOST HJAR PEER PJAR
The twins gate (version 89) against two fake ships. HOST shares an
activity whose legs name PEER's owner and HOST's own; PEER reads them
as person/me and as its body for HOST. Sharing the person HOST keeps
for PEER's owner lands on PEER's person/me and writes its twin, and a
leg read before that twin was known is read again. A ref PEER pushes
back reads HOST's way; a twin fact never crosses; an offered event
lands on PEER's own body for the same calendar uid. Each ship's name is
read from its own /~/host. Safe to rerun: every run's ids are its own,
and it revokes and deletes what it made."""
import secrets, sys
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


def refs(side, bid, name, by=None):
    return sorted(str(dictish(r.get('value')).get('ref')) for r in rows(side, bid, name) if by is None or r.get('by') == by)


def observe(side, subject, name, value, src=('matrix', 'twins-' + RUN), by='owner', bodies=()):
    return side('POST', '/observe', {'bodies': list(bodies), 'observations': [
        {'subject': subject, 'attr': name, 'value': value, 'at': iso(NOW), 'conf': 100,
         'source': {'kind': src[0], 'id': src[1]}, 'by': by}]})


def carriers(side, ship):
    """the people on a side carrying a ship: another gate's accept can leave one"""
    return [dictish(x).get('id') for x in listish(dictish(side('GET', '/location')[1]).get('peers')) if dictish(x).get('ship') == ship]


def offered(key):
    return dictish(dictish(peer('GET', '/shares')[1]).get('offers')).get(key)


def share(bid, mode):
    code, d = host('POST', '/share', {'id': bid, 'ship': PEERNAME, 'mode': mode})
    wait('the offer of ' + bid + ' reaches the peer', lambda: offered(HOSTNAME + '/' + bid), 60)
    return code, d


PARTNER = 'person/gate-tw-' + RUN          # HOST's body for PEER's owner
SWIM = 'activity/gate-tw-swim-' + RUN       # shared, its legs naming both owners
THEM = 'person/gate-tw-host-' + RUN         # PEER's body for HOST's owner
PARTY = 'situation/gate-tw-party-' + RUN    # HOST's body for an event
OURS = 'situation/gate-tw-our-party-' + RUN  # PEER's body for the same event
UID = 'gate-' + RUN + '@' + HOSTNAME
ref = lambda b: {'ref': b}

print('== twins between', HOSTNAME, 'and', PEERNAME)
host('POST', '/bodies', {'id': PARTNER, 'name': 'Gate partner ' + RUN, 'ship': PEERNAME})
peer('POST', '/bodies', {'id': THEM, 'name': 'Gate host ' + RUN, 'ship': HOSTNAME})
observe(host, SWIM, 'drop-off', ref(PARTNER), bodies=[{'id': SWIM, 'name': 'Gate swim ' + RUN}])
observe(host, SWIM, 'pick-up', ref('person/me'))

# the activity first: its drop-off names a body the peer has no twin for yet
code, d = share(SWIM, 'edit')
check('share the activity in edit mode', code == 200, (code, d))
code, d = peer('POST', '/accept', {'host': HOSTNAME, 'id': SWIM})
check('the activity lands under its own id', code == 200 and dictish(d).get('target') == SWIM, (code, d))
peer('POST', '/sync')
got = wait('the legs mirror', lambda: (lambda p: p if p else None)(refs(peer, SWIM, 'pick-up', HOSTNAME)), 90) or []
check("the host's own self reads as the peer's body carrying the host's ship", len(got) == 1 and got[0] in carriers(peer, HOSTNAME), (got, carriers(peer, HOSTNAME)))
check('the drop-off, with no twin yet, arrives as written', refs(peer, SWIM, 'drop-off', HOSTNAME) == [PARTNER], refs(peer, SWIM, 'drop-off'))
twins = [dictish(r.get('value')) for r in rows(peer, SWIM, 'twin')]
check('the accept wrote the twin on the landing body', {'ship': HOSTNAME, 'id': SWIM} in twins, twins)

# the person the host keeps for the peer's owner: it lands on person/me, and its twin fixes the leg
code, d = share(PARTNER, 'read')
code, d = peer('POST', '/accept', {'host': HOSTNAME, 'id': PARTNER})
check("the host's body for the peer's owner lands on person/me", code == 200 and dictish(d).get('target') == 'person/me', (code, d))
twins = [dictish(r.get('value')) for r in rows(peer, 'person/me', 'twin')]
check("person/me carries the host's id for it as its twin", {'ship': HOSTNAME, 'id': PARTNER} in twins, twins)
peer('POST', '/sync')
got = wait('the drop-off is read again', lambda: (lambda p: p if p == ['person/me'] else None)(refs(peer, SWIM, 'drop-off', HOSTNAME)), 90) or []
check('the drop-off read before its twin now means the peer itself, once', got == ['person/me'], refs(peer, SWIM, 'drop-off'))

# the peer's own row goes back and reads the host's way; its twin stays home
code, d = observe(peer, SWIM, 'participants', ref('person/me'))
check('the peer says it takes part', code == 200, (code, d))
peer('POST', '/sync')
got = wait('the participant crosses', lambda: (lambda p: p if p else None)(refs(host, SWIM, 'participants', PEERNAME)), 90) or []
check("the peer's person/me arrives as the host's body carrying the peer's ship", len(got) == 1 and got[0] in carriers(host, PEERNAME), (got, carriers(host, PEERNAME)))
check('no twin fact crossed to the host', not [r for r in rows(host, SWIM, 'twin') if r.get('by') == PEERNAME], rows(host, SWIM, 'twin'))

# an event both ships keep under their own ids: the offer's uid lands it on the peer's
observe(host, PARTY, 'starts', iso(NOW), src=('calendar', 'gatecal/' + UID), by='calendar', bodies=[{'id': PARTY, 'name': 'Gate party ' + RUN}])
code, d = observe(peer, OURS, 'starts', iso(NOW), src=('calendar', UID), by='calendar', bodies=[{'id': OURS, 'name': 'Gate party ' + RUN}])
check('each ship holds the event from the calendar', code == 200, (code, d))
code, d = share(PARTY, 'read')
check('the offer carries the event uid', UID in listish(dictish(offered(HOSTNAME + '/' + PARTY)).get('uids')), offered(HOSTNAME + '/' + PARTY))
code, d = peer('POST', '/accept', {'host': HOSTNAME, 'id': PARTY})
check("the event lands on the peer's own body for it", code == 200 and dictish(d).get('target') == OURS, (code, d))

# put back what this run made
for bid in (SWIM, PARTNER, PARTY):
    host('DELETE', '/share/' + bid + '/' + PEERNAME)
for bid in (SWIM, PARTNER, PARTY):
    host('DELETE', '/body/' + bid)
for bid in (SWIM, THEM, OURS):
    peer('DELETE', '/body/' + bid)
for r in rows(peer, 'person/me', 'twin'):
    if dictish(r.get('value')).get('id') == PARTNER:
        peer('POST', '/retract', {'id': r.get('obs', ''), 'note': 'twins gate'})
print()
print('FAILED: ' + ', '.join(fails) if fails else 'ALL OK')
sys.exit(1 if fails else 0)
