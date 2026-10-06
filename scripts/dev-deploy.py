#!/usr/bin/env python3
"""Put code/ on a DEV ship as the orrery desk, the way a user adds one.

  dev-deploy.py <base-url> <cookie-jar> <code-dir> [--add]

Mirrors code/ into the ship's ball at /furum-dev/code through the explorer
(creating what is missing, rewriting the rest), then stamps that copy's
version.json so the desk pulls it: a desk follows its source's version file,
and any change to it is a release. --add makes the desk the first time
(POST /desks/add, following /furum-dev/code), jailed until you approve it on
/apps/grubbery/permits. The jar comes from hoon-test-kit/ship-cookie.sh.

Never point this at a real ship: releases go through the forge.
"""
import json, os, re, sys, time, urllib.error, urllib.parse, urllib.request

url, jar = sys.argv[1].rstrip('/'), sys.argv[2]
code = sys.argv[3]
dest = 'orrery-dev/code'
cookie = next(f'{p[5]}={p[6]}' for p in (l.rstrip('\n').split('\t') for l in open(jar))
              if len(p) == 7 and p[5].startswith('urbauth-'))

def call(method, path, form=None, body=None):
    head = {'cookie': cookie, 'accept': 'application/json'}
    data = urllib.parse.urlencode(form).encode() if form else None
    if body is not None:
        data, head['content-type'] = json.dumps(body).encode(), 'application/json'
    req = urllib.request.Request(f'{url}/{path}', data=data, method=method, headers=head)
    #  the explorer answers a create with a 303 back to the page; don't follow it
    class Stay(urllib.request.HTTPRedirectHandler):
        def redirect_request(self, *a): return None
    try:
        with urllib.request.build_opener(Stay).open(req) as r: return r.status, r.read()
    except urllib.error.HTTPError as e: return e.code, e.read()

def exists(path):
    return call('GET', f'grubbery/ball/{path}?info=1')[0] == 200

def ensure_dir(path):
    if exists(path): return
    parent, name = path.rsplit('/', 1) if '/' in path else ('', path)
    if parent: ensure_dir(parent)
    s, b = call('POST', f'grubbery/ball/{parent}', {'action': 'create-folder', 'foldername': name})
    if s not in (200, 303): sys.exit(f'create-folder {path}: {s} {b[:200]}')

def blot(path):
    s, b = call('GET', f'grubbery/ball/{path}?info=1')
    return json.loads(b).get('blot') if s == 200 else None

#  a .hoon or .json file is kept under its own mark; any other (the icon)
#  as mime, which is what a /< import of it finds, as the forge lays it
def put(rel, text):
    path = f'{dest}/{rel}'
    d, name = path.rsplit('/', 1)
    ensure_dir(d)
    form = {'action': 'create-file', 'filename': name}
    if not name.endswith(('.hoon', '.json')):
        form['blot'] = '/mime'
        if blot(path) not in (None, '/mime'):
            s, b = call('POST', f'grubbery/ball/{d}', {'action': 'delete-grub', 'filename': name})
            if s not in (200, 303): sys.exit(f'delete-grub {path}: {s} {b[:200]}')
    if not exists(path):
        s, b = call('POST', f'grubbery/ball/{d}', form)
        if s not in (200, 303): sys.exit(f'create-file {path}: {s} {b[:200]}')
    s, b = call('POST', f'grubbery/ball/{path}', {'action': 'write-text', 'content': text})
    if s != 200: sys.exit(f'write-text {path}: {s} {b.decode(errors="replace")[:400]}')

files = sorted(os.path.relpath(os.path.join(dp, f), code)
               for dp, _, fs in os.walk(code) for f in fs)
for rel in files:
    if rel == 'version.json': continue
    put(rel, open(os.path.join(code, rel), encoding='utf-8').read())
    print('  ' + rel)
#  last, so the desk pulls a whole tree: the repo's version, stamped
ver = json.load(open(os.path.join(code, 'version.json')))
ver['dev'] = time.strftime('%Y-%m-%dT%H:%M:%S')
put('version.json', json.dumps(ver))
print(f'  version.json {json.dumps(ver)}')

if '--add' in sys.argv:
    s, b = call('POST', 'apps/grubbery/desks/add', body={'name': 'orrery', 'code': '/' + dest})
    print(f'desks/add: {s} {b.decode(errors="replace")}')
