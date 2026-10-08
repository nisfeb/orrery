#!/usr/bin/env python3
"""location-matrix.py HOST HJAR PEER PJAR
The location sharing gate (version 88) against two fake ships: HOST
shares its owner's position with PEER for a while, about a kilometre and
then exact; PEER keeps the latest only when a person there carries
HOST's ship; a stop and an arrival home both end it on PEER. Each ship's
name is read from its own /~/host. Safe to rerun: it stops what an
earlier run left and puts back what it changed."""
import secrets, sys, time
from gate import fails, check, wait, dictish, listish
import gate

HOST, HJAR, PEER, PJAR = sys.argv[1:5]
HOSTNAME, PEERNAME = (str(gate.curl('GET', b + '/~/host')[1]).strip() for b in (HOST, PEER))
RUN = secrets.token_hex(3)
HOME = ('39.7817', '-89.6501')


def api(base, jar, method, path, body=None):
    return gate.curl(method, base + '/apps/orrery/api' + path, body, jar=jar)


def h(method, path, body=None): return api(HOST, HJAR, method, path, body)
def p(method, path, body=None): return api(PEER, PJAR, method, path, body)


def theirs():
    """PEER's entry for HOST's position, or {}"""
    return next((e for e in listish(dictish(p('GET', '/location')[1]).get('in')) if dictish(e).get('ship') == HOSTNAME), {})


def carriers():
    """the people on PEER carrying HOST's ship: another gate's accept can leave one"""
    return [dictish(x) for x in listish(dictish(p('GET', '/location')[1]).get('peers')) if dictish(x).get('ship') == HOSTNAME]


def obs(sub, attr, value):
    return {'subject': sub, 'attr': attr, 'value': value, 'conf': 100, 'source': {'kind': 'user', 'id': 'location-gate-' + RUN}, 'by': 'owner'}


# a clean slate: no grant left on HOST, a person on each side carrying the other's ship
h('DELETE', '/location/share/' + PEERNAME)
HP, PP = 'person/gate-loc-peer-' + RUN, 'person/gate-loc-host-' + RUN
h('POST', '/bodies', {'id': HP, 'name': 'Gate peer ' + RUN, 'ship': PEERNAME})
p('POST', '/bodies', {'id': PP, 'name': 'Gate host ' + RUN, 'ship': HOSTNAME})
code, hd = h('POST', '/observe', {'bodies': [{'id': 'place/home', 'name': 'Home'}], 'observations': [obs('place/home', 'geo', ','.join(HOME))]})
home_row = (dictish(hd).get('observations') or [{}])[0].get('id')

print('== location sharing between', HOSTNAME, 'and', PEERNAME)
code, d = h('GET', '/location')
check('the people with a ship are offered to share with', code == 200 and any(dictish(x).get('ship') == PEERNAME for x in listish(dictish(d).get('peers'))), d)
code, d = h('POST', '/location/share', {'ship': PEERNAME, 'hours': 1, 'precision': 'area'})
check('a share for an hour, to about a kilometre, answers its grant', code == 200 and dictish(d).get('ship') == PEERNAME and dictish(d).get('exact') is False and dictish(d).get('until'), (code, d))
h('POST', '/position', {'lat': 39.6588, 'lon': -89.7112, 'acc': 12})
e = wait('the peer has the fix', lambda: theirs() or None, 60) or {}
check('the peer keeps it, cut to two decimals, with the person it belongs to and the time it ends',
      e.get('lat') == '39.65' and e.get('lon') == '-89.71' and e.get('id') in [c.get('id') for c in carriers()] and e.get('until'), e)
check('and how far that is from the peer\'s home is its own reckoning', 'km_from_home' in e, e)
code, d = h('POST', '/location/share', {'ship': PEERNAME, 'hours': 1, 'precision': 'exact'})
h('POST', '/position', {'lat': 39.6589, 'lon': -89.7113, 'acc': 12})
e = wait('the exact fix arrives', lambda: (lambda x: x if x.get('lat') == '39.6589' else None)(theirs()), 60) or {}
check('exact, the fix goes as the phone gave it', e.get('lat') == '39.6589' and e.get('lon') == '-89.7113', e)
# a ship no person on the peer carries is refused: every carrier goes for a moment, and comes back
away = carriers()
for c in away:
    p('DELETE', '/body/' + c['id'])
h('POST', '/position', {'lat': 39.6590, 'lon': -89.7114, 'acc': 12})
time.sleep(12)
check('with no person carrying the ship, the peer keeps nothing new', theirs().get('lat') != '39.659', theirs())
for c in away:
    p('POST', '/bodies', {'id': c['id'], 'name': c.get('name') or c['id'], 'ship': HOSTNAME})
# a stop ends it on the peer
code, d = h('DELETE', '/location/share/' + PEERNAME)
check('a stop answers that the peer was told', code == 200 and dictish(d).get('told') is True, (code, d))
check('and the peer drops the position', bool(wait('the peer drops it', lambda: (not theirs()) or None, 60)), theirs())
code, d = h('DELETE', '/location/share/' + PEERNAME)
check('stopping what is not shared is a 404', code == 404, (code, d))
# until home: begun at home it lasts; seen away, then home, it ends by itself
h('POST', '/position', {'lat': float(HOME[0]) + 0.0002, 'lon': float(HOME[1]), 'acc': 12})
code, d = h('POST', '/location/share', {'ship': PEERNAME, 'home': True, 'precision': 'exact'})
check('a share until home has no end time', code == 200 and dictish(d).get('home') is True and not dictish(d).get('until'), (code, d))
e = wait('the latest fix goes at once', lambda: theirs() or None, 60) or {}
check('begun at home, the latest fix goes at once and the share lasts', e.get('lat') == str(float(HOME[0]) + 0.0002), e)
h('POST', '/position', {'lat': 39.6012, 'lon': -89.7012, 'acc': 12})
wait('the away fix arrives', lambda: (lambda x: x if x.get('lat') == '39.6012' else None)(theirs()), 60)
h('POST', '/position', {'lat': float(HOME[0]) + 0.0003, 'lon': float(HOME[1]), 'acc': 12})
check('home, the share ends and the peer drops it', bool(wait('home ends it', lambda: (not theirs()) or None, 60)), theirs())
code, d = h('GET', '/location')
check('and no grant is left on the host', not listish(dictish(d).get('out')), d)

# put back what this run changed
if home_row: h('POST', '/retract', {'id': home_row, 'note': 'location gate'})
h('DELETE', '/body/' + HP)
p('DELETE', '/body/' + PP)
print()
print('FAILED: ' + ', '.join(fails) if fails else 'ALL OK')
sys.exit(1 if fails else 0)
