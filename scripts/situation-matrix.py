#!/usr/bin/env python3
"""situation-matrix.py HOST HJAR PEER PJAR
The sharing-one-situation gate (version 94) against two fake ships. HOST
shares a party with a grandparent who runs orrery (a person carrying
PEER's ship) and one who does not. PEER is offered the party with the
park it names, thin (its name, address and point), accepts it in edit
mode, and its "we bring the cake" comes back to HOST under PEER's name.
The other gets an invitation (a message action with the party in plain
words), filed again when the time changes, the old one dismissed. A day
after the party ends, PEER's share closes by itself. Each ship's name is
read from its own /~/host. Safe to rerun: every run's ids are its own."""
import secrets, sys, time
from gate import fails, check, wait, dictish, listish, iso
import gate
from datetime import datetime, timedelta, timezone

HOST, HJAR, PEER, PJAR = sys.argv[1:5]
HOSTNAME, PEERNAME = (str(gate.curl('GET', b + '/~/host')[1]).strip() for b in (HOST, PEER))
RUN = secrets.token_hex(3)
NOW = datetime.now(timezone.utc)


def api(base, jar, method, path, body=None):
    return gate.curl(method, base + '/apps/orrery/api' + path, body, jar=jar)


def host(method, path, body=None): return api(HOST, HJAR, method, path, body)
def peer(method, path, body=None): return api(PEER, PJAR, method, path, body)


def observe(side, subject, name, value, by='owner', bodies=()):
    code, d = side('POST', '/observe', {'bodies': list(bodies), 'observations': [
        {'subject': subject, 'attr': name, 'value': value, 'at': iso(NOW), 'conf': 100,
         'source': {'kind': 'matrix', 'id': 'situation-' + RUN}, 'by': by}]})
    return code, (dictish(d).get('observations') or [{}])[0].get('id')


def values(side, bid, name, by=None):
    code, d = side('GET', '/body/' + bid)
    v = dictish(dictish(d).get('attrs')).get(name) if code == 200 else None
    rs = [dictish(r) for r in (v if isinstance(v, list) else [v] if v else [])]
    return sorted(str(r.get('value')) for r in rs if by is None or r.get('by') == by)


def invites():
    return [dictish(a) for a in listish(host('GET', '/actions?status=all')[1]) if dictish(a).get('title') == 'Invite Pop ' + RUN + ' to Party ' + RUN]


def offered():
    return dictish(dictish(peer('GET', '/shares')[1]).get('offers')).get(HOSTNAME + '/' + SIT)


SIT, PARK = 'situation/gate-st-party-' + RUN, 'place/gate-st-park-' + RUN
GRAN, POP = 'person/gate-st-gran-' + RUN, 'person/gate-st-pop-' + RUN
ref = lambda b: {'ref': b}
START = (NOW + timedelta(days=2)).replace(microsecond=0)

print('== sharing one situation from', HOSTNAME, 'to', PEERNAME)
observe(host, PARK, 'address', '1 Park Rd', bodies=[{'id': PARK, 'name': 'Park ' + RUN}])
observe(host, PARK, 'geo', '39.78,-89.65')
observe(host, GRAN, 'relationship', 'grandmother', bodies=[{'id': GRAN, 'name': 'Gran ' + RUN, 'ship': PEERNAME}])
observe(host, POP, 'email', 'pop-' + RUN + '@example.invalid', bodies=[{'id': POP, 'name': 'Pop ' + RUN}])
observe(host, SIT, 'starts', iso(START), bodies=[{'id': SIT, 'name': 'Party ' + RUN}])
observe(host, SIT, 'ends', iso(START + timedelta(hours=3)))
observe(host, SIT, 'location', ref(PARK))
observe(host, SIT, 'needs', 'a cake')
observe(host, SIT, 'shared-with', ref(GRAN))
_, popwith = observe(host, SIT, 'shared-with', ref(POP), by='generator')
host('POST', '/sync')

# the grandparent with orrery: the party, the park thin, edit mode
got = wait('the party is offered', offered, 120) or {}
check('the party is offered to the ship, in edit mode, with the park it names', got.get('mode') == 'edit'
      and any(dictish(t).get('id') == PARK and dictish(t).get('address') == '1 Park Rd' for t in listish(got.get('thin'))), got)
code, d = peer('POST', '/accept', {'host': HOSTNAME, 'id': SIT})
check('the party is accepted', code == 200, (code, d))
peer('POST', '/sync')
check('the party lands with its time and what it needs', bool(wait('the party lands', lambda: values(peer, SIT, 'needs', HOSTNAME) or None, 120))
      and values(peer, SIT, 'starts', HOSTNAME) == [iso(START)], (values(peer, SIT, 'needs'), values(peer, SIT, 'starts')))
check('the park comes thin: its name and address, as the host gave them', values(peer, PARK, 'address', HOSTNAME) == ['1 Park Rd']
      and dictish(peer('GET', '/body/' + PARK)[1]).get('name') == 'Park ' + RUN, (values(peer, PARK, 'address'), peer('GET', '/body/' + PARK)[1]))
observe(peer, SIT, 'needs', 'we bring the cake')
peer('POST', '/sync')
got = wait('the answer comes back', lambda: values(host, SIT, 'needs', PEERNAME) or None, 120) or []
check("their answer comes back under the peer's name", got == ['we bring the cake'], values(host, SIT, 'needs'))

# the grandparent without: an invitation, again when the time moves
got = wait('the invitation is filed', lambda: invites() or None, 60) or [{}]
text = str(dictish(got[0].get('payload')).get('text'))
check('the other gets an invitation in plain words, by mail', 'Party ' + RUN in text and 'Park ' + RUN + ', 1 Park Rd' in text
      and 'a cake' in text and dictish(got[0].get('payload')).get('via') == 'mail', got[0])
check('filed by whoever shared it, so a model\'s waits for the owner', got[0].get('status') == 'proposed', got[0])
observe(host, SIT, 'starts', iso(START + timedelta(hours=1)))
host('POST', '/sync')
got = wait('a new invitation', lambda: (lambda l: l if len(l) == 2 else None)(invites()), 90) or []
st = sorted(str(a.get('status')) for a in got)
check('the time moves: invited again, the old one dismissed', st == ['dismissed', 'proposed'], [(a.get('status'), dictish(a.get('payload')).get('text')) for a in got])

# a day after the end, the share closes
observe(host, SIT, 'ends', iso(NOW - timedelta(days=2)))
host('POST', '/sync')
check("a day after the party, the peer's share closes by itself", bool(wait('the share closes',
      lambda: (HOSTNAME + '/' + SIT) not in dictish(dictish(peer('GET', '/shares')[1]).get('accepted')) or None, 120)),
      dictish(dictish(peer('GET', '/shares')[1]).get('accepted')).keys())
check('what the peer holds stays', bool(values(peer, SIT, 'location', HOSTNAME)) and peer('GET', '/body/' + SIT)[0] == 200, values(peer, SIT, 'location'))

# put back what this run made
for a in invites():
    if a.get('status') in ('proposed', 'approved'):
        host('POST', '/actions/' + a.get('id', ''), {'status': 'dismissed', 'note': 'situation gate'})
for bid in (SIT, PARK, GRAN, POP):
    host('DELETE', '/body/' + bid)
for bid in (SIT, PARK):
    peer('DELETE', '/body/' + bid)
print()
print('FAILED: ' + ', '.join(fails) if fails else 'ALL OK')
sys.exit(1 if fails else 0)
