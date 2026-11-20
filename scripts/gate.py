"""gate.py: what the orrery gates share. One curl to the ship, one check
that counts and prints, the small readers and the ISO stamp. A gate
imports these beside its own helpers and reports from the same
fails and count."""
import json, subprocess, time

fails = []
count = [0]


def curl(method, url, body=None, jar=None, token=None, timeout=60, headers=(), raw=None):
    """(status, parsed body): the JSON when it parses, else the text. A
    token is the request's whole identity, so a jar beside it is not
    sent: a request carrying both would be the owner's. raw is a body
    sent as it is, with whatever content-type headers names."""
    cmd = ['curl', '-s', '-m', str(timeout), '-X', method, '-w', '\n%{http_code}', url]
    #  a read follows a redirect, as a browser does
    if method == 'GET':
        cmd.insert(1, '-L')
    if token:
        cmd += ['-H', 'Authorization: Bearer ' + token]
    elif jar:
        cmd += ['-b', jar]
    for h in headers:
        cmd += ['-H', h]
    if raw is not None:
        cmd += ['--data-binary', raw]
    elif body is not None:
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


#  The ship's namespace, through the kernel's own API: GET
#  /grubbery/api/peek/<path> reads a grub, or lists a directory as
#  {"files", "dirs"} when the path ends in a slash. PUT
#  /grubbery/api/make/<path>?blot=/json makes a grub, and with ?force=1
#  writes over one. GET /grubbery/api/bang/<dir>/ counts what is banged.
_shells = {}


def shell(host, jar):
    """the shell's directory: /apps/shell on a current kernel, and
    /apps/shell.shell on an older one, as /apps/ lists it"""
    if host not in _shells:
        code, d = curl('GET', host + '/grubbery/api/peek/apps/', jar=jar)
        dirs = listish(dictish(d).get('dirs'))
        if 'shell' in dirs:
            _shells[host] = '/apps/shell'
        elif 'shell.shell' in dirs:
            _shells[host] = '/apps/shell.shell'
        else:
            raise SystemExit('no shell under /apps on %s: GET /grubbery/api/peek/apps/ answered %s %s' % (host, code, str(d)[:200]))
    return _shells[host]


def app(host, jar, desk='orrery'):
    """where a desk's instance lives"""
    return '%s/desks/%s.desk/desk/data/%s.%s_app' % (shell(host, jar), desk, desk, desk)


def peek(host, path, jar, timeout=60):
    """(status, body) of a grub, or of a directory's listing when path ends in /"""
    return curl('GET', host + '/grubbery/api/peek' + path, jar=jar, timeout=timeout)


def lay(host, path, doc, jar):
    """a JSON grub written whole, made if it is not there yet"""
    raw = json.dumps(doc)
    hd = ['content-type: application/json']
    code, d = curl('PUT', host + '/grubbery/api/make' + path + '?force=1&blot=/json', jar=jar, raw=raw, headers=hd)
    if code == 404:
        code, d = curl('PUT', host + '/grubbery/api/make' + path + '?blot=/json', jar=jar, raw=raw, headers=hd)
    return code, d


def banged(host, path, jar):
    """how many grubs and directories under path are banged, or None when
    the ship cannot say (nothing there, or no answer)"""
    code, d = curl('GET', host + '/grubbery/api/bang' + path.rstrip('/') + '/', jar=jar)
    n = dictish(d).get('banged') if code == 200 else None
    return n if isinstance(n, int) else None
