"""gate.py: what the orrery gates share. One curl to the ship, one check
that counts and prints, the small readers and the ISO stamp. A gate
imports these beside its own helpers and reports from the same
fails and count."""
import json, subprocess, time

fails = []
count = [0]


def curl(method, url, body=None, jar=None, token=None, timeout=60, headers=()):
    """(status, parsed body): the JSON when it parses, else the text. A
    token is the request's whole identity, so a jar beside it is not
    sent: a request carrying both would be the owner's."""
    cmd = ['curl', '-s', '-m', str(timeout), '-X', method, '-w', '\n%{http_code}', url]
    if token:
        cmd += ['-H', 'Authorization: Bearer ' + token]
    elif jar:
        cmd += ['-b', jar]
    for h in headers:
        cmd += ['-H', h]
    if body is not None:
        cmd += ['-H', 'content-type: application/json', '-d', json.dumps(body)]
    out = subprocess.run(cmd, capture_output=True, text=True).stdout
    text, _, code = out.rpartition('\n')
    try:
        data = json.loads(text) if text else None
    except json.JSONDecodeError:
        data = text
    return int(code or 0), data


T0 = time.time()


def check(label, cond, detail=''):
    count[0] += 1
    print('%5.0fs ' % (time.time() - T0) + ('  ok   ' if cond else '  FAIL ') + label + ('' if cond else '   ' + str(detail)[:900]))
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
        time.sleep(1)
    check(label, bool(got), 'timed out after %ds' % secs)
    return got


def dictish(x):
    return x if isinstance(x, dict) else {}


def listish(x):
    return x if isinstance(x, list) else []


def iso(dt):
    return dt.replace(microsecond=0).strftime('%Y-%m-%dT%H:%M:%SZ')


def all_ok(d, key, n):
    items = listish(dictish(d).get(key))
    return len(items) == n and all(dictish(r).get('ok') is True for r in items)
