#!/usr/bin/env python3
"""notify-matrix.py HOST HJAR PEER PJAR
The notifications gate (version 93) against two fake ships. HOST shares
a test sphere with PEER. A leg HOST gives PEER's owner (a drop-off naming
the body HOST keeps for them) is pushed on PEER at once; any other change
is quiet until PEER's owner widens peer_push to "all", and then a page of
changes is pushed as one. A fake ship has no phone, so the gate reads the
push notes in PEER's audit log. Each ship's name is read from its own
/~/host. Safe to rerun: it puts PEER's policy back."""
import secrets, sys, time
from gate import fails, check, wait, dictish, listish, iso
import gate
from datetime import datetime, timezone

HOST, HJAR, PEER, PJAR = sys.argv[1:5]
HOSTNAME, PEERNAME = (str(gate.curl('GET', b + '/~/host')[1]).strip() for b in (HOST, PEER))
RUN = secrets.token_hex(3)
NOW = datetime.now(timezone.utc)
INSTANCE = '/grubbery/ball/apps/shell.shell/desks/orrery.desk/desk/data/orrery.orrery_app'


def api(base, jar, method, path, body=None):
    return gate.curl(method, base + '/apps/orrery/api' + path, body, jar=jar)


def host(method, path, body=None): return api(HOST, HJAR, method, path, body)
def peer(method, path, body=None): return api(PEER, PJAR, method, path, body)


def observe(side, subject, name, value, bodies=()):
    return side('POST', '/observe', {'bodies': list(bodies), 'observations': [
        {'subject': subject, 'attr': name, 'value': value, 'at': iso(NOW), 'conf': 100,
         'source': {'kind': 'matrix', 'id': 'notify-' + RUN}, 'by': 'owner'}]})


def pushes(since):
    """the push notes in PEER's audit log at or after a time (the log is a
    ring of 500, so counting entries would not do)"""
    code, log = gate.curl('GET', PEER + INSTANCE + '/tr/log?raw=1', jar=PJAR)
    log = log if isinstance(log, list) else []
    return [str(dictish(e).get('why')) for e in log if dictish(e).get('op') == 'push' and str(dictish(e).get('at')) >= since]


def log_len():
    """now, as the log stamps it"""
    return datetime.now(timezone.utc).strftime('%Y-%m-%dT%H:%M:%SZ')


SPH = 'sphere/gate-nt-' + RUN
PARTNER, KID = 'person/gate-nt-partner-' + RUN, 'person/gate-nt-kid-' + RUN
KEY = HOSTNAME + '|' + SPH
KIDNAME = 'Kid ' + RUN
ref = lambda b: {'ref': b}

print('== notifications between', HOSTNAME, 'and', PEERNAME)
_, ppol = peer('GET', '/policy')
ppol = dictish(ppol)
peer('PUT', '/policy', {k: v for k, v in ppol.items() if k != 'peer_push'})
observe(host, SPH, 'summary', 'the notify gate', bodies=[{'id': SPH, 'name': 'Gate notify ' + RUN}])
observe(host, PARTNER, 'sphere', ref(SPH), bodies=[{'id': PARTNER, 'name': 'Partner ' + RUN, 'ship': PEERNAME}])
observe(host, KID, 'sphere', ref(SPH), bodies=[{'id': KID, 'name': KIDNAME}])
host('POST', '/sphere-share', {'sphere': SPH, 'ship': PEERNAME, 'mode': 'edit'})
wait('the offer reaches the peer', lambda: dictish(dictish(peer('GET', '/shares')[1]).get('sphere_offers')).get(KEY), 60)
peer('POST', '/sphere-accept', {'host': HOSTNAME, 'sphere': SPH})
peer('POST', '/sync')
check('the sphere comes in', bool(wait('the kid arrives', lambda: peer('GET', '/body/' + KID)[0] == 200 or None, 120)), KID)

# a change that asks nothing is quiet by default
mark = log_len()
observe(host, KID, 'likes', 'swimming')
wait('the like crosses', lambda: (dictish(dictish(peer('GET', '/body/' + KID)[1]).get('attrs')).get('likes') or None), 120)
check('a change that asks nothing pushes nothing', not pushes(mark), pushes(mark))

# a leg that is now the peer owner's is told at once
mark = log_len()
observe(host, KID, 'drop-off', ref(PARTNER))
got = wait('the leg is pushed', lambda: [p for p in pushes(mark) if KIDNAME in p] or None, 120) or []
check("a drop-off naming the peer's owner is pushed to them", got == ['You drop off for ' + KIDNAME + '.'], pushes(mark))

# widened, every page of changes is pushed as one
peer('PUT', '/policy', dict(ppol, peer_push='all'))
mark = log_len()
observe(host, KID, 'status', 'at school')
got = wait('the change is pushed', lambda: [p for p in pushes(mark) if 'you share' in p] or None, 120) or []
check('widened, a page of changes is pushed as one', len(got) == 1 and got[0].startswith('changed '), pushes(mark))

# put back what this run made
peer('PUT', '/policy', ppol)
host('DELETE', '/sphere-share/' + SPH + '/' + PEERNAME)
for bid in (SPH, PARTNER, KID):
    host('DELETE', '/body/' + bid)
for bid in (SPH, KID):
    peer('DELETE', '/body/' + bid)
for r in listish(dictish(dictish(peer('GET', '/body/person/me')[1]).get('attrs')).get('twin')):
    if PARTNER in str(dictish(r).get('value')):
        peer('POST', '/retract', {'id': dictish(r).get('obs', ''), 'note': 'notify gate'})
print()
print('FAILED: ' + ', '.join(fails) if fails else 'ALL OK')
sys.exit(1 if fails else 0)
